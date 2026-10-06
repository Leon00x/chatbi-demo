import os
import tempfile

# Configure isolated DB before importing app modules.
_temp = tempfile.TemporaryDirectory()
os.environ['DATABASE_URL'] = 'sqlite:///' + (_temp.name.replace('\\','/') + '/test.db')
os.environ['MAAS_API_KEY'] = ''

import json
import sqlite3
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app import service, maas, config
from app.database import seed_database, query_database, validate_sql, engine

@pytest.fixture(autouse=True)
def initialize():
    seed_database()

@pytest.fixture(scope='session', autouse=True)
def release_database():
    yield
    engine.dispose()
    _temp.cleanup()

def test_seed_and_aggregate():
    result = query_database('SELECT COUNT(DISTINCT order_id) AS orders, COUNT(*) AS lines FROM sales')
    row = result['rows'][0]
    assert row['lines'] > row['orders'] > 10000
    assert query_database('SELECT name FROM stores')['row_count'] == 4
    first_count = row['lines']
    seed_database()
    assert query_database('SELECT COUNT(*) AS n FROM sales')['rows'][0]['n'] == first_count
    result = query_database("SELECT stores.name AS store_name, ROUND(SUM(net_amount),2) AS revenue FROM sales JOIN stores ON stores.id=sales.store_id WHERE sale_date>='2026-09-01' AND sale_date<'2026-10-01' GROUP BY stores.name")
    assert len(result['rows']) == 4
    assert all(row['revenue'] > 0 for row in result['rows'])

@pytest.mark.parametrize('sql', [
    'DELETE FROM sales', 'DROP TABLE sales', 'SELECT * FROM sales; DELETE FROM sales',
    'SELECT * FROM sqlite_master', 'PRAGMA table_info(sales)', "ATTACH DATABASE 'x' AS other",
    'SELECT * FROM other.sales', 'WITH q AS (SELECT * FROM sqlite_master) SELECT * FROM q',
    "SELECT load_extension('x')", 'SELECT * FROM pragma_table_info(\'sales\')',
    'SELECT * FROM sales UNION SELECT * FROM sqlite_master',
    'SELECT randomblob(1000000000)',
])
def test_unsafe_sql_rejected(sql):
    with pytest.raises((ValueError, sqlite3.Error)):
        query_database(sql)

def test_cte_limit_empty_and_duplicate_columns():
    assert query_database('WITH q AS (SELECT name FROM stores) SELECT * FROM q')['row_count'] == 4
    result = query_database('SELECT * FROM sales')
    assert len(result['rows']) == 200 and result['truncated']
    assert query_database("SELECT * FROM sales WHERE sale_date='2027-01-01'")['rows'] == []
    with pytest.raises(ValueError):
        query_database('SELECT id, id FROM sales')

def test_health_missing_key_and_contract(monkeypatch):
    monkeypatch.setattr(config, 'API_KEY', '')
    with TestClient(app) as client:
        health = client.get('/api/health').json()
        assert health['maas']['state'] == 'missing_key'
        assert health['features']['charts'] is False
        assert 'api_key' not in json.dumps(health).lower()
        assert client.get('/api/scenario').json()['currency'] == 'SGD'
        assert client.post('/api/connection/check').json()['state'] == 'missing_key'
        assert client.post('/api/chat',json={'question':'测试'}).status_code == 503
        assert client.post('/api/chat',json={'question':'','history':[]}).status_code == 422

def test_chat_response_and_analysis_failure(monkeypatch):
    calls = []
    async def fake(messages, max_tokens=1200):
        calls.append(messages)
        if len(calls) > 1:
            raise maas.MaaSError('timeout', 'fake upstream failure')
        return json.dumps({'kind':'query','answer':'门店列表','sql':'SELECT name FROM stores'})
    monkeypatch.setattr(service, 'completion', fake)
    with TestClient(app) as client:
        result = client.post('/api/chat',json={'question':'分析所有门店'}).json()
        assert result['chart'] is None and len(result['table']['rows']) == 4
        assert result['sql'] and result['warnings'] and result['analysis'] is None
    assert len(calls) == 2

@pytest.mark.parametrize('question,expected_calls', [
    ('Sales by store?', 1),
    ('Explain the change', 2),
    ('Why did it change?', 2),
    ('分析销售变化', 2),
    ('有什么建议？', 2),
    ('Show data only, without analysis', 1),
    ("Do not analyze the results", 1),
    ('只展示数据，不需要分析', 1),
])
def test_question_controls_analysis(monkeypatch, question, expected_calls):
    calls = []
    async def fake(messages, max_tokens=1200):
        calls.append(messages)
        if len(calls) == 2:
            return 'Analysis from the returned rows.'
        return json.dumps({'kind':'query','answer':'Store totals','sql':'SELECT stores.name AS store, SUM(net_amount) AS revenue FROM sales JOIN stores ON stores.id=sales.store_id GROUP BY stores.name'})
    monkeypatch.setattr(service, 'completion', fake)
    with TestClient(app) as client:
        response = client.post('/api/chat', json={'question':question})
        assert response.status_code == 200
        result = response.json()
        assert bool(result['analysis']) == (expected_calls == 2)
        assert result['chart'] is None
    assert len(calls) == expected_calls

def test_no_analysis_and_invalid_model_plan(monkeypatch):
    calls=[]
    async def fake(messages, max_tokens=1200):
        calls.append(messages)
        return '{"kind":"query","answer":"门店","sql":"SELECT name FROM stores"}'
    monkeypatch.setattr(service,'completion',fake)
    with TestClient(app) as client:
        assert client.post('/api/chat',json={'question':'门店'}).json()['analysis'] is None
        assert len(calls) == 1
        async def bad(*args,**kwargs): return '{"kind":"query","answer":"删除","sql":"DELETE FROM sales"}'
        monkeypatch.setattr(service,'completion',bad)
        assert client.post('/api/chat',json={'question':'删除数据'}).status_code == 422
        async def invalid(*args,**kwargs): return 'not JSON'
        monkeypatch.setattr(service,'completion',invalid)
        assert client.post('/api/chat',json={'question':'测试'}).status_code == 422

@pytest.mark.parametrize('http_status,code',[(401,'auth_failed'),(403,'auth_failed'),(404,'model_or_endpoint'),(429,'rate_limited'),(500,'upstream_error')])
def test_maas_error_classification(monkeypatch,http_status,code):
    import httpx
    monkeypatch.setattr(config,'API_KEY','test-placeholder')
    monkeypatch.setattr(config,'BASE_URL','https://example.invalid/v1')
    monkeypatch.setattr(config,'MODEL','test-model')
    class FakeClient:
        def __init__(self,**kwargs): pass
        async def __aenter__(self): return self
        async def __aexit__(self,*args): pass
        async def post(self,*args,**kwargs): return httpx.Response(http_status,json={'error':'secret upstream body'})
    monkeypatch.setattr(maas.httpx,'AsyncClient',FakeClient)
    with TestClient(app) as client:
        result=client.post('/api/connection/check').json()
        assert result['state']==code
        assert 'secret' not in json.dumps(result)
