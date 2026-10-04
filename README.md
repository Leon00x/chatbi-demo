# Lion City ChatBI · CodeArts Agent Demo

用于演示华为云 CodeArts Agent 编码能力的基础项目。默认是虚构的新加坡零售企业，货币 SGD。React + Vite + TypeScript + Tailwind 前端，FastAPI + SQLAlchemy + SQLite 后端，通过 MaaS 的 OpenAI-compatible Chat Completions API 生成 SQL。

## 基础版与演示任务

已实现：聊天界面、自然语言查库、结果表格、SQL 折叠框、多轮问题上下文、勾选式业务分析、MaaS 实际连接检测、可替换场景文件、可复现数据生成。

后续实践任务包括图表展示、模型选择和会话历史，你可以自行实现或使用 CodeArts Agent 协助。基础返回 `chart: null`。项目初始化和各步参考提示词见 [guide.md](guide.md)。

## 启动

首次使用可先按 [guide.md 的 Step 0](guide.md#step-0初始化项目并跑通基础问数) 初始化项目，那里也提供了可选参考提示词。

要求 Python 3.11+、Node.js 22.12+（本项目验证环境为 Node 24）。以下命令从项目根目录执行。

后端，Windows PowerShell：

```powershell
cd backend
if (!(Test-Path .env)) { Copy-Item .env.example .env }
# 编辑 .env，填写自己的 MaaS endpoint、key、已开通的模型名
uv venv --python 3.11
uv pip install -r requirements.txt
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

也可使用 Python 原生 venv：`python -m venv .venv`，再 `.venv\Scripts\python.exe -m pip install -r requirements.txt`。uv 未安装时采用此方式。

macOS / Linux：

```bash
cd backend
[ -f .env ] || cp .env.example .env
# 编辑 .env
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

前端另开终端：

```bash
cd frontend
npm install
npm run dev
```

打开 http://localhost:5173 。后端 API 文档：http://127.0.0.1:8000/docs 。交付包附带 `backend/data/retail.db` 合成数据库；文件不存在时首次启动自动初始化。已有数据不会被覆盖。

开发时前端由 Vite 自动更新页面，后端 `--reload` 会在 Python 代码修改后自动重启。`.env` 和场景 JSON 修改后仍需手动重启后端。

## 配置与连接检测

前往 [华为云控制台](https://console.huaweicloud.com/) 的 MaaS 服务获取 API Token / API Key，确认已开通模型与对应调用地址。Token 填入后端 `MAAS_API_KEY`，地址与模型分别填入 `MAAS_BASE_URL`、`MAAS_MODEL`。具体获取步骤后续补充独立指导文档；当前以控制台信息为准，不要将真实 Token 发到聊天或提交到仓库。

`.env.example` 只含占位 key，项目没有预置任何真实密钥。前端不读取 `.env`，不接触 key。修改后端 `.env` 后必须重启后端。

启动时，如存在完整配置，后端发起一次短模型请求验证端点、key 和模型是否可用；前端展示检测结果。点击 `Check again`再次执行实际调用，会产生少量 token 消耗。状态涵盖缺少 key、鉴权失败、端点/模型异常、限流、超时和网络错误。配置检查不等同于验证 key；只有调用成功才显示 `MaaS connected`。模型名须与账户开通的名称一致。

默认所有相对日期以演示数据截止日 2026-09-30 为基准；提问时推荐写明年月，避免真实日期与演示数据日期混淆。

## 验证

```powershell
cd backend
.\.venv\Scripts\python.exe -m pytest -q
cd ../frontend
npm run build
```

测试使用临时 SQLite 与模拟 MaaS 响应，不消费真实 API 配额。真实模型端到端验证需填写自己的 key，然后使用 guide.md 的演示问题。

不安装依赖也可验证附带数据库：`python backend/verify_data.py`。本次环境已完成的检查及未验证事项见 docs/verification.md。

## 文件结构

```text
backend/app/          配置、API、MaaS、查询服务、数据库安全边界
backend/scenarios/    企业场景、业务指标、示例问题、seed 输入
backend/tests/        查询安全与 API 契约测试
frontend/src/        界面、API 客户端、类型、图表扩展点
guide.md             CodeArts Agent 图表开发任务与验收
AGENTS.md            编码约定
docs/                架构、API、数据字典与演示脚本
```

此版本面向本机演示，没有登录、租户隔离或生产访问控制。默认绑定 loopback；云数据库仅保留适配设计，基础版未实现，不能只改 URL 就直接连接云库。
