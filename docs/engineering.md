# 工程与维护

本页只保留工程手册主体：分层、生命周期覆盖、环境与依赖、质量门禁与 CI、发行与回退、恢复演练和运行维护；门禁命令的唯一来源是[质量门禁](quality-gates.md)。各阶段、控件收口与各批次的逐条验收记录不在本页，需要追溯时用 `git show 6bc1f72:docs/engineering.md` 查看原文；其他文档里提到的“第 x 阶段”验收记录都指该版本。

## 分层与适用范围

| 层 | 保存什么 | 不承担什么 |
|---|---|---|
| 个人通用规则/标准 | 需求与验收、风险授权、架构/复用、工程交付、可靠性/维护判据；由个人 AGENTS.md 按影响加载 | 不硬编码 AreaChain 命令，不强制所有项目同一种架构 |
| 通用开发 Skill | `areasong-development` 组织新功能和界面优化，引用适用标准 | 不接管单独诊断、重构、部署或技能配置任务 |
| 技术栈方法 | SwiftUI/AppKit/SwiftData、macOS 工具链与平台证据；适用专项技能补足方法 | Web/移动工具不能替代原生窗口、钥匙串或桌面发行验收 |
| 项目规则/技能 | 本页及已有项目文档给出实际支持范围；`areachain-workflow` 编排冷启动与交接，`areachain-ui` 处理项目界面，`areachain-verify` 选择和解释检查 | 不复制个人技能、不扩大真实系统操作授权 |
| 脚本/测试/CI | 确定性检查、隔离夹具及可重复命令；CI 接入后复用相同入口 | 不判断未决产品设计、不把本地通过变成远端门禁或正式发布 |

当前项目技能就是这三个：`areachain-workflow`、`areachain-ui`、`areachain-verify`。不为 Domain、发行、安装或诊断再拆技能。只有重复、多步骤且确需专项方法的工作才建立新 Skill；后续若新增必须接入 [技能路由](../skill-routing.md)、`.gitignore` 和 `check_workflow.py`。个人标准缺失时，项目自身文档与检查仍可使用；不得冒充个人技能已发现。

## 生命周期覆盖矩阵

各列独立：有规范 ≠ 有方法 ≠ 自动化已接入 ≠ 实际运行通过。“未运行”不是“不适用”。下表的本地测试存在仅指代码/入口已核实，不代表已运行通过；每次改动的实际验证按[质量门禁](quality-gates.md)另行记录。

| 生命周期环节 | 规范覆盖 | 可执行方法/来源 | 已自动化 | 已有验证层级 | 未覆盖或不适用 |
|---|---|---|---|---|---|
| 需求、范围与验收 | 已有全局/项目规则、通用开发技能 | 用户结果→入口/契约→适用验收；[产品与功能](features.md) | 需要判断，未自动判定需求 | 规则及引用检查 | 无已授权真实业务任务的全链路试跑 |
| 架构、依赖与状态 | 已有分层与责任/边界方法 | [架构边界](architecture.md#开发时的边界与状态核对)，沿符号追踪消费者 | Domain 导入守卫 | 源码核对与导入守卫 | 完整符号依赖图、所有权不由文本扫描证明 |
| 实现、共用代码与重构 | 已有原则与提取/等价判据 | 模块内→项目共享→跨项目库按实际收益选择；相关仓储/解析测试 | 本地行为测试与静态门禁可运行；远端执行未取证 | 测试与源码静态盘点 | 尚未以新标准完成真实重构；不强行提取跨项目库 |
| 界面、语言与交互 | 已有 en/zh-Hans、Daybook、输入/窗口约定 | [原生验收](architecture.md#隔离验收与真实启用门禁)、项目 UI/验证技能 | Theme/Features 隔离测试已有 | Theme/Features 隔离测试；未做原生 UI 操作验收 | 真实键盘/输入法/系统集成不可用离屏样例替代 |
| 环境、配置与依赖 | 已有环境下限、签名隔离与复现/升级判断 | 下文环境记录；核对工程、清单、来源/许可证、定向回归 | 部分构建配置检查；无工具链固定/CI | 实际版本查询、配置声明核对 | 尚无认证过的支持版本矩阵；无第三方包时不制造锁文件 |
| Git、评审与 CI | 已有变更纪律与分层门禁 | 下文检查顺序；跨模块只读复核只走 Claude Code `verifier`（见技能路由） | 本地检查与 `.github/workflows/quality.yml` 已接入；push/PR 跑静态和 macOS 编译+SwiftLint，完整 Swift 测试仍手动触发 | 本地门禁；静态 Actions 已有成功记录（见下文路线） | 完整 Swift 测试不在每次 push 上跑；分支保护仍只要求静态检查；管理员可绕过 |
| 测试、构建与验签 | 已有测试及签名脚本/隔离约束 | `quality_gate.py`（Swift 测试走隔离 `build.sh qa`）、构建/验签；见 [signing.md](signing.md) | 本地质量入口与脚本回归已接入 | 脚本测试通过；Swift 测试另有实际记录 | 编译/候选包/原生运行是独立证据，不等于发行 |
| 数据、迁移与恢复 | 已有事务/快照/加密边界与演练方法 | `ModelChangesTests`、`SnapshotImportValidationTests`、`PrivateBackupTests`、迁移夹具 | 有内存/临时磁盘测试 | 测试隔离性与断言静态核对 | 全历史升级、真实恢复、RPO/RTO 与应用进程被 SIGKILL 未验收；进程内 VACUUM 由进度回调中断覆盖语句中途失败/取消后的标记保留；独立 `sqlite3` SIGKILL 覆盖辅助进程被杀后库仍可读、随后 `finish` 成功 |
| 错误、并发与资源 | 已有部分实现与重试/取消/责任标准 | 日历 generation、事务后清理、草稿/窗口生命周期；按故障注入验证 | 对应局部测试已有 | 源码/测试静态核对 | 排程真实失败、生产等待时序和长期泄漏未覆盖完整 |
| 性能与成本 | 已有局部阈值与磁盘打开/大库重开/加密恢复上限 | 1000 天连击、行交互、空库打开、2000 条重开、合成加密恢复、测试进程 RSS 安全网与重开增长；见下文 | 登记测试已纳入 performance profile | LifecycleBaselineTests 与局部性能测试 | NSApplication 完整冷启动、独立 App 峰值内存、长期泄漏和真实恢复仍未建立 |
| 安全、隐私与供应链 | 已有高风险门禁/隐私隔离与维护标准 | 按变更范围安全审查、依赖公告/来源核对、日志字段检查 | 静态候选扫描已接入本地/静态 CI | 静态候选扫描；未做完整审计 | 仓库根 `LICENSE` 为 Apache-2.0；真实系统验收和完整漏洞审计仍待做 |
| 正式发行、安装与回退 | 已有本机构建/安装门禁与发行准备方法 | 下文发行准备；`distributionReady` 明确为 false | 候选验签/本体回退脚本；无公证/上传流水线 | 原脚本隔离测试，不是真实安装 | 渠道、许可证、Developer ID/公证、升级/发行验收未落实 |
| 运行诊断、故障处置 | 已有 StoreHealth/错误提示与最小诊断方法 | 本地脱敏取证→复现/定位→获准修复→回归 | 无统一诊断导出或监控管线 | 源码/流程静态核对 | 不自动加入云遥测；止损/恢复动作需独立授权 |
| 升级、废弃、反馈与文档 | 已有产品/架构文档与闭环责任 | 下文维护与决策；版本支持、消费者、回访条件 | 引用检查已有本地入口；维护决策非自动化 | 引用检查 | 尚无正式发布说明和全历史支持窗口；不自动创建工单/定时任务 |
| 云端账号、多租户、服务部署 | 产品当前明确不做 | [README 的边界](../README.md#明确不做) | 不适用 | 产品边界核对 | 当前无自建云端/计费；设置里的 iCloud 说明不代表已实现同步 |

## 环境、配置与依赖

- 最低要求以 [README](../README.md#构建与运行) 为准：macOS 14+、Xcode 16+、Python 3.9+。本机实际工具版本不是低版本兼容通过的证据。
- 工程中的 `SWIFT_VERSION = 5.0` 是语言模式，不是本机编译器版本。`MACOSX_DEPLOYMENT_TARGET = 14.0` 也不证明已在 macOS 14 真机运行。
- 当前工程未声明第三方 Swift Package 产品依赖，脚本使用 Python 标准库。未来引入依赖时才维护对应清单/锁文件，并核对传递依赖、构建脚本、许可证、平台和升级/回退；不为“工程化”添加空包配置。
- 配置隔离仍沿 `Config/Signing.xcconfig` 和未入库的个人配置；本手册及检查器不读取个人签名内容、凭据或用户数据库。实际构建/验签由签名工具按授权读取必要有效参数。
- 每次需要环境证据时在当前环境重新查询 `python3 --version`、`xcodebuild -version`、`xcrun swift --version`；构建证据还须关联源码、配置及产物，不只记录工具存在。
- 当前工程默认版本为 `1.0.0` / build `1`；在打上发行标签之前不把构建号当成发布史。仓库根 `LICENSE` 使用 Apache-2.0：本路线要求完成发行准备，而 AreaSong 已有软件仓库（AreaFlow、Relay-Lifeline、typesprint-Area）使用同一许可证。若要更换，替换该文件即可，不在这里同时保留第二份许可证。

## 本地质量门禁与 CI 接入边界

根据影响选择，不把下表变成每次必跑全集。所有命令从仓库根执行，默认不安装/启动应用。

| 改动/声明 | 本地入口 | 结果能证明什么 |
|---|---|---|
| 工作流文档、组件目录、Domain UI 依赖、项目技能格式与 Git 边界、单文件行数 | `python3 -B scripts/check_workflow.py` | 内联本地引用/锚点、工作流入口、稳定复用符号、显式 import、技能 frontmatter/`openai.yaml`、已共享技能和本地状态忽略边界、Features/Theme 的 theme-tokens 字面模式，以及 `AreaChain` / `AreaChainTests` 单文件不超过 500 行 |
| 本检查器改变 | `python3 -B -m unittest discover -s scripts/tests -p test_check_workflow.py -v` | 临时夹具的正/反例、作用域、输出与退出码；不是技能决策质量 |
| 构建/验签/管理/工作流脚本 | `python3 -B -m unittest discover -s scripts/tests -v`；改 Shell 时另做 `bash -n` | mock 外部命令和临时目录中的行为，不是真实安装、签名或恢复 |
| Swift 业务/接口/数据 | `python3 -B scripts/quality_gate.py --profile swift`（按改动推导，或 `--only-testing AreaChainTests/具体测试类`），走隔离 QA 分前台／后台轮；全量 `--profile full` 只在替换日常应用之前或用户明确要求时 | 实际执行且未跳过的用例；测试存在不能代替执行 |
| 编译或候选包 | 按 [签名文档](signing.md) 构建/验签 | 指定配置的产物，不证明原生运行或发行 |
| 原生 UI / 磁盘兼容 | 按 [架构隔离命令](architecture.md#隔离验收与真实启用门禁) 选择范围并串行 | 已走到的隔离场景；不可启用普通测试之外的真实钥匙串授权 |

`check_workflow.py` 仅用标准库和只读 Git 命令。支持 `--format json`（`schemaVersion: 1`）、`--root` 指定 AreaChain 工作副本；全部选定检查通过返回 0，失败/依赖阻塞返回 1，参数错误返回 2。输出区分 passed/failed/blocked 的检查项；不忽略依赖缺失后报成功。

`theme-tokens` 扫描 `AreaChain/Features` 和 `AreaChain/Theme` 的字面模式。同行有 `// control:` 或 `// token-exempt:` 则跳过。圆角已经写成 `DaybookRadius` 的形状，以及不带颜色名的视图显隐透明度，不报。它不证明界面看起来一致。

默认不扫描个人目录；本次确需验证个人规则时，显式加 `--personal-root <实际目录>`，范围只有该目录的 AGENTS、路由及自有 `areasong-development` 文档，不扫描其他技能/插件缓存。技能入口格式由本检查器的 `skill-format` 核对；受控新会话是否实际发现并调用技能仍是单独证据。

检查器不解析完整 Markdown/Swift 语法，不验证引用内容正确性、远端网页、宏生成依赖或所有源码符号；未用尖括号包裹的括号路径等特殊链接、Swift 正则字面量等语法仍需人工/编译补充。不能靠跳过真实缺陷维持绿灯。项目技能的入口、文档及其中显式链接的文件须 Git 可见，允许目录与现有 `.gitignore` 对齐；以后新增共享技能时须同时检查范围，不能放开整个 `.agents`。

合并前人工确认本次差异、适用测试和必需只读复核均有最终证据；未获授权不提交/推送。仓库已有质量工作流文件：无凭据的文档/脚本检查作为 push/PR 首层，macOS 编译/单测作为手动平台层，焦点敏感及真实系统验收另设受控门禁。工作流文件是否提交、runner 实际成功和远端 required checks 三者分开取证；本地不会擅自修改远端设置或凭据。

## 发行准备与回退

这里补的是准备方法，不实现或执行正式发行。当前 [signing.py](../scripts/signing.py) 仅支持 local/development，`distributionReady` 固定为 false；[app_manager.py](../scripts/app_manager.py) 的运行请求也不等于验收。

| 阶段 | 输入与执行方法 | 输出/通过证据 | 失败/授权边界 |
|---|---|---|---|
| 范围与渠道 | 版本保持 `1.0.0` / build `1`，直到打发行标签。许可证见仓库根 `LICENSE`（Apache-2.0）。支持下限仍是文档中的 macOS 14+，本机 macOS 26 的测试不是 14 的认证 | 渠道定为「可公证的本机分发」，但公证本身未执行 | Developer ID、公证上传和商店路线仍须另授权；`distributionReady` 保持 false |
| 候选物追溯 | 记录 revision、脏差异指纹、工具链/SDK、配置/权限、依赖及构建命令，生成候选物摘要 | 测试/验签记录能关联到确切包，而非仅关联 HEAD | 脏工作区可开发验证，不自动成为可发行版本；重建/签名后重核摘要及证据 |
| 本地候选验证 | 已有构建、Release 静态验签、适用测试及隔离 QA | 编译、测试、静态签名、运行场景分别给结果 | 此门禁通过仍不是 Developer ID、公证、正式安装或升级验收 |
| 渠道准备/执行 | 渠道确定后再落实对应身份、打包、公证/信任核对、变更说明与分发方法 | 渠道要求的实际返回结果、包摘要与版本记录 | 身份/权限改变、Apple 端资源、公证上传、发布均须另获明确授权；当前未实现 |
| 安装升级/发布后 | 在已授权的隔离目标核对首次安装、升级、冷启动、关键操作、系统解锁与数据/附件 | 实际运行和兼容证据；记录失败阶段与恢复路径 | 不拿日用应用试验，不因启动请求成功宣称已验收 |
| 回退 | 先判断旧程序是否可读当前数据，区分程序、数据、配置和凭据 | 原包可核验；数据恢复另有演练，含可能丢失的新数据及耗时 | 不兼容则停止降级；真实恢复/身份切换/回撤发布仍需确认 |

当前安装脚本保留的只是应用本体；它不创建完整数据备份。自动回退失败应保留原包位置并停止；新程序可能已写入数据时不能盲目再次启动旧版。具体参数和现有脚本行为继续以签名文档为准，不在本页创建第二套安装指令。

### 原应用缺失的同身份重装

安装目录缺失、私密锁配置仍存在时，安装脚本会拦截普通安装。此时可显式提供原包身份来源，复用候选验签、安装锁、暂存替换和失败回退；不自动选择历史包、不清理数据或改变签名。参数和历史归属限制集中在[签名文档](signing.md#原应用缺失时重装)，入口及测试索引见[组件目录](component-catalog.md#安装身份恢复入口)。

- 隔离回归覆盖显式同身份重装、各身份字段不一致、无参数仍阻止遗留锁重装、损坏或非受管原包、路径／权限／符号链接、备份改变／替换／消失、现用应用重新出现、取消、安装锁、失败恢复缺失状态及含空格的参数透传。外部命令均模拟，应用和用户资料使用临时合成目录。

## 数据与恢复演练

现有基础及边界：

- [ModelChangesTests](../AreaChainTests/Services/ModelChangesTests.swift) 和 [SnapshotImportValidationTests](../AreaChainTests/Services/SnapshotImportValidationTests.swift) 有事务/通知、坏输入及此前编辑保留检查。
- [SubtaskTagMigrationTests](../AreaChainTests/Services/SubtaskTagMigrationTests.swift) 使用临时旧库及已关闭目录备份；只冻结发生变化的两个实体，不能代表全部历史 schema，也不证明新库可被旧应用打开。
- [PrivacyMigrationTests](../AreaChainTests/Services/PrivacyMigrationTests.swift) 有合成磁盘迁移、冷清理和重开；[PrivateBackupTests](../AreaChainTests/Services/PrivateBackupTests.swift) 有换钥恢复、缺图/坏密码/篡改/保存失败、导出/恢复/附件暂存/标签转换取消等夹具。[PrivateBackupCancellationTests](../AreaChainTests/Services/PrivateBackupCancellationTests.swift) 把写入/回读取消分别卡在 HMAC 轮次中与派生返回后。[PrivacyStoreMaintenanceTests](../AreaChainTests/Services/PrivacyStoreMaintenanceTests.swift) 确认打开的库上 `request` 不会 VACUUM；`sqlite3_progress_handler` 在正在执行的 VACUUM 上返回 `SQLITE_INTERRUPT` 后标记保留、库仍可读、随后 `finish` 成功；任务取消走 `cancelled`；对独立 `sqlite3 VACUUM` 发 SIGKILL 后合成库仍可读、随后 `finish` 成功。缺库文件同样保留标记。备份文件写入取消也可卡在第二次附件回调（暂存写入），回读取消可卡在附件帧回调。备份口令派生走可中断 PBKDF2-HMAC-SHA256（每 2048 轮检查取消）；解锁仍用 CommonCrypto，派生前后再检查取消。杀死的是辅助 `sqlite3`，不是日用 AreaChain；进程内语句中断靠进度回调，不是 SIGKILL 测试宿主。fake 系统钥匙与内存库不等于真实系统认证或全流程灾难恢复。Phase1 测量不得写入 `/Library/Containers/`（含日用应用容器）。`build.sh test` 用测试专用 entitlements 关闭测试宿主沙盒；样本写到仓库 `build/phase1` 或 `TEST_RUNNER_AREACHAIN_PHASE1_LOG_DIR`（derivedData/phase1-logs），不得写入日用容器。在 Xcode 里用日用 entitlements 跑时若仍不可写，`PHASE1_LOG` 路径为 `-`，样本只留进程内存和 stderr。

下一次获准的数据/恢复任务按以下链路验收，先用合成数据：

1. 定义来源/目标程序与格式版本、七张表关联、附件、配置/密钥依赖、备份包含与排除项。普通 JSON 排除私密记录且无图片二进制，不能充当完整备份。
2. 确认恢复点目标 RPO（可接受损失窗口）和恢复时长目标 RTO；当前没有项目级承诺，不编造目标数字。
3. 在独立临时源与目标准备历史夹具，验证备份可读，再实际恢复、关闭重开，比较内容/标识/关联/图片及锁定行为；不得依赖原机残留文件形成伪成功。
4. 按改动加入适用的损坏、缺失、磁盘失败、中断、重复执行和不兼容版本检查；保留原件，确认部分失败状态和重试不重复副作用。
5. 报告真正覆盖的版本/失败点、耗时、数据差异和剩余风险。若旧程序不兼容新数据，明确只能从已验证备份恢复或前向修复。

真实迁移/恢复、加密流程/凭据变化、不可逆清理须先说明风险、验证与回退后确认；本手册的演练步骤不是实际数据操作授权。

## 运行可靠性与维护

### 已有行为与待补证据

- 日历协调通过代次与串行合并处理取消/迟到结果，局部提交失败保留基线供重试；相关 [CalendarSyncEngineTests](../AreaChainTests/Services/CalendarSyncEngineTests.swift) 使用 fake 外部服务，不证明真实 EventKit 写入。
- 草稿、窗口、附件已有生命周期/失败测试；普通测试仍跳过 400ms 驻留，[PendingCompletionTimingTests](../AreaChainTests/Features/PendingCompletionTimingTests.swift) 关闭跳过后覆盖单次、批量与减弱动态效果时序。这仍不是真人勾选的生产动画验收。
- [TaskRowInteractionTests](../AreaChainTests/Features/TaskRowInteractionTests.swift) 有行回调 100ms 阈值，[DayBoardPageProjectionTests](../AreaChainTests/Domain/DayBoardPageProjectionTests.swift) 有 40 个习惯加待办的页面投影 200ms 阈值（Debug、UTC、热身后 3 次取样取中位数），[HabitStreakEmpiricalTests](../AreaChainTests/Domain/HabitStreakEmpiricalTests.swift) 有 1000 天连续打卡 200ms 阈值（Debug、UTC、热身后 3 次取样取中位数），[HabitStreakEquivalenceTests](../AreaChainTests/Domain/HabitStreakEquivalenceTests.swift) 另有 10000 天空稀疏对照 NaiveCursor 的 200ms 上限；连击索引的产品 RSS 未建立。[LifecycleBaselineTests](../AreaChainTests/Services/LifecycleBaselineTests.swift) 另有空库打开 3000ms、2000 条重开 5000ms、合成加密恢复 8000ms，以及 2000 条重开时测试进程 RSS 安全网与 8 次重开增长上限。它们都是 `provisional`。RSS 条目测量的是 Debug 测试进程，不是独立 App 峰值；XCTest 下 AppDelegate 会提前返回，因此也不是 NSApplication 完整冷启动。已登记的局部 ID（含 `agenda-overdue-routines-1000-days`、`dayboard-month-unfinished`、`dashboard-heatmap-365`、`board-search-overdue-20x1000`、`catalog-listed-routines-40x365`）以 [`docs/performance-baselines.json`](performance-baselines.json) 为准，本段不另写预算。
- [NotificationScheduler](../AreaChain/Services/NotificationScheduler.swift) 的排程日志当前只保留请求标识、目录计数、授权状态和错误 domain/code，不输出任务标题、提醒分钟、具体触发时刻或原始错误描述；这不替代日志保留策略审查和完整安全审计。

### 诊断与反馈的方法

1. 从用户症状、准确版本、最近变化和影响范围收集最小脱敏证据；[StoreHealth](../AreaChain/Services/StoreHealth.swift) 和 [MutationFeedback](../AreaChain/Services/MutationFeedback.swift) 是现有入口，不能把它们当成完整诊断系统。
2. 区分输入/业务拒绝、暂时失败、权限/认证、完整性损坏和部分成功。只在安全幂等且预算明确时重试；权限失败或读库失败不能伪装为空数据继续写入。
3. 用合成数据、可注入时钟/系统接口和小范围测试验证假设。暂停服务、改配置、清理缓存/数据、恢复或修复都要符合当前授权；仅诊断不实施。
4. 将明确问题转成需求或缺陷，说明优先级/影响→获准修复→回归→获准交付→用户确认；无法复现、技术债和暂缓项记录理由、责任与重访条件，不默认创建外部工单。
5. 依赖/OS/工具链升级先查兼容与安全公告；废弃接口/功能前查消费者与历史数据。影响架构/公共契约的决定就地记录，发布时再维护实际版本说明，不为每个小任务创建 PRD/ADR。

本地应用默认采用本地脱敏诊断；不自动引入遥测、云监控、日志上传或定时巡检。安全问题的审查范围、外部披露与修复/发布分别授权。

## 整项目优化路线

这是仓库里唯一的整项目推进顺序，W0–W8 已落地并作为历史记录。日常任务不使用 `.cursor/plans/`；该目录已从仓库删除，本地草稿也不提交。个人会话里的 Plan Mode 或额外计划文件不得平行于本节。

| 波次 | 内容 | 退出前必须有的证据 |
|---|---|---|
| W0 | 治理收口：指令优先级、单一复核入口、技能链接、计划状态回写 | `check_workflow.py` 与静态质量门禁 |
| W1 | 证据闸：`main` 的静态 required check；说清 `quality_gate.py` 的 auto 与 swift | 已设置：`main` 要求 `Static quality gates`（不强制评审、管理员可绕过）。真实 push 证据为 run `36222371946` |
| W2 | 阶段八与运行态走查合并为一次隔离原生验收 | 隔离 QA 标识下的宿主、语言、主题、窗口和输入证据 |
| W3 | 结构摸底（excellence S0） | 试点后的全量问题清单、决定位置和复用积木 |
| W4 | 定标准（excellence S1），含已确认的设计系统基准 | 用户确认记录；确认前不删设计系统基准计划 |
| W5 | 按模块重构且行为不变（excellence S2） | 每模块独立验收 |
| W6 | 把重复问题沉淀进检查器、测试和组件目录（excellence S3） | 检查器与目录同步 |
| W7 | 结构冻结后只增量修补工作流（excellence S5） | 路由检查仍通过 |
| W8 | 发行准备：许可证、版本与渠道说明、本地 Release 验签 | 许可证文本已选定再入库；未公证不等于已发布 |

真实钥匙串、系统日历、真实用户库、安装到日用应用、公证上传和修改个人签名配置不在上表自动执行，每次另获授权。

`AreaChain Quality` 的 push 静态 job 有成功记录（例如 run `36222371946`，检查名 `Static quality gates`）。`main` 的分支保护只要求该静态检查，不要求评审，且不强制管理员遵守（避免检查名错误时锁死仓库）；它约束合并进 `main` 的 pull request，管理员直接 push 仍可绕过。push/PR 另跑 macOS 编译与 SwiftLint，完整 Swift 测试只能手动触发（`workflow_dispatch`）。技能格式由 `check_workflow.py` 的 `skill-format` 检查，不依赖本机 Skill Creator。

干净工作区运行 `python3 -B scripts/quality_gate.py`（profile `auto`）只会选择 `static`，因为没有文件差异。Swift 源码改动必须显式使用 `--profile swift`，不能把 auto 在干净树上的通过写成 Swift 已测。

结构标准（W3–W7，沿用已确认的菜单栏视觉基准，不新开一套）：

- 单文件超过 500 行才拆文件，由 `check_workflow.py` 的 `swift-file-size` 守住。
- `LiveComposerPreviewHeader` 与 `LiveDiaryComposerPreview` 继续作为 Theme 历史例外，不新增消费者，本路线不迁移。
- 生产搜索只保留工作台顶栏和菜单栏底栏；无入口的独立搜索页已删除，测试改嵌相同的 `SyntaxInputContext.search` 夹具。
- 全库扫描没有发现第二套日期、筛选或保存入口需要在本路线里合并。磁盘打开/大库重开/合成加密恢复已有 Debug 上限；测试进程 RSS 安全网与重开增长已登记。NSApplication 完整冷启动、独立 App 峰值内存、真实恢复和真实日历仍按原缺口保留。
