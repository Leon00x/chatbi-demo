# ChatBI portable package guide

## Project overview

Lion City ChatBI lets you ask questions about sample retail data in English or Chinese. MaaS generates SQL; the backend checks it and queries the local database. The starter displays result tables, with SQL available to inspect. Ask for analysis or an explanation in your question when needed.

## Project goal

Continue building ChatBI with charts, model selection, and saved conversations. Implement the tasks yourself or use the optional CodeArts Agent prompts below.

The `main` branch provides the starter. Run it with Step 0, then continue through Steps 1–3 to add the capabilities below.

## Step 0: Prepare the portable environment, configure MaaS, then start manually

### Prepare your environment

Download the development ZIP for Windows x64 or macOS Apple Silicon from [GitHub Releases](https://github.com/Leon00x/chatbi-demo/releases). Extract it and open the extracted `ChatBI` folder in CodeArts Agent. It contains the source code, Python, Node.js, offline dependencies and the example database.

Ask CodeArts Agent to run your platform's regular setup script from the project root. It uses the bundled runtimes and dependencies to create `backend/.venv` and `backend/.env` if needed.

Windows PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
```

macOS:

```bash
bash ./setup.sh
```

### Configure MaaS

Get your MaaS API Token or API Key and an enabled model ID from the [Huawei Cloud Console](https://console.huaweicloud.com/). Edit `backend/.env`:

| Setting | What to enter |
|---|---|
| `MAAS_API_KEY` | Your token or API key |
| `MAAS_BASE_URL` | Defaults to `https://api-ap-southeast-1.modelarts-maas.com/openai/v1` (international site). The China site address is included as a comment in `.env.example`. |
| `MAAS_MODEL` | A model ID enabled for your account; replace the template value if needed |

Keep the token out of chat and Git. This app's configuration is separate from CodeArts Agent's model settings.

If the backend is already running, stop it with `Ctrl+C` and run its startup command again after saving `.env`. The `--reload` option does not reload `.env` changes. Edit `backend/.env` directly; changing `.env.example` does not update an existing `.env`.

### Start the app yourself

Save `.env`, then run the backend from the project root:

Windows PowerShell:

```powershell
cd backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

macOS:

```bash
cd backend
.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

Open another terminal in the project root. Add the bundled Node.js to that terminal's `PATH` before starting Vite.

Windows PowerShell:

```powershell
$env:Path = (Join-Path $PWD.Path 'runtime\node') + [IO.Path]::PathSeparator + $env:Path
cd frontend
npm.cmd run dev -- --port 5173 --strictPort
```

macOS:

```bash
export PATH="$PWD/runtime/node/bin:$PATH"
cd frontend
npm run dev -- --port 5173 --strictPort
```

After both services start, open Vite's `Local:` address. The commands above default to [http://127.0.0.1:5173/](http://127.0.0.1:5173/) for the app and [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs) for API docs. If you change ports, use the addresses printed in your terminals.

If a port is occupied, stop the conflicting service or choose a free port. For a different backend port, update the `/api` proxy in `frontend/vite.config.ts` and restart Vite.

Startup checks MaaS with a small model call. Code changes reload automatically; `.env` and scenario JSON changes require a backend restart. Keep both terminals open while using the app; press `Ctrl+C` to stop each service.

### Check your first query

Confirm `MaaS connected`, then select a suggested question on the page. Expect a result table and expandable SQL. Ask for analysis or an explanation in your question when needed. If connection fails, open the connection status for details.

`New chat` clears the current conversation. Refreshing also clears it until you implement Step 3.

## Step 1: Add charts

Show suitable query results as charts: bar charts for category comparisons and line charts for time trends. Keep the table and SQL available.

You can also use this prompt to let CodeArts Agent implement it:

> Follow AGENTS.md and add ECharts to the existing frontend. Use the returned table rows to draw a bar chart for categories or a line chart for dates/months, sorted chronologically. Plot one numeric measure and keep the full table and SQL accessible. Empty, single-row or unsuitable results remain as tables. Handle chart resizing and cleanup. Keep the implementation small: no extra model calls or general-purpose chart framework. Update the chart feature flag and API docs, then run the project checks.

Expected result: Ask questions directly to see comparisons and trends as charts, with the data table and SQL still available.

## Step 2: Show and select the model

Add a model selector so you can see the current model and choose another before asking a question.

Optional Agent prompt:

> Follow AGENTS.md and add a Model selector to the bilingual UI. Keep `deepseek-v4.1-flash-1017` as the starter default and include `glm-5.3` as a second option without extra setup. Validate model IDs against a backend allowlist and use the selected model for SQL generation, analysis and connection checks.

After implementation, open the app and confirm both models appear. Select `glm-5.3`, run a connection check, and ask a question to confirm the app still returns a result. Both models need to be enabled for the configured MaaS account.

## Step 3: Save and switch conversations

Add a conversation list so you can name conversations, switch between them and return to earlier results after refreshing the browser.

Optional Agent prompt:

> Following AGENTS.md, add a conversation list with new, rename and switch actions. Save questions, tables, SQL and analysis in browser local storage and restore them on refresh. Send only the active conversation's recent history. Keep in-flight responses in their original conversation and handle invalid or unavailable storage. Never store credentials. Run the checks required by AGENTS.md.

Expected result: Create, name and switch conversations, then return to them after refreshing the page.
