"""Offline data checks; requires only Python standard library."""
import json
import sqlite3
from pathlib import Path

db = Path(__file__).parent / 'data/retail.db'
with sqlite3.connect(db.as_uri() + '?mode=ro', uri=True) as conn:
    assert conn.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
    assert conn.execute('PRAGMA foreign_key_check').fetchall() == []
    assert conn.execute('SELECT COUNT(*) FROM stores').fetchone()[0] == 4
    assert conn.execute('SELECT COUNT(*) FROM products').fetchone()[0] == 8
    lines, orders, start, end = conn.execute('SELECT COUNT(*), COUNT(DISTINCT order_id), MIN(sale_date), MAX(sale_date) FROM sales').fetchone()
    assert lines > orders > 10000
    assert (start,end) == ('2026-01-01','2026-09-30')
    print(json.dumps({'lines':lines,'orders':orders,'date_range':[start,end],'integrity':'ok'},indent=2))
