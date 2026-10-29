# AreaChain 技能路由与交付闭环

这是 AreaChain 的项目级路由契约。它把仓库规则、项目技能、共享组件、实现和验收串成一条冷启动也能执行的流程；它不改变全局技能的启用策略，也不授予安装、签名、真实数据或远端写入权限。

## 指定只读复核入口

本节是指定只读复核的唯一权威来源，其他文件只引用这里。

- **入口**：2026-10-18 起，共享契约、持久化语义、复杂状态、跨模块行为和高风险变更的指定只读复核，由 Claude Code `verifier` 子代理承担。它定义在本机 `~/.claude/agents/verifier.md`，运行在独立上下文中，只读。
- **时机与输入**：执行对话在本批最终验证之后显式派发它。派发时提供原始需求或提示词、适用的项目约定、实际差异（文件列表与关键 diff）、已运行的命令与结果；要求它按"结论 / 实际运行的检查 / 整改清单 / 未覆盖项"四段格式返回，并给出 `file:line`。
- **结论处理**：结论为"通过"，才算关闭本批的复核缺口。结论为"不通过"时，只按整改清单修复，重跑受影响的检查，再派发一次复核。执行者自己不能充当复核者，也不能让普通子代理（如 `Explore`、`general-purpose`）顶替。
- **不可用环境**：在没有该子代理的环境（如 Codex、Cursor）中，或派发失败时，保留复核缺口并报告 partial，不得冒充已复核。
- **历史段落**：其他文档历史段落（以及本文件 git 历史里的里程碑路由）中的"指定 Cursor verifier / Cursor `verifier`"保留当时的含义，不逐段改写。它们留下的复核缺口不会因本节自动关闭，需另开补复核批次处理。

## 来源优先级

发生冲突时按以下顺序核对，不能把旧提示词或模型记忆当成项目事实：

1. 用户本次明确的目标、范围和授权。
2. 仓库 [AGENTS.md](AGENTS.md) 的硬性边界。
3. 产品、使用、架构和工程文档中的已核实事实。
4. 当前代码、测试和脚本的实际行为。
5. 适用技能提供的方法和质量判据。

文档、代码和测试不一致时，先记录当前行为与目标行为，再决定是否需要改变；不能静默选择对实现最方便的一方。

## 冷启动必经流程

任何新对话、续作任务或子任务都按下面顺序开始。小任务可以合并步骤，但不能跳过“状态检查”和“复用检索”。

## 用户输入契约

用户可以只用自然语言描述目标，不需要知道项目目录、技能名称或复用规则。代理负责把“读取当前项目”“查看任务页相关代码”“把这个控件统一到全局”等表达转换为仓库内的检索、影响分析和验证动作；这些动作是默认工作流，不应要求用户重复粘贴一套操作提示词。

如果用户没有明确要求修改，默认只做读取、定位和现状说明；如果用户要求修改，默认先完成冷启动和复用检索再实施。只有技术定位会改变范围、权限、数据或不可逆结果时，才需要向用户澄清。

### 1. 接收与定界

- 判断任务属于：新增功能、界面优化、领域/服务改动、重构、诊断/审阅、验证、文档/规则维护，还是技能维护。
- 明确目标、非目标、受影响入口、必须保持的行为和可能的高风险边界。
- 执行 `git status --short`、`git diff --cached --stat`、`git diff --stat`；保留已有用户修改。

### 2. 读取最小上下文

- 所有任务先读 [AGENTS.md](AGENTS.md) 和本文件。
- 产品行为读 `docs/product.md`、`docs/features.md`、`docs/usage.md`。
- 模块、状态、窗口和数据契约读 `docs/architecture.md` 的相关章节。
- 生命周期质量、注释、安全、性能、测试、交付和维护读 [质量门禁](docs/quality-gates.md)；性能数字再读 [`docs/performance-baselines.json`](docs/performance-baselines.json)。
- 构建、脚本、签名、恢复或交付读 `docs/engineering.md` 的相关章节，必要时再读 `docs/signing.md`。
- 需要新增或修改界面时读 [组件目录](docs/component-catalog.md) 的相关条目及实际调用方；不能只看组件名。
- `architecture.md`、`component-catalog.md`、`engineering.md` 和统一搜索权威设计都是数百 KB 的大文档：先按标题或锚点检索，只读本次相关章节，不整篇载入。

### 3. 选择技能

| 任务类型 | 主流程 | 补充能力 | 必要交接 |
|---|---|---|---|
| 新增产品能力或页面 | `areasong-development`（当前会话可用时）与 [areachain-workflow](.agents/skills/areachain-workflow/SKILL.md) | 有界面时用 [areachain-ui](.agents/skills/areachain-ui/SKILL.md) | [areachain-verify](.agents/skills/areachain-verify/SKILL.md) |
| 既有界面、输入、窗口或视觉调整 | [areachain-ui](.agents/skills/areachain-ui/SKILL.md) 与 `areasong-development` 的 UI 路径 | 按实际问题选择 UI/UX 或平台方法 | [areachain-verify](.agents/skills/areachain-verify/SKILL.md) |
| Domain、Services、持久化、同步或公共状态 | [areachain-workflow](.agents/skills/areachain-workflow/SKILL.md) | `areasong-development` 的架构/可靠性/工程引用 | [areachain-verify](.agents/skills/areachain-verify/SKILL.md) |
| 重构、公共组件或跨模块契约 | [areachain-workflow](.agents/skills/areachain-workflow/SKILL.md) | `areasong-development` 架构治理 | Claude Code `verifier` 子代理（见[指定只读复核入口](#指定只读复核入口)）只读复核，以及 [areachain-verify](.agents/skills/areachain-verify/SKILL.md) |
| 只读诊断、代码审阅或进度查询 | 相关代码/文档和验证入口 | 不因“看起来像功能”而实施修改 | 按请求报告证据，不自动修复 |
| 验证或回归 | [areachain-verify](.agents/skills/areachain-verify/SKILL.md) | 按影响选择测试、构建和原生证据 | 报告通过、失败、跳过和未运行 |
| 文档、AGENTS、路由或项目技能维护 | [areachain-workflow](.agents/skills/areachain-workflow/SKILL.md) | 不引入第四个项目技能或本机 `skill-creator` | `check_workflow.py`（含 `skill-format`）和差异复核 |

技能不可用时，按同一表格读取项目文档和脚本完成安全部分，并明确缺口；不能冒充技能已调用。技能本身不扩大用户授权。

仓库只维护三个项目技能：`areachain-workflow`、`areachain-ui`、`areachain-verify`。不为 Domain、发行、安装、诊断或钥匙串再拆技能；那些事实分别在文档、脚本和高风险授权里。个人级 `areasong-development` 发现才用，不是仓库内容。新增项目技能的门槛仍是重复、多步骤且确需本仓库专项方法，并同时改本文件、`AGENTS.md`、`.gitignore` 和 `check_workflow.py`。

### 4. 复用门禁

在新增控件、规则、状态对象、仓储入口或测试夹具前，先完成一张简短的复用/影响表：

| 需求 | 已有入口或组件 | 文件与真实消费者 | 直接复用/局部扩展/新建 | 保持的契约 |
|---|---|---|---|---|

至少检索 [docs/component-catalog.md](docs/component-catalog.md)、所属 Feature、对应 Domain/Services 和相关测试。只有一个真实消费者时默认留在所属功能；多个消费者共享同一语义且需要同步演进时，才提取到公共层。新增公共组件必须补目录、调用方回归和边界测试。

复用不等于抹平差异：任务输入、手记输入、剪贴板捕获、搜索、菜单栏和独立窗口可以共享外观，但 Return、Command-Return、Escape、失焦、隐私和保存语义必须分别核对。

公共顶栏的页面接入走 `WorkspaceHeaderContent` / `workspaceHeader`；详情能力走当前页面投影登记，入口与消费者见 [组件目录](docs/component-catalog.md)。验收补 `WorkspaceHeaderStateTests`、`WorkspaceHeaderInteractionTests` 和 `WorkspaceRenderingTests`，由原生 UI 技能实施、验证技能执行，公共状态交 Claude Code `verifier` 子代理（见[指定只读复核入口](#指定只读复核入口)）只读复核。

### 5. 质量门禁

- 默认从仓库根运行 `python3 -B scripts/quality_gate.py`，由它按当前差异选择静态、Swift、性能或候选包范围；需要机器读取时使用 `--format json`。干净工作区没有差异时，`auto` 只会跑 `static`。Swift 源码改动必须显式加上 `--profile swift`，不能把干净树上的通过写成 Swift 已测。Swift 门禁按变更推导定向测试，推导不了会报 `swift-test-scope` 警告，不会静默跑全量；全量回归显式用 `--profile full`。
- `failed` 和 `blocked` 不能宣称完成；`warning` 必须在交接中列出，发布/合并前可用 `--strict` 将其升级为失败。
- 注释、敏感日志、依赖、性能和恢复不是“顺手检查”的口头要求，分别对应 [质量门禁](docs/quality-gates.md)、脚本扫描、工程/架构文档和性能基线清单。
- 本地通过只证明本地命令；远端 CI、分支保护、真实钥匙串/日历、安装、恢复、公证和正式发行仍需各自证据。

### 6. 实施

- 沿 `Domain → Services → Features → Theme` 的责任方向修改；目录名不是依赖证明，需沿实际调用链核对。
- 规则、筛选、日期、搜索和事务只保留一个权威入口；页面不能复制第二套判断。
- 共享视觉使用语义令牌和现有基座；不以局部需求重建设计系统。
- 保存成功、通知排程、外部同步和界面反馈分别判断；失败不清除唯一草稿或虚报成功。
- 触及真实钥匙串、系统日历、签名、迁移、删除或外部发布时，先按 `AGENTS.md` 的高风险门禁停下确认。

### 7. 验证与交接

完成相关编辑后：

1. 运行本次影响对应的静态检查、定向测试、脚本测试或构建；不要用旧结果代替新证据。
2. UI 变更分别检查行为、焦点/键盘、双语、浅深色、最小窗口和原生宿主；网页截图不能证明 macOS 原生验收。
3. 共享组件或公共契约变化扩大到所有真实消费者。跨模块契约只由 Claude Code `verifier` 子代理（见[指定只读复核入口](#指定只读复核入口)）做只读复核；测试、构建和隔离原生只由 [areachain-verify](.agents/skills/areachain-verify/SKILL.md) 选择并执行。
4. 最终报告区分：已实现、已验证、已安装、已发布、跳过、未运行和残余风险。
5. 更新权威文档和组件目录；不生成重复的计划性规范。

## 完成状态

项目任务只能使用以下状态词：

- **已实现**：代码或文档已修改。
- **已验证**：对应检查已实际运行并通过。
- **部分完成**：有明确缺口，但仍有安全可交付内容。
- **阻塞**：缺少必要授权、环境或失败证据，无法继续宣称完成。
- **已安装/已发布**：只有执行并验证了对应外部动作后才能使用。

“代码存在”“构建成功”“测试目标存在”都不能单独替代运行行为或原生界面证据。

## 路由维护

- 新增项目技能时，同时更新本文件、`AGENTS.md`、`.gitignore`、`scripts/check_workflow.py` 的技能清单、`skill-format` 夹具和对应测试。默认不新增；现有三个已覆盖日常编排、界面和验收。
- 新增共享控件或公共规则时，同时更新 [组件目录](docs/component-catalog.md)、实际调用方测试和必要架构说明。
- 修改验证入口时，保持脚本、技能、README 和工程手册使用同一命令来源；不维护两套互相漂移的门禁。
- 任何路由文件、技能引用或组件目录变更，都要运行 `python3 -B scripts/check_workflow.py`；修改检查器本身还要运行其定向测试。
- **统一搜索交接规则**（2026-10-19 起，本条是唯一出处，其他文件只引用）：
  - 每批只更新 [统一搜索现状总览](docs/unified-search-status.md) 里受影响的行（覆盖表、缺口、补复核待办），不再往[权威设计](docs/unified-search-commands.md) §8 表格行末追加注记。
  - 权威设计 §9 的交接节不超过 80 行：只写本批的决定、入口、测试数字和缺口；不重复历史，不转录长日志，证据放在被忽略的 `build/` 批次目录。
  - 只有路由本身变化（新技能顺序、新复核或验证入口）时才在本文件加段落；普通里程碑不在这里加路由段落。

## 历史里程碑路由

2026-10-29 前，本文件逐批记录了各阶段与统一搜索里程碑的技能顺序和边界（第三～第十阶段、统一搜索 1A～N-M2、T/C/P/R/B 系列等）。这些记录已从本文件移出：它们不再约束新任务，却让每次冷启动都要通读。需要追溯时用 `git show ffe27a3:skill-routing.md` 查看原文；各里程碑的组件入口与证据仍分别在[组件目录](docs/component-catalog.md)和[工程手册](docs/engineering.md)的对应章节。
