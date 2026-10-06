# Project conventions

This is the ChatBI demo starter on main; Steps 1–3 are development tasks. Read README.md, guide.md and docs/architecture.md before making changes. Keep user-facing documentation in English and distinguish implemented features from practice tasks.

- Keep query, table, collapsible SQL and MaaS connection status working.
- The starter returns `chart: null`. Analysis uses simple question keywords; Step 1 adds frontend charts from the existing table data.
- Never read or print `.env` secrets. Never put keys in source, logs, frontend bundles or snapshots.
- Extend the stable `/api/chat` contract. Scenario files provide business content; do not hard-code stores, currency or dates in chart components.
- Treat user input and model output as untrusted. Keep SQL AST validation, the SQLite authorizer, read-only connections, row limits and execution timeouts.
- Charts must use the current SQL result, never model-invented values or executable JavaScript/HTML.
- Seed only an empty database and never overwrite existing scenario data. New scenarios use separate database files.
- Keep the frontend and backend separate and use the existing stack. Prefer small, direct changes; avoid new frameworks, generic adapters and speculative edge-case handling.
- After code changes, run backend pytest and `npm run build`; report validation and remaining limitations. For documentation-only edits, check accuracy, links and `git diff --check`.
- Treat any `sources/` directory above this project as read-only.

## Development checks

From `backend`, run `.venv\Scripts\python.exe -m pytest -q` on Windows or `.venv/bin/python -m pytest -q` on Linux/macOS. From `frontend`, run `npm run build`.

Tests use temporary SQLite databases and simulated MaaS responses. `backend/verify_data.py` is an optional offline integrity check for the bundled retail database. Real MaaS queries use the configured account and consume quota.
