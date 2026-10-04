# 项目编码约定

这是 CodeArts Agent 的 ChatBI 演示起点。先阅读 README.md、guide.md 和 docs/architecture.md。

- 基础查询、表格、SQL 折叠、MaaS 连接状态必须持续可用。
- 只有用户要求开发时才实现 guide.md 的图表任务；初始项目的 chart 必须为 null。
- 不读取或输出 `.env` 的密钥；不将密钥写入源码、日志、前端 bundle、测试快照。
- 新功能通过稳定的 `/api/chat` 契约扩展；业务信息来自 scenario 文件，避免把门店名、货币和日期硬编码进图表组件。
- 用户输入和模型输出都不可信；保留 SQL AST 校验、SQLite authorizer、只读连接、行数上限和执行超时。
- 图表数据来自本次 SQL 查询结果，不允许模型自行编造数据或返回可执行 JavaScript/HTML。
- 场景种子只初始化空数据库，不自动删除或覆盖已有数据库。新场景使用独立数据库文件。
- 前后端分离，保持当前栈，不引入额外服务。不要为图表任务重写项目。
- 完成后运行 backend pytest 和 frontend npm run build，并报告修改文件、验证结果及尚未验证的事项。
- 本目录上层 sources/ 如存在，均为只读参考，不得改动。
