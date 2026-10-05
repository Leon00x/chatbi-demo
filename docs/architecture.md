# Architecture

## Components

```text
Local machine                                  Huawei Cloud
+---------------------------------------+      +-----------------------+
| Browser: React UI                     |      | MaaS                  |
| Chat, tables, SQL, optional analysis   |      | SQL planning          |
+-------------------+-------------------+      | Optional analysis     |
                    | /api                    | Connection checks     |
+-------------------v-------------------+      +-----------^-----------+
| Vite development server               |                  |
| Serves UI; proxies /api to FastAPI    |                  | HTTPS
+-------------------+-------------------+                  |
                    |                                     |
+-------------------v-------------------+                  |
| FastAPI backend                       |                  |
| Query service + MaaS client           +------------------+
| SQL validation + read-only execution  |
| Optional result-based analysis        |
+-----------+-------------------^-------+
            | query             | rows
+-----------v-------------------+-------+
| SQLite: synthetic scenario data       |
+---------------------------------------+

Backend inputs: .env (endpoint, key, model, database path)
                Scenario JSON (data scope, metrics, seed configuration)
```

Only the backend calls MaaS and accesses SQLite. Vite provides the local development proxy; production hosting is outside this demo's scope.

## Query flow

1. The UI sends the question, language and recent conversation context to `/api/chat`.
2. MaaS returns a query plan, a clarification question or a short message.
3. For a query, the backend validates the SQL and executes it through a read-only SQLite connection. Table/function allowlists, execution limits and a 200-row cap apply.
4. If the request sets `analyze: true` and rows are available, the backend makes an additional MaaS analysis call using the query result.
5. The UI displays the result table, expandable SQL, and any analysis or warnings.

The starter always returns `chart: null`. Step 1 adds chart rendering and replaces the analysis checkbox with question-based intent detection; these are not implemented on main.

Responses are non-streaming. Conversation history lives in browser memory; the UI sends up to six previous turns containing questions and response text. Follow-up query plans are validated and executed again. Clarifications and non-query messages do not execute SQL. Analysis is controlled by the request flag, not inferred from the question.

## Data and configuration

The backend loads `.env` and scenario JSON at startup; restart it after editing either. A connection check makes a small MaaS request. Credentials are never sent to the frontend.

Startup seeds a database only when it has no tables. Existing tables must match the scenario; existing data is preserved. The current implementation supports SQLite and the included retail schema. Scenario JSON supplies seed values and business context, but a different industry schema also requires changes to the seed routine, query prompt and relevant UI text.

This is a local demo without authentication or tenant isolation. A future database adapter needs equivalent read-only permissions, query limits and SQL validation.

## Code map

| File | Responsibility |
|---|---|
| `backend/app/main.py` | Endpoints, request validation and startup |
| `backend/app/config.py` | Environment and scenario loading |
| `backend/app/maas.py` | Model requests and connection errors |
| `backend/app/service.py` | Query planning and result-based analysis |
| `backend/app/database.py` | Seed data, SQL validation and read-only execution |
| `frontend/src/main.tsx` | Conversation UI, language and request state |

See the [API contract](api.md) for request/response details, the [data dictionary](data-dictionary.md) for metrics, and [AGENTS.md](../AGENTS.md) for development rules. The [README](../README.md#documentation) lists all documents.
