# API 契约

| 方法 | 路径 | 用途 |
|---|---|---|
| GET | /api/health | 后端状态、MaaS最近检测状态、模型名、features.charts=false |
| POST | /api/connection/check | 实际短模型调用，返回state/message，不返回key |
| GET | /api/scenario | 公开场景信息、指标口径、推荐问题 |
| POST | /api/chat | 自然语言查询或澄清回复 |

请求：

```json
{"question":"2026年9月各门店销售额是多少？","history":[],"analyze":false}
```

history 支持 user/assistant，最多12条，每条最多3000字符。question 1–2000字符。

响应示意（数值只是契约示例，不代表seed查询结果）：

```json
{
  "kind":"query",
  "answer":"按门店汇总2026年9月销售额，单位SGD。",
  "sql":"SELECT s.name AS store_name, ROUND(SUM(x.net_amount),2) AS revenue FROM sales x JOIN stores s ON s.id=x.store_id WHERE x.sale_date >= '2026-09-01' AND x.sale_date < '2026-10-01' GROUP BY s.name",
  "table":{"columns":["store_name","revenue"],"rows":[{"store_name":"Orchard","revenue":100}],"row_count":1,"truncated":false},
  "analysis":null,
  "chart":null,
  "warnings":[]
}
```

kind 为 query/message/clarify；后两种没有sql/table。表格最多200行；空结果rows=[]。MaaS错误HTTP503，非法查询/计划HTTP422，detail中提供可读message。不返回上游原始错误体，避免泄漏配置。查询成功但分析失败保留结果并给出warnings。
