# ChatBI practice guide

## Project overview

Lion City ChatBI lets you ask questions about sample retail data in English or Chinese. MaaS generates SQL; the backend checks it and queries the local database. The starter displays result tables, with SQL available to inspect. Analysis is available through the Include business analysis checkbox.

## Project goal

Continue building ChatBI with default charts and analysis, model selection, and saved conversations. Implement the tasks yourself or use the optional CodeArts Agent prompts below.

The `main` branch provides the starter. Run it with Step 0, then continue through Steps 1–3 to add the capabilities below.

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

> Read README.md and AGENTS.md, then run the setup script for my operating system using compatible installed Python and Node.js versions. Preserve existing configuration and data; do not read or expose secrets. Report any setup errors. Stop after environment preparation. Explain which backend/.env values I should edit and give the manual startup commands. Tell me to open the address printed by Vite after I start the services.

### Configure MaaS

Get your MaaS API Token or API Key and an enabled model ID from the [Huawei Cloud Console](https://console.huaweicloud.com/). Edit `backend/.env`:

| Setting | What to enter |
|---|---|
| `MAAS_API_KEY` | Your token or API key |
| `MAAS_BASE_URL` | Defaults to `https://api.modelarts-maas.com/openai/v1`; change it if your service uses another endpoint |
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

Confirm `MaaS connected`, then select a suggested question on the page. Expect a result table and expandable SQL. Select Include business analysis when you want analysis; Step 1 replaces this checkbox with question-based analysis. If connection fails, open the connection status for details.

`New chat` clears the current conversation. Refreshing also clears it until you implement Step 3.

## Step 1: Show charts by default and analyze when asked

Present suitable query results as charts by default, with a way to view the table and SQL. Choose bar charts for comparisons, line charts for trends and pie charts for suitable shares. Add business analysis when the question asks for it, including follow-up questions, rather than requiring checkboxes.

Optional Agent prompt:

> Follow AGENTS.md and implement only Step 1 using the existing stack.
>
> Show ECharts by default: bar for comparisons, line for time trends (in chronological order), and pie for nonnegative shares with a positive total. Honor a requested type when suitable. Use one category/time column and the first numeric measure; keep other measures in the table to avoid mixing units. Empty, single-row or unsuitable results stay as tables. Keep the table and SQL expandable. Return a validated chart object with only type, dimension and measures referencing table.rows; never invent values or accept executable chart options. Handle resize and disposal.
>
> Remove the analysis checkbox. Use simple backend rules for English/Chinese requests for analysis, explanations or recommendations, including follow-ups. Simple queries and explicit “data only” or “no analysis” requests make no extra analysis call. Keep prior question/SQL scope for follow-ups, then query again; analyze fresh results and separate facts from possible causes. Do not add a classifier model call, an agent framework or new services.
>
> Update the API docs and run the checks required by AGENTS.md. Leave Steps 2 and 3 unchanged.

Expected result: Ask questions directly to see suitable charts. Request an explanation when needed, and expand the table or SQL for details.

## Step 2: Show and select the model

Add a model selector so you can see the current model and choose another available model before asking a question.

Optional Agent prompt:

> Following AGENTS.md, add a Model selector to the bilingual UI using a backend allowlist. Pass the selected model to chat and connection checks per request; SQL and analysis must use the same model. Reject unknown IDs. Reset connection status on switching and disable switching during requests. Preserve the choice through New chat and restore the default on refresh. Update the API docs and run the checks required by AGENTS.md.

Expected result: See the current model and choose another available model for subsequent queries.

## Step 3: Save and switch conversations

Add a conversation list so you can name conversations, switch between them and return to earlier results after refreshing the browser.

Optional Agent prompt:

> Following AGENTS.md, add a conversation list with new, rename and switch actions. Save questions, tables, SQL and analysis in browser local storage and restore them on refresh. Send only the active conversation's recent history. Keep in-flight responses in their original conversation and handle invalid or unavailable storage. Never store credentials. Run the checks required by AGENTS.md.

Expected result: Create, name and switch conversations, then return to them after refreshing the page.
