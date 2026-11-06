# 研枢与 OpenScience 接口契约 V1

版本：2026-11-06；状态：计划中的接口约定。首周需固定 OpenScience 运行时与 SDK 的匹配版本。

官方依据：[OpenScience Runtime SDK and API](https://github.com/synthetic-sciences/openscience/blob/main/frontend/docs/src/content/openscience/api.mdx)、[Headless server hosting](https://github.com/synthetic-sciences/openscience/blob/main/frontend/docs/src/content/openscience/server-hosting.mdx)。

## 1. 职责

研枢负责项目数据授权、科研任务、检查点、确认流程、证据关系、材料规则与独立审查。OpenScience 负责 Research Agent 执行、模型/工具、会话、运行回执及自身权限。V1 优先 SDK、HTTP 和 SSE；没有官方依据时不另造 Webhook，也不自建第二套 Agent 循环。

| 研枢业务接口草案 | 预期作用 |
|---|---|
| POST /api/tasks | 验证授权和输入，登记任务 |
| POST /api/tasks/{id}/start | 保存请求 ID 后调用 OpenScience |
| GET /api/tasks/{id} | 返回业务状态、外部尝试与结果摘要 |
| POST /api/tasks/{id}/submit-data | 补齐资料并校验版本 |
| POST /api/tasks/{id}/confirm | 对有权限且仍有效的确认进行回复 |
| POST /api/tasks/{id}/reconcile | 检查中断回执、作业及文件副作用 |
| POST /api/tasks/{id}/retry | 安全核对后建立新尝试 |
| GET /api/tasks/{id}/evidence | 按项目授权返回证据关联 |

此表是研枢拟实现接口，不表示已在 OpenScience 中存在相同路径。

## 2. 下发及观察

1. 检查 /runtime/capabilities 及协议支持。用固定版本的 TS 或 Python SDK，不因提交失败而盲目回退旧 API。
2. 为每个执行登记 os_session_id、os_request_id 和输入内容哈希。请求实际被接纳后补存 os_run_id；首次调用前持久化原始请求的完整标识。
3. 202 或 accepted 只代表接纳，不代表科研工作完成。观察 Snapshot、SSE 事件和最终回执；事件游标失效后重取 Snapshot 并按事件序号去重。
4. 只有授权研究者可以通过最新的 permissions/questions 回应 runtime.decide。服务进程重启后，不沿用已失效的旧授权上下文。
5. 完成后核对 resultMessageID、Results、compute jobs 及研枢证据记录，再决定业务是否 COMPLETED。

## 3. 文件与权限

原始输入目录必须由实际文件系统 ACL、受限账号或隔离工作区强制只读；仅在 Prompt 写“read-only”不构成安全隔离。单个 attempt 的输出有唯一目录，先校验 SHA256 和科学结果，再原子提交；失败不覆盖原始文件与已确认产物。

当前 OpenScience 的项目目录选择不等于多租户授权。官方说明已登录实例可能默认分享完整会话轨迹，Day 1 必须核对设备/账户设置与实际数据外发路径。未经授权的实验室未发表资料不能发送到外部模型或遥测服务。

## 4. G2 验收

至 Day 5，需在 Windows 本地验证一次真实模型调用、一次 Python 工具调用、结果保存、SSE 重连、请求与运行 ID 存储、任务中断后的核对、输入目录不可写、权限审批及费用记录。仅调用脚本成功不能算 G2 通过。结果必须注明实测的 OpenScience 版本、命令、日志位置与未完成问题。
