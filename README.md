# Lion City ChatBI

ChatBI is a starter project for demonstrating Huawei Cloud CodeArts Agent. It provides an English-first, bilingual conversational analytics UI for a fictional Singapore retailer. Users ask questions in natural language; MaaS generates a read-only SQL plan, the backend validates and executes it against SQLite, and the frontend shows the result table and collapsible SQL.

The starter includes query chat, tables, SQL inspection, optional analysis, connection checks, bilingual UI and synthetic data. Chart rendering, model selection and persistent conversations are intentionally left as guided development tasks in [guide.md](guide.md).

## Stack and requirements

React + Vite + TypeScript + Tailwind CSS frontend; FastAPI + SQLAlchemy + SQLite backend; OpenAI-compatible MaaS Chat Completions API. Use Python 3.11+ and Node.js 22.12+.

## Step 0: Start locally

First read [Step 0 in guide.md](guide.md#step-0-initialize-and-verify-the-starter). Obtain a MaaS API Token or API Key from the [Huawei Cloud Console](https://console.huaweicloud.com/), confirm the model and endpoint available to your account, and keep the token only in the backend `.env`. A separate token guide may be added later.

Windows PowerShell backend:

```powershell
cd backend
if (!(Test-Path .env)) { Copy-Item .env.example .env }
# Edit .env with MAAS_BASE_URL, MAAS_API_KEY and MAAS_MODEL
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

Frontend in another terminal:

```powershell
cd frontend
npm install
npm run dev
```

Open http://127.0.0.1:5173 and the API docs at http://127.0.0.1:8000/docs. Vite updates frontend code automatically; backend `--reload` restarts after Python changes. Restart the backend after editing `.env` or scenario JSON.

For macOS or Linux, use `python3 -m venv .venv`, `.venv/bin/pip install -r requirements.txt`, `.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload`, then run the frontend commands above.

The bundled SQLite database is synthetic. If the database does not exist, startup initializes it; existing data is never overwritten. The default scenario covers four stores, eight products, and January–September 2026 in SGD.

## MaaS connection

The frontend never reads `.env`. At startup the backend makes a short real request when complete configuration is present. Only a successful call is shown as `MaaS connected`. Missing keys, authentication errors, endpoint or model errors, rate limits, timeouts and network errors are reported separately. A manual connection check consumes a small amount of model quota.

## Validation

```powershell
cd backend
.\.venv\Scripts\python.exe -m pytest -q
cd ../frontend
npm run build
```

Tests use temporary SQLite databases and simulated MaaS responses. Real end-to-end queries require the user's own token. See [docs/verification.md](docs/verification.md) for the current local verification record.

## Repository layout

```text
backend/app/       configuration, API, MaaS, query service and database safety
backend/scenarios/ scenario definitions and seed data
backend/tests/     query security and API contract tests
frontend/src/      UI, API client, types and styling
docs/              architecture, API, data dictionary, demo script and verification
guide.md           CodeArts Agent practice tasks
AGENTS.md          project conventions
```

This is a local demo without login, tenant isolation or production access control. It binds to loopback by default. Non-SQLite URLs are rejected.
