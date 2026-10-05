# Verification record

The project has been checked locally with the current dependency set.

- Backend pytest: 22 tests pass, with one dependency deprecation warning.
- Frontend: TypeScript checking and Vite production build pass.
- The seeded database contains four stores, eight products, 14,755 distinct orders and 29,337 order lines.
- Read-only query checks cover writes, system tables, large functions, empty results and the 200-row limit.
- The frontend build covers the English default and Chinese toggle; repeat browser checks after changing local configuration.
- Real MaaS verification depends on the user's configured endpoint, token and model. Those values are never stored in this repository.
- A Windows temporary SQLite file cleanup warning may appear after pytest; it does not change the test result.
