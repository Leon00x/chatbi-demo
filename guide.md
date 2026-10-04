# ChatBI 实践指南

## 项目介绍

Lion City ChatBI 是一个面向零售数据的对话式分析项目。你可以用自然语言提问，应用通过 MaaS 模型生成 SQL，查询本地 SQLite 数据库，并返回数据表格和可展开的 SQL。勾选 `Include business analysis` 后，还可以生成基于查询结果的业务分析。

项目采用 React + TypeScript 前端和 FastAPI 后端，默认场景是虚构的新加坡零售企业 Lion City Retail。演示数据覆盖 2026 年 1–9 月，金额单位为 SGD，全部为合成数据。

当前已支持基础问数、表格、SQL 折叠、连接检测和 `New chat`。图表、页面模型选择以及可保存和切换的会话历史，需要继续完成。

## 本项目目标

在现有基础上，继续完成一个更直观、更易用的 ChatBI 应用。下面的步骤依次增加图表、模型选择和会话历史能力。

你可以自行编写代码，也可以使用 CodeArts Agent 协助完成。每一步的提示词仅供参考，可以按自己的实现方式调整。完成后，用同样的业务问题检查新增能力与原有功能。

## Step 0：初始化项目并跑通基础问数

### 要完成什么

准备 Python 3.11+ 和 Node.js 22.12+，安装前后端依赖、配置 MaaS，并启动应用。你可以按下面的命令自行操作，也可以使用参考提示词让 CodeArts Agent 协助。

先前往 [华为云控制台](https://console.huaweicloud.com/) 的 MaaS 服务获取 API Token / API Key，并确认账户已开通的模型及对应调用地址。将 Token 填入后端 `MAAS_API_KEY`，调用地址填入 `MAAS_BASE_URL`，模型名填入 `MAAS_MODEL`。具体获取步骤后续会补充独立指导文档，当前请以控制台提供的信息为准。不要把真实 Token 贴入聊天或提交到仓库。

应用与 CodeArts Agent 的模型配置相互独立，需要分别配置。

以下以 Windows PowerShell 为例，从项目根目录执行。仅在 `.env` 尚不存在时复制模板，避免覆盖已有配置：

```powershell
cd backend
if (!(Test-Path .env)) { Copy-Item .env.example .env }
# 在编辑器中填写 MaaS 地址、Token 和模型名
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

另开终端，从项目根目录启动前端：

```powershell
cd frontend
npm install
npm run dev
```

打开 [ChatBI 页面](http://127.0.0.1:5173/)。已有合成数据库会保留；数据库文件不存在时，首次启动会自动初始化。前端开发服务会自动更新页面；后端使用 `--reload`，修改 Python 代码后自动重启。修改 `.env` 或场景 JSON 后仍需手动重启后端。其他系统及 uv 启动方式见 [README.md](README.md)。

### 可参考的提示词

> 阅读 README.md、AGENTS.md、docs/architecture.md 和 docs/api.md，协助初始化并启动当前 ChatBI 基础项目。检查 Python 和 Node.js 环境，安装前后端依赖；仅在后端 .env 不存在时从 .env.example 创建，保留已有配置和数据库。告诉我需要从华为云控制台获取 MaaS API Token，并自行在后端 .env 中填写 MAAS_BASE_URL、MAAS_API_KEY 和 MAAS_MODEL，不要求我把 Token 发到聊天，不读取、输出或提交密钥。配置完成后启动前后端，后端使用 uvicorn --reload 开启 Python 代码自动重载，说明 .env 和场景 JSON 修改后仍需手动重启，检查页面和健康接口，通过真实短请求验证 MaaS 连接并说明检测会消耗少量配额。运行后端 pytest 和前端构建，如有失败如实报告。此步骤只跑通基础问数，不提前实现图表、模型选择或会话历史。

### 完成后检查

- 页面可打开，显示 `MaaS connected`；缺少或无效 Token 时显示明确配置或鉴权提示。
- 提问 `What were sales by store in September 2026?`：返回四家门店的数据表格，SQL 默认收起且可展开。
- 勾选 `Include business analysis` 再提问：能返回基于数据的分析。
- 点击 `New chat`：清空当前对话，开始新的提问。

## Step 1：增加图表展示

### 要完成什么

让查询结果除了表格，还能展示柱状图、折线图和饼图。门店比较用柱状图，月度趋势用折线图，品类占比用饼图。图表与表格使用同一份查询数据，并保留 SQL 和业务分析。

### 可参考的提示词

> 阅读 README.md、AGENTS.md、docs/architecture.md、docs/api.md 和 guide.md，为现有 ChatBI 增加图表能力，使用 ECharts 支持柱状图、折线图和饼图。在英文页面增加生成图表选项，并支持用户明确提出的画图请求。后端目前返回 chart: null，请将其扩展为受限的 ChartSpec，只描述图表类型、标题、维度、数值系列和单位；图表数值始终来自本次 table.rows，不让模型编造数据，不接受可执行 JavaScript、HTML 或任意 ECharts option。校验字段与数值类型，空结果、单值或不适合绘图时保留表格并给出提示。前端做好尺寸自适应和实例释放，图表失败不能影响表格、SQL 折叠和分析。保留现有 SQL AST 校验、只读连接、表白名单、行数上限和执行超时，不读取或输出 .env 密钥。先说明实现计划，再完成代码、必要测试与前端构建，更新相关文档。

### 完成后检查

- 问 `Show sales by store in September 2026 as a bar chart.`：显示四家门店，数值与表格一致，单位为 SGD。
- 问 `Show monthly sales in 2026 as a line chart.`：按 1–9 月顺序显示。
- 问 `Show the sales share by category in September 2026 as a pie chart.`：占比与表格一致。
- 查询 2027 年数据：显示空结果，不生成虚构图表。
- 调整窗口大小，展开 SQL 并继续追问：原有功能正常。

## Step 2：显示与选择模型

### 要完成什么

在页面显示当前模型，并允许从已配置的模型列表中选择。连接检测、SQL 生成和业务分析都应使用所选模型，让你可以比较不同模型的效果。

### 可参考的提示词

> 阅读项目说明和接口文档，在当前英文页面增加 Model 显示和下拉选择器。候选模型由后端允许列表提供，默认包含现有 MAAS_MODEL；只返回模型 ID、显示名称与默认值，不返回密钥，候选列表也不能被当作账户权限已验证的证明。为聊天和连接检测增加可选 model 参数，省略时使用默认模型，后端拒绝列表以外的 ID。通过请求传递模型选择，不修改全局默认值或 .env；同一次请求的 SQL 生成和分析使用同一模型，不同页面的选择互不影响。切换后重置连接状态，只有对所选模型实际调用成功才能显示已连接，旧检测结果不能覆盖新选择。查询中禁用切换；New chat 保留选择，刷新恢复默认模型。使用英文提示处理模型未开通、鉴权、配额和网络错误，保留已有聊天和只读查询安全边界。不读取或输出 .env 密钥。完成代码、必要测试、前端构建，并更新接口文档与配置模板。

### 完成后检查

- 打开页面：显示默认模型，候选项与后端配置一致。
- 切换模型并提问、勾选分析：检测、查询和分析使用所选模型。
- 模型不可用：显示明确错误，不显示虚假的连接成功。
- 两个页面选择不同模型：互不影响；提交未允许的模型 ID 时，后端拒绝。

## Step 3：保存与切换会话

### 要完成什么

当前 `New chat` 能清空对话，但刷新后历史会消失。增加会话列表、命名、切换和本地保存，让你可以返回之前的分析。

### 可参考的提示词

> 为现有 ChatBI 增加会话历史，在英文页面提供会话列表、新建、命名和切换能力。使用浏览器本地存储保存会话，刷新后恢复，保留提问、表格、SQL 和分析。新会话不能携带其他会话的上下文，后端仍只接收当前会话最近六轮历史。请求进行中避免切换导致结果写入错误会话，处理存储不可用或数据损坏并给出可读提示。不保存密钥，不改动已有查询安全边界。完成必要测试和前端构建，更新使用说明。

### 完成后检查

- 新建两个会话，分别提问，切换后能看到各自的内容。
- 新会话的追问不会引用上一会话的数据。
- 刷新后能恢复已保存的会话，SQL 和表格仍可查看。

## 完成验证

每一步完成后，从项目目录运行：

```powershell
cd backend
.\.venv\Scripts\python.exe -m pytest -q
cd ../frontend
npm run build
```

自动测试和构建通过后，再在页面验证实际 MaaS 调用。模型调用会消耗账户配额；自动测试使用模拟响应，不消耗真实模型配额。

## 还可以尝试什么

更换零售场景：复制 backend/scenarios/sg-retail.json，修改企业、门店、商品、示例问题和指标，设置新的 SCENARIO 与独立数据库路径。同类型零售场景可以复用现有数据生成器；已有数据库不会自动被新场景覆盖。

跨行业场景或云数据库接入需要新的数据结构、适配器和相应验证，可作为进一步练习。
