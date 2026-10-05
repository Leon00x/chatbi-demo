# ChatBI practice guide

## Project overview

Lion City ChatBI is a conversational retail analytics project. Users ask questions in natural language; MaaS generates a SQL plan, the backend validates and executes it against a local SQLite database, and the app returns a table with collapsible SQL. Optional business analysis is based on the returned data.

The project uses React, TypeScript, Vite, FastAPI, SQLAlchemy and SQLite. The default scenario is fictional Lion City Retail in Singapore. Data covers January through September 2026, uses SGD, and is synthetic.

The starter already supports querying, tables, SQL inspection, connection checks, bilingual UI and New chat. Charts, model selection and persistent conversation history remain practice tasks.

## Project goal

Continue the starter into a clearer and more useful ChatBI application. You may write the code yourself or use CodeArts Agent. Prompts below are suggestions; adapt them to your own implementation.

## Step 0: Prepare the environment, configure MaaS, then start manually

Use your existing Python and Node.js installations if compatible; you do not need the same versions as the development machine. Python 3.11+ is required by the backend SQLite safety API; the current frontend dependencies need Node.js 20+ and npm.

First prepare the environment from the project root. These scripts create a missing `.env`, create or reuse `.venv`, and install dependencies. They preserve existing configuration and data and do not start the app. Stop development servers before rerunning setup so dependency files are not locked.

Windows PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
```

Linux / macOS:

```bash
bash ./setup.sh
```

Suggested prompt:

> Read README.md and AGENTS.md and prepare this project's environment only. Reuse compatible Python and Node.js installations rather than requiring an exact version. Use setup.ps1 on Windows or setup.sh on Linux/macOS to create a missing backend/.env and virtual environment and install dependencies. Preserve existing configuration and database data. Do not read or print secrets, ask me to paste a token into chat, or commit credentials. Report setup errors clearly. When preparation is complete, tell me to obtain the MaaS token from the Huawei Cloud Console, edit backend/.env myself, and manually start the backend and frontend using the commands in guide.md. Tell me the default app address is http://127.0.0.1:5173/ and API docs are at http://127.0.0.1:8000/docs. Do not start either service or make a MaaS call in this step, and do not implement the later feature tasks.

After setup finishes, get the MaaS API Token or API Key from the [Huawei Cloud Console](https://console.huaweicloud.com/) and confirm the endpoint and model available to your account. Edit `backend/.env` yourself: set `MAAS_API_KEY`, `MAAS_BASE_URL` and `MAAS_MODEL`. Never paste the token into chat or commit it. A separate token acquisition guide may be added later.

Once you have saved `.env`, start the backend manually in one terminal:

Windows PowerShell:

```powershell
cd backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

Linux / macOS:

```bash
cd backend
.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

In another terminal, from the project root:

```bash
cd frontend
npm run dev -- --port 5173 --strictPort
```

Open [http://127.0.0.1:5173/](http://127.0.0.1:5173/). The backend address is [http://127.0.0.1:8000](http://127.0.0.1:8000), and interactive API docs are at [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs). These commands report a port conflict instead of silently changing the address. Startup performs a small MaaS connection check when complete configuration is present. Frontend code updates through Vite; Python code reloads automatically. Restart the backend after `.env` or scenario JSON changes.

Check that the page opens, the connection status is honest, the September store question returns a table, SQL can expand, business analysis works, and New chat clears the current conversation.

## Step 1: Add charts

Add bar, line and pie charts while keeping the table, SQL and analysis. Chart values must come from the current `table.rows`; empty or unsuitable results should keep the table and explain why no chart is shown.

Suggested prompt:

> Read the project docs and add ECharts charts to the existing ChatBI. Extend the `chart: null` extension point with a constrained ChartSpec for bar, line and pie charts. Validate keys and numeric series on the backend, never accept executable JavaScript, HTML or arbitrary chart options, and never let the model invent values. Add a chart option to the English and Chinese UI, keep tables, SQL, analysis and query security, handle empty and unsuitable data safely, release chart instances on unmount, write necessary tests and run the frontend build. Do not read or print .env secrets.

Verify store comparison, monthly trend, category share, empty results, resizing and SQL inspection.

## Step 2: Show and select the model

Display the current MaaS model and allow selection from a backend-provided allowlist. Connection checks, SQL generation and analysis must use the selected model without exposing credentials or changing global configuration.

Suggested prompt:

> Add an accessible Model display and selector to the bilingual UI. Provide an allowlist from the backend with model IDs, labels and a default, never keys. Add an optional model to chat and connection-check requests; reject IDs outside the allowlist. Pass the selected model per request so SQL and analysis use the same model and concurrent sessions do not interfere. Reset connection status after a switch, prevent switching during a request, preserve the choice through New chat, restore the default on refresh, update docs and tests, and keep all query safety rules.

Verify default display, switching, unavailable models, rejected IDs and independent sessions.

## Step 3: Save and switch conversations

The starter New chat clears the current conversation. Add a list, names, switching and browser-local persistence so users can return to earlier analysis without mixing histories or storing secrets.

Suggested prompt:

> Add conversation history to the bilingual ChatBI UI with a list, new conversation, rename and switch actions. Persist conversations in browser local storage, restore them after refresh, keep questions, tables, SQL and analysis, and send only the active conversation's recent history. Prevent in-flight responses from being written to another conversation and handle invalid or unavailable storage. Do not store keys or change query security. Add tests and run the build.

Verify two independent conversations, refresh recovery, SQL inspection and safe switching during a request.

## Validation

```powershell
cd backend
.\.venv\Scripts\python.exe -m pytest -q
cd ../frontend
npm run build
```

Automated tests use simulated MaaS responses. Real queries require the user's own configured token and consume account quota.
