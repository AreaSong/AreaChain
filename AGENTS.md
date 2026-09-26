# AreaChain 项目协作约定

本文件适用于本仓库，在全局与当前会话约束基础上补充项目事实和验证入口，不扩大操作授权。只检查本次变更相关的约定；改变已有产品边界时先说明并按风险分级处理。

本仓库与个人会话规则冲突时，以本文件和 [技能路由](skill-routing.md) 为准。日常任务不把 `.cursor/plans` 当项目路线：不读取、不写入、不提交该目录；Cursor 若在本地生成草稿，忽略它，不把它当任务清单。整项目优化只沿 [工程手册](docs/engineering.md) 的已完成路线作为历史记录，不再另开总任务执行器。

## 开发技能分层

- **项目级工作流编排**：[areachain-workflow](.agents/skills/areachain-workflow/SKILL.md) 负责冷启动定界、上下文加载、复用检索、技能衔接和交付交接；不替代实现或验收技能。
- **个人级通用流程**：已发现的 `areasong-development` 组织新功能与界面优化的需求、风险和交付，提供跨项目质量判据。
- **项目级原生界面**：[areachain-ui](.agents/skills/areachain-ui/SKILL.md) 负责本仓库的双语、Daybook 样式、原生输入和窗口契约应用。
- **项目级验证**：[areachain-verify](.agents/skills/areachain-verify/SKILL.md) 根据改动范围选择项目测试、构建和隔离验收，并报告真实证据与缺口。
- 本文件和原有项目文档保留具体事实；[技能路由](skill-routing.md) 负责选择顺序，[共享组件与复用目录](docs/component-catalog.md) 负责可复用入口索引。技能引用这些来源，不复制通用技能或另建相互矛盾的规范。专项技能仍按触发要求协作，不扩大操作授权。
- 按当前会话实际发现的技能使用；项目技能缺失时说明并按现有文档/脚本完成允许部分，不自动安装或冒充调用。仅项目专用技能目录纳入版本管理，其他 `.agents` 本地状态继续忽略。仓库只维护上述三个项目技能，不为 Domain、发行、安装或诊断再拆技能。

## 按任务读取上下文

- 所有新对话先读 [技能路由](skill-routing.md)；新增控件、公共规则或界面时再读 [共享组件与复用目录](docs/component-catalog.md)，并沿实际调用方核对，不只按名称猜测。
- 入口、环境要求和命令见 [README.md](README.md)；产品范围见 [docs/product.md](docs/product.md) 与 [docs/features.md](docs/features.md)。
- 界面、快捷键和保存行为见 [docs/usage.md](docs/usage.md)；分层、数据与隔离验收见 [docs/architecture.md](docs/architecture.md)。
- 开发全生命周期的覆盖状态、工程环境、质量门禁、发行准备及恢复/维护方法见 [docs/engineering.md](docs/engineering.md) 与 [docs/quality-gates.md](docs/quality-gates.md)；通用标准由全局规则按需引用，项目手册只保存本项目证据、入口和缺口。
- 触及构建、签名、安装或系统解锁时先读 [docs/signing.md](docs/signing.md)。不要把安装、启动或真实认证当作普通检查的隐含步骤。
- 文档与实现有差异时先核对相关代码和测试，说明现状与目标；不凭单一旧说明扩大权限或修改无关行为。

### 白话请求默认行为

- 用户不需要在对话中提供技能名、文件路径或额外的“冷启动/复用”提示词；只要当前工作目录是本仓库，代理就应自行读取本节规定的项目入口。
- 当用户用白话说“读取当前项目”“看看任务页”“调整这个页面”或“新增一个类似的功能”时，代理先根据请求定位相关 Feature、Domain、Services、Theme 和测试，再建立最小影响/复用表；不要要求用户先把路径或流程翻译成技术术语。
- 只有在多个候选入口会导致不同实现范围、权限边界或不可逆影响时，才向用户提出澄清；普通的代码定位、组件检索和技能衔接由代理自行完成。
- 用户未要求实现时只阅读并报告现状；用户明确要求修改时，沿同一冷启动、复用和验证闭环继续执行。

## 新任务闭环

- 修改前先判断任务类型，检查工作区状态，并建立最小影响/复用表；没有完成复用检索，不先新增控件、领域规则、保存入口或平行状态。
- 实施沿现有 `Domain → Services → Features → Theme` 责任方向进行；任务、手记、搜索、菜单栏和独立窗口的外观可以复用，提交、快捷键、隐私和草稿语义必须分别核对。
- 修改后按影响选择验证：默认运行 `python3 -B scripts/quality_gate.py`；规则/技能/文档仍需 `python3 -B scripts/check_workflow.py`，Swift/UI 交给项目验收技能选择定向测试和构建。共享契约或跨模块行为变化只走一个复核入口：Cursor `verifier` 做只读核对，测试、构建和隔离原生交给 [areachain-verify](.agents/skills/areachain-verify/SKILL.md)。
- 交付时明确区分已实现、已验证、已安装、已发布、跳过、未运行和残余风险；旧测试结果、代码存在或构建成功不能单独宣称完成。
- 新增或改变公共组件、路由、技能或验证入口时，必须同步维护 [技能路由](skill-routing.md)、[组件目录](docs/component-catalog.md)、相关文档和检查脚本测试。

## 代码质量与安全默认门禁

- 注释解释原因、不变量、平台限制或安全边界，不重复代码；`TODO`/`FIXME`/静态检查豁免必须有可追踪原因。
- 质量、安全和性能的统一入口是 [质量门禁](docs/quality-gates.md)；不要为单个任务复制一套私有检查脚本或把警告写成通过。
- 涉及用户正文、附件、密码、令牌、钥匙串、外部响应或通知内容时，先检查日志和测试产物是否泄露；疑似高置信秘密必须阻断。
- 性能数字必须关联数据规模、环境、冷/热状态和测量方法；没有基线时报告未建立，不猜测产品预算。

## 技术与分层

- 这是原生 macOS 应用，使用 SwiftUI、AppKit 和 SwiftData，不是 Web 前端。界面技能与验证工具须适配原生平台，网页截图不能证明原生界面已通过验收。
- [AreaChain/Domain](AreaChain/Domain) 放领域模型与规则，不引入 SwiftUI/AppKit；模型可使用 SwiftData。系统 IO、持久化和平台集成在 [AreaChain/Services](AreaChain/Services)，界面组合在 [AreaChain/Features](AreaChain/Features)，共享视觉在 [AreaChain/Theme](AreaChain/Theme)。
- 复用已有领域规则、仓储及变更入口，不在多个页面复制解析、过滤和保存逻辑。不要为了新增一个实现建立额外接口或框架。
- Xcode 使用文件系统同步组；常规新增 Swift 文件放入对应源码或测试目录，不因添加文件而机械改写工程配置。

## 原生界面任务的技能协作

- 界面任务按当前技能触发要求使用 `ui-ux-pro-max` 等适用能力；局部问题做聚焦检索，实现建议按 `swiftui` 检索。返回结果仍需核对 macOS 适用性，不能因 iOS 示例建议就重写现有 AppKit 输入、焦点或窗口管理。
- 需要新 UI 或视觉重塑时，适用的 `frontend-design` 以本项目已有风格为约束，与 UI/UX 检查共用同一方案；调整文案、间距或局部交互不自动重建全应用设计系统。
- 浏览器技能只用于实际 Web/Electron 任务或对应外部网页；本应用界面的验收走下文原生验证入口。缺少某个 REPL、MCP 或设计工具时说明缺口，不改工程技术栈、全局开关或签名来迁就工具。

## 语言与界面一致性

- 已支持英文 `en` 与简体中文 `zh-Hans`。可见文案维护在 [Localizable.xcstrings](AreaChain/Resources/Localizable.xcstrings)，遵循 [L10n.swift](AreaChain/Domain/L10n.swift) 和 [AppPreferences.swift](AreaChain/Services/AppPreferences.swift) 的语言选择与格式化方式；机器字段、稳定标识和用户正文不随翻译改变。
- 新增或修改文案时同时核对两种语言，以及相关提示、错误、占位符和可访问性标签；检查格式参数和长文本布局。语言资源已有无关缺口时单独说明，不顺手全量重写。
- 复用 [DaybookPalette.swift](AreaChain/Theme/DaybookPalette.swift)、[DaybookMetrics.swift](AreaChain/Theme/DaybookMetrics.swift)、[DaybookTokens.swift](AreaChain/Theme/DaybookTokens.swift) 中的语义色、尺寸、字号、圆角、间距令牌与已有共享组件。菜单栏、工作台与手记小窗共用同一套令牌与外观；工作台只在 [WorkspaceLayout.swift](AreaChain/Theme/WorkspaceLayout.swift) 保留页头、侧栏与内容宽度等布局尺寸，并用 `workspaceEmbedded` 环境值表达"有无侧栏/页头"这类能力差异，不得用它切换颜色、字体或尺寸。
- 受影响界面检查中英文、浅深色、正常与最小支持窗口；共享组件覆盖其相关宿主。动效遵守系统减弱动态效果，操作保留键盘、焦点、输入法组合文本和撤销能力。
- 输入外壳统一用 `DaybookInputShell`（composer / search / editor 三种 kind，尺寸可用 configure 重载，颜色不可），正文控件复用现有 `DaybookTextField`、`DaybookTextEditor`、`SyntaxTextField`、`SyntaxTextEditor`。新增、搜索、标题编辑和手记保存有各自语义，不以统一外观为由改变 Return、⌘Return、Esc 或失焦行为。

## 输入输出与数据约定

- 新功能沿输入、解析/校验、领域规则、仓储/事务、展示与反馈追踪；新增字段、状态或筛选条件只检查真实受影响的列表、详情、搜索、导入导出及系统集成。
- 复用 [NaturalLanguageParser.swift](AreaChain/Domain/NaturalLanguageParser.swift)、[TagSyntax.swift](AreaChain/Domain/TagSyntax.swift) 与现有标签解析入口。剪贴板捕获保留原文、只解析标签，与普通任务输入不同；搜索不能创建标签。这些是产品约定，不是待统一消除的差异。
- 日期键遵循 [DayKey.swift](AreaChain/Domain/DayKey.swift) 的民事日期语义；快照日期遵循 [ExportDates.swift](AreaChain/Domain/ExportDates.swift) 的编码与旧格式兼容。不要把本地日期、提醒时刻和时间戳互相替换。
- 保存复用 [ModelChanges.swift](AreaChain/Services/ModelChanges.swift) 的事务与失败处理；只有保存成功才发布变更。失败不能清掉唯一草稿或虚报保存成功；本地保存、通知排程和日历同步分开判断结果。
- 模型、软删除、子任务及附件归属、快照兼容和隐私投影遵守架构文档；相关语义变化交给 Cursor `verifier` 做只读复核，不直接操作真实用户库来验证。

## 按影响选择验证

- 仅改文档、协作规则、技能或组件目录：检查差异、引用路径、规则冲突与适用场景，运行 `python3 -B scripts/check_workflow.py`（含技能格式），不因此运行整套应用或安装流程。
- 文档/技能引用、Domain 显式 UI 导入或项目技能共享边界受影响时，运行 `python3 -B scripts/check_workflow.py`；修改该检查器时运行其定向测试及 `scripts/tests` 回归。该脚本不读取个人配置、不启动应用，也不证明完整依赖图、技能发现或远端 CI 通过，详见工程手册。
- Swift 变更：先选相关测试，并按共享层和调用方影响扩大范围；需要编译验证时运行 `./scripts/build.sh`。此命令只构建并验签 Debug，不安装、不启动，也不替代运行验收。
- 定向测试示例：`./scripts/build.sh test --only-testing AreaChainTests/DayBoardLogicTests`，按实际变更替换测试类；需要全量回归时运行 `./scripts/build.sh test`。普通测试不得启用真实钥匙串授权。
- 构建、签名或应用管理脚本变更：运行 `python3 -B -m unittest discover -s scripts/tests -v`，Shell 脚本另做语法检查。这些隔离测试不代替真实安装、系统认证或恢复验收。
- 样式与交互分别选择 [AreaChainTests/Theme](AreaChainTests/Theme) 和 [AreaChainTests/Features](AreaChainTests/Features) 的相关测试，例如 `DaybookTokenTests`、`WorkspaceLayoutTests`、`WorkspaceRenderingTests`、`InputSyntaxInteractionTests`；不能只做编译就宣布界面通过。
- 原生窗口验证先读 [架构文档的隔离验收说明](docs/architecture.md#隔离验收与真实启用门禁)，采用独立 QA 标识、隔离构建目录和内存/临时数据，保持测试串行。焦点敏感测试期间不要同时操纵其他窗口；截图查看与交互执行分开，不能用跳过焦点断言消除失败。
- 最终列出实际运行的检查和未覆盖项；相关编辑后重跑受影响检查，不把旧结果作为新改动的通过证据。

## 系统集成与交付边界

- 涉及私密锁、签名身份、钥匙串权限的变更，真实数据转换或真实钥匙串/系统日历写入，须按高风险边界先确认；普通验证使用合成数据和隔离环境，不读取真实手记、附件或凭据来凑测试材料。
- `./scripts/build.sh release` 只生成并验签候选包，不自动运行测试，不表示完成公证或发布。安装、卸载、启动、Apple 端签名资源写入均不是代码修改的默认后续动作。
- `scripts/install.sh`、`scripts/uninstall.sh` 和 `--allow-provisioning` 的使用须符合本次明确授权；不能把 `--yes` 当作绕过用户确认的办法。应用本体回退与数据备份不是同一件事，完整门禁以签名文档为准。
- 未经明确授权不修改个人签名配置；个人签名配置、构建产物、真实数据和验收凭据不提交。项目无云端账号，iCloud 开关目前仅保存偏好；新增功能不能据此假设云同步已实现。
