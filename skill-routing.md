# AreaChain 技能路由与交付闭环

统一搜索 2H-2 沿 `areachain-workflow` → `areasong-development` 领域/架构路径 → `areachain-verify`。入口 TrashQueryProvider.read 消费同次 TrashTombstoneReader 安全投影，字段匹配、routine 证据、命中提升与完整性见[权威设计第 9.26 节](docs/unified-search-commands.md#926-阶段-2h-2显式墓碑只读搜索与命中归组)。验证六套 TrashQuery、四套 TrashTombstone、活提供者/查询和旧软删除回归，静态质量/原脚本回归、工作流、严格局部 lint 与 Debug 构建。没有更改检查器接口或另建执行器。指定 Cursor verifier 缺失继续 partial，不重复登录或替代复核；真实枚举、恢复/永久删除/文件操作、生产 UI、聚合与独立执行记录均未接线，完成后停止。

统一搜索 2H-1 沿 `areachain-workflow` → `areasong-development` 纯领域/架构治理 → `areachain-verify`。公共输入与读取入口 TrashTombstoneInput / TrashTombstoneReader 见组件目录，唯一交接见[权威设计第 9.25 节](docs/unified-search-commands.md#925-阶段-2h-1回收站墓碑删除关联与恢复条件的只读契约)。验证四套墓碑测试、旧 SoftDelete/子任务/附件/回收站与隐私投影定向回归，另跑静态质量及原脚本回归、工作流、严格局部 lint 和 Debug 构建。检查器接口不变，不新增专项执行器；指定 Cursor verifier 缺失仍 partial，不重查登录、不替代复核。不接查询提供者、真实恢复/删除/文件、生产 UI 或认证，完成后停在 2H-1。

统一搜索 2G 沿 `areachain-workflow` → `areasong-development` 纯领域/架构路径 → `areachain-verify`。ClipboardQueryProvider 与旧 ClipboardHistoryRules 共用 ClipboardTextMatching，实际入口见组件目录，唯一交接见[权威设计第 9.24 节](docs/unified-search-commands.md#924-阶段-2g显式剪贴板历史的只读搜索提供者)。验证四套 ClipboardQuery、独立旧算法对照、目录参数/补全、完整查询/转交及其他提供者回归，另跑静态质量/脚本回归、工作流、严格局部 lint 与 Debug 构建。检查器接口/规则不变；指定 Cursor verifier 缺失仍 partial，不重查登录或替代复核。不接真实历史、系统剪贴板、生产 UI、聚合或执行，完成后停在 2G。

这是 AreaChain 的项目级路由契约。它把仓库规则、项目技能、共享组件、实现和验收串成一条冷启动也能执行的流程；它不改变全局技能的启用策略，也不授予安装、签名、真实数据或远端写入权限。

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
- 模块、状态、窗口和数据契约读 `docs/architecture.md`。
- 生命周期质量、注释、安全、性能、测试、交付和维护读 [质量门禁](docs/quality-gates.md)；性能数字再读 [`docs/performance-baselines.json`](docs/performance-baselines.json)。
- 构建、脚本、签名、恢复或交付读 `docs/engineering.md`，必要时再读 `docs/signing.md`。
- 需要新增或修改界面时读 [组件目录](docs/component-catalog.md) 及实际调用方；不能只看组件名。

### 3. 选择技能

| 任务类型 | 主流程 | 补充能力 | 必要交接 |
|---|---|---|---|
| 新增产品能力或页面 | `areasong-development`（当前会话可用时）与 [areachain-workflow](.agents/skills/areachain-workflow/SKILL.md) | 有界面时用 [areachain-ui](.agents/skills/areachain-ui/SKILL.md) | [areachain-verify](.agents/skills/areachain-verify/SKILL.md) |
| 既有界面、输入、窗口或视觉调整 | [areachain-ui](.agents/skills/areachain-ui/SKILL.md) 与 `areasong-development` 的 UI 路径 | 按实际问题选择 UI/UX 或平台方法 | [areachain-verify](.agents/skills/areachain-verify/SKILL.md) |
| Domain、Services、持久化、同步或公共状态 | [areachain-workflow](.agents/skills/areachain-workflow/SKILL.md) | `areasong-development` 的架构/可靠性/工程引用 | [areachain-verify](.agents/skills/areachain-verify/SKILL.md) |
| 重构、公共组件或跨模块契约 | [areachain-workflow](.agents/skills/areachain-workflow/SKILL.md) | `areasong-development` 架构治理 | Cursor `verifier` 只读复核，以及 [areachain-verify](.agents/skills/areachain-verify/SKILL.md) |
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

公共顶栏的页面接入走 `WorkspaceHeaderContent` / `workspaceHeader`；详情能力走当前页面投影登记，入口与消费者见 [组件目录](docs/component-catalog.md)。验收补 `WorkspaceHeaderStateTests`、`WorkspaceHeaderInteractionTests` 和 `WorkspaceRenderingTests`，由原生 UI 技能实施、验证技能执行，公共状态仍交 Cursor `verifier` 只读复核。

### 5. 质量门禁

- 默认从仓库根运行 `python3 -B scripts/quality_gate.py`，由它按当前差异选择静态、Swift、性能或候选包范围；需要机器读取时使用 `--format json`。干净工作区没有差异时，`auto` 只会跑 `static`。Swift 源码改动必须显式加上 `--profile swift`，不能把干净树上的通过写成 Swift 已测。
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
3. 共享组件或公共契约变化扩大到所有真实消费者。跨模块契约只由 Cursor `verifier` 做只读复核；测试、构建和隔离原生只由 [areachain-verify](.agents/skills/areachain-verify/SKILL.md) 选择并执行。
4. 最终报告区分：已实现、已验证、已安装、已发布、跳过、未运行和残余风险。
5. 更新权威文档和组件目录；不生成重复的计划性规范。

第三阶段 F 的数值控件沿 `areachain-workflow` → `areachain-ui` → `areachain-verify`；公共入口为 `DaybookStepper`，只接剪贴板两个数值绑定。原生对照、公共交互与真实消费者分别验证，展示复用 DaybookControlsPreview，隔离沿 ClipboardOptionsFixture。接口与边界见[组件目录](docs/component-catalog.md#第三阶段-f公共数值加减与剪贴板)，稳定实现/几何由原 check_workflow.py 守卫。公共能力仍指定 Cursor verifier 只读复核；工具不可用保持缺口，不以其他代理替代。不进入日期、任务完成或其他控件。

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

按钮基础维护沿 `areachain-ui` → `areachain-verify`；公共入口和后续迁移边界见[组件目录](docs/component-catalog.md)，测试专用展示窗口打开方法见[按钮开发展示与验收](docs/engineering.md#按钮开发展示与验收)。展示与真实消费者分别回归，不加入正式导航。

统一搜索与指令的阶段 1A 维护沿 `areachain-workflow` → `areachain-verify`，公共契约复核仍指定 Cursor `verifier`。入口为 [CommandCatalog.swift](AreaChain/Domain/CommandCatalog.swift)，消费者与边界见[组件目录](docs/component-catalog.md)，阶段决定与覆盖只更新[权威设计](docs/unified-search-commands.md)。目录不能作为执行器或权限授予来源，后续阶段需独立授权。

统一搜索 1B-1 的 `CommandPathParser` 沿上述工作流与验证路由，复用 1A 目录/参数和既有语法保护区间；公共契约仍须 Cursor `verifier`，不可用时保持 partial。领域定向测试、编译和静态检查不能替代指定复核；独立输入、候选与后续 1B-2 边界见[权威设计](docs/unified-search-commands.md#97-阶段-1b-1-指令路径解析与补全)。

统一搜索 1B-2A 的 `ContentQueryParser`、日期、范围与适用性仍走 Domain 工作流和定向验证；复用入口见[组件目录](docs/component-catalog.md)，语法、范围、接口与 1B-2B 仅登记要求见[权威设计第 9.8 节](docs/unified-search-commands.md#98-阶段-1b-2a内容查询语法范围与日期契约)。新契约目前仅由领域测试消费，不因解析就接 UI/提供者/执行；指定 Cursor 复核缺失保持 partial，不重复检查认证或以其他复核替代。检查器接口未改变，继续使用原工作流/质量守卫。

统一搜索 1B-2B 的页面上下文、条件身份/来源、绑定与纯转移同样由 `areachain-workflow` → `areachain-verify` 组织，架构治理只补状态所有权；入口与复用见组件目录，唯一交接为[权威设计第 9.9 节](docs/unified-search-commands.md#99-阶段-1b-2b页面查询上下文与纯状态转移)。验收选择 ContentQuerySessionTests / ContentQueryProjectionTests / ContentQueryPageMappingTests 和相关查询、路径、日期、筛选回归；生产 UI 与 1C 不在范围。指定 Cursor verifier 不可用仍 partial，不重新检查登录，不用其他复核替代。检查脚本接口/规则未改变，继续实际运行原静态、Swift 与工作流入口，不新增专项检查器。

统一搜索 1C-1 的操作草稿、固定目标、基线及保护转移沿 `areachain-workflow` → 架构治理 → `areachain-verify`，新增入口见组件目录，唯一规格与 1C-2/1C-3 分界见[权威设计第 9.10 节](docs/unified-search-commands.md#910-阶段-1c-1操作草稿固定目标与编辑保护)。回归选 CommandDraftTests / CommandDraftProtectionTests / CommandHostSessionTests 及既有目录、参数、查询和路径测试。指定 Cursor verifier 缺失仍 partial，不重复认证检查，不以其他复核替代；既有检查器和规则未改动，不新建专项执行器或脚本。

统一搜索 1C-2 的待执行计划、依赖/创建输出引用、合并和纯生命周期沿 `areachain-workflow` → 架构/可靠性治理 → `areachain-verify`。复用目录见组件目录，唯一协议与后续适配限制见[权威设计第 9.11 节](docs/unified-search-commands.md#911-阶段-1c-2待执行计划依赖与纯生命周期协议)。回归新增五套计划/执行 Domain 测试及原草稿、宿主、参数、目录、查询和路径测试；没有 UI 或真实执行验收。指定 Cursor verifier 缺失保持 partial，不重复登录、不替代复核；未改检查器接口/规则，不新建专项检查脚本，继续运行原静态、工作流、Swift 门禁和构建。停在 1C-2，不自动进入 1C-3。

第三阶段 A 的公共启用开关沿 `areachain-workflow` → `areachain-ui` → `areachain-verify`，入口为 [DaybookToggleStyle.swift](AreaChain/Theme/DaybookToggleStyle.swift)。仅新建重复事项和管理行接入，具体参数、提交差异和后续边界见[组件目录](docs/component-catalog.md)。新增公共组件仍须 Cursor `verifier`，不可用保留复核缺口；原生证据仅走现有隔离 XCTest，展示复用 `DaybookControlsPreview`。稳定入口由原 `check_workflow.py` 维护，不新增技能或验收应用。

统一搜索 1C-3 的跨入口主动转交沿 `areachain-workflow` → 架构/可靠性治理 → `areachain-verify`。入口为 [CommandHandoffCoordinator.swift](AreaChain/Domain/CommandHandoffCoordinator.swift)；既有宿主/草稿/计划/执行/查询协议继续复用，权威交接仅在[第 9.12 节](docs/unified-search-commands.md#912-阶段-1c-3跨入口主动转交与唯一所有权)。选择四套新增转交测试及相关既有 Domain 回归、构建、静态和工作流检查；本阶段不操作真实窗口，因此不运行会启动全套原生交互的 auto / swift profile，也不把定向证据冒充整树通过。指定 Cursor verifier 缺失继续 partial，不重复登录、不替代复核。检查器接口/规则不变，无专项脚本；完成后停止，不自动接真实窗口、权限资源、隐私或执行器。

阶段 1D 沿同一工作流与验证入口，选择四套领域集成测试及实际受影响的目录/参数/路径/查询/草稿/计划/执行/转交回归；边界、最小修正和证据统一见[第 9.13 节](docs/unified-search-commands.md#913-阶段-1d领域链路集成验证与最小修正)。仅静态门禁、严格局部 lint、定向测试和 Debug 构建，不运行无关原生全量测试；Cursor 指定复核缺失保持 partial，不重复认证检查。没有新检查器入口或脚本，不进入数据提供者或 UI 阶段。

统一搜索 2A 的 todo 注入快照提供者沿 `areachain-workflow` → 架构治理 → `areachain-verify`；接口、支持与缺口见[组件目录](docs/component-catalog.md)和[权威设计第 9.14 节](docs/unified-search-commands.md#914-阶段-2atodo-只读快照提供者与类型化结果)。验收选四套 TodoQuery 测试及查询/日期/分类/列表/旧搜索回归，运行静态、工作流、严格局部 lint 和 Debug 构建；不运行无关原生全量 profile。检查器接口/规则未改，不新增专项脚本；指定 Cursor verifier 不可用保留 partial，不重查登录或替代复核。仅合成数据，到 2A 停止。

第三阶段 B 延续第三阶段 A 的 UI 与验证路由，公共入口扩展为 `DaybookToggleStyle(.checkbox)`，只接入 `PrivacySetupSheet.tagChoices`。复用 `DaybookControlsPreview`、原生测试宿主及 `PrivacyInteractionTests`；原开关与重复事项回归仍需执行。稳定表现/几何由 `check_workflow.py` 维护，独立只读复核仍指定 Cursor `verifier`，不可用保留缺口。后续迁移边界见[组件目录](docs/component-catalog.md)。

统一搜索 2B 的活子任务注入快照提供者沿 `areachain-workflow` → 架构治理 → `areachain-verify`；入口与真实消费者登记在组件目录，唯一契约与证据见[权威设计第 9.15 节](docs/unified-search-commands.md#915-阶段-2b活子任务独立结果的只读快照提供者)。验收选五套 SubtaskQuery、四套 TodoQuery 及实际受影响的查询/日期/分类/列表/旧搜索回归，静态门禁、工作流、严格局部 lint 和 Debug 构建；不运行无关原生全量 profile。既有检查器接口/规则未改，继续使用并实际运行原检查和脚本回归，不新建专项检查器。指定 Cursor verifier 不可用仍 partial，不重查认证、不替代复核；不接真实数据/UI/聚合/执行，完成后停在 2B。

统一搜索 2B-R 沿 `areachain-workflow` → 架构治理 → `areachain-verify` 修正页面父级条件、类型分析与两个快照提供者，入口见组件目录和[权威设计第 9.16 节](docs/unified-search-commands.md#916-阶段-2b-r父级页面条件与按类型可满足性)。验证覆盖解析、条件、页面映射/投影、Session、转交、todo/subtask 与旧共同查询，继续原静态/工作流/严格局部 lint 和 Debug 构建；无新增检查器接口或脚本。指定 Cursor verifier 与历史缺口保留，不重查认证、不替代复核；不进入习惯提供者、UI、仓储或执行。

统一搜索 2C-1 沿 `areachain-workflow` → 架构治理（通用开发的纯领域路径）→ `areachain-verify`，维护 on/skipped、单日记录归并及有界历史证据；接口见组件目录，唯一交接见[权威设计第 9.17 节](docs/unified-search-commands.md#917-阶段-2c-1习惯执行日历史证据与只读状态契约)。四套新领域测试与查询/类型/条件/转交、todo/subtask、旧日期/看板/逾期回归串行验证，另运行静态、工作流、严格局部 lint 和 Debug 构建。检查器接口及规则未改，继续实际运行原脚本回归，不新建执行器；指定 Cursor verifier 缺失仍 partial，不重查登录、不替代复核，不进入 2C-2、真实仓储、UI、历史持久化或写入修复。

统一搜索 2C-2 继续 `areachain-workflow` → 架构治理 → `areachain-verify`，入口为 RoutineQueryProvider，复用边界见组件目录，唯一交接见[权威设计第 9.18 节](docs/unified-search-commands.md#918-阶段-2c-2习惯定义只读快照提供者)。验证四套新增 RoutineQuery 与 todo/subtask、2C-1、查询/转交及旧投影回归，另跑 Debug 构建、严格局部 lint、静态和工作流门禁；检查器接口及规则未改，继续原脚本回归，不新建专项检查器。指定 Cursor verifier 缺口保留，不重查认证、不替代复核；开发停在快照定义提供者，不接真实证据适配、仓储、UI 或执行。

统一搜索 2D 沿 `areachain-workflow` → `areasong-development` 纯领域/架构路径 → `areachain-verify`，入口为 DiaryQueryProvider；组件及实际消费者见目录，唯一交接见[权威设计第 9.19 节](docs/unified-search-commands.md#919-阶段-2d手记只读快照提供者)。验证选五套新增 DiaryQuery、原查询/日期/标签/类型/页面/转交、todo/subtask/routine 与旧搜索回归，另跑 Debug 构建、严格局部 lint、静态和工作流门禁。既有检查器入口/规则未改，继续实际运行原脚本回归，不新增专项检查器。指定 Cursor verifier 缺失保持 partial，不重查认证、不替代复核；合成数据不代替真实隐私接线验收，停在注入快照，不接生产 UI、仓储、附件或执行。

统一搜索 2E-1 继续 `areachain-workflow` → `areasong-development` 纯领域/架构路径 → `areachain-verify`。入口 ImageAssociationReader 与 AttachmentBrowseFacts 见组件目录，唯一关联/覆盖契约和 2E-2 前置见[权威设计第 9.20 节](docs/unified-search-commands.md#920-阶段-2e-1类型化图片拥有者关联完整性与只读可浏览投影)。验证四套新增合成测试、旧 AttachmentAccess 浏览及现有 todo/subtask/routine/diary 回归，运行静态质量、工作流、严格局部 lint 与 Debug 构建；不读取图片或真实库。既有检查器接口/规则不变，继续原脚本回归。指定 Cursor verifier 缺失保留 partial，不重查认证、不替代复核；不接生产 UI、真实隐私适配或完整图片查询，停在 2E-1。

第三阶段 G 沿 `areachain-workflow` → `areachain-ui` → `areachain-verify`，扩展 ModernCheckbox 的 inlineSubtask 表现，只迁移 TaskRowSubtaskInlineList。尺寸、提交差异、测试与后续详情子任务边界统一见[组件目录](docs/component-catalog.md#第三阶段-g公共任务完成控件与行内子任务)。公共复核只交 Cursor verifier，不可用保留缺口；隔离验收复用原 XCTest 与 DaybookControlsPreview，保留真实延迟测试。完成后停止，不迁移详情子任务、日期或其他控件。

第三阶段 H 继续 `areachain-workflow` → `areachain-ui` → `areachain-verify`；只把 SubtaskRowView.toggleCheckboxButton 接入 ModernCheckbox.detailSubtask，集中符号几何、真实行/详情前后对照与触感次数入口见[组件目录](docs/component-catalog.md#第三阶段-h详情子任务完成控件接入)。失败刷新必须在同一宿主自然更新下观察，既有缺陷与迁移回归分开；展示复用 DaybookControlsPreview。稳定入口仍由原 check_workflow.py 维护，公共复核仍只交 Cursor verifier，不可用保留缺口。完成后停止，不迁移日期、分段或其他控件。

统一搜索 2E-2A 沿 `areachain-workflow` → `areasong-development` 纯领域/架构路径 → `areachain-verify`。入口 ImageQueryProvider 与实际复用消费者见组件目录，唯一交接见[权威设计第 9.21 节](docs/unified-search-commands.md#921-阶段-2e-2a公开图片元数据的只读搜索提供者)。验收选五套 ImageQuery、2E-1、完整查询/类型/页面/转交、四类提供者及习惯历史/记录回归，另跑 Debug 构建、严格局部 lint、静态质量与工作流门禁；既有检查器接口/规则未变，继续原脚本回归。指定 Cursor verifier 缺失仍 partial，不重查登录、不替代复核；不读取真实图片、不接仓储/UI/执行、不进入其他提供者 has:image 的 2E-2B。


统一搜索 2E-2B 继续 `areachain-workflow` → `areasong-development` 纯领域/架构路径 → `areachain-verify`。共用 ContentQueryImageRead 与三个提供者只消费本次主请求快照，接口见组件目录，唯一交接见[权威设计第 9.22 节](docs/unified-search-commands.md#922-阶段-2e-2b三类记录的图片存在性查询)。验证四套 RecordImageQuery、Todo 辅助未知组合、原提供者/查询/转交、2E-1 与 ImageQuery 回归，另跑 Debug 构建、严格局部 lint、静态质量和工作流门禁。检查器接口/规则不变，原脚本回归照常运行；指定 Cursor verifier 缺失与历史缺口保持 partial，不重查认证或替代复核。不接真实仓储、文件、UI、执行或私密授权能力，完成后停在 2E-2B。

统一搜索 2F 沿 `areachain-workflow` → `areasong-development` 纯领域/架构路径 → `areachain-verify`。入口 TagQueryProvider 与旧目录共用 TagUsage.filteredValues，实际消费者见组件目录，唯一交接见[权威设计第 9.23 节](docs/unified-search-commands.md#923-阶段-2f活标签只读快照搜索提供者)。验证四套 TagQuery、旧标签目录/搜索、查询/页面/转交及各类提供者回归，另跑静态质量/脚本回归、工作流、严格局部 lint 和 Debug 构建；检查器接口/规则不变。指定 Cursor verifier 缺失保持 partial，不重查登录或替代复核；不接真实统计/仓储、生产 UI、聚合或写入，完成后停在 2F。

第四阶段 A 公共下拉沿 `areachain-workflow` → `areachain-ui` → `areachain-verify`；只接 ClipboardHistoryOptions 三处，公共接口 DaybookPicker / DaybookPickerOption 与集中几何见[组件目录](docs/component-catalog.md#第四阶段-a公共下拉选择器与剪贴板)。直接挂载生产页面/控件、复用 ClipboardOptionsFixture 及原展示；原生事件与菜单项动作派发分别取证。公共契约仍只交 Cursor verifier，不可用保留缺口；不继续普通设置、标签合并、自动锁定或分段切换。
