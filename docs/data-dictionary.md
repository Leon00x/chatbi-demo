# Data dictionary

The default scenario is fictional Lion City Retail in Singapore. Currency is SGD and dates cover 2026-01-01 through 2026-09-30. All rows are synthetic.

| Table | Grain and purpose |
|---|---|
| `stores` | One row per store, including name and region |
| `products` | One row per product, category, list price and unit cost |
| `sales` | One order line with date, store, product, channel, quantity, net amount and cost |

Metric definitions:

- Sales: `SUM(sales.net_amount)` after discounts.
- Orders: `COUNT(DISTINCT sales.order_id)`.
- Gross profit: sales minus cost.
- Gross margin: total gross profit divided by total sales.
- Average order value: total sales divided by distinct orders.
- GST is not modeled or added automatically.
