# API contract

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/health` | Backend and MaaS status, configured model and feature flags |
| POST | `/api/connection/check` | Makes a short real model call; never returns the key |
| GET | `/api/scenario` | Public scenario information and suggestions |
| POST | `/api/chat` | Natural-language query or clarification |

Chat request:

```json
{"question":"What were sales by store in September 2026?","history":[],"analyze":false,"language":"en"}
```

`language` is `en` by default and may be `zh`. History accepts user and assistant messages, up to 12 items and 3000 characters each. Questions are limited to 2000 characters.

Chat responses contain `kind`, `answer`, `sql`, `table`, `analysis`, `chart` and `warnings`. `kind` is `query`, `message` or `clarify`; the latter two omit SQL and table. Tables contain at most 200 rows. MaaS errors return HTTP 503 and invalid plans return HTTP 422 without exposing upstream response bodies.
