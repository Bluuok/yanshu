# 研枢与 OpenScience 接口契约 V1

版本：2026-11-10；状态：待实测的接口约定。产品目标已确定为 Ubuntu 实验室工作站运行、Windows 客户端访问，并对 OpenScience 前端进行较大幅度改造；首周需固定 runtime/SDK 匹配版本。**是否深度 Fork、如何接入前端和远程访问方式尚未定稿**。

官方依据：[OpenScience Runtime SDK and API](https://github.com/synthetic-sciences/openscience/blob/main/frontend/docs/src/content/openscience/api.mdx)、[Headless server hosting](https://github.com/synthetic-sciences/openscience/blob/main/frontend/docs/src/content/openscience/server-hosting.mdx)。

## 1. 职责

研枢负责项目数据授权、科研任务、检查点、确认流程、证据关系、材料规则与独立审查。OpenScience 负责 Research Agent 执行、模型/工具、会话、运行回执及自身权限。V1 优先 SDK、HTTP 和 SSE；没有官方依据时不另造 Webhook，也不自建第二套 Agent 循环。

| 研枢业务接口草案 | 预期作用 |
|---|---|
| POST /api/tasks | 验证授权和输入，缺材料时允许直接登记 WAITING_FOR_DATA |
| POST /api/tasks/{id}/start | 保存请求 ID 后调用 OpenScience |
| GET /api/tasks/{id} | 返回业务状态、外部尝试与结果摘要 |
| POST /api/tasks/{id}/submit-data | 补齐资料并校验版本 |
| POST /api/tasks/{id}/confirm | 对有权限且仍有效的确认进行回复 |
| POST /api/tasks/{id}/reconcile | 检查中断回执、作业及文件副作用 |
| POST /api/tasks/{id}/retry | 未终态任务经安全核对可建新 attempt；FAILED 须新建关联业务任务 |
| GET /api/tasks/{id}/evidence | 按项目授权返回证据关联 |

此表是研枢拟实现接口，不表示已在 OpenScience 中存在相同路径。

## 2. 下发及观察

1. 检查 /runtime/capabilities 及协议支持。用固定版本的 TS 或 Python SDK，不因提交失败而盲目回退旧 API。
2. 为每个执行登记 os_session_id、os_request_id 和输入内容哈希。请求实际被接纳后补存 os_run_id；首次调用前持久化原始请求的完整标识。
3. 202 或 accepted 只代表接纳，不代表科研工作完成。观察 Snapshot、SSE 事件和最终回执；事件游标失效后重取 Snapshot 并按事件序号去重。
4. 只有授权研究者可以审批当前有效的 approval_requests。请求绑定 task_id、attempt_id、os_pending_request_id、task_version、plan_version_id、权限 scope 和有效期，decision_operation_id 防止重复提交。处理 live permission/question 前必须从最新 Snapshot 重新确认请求仍存在，调用 runtime.decide 后单独记录 OpenScience 决定回执。旧快照、越权、重复点击或已撤销的审批不得继续执行。服务进程重启后，不沿用已失效的旧授权上下文。
5. 完成后核对 resultMessageID、Results、compute jobs 及研枢证据记录，再决定业务是否 COMPLETED。

## 3. Session 工作区选择与受控文件映射

OpenScience 官方 session.create 默认建立 isolated scratch 工作区。只有显式选择 workspace: "project"，工具中的相对路径才以连接选择的项目目录为基准。模式在 session 创建后固定，不能在后续 prompt 中直接切换。官方参考：[Session workspaces](https://github.com/synthetic-sciences/openscience/blob/main/frontend/docs/src/content/openscience/sessions.mdx)。

**V1 首选 project 模式，每个 attempt 使用独立的受限工作区，不把原始资料归档目录直接设为 project。**

1. 研枢在源文件归档中保存不可变原件，给本次 attempt 创建专属工作区，包含只读 input、可写 output 与文件映射清单 manifest。受控副本或实际只读挂载来自获授权的 source_id；manifest 保存源文件 SHA256、复制后 SHA256、实际工具可访问路径和权限。
2. SDK 的 directory 指向此 attempt 的工作区，创建 session 时显式 workspace: "project"。一个 attempt 保存 os_session_id、workspace_mode、workspace_path、manifest 及 output 目录。Python 工具只通过该工作区的受控路径访问文件，不得访问原始归档或其他项目目录。
3. 实际隔离由受限进程账号、操作系统 ACL 或经测试的沙箱实现。同一操作系统账户仍可随意写 input 时，不得宣称只读安全。输出先保存到本 attempt 的暂存区，校验哈希和业务结果后才原子提交，不能覆盖其他 attempt 的产物。

**备选 isolated 模式，仅在验证附件可达后启用。** 如果使用默认 isolated scratch，会话所见附件不一定等于 Python 工具可打开的文件。必须实测附件输入的实际文件位置、访问权限和哈希，并记录到 manifest；若工具找不到数据，应修正映射，不得临时放宽原始数据权限。两种模式须在创建 session 时择一，不能在运行中隐式混用。

## 4. 文件与权限

原始输入目录必须由实际文件系统 ACL、受限账号或隔离工作区强制只读；仅在 Prompt 写“read-only”不构成安全隔离。单个 attempt 的输出有唯一目录，先校验 SHA256 和科学结果，再原子提交；失败不覆盖原始文件与已确认产物。

当前 OpenScience 的项目目录选择不等于多租户授权。官方说明已登录实例可能默认分享完整会话轨迹，Day 1 必须核对设备/账户设置与实际数据外发路径。未经授权的实验室未发表资料不能发送到外部模型或遥测服务。

## 5. 远程工作台和可观测性边界

1. OpenScience 后端和科研计算默认部署在 Ubuntu 工作站；Windows 客户端须能经获授权的浏览器或工作台入口访问，不要求 Windows 主机负责运行 Agent。明确使用者身份、网络暴露范围、传输加密、密钥保存和会话权限，不允许为了远程访问公开未加保护的 Runtime API。
2. 因主运行底座优先采用 OpenScience，其前端会进行导航、视觉、交互和甘特图改造。现有组件、插件、源码修改的工程比例通过实测与《开发实施方案》决定，不能从产品目标推断必须重写 Agent 内核。
3. 运行观测先复用 OpenScience 记录；如使用 Langfuse/OTel，必须保证 Task/Attempt/Session/Run ID 正确关联、敏感输入不泄露、观测故障不影响科研任务。见 [可观测性与第三方能力接入](06-可观测性与第三方能力接入规范.md)。
4. 不把 OpenScience 的工具权限确认等同于研枢对重要科研决策的审批。普通已授权计算可自动执行；研究方向、重要实验条件变更及权限/数据外发范围扩大必须请求有效的人工审批。

## 6. G2 验收

至 Day 5，需在 Ubuntu 工作站上验证一次真实模型调用，且 Windows 客户端能按授权范围访问研枢工作台；还须验证一次 Python 工具调用、结果保存、SSE 重连、请求与运行 ID 存储、任务中断后的核对、输入目录不可写、权限审批及费用记录。必须记录选择的 session workspace 模式、实际 input/output 路径与 manifest；让工具主动尝试写入 input，须由操作系统拒绝，同时 output 可以写入、原始数据 SHA256 不变；审批的过期、重复点击和旧快照也须拒绝。仅调用脚本成功不能算 G2 通过。结果必须注明实测的 OpenScience 版本、命令、日志位置与未完成问题。
