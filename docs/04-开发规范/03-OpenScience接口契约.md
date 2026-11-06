# OpenScience 接口契约 V1

状态：基于 OpenScience 官方 runtime 1.0 文档拟定，具体 SDK 与运行时版本需要 Day 1 锁定实测。
官方来源：https://github.com/synthetic-sciences/openscience/blob/main/frontend/docs/src/content/openscience/api.mdx

## 职责边界

研枢负责认证、项目数据边界、科研任务状态、检查点、证据与批准策略。OpenScience 负责 Research Agent 会话、模型调用、工具、权限继续、文件 Results 和 compute jobs。不要自建第二套模型执行循环，也不要假设 OpenScience 原生具备多租户隔离。

首周采用同版本 TypeScript SDK 或 Python SDK，使用 HTTP + SSE；当前不设计未证实的 Webhook。通过 GET /runtime/capabilities 检查 protocolVersion，运行旧版本或能力缺失时标记选型未通过，不在不确定情况下悄悄换接口再次提交。

## 研枢业务 API 草案

| 接口 | 操作 | 验证与副作用 |
|---|---|---|
| POST /api/tasks | 创建任务 | 验证项目、输入版本、授权；写 PENDING |
| POST /api/tasks/{id}/start | 提交任务 | 状态比较更新，先写 PREPARED attempt 再 runtime.prompt |
| GET /api/tasks/{id} | 读取状态 | 返回研枢业务状态、最近 attempt 与证据摘要 |
| POST /api/tasks/{id}/submit-data | 提供数据 | 验证内容和权限；WAITING_FOR_DATA 才允许进入 PENDING |
| POST /api/tasks/{id}/confirm | 用户确认 | 验证操作者及当前 Snapshot；对 live decision 使用 runtime.decide |
| POST /api/tasks/{id}/reconcile | 核查中断 | 读取运行回执、作业、文件、外部操作记录，不盲重试 |
| POST /api/tasks/{id}/retry | 安全重试 | 仅审核通过 RECONCILING 的尝试，使用新 requestID |
| GET /api/tasks/{id}/evidence | 查询证据 | 使用项目权限与可见数据范围过滤 |

建议每个会改变状态的请求带客户端业务操作 ID。服务端必须用事务判重，不能仅靠 UI 禁用按钮防重复。

## OpenScience 运行契约

1. 建立或复用 session，记录 os_session_id 和目录/工作区模式。项目模式需要研究员批准才能给写权限，且 project selector 不是权限隔离。
2. 生成并保存 requestID、消息及输入清单哈希，提交 runtime.prompt。接收 202 后保存 runID；同一 session + requestID 重试入站请求只会重放回执，参数变更会冲突。
3. 使用 runtime.wait、snapshot、events 收取执行状态。Snapshot 后以 latestSequence 继续 SSE，并按序列去重。断档时重新取快照。
4. 处理 Snapshot 中仍有效的 permission 或 question，只有授权研究员能触发 runtime.decide。进程崩溃后不可假设等待中的决定仍有效。
5. completed 后另行读取 resultMessageID、已提交 Results 和 jobs，再运行研枢独立科研质量检查。未通过时状态不设为 COMPLETED。

## 输入与输出目录

原始文件保存在不可变输入区。工具进程由独立受限账号、沙箱或实际文件系统 ACL 限制写权限，只能向专属输出暂存目录写入；完成校验后原子移动到带 attempt_id 的正式结果目录。路径字符串或 Prompt 中写“只读”并不能实现隔离。

输出 manifest 至少含 task_id、attempt_id、文件路径、文件 SHA256、类型、创建时间、对应 compute_record。每次运行记录模型标识、Token 用量或未知状态、工具失败与审批结果。未授权的未发表数据禁止传到云端模型及遥测；核验 OpenScience 会话轨迹分享配置和实际外发路径。

## 第五天 G2 验收

在 Windows 上完成 1 次真实模型调用和 1 次 Python 工具调用，验证 Results 持久化、原始数据目录不可写、异常中断后核对和安全重试、SSE 断连恢复及权限审批记录。只跑通 Python 脚本不足以判定 G2 通过。OpenScience 若未通过，记录具体失败并评估最小替代方案，不改写现有科研证据数据结构。
