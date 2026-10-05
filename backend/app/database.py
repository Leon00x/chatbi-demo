import random
import sqlite3
import time
from datetime import date, timedelta
from pathlib import Path
from sqlalchemy import create_engine, inspect, text
from sqlglot import parse, exp
from .config import DATABASE_URL, SCENARIO

if not DATABASE_URL.startswith('sqlite:///'):
    raise ValueError('The starter supports SQLite only. A cloud adapter must add equivalent read-only permissions and timeouts.')
Path(DATABASE_URL.removeprefix('sqlite:///')).parent.mkdir(parents=True, exist_ok=True)
engine = create_engine(DATABASE_URL)
MAX_ROWS = 200

def seed_database():
    """Initialize an empty DB; never overwrite existing data."""
    tables = inspect(engine).get_table_names()
    if tables:
        if not set(SCENARIO['tables']).issubset(tables):
            raise ValueError('The database does not match this scenario. Set a new DATABASE_URL for a new scenario.')
        return
    seed = SCENARIO['seed']
    if seed['kind'] != 'retail-v1':
        raise ValueError('This scenario requires a new seed adapter.')
    rng = random.Random(seed['random_seed'])
    with engine.begin() as conn:
        conn.exec_driver_sql('CREATE TABLE stores (id INTEGER PRIMARY KEY, name TEXT NOT NULL, region TEXT NOT NULL)')
        conn.exec_driver_sql('CREATE TABLE products (id INTEGER PRIMARY KEY, name TEXT NOT NULL, category TEXT NOT NULL, price REAL NOT NULL, unit_cost REAL NOT NULL)')
        conn.exec_driver_sql('CREATE TABLE sales (id INTEGER PRIMARY KEY, order_id TEXT NOT NULL, sale_date TEXT NOT NULL, store_id INTEGER NOT NULL REFERENCES stores(id), product_id INTEGER NOT NULL REFERENCES products(id), channel TEXT NOT NULL, quantity INTEGER NOT NULL, net_amount REAL NOT NULL, cost_amount REAL NOT NULL)')
        conn.exec_driver_sql('CREATE INDEX idx_sales_date ON sales(sale_date)')
        conn.exec_driver_sql('INSERT INTO stores VALUES (?,?,?)', [tuple(s) for s in seed['stores']])
        conn.exec_driver_sql('INSERT INTO products VALUES (?,?,?,?,?)', [tuple(p) for p in seed['products']])
        rows = []
        start, end = map(date.fromisoformat, SCENARIO['date_range'])
        for d in range((end-start).days+1):
            day = start + timedelta(days=d)
            for store in seed['stores']:
                volume = rng.randint(8, 16) + (5 if day.weekday() >= 5 else 0)
                # A visible September promotion; inference must remain grounded in data.
                if day.month == 9 and store[0] == 2:
                    volume += 6
                for o in range(volume):
                    order = f'{day.isoformat()}-{store[0]}-{o}'
                    channel = rng.choice(['In-store', 'Online'])
                    for product in rng.sample(seed['products'], rng.randint(1, 3)):
                        quantity = rng.randint(1, 3)
                        discount = 0.88 if day.month == 9 and product[2] == 'Food & Beverage' else 1
                        rows.append((len(rows)+1, order, day.isoformat(), store[0], product[0], channel, quantity, round(product[3]*quantity*discount,2), round(product[4]*quantity,2)))
        conn.exec_driver_sql('INSERT INTO sales VALUES (?,?,?,?,?,?,?,?,?)', rows)

def schema_text():
    inspector = inspect(engine)
    return '\n'.join(f"{table}: " + ', '.join(f"{c['name']} {c['type']}" for c in inspector.get_columns(table)) for table in SCENARIO['tables'])

def validate_sql(sql: str):
    statements = parse(sql, read='sqlite')
    if len(statements) != 1 or not isinstance(statements[0], exp.Query):
        raise ValueError('Only one SELECT query is allowed.')
    tree = statements[0]
    forbidden = (exp.Insert, exp.Update, exp.Delete, exp.Create, exp.Drop, exp.Command, exp.Into)
    if any(isinstance(node, forbidden) for node in tree.walk()):
        raise ValueError('Database changes are not allowed.')
    ctes = {cte.alias_or_name.lower() for cte in tree.find_all(exp.CTE)}
    for table in tree.find_all(exp.Table):
        if table.db or table.catalog or table.name.lower() not in set(SCENARIO['tables']) | ctes:
            raise ValueError('The query contains an unauthorized table.')
    return tree.sql(dialect='sqlite')

def query_database(sql: str):
    validated = validate_sql(sql)
    # A dedicated DBAPI connection prevents authorizer state leaking across requests.
    db_path = engine.url.database
    conn = sqlite3.connect(Path(db_path).as_uri() + '?mode=ro', uri=True)
    allowed_actions = {sqlite3.SQLITE_SELECT, sqlite3.SQLITE_READ, sqlite3.SQLITE_FUNCTION, sqlite3.SQLITE_RECURSIVE}
    allowed_tables = set(SCENARIO['tables'])
    allowed_functions = {'count','sum','avg','min','max','total','round','abs','nullif','coalesce','ifnull','iif','strftime','date','datetime','julianday','unixepoch','time','substr','substring','length','lower','upper','trim','ltrim','rtrim','replace','instr','printf','format','cast','row_number','rank','dense_rank','lag','lead','first_value','last_value','nth_value','ntile','cume_dist','percent_rank'}
    def authorize(action, arg1, arg2, db, source):
        if action not in allowed_actions:
            return sqlite3.SQLITE_DENY
        # SQLite reports db=None for COUNT(*) reads with an empty column name.
        if action == sqlite3.SQLITE_READ and (arg1 not in allowed_tables or db not in {None, 'main'}):
            return sqlite3.SQLITE_DENY
        if action == sqlite3.SQLITE_FUNCTION and str(arg2).lower() not in allowed_functions:
            return sqlite3.SQLITE_DENY
        return sqlite3.SQLITE_OK
    deadline = time.monotonic() + 3
    conn.setlimit(sqlite3.SQLITE_LIMIT_LENGTH, 1_000_000)
    conn.setlimit(sqlite3.SQLITE_LIMIT_SQL_LENGTH, 50_000)
    conn.set_authorizer(authorize)
    conn.set_progress_handler(lambda: int(time.monotonic() > deadline), 1000)
    try:
        cursor = conn.execute(validated)
        columns = [d[0] for d in cursor.description]
        # Reject ambiguous aliases rather than silently losing duplicate columns.
        if len(set(columns)) != len(columns):
            raise ValueError('Result column names must be unique aliases.')
        rows = cursor.fetchmany(MAX_ROWS + 1)
        return {'sql': validated, 'columns': columns, 'rows': [dict(zip(columns, row)) for row in rows[:MAX_ROWS]], 'truncated': len(rows) > MAX_ROWS, 'row_count': min(len(rows), MAX_ROWS)}
    finally:
        conn.close()
