# ChatBI practice guide

## Project overview

Lion City ChatBI lets you ask retail data questions in natural language. It queries a local SQLite database through MaaS and returns tables, collapsible SQL and optional business analysis.

The project uses React, TypeScript, Vite, FastAPI, SQLAlchemy and SQLite. The default scenario is fictional Lion City Retail in Singapore. Data covers January through September 2026, uses SGD, and is synthetic.

The app supports English and Chinese, connection checks and New chat. The tasks below add charts, model selection and saved conversations.

## Project goal

Extend the app through the tasks below. Implement them yourself or use the optional CodeArts Agent prompts. When using Agent, have it follow AGENTS.md and the project documentation.

## Step 0: Prepare the environment, configure MaaS, then start manually

Use Python 3.11+ and Node.js 20+ with npm. Any compatible version is fine.

### Prepare your environment

In the project root (the folder containing README.md), run the command for your operating system. The script prepares `.env`, `.venv` and dependencies without starting the app or overwriting existing configuration and data. Stop development servers before rerunning it.

Windows PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
```

Linux / macOS:

```bash
bash ./setup.sh
```

Or use this prompt to let CodeArts Agent prepare the environment:

> Read README.md and AGENTS.md, then run the setup script for my operating system using compatible installed Python and Node.js versions. Preserve existing configuration and data; do not read or expose secrets. Report any setup errors. Stop after environment preparation and show me how to configure backend/.env and start both services manually, using the actual addresses printed at startup.

### Configure MaaS

Get your MaaS API Token or API Key, endpoint and enabled model from the [Huawei Cloud Console](https://console.huaweicloud.com/). Set `MAAS_API_KEY`, `MAAS_BASE_URL` and `MAAS_MODEL` in `backend/.env`. Keep the token out of chat and Git. This app's configuration is separate from CodeArts Agent's model settings.

If the backend is already running, stop it with `Ctrl+C` and run its startup command again after saving `.env`. The `--reload` option does not reload `.env` changes. Edit `backend/.env` directly; changing `.env.example` does not update an existing `.env`.

### Start the app yourself

Save `.env`, then run the backend from the project root:

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

After both services start, open Vite's `Local:` address. The commands above default to [http://127.0.0.1:5173/](http://127.0.0.1:5173/) for the app and [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs) for API docs. If you change ports, use the addresses printed in your terminals.

If a port is occupied, stop the conflicting service or choose a free port. For a different backend port, update the `/api` proxy in `frontend/vite.config.ts` and restart Vite.

Startup checks MaaS with a small model call. Code changes reload automatically; `.env` and scenario JSON changes require a backend restart. Keep both terminals open while using the app; press `Ctrl+C` to stop each service.

### Check your first query

Confirm `MaaS connected`, then ask `What were sales by store in September 2026?`. Expect four stores and expandable SQL. In the starter, enable `Include business analysis` for analysis; Step 1 replaces this checkbox with question-based analysis. Use `New chat` to clear the conversation. If connection fails, follow the displayed error message.

## Step 1: Show charts by default and analyze when asked

Present suitable query results as charts by default, with a way to view the table and SQL. Choose bar charts for comparisons, line charts for trends and pie charts for suitable shares. Add business analysis when the question asks for it, including follow-up questions, rather than requiring checkboxes.

Optional Agent prompt:

> Following AGENTS.md, make this bilingual ChatBI show suitable query results as ECharts charts by default, without a Generate chart checkbox. Choose bar, line or pie from the question and data, and honor a requested chart type when suitable. Keep the table and collapsible SQL accessible; use a table or single-value result for empty or unsuitable chart data. Replace the Include business analysis checkbox with backend intent detection in English and Chinese: generate analysis when the user asks for analysis, interpretation, recommendations or an explanation of changes, including follow-up questions. Simple data requests need only a brief result description, without an extra analysis call; honor requests for data only. Base analysis on query results and distinguish supported facts from hypotheses. Extend chart: null with a validated ChartSpec using table.rows, never invented values or executable options. Support resizing and disposal. Update the API docs and test default charts, analysis intent and graceful fallback, then run the checks in the Validation section.

Verify without selecting any chart or analysis checkbox:

- `What were sales by store in September 2026?` → a bar chart and brief description, with the table and SQL accessible.
- `How did monthly sales trend in 2026?` → a line chart.
- `Show sales share by category in September 2026.` → a pie chart when the values are suitable.
- `Compare August and September 2026 sales and explain the change.` → a chart and data-based analysis.
- `Why did it change?` → follow-up analysis based on the relevant query results, without invented causes.
- `Show the data only, without analysis.` → data without an extra analysis call.
- An empty result, single value or unsuitable data → a clear fallback without a fabricated chart.

Repeat in Chinese and check resizing, table access and SQL inspection.

## Step 2: Show and select the model

Display the current MaaS model and allow selection from a backend-provided allowlist. Connection checks, SQL generation and analysis must use the selected model without exposing credentials or changing global configuration.

Optional Agent prompt:

> Following AGENTS.md, add a Model selector to the bilingual UI using a backend allowlist. Pass the selected model to chat and connection checks per request; SQL and analysis must use the same model. Reject unknown IDs. Reset connection status on switching and disable switching during requests. Preserve the choice through New chat and restore the default on refresh. Update the API docs and run the checks in the Validation section.

Verify default display, switching, unavailable models, rejected IDs and independent sessions.

## Step 3: Save and switch conversations

The starter New chat clears the current conversation. Add a list, names, switching and browser-local persistence so users can return to earlier analysis without mixing histories or storing secrets.

Optional Agent prompt:

> Following AGENTS.md, add a conversation list with new, rename and switch actions. Save questions, tables, SQL and analysis in browser local storage and restore them on refresh. Send only the active conversation's recent history. Keep in-flight responses in their original conversation and handle invalid or unavailable storage. Never store credentials. Run the checks in the Validation section.

Verify two independent conversations, refresh recovery, SQL inspection and safe switching during a request.

## Validation

After each feature task, run these commands from the project root. On Windows:

```powershell
cd backend
.\.venv\Scripts\python.exe -m pytest -q
cd ../frontend
npm run build
```

On Linux / macOS:

```bash
cd backend
.venv/bin/python -m pytest -q
cd ../frontend
npm run build
```

Automated tests use simulated MaaS responses. Real queries require the user's own configured token and consume account quota.
