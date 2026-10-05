# API contract

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/health` | Backend and MaaS status, configured model and feature flags |
| POST | `/api/connection/check` | Makes a short real model call; never returns the key |
| GET | `/api/scenario` | Public scenario information and suggestions |
| POST | `/api/chat` | Natural-language query or clarification |

Chat request:

```json
{"question":"What were sales by store in September 2026?","history":[],"language":"en"}
```

`language` is `en` by default and may be `zh`. History accepts user and assistant messages, up to 12 items and 3000 characters each. Questions are limited to 2000 characters.

Analysis intent is inferred from English/Chinese question text, including follow-ups. Ask for analysis, interpretation, recommendations or an explanation to request it; explicit data-only requests suppress it. The former `analyze` property is no longer used (extra fields are ignored for older clients). Simple data requests make no extra analysis call.

`chart` is either `null` or a constrained object, for example `{"type":"bar","dimension":"store","measures":["revenue"]}`. Type is `bar`, `line` or `pie`; dimension and up to four measures must be existing table columns. Default selection plots only the first numeric measure because the result has no trusted unit metadata; all other measures stay in the table, avoiding incompatible units on one axis. All values come from `table.rows`. Empty/single-row results, duplicate or missing labels, mixed/nonfinite measures and ambiguous dimensions fall back to a table. Pies require one nonnegative measure, a positive finite total and at most twelve rows; unsuitable shares fall back to a bar when possible. The chart contains no values, HTML, JavaScript or executable options. `/api/health` reports `features.charts: true`.

Chat responses contain `kind`, `answer`, `sql`, `table`, `analysis`, `chart` and `warnings`. `kind` is `query`, `message` or `clarify`; the latter two omit SQL and table. Tables contain at most 200 rows. MaaS errors return HTTP 503 and invalid plans return HTTP 422 without exposing upstream response bodies.
