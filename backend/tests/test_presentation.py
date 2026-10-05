import json
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app import service
from app.presentation import choose_chart, validate_chart, analysis_requested


def table(rows):
    return {'columns': list(rows[0]) if rows else ['name', 'value'], 'rows': rows}


@pytest.mark.parametrize('question,expected', [
    ('Compare sales by store', 'bar'), ('Show sales share by category', 'pie'),
    ('按门店比较销售额', 'bar'), ('各品类占比', 'pie'), ('Show a line chart', 'line'),
])
def test_default_and_requested_types(question, expected):
    data = table([{'name': 'A', 'value': 10}, {'name': 'B', 'value': 20}])
    assert choose_chart(question, data) == {'type': expected, 'dimension': 'name', 'measures': ['value']}


def test_numeric_month_dimension_and_multiple_measures():
    data = table([{'month': 1, 'sales': 10, 'profit': 2}, {'month': 2, 'sales': 20, 'profit': 3}])
    assert choose_chart('Monthly sales', data) == {'type': 'line', 'dimension': 'month', 'measures': ['sales']}


def test_different_units_never_share_a_default_axis():
    data = table([{'month': '2026-01', 'revenue': 100000, 'orders': 100, 'margin': 0.3},
                  {'month': '2026-02', 'revenue': 200000, 'orders': 200, 'margin': 0.4}])
    assert choose_chart('Monthly sales trend', data)['measures'] == ['revenue']
    assert list(data['rows'][0]) == ['month', 'revenue', 'orders', 'margin']
    shares = table([{'category':'A','sales':100,'share_pct':25}, {'category':'B','sales':300,'share_pct':75}])
    assert choose_chart('Show sales share by category', shares) == {'type':'pie','dimension':'category','measures':['sales']}


@pytest.mark.parametrize('rows', [[], [{'value': 1}], [{'name':'A','value':None},{'name':'B','value':2}],
    [{'name':'A','value':float('inf')},{'name':'B','value':2}],
    [{'name':'A','value':1},{'name':'A','value':2}],
    [{'name':'A','value':'10'},{'name':'B','value':2}],
    [{'store':'A','category':'C','value':1},{'store':'B','category':'D','value':2}],
])
def test_unsafe_or_unsuitable_data_falls_back(rows):
    assert choose_chart('Show chart', table(rows)) is None


def test_validation_rejects_invented_fields_values_and_executable_options():
    data = table([{'name':'A','value':1},{'name':'B','value':2}])
    for candidate in [
        {'type':'bar','dimension':'name','measures':['invented']},
        {'type':'bar','dimension':'name','measures':['value'],'values':[999]},
        {'type':'bar','dimension':'name','measures':['value'],'formatter':'alert(1)'},
        {'type':'scatter','dimension':'name','measures':['value']},
    ]:
        assert validate_chart(candidate, data) is None
    data['rows'][0]['value'] = -1
    assert validate_chart({'type':'pie','dimension':'name','measures':['value']}, data) is None
    assert choose_chart('Share', data)['type'] == 'bar'
    data['rows'][0]['value'] = data['rows'][1]['value'] = 0
    assert choose_chart('Share', data)['type'] == 'bar'


@pytest.mark.parametrize('question,expected', [
    ('Sales by store?',False), ('Compare months',False), ('Explain the change',True),
    ('Why did it change?',True), ('Recommendations?',True), ('What does this mean?',True),
    ('Show data only, without analysis',False), ('Explain, but data only',False), ("Don't analyze it",False),
    ('分析销售变化',True), ('为什么下降？',True), ('有什么建议？',True),
    ('只展示数据，不需要分析',False), ('不要进行分析',False), ('按门店查询销售',False),
])
def test_bilingual_analysis_intent(question, expected):
    assert analysis_requested(question, [{'role':'user','content':'Sales by month'}]) is expected


def test_api_chart_and_analysis_call_count(monkeypatch):
    calls = []
    async def fake(messages, max_tokens=1200):
        calls.append(messages)
        if 'Write a brief business analysis' in messages[0]['content']:
            return 'Query results support a comparison; causes need more evidence.'
        return json.dumps({'kind':'query','answer':'Store totals','sql':'SELECT stores.name AS store, SUM(net_amount) AS revenue FROM sales JOIN stores ON stores.id=sales.store_id GROUP BY stores.name'})
    monkeypatch.setattr(service, 'completion', fake)
    with TestClient(app) as client:
        first = client.post('/api/chat',json={'question':'Sales by store?'}).json()
        assert first['chart']['type'] == 'bar' and first['analysis'] is None and len(calls) == 1
        follow = client.post('/api/chat',json={'question':'Why did it change?', 'history':[{'role':'user','content':'Sales by store?'}]}).json()
        assert follow['analysis'] and len(calls) == 3
        only = client.post('/api/chat',json={'question':'数据即可，不需要分析','language':'zh'}).json()
        assert only['analysis'] is None and len(calls) == 4
        assert 'Simplified Chinese' in calls[-1][0]['content']
