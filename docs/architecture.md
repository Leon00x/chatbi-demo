# Architecture and boundaries

The React SPA calls FastAPI through `/api`. Vite proxies local development requests to `127.0.0.1:8000`. MaaS credentials stay in the backend environment.

The request path is: `ChatRequest` → question and history → MaaS query plan → JSON parsing → SQL AST validation → table allowlist → SQLite authorizer and read-only connection → at most 200 rows → optional MaaS analysis → `ChatResult`.

The starter is non-streaming. History lives in browser memory and at most six turns are sent to the backend. The chart extension point is `chart`; the starter always returns `null`.

The database is seeded only when empty. Existing data is never overwritten. Non-SQLite URLs are rejected. A future cloud adapter must provide an equivalent read-only user, timeout, dialect and table allowlist.

The app has no login, tenant isolation or production access control and binds to loopback by default.
