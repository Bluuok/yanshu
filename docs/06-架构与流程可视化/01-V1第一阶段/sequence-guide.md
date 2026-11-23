# 研枢｜第一阶段 V1 程序运行时序图：阅读指南与设计完整性判断

> **基准仓库**：[`Bluuok/yanshu`](https://github.com/Bluuok/yanshu)，`main` SHA `f4a4ef11ea9ef3d0874d6c4183bdb479c20499f7`（2026-11-17 提交；本次 2026-11-23 再核对 SHA 未变）。本报告描述**正式需求与设计契约对应的预期运行时序**，不表示程序已开发或接口已在真实 OpenScience 版本上通过。
>
> **“第一阶段”指平台六阶段演进中的基础科研辅助阶段**；重点展示该阶段的首月 V1 双主线及其共享基础设施，不表示第一阶段所有未来扩展均纳入首月 MUST。

## 打开交互式 HTML

仓库文件：[stage1-sequence.html](stage1-sequence.html)。GitHub 的代码预览页**不会直接运行 HTML 中的 JavaScript**：请在文件页点击 **Download raw file（下载原始文件）**，将文件保存为 `stage1-sequence.html`，然后用浏览器打开；无需安装依赖、图片或联网。仓库暂未配置 GitHub Pages 在线展示，本次也未改变仓库可见性与部署设置。

## 1. 结论：已有架构图详细到哪一步？

上一版架构地图的数据模型（125 个节点、162 条带依据的依赖）已能说明**模块职责、实体字段和静态依赖**，但单独不足以指导程序运行调试。静态依赖图不能回答：先保存哪个 ID 再发 Agent 请求、SSE 掉线如何恢复、科研输入缺失时阻断哪些步骤、计划批准如何与通知交付分离、ExperimentFact 什么时候可用于论文 Results。

本次补齐的是**设计级时序层**，通过 8 张视图详细说明逻辑消息、控制/数据流方向、持久化、条件分支、人工审批和科研真实性约束。它已可以辅助模块责任划分、接口评审、测试设计与开发人员理解，却**不能替代 G2 之后的源码级详细设计**。

| 完整性层次 | 当前判断 | 依据/限制 |
|---|---|---|
| V1 产品目标与业务边界 | 较充分 | 两条主线、F01–F15、30 天与预算均有权威文档 |
| 模块职责与主要数据模型 | 较充分，待工程映射 | UI / ACCESS / TASK / DATA / PAPER / PLAN / QUALITY 已定义；审批和通知可独立展示，但不代表独立微服务 |
| 业务运行时序与异常分支 | 本交付已覆盖设计级核心 | 从业务请求到 Agent 回执、来源/事实、稿件/计划、审批、调度、质量；条件路径非固定 Agent 链 |
| 真实 API/SDK/DTO 与错误语义 | 部分草案，未冻结 | 研枢路由仅候选，OpenScience SDK/HTTP/SSE、前端二开与 workspace 隔离需 G2 固定版本实测 |
| 物理表、迁移与事务实现 | 未完成代码级设计 | ExperimentFact / ScientificAction / ManuscriptVersion 等是逻辑契约，不应机械建表；约束、索引和事务实现需补齐 |
| 科研规则与质量通过判断 | 尚未可宣称实证通过 | 材料参数、真实反馈样本、论文八维与实验 E1–E10 阈值仍需专家批准/实测 |
| 系统上线及设备联动 | 未完成/不属本次首月承诺 | G2/G3/G4 尚需工程验收；真实设备控制属于后续阶段 |

## 2. 八张时序图（共 168 次逻辑消息）

| # | 视图 | 消息数 | 该图主要回答什么 |
|---:|---|---:|---|
| 1 | 全局运行时序 | 17 | 如何选择论文或实验主线？共享什么服务？如何跨线传递证据？ |
| 2 | 共享执行内核 | 23 | 业务 task 和 OpenScience attempt 怎么建？谁保存 session/request/run ID？何时 RECONCILING？ |
| 3 | 论文研究与稿件 | 28 | 来源、计算、claims、MissingInputRequest、ReviewIssue、版本修订和导出怎样衔接？ |
| 4 | 实验初始规划 | 21 | 假设、模型候选、材料规则、DAG、资源、审批和 ACTIVE 版本怎样生效？ |
| 5 | 实验结果驱动科研决策 | 24 | 延期与科学测量如何分支？真实 Fact 怎样触发科学建议和受控 PlanChange？ |
| 6 | 权限审批与安全恢复 | 22 | 业务审批与 OpenScience live permission 如何区分？如何处理旧快照、重复执行和失败任务重开？ |
| 7 | 通知与任务恢复 | 16 | SQLite outbox、外部投递、重启补处理、已读/确认/延后如何独立？ |
| 8 | 证据闭环与独立评测 | 17 | 如何复算、核实事实、验证引文、独立评价论文与实验科学质量？ |

各图的步骤、状态与文档行号已经统一内嵌于 `stage1-sequence.html` 的 `#seq-data` JSON 数据区块。仓库仅保存此 HTML 和指南，不另行提交 `sequence-source-map.json`、Mermaid 生成文件或截图。SVG / PNG / Mermaid 可在 HTML 中按需导出。

## 3. 实际运行中最容易误解的三条链

**链路 A：从真实材料数据到论文。** 授权与来源登记 → 保留原件 SHA256 → TASK 按需调用 OpenScience / 受控计算工具 → compute_inputs/compute_records → scientific_claims/evidence_links → ManuscriptVersion/Section → QUALITY 定量/引文独立审查 → 必要的局部版本修订 → DOCX / LaTeX 单独核验。缺 Results 时只生成缺项请求或有占位的部分稿件；模型不得虚构实验数据。

**链路 B：新结果改变下一次实验。** `experiment_feedback` 是反馈事件；若存在测量，DATA 将其映射到一份可核对的 `ExperimentFact`，先 `UNVERIFIED`，待真实原件、试样、单位与授权得到核查再成为 `REAL + VERIFIED`。PLAN 读取早已确认的 `Hypothesis` 版本，调用按需科学解释/建议，形成 `ScientificAction`，由确定性规则检查资源与工艺，生成 `PlanChange` 和候选 `plan_versions`。重大变更仅在有效批准后切换 ACTIVE；数据库内同步更换资源占用和通知 outbox。模拟事实不允许冒充已测量的 Results。

**链路 C：运行异常不等于允许重试。** 研枢业务 `yanshu_status` 与 OpenScience 的 Agent run 状态分开；在请求前保存 PREPARED attempt、session/request ID 与工作区清单。SSE 丢失可查询 Snapshot；未知工具副作用进入 `RECONCILING`，检查文件哈希与外部作业再决定安全的新 attempt。已 `FAILED` 的任务为终态，研究者主动重开需新任务并以 `retry_of_task_id` 关联旧任务。

## 4. 重要不变量（应据此写负面测试）

- 一个项目的数据不能跨授权范围引用；`source_id`、`project_id`、文件原件哈希、逻辑事实与论文证据应一致。
- 同一 session 的 requestID 去重不能保证外部工具副作用恰好一次；未知时先对账。
- 研究者业务批准不等于 OpenScience live permission 已成功投递；只对最新 Snapshot 存在的 pending request 发送决定。
- `approval_requests.status`、`approval_decisions.decision`、`delivery_status` 分别表示申请、决定与外部投递状态，不能合并为一个布尔值。
- 计划 `DRAFT`、`PENDING_APPROVAL` 不得激活 booking 或发送有效通知；原始实验事实永不随候选版本回滚。
- 计划 ACTIVE/booking/取消旧提醒/新通知 QUEUED 可以在 SQLite 短事务内原子更新；实际浏览器通知和外部服务**不在该事务内**。
- 已投递 `DELIVERED` ≠ 用户 `READ` ≠ 用户 `ACKNOWLEDGED` ≠ 实验实际完成。
- `REAL + VERIFIED` 的 Fact 可以用于“已实测”类论断，但仍不能证明材料机理/科研解释正确。
- `EVALUATION_INCOMPLETE`、科研质量 `BLOCKED` 和业务状态机里的 `FAILED/COMPLETED` 是不同维度，不能互换。
- 原始论文/实验评分只是经专家校准前的候选，不能宣称科研质量达标。

## 5. 仍需要开发实施阶段明确的契约

1. **G2 OpenScience 实机绑定**：精确版本、SDK/HTTP/SSE 的真实事件结构、Snapshot 游标行为、权限回执、Session workspace 的源码入口和异常语义；G2 通过前图中的 OpenScience 箭头只能叫“预期交互”。
2. **SERVICE → DTO → DATA**：每条业务 API 的输入/输出 JSON Schema、project_id 归属校验、字段空值、稳定错误码与合法状态转移；至少为 TASK/APPROVAL/PLAN/PAPER 画出 4 个真实边界示例。
3. **SQLite DDL / 事务设计**：明确哪些逻辑对象共表、独立表或受约束 JSON；关键主外键/唯一索引、版本乐观锁、活跃计划唯一性、outbox 去重和重入保障。
4. **科研专业规则**：通过真实标准/材料范围批准的可执行规则版本、试样/单位映射方法、资源容量与维护日历，以及假设/Fact/Action 的实际专家评议路径。
5. **回归与真实使用证据**：真实授权材料数据、TEST-T01–TEST-T15 正反例、G2/G3/G4、Windows 浏览器可用性、科研专家签署、错误和费用报告。

执行顺序必须以《V1 开发实施计划》为准；本时序图**不是额外开工进度表**，不会改变 30 自然日、Day 24–30 七天完整测试或首月采购上限 4,000 元的已批准决定。

## 6. 数据来源与重生成

重点基于当前固定 SHA 的以下文档：

- [`00-V1实施总方案.md`](https://github.com/Bluuok/yanshu/blob/f4a4ef11ea9ef3d0874d6c4183bdb479c20499f7/docs/02-产品与实施/00-V1实施总方案.md)：F01–F15 用户路径、实现候选、异常和验收。
- [`02-第一阶段实施规范.md`](https://github.com/Bluuok/yanshu/blob/f4a4ef11ea9ef3d0874d6c4183bdb479c20499f7/docs/02-产品与实施/02-第一阶段实施规范.md)：论文和实验两线、动态科研反馈、数据事实边界。
- [`03-数据运行与接口.md`](https://github.com/Bluuok/yanshu/blob/f4a4ef11ea9ef3d0874d6c4183bdb479c20499f7/docs/04-技术选型与开发/03-数据运行与接口.md)：持久化对象、状态、审批、OpenScience 调用、通知 outbox 与逻辑契约。
- [`05-工作台与甘特图.md`](https://github.com/Bluuok/yanshu/blob/f4a4ef11ea9ef3d0874d6c4183bdb479c20499f7/docs/04-技术选型与开发/05-工作台与甘特图.md)：研究者操作、甘特数据约束。
- [`04-材料规则与外部接入.md`](https://github.com/Bluuok/yanshu/blob/f4a4ef11ea9ef3d0874d6c4183bdb479c20499f7/docs/04-技术选型与开发/04-材料规则与外部接入.md)：真实测量、单位和材料规则审核。
- [`03-实验规划评分.md`](https://github.com/Bluuok/yanshu/blob/f4a4ef11ea9ef3d0874d6c4183bdb479c20499f7/docs/03-科研质量与样本/03-实验规划评分.md)：E1–E10 科研评价边界。

使用方式：直接打开 `stage1-sequence.html`，左侧选择章节；单击消息查看字段、风险与来源；支持搜索、缩放、宽屏专注及 SVG/PNG/Mermaid 导出。离线即可查看，无需 CDN 或额外依赖。本仓库版将程序与结构化时序模型一并封装在 `stage1-sequence.html` 中，直接打开即可使用。若后续需要修改图中的逻辑步骤，应同步更新 HTML 内嵌的 `#seq-data`，并检查对应来源依据；本目录不保留生成脚本或预生成图像。

## 7. 真实浏览器验证与限制

- 验证工具：Chromium headless + Playwright（当前运行环境）。
- 核对视口：1920×1080、2560×1440。
- 已实际测试：8 个章节的 SVG 生成、消息详情与来源、搜索命中、放大/缩小/适配、宽屏模式、SVG/PNG/Mermaid 导出，以及两种视口下无页面级横向溢出和 JavaScript console/pageerror。
- **实际修复**：第一轮 SVG 独立导出时，由于页面样式没有内嵌到 SVG，透明交互层在 PNG 导出时错误表现为黑色背景；已为交互层写入显式透明 `fill` 并复测最终 PNG。此次记录的是可复现的缺陷，不计入科研软件 G2 的测试。
- 本执行环境的浏览器禁止直接导航 `file://` 本地路径，采用 Playwright `page.set_content` 加载**同一份完整 HTML 内容**进行渲染、交互和导出测试。普通本地浏览器直接打开网页的行为未在该受限环境完成端到端 file:// 验证。不能把本次可视化浏览器测试冒充真实研枢系统运行通过。
