# API contract

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/health` | Backend and MaaS status, configured model and feature flags |
| POST | `/api/connection/check` | Makes a short real model call; never returns the key |
| GET | `/api/scenario` | Public scenario information and suggestions |
| POST | `/api/chat` | Natural-language query or clarification |

## Chat request

```json
{"question":"What were sales by store in September 2026?","history":[],"language":"en"}
```

`language` is `en` by default and may be `zh`. History accepts user and assistant messages, up to 12 items and 3000 characters each. Questions are limited to 2000 characters.

Simple English/Chinese keywords such as analysis, explain, why, 分析 or 建议 request analysis when the query returns rows. Explicit data-only or no-analysis wording suppresses it. This is a lightweight rule, so unfamiliar wording may not be recognized. There is no analysis checkbox or request flag.

## Chat response

| Field | Meaning |
|---|---|
| `kind` | `query`, `message` or `clarify` |
| `answer` | Query scope, a short message or a clarification question |
| `sql` | Validated SQL, or `null` for a non-query response |
| `table` | `columns`, `rows`, `row_count` and `truncated`, or `null` |
| `chart` | Always `null` in the starter; available for future chart metadata |
| `analysis` | Generated analysis text, or `null` |
| `warnings` | Messages about truncation or failed analysis; otherwise `[]` |

`message` and `clarify` responses include `sql`, `table`, `chart` and `analysis` as `null`. Tables contain at most 200 rows; `truncated` indicates additional rows were omitted. An analysis failure preserves the successful query result and adds a warning.

## Errors

Chat returns HTTP 503 for MaaS failures and HTTP 422 for invalid requests or unsafe/invalid query plans. Service errors use `detail: {code, message}`; request validation errors may use FastAPI's standard validation format. Upstream response bodies and credentials are not exposed.

`/api/connection/check` returns a status object with `state` and `message`, including failed connection states, rather than using chat's error format. Interactive endpoint schemas are available at `/docs` on the running backend.
