# Project conventions

This repository is the ChatBI demo starter. Read README.md, guide.md and docs/architecture.md before making changes.

- Keep query, table, collapsible SQL and MaaS connection status working.
- The starter keeps `chart: null`; implement chart work only when the user asks for it.
- Never read or print `.env` secrets. Never put keys in source, logs, frontend bundles or snapshots.
- Extend the stable `/api/chat` contract. Scenario files provide business content; do not hard-code stores, currency or dates in chart components.
- Treat user input and model output as untrusted. Keep SQL AST validation, the SQLite authorizer, read-only connections, row limits and execution timeouts.
- Charts must use the current SQL result, never model-invented values or executable JavaScript/HTML.
- Seed only an empty database and never overwrite existing scenario data. New scenarios use separate database files.
- Keep the frontend and backend separate and use the existing stack.
- After changes, run backend pytest and `npm run build` and report files, validation and remaining limitations.
- Treat any `sources/` directory above this project as read-only.
