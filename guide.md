# ChatBI practice guide

## Project overview

Lion City ChatBI lets you ask questions about sample retail data in English or Chinese. MaaS generates SQL; the backend checks it and queries the local database. The starter displays result tables, with SQL available to inspect. Ask for analysis or an explanation in your question when needed.

## Project goal

Continue building ChatBI with charts, model selection, and saved conversations. Implement the tasks yourself or use the optional CodeArts Agent prompts below.

This workshop kit contains the starter. Run it with Step 0, then continue through Steps 1–3 to add the capabilities below.

## Step 0: Prepare the environment, configure MaaS, then start manually

### Prepare your environment

Download the kit for your **System type** in Windows **Settings → System → About**. Choose the x64 ZIP for an x64-based processor or the ARM64 ZIP for an ARM-based processor. Use **Extract All** and open PowerShell in the extracted project root (the folder containing `setup.ps1`). In CodeArts, open that same folder as your project.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 -LocalOnly
```

Wait for `Setup complete. No services were started.` The script uses the bundled Python, Node.js and dependencies. It checks the kit, creates `backend\.venv` and prepares `backend\.env` from the template if needed. Existing configuration and data are preserved. Stop both servers before rerunning setup. If you move the project folder after setup, run the following from its new location.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1 -LocalOnly -Repair
```

For the pre-class check, you can start both services and open the home page with the default configuration. Complete the MaaS setup before trying a question.

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

In the first PowerShell terminal, start the backend from the project root.

```powershell
Set-Location .\backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

Open a second PowerShell terminal in the project root. Use the bundled Node.js in this terminal and start the frontend.

```powershell
Set-Location .\frontend
$env:Path = "$(Resolve-Path ..\.offline\node);$env:Path"
npm.cmd run dev -- --port 5173 --strictPort
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
