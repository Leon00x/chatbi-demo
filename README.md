# Lion City ChatBI

ChatBI is a starter project for demonstrating Huawei Cloud CodeArts Agent. It provides an English-first, bilingual conversational analytics UI for a fictional Singapore retailer. Users ask questions in natural language; MaaS generates a read-only SQL plan, the backend validates and executes it against SQLite, and the frontend shows the result table and collapsible SQL.

The starter includes query chat, tables, SQL inspection, optional analysis, connection checks, bilingual UI and synthetic data. Chart rendering, model selection and persistent conversations are intentionally left as guided development tasks in [guide.md](guide.md).

## Stack and requirements

React + Vite + TypeScript + Tailwind CSS frontend; FastAPI + SQLAlchemy + SQLite backend; OpenAI-compatible MaaS Chat Completions API. Use your existing Python and Node.js installations if they support the project; no exact release is required. Python 3.11+ is needed for the SQLite safety API, and the current frontend dependencies need Node.js 20+ with npm.

## Step 0: Start locally

First follow [Step 0 in guide.md](guide.md#step-0-prepare-the-environment-configure-maas-then-start-manually): prepare the environment, edit `.env` yourself, and then start manually. Obtain a MaaS API Token or API Key from the [Huawei Cloud Console](https://console.huaweicloud.com/), confirm the model and endpoint available to your account, and keep the token only in the backend `.env`. A separate token guide may be added later.

Run the setup script from the project root. It creates `backend/.env` only if missing, creates or reuses `backend/.venv`, and installs backend and frontend dependencies. It does not start services or change existing credentials or database data. Stop running development servers before rerunning setup, as Windows may lock dependency files in use.

Windows PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
```

Linux / macOS:

```bash
bash ./setup.sh
```

If you need to choose a Python executable when creating a new environment, pass `-Python "C:\path\to\python.exe"` to `setup.ps1`, or run `PYTHON=python3.12 bash ./setup.sh`. Existing virtual environments are reused. If a command reports incompatibility, use a compatible installed runtime; matching the development machine's exact version is unnecessary.

Next, edit `backend/.env` yourself with `MAAS_BASE_URL`, `MAAS_API_KEY` and `MAAS_MODEL`. Then start the backend manually in one terminal:

Windows:

```powershell
cd backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

Linux / macOS:

```bash
cd backend
.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

Start the frontend manually in another terminal, from the project root:

```powershell
cd frontend
npm run dev -- --port 5173 --strictPort
```

Open the app at [http://127.0.0.1:5173/](http://127.0.0.1:5173/). The backend is at [http://127.0.0.1:8000](http://127.0.0.1:8000), with API docs at [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs). If a port is occupied, stop the conflicting service before retrying. Vite updates frontend code automatically; backend `--reload` restarts after Python changes. Restart the backend after editing `.env` or scenario JSON.

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
setup.ps1          Windows environment setup (does not start services)
setup.sh           Linux / macOS environment setup (does not start services)
```

This is a local demo without login, tenant isolation or production access control. It binds to loopback by default. Non-SQLite URLs are rejected.
