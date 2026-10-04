# CodeArts Agent 实战：为 ChatBI 增加图表

## 目标与准备

客户拿到的初始项目已经可以“自然语言 → SQL → SQLite → 表格”，并可生成业务分析。现场用 CodeArts Agent 将表格升级为可视化，展示阅读项目、规划、修改前后端、验证和修复的能力。

1. 解压项目，先阅读 README.md 并跑通基础版。
2. 为 CodeArts Agent 配置可用模型。应用后端 `.env` 也需要配置 MaaS endpoint、key 和 model；两个配置独立，可以使用同一账户允许的 key，但 Agent 配置不会自动传给应用。
3. 打开页面，确认 MaaS 实际调用成功，再问“2026年9月各门店销售额是多少？”。确认显示表格且 SQL 默认折叠。
4. 不把真实 key 贴入提示词；让 Agent 使用现有 `.env`，不要读取或输出内容。

## 第一轮：让 Agent 规划

复制此提示词：

> 阅读 README.md、AGENTS.md、docs/architecture.md、docs/api.md 和本 guide.md。理解查询链路和已有 UI。我要在现有 ChatBI 中增加图表功能：支持柱状图、折线图和饼图，使用 ECharts。先给出涉及文件与实现计划，然后完成代码、依赖安装、测试与构建。保留表格、SQL 折叠、按需分析和 MaaS 检测。不要读取或输出 .env 密钥。

## 第二轮：实现约束

基础版后端目前返回 `chart: null`，前端类型位于 `frontend/src/types.ts`。请扩展为 `ChartSpec | null`，例如：

```json
{
  "type": "bar",
  "title": "2026年9月各门店销售额",
  "x_key": "store_name",
  "series": [{"key": "revenue", "label": "销售额"}],
  "unit": "SGD"
}
```

ChartSpec 只描述展示结构，数据始终取自 `table.rows`；不要重复生成图表数值。折线适合时间趋势，柱状图适合类别比较；饼图只用于非负、有明确总量、类别数适合的占比。单数值、空结果、没有数值列等情况返回 null。不适合请求的图表类型时说明原因并保留表格。

建议实现步骤：

1. 后端定义 Pydantic ChartSpec，类型只允许 line/bar/pie，校验 x_key 和 series.key 均存在于本次查询列中，数值列类型正确；禁止任意 ECharts option、JavaScript 和 HTML。
2. 增加请求参数 `visualize: bool = false`，页面提供“生成图表”选项；用户明确要求画图时也可识别意图。
3. 服务在查询成功后依据真实结果生成和校验 ChartSpec。可采用规则或模型规划，失败退化为 `chart: null` 并给出 warning。
4. 新建 `ChartRenderer.tsx`，安装 ECharts，按受限 ChartSpec 转换成 option，使用现有 table.rows。支持 resize，组件卸载 dispose。展示单位，不把销量等所有数值都标为 SGD。
5. 在回复中保留表格与折叠 SQL，可增加“图表 / 数据”切换。图表失败不能导致整条回复消失。
6. 写必要测试，运行 pytest、TypeScript 检查与生产构建；如失败，定位并修复。

## 验收

| 问题/操作 | 预期 |
|---|---|
| 2026年9月各门店销售额，画柱状图 | 4个门店；数值与表格完全一致；单位SGD |
| 2026年每个月销售额，画折线图 | 1–9月按日期顺序展示，不能按字母排序 |
| 2026年9月各品类销售额占比，画饼图 | 非负占比；总量与表格一致 |
| 比较2026年8月和9月销售额，并分析 | 表格和分析仍可用，日期口径明确 |
| 查询2027年门店销售额 | 空结果提示，无虚构图表 |
| 单个总销售额、包含null或非法数值的数据 | 稳健退化或合适的展示，不崩溃 |
| 查看SQL、连续提问、窄屏、刷新、调整窗口大小 | 原功能可用；图表不溢出，实例不泄漏 |
| 删除数据库、读取sqlite_master的用户请求 | 只读安全边界保持有效 |
| key 缺失或失效 | 仍显示配置/鉴权错误；不会显示伪造成功 |

## 可选后续任务：换场景

同类型零售企业可以修改 `backend/scenarios/sg-retail.json` 中的企业名、门店、商品、数据日期和示例问题；复制为新 ID，设置 `SCENARIO` 并指定新数据库路径。同一数据模型的种子生成器可复用。

如换成银行、物流或制造业，须新增场景文件、schema/seed 适配器与指标定义，更新 Text-to-SQL 语义和测试。不要把 retail-v1 数据假装成其他行业。云库适配是另一个可选任务，需要实际账户、驱动、只读数据库用户、超时和等效表白名单约束，当前版本未实现。
