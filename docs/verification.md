# Verification record

The project has been checked locally with the current dependency set.

- Backend pytest: 53 tests pass, with one dependency deprecation warning.
- Frontend: TypeScript checking and Vite production build pass.
- The seeded database contains four stores, eight products, 14,755 distinct orders and 29,337 order lines.
- Read-only query checks cover writes, system tables, large functions, empty results and the 200-row limit.
- The frontend build covers the English default and Chinese toggle; repeat browser checks after changing local configuration.
- Real MaaS verification depends on the user's configured endpoint, token and model. Those values are never stored in this repository.
- Test teardown disposes the SQLite engine before deleting temporary files; no Windows file cleanup warning was observed.
- Step 1 tests cover default/requested chart types, constrained metadata, unsafe and unsuitable values, bilingual analysis intent, follow-ups and model call counts. Browser rendering and real MaaS queries still require interactive validation.

## Environment setup scripts

- `setup.ps1` was run successfully on Windows with an existing virtual environment. It installed dependencies, preserved the existing `.env` (verified by hash), and did not start services.
- `setup.sh` passes Bash syntax validation. A full Linux/macOS dependency installation has not been verified on this Windows machine.
- Setup and manual startup are separate. README.md and guide.md include platform commands and the default frontend and API addresses.
