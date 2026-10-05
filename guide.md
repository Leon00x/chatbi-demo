# ChatBI practice guide

## Project overview

Lion City ChatBI is a conversational retail analytics project. Users ask questions in natural language; MaaS generates a SQL plan, the backend validates and executes it against a local SQLite database, and the app returns a table with collapsible SQL. Optional business analysis is based on the returned data.

The project uses React, TypeScript, Vite, FastAPI, SQLAlchemy and SQLite. The default scenario is fictional Lion City Retail in Singapore. Data covers January through September 2026, uses SGD, and is synthetic.

The starter already supports querying, tables, SQL inspection, connection checks, bilingual UI and New chat. Charts, model selection and persistent conversation history remain practice tasks.

## Project goal

Continue the starter into a clearer and more useful ChatBI application. You may write the code yourself or use CodeArts Agent. Prompts below are suggestions; adapt them to your own implementation.

## Step 0: Initialize and verify the starter

Install dependencies, configure MaaS and run the frontend and backend. Get the MaaS API Token or API Key from the [Huawei Cloud Console](https://console.huaweicloud.com/). Confirm the account has access to the selected model and endpoint. Put the values in `backend/.env` as `MAAS_API_KEY`, `MAAS_BASE_URL` and `MAAS_MODEL`; never paste a real token into chat or commit it. A separate token acquisition guide may be added later.

Read README.md for platform-specific commands. For Windows development, run the backend with `--reload`; frontend changes update through Vite, while `.env` and scenario changes require a backend restart.

Suggested prompt:

> Read README.md, AGENTS.md, docs/architecture.md and docs/api.md. Help initialize and start this ChatBI project. Check Python and Node.js, install dependencies, create backend/.env only when it does not exist, and preserve existing configuration and data. Explain that the MaaS token must be obtained from the Huawei Cloud Console. Do not ask me to paste the token, read or print secrets, or commit them. Start both services, check the page and health endpoint, run backend tests and the frontend build, and report failures honestly. Only verify the starter; do not implement charts, model selection or conversation history.

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
