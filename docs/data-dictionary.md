# 数据字典：新加坡零售

虚构企业 Lion City Retail，4家门店、8种商品；日期范围2026-01-01至2026-09-30。数据不代表真实企业经营情况。

| 表 | 粒度 | 字段 |
|---|---|---|
| stores | 每门店一行 | id，name，region |
| products | 每商品一行 | id，name，category，price，unit_cost |
| sales | 每订单商品行 | id，order_id，sale_date，store_id，product_id，channel，quantity，net_amount，cost_amount |

sales.store_id → stores.id；sales.product_id → products.id。门店 Orchard/Tampines/Jurong East/Woodlands，渠道 In-store/Online。sale_date 用 YYYY-MM-DD 表示新加坡本地业务日期。

net_amount 是当前订单行折扣后销售额，cost_amount 是该行成本；均为SGD。订单可能多个商品行，订单数用 COUNT(DISTINCT order_id)，不能 COUNT(*)。毛利率是总毛利除以总销售额，不能简单平均每行比率；客单价是总销售额除以去重订单数。GST不单独建模，不自动额外扣税或加税。

种子包含周末客流变化和9月Tampines增量、食品饮料折扣，以便观察趋势。业务分析应区分从查询可见的事实与其他原因猜测。详细生成规则见 backend/app/database.py，指标定义见scenario文件。
