# Lion City ChatBI

ChatBI is a starter project for demonstrating Huawei Cloud CodeArts Agent. It provides an English-first, bilingual conversational analytics UI for a fictional Singapore retailer. Users ask questions in natural language; MaaS generates a read-only SQL plan, the backend validates and executes it against SQLite, and the frontend shows the result table and collapsible SQL.

The starter includes query chat, tables, SQL inspection, optional analysis, connection checks, bilingual UI and synthetic data. Chart rendering, model selection and persistent conversations are intentionally left as guided development tasks in [guide.md](guide.md).

## Stack and requirements

React + Vite + TypeScript + Tailwind CSS frontend; FastAPI + SQLAlchemy + SQLite backend; OpenAI-compatible MaaS API. Use any compatible Python 3.11+ and Node.js 20+ installation with npm.

## Step 0: Start locally

Prepare the environment, configure MaaS, then start manually. [Step 0 in guide.md](guide.md#step-0-prepare-the-environment-configure-maas-then-start-manually) also provides an optional Agent prompt.

Run setup from the project root. It prepares `.env`, `.venv` and dependencies without starting services or overwriting existing configuration and data. Stop development servers before rerunning it.

Windows PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
```

Linux / macOS:

```bash
bash ./setup.sh
```

To choose Python for a new environment, pass `-Python "C:\path\to\python.exe"` to `setup.ps1`, or run `PYTHON=python3.12 bash ./setup.sh`. Existing virtual environments are reused.

Get your token, endpoint and enabled model from the [Huawei Cloud Console](https://console.huaweicloud.com/). Set `MAAS_BASE_URL`, `MAAS_API_KEY` and `MAAS_MODEL` in `backend/.env`, then start the backend:

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

After both services start, open Vite's `Local:` address. Defaults are [http://127.0.0.1:5173/](http://127.0.0.1:5173/) for the app and [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs) for API docs. Use the actual terminal output if you change ports.

If a port is occupied, stop the conflicting service or choose a free port. A different backend port requires updating the `/api` proxy in `frontend/vite.config.ts` and restarting Vite. Keep both terminals open; use `Ctrl+C` to stop services. Code changes reload automatically, but `.env` and scenario JSON changes require a backend restart.

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

## Documentation

Start with this README to run the app, then follow guide.md for the practice tasks. Before changing code, read AGENTS.md, the architecture and the API contract.

| Document | Purpose |
|---|---|
| [README.md](README.md) | Project overview, setup and startup |
| [guide.md](guide.md) | Setup, default charts and question-based analysis, model selection and saved conversations |
| [AGENTS.md](AGENTS.md) | Development conventions and safety requirements |
| [docs/architecture.md](docs/architecture.md) | Components, query flow and extension boundaries |
| [docs/api.md](docs/api.md) | API endpoints, requests and responses |
| [docs/data-dictionary.md](docs/data-dictionary.md) | Demo tables, data scope and metric definitions |
| [docs/demo-script.md](docs/demo-script.md) | Suggested walkthrough and example questions |
| [docs/verification.md](docs/verification.md) | Completed checks and known limitations |

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
