import json
import os
from pathlib import Path
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / '.env')
SCENARIO_ID = os.getenv('SCENARIO', 'sg-retail')
if not SCENARIO_ID.replace('-', '').isalnum():
    raise ValueError('Invalid SCENARIO')
SCENARIO = json.loads((ROOT / 'scenarios' / f'{SCENARIO_ID}.json').read_text(encoding='utf-8'))
BASE_URL = os.getenv('MAAS_BASE_URL', '').rstrip('/')
API_KEY = os.getenv('MAAS_API_KEY', '')
MODEL = os.getenv('MAAS_MODEL', '')
DATABASE_URL = os.getenv('DATABASE_URL', 'sqlite:///./data/retail.db')
# Relative SQLite URLs are always resolved against backend, regardless of cwd.
if DATABASE_URL.startswith('sqlite:///./'):
    DATABASE_URL = 'sqlite:///' + (ROOT / DATABASE_URL.removeprefix('sqlite:///./')).as_posix()
CORS_ORIGINS = os.getenv('CORS_ORIGINS', 'http://localhost:5173,http://127.0.0.1:5173').split(',')
