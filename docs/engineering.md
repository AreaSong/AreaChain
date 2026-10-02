# 工程与维护

这是 AreaChain 的开发协作与交付手册，不是应用使用说明，也不表示各阶段已全部验收。产品边界见 [product.md](product.md)，运行行为见 [usage.md](usage.md)，架构/数据及隔离要求见 [architecture.md](architecture.md)，签名/安装操作以 [signing.md](signing.md) 为准。本页只维护工程入口、证据状态和实际缺口，不复制上述规范。

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

状态快照：2026-09-26。各列独立：有规范 ≠ 有方法 ≠ 自动化已接入 ≠ 实际运行通过。“未运行”不是“不适用”。下表的本地测试存在仅指代码/入口已核实，不复用历史测试结果；本批实际命令见文末。

| 生命周期环节 | 规范覆盖 | 可执行方法/来源 | 已自动化 | 本批实际验证层级 | 未覆盖或不适用 |
|---|---|---|---|---|---|
| 需求、范围与验收 | 已有全局/项目规则、通用开发技能 | 用户结果→入口/契约→适用验收；[产品](product.md)、[功能](features.md) | 需要判断，未自动判定需求 | 规则及引用检查 | 无已授权真实业务任务的全链路试跑 |
| 架构、依赖与状态 | 已有分层；本批补责任/边界方法 | [架构边界](architecture.md#开发时的边界与状态核对)，沿符号追踪消费者 | 本批增加 Domain 导入守卫 | 源码核对；守卫结果见文末 | 完整符号依赖图、所有权不由文本扫描证明 |
| 实现、共用代码与重构 | 已有原则；本批补提取/等价判据 | 模块内→项目共享→跨项目库按实际收益选择；相关仓储/解析测试 | 本地行为测试与静态门禁可运行；远端执行未取证 | 测试与源码静态盘点 | 尚未以新标准完成真实重构；不强行提取跨项目库 |
| 界面、语言与交互 | 已有 en/zh-Hans、Daybook、输入/窗口约定 | [原生验收](architecture.md#隔离验收与真实启用门禁)、项目 UI/验证技能 | Theme/Features 隔离测试已有 | 本批全量 Swift 测试通过；未做原生 UI 操作验收 | 真实键盘/输入法/系统集成不可用离屏样例替代 |
| 环境、配置与依赖 | 已有环境下限与签名隔离；本批补复现/升级判断 | 下文环境记录；核对工程、清单、来源/许可证、定向回归 | 部分构建配置检查；无工具链固定/CI | 实际版本查询、配置声明核对 | 尚无认证过的支持版本矩阵；无第三方包时不制造锁文件 |
| Git、评审与 CI | 已有变更纪律；本批补分层门禁 | 下文检查顺序；跨模块只读复核只走 Cursor `verifier` | 本地检查与 `.github/workflows/quality.yml` 已接入；push/PR 跑静态和 macOS 编译+SwiftLint，完整 Swift 测试仍手动触发 | 本地证据见文末；静态 Actions 成功记录见 2026-09-26 路线说明 | 完整 Swift 测试不在每次 push 上跑；分支保护仍只要求静态检查；管理员可绕过 |
| 测试、构建与验签 | 已有测试及签名脚本/隔离约束 | `quality_gate.py`、`build.sh test`、构建/验签；见 [signing.md](signing.md) | 本地质量入口与脚本回归已接入 | 脚本测试通过；Swift 测试另有实际记录 | 编译/候选包/原生运行是独立证据，不等于发行 |
| 数据、迁移与恢复 | 已有事务/快照/加密边界；本批补演练方法 | `ModelChangesTests`、`SnapshotImportValidationTests`、`PrivateBackupTests`、迁移夹具 | 有内存/临时磁盘测试 | 测试隔离性与断言静态核对 | 全历史升级、真实恢复、RPO/RTO 与应用进程被 SIGKILL 未验收；进程内 VACUUM 由进度回调中断覆盖语句中途失败/取消后的标记保留；独立 `sqlite3` SIGKILL 覆盖辅助进程被杀后库仍可读、随后 `finish` 成功 |
| 错误、并发与资源 | 已有部分实现；本批补重试/取消/责任标准 | 日历 generation、事务后清理、草稿/窗口生命周期；按故障注入验证 | 对应局部测试已有 | 源码/测试静态核对 | 排程真实失败、生产等待时序和长期泄漏未覆盖完整 |
| 性能与成本 | 已有局部阈值；本批补磁盘打开/大库重开/加密恢复上限 | 1000 天连击、行交互、空库打开、2000 条重开、合成加密恢复、测试进程 RSS 安全网与重开增长；见下文 | 登记测试已纳入 performance profile | 本批 LifecycleBaselineTests 与既有局部测试通过 | NSApplication 完整冷启动、独立 App 峰值内存、长期泄漏和真实恢复仍未建立 |
| 安全、隐私与供应链 | 已有高风险门禁/隐私隔离；本批补维护标准 | 按变更范围安全审查、依赖公告/来源核对、日志字段检查 | 静态候选扫描已接入本地/静态 CI | 本批扫描高风险 0、敏感日志候选 0；未做完整审计 | 仓库根 `LICENSE` 为 Apache-2.0；真实系统验收和完整漏洞审计仍待做 |
| 正式发行、安装与回退 | 已有本机构建/安装门禁；本批补发行准备 | 下文发行准备；`distributionReady` 明确为 false | 候选验签/本体回退脚本；无公证/上传流水线 | 原脚本隔离测试，不是真实安装 | 渠道、许可证、Developer ID/公证、升级/发行验收未落实 |
| 运行诊断、故障处置 | 已有 StoreHealth/错误提示；本批补最小诊断方法 | 本地脱敏取证→复现/定位→获准修复→回归 | 无统一诊断导出或监控管线 | 源码/流程静态核对 | 不自动加入云遥测；止损/恢复动作需独立授权 |
| 升级、废弃、反馈与文档 | 已有产品/架构文档；本批补闭环责任 | 下文维护与决策；版本支持、消费者、回访条件 | 引用检查已有本地入口；维护决策非自动化 | 引用/场景复核见文末 | 尚无正式发布说明和全历史支持窗口；不自动创建工单/定时任务 |
| 云端账号、多租户、服务部署 | 产品当前明确不做 | [README 的边界](../README.md#明确不做) | 不适用 | 产品边界核对 | 当前无自建云端/计费；设置里的 iCloud 说明不代表已实现同步 |

## 环境、配置与依赖

- 最低要求以 [README](../README.md#构建与运行) 为准：macOS 14+、Xcode 16+、Python 3.9+。本批实际查询为 Xcode 26.6（17F113）、Apple Swift 6.3.3、Python 3.9.6；这不是低版本兼容通过的证据。
- 工程中的 `SWIFT_VERSION = 5.0` 是语言模式，不是本机编译器版本。`MACOSX_DEPLOYMENT_TARGET = 14.0` 也不证明已在 macOS 14 真机运行。
- 当前工程未声明第三方 Swift Package 产品依赖，脚本使用 Python 标准库。未来引入依赖时才维护对应清单/锁文件，并核对传递依赖、构建脚本、许可证、平台和升级/回退；不为“工程化”添加空包配置。
- 配置隔离仍沿 `Config/Signing.xcconfig` 和未入库的个人配置；本手册及检查器不读取个人签名内容、凭据或用户数据库。实际构建/验签由签名工具按授权读取必要有效参数。
- 每次需要环境证据时在当前环境重新查询 `python3 --version`、`xcodebuild -version`、`xcrun swift --version`；构建证据还须关联源码、配置及产物，不只记录工具存在。
- 当前工程默认版本为 `0.1.0` / build `1`；在打上发行标签之前不把构建号当成发布史。仓库根 `LICENSE` 使用 Apache-2.0：本路线要求完成发行准备，而 AreaSong 已有软件仓库（AreaFlow、Relay-Lifeline、typesprint-Area）使用同一许可证。若要更换，替换该文件即可，不在这里同时保留第二份许可证。

## 本地质量门禁与 CI 接入边界

根据影响选择，不把下表变成每次必跑全集。所有命令从仓库根执行，默认不安装/启动应用。

| 改动/声明 | 本地入口 | 结果能证明什么 |
|---|---|---|
| 工作流文档、组件目录、Domain UI 依赖、项目技能格式与 Git 边界、单文件行数 | `python3 -B scripts/check_workflow.py` | 内联本地引用/锚点、工作流入口、稳定复用符号、显式 import、技能 frontmatter/`openai.yaml`、已共享技能和本地状态忽略边界、Features/Theme 的 theme-tokens 字面模式，以及 `AreaChain` / `AreaChainTests` 单文件不超过 500 行 |
| 本检查器改变 | `python3 -B -m unittest discover -s scripts/tests -p test_check_workflow.py -v` | 临时夹具的正/反例、作用域、输出与退出码；不是技能决策质量 |
| 构建/验签/管理/工作流脚本 | `python3 -B -m unittest discover -s scripts/tests -v`；改 Shell 时另做 `bash -n` | mock 外部命令和临时目录中的行为，不是真实安装、签名或恢复 |
| Swift 业务/接口/数据 | 按项目验证技能选择 `./scripts/build.sh test --only-testing AreaChainTests/具体测试类` | 实际执行且未跳过的用例；测试存在不能代替执行 |
| 编译或候选包 | 按 [签名文档](signing.md) 构建/验签 | 指定配置的产物，不证明原生运行或发行 |
| 原生 UI / 磁盘兼容 | 按 [架构隔离命令](architecture.md#隔离验收与真实启用门禁) 选择范围并串行 | 已走到的隔离场景；不可启用普通测试之外的真实钥匙串授权 |

`check_workflow.py` 仅用标准库和只读 Git 命令。支持 `--format json`（`schemaVersion: 1`）、`--root` 指定 AreaChain 工作副本；全部选定检查通过返回 0，失败/依赖阻塞返回 1，参数错误返回 2。输出区分 passed/failed/blocked 的检查项；不忽略依赖缺失后报成功。

`theme-tokens` 扫描 `AreaChain/Features` 和 `AreaChain/Theme` 的字面模式。同行有 `// control:` 或 `// token-exempt:` 则跳过。圆角已经写成 `DaybookRadius` 的形状，以及不带颜色名的视图显隐透明度，不报。它不证明界面看起来一致。

默认不扫描个人目录；本次确需验证个人规则时，显式加 `--personal-root <实际目录>`，范围只有该目录的 AGENTS、路由及自有 `areasong-development` 文档，不扫描其他技能/插件缓存。技能入口格式由本检查器的 `skill-format` 核对；受控新会话是否实际发现并调用技能仍是单独证据。

检查器不解析完整 Markdown/Swift 语法，不验证引用内容正确性、远端网页、宏生成依赖或所有源码符号；未用尖括号包裹的括号路径等特殊链接、Swift 正则字面量等语法仍需人工/编译补充。不能靠跳过真实缺陷维持绿灯。项目技能的入口、文档及其中显式链接的文件须 Git 可见，允许目录与现有 `.gitignore` 对齐；以后新增共享技能时须同时检查范围，不能放开整个 `.agents`。

合并前人工确认本次差异、适用测试和必需只读复核均有最终证据；未获授权不提交/推送。当前工作区已加入质量工作流文件：无凭据的文档/脚本检查作为 push/PR 首层，macOS 编译/单测作为手动平台层，焦点敏感及真实系统验收另设受控门禁。工作流文件是否提交、runner 实际成功和远端 required checks 三者分开取证；本地不会擅自修改远端设置或凭据。

## 发行准备与回退

这里补的是准备方法，不实现或执行正式发行。当前 [signing.py](../scripts/signing.py) 仅支持 local/development，`distributionReady` 固定为 false；[app_manager.py](../scripts/app_manager.py) 的运行请求也不等于验收。

| 阶段 | 输入与执行方法 | 输出/通过证据 | 失败/授权边界 |
|---|---|---|---|
| 范围与渠道 | 版本保持 `0.1.0` / build `1`，直到打发行标签。许可证见仓库根 `LICENSE`（Apache-2.0）。支持下限仍是文档中的 macOS 14+，本机 macOS 26 的测试不是 14 的认证 | 渠道定为「可公证的本机分发」，但公证本身未执行 | Developer ID、公证上传和商店路线仍须另授权；`distributionReady` 保持 false |
| 候选物追溯 | 记录 revision、脏差异指纹、工具链/SDK、配置/权限、依赖及构建命令，生成候选物摘要 | 测试/验签记录能关联到确切包，而非仅关联 HEAD | 脏工作区可开发验证，不自动成为可发行版本；重建/签名后重核摘要及证据 |
| 本地候选验证 | 已有构建、Release 静态验签、适用测试及隔离 QA | 编译、测试、静态签名、运行场景分别给结果 | 此门禁通过仍不是 Developer ID、公证、正式安装或升级验收 |
| 渠道准备/执行 | 渠道确定后再落实对应身份、打包、公证/信任核对、变更说明与分发方法 | 渠道要求的实际返回结果、包摘要与版本记录 | 身份/权限改变、Apple 端资源、公证上传、发布均须另获明确授权；当前未实现 |
| 安装升级/发布后 | 在已授权的隔离目标核对首次安装、升级、冷启动、关键操作、系统解锁与数据/附件 | 实际运行和兼容证据；记录失败阶段与恢复路径 | 不拿日用应用试验，不因启动请求成功宣称已验收 |
| 回退 | 先判断旧程序是否可读当前数据，区分程序、数据、配置和凭据 | 原包可核验；数据恢复另有演练，含可能丢失的新数据及耗时 | 不兼容则停止降级；真实恢复/身份切换/回撤发布仍需确认 |

当前安装脚本保留的只是应用本体；它不创建完整数据备份。自动回退失败应保留原包位置并停止；新程序可能已写入数据时不能盲目再次启动旧版。具体参数和现有脚本行为继续以签名文档为准，不在本页创建第二套安装指令。

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

## 本批证据与后续批次

本批主要修改规则、文档、技能引用和本地检查器，并修复 `NotificationScheduler` 的敏感日志字段；签名配置、构建/安装实现和数据模型保持不动。交接中的 173 项 AppKit 样例断言及历史发现记录不作为本批或真实 AreaChain 业务联动验收。

- `python3 -B scripts/check_workflow.py --personal-root /Users/as/.codex --format json` 通过：16 份项目文档、41 个 Domain 文件、9 份个人文档及项目技能 Git 边界。个人目录是本次显式输入，不是脚本默认值；这是静态检查证据。后续 Domain 文件数以当时 `check_workflow.py` 的 `domain-imports.checked` 为准（2026-09-29 为 47）。
- `python3 -B -m unittest discover -s scripts/tests -p test_check_workflow.py -v`：当时 46 项通过；`python3 -B -m unittest discover -s scripts/tests -v`：当时 165 项通过。原脚本外部命令为 mock，工作流反例使用临时文档/代码/Git 仓库，不操作日用应用或真实数据。2026-09-29 静态盘点为 `test_check_workflow.py` 49 项、全套 `scripts/tests` 169 项；以当时实际 discover 结果为准。
- 当前会话 Skill Creator 的 `quick_validate.py` 对项目级 `areachain-workflow`、`areachain-ui`、`areachain-verify` 均通过；三个 `agents/openai.yaml` 解析与元数据约束通过，隐式调用策略未改变。该批之后技能格式改由仓库内 `skill-format` 检查，不再依赖本机 Skill Creator。
- Skill Creator 校验只证明项目技能的结构、元数据和引用可解析；新对话是否自动发现并实际调用技能仍需在对应客户端会话中单独取证，不能由本地文件存在推断。
- 独立只读检查器复核发现引用文件 Git 漏检（含被忽略的符号链接）、Swift 插值误报、个人锚点读取范围及 Git 解码异常，主代理先复现再修正/回测；另完成诊断、新功能方案、发行判断、复用评估和降级恢复五个静态场景推演。旧使用文档中“一律恢复备份”的回退表述已与兼容性/授权门禁对齐。
- `git diff --check` 通过。以上是本批快照；后续相关编辑须重新取得受影响证据，不能永久沿用本页的通过状态。
- Swift 全量/定向测试、原生 UI、真实钥匙串、真实日历、恢复/安装、候选包构建与正式发行不由静态证据替代；本批全量 Swift 测试已由质量门禁实际运行并通过，原生 UI 及其余真实系统层级仍未执行。

| 批次 | 价值与当前状态 | 下一步所需条件 |
|---|---|---|
| 1. 规范与本地守卫 | 本批已补架构/复用、工程、恢复/维护；现有技能引用与本地守卫已验证，证据如上 | 后续改动重跑受影响检查；保持产品与真实系统边界不变 |
| 2. CI 工程接入 | 无凭据静态工作流已在 push 上多次成功；`main` 已要求检查 `Static quality gates`；push/PR 另有 macOS 编译与全库 SwiftLint | 完整 Swift 测试仍须 `workflow_dispatch`；管理员可绕过保护；编译成功不等于测试或原生验收 |
| 3. 真实开发与可靠性验收 | 用明确真实需求检验标准联动，按影响补性能/日志/恢复/生产时序证据 | 用户明确业务或专项测试目标；涉及敏感处理/真实系统/数据时独立确认 |
| 4. 正式发行与升级维护 | 候选物追溯、渠道、许可证、签名、公证、恢复和运行验收仍待落实 | 渠道/权利/身份决策及每个真实操作的授权；本机构建成功不能跳过这些门禁 |

规范、方法和本地守卫已经增加，也仍须保留矩阵中尚未覆盖的内容；不能将本批交付描述为整个生命周期全部闭环。

## 工作流闭环更新（2026-09-26）

本次主要补强项目协作基础设施，并修复通知排程日志脱敏；没有改变业务数据、签名配置或安装行为：

- 新增 [技能路由](../skill-routing.md)、[共享组件与复用目录](component-catalog.md) 和项目级 `areachain-workflow` 编排技能；`areachain-ui` 与 `areachain-verify` 已接入同一套冷启动和交接入口。
- `scripts/check_workflow.py` 新增 `workflow-contract` 与 `component-catalog` 检查，并把路由、组件目录和项目技能纳入必需引用与 Git 作用域；检查器仍只做静态守卫，不证明模型实际调用或原生运行。
- 实际验证：`python3 -B scripts/check_workflow.py --format json` 通过（含 `workflow-contract`、`component-catalog`、`performance-baselines` 与 `ci-contract`）；项目技能结构校验、脚本回归和 `git diff --check` 也已在本批最终差异上重跑。
- 全量 Swift 测试和本次变更文件的严格 SwiftLint 已由质量门禁实际运行；后续业务代码或共享 UI 改动仍必须按路由选择定向测试、构建和原生验收。

## 全生命周期质量门禁更新（2026-09-26）

本批把此前“有规范但缺统一执行入口”的部分接成可重复门禁，权威说明见 [质量门禁](quality-gates.md)：

- 新增 `scripts/quality_gate.py`，按差异自动选择工作流契约、差异、脚本测试、Shell 语法、安全候选、注释契约、性能基线、SwiftLint、Swift 测试和 Release 候选包检查；`warning`、`blocked`、`failed` 分开报告，`--strict` 可用于合并/发布前收紧。性能 profile 的登记测试覆盖局部阈值和 LifecycleBaselineTests；NSApplication 完整冷启动与独立 App 峰值内存仍未建立。
- 新增 [`docs/performance-baselines.json`](performance-baselines.json)，保留已有局部阈值的来源；当时启动、大库和恢复仍标为尚未建立。同日后续收口已改为 Debug 合成数据的 `provisional` 上限，并补上测试进程 RSS 安全网与重开增长；NSApplication 完整冷启动与独立 App 峰值内存仍未建立。
- 新增 `scripts/tests/test_quality_gate.py`，以临时目录验证质量脚本的配置、秘密/敏感日志候选、注释豁免、性能清单和状态聚合；不启动应用、不读取真实数据。
- 新增 `.github/workflows/quality.yml`：push/PR 的静态门禁和手动触发的 macOS Swift 门禁共用本地脚本。工作流文件存在不等于远端 runner 成功或分支保护已启用，仍需分别取证。
- 修复 `NotificationScheduler` 日志不再输出任务标题，只保留请求标识和错误类别；后续新增日志仍须通过安全候选扫描和人工隐私复核。

本批最终实际证据：脚本回归 165 项通过，工作流定向测试 46 项通过，静态严格门禁通过，Swift 严格门禁（含全量 Swift 测试）通过，performance profile 的登记局部测试通过；该批当时把启动/大库/恢复标为未建立，并留下全库 advisory SwiftLint 债务（同日质量优化收口后 `swiftlint lint --strict AreaChain AreaChainTests` 已为 0，见下文）。该批当时还没有远端 runner 成功记录；2026-09-26 已另行核对静态 Actions 多次成功，见下一节。钥匙串、真实恢复和正式发行仍不是已通过证据。

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

2026-09-26 核对：`AreaChain Quality` 的 push 静态 job 已多次成功（例如 run `36222371946`，检查名 `Static quality gates`）。同日已为 `main` 打开分支保护，只要求该静态检查，不要求评审，且不强制管理员遵守（避免检查名错误时锁死仓库）。这约束的是合并进 `main` 的 pull request；管理员直接 push 仍可绕过。当时 macOS 完整 Swift job 还没有 `workflow_dispatch` 记录；同日质量优化收口后 push/PR 增加了 macOS 编译与 SwiftLint，完整测试仍手动触发。同日删除 `.cursor/plans/`（设计系统归档与 excellence 执行器）；技能格式改由 `check_workflow.py` 的 `skill-format` 检查，不再依赖本机 Skill Creator。

干净工作区运行 `python3 -B scripts/quality_gate.py`（profile `auto`）只会选择 `static`，因为没有文件差异。Swift 源码改动必须显式使用 `--profile swift`，不能把 auto 在干净树上的通过写成 Swift 已测。

2026-09-26 W2：按架构文档的隔离命令，使用 `PRODUCT_BUNDLE_IDENTIFIER=com.areachain.privacy-qa`、`build/PrivacyQA` 和已清除的真实钥匙串变量，串行跑完整 scheme 测试。总览文件拆分之后重跑的结果包是 `build/PrivacyQA/W2-final.xcresult`：Passed，795 通过、0 失败、1 跳过（`SystemVaultIntegrationTests.testAuthorizedPhase`）。该次覆盖工作台路由、菜单栏浮层、手记小窗、浅深色、最小窗口、中英以及已有的组合文本与撤销用例。它不是真人输入法现场，也不是真实钥匙串验收。另有 `DashboardProjectionTests` 11 通过。

2026-09-26 W8：`./scripts/build.sh release` 退出码 0。产物在 `build/development-DerivedData/Build/Products/Release/AreaChain.app`，静态验签通过，`bundleVersion` 为 1，`distributionReady` 为 false。该包使用本机已有的 development 签名，不是 Developer ID，也没有公证或安装。它来自当时的未提交工作区，不能当成已发布版本。

2026-09-26 结构标准（本路线 W3–W7，沿用已确认的菜单栏视觉基准，不新开一套）：

- 单文件超过 500 行才拆文件。当时只有 `DashboardProjection.swift` 超限，快照值已挪到 `DashboardModels.swift`。
- `LiveComposerPreviewHeader` 与 `LiveDiaryComposerPreview` 继续作为 Theme 历史例外，不新增消费者，本路线不迁移。
- 生产搜索只保留工作台顶栏和菜单栏底栏；无入口的独立搜索页已删除，测试改嵌相同的 `SyntaxInputContext.search` 夹具。
- 全库扫描没有发现第二套日期、筛选或保存入口需要在本路线里合并。磁盘打开/大库重开/合成加密恢复已有 Debug 上限；测试进程 RSS 安全网与重开增长已登记。NSApplication 完整冷启动、独立 App 峰值内存、真实恢复和真实日历仍按原缺口保留。

## 仓库内诚实收口（2026-09-26）

本批只补仓库内能诚实完成的缺口，不接 CloudKit、不装到日用应用、不公证：

- 设置里的 iCloud 改为静态说明，删除无效偏好；无入口的独立搜索页已删除，语法搜索测试改嵌 `SyntaxInputContext.search` 夹具。
- `PendingCompletionTimingTests` 关闭测试跳过，覆盖 400ms 单次、批量与减弱动态效果；普通 UI 测试仍直调。
- `LifecycleBaselineTests` 把空库打开、2000 条重开和合成加密恢复登记为 `provisional`；首次预置测试使用隔离 `UserDefaults`，不写系统偏好。
- 完整应用冷启动、独立 App 峰值内存、真实钥匙串/日历和公证仍不是该收口的证据。

## 质量优化收口（2026-09-26）

本批只补仓库内能诚实完成的质量优化，不接 CloudKit、不装到日用应用、不公证、不改分支保护：

- 仓库增加 `.swiftlint.yml`，对齐 500 行文件上限、短标识和 SwiftUI 习惯；编译期正则改为 `CompiledRegularExpression` + `preconditionFailure`。本地 `swiftlint lint --strict AreaChain AreaChainTests` 为 0，`quality_gate --profile swift --strict` 的 swiftlint 检查通过。
- `LifecycleBaselineTests` 增加 2000 条重开时的测试进程 RSS 安全网，以及连续 8 次重开的增长上限；测量的是 Debug XCTest 进程，不是独立 App 峰值。
- `.github/workflows/quality.yml` 在 push/PR 增加 macOS 15 Debug 构建与全库 SwiftLint，并安装 SwiftLint。push 与手动 `workflow_dispatch` 分开 concurrency，避免互相取消。远端已核实：静态 + 编译通过见 run [`36242540609`](https://github.com/AreaSong/AreaChain/actions/runs/36242540609)；旧 `macos-14` 手动跑 [`36237740856`](https://github.com/AreaSong/AreaChain/actions/runs/36237740856) 因工程格式与缺 SwiftLint 失败。完整 `quality_gate --profile swift` 的 `workflow_dispatch` [`36242245269`](https://github.com/AreaSong/AreaChain/actions/runs/36242245269) 在托管 runner 上 `build.sh test` 跑满 1800s 超时，原生焦点套件不能当作 GitHub hosted 必过项；全量 Swift 证据仍以本机 `quality_gate --profile swift` 和隔离 PrivacyQA 为准。
- 隔离 PrivacyQA 本批结果包 `build/PrivacyQA/quality-opt.xcresult`：Passed，804 通过、0 失败、1 跳过（默认跳过的真实钥匙串入口）。不是真人输入法现场，也不是真实钥匙串验收。
- 本次未改分支保护、未装到日用应用、未跑真实钥匙串/日历、未公证。新对话冷启动只能另开会话抽查。

## PHASE-6 授权补证（2026-09-29）

获准后补合成进程杀死、隔离真实钥匙串，以及同身份日用 Debug 安装；仍不读真实手记，不杀日用进程做 VACUUM SIGKILL：

- `PrivacyStoreMaintenanceTests.killedExternalVacuumLeavesStoreReadableAndFinishSucceeds` 对独立 `/usr/bin/sqlite3 VACUUM` 发 SIGKILL：进程须仍在运行时被杀死，合成库可读，随后 `finish` 成功。sidecar 标记不是库文件，VACUUM 不得删掉它。进程内 VACUUM 中途中断由进度回调覆盖（`vacuumInterruptLeavesMarkerAndRetrySucceeds` / `vacuumCancelDuringStatementLeavesMarker`）。不是杀死 `/Applications/AreaChain.app`。
- 隔离 `PRODUCT_BUNDLE_IDENTIFIER=com.areachain.privacy-qa`、`build/PrivacyQA-keychain`，`SystemVaultIntegrationTests` 分阶段 `create` / `read` / `cancel-read` / `rebuild-read`（`CURRENT_PROJECT_VERSION=2`）/ `cleanup` 均通过。授权变量必须出现在 xcodebuild 进程环境（含 `TEST_RUNNER_` 前缀映射），只写成 build setting 仍会 skip。条目使用随机 UUID 服务名，不读写日用私密锁。覆盖 `CODE_SIGN_ENTITLEMENTS=AreaChain/App/AreaChain.entitlements` 会丢掉钥匙串访问组并得到 `errSecMissingEntitlement (-34018)`；须走开发签名注入的 `AreaChain.SystemUnlock.entitlements`。
- 2026-09-29 12:09–12:11 本轮重跑钥匙串：`RUN_ID=FD91734C-81FE-43E3-974B-349A1ACB1745`。`create` / `read`（37s）/ `cancel-read`（重试，`OSStatus=-128`）/ `rebuild-read`（`bundleVersion=2`，9s）/ `cleanup` 通过。第一次 `cancel-read` 因认证通过而失败（夹具要求用户点取消），不能把超时或误通过写成用户取消。
- 同日安装：先 `./scripts/build.sh` 得到开启沙盒的 `com.areachain.app` Debug，再 `./scripts/install.sh --yes --no-build`。测试产物关沙盒时 `--dry-run` 会拒绝。安装脚本不备份用户数据（`dataBackupCreated: false`）；本体回退在 `AreaChain-InstallBackups/install-20260929T041203Z-i8zbja7o`。`launchRequested: true`，`runtimeVerified: false`。未修改个人签名配置，未加 `--allow-provisioning`。日用私密锁 `com.areachain.app` 未做钥匙串分阶段验收。

## PHASE-7 维护清理（2026-09-29）

本批只收口已有证据确认的旁路包装、测试缺口和文档漂移，不改产品规则，不合并独立契约：

- 删除 `DayBoardLogic` 中无生产调用方的 `matching*` / `sortedForBoard` / `habitStreak` / `openBoardItems` / `completedBoardItems`。筛选、排序和连击仍走 `Classification` 与 `HabitStreakLogic`；`openTodos` / `openRoutines` / `todayProgress` 仍给菜单栏、四象限和进度环使用。
- `TasksPage` 去掉仅供测试的第二份 `pageSnapshot`。body 仍走 `TasksPageViewModel.make`；筛选/空态测试改断言 `DayBoardPageProjection.project`。
- 补失败路径：`ModelChanges.afterTransaction` 回滚与提交副作用失败仍发布、`requestAuthorization` 抛错后仍 refresh、错误口令 restore、不可打开库的 VACUUM `finish`、日历 `.denied` 与 ledger `version != 1`。
- 文档：工程手册把 2026-09-26 的 165/46 和 41 个 Domain 文件标成当时快照；架构树补 `Dashboard/`、`Board/`；组件目录补多消费者入口并写明菜单栏 `SearchResultsView` 不服务工作台；性能清单 `dayboard-page-projection` 的 source 行改为预算断言处。不新写性能预算。

## 按钮开发展示与验收

公共维护入口是 `DaybookButtonStyle`、`DaybookIconButton`、`daybookMenuLabel`（均在 [DaybookButtonStyle.swift](../AreaChain/Theme/DaybookButtonStyle.swift)），快捷提交继续用 [CommandReturnButton.swift](../AreaChain/Theme/CommandReturnButton.swift)。动作、`ButtonRole`、禁用和快捷键注册由原生控件/宿主负责；样式不保存、不导航、不请求权限。既有变体与参数兼容，`pill(tint:)` 仅保留已有用法，不新增任意外观覆盖接口。

[DaybookControlsPreview.swift](../AreaChainTests/Theme/DaybookControlsPreview.swift) 仅在 Debug 测试 target 中，直接装配生产按钮。它没有正式导航或应用启动入口，避免 Canvas 经生产 App 初始化触及服务。窗口可切换中英文、浅深色、禁用、长标签、减弱动态效果；鼠标悬停/按下、Tab 焦点、Command 高亮及 ⌘Return 使用真实原生事件。Tab 遍历受 macOS 的键盘导航设置影响，测试不修改全局设置。所有动作只增加本地计数。

打开方法：使用[架构文档的隔离命令](architecture.md#隔离验收与真实启用门禁)，在 `env` 的 `-u` 参数之后加入 `TEST_RUNNER_AREACHAIN_CONTROLS_PREVIEW_SECONDS=300`，并在 `test` 前加入 `'-only-testing:AreaChainTests/DaybookButtonInteractionTests/interactiveGallery()'`。窗口保留 300 秒（上限 600 秒），关闭窗口可提前结束，结束自动释放；不启动日用应用、不连接用户库。可调整窗口大小检查窄布局。不要直接 Run 生产 App 来展示控件。

自动检查沿同一隔离命令选 `DaybookButtonStyleTests`、`DaybookButtonInteractionTests`、`DiaryComposerInteractionTests`、`WorkspaceLayoutTests`；展示渲染 PNG 在测试进程临时目录的 `AreaChainButtonQA` 下。展示不代替真实消费者回归，快捷提交至少覆盖手记输入与菜单栏捕获。

后续按钮迁移仍需逐宿主核对：菜单栏底栏、Board 命令条、工作台顶栏与检查器、设置/备份/回收站中的局部 plain/borderless 图文按钮和 Menu 标签。任务完成圆圈、星期选择、分段切换和行选择不属于普通按钮迁移。

本阶段本机证据（2026-10-01）：`quality_gate.py --profile swift` 通过（1003 个测试通过、1 个真实钥匙串测试按授权边界跳过；包含参数化运行为 1089 次通过）；最终菜单命中区和展示宿主调整后，五组隔离定向测试 26 个测试 / 37 次运行全部通过，`./scripts/build.sh` 构建验签通过。`check_workflow.py`、51 项检查器定向测试、171 项脚本回归和本阶段 Swift 文件严格 SwiftLint 通过。展示窗口实际确认普通点击、⌘Return、系统菜单危险动作、禁用不触发、语言/主题/长标签切换；Tab 未进入按钮，持续按下视觉反馈及系统减弱动态效果联动仍待补验（本地展示开关已操作）。Cursor 只读 verifier 命令因未认证失败，不能视作独立复核通过。首次展示过滤器漏写 `()` 未运行测试，UI 工具随后启动过 QA 包，已立即终止；此启动不计验收证据，未检查其启动副作用。随后使用上面的完整测试标识完成隔离展示检查。未执行安装、发布或全应用按钮批量迁移。

### 第一阶段 B 补充验收（2026-10-01）

状态为**部分完成**。本轮只追加验收与核查记录，未修改生产代码或测试代码，未开展第二阶段。以上第一阶段记录保留为历史，不作为本轮通过证据。工作区已有并发文档、文案、脚本及按钮修改，均保留。

**实现范围与基线**：完整读取当前 `DaybookButtonStyle.swift`（全部变体/尺寸、Body/Chrome/Frame、IconButton、Menu label 和 Debug 环境值），以及 `CommandReturnButton`、两个展示/交互测试文件、`DaybookButtonStyleTests`、`NativeSyntaxUI`、`SystemPageHost` 和 `DaybookMotion`；沿 `FooterBar`、`BoardCommandStrip`、`WorkspaceHeaderBar` 核对真实消费者。当前 HEAD 为 `25a7cb3777f52983c26a6e3f938bd1fac0bd441d`，公共基础部分已在 HEAD；工作区另有 Debug 减弱效果覆盖、菜单命中区和未跟踪测试文件。本轮没有取得“第一阶段开始前”的不可变完整快照，不能把当前 diff 当作整个阶段的等价性证明。

**安全入口与本次执行**：使用架构文档的隔离命令，保留六个真实钥匙串授权变量清除、`build/PrivacyQA`、`com.areachain.privacy-qa`、临时本地签名、`AreaChain.entitlements`、`LSUIElement=NO` 和串行参数；增加 `TEST_RUNNER_AREACHAIN_CONTROLS_PREVIEW_SECONDS=600`、`'-only-testing:AreaChainTests/DaybookButtonInteractionTests/interactiveGallery()'`、`-resultBundlePath build/ButtonStageB.xcresult`。未修改工程或个人签名配置。结果包名已存在时应另选明确的新路径，不删除既有证据来重跑。

- 北京时间 11:31:10–11:37:16，macOS 26.6.2（25G83）、arm64；`xcodebuild` 退出 0。
- `xcresulttool get test-results summary` 与 `get test-results tests` 均核对 `build/ButtonStageB.xcresult`：目标 `DaybookButtonInteractionTests/interactiveGallery()` 实际运行，1 项 Passed、0 failed、0 skipped，目标时长 342.704 秒。此通过仅证明展示测试执行和窗口生命周期，不自动证明以下人工行为全部通过。
- `Persistence.makeSession` 在磁盘访问前凭 `XCTestConfigurationFilePath` 切换内存库；`AppDelegate.applicationDidFinishLaunching` 使用同一条件跳过启动服务。展示直接使用生产按钮和本地动作计数，不使用 `SystemPageHost.window` 的全局禁动画事务。
- UI 工具连接前先确认 XCTest 进程及精确可执行路径；Bundle ID 有两个本地 QA 包而存在歧义，改用**已确认运行的** `build/PrivacyQA/Build/Products/Debug/AreaChain.app`。只有目标测试实际运行且窗口存在时才连接；零测试、过滤失败或进程不存在时修正测试入口，不调用会自动启动应用的 `getApp` 作为替代。
- 关闭测试窗口后 UI 状态读取超时；随后由测试结果和进程检查确认测试正常结束、QA 宿主已退出，没有再次调用 `getApp`。未操作日用应用。

**交互证据与限度**（CUA 原生事件，截图观察与下一轮操作分开，未切换其他窗口）：

| 项目 | 本轮结果 | 状态与剩余条件 |
|---|---|---|
| Tab / Shift-Tab | 实际正向 7 次、反向 2 次，AX 焦点始终为展示窗口；画面没有按钮焦点环。只读 `defaults read -g AppleKeyboardUIMode` 为 `1`，AppKit `NSApplication.shared.isFullKeyboardAccessEnabled` 为 `false`。 | 环境受限：未完成焦点进入、移动、退出及可见反馈。系统未开启全控件导航，但没有在开启条件下完成对照，不能单独排除宿主或组件问题。未强设 `isFocused` 或派发 action 冒充 Tab。 |
| 焦点实现 | `DaybookButtonChrome` 读取原生 `isFocused` 与既有显式值，只负责描边；展示没有增加焦点注册。`CommandReturnButton` 明确 `.focusable(false)`。 | 快捷提交按钮不进入 Tab 是既有契约；普通 Button/Menu 的开启导航场景仍待验收，不为凑通过修改行为。 |
| 释放与取消 | 普通文字按钮从内部拖到外部释放，计数保持 0；同坐标原位点击变为 1。图标按钮拖出释放保持 1，原位点击变为 2。禁用后两类拖出和点击均保持 2，禁用菜单不展开。 | 已验证这些释放/取消路径。当前 CUA 仅提供 click/drag，没有可分离的 down/hold/up，无法停留按下态取证；持续保持时的视觉、动作是否提前触发及释放动画均未通过验收。 |
| 菜单差异 | 点击启用菜单只展开系统菜单，Escape 关闭，计数不变。 | Menu label 不接收 `ButtonStyle.Configuration.isPressed`；系统负责按下/展开交互，不应套用普通按钮的 0.97 缩放判据。持续按住菜单入口仍未测。 |
| 减弱动态效果 | 系统 `defaults read com.apple.universalaccess reduceMotion` 为 `0`，`NSWorkspace.shared.accessibilityDisplayShouldReduceMotion=false`。展示开关实际开/关；开启时普通按钮拖出取消不计数、原位释放加 1（最终 3）。结束后系统两项偏好仍为 1 / 0。 | 仅验证当前系统状态、局部开关和相应释放行为。没有系统开启及运行中系统切换证据，没有持续按下缩放/动画的视觉证据。 |

生产路径是 `@Environment(\.accessibilityReduceMotion)` → `systemReduceMotion`；Release 只读该值，Debug 取 `systemReduceMotion || daybookButtonReduceMotionPreview`。为 true 时按下缩放为 1，`DaybookMotion.interactive/snappy` 返回 nil；按下填充反馈仍保留。展示开关只加强本地视图树里的公共按钮 Chrome，不能关闭已开启的系统减弱效果，也不覆盖系统 Menu 动画或全应用其他动效。以上路径属于源码核对，不能替代真实系统联动验收。未修改全局键盘导航、辅助功能或其他系统设置；未因本轮纯证据更新机械重跑旧的 ⌘Return、全语言/主题矩阵或全量测试。

**误启动只读核查**：历史来源为 Codex 会话 `01a0f55c-f9de-7d92-bc57-c06f148953a1`，turn `01a0f55c-fbfe-73d0-9674-98e31d48050f`。本轮历史检索在新测试前读取 `build/PrivacyQA/Logs/Test` 的三个结果摘要：11:05:40 的定向测试为 26 项/37 次通过；11:06:50 的缺 `()` 过滤为 0 项、result unknown；11:08:23 的正确展示为 1 项通过。新测试后再次访问旧的 11:06:50 结果路径已不存在，因此保留上述已读取摘要与历史会话出处，不承诺旧结果包仍可复查。

- **有记录的执行**：缺括号命令结束后，UI 工具按 QA 包路径调用 `getApp`；`ps` 列出 PID 35111、该精确可执行路径、`etime=00:20`，随后 `kill -TERM 35111`。这补充了上文“立即终止”的时间限度。后续正确展示使用另一 PID 35289，不能用其 XCTest 环境外推前一进程。
- **环境强推断**：顺序支持误启动脱离 XCTest，但当时没有 PID 的父进程或环境快照，无法直接证明 `XCTestConfigurationFilePath` 缺失。六项环境清除只适用于当时的 `xcodebuild`，不能自动外推到 UI 工具启动。
- **隔离依据与边界**：新测试前核对旧 QA 产物的 Bundle ID、`LSUIElement=false` 和沙盒 entitlement；可执行文件/签名资源 mtime 为 11:06:52，与历史构建相符，仍不是不可变签名快照。QA 容器路径为 `~/Library/Containers/com.areachain.privacy-qa/Data/Library/Application Support`，与日用 ID `com.areachain.app` 不同，且解析后没有指向日用目录；它是既有 QA 容器，并非本次新建空白数据目录。未采集当时进程的实际路径调用，不能由包名推出所有访问均已隔离。剪贴板仍是系统 `.general`；通知/EventKit 也不是 fake。
- **文件元数据**：只 stat 已知 QA 路径，不打开内容。`areachain.store` / `-wal` / `-shm` 均创建于 9 月 15 日，mtime 分别为 10 月 1 日 11:07:22.610 / .611 / .402，与误启动时段一致；这是该时段文件发生过修改的证据，不能证明具体记录变化或唯一归因到 PID 35111。已知剪贴板目录、附件目录、隐私配置和日历基线当前不存在；不存在不证明历史未创建、未读取或未调用系统服务。
- **代码可能执行**：若没有 XCTest 环境，`Persistence` 可执行冷启动维护、SQLite 空备注修正及打开磁盘库；AppDelegate 可启动隐私配置读取/锁定监听、示例播种、状态栏、快捷键、剪贴板监控/面板、通知刷新、撤销与日历协调。剪贴板监控以 changeCount 变化为读取条件；日历写入取决于偏好、权限与同步结果；隐私生命周期不等于发生系统认证。这些代码可达性不是实际执行日志。
- **无法追溯确认**：没有当时逐服务日志或前后快照，无法确认具体数据库改动、剪贴板读取/保存、通知排程或日历写入，也无法以进程退出、当前文件缺失或未见异常证明零副作用。没有读取真实正文、数据库内容、附件、剪贴板或凭据，没有复现启动或清理。若需恢复，应先由用户确认受影响范围及恢复授权，再基于可用历史备份核对；现有证据不足以建议自动回滚。

**独立复核**：本轮向 `cursor-agent --mode ask --print --workspace /Users/as/Ai-Project/project/AreaChain` 提供原始范围、完整实现文件、HEAD/工作区限度及上述真实证据，请其承担 Cursor verifier。一次调用即返回退出码 1：`Authentication required`。没有登录、读取凭据、修改配置或重试；项目/个人目录也未发现 `verifier.md`，不能宣称独立代理配置已加载。历史检索子代理只查记录，不替代规定的 Cursor 复核。复核缺口继续保留。

**收尾检查**：本轮只编辑本节，按本次范围运行 `python3 -B scripts/quality_gate.py --profile static`，避免默认 auto 因既有/并发 Swift 差异启动无关全量测试及非本轮隔离宿主。172 项脚本测试通过，差异空白、安全静态（高风险/敏感日志候选均为 0）、注释和性能契约通过。`check_workflow.py` 与总门禁第一次执行失败于并发修改的 `docs/component-catalog.md:63` → `unified-search-commands.md#96-阶段-1a-目录决策与证据` 缺失锚点；其余工作流检查通过。该问题随后随并发文档更新消除，复跑静态总门禁（含 172 项脚本测试）、`check_workflow.py` 与 `git diff --check` 全部通过，本轮未修改或覆盖对方文件。Swift 全量测试、额外构建、安装、发布、提交和推送均未运行。

### 第二阶段 A：手记与标签弹窗按钮接入（2026-10-01）

**已实现，验收部分完成**：仅将 `DiaryWindowView` 的置顶、显示正文、保存，`DiaryCardComponents` 的编辑保存，以及 `TaskDetailTagSelector` 标签弹窗的创建/取消接入现有 `DaybookButtonStyle`；变体、尺寸及合理例外见[组件目录](component-catalog.md)。卡片取消和其他已接入按钮保留。没有修改公共 API、业务回调、禁用、快捷键、授权、编辑器或保存/关闭规则；系统 confirmationDialog/alert 保留系统按钮。本阶段纯消费者样式迁移，不新增必需独立复核。

**本阶段证据**：沿架构文档的隔离 XCTest 命令，使用 `build/PrivacyQA`、`com.areachain.privacy-qa`、本地临时签名、生产沙盒 entitlement、串行执行并清除六个真实钥匙串授权变量。测试使用内存库、合成内容和 `PrivacyFixture` 的内存配置/系统密钥替身，不直接启动 QA 包或日用应用。新增 `DiaryButtonConsumerTests` 直接挂载三个生产消费者，并通过原生鼠标事件验证按钮；没有另建展示页或复制生产回调。

- `build/ButtonStage2A-verified.xcresult` 中手记消费者、`DiaryEditorSessionTests` 和 `DiaryWindowLifecycleTests` 共 23 次通过；覆盖最小 328×230 小窗、置顶往返、禁用保存、保存失败重试、显示/遮罩/冲突保留草稿、卡片保存/取消和原窗口生命周期。
- 同包标签组曾有一次取消失败。修正测试对 SwiftUI 动态辅助树的读取、内存容器生命周期，以及原生 sheet 呈现/关闭等待后，最终 `build/ButtonStage2A-tag-focus.xcresult` 实际命中标签组，4 次通过、0 失败、0 跳过；覆盖中英文×浅深色的空值禁用、保留名称、失败保留输入与错误、成功、取消及重新打开清空。测试等待窗口稳定且为 key window，不跳过关闭或焦点断言。早期失败包保留，不作为通过证据。
- 已查看三个消费者中英文×浅深色的原生缓存截图及按钮边界断言；长标签未挤压操作按钮，小窗最小尺寸可用。截图位于测试临时目录 `AreaChainButtonConsumersQA`；sheet 缓存的透明材质不代表完整屏幕合成效果。
- 变更 Swift 文件严格 SwiftLint、`git diff --check`、`check_workflow.py` 和 `quality_gate.py --profile static` 通过（172 项脚本测试）。默认 Swift profile 会运行全量测试，本次按用户限定的隔离/系统操作边界改用上述定向测试，未执行全量 Swift profile。编译仍有既有测试辅助 API 弃用/未使用变量警告。

**保留缺口**：未实测真人输入法/撤销、授权拒绝分支及卡片按钮直接触发保存失败/冲突弹窗（会话层失败/冲突回归已通过）。`SystemPageHost` 关闭动画，不能据此验收持续按下与真实动效。第一阶段的 Tab 全控件导航、持续按下视觉、系统减弱动态效果开启/切换、未认证 Cursor verifier 和历史误启动副作用均无新证据，继续保留。下一阶段候选仍包括设置隐私 sheet 等局部系统样式按钮，本次未迁移。未提交、推送、安装或发布，未改全局设置、权限或真实用户数据。

### 第二阶段 B：隐私弹窗按钮接入（2026-10-01）

**已实现，验收部分完成**：三个隐私弹窗的 7 个按钮直接复用现有 `DaybookButtonStyle`，主操作 `.prominent`、取消 `.quiet`，均为 regular；消费者和布局例外见[组件目录](component-catalog.md)。生产差异只有按钮样式修饰符；没有改变认证、授权、密码校验、密钥、保护流程、生产默认值、窗口装配或公共 API。`PrivacyUnlockView` 的取消仍不随 busy 禁用，另外两个 sheet 的取消仍随 busy 禁用。原回调、密码清空、错误反馈、防重入、快捷键、辅助功能和 sheet 关闭限制全部保留。本次为纯消费者样式迁移，不新增必需独立复核；既有 Cursor 未认证缺口不标为通过。

**本阶段隔离与证据**：沿架构文档的 XCTest 命令，使用 `build/PrivacyQA`、`com.areachain.privacy-qa`、本地临时签名、`AreaChain.entitlements`、`LSUIElement=NO`、串行测试并清除六个真实钥匙串授权变量。`PrivacyFixture` 使用内存库、合成内容、内存配置和 `FakeSystemVaultKeys`；Setup 均显式传 `probeSystem: false`。没有直接启动 QA 包或日用应用。

- 新增 `PrivacyButtonConsumerTests` 直接挂载生产视图，复用 `SystemPageHost`、原生鼠标事件及真实 sheet，未新建展示页。`build/ButtonStage2B-consumers.xcresult` 实际命中 5 项、12 次运行，通过且零失败/跳过：中英文×浅深色密码空值/不一致、busy 防重入和取消禁用、注入失败后恢复及成功回调一次；替身系统解锁和主密码解锁、busy 时取消回调一次；两个 sheet 空闲取消关闭且不提交；Setup 无解锁方式、主密码不足 12 字符及确认不一致时禁用。
- `build/ButtonStage2B-regression.xcresult` 实际命中 `PrivacyRenderingTests`、`PrivacyInteractionTests` 及 `PrivacyVaultTests` 的 `bothRoutesUnlockTheSameKeyAndNeverStorePassword()`、`idleAndLateAuthenticationCannotReopenALockedVault()`、`passwordOnlyNeverTouchesSystemStoreAndCannotRemoveLastMethod()`，共 13 项通过、零失败/跳过。未选择真实钥匙串测试或能力探测测试。
- 首次 `build/ButtonStage2B.xcresult` 因并发新增的 `CommandPathParser` 当时缺少 `CommandPathCompletion` 而编译失败、零测试；未修改该功能，依赖文件出现后才重跑。该包保留为失败证据。
- 最终补充初始 390×300 解锁窗口的全部按钮边界及密码弹窗启用态截图后，`build/ButtonStage2B-layout.xcresult` 再次实际命中消费者 5 项、12 次运行，零失败/跳过。已检查三处中英文×浅深色、长说明的原生缓存截图和按钮边界：解锁 390×300 / 390×390、密码 440×330、Setup 480×540；截图复用测试临时目录 `AreaChainButtonConsumersQA/privacy-*.png`。sheet 缓存背景透明，不能证明完整系统材质合成或其最终对比度。
- 最终 Swift 文件严格 SwiftLint、`git diff --check`、`python3 -B scripts/check_workflow.py` 和 `python3 -B scripts/quality_gate.py --profile static` 通过。默认 auto/Swift profile 会调用全量测试，本次按限定的隔离边界以静态门禁加上述定向 XCTest 替代，未运行全量 Swift profile。编译有既有测试辅助 API 弃用警告；构建及本地临时签名不代表安装、真实系统认证或发行。

**明确未测**：Setup 的 Apply 提交可能进入 `PrivacyUnlockPresenter`、文件面板、备份和默认 `PrivacyPersistence`，因此没有执行提交、busy/失败恢复或完成回调路径；仅有替身 vault 不足以证明整条链路隔离。这些回调与判断已逐行核对未变。解锁取消测到视图回调，未重测 Presenter 请求/continuation 生命周期。真实认证、系统钥匙串、真实内容保护与数据处理均未执行；未补第一阶段 Tab、持续按下、系统减弱动态效果联动、Cursor 复核和误启动历史证据，也未补第二阶段 A 的输入法/撤销、授权拒绝、卡片失败/冲突弹窗。

本阶段到此停止。普通设置、快捷键的重置等剩余按钮仅作后续线索；开关、密码框、加载指示器与其他页面未迁移。未提交、推送、安装或发布，未修改全局配置、签名配置、权限或真实用户数据。

### 第二阶段 C：普通设置、快捷键和项目支持按钮接入（2026-10-01）

**已实现，已完成本阶段隔离验证；真实系统路径未测**：生产范围限定 `SettingsSections.swift`、`ProjectSupportSections.swift`、`HotKeyRecorder.swift`、`ShortcutsSettingsView.swift`，15 处按钮声明直接接入 `DaybookButtonStyle`，变体与消费者见[组件目录](component-catalog.md)。未增加公共 API、令牌、状态或页面根按钮样式；Form 分组、action、角色、条件、禁用、帮助及辅助功能标识保持。通知防重复发送、结果提示/状态刷新、日历回调、支持链接/环境信息复制及部分失败提示、快捷键录入/Escape/冲突/持久化/全局注册/监听释放均沿原实现。本次纯消费者样式迁移，不新增必需独立复核。

**隔离边界**：测试直接挂载生产分节、`ShortcutRecorder` 和 `ShortcutsSettingsView`，不复制按钮/业务回调，不挂载含系统状态查询的 `SettingsView`。复用 `SystemPageHost`；偏好使用随机独立 UserDefaults suite，模型为内存库；快捷键同时注入带 fake register/unregister 的 `HotKeyCenter` 后构造 `ShortcutStore`。`HotKeyCenter.installHandlerIfNeeded` 在 fake 路径跳过 Carbon 安装；XCTest 下 AppDelegate 跳过日用服务启动，`.hotKeyDidChange` 当前无订阅者，测试不启动日历协调器。设置页测试只暂存/恢复当前 XCTest 进程的合成 `CalendarSyncStatus`，不刷新真实日历；只点击注入的通知申请和冲突查看回调。

**本阶段实际证据**（macOS 26.6.2，arm64）：沿架构文档已确认的隔离 XCTest 入口，使用 `build/PrivacyQA`、`com.areachain.privacy-qa`、本地临时签名、`AreaChain.entitlements`、`LSUIElement=NO`，清除六个真实钥匙串授权变量，等待仓库构建锁后串行运行；没有直接打开 QA App 或日用应用。

- `build/ButtonStage2C.xcresult`：`ShortcutStoreTests` 3 项、`SettingsSectionPresentationTests` 3 项、`ProjectSupportTests` 4 项、`DaybookButtonStyleTests` 3 项及原快捷键页面清单 1 项通过。新增消费者 8 项起初失败于测试辅助代码用 Objective-C `perform` 读取结构体矩形；改用既有宿主采用的 KVC 取值后重跑，没有修改生产行为或放宽断言。首轮四个按方法筛选的用例未命中，随后改用带完整参数/括号的方法标识补跑。
- `build/ButtonStage2C-consumers.xcresult`：13 项、32 次运行全部通过，0 失败/跳过。包含 `SettingsButtonConsumerTests`、`ShortcutsPageTests`、通知 fake 的 `testBannerPostsImmediatelyWithoutTouchingReminders()` / `deniedTestBannerLeavesExistingReminders()` / `failedTestBannerDoesNotClaimDelivery()`，以及公共按钮 `disabledButtonsRejectMouseAndShortcut(disabled:)`。结果包 summary 和 tests 均核对实际执行标识，过滤退出成功不单独计为通过。
- 补充已有绑定重新监听的相邻按钮边界和全部重置的双语主题窄窗场景后，`build/ButtonStage2C-shortcuts.xcresult` 实际运行 `ShortcutsPageTests` 5 项、14 次，全部通过，0 失败/跳过。原生鼠标/按键覆盖进入监听、重复点击防重入、Escape 保留原绑定、有效组合更新正确项并退出、fake 注册失败提示、单项/全部重置及偏好重建；移除视图后再投递组合不会写回 store 或注册，核对监听释放。
- 已查看设置、项目支持、冲突长标题和快捷键各状态的中英文 × 浅深色原生缓存截图，并核对按钮存在、几何边界及相邻按钮无重叠。分节和快捷键页面窄窗为 420×560，既有全页面标识测试仍覆盖 780×500 的工作台最小尺寸；登录待批准与全部重置先滚动至按钮再检查/点击。英文重新录入提示在有重置按钮时自然换成两行，未遮挡重置。PNG 在测试临时目录 `AreaChainButtonConsumersQA/settings-*.png`；缓存截图不代表完整系统材质合成。
- 最终 8 个变更 Swift 文件严格 SwiftLint、`git diff --check`、`python3 -B scripts/check_workflow.py` 和 `python3 -B scripts/quality_gate.py --profile static` 通过（172 项脚本测试）；隔离测试同时完成编译。默认 auto/Swift profile 会调用全量测试，按本阶段限定范围以静态门禁加上述定向 XCTest 替代，未执行全量 Swift profile。编译仍有既有测试辅助 API 弃用警告。生产差异核对为仅新增 15 行按钮样式修饰符。

**明确未测与停止边界**：未发送系统通知、申请真实通知权限、打开系统设置或浏览器、写真实剪贴板、刷新真实日历。通知按钮自身的异步 busy/消息刷新、支持按钮外部打开/复制结果提示及日历重试仍以回调差异核对和已有 fake/领域测试取证，不能写成端到端通过；没有为此新增服务抽象。`SystemPageHost` 关闭动画，未补持续按下、系统减弱效果或真人 Tab/辅助功能导航。第一阶段与 A/B 的 Tab、持续按下、系统减弱动态效果、Cursor 未认证、历史误启动及其他消费者未验项保持原记录，未重试认证或重查历史。下一阶段仅留隐私主页、数据备份、其他页面局部按钮/Menu 标签线索；Picker、Toggle、输入框和其他控件不在本阶段。保留前期及并发修改，未提交、推送、安装、发布，未修改全局设置、个人签名配置、权限或真实用户数据。本阶段到此停止。


### 第二阶段 D：隐私主页与数据备份页按钮接入（2026-10-01）

**实现范围**：仅在 `PrivacySettingsSection.swift` 和 `DataBackupView.swift` 增加 14 行公共按钮样式。隐私主页 9 处及备份页 4 处普通入口用 `.quiet`，原 destructive 重置入口用 `.destructive`，全部 regular；保留 Form、HStack 和对齐，无公共 API、状态、令牌或确认流程变更。移除这 14 行后，两份生产文件逐字等于本阶段开始时的 HEAD。busy/内存回退整组禁用、最后一种解锁方式限制、回调/角色/辅助功能标识、清理状态、导入预览/错误、密码 sheet 关闭方式及仅回退显示重置均保持原实现。系统 alert、confirmationDialog、NSAlert、NSOpenPanel、NSSavePanel 内部按钮保留系统承载。本次消费者样式等价改动不新增必需独立复核。

**隔离核对**：沿既有架构 XCTest 命令，清除六个真实钥匙串授权变量，使用 `build/PrivacyQA`、`com.areachain.privacy-qa`、本地临时签名及串行选项；等待仓库构建锁，不直接打开 QA 或日用 App。XCTest 环境使 Persistence 使用内存库、AppDelegate 跳过真实启动服务。新增测试直接挂载生产消费者，复用 `PrivacyButtonConsumerTests`、`SettingsButtonTestSupport`、`SystemPageHost`、内存配置和 `FakeSystemVaultKeys`；独立随机偏好 suite 用后清理，附件只插入合成元数据，不创建/清理附件文件。StoreHealth 仅在两页、Setup/备份服务守卫及启动赋值处使用；测试不启动后续服务，串行暂存/恢复进程内回退标志。原有 `PrivacyFixture` 的随机临时目录仅供其隔离夹具使用。

**实际验证**（macOS 26.6.2/arm64，Xcode 26.6，Swift 6.3.3）：

- 首轮 `build/ButtonStage2D.xcresult` 编译被并发新增 `ContentQueryContractTests.swift:126` 的 `#expect(explicit.allSatisfy(\.isApplicable))` 宏报错阻断，未运行测试。后两轮仅在命令行传 `EXCLUDED_SOURCE_FILE_NAMES=ContentQueryContractTests.swift`，不编辑/删除该文件或修改工程；因此不声明搜索领域测试或完整测试 target 无条件通过。
- `build/ButtonStage2D-consumers.xcresult` 实际执行 16 项、35 次，两个新增测试失败：英文 420×560 页的重置按钮需要滚动进入视口；不可用 vault 不加载 pending key journal，不能预期系统清理按钮。测试改为先复用 `reveal` 滚动并保留原边界断言、按真实不可用状态检查按钮缺席；没有改生产行为或放宽几何容差。
- 最终 `build/ButtonStage2D-verified.xcresult`：16 项、35 次全部通过，0 失败/跳过；使用 `xcresulttool get test-results summary` 和 `tests` 核对实际命中。包括 `PrivacyButtonConsumerTests` 全部 9 项、`DaybookButtonStyleTests` 3 项、`DataBackupInteractionTests` 的状态命名/待清理 2 项、`DataBackupRenderingTests` 的回退重置 1 项及 `PrivacyRenderingTests` 的双外观 1 项。编译随隔离 XCTest 完成，仍有既有测试辅助 API 弃用警告。
- 新消费者矩阵在 420×560、en/zh-Hans、浅深色下检查主密码/系统/双方式 × 锁定/解锁，最后方式不可移除及回退整组禁用；检查未配置、不可用、合成附件/密钥待清理。原回退测试覆盖工作台最小 780×500，原隐私渲染覆盖 560×640。按钮几何和相邻按钮无重叠通过；已查看生产主页、待清理、不可用和备份回退的双语主题缓存截图，英文主密码按钮自然换行、重置需正常滚动。缓存截图和关闭动画的宿主不证明真实系统材质或动效。
- 真实原生鼠标事件只打开/取消标签管理、主密码更改、关闭系统方式以及两种加密备份密码 sheet；返回后 vault revision/解锁方式不变，备份入口恢复启用，内存模型无新增手记。既有密码 sheet/解锁视图的 fake 回调次数、busy、防重复、错误恢复和取消测试通过；不把它们外推为主页真实认证/备份提交次数已测。
- 最终范围的严格 SwiftLint、`git diff --check`、`check_workflow.py` 与 `quality_gate.py --profile static` 通过；20 个相关按钮键的 en/zh-Hans 值非空。默认 auto/Swift profile 会启动全量测试，按本阶段隔离限制以静态门禁、严格 lint 和上述定向 XCTest 替代，未运行全量 Swift profile。本阶段样式接入与安全隔离验证已完成，下述系统路径明确未执行。

**未执行边界**：首次设置的嵌套 Setup 默认 `probeSystem=true`，故不点击；标签管理 `creating=false` 不探测，主密码与关闭系统方式仅打开/取消，不 Save。加密备份仅打开/取消密码 sheet，禁止提交后连接默认 vault、面板与备份服务。未执行真实认证、密钥/附件清理、内容保护、普通文件选择/导入导出、备份恢复、数据库重置或退出。内存库的 `PrivacyStoreMaintenance.isPending` 固定为 false，因此数据库清理提示/退出入口只核对源码，未新增磁盘夹具或生产注入；主页 busy 的真实认证/清理时序亦未执行。系统路径不以编译、截图或静态相等冒充通过。

前期 Tab、持续按下视觉、系统减弱效果联动、Cursor 复核、历史误启动及 A/B/C 消费者未验项保持原记录，不重复尝试。后续具体线索仅记录：`DiaryPage.quickComposer` 的锁定草稿解锁/丢弃（约 290/296 行），`DayScheduleMenu.swift` 日期弹出层确认（约 50 行）尚无公共按钮样式；菜单内按钮、芯片/星期/象限等特殊选择控件需分别判断，不批量迁移。组件目录与本节保留并发搜索领域文档；不提交、推送、安装、发布或修改真实数据、签名配置、权限、全局设置。


### 第二阶段 E：剩余按钮接入与全应用清单核对（2026-10-01）

**已实现**：仅在 `DiaryPage.quickComposer` 的封存草稿解锁/丢弃和 `DaySchedulePicker` 确认增加三行 `DaybookButtonStyle`；分别 `.prominent / .quiet / .prominent`、regular。不新增包装、公共 API、状态或令牌；移除这三行后两份生产文件与本轮开始时一致。指定 vault、`PrivacyAccess`、restore/焦点、丢弃入口与最终 destructive 确认的角色、日期临时值/初始化/转换及调用方保存和关闭语义均保持。日期选择器本体、菜单内容和系统确认按钮未改。

**本轮隔离证据**：沿架构文档的串行 XCTest 入口，使用 `build/PrivacyQA`、`com.areachain.privacy-qa`、本地临时签名、生产 entitlement、`LSUIElement=NO`，清除六个真实钥匙串授权变量并遵守仓库构建锁。仅通过 XCTest 启动宿主，没有直接打开 QA 或日用 App。内存模型、合成内容、`PrivacyFixture`/`FakeSystemVaultKeys` 和 `SystemPageHost` 沿用已有夹具。日期测试偏好使用独立 suite；没有读取真实正文、附件或凭据。

- `build/ButtonStage2E.xcresult`：正常目标配置编译成功，**没有传 `EXCLUDED_SOURCE_FILE_NAMES` 或排除测试源码**。D 阶段阻断处在并发搜索改动中已改为 `allSatisfy { $0.isApplicable }`；本轮未修改搜索源码或测试。编译保留测试辅助 API 弃用及既有 actor 隔离警告，不等于零警告或搜索测试已运行。
- 同一结果包的 `summary` 和 `tests` 实际命中 18 项、36 次，0 失败/跳过：`DiaryButtonConsumerTests` 6 项、`DayScheduleButtonConsumerTests` 首批 3 项、`DiaryComposerInteractionTests` 8 项，以及 `PrivacyInteractionTests.filteredOutCardKeepsItsSealedUnsavedSession()`。
- 新增封存消费者测试直接挂载 `DiaryPage`，在锁定 vault 下检查两按钮边界、点击丢弃只打开原确认框、取消保留原草稿 ID/封存内容、确认后按原规则清空。另在 fake vault 已解锁但草稿仍封存时点击原解锁按钮，验证 `PrivacyAccess` 快路径恢复合成正文与同一草稿 ID，并核对原回调使原生编辑器成为 first responder；没有改变生产认证条件。
- 日期消费者测试直接挂载 `DaySchedulePicker`，核对 2026-10-01 初值、通过原 NSDatePicker 的选择 action 改到 2026-10-18 不提交、原生鼠标点击确认只记录一次正确 DayKey；另验证自定义长确认文案及 2026-12-31。`TaskDetailDateChips` 实际打开弹出层后重复该链路并确认关闭。原生日历选择为程序化 `dateValue` + target/action，不能声称真人点击日格已验收。
- 手记调用方静态核对覆盖 `DiaryNoteCard`、`DiarySummaryRow.daySchedulePopover`，任务调用方覆盖 `TaskRow`、`TaskDetailDateChips`；四处仍传原日期、使用默认 `day.confirm`，提交后走原变更入口并置 `pickingDay=false`。没有调用方自定义确认文案被覆盖。补测直接从已打开弹出层的状态挂载真实 `DiaryNoteCard`，未复制确认按钮/回调或改变生产条件；该测试不覆盖从手记菜单打开弹出层的手势。
- 已检查 en/zh-Hans × 浅深色下封存页 380×230、日期组件 300×340 的原生缓存 PNG 与几何断言；英文解锁/丢弃完整、相邻按钮不重叠，长日期确认文案自然两行。图片复用 QA 临时目录 `AreaChainButtonConsumersQA` 的 `sealed-composer-*`、`settings-date-confirm-*`。透明背景/材质以及深色 NSDatePicker 白色缓存区域不能证明系统最终合成色与对比度，日期本体未改动。

**最终补测与门禁**：等待并发任务释放仓库构建锁后，`build/ButtonStage2E-dates.xcresult` 在同一正常配置下完成编译，仍不排除任何源码。`summary` / `tests` 确认 `DayScheduleButtonConsumerTests` 4 项、7 次全部通过，0 失败/跳过，包含新增 `diaryConsumerCommitsAndClosesPopover()`：选择变化不改原记录，确认后 `dayKey` 正确且内存 context 无未保存变更，原弹出层关闭；任务回调也只提交一次并关闭。首轮生产/草稿测试后的唯一 Swift 增补是此手记测试，日期整套已重跑。最终四份 Swift 文件严格 SwiftLint、`git diff --check`、`check_workflow.py`、`quality_gate.py --profile static` 通过（172 项脚本测试），8 个受影响文案键 en/zh-Hans 均非空。文档和组件目录保留 A–D 及并发搜索记录。

**全应用静态核对**：具体 A/B/C/D 文件、符号与父容器依据维护在[组件目录](component-catalog.md#第二阶段-e按钮接入与全应用静态清单2026-10-01)。扫描覆盖普通/默认 Button、全部 plain 可疑项、样式、Menu label、公共封装、继承样式及 AppKit/手势入口；主代理抽查遗漏及菜单父容器。子代理首轮限流，重试只读核对完成；不是指定 Cursor verifier，也不用于替代历史复核。纯消费者样式等价迁移不新增必需契约复核。

E 阶段结束时 D 类仍有 6 处定义：`TagManagementPage.mergeSheet` 取消、`BatchActionBar.dateAdjustmentMenu/statusAdjustmentMenu/tagAssignmentMenu`、`WorkspaceAllItemsView.scopeMenu`（三处呈现）、`TagManagementPage.colorMenu`。系统菜单展开内容归 B，页面上的 `.borderlessButton` label 不因此豁免。未擅自迁移范围外入口；**当时第二阶段全部普通按钮/菜单入口接入尚未完成**；后续接入见 F 阶段，不能把此次静态核对写成全应用运行统一。

**继承缺口与停止边界**：真实认证、系统钥匙串及解锁 Presenter 全链路未测；本轮快路径不补这些证据。历史 Tab、持续按下视觉、系统减弱动态效果联动、Cursor、误启动副作用和 A/B/C/D 其他消费者未验项保持原记录。`SystemPageHost` 禁动画和缓存图不证明真实动效/系统材质。默认 auto/Swift profile 会启动全量测试，本阶段按限定隔离范围使用静态门禁、严格 lint 和定向 XCTest，不执行全量 Swift profile。本轮到 E 停止，不重写日期选择器、开关，不提交、推送、安装、发布或修改全局设置、个人签名配置、权限及真实用户数据。

### 第二阶段 F：菜单入口与标签合并取消（2026-10-01）

**已实现，运行验收部分完成**：E 留下的六处定义全部接入，具体消费者与分类更新在[组件目录](component-catalog.md#第二阶段-f菜单入口与标签合并取消2026-10-01)。取消为 `.quiet / .compact`；五处 Menu label 为 compact、`fitsLabel: true`。保留原生 Menu、menuStyle、Section、角色、回调、参数、显隐及筛选状态。批量栏原横排在 580pt 英文全操作/说明场景出现逐字换行和删除文字消失，故按本轮允许的局部布局调整复用 `ViewThatFits`：宽时横排，窄时分行；没有改全局令牌、公共 API 或状态。

**正常配置与隔离**：Xcode 26.6 / Swift 6.3.3、macOS 26.6.2 arm64。沿架构文档的串行 XCTest 命令及仓库构建锁，使用 `build/PrivacyQA`、`com.areachain.privacy-qa`、临时签名、生产 entitlement、`LSUIElement=NO`，清除六个真实钥匙串授权变量。未排除源码；应用与完整正常测试 target 编译成功，保留已有辅助 API 弃用等警告。仅通过 XCTest 启动宿主。直接挂载 `BatchActionBar`、`WorkspaceAllItemsView`、`TagManagementPage`，复用 `SystemPageHost`、独立偏好 suite、内存模型及合成事项/标签。全部事项测试保存并恢复实际受影响的进程内查询、选择/锚点、检查器和列表检查日，不切页或写日用偏好。

**F 首轮最终证据（保留失败历史）**：`build/ButtonStage2F-final.xcresult` 的 `summary` / `tests` 已核对实际标识：45 项、57 次运行，44 项通过，1 项失败（中文浅/深色共 2 次），零跳过。7 个实际命中套件为 `BatchMenuConsumerTests`、`WorkspaceMenuConsumerTests`、`DaybookButtonStyleTests`、`ItemsListingTests`、`WorkspaceItemsPageTests`、`BatchMutationsTests`、`TagCatalogTests`。不能把本包写成测试全通过。

- **真实原生事件**：批量菜单的文字、图标、左右及上下原生矩形边缘均能展开；NSMenu 追踪开始和 Escape 结束被观察到，未调用业务回调。三个真实 scope 入口逐一展开/取消，查询与选择不变；禁用批量菜单不展开，空标签和条件隐藏保持。颜色入口展开/取消不写库；真实取消按钮关闭合并 sheet，三条标签及关联待办保持原记录，context 无未保存变更。
- **程序化动作**：通过实际展开得到的 NSMenu 派发原菜单项，今天/明天、完成 true/false、标签 UUID 与添加/移除布尔值均准确。三个 scope 选择只改变各自字段，当前标签、实际列表投影和计数一致。颜色选项只保存选中两条合成标签的稳定颜色标识，第三条不变。标签选择夹具通过原 NSTableView 的 `selectRowIndexes` 建立；没有复制菜单或业务回调。这些不冒充菜单项真实鼠标选择。
- **画面/几何**：检查 en/zh-Hans × 浅深色的 580×160 批量栏、480×200 全操作/说明栏、480×500 全部事项和标签页、360pt 合并 sheet，包含长中英文合成标签。按钮严格边界/无重叠断言、文字宽度与原生缓存 PNG 结合；未放宽重叠容差。图片复用 QA 临时目录 `AreaChainButtonConsumersQA/settings-{batch,all-items,tags}-*.png`；`build/ButtonStage2F-contact.png` 为透明缓存加阅读底色的核对图，不是系统最终材质或对比度证据。

**历史失败入口**：首轮 `TagManagementPage.body` 的 `.sheet(isPresented: $showMerge) { mergeSheet }`（当时 56 行）未显式传递 locale；中文页面下的合并标题、说明、按钮仍呈英文。相邻 `TaskDetailTagSelector` 的 sheet 显式注入 locale。当轮只获准改合并取消样式，未扩展到整个弹窗的语言传播。测试保留 `usesRequestedLanguage` 失败，并继续点击实际英文取消按钮核对关闭/无提交；没有把回退语言当成中文通过。当时中文 sheet 运行验收未完成；此失败已在下述 `build/ButtonStage2F-locale-matrix.xcresult` 与七组回归包中消除，旧包不改写。

**修正与静态记录**：早期 `batch` 包把菜单 AX 紧边界误当 22pt 标签高度；随后按原生实际矩形做边缘点击，未修改全局尺寸。`consumers` 包因本轮测试辅助名笔误编译失败，已修正；`native` 包暴露动态文本读取、标签选择夹具和布局问题，`layout` / `tags` 包收敛到上述语言缺口。失败包保留。初次静态门禁还被并发 `CommandDraft.swift` 末尾空行阻断；未修改他人源码，后续该差异已自行消失。最终 `quality_gate.py --profile static`（172 项脚本测试）、`check_workflow.py`、六份本轮 Swift 的严格 SwiftLint 及 `git diff --check` 均通过，16 个相关文案键 en/zh-Hans 非空；不调用会启动非指定宿主的全量 Swift profile。

**阶段边界**：当前静态清单中普通按钮/Menu 入口实现覆盖完整，未发现并发新增的确定遗漏；不是全应用运行统一。20 个 Menu 中 13 个公共标签、6 个系统子菜单、1 个手记标签胶囊，仍按 A/B/C 分类；系统展开内容和确认框不迁移。纯消费者样式与局部布局未改变公共契约或持久化语义，不新增必需独立复核；只读清单子代理不替代 Cursor verifier。既有 Tab、持续按下、系统减弱效果、Cursor、误启动和其他消费者未验项继续保留，不重复补验。菜单项真实鼠标选择、所有完整工作台宿主组合及系统最终材质未重跑。第三阶段仍留完成框、日期/星期、分段、象限、开关、芯片/标签胶囊、导航/内容选择等特殊控件。本轮停在 F；没有提交、推送、安装、发布、真实数据操作或全局设置/签名/权限变更。

#### F 补修：标签合并弹窗语言传递（2026-10-01）

**已实现并通过本次限定验收**：先核对原失败包、生产 sheet、相邻 `TaskDetailTagSelector` 和五个 en/zh-Hans 文案资源，再用未改动用例复现。原因是该 macOS sheet 呈现边界没有显式传入测试宿主的 locale；资源已有翻译。生产改动只在 `TagManagementPage.body` 的 sheet 内容添加 `.environment(\.locale, locale)`，沿用相邻模式。没有硬编码语言或改全局偏好、L10n、文案资源、Picker、按钮样式、选择、取消、提交、关闭及保存逻辑。

| 新结果包 | 实际命中与结果 |
|---|---|
| `build/ButtonStage2F-locale-before.xcresult` | 原 `tagColorAndMergeCancellationUseOriginalSelection(locale:scheme:)` 1 项、4 次：en 浅/深色通过，zh-Hans 浅/深色因 `usesRequestedLanguage` 失败，零跳过；保留复现证据。 |
| `build/ButtonStage2F-locale-matrix.xcresult` | 修复后同一用例完整矩阵 1 项、4 次全部通过，0 失败/跳过；使用加强后的严格目标语言、文本及几何断言。 |
| `build/ButtonStage2F-locale-regression.xcresult` | 上述 F 七组全部实际命中，46 项、59 次全部通过，0 失败/跳过。较原范围增加 `reopenedMergeUsesChangedHostLanguage(scheme:)` 1 项、2 次；浅/深色各在同一页面按 en → zh-Hans → en 重开 sheet，原选择保留。 |

三个包均以 `xcresulttool get test-results summary` 和 `tests` 核对标识、参数、通过/失败/跳过数。沿既有串行 XCTest 命令及构建锁：`build/PrivacyQA`、QA Bundle ID、本地临时签名、生产 entitlement、`LSUIElement=NO`，清除六个真实钥匙串变量；方法过滤保留完整 `(locale:scheme:)` 标识，七组用套件标识。正常测试 target 编译，不排除任何源码；编译保留已有辅助 API 弃用等警告。只通过 XCTest 启动隔离宿主，使用原内存模型、独立偏好 suite 和合成数据；重开测试只改变视图环境值。

**行为与画面证据**：保留 `usesRequestedLanguage`，删除测试按英文查找控件的兜底；标题、完整说明、目标选择标签、取消和合并必须匹配预期语言。原取消回归仍经原生鼠标事件关闭实际 sheet，核对三条标签 ID/名称/颜色/删除状态及待办关联未变、没有提交合并、context 无未保存修改。现有 `TagCatalogTests` 的关联迁移、去重和来源软删除回归通过；本补修未新增 sheet 合并提交操作。Picker 默认目标保持长合成标签原文。四组参数均检查 360pt 宽、文案/Picker/按钮边界与无重叠；已查看 `settings-tags-merge-locale-*.png` 及 `build/ButtonStage2F-locale-contact.png`。后者只给透明缓存添加阅读底色，不证明系统最终材质或对比度。

**门禁与交接**：最终两份 Swift 严格 SwiftLint、`git diff --check`、`check_workflow.py` 与 `quality_gate.py --profile static`（172 项脚本测试）通过。只将原误放在 F 末尾的“本轮到 E 停止”段落移回 E，并标明 E 未接入清单的历史时点；未清理其他任务记录。第二阶段静态清单的普通按钮/Menu 接入已实现，F 本次限定回归通过；整体运行验收仍部分完成，历史 Tab、持续按下、系统减弱效果、Cursor、误启动和各消费者其他未验项原样保留。此次局部语言传递不改变公共契约或持久化语义，不新增必需独立复核。停在 F 补修，不进入第三阶段，不提交、推送、安装或发布。

### 第三阶段 A：公共启用开关与重复事项（2026-10-01）

已实现：公共 `DaybookToggleStyle` 与两个限定消费者，参数和维护位置见[组件目录](component-catalog.md)。展示沿原 `DaybookControlsPreview` 与 `DaybookButtonInteractionTests/interactiveGallery()` 入口；窗口改为 Controls，新增开关区和外部状态更新按钮。原控制面板 Toggle 保持原生。减弱效果开关明确标为按钮专用，开关只读取系统环境，不修改全局设置。

**最终验证：部分完成**。macOS 26.6.2 / Xcode 26.6 / Swift 6.3.3；沿架构文档的 QA XCTest 命令、`build/PrivacyQA`、独立标识、临时签名、生产 sandbox entitlement、六个真实钥匙串变量清除及串行参数执行，没有排除源码。最终结果包 `build/ToggleStageAReview.xcresult` 经 `xcresulttool` summary/tests 核对：18 项测试、35 次运行通过，0 失败/0 跳过。范围为 DaybookToggleStyleTests、RecurringToggleConsumerTests、RecurringItemEditorTests；SwiftDataRoutineRepositoryTests 的 `routineReEnablingBridgesSkipsAccordingToMask()`，BatchMutationsTests 的 `enablingLegacyPausedHabitFillsSkippedDays()` / `enablingAlreadyEnabledHabitDoesNotBackfillSkips()`；已有展示的 `galleryRenders(locale:dark:)` / `interactiveGallery()`。后者仅默认挂载，未保留 300 秒人工操作。正常 Debug 的 `./scripts/build.sh` 重新构建、验签通过，未安装或启动该产物。

- **状态与事务**：原生鼠标事件验证往返、单次写入、外部更新与拒绝更新；滑块左右像素独立核对真实显示。辅助操作经公开 AX selector 程序化派发，核对隐藏名称、状态和禁用不写入。新建不落库/取消不创建、合成记录启用值、失败保留草稿并重试通过。管理行沿原事务保存，注入提交失败后数据/显示回滚，暂停/恢复规则及历史回填回归通过。相邻标题草稿、失焦保存、检查器动作和几何无重叠通过；删除确认的完整操作链未重跑。
- **焦点与事件边界**：补充对照发现 `.focusable()` 默认 edit 交互会在鼠标点击时抢走原生开关保留的标题焦点，已改为 `.activate` 并保留对照断言。最终 `TOGGLE_KEYBOARD_ACTIVATION enabled=false`：验证当前系统策略拒绝焦点、空格不写入，以及新旧开关的标题焦点行为一致；不是开启键盘导航后的正向切换证明。空格按住/重复、释放单写与禁用/失焦取消在生产路径实现，但先前 edit 试验的正向结果不计入最终验收。没有跳过焦点断言或修改全局键盘设置。
- **布局与视觉**：长中英文开关 320×220、真实新建布局 440/560×640、管理行 440×520、展示 760×640，浅深色参数化几何/缓存图通过；已查看新开关长标签及两个消费者的最终缓存图。缓存图不证明系统最终材质；完整工作台、所有最小高度组合、悬停/持续按下的真人观察、Tab、真人辅助功能及系统减弱动态效果运行中联动未验。按钮专用预览不作为开关证据。
- **失败与门禁**：探索中的隐藏名称、测试宿主观察、焦点行为与测试作用域错误均经修正后重跑；原生 NSSwitch 对照曾因同步 mouseDown 未先排入 mouseUp 停滞，仅终止本次测试进程并修复事件队列，未直接打开 QA App。并发新增 ContentQueryHandoffTests 的比较编译错误曾阻断测试，待其被并发任务修复后重跑，没有修改或排除该源码。最终九份本阶段 Swift 严格 SwiftLint、`git diff --check`、`check_workflow.py`、53 项检查器测试与 `quality_gate.py --profile static`（173 项脚本测试）通过。正常目标保留已有辅助 API 弃用警告；为遵守限定隔离范围，没有机械运行 default auto / 全量 Swift profile。

新增公共控件所需 Cursor verifier 当前无可调用工具，依项目规定不替换复核机制，故阶段整体仍部分完成。第二阶段静态接入及 F 限定回归是独立历史证据，Tab、持续按下、系统减弱效果、Cursor、误启动及其他消费者未验项保持。只记录后续设置/剪贴板/隐私 Toggle、普通复选框、任务完成圆圈等线索，没有迁移；本阶段到此停止，未提交、推送、安装、发布，未修改全局设置、个人签名、权限或真实用户数据。

### 第三阶段 B：公共复选框与隐私标签选择（2026-10-01）

已实现公共 `.checkbox` 表现、唯一消费者及原展示扩展，入口与后续边界见[组件目录](component-catalog.md)。默认开关和 `hiddenLabel:` 接口兼容，两种表现共用操作基础。生产消费者仅替换 `tagChoices` 一行样式，没有修改选择/初始化、busy、取消、valid、submit、认证或内容保护链。

**最终验证：部分完成**。macOS 26.6.2 / Xcode 26.6 / Swift 6.3.3，使用架构文档的 `build/PrivacyQA`、独立 QA 标识、本地临时签名、生产 sandbox entitlement、六项真实钥匙串变量清除和串行 XCTest 命令。正常测试目标编译，未排除源码，仅由 XCTest 启动宿主。`build/CheckboxStageBFinal.xcresult` 经 `xcresulttool` summary/tests 核对：17 项、55 次运行通过，0 失败/跳过。

- 实际命中全部 `DaybookToggleStyleTests` 与 `RecurringToggleConsumerTests`；`PrivacyInteractionTests/tagChoicesRemainLocalThroughCancelAndReopen(creating:environment:)`；`PrivacyButtonConsumerTests` 的 `setupValidationAndLongUnlockLayout(locale:scheme:)`、`idleCancelDismissesActualSheetWithoutSubmitting(setup:)`；原展示 `galleryRenders(locale:dark:)` 与 `interactiveGallery()`。后者只默认挂载，未保留人工操作窗口。
- 绑定往返、单次写入、外部更新、拒绝更新、禁用鼠标/AX 不写入、名称/值、方框与标签两侧点击通过。滑块旧像素断言保留；新增方框像素比较确认外部更新改变外观、拒绝写入不滞留错误状态。原生 `.checkbox` 与公共复选框的相邻输入焦点单独对照通过；旧 `.switch` 对照和重复事项标题/保存失败回归通过。
- 隐私表单使用内存模型、合成标签、`MemoryVaultConfigurationStore`、`FakeSystemVaultKeys`，始终 `probeSystem: false`。创建/管理 × en/zh-Hans × 浅深色，等待原初始化任务产生私密标签选中值，检查密码标签初选、软删过滤/保留及排序。分别点不同标签后，仅对应 AX 选择变化，模型 ID/名称/排序/删除/私密值不变，context 无未保存修改；取消不提交，重开恢复原初选，配置仍空、fake key 集合仍空。未点击 Apply，未进入认证、文件面板、备份或内容保护链。
- 长标签公共布局 320×220、实际 480pt 表单及 760×640 展示通过参数化检查；已查看本轮长中英文、消费者和展示缓存图。图标/方框保持完整，展示外部更新使用生产控件并断言名称和值。缓存图不证明系统最终材质；本轮新增资源最终仅做缩进整理，JSON 解析对象前后相等。
- 首轮 2 次中文消费者取消失败，原因是测试 sheet 宿主未传 locale；只修正复用的 `PrivacyButtonSheetHost` 环境传递，保留严格目标语言断言，第二轮及最终轮全部通过。最终八份相关 Swift 严格 SwiftLint、54 项检查器测试、`check_workflow.py`、`quality_gate.py --profile static`（174 项脚本测试）与 `git diff --check` 通过。`./scripts/build.sh` Debug 构建/验签通过，未安装或启动其产物。为遵守限定隔离宿主范围，未运行会启动全套测试的 default auto / swift profile；指定范围的 QA 测试和严格 lint 分别提供 Swift 证据，保留已有编译弃用警告。

**未验与停止边界**：当前键盘策略关闭，两个表现实际命中策略测试，覆盖拒绝焦点/空格不写入；最终 `settings-toggle-key-policy-false.png` 是本轮产物。不是正向 Tab、空格按住/重复/释放切换或真人辅助功能的完整证明。宿主关闭动画，悬停/持续按下及系统减弱动态效果实时联动未验。指定 Cursor verifier 当前没有可调用工具，按规则不以其他代理替代，整体验收保持部分完成。阶段 A 及更早的历史未验项保持，未重试相同补验。

后续仅记录 SettingsSections 的登录启动/捕获来源/日历同步，以及 ClipboardHistoryOptions 的通用剪贴板过滤/纯文本默认/声音；应先核对实际宿主默认形态、提交、权限与失败回滚，再决定用滑动或方形入口。本阶段不迁移这些控件、其他隐私 Toggle、任务完成圆圈或子任务勾选。保留并发 Command/Query 改动，本阶段到此停止；未提交、推送、安装、发布，未修改全局设置、签名配置、权限或真实用户数据。

### 第三阶段 C：剪贴板选项布尔控件（2026-10-01）

已实现并通过本阶段限定验收。生产仅在 `ClipboardHistoryOptions.swift` 的 ignoreUniversal、plainByDefault、playSound 三处增加 `DaybookToggleStyle(.checkbox)`；原绑定、文字、字体、440×560 尺寸和其他控件不变。形态先由未修改生产页面的隔离原生截图确认：均为标签前的方形复选框；`build/ClipboardStageC-native-baseline.xcresult` 实际命中 1 项、4 次，en/zh-Hans × 浅深色通过。入口与立即保存/取消契约见[组件目录](component-catalog.md#第三阶段-c剪贴板选项布尔控件)。

**隔离与结果**：macOS 26.6.2 / Xcode 26.6 / Swift 6.3.3。沿架构文档的串行 XCTest 命令，使用 `build/PrivacyQA`、`com.areachain.privacy-qa`、本地临时签名、生产 sandbox entitlement、`LSUIElement=NO`，清除六个真实钥匙串授权变量并遵守构建锁。正常测试目标编译全部源码，只通过 XCTest 启动宿主。`build/ClipboardStageC-acceptance.xcresult` 经 `xcresulttool get test-results summary` / `tests` 核对：10 项、38 次运行通过，0 失败/跳过，实际命中：

- `ClipboardOptionsConsumerTests` 四项（16 次）：初始名称/值/布局；立即保存、取消、重开及重建；禁用不写入；未提交输入与滚动边界。
- `DaybookToggleStyleTests` 的 `bindingAndSemantics`、`disabledRejectsMouseAndAccessibility`、`longLabelLayouts`、`checkboxGraphicAndLabelShareOneAction`、`mouseKeepsNativeNeighborFocusContract`（21 次）；覆盖公共两种表现及既有原生焦点对照。
- `ClipboardHistoryRulesTests/ignoredAppPatternAndUniversalClipboard()`（1 次），仅纯规则回归。

新增夹具显式构造 session：随机目录先确认不存在再创建，独立随机 UserDefaults suite 创建失败即终止，pasteboard 为 nil，paste gate 为无副作用替身。仅清理本轮目录和 suite；没有 shared/start/stage、真实剪贴板读写、粘贴按键或声音。逐次切换比较完整测试偏好字典，确认只有对应键变化；同时检查实际偏好和新建 UserDefaults/会话读取结果、其他偏好及运行状态。原 setter 外部更新反映到页面；真实 sheet 复用显式传递 locale 的宿主，严格按目标语言查找控件，取消后偏好仍在，原会话重开及同 suite 重建均保持。

**画面与测试修正**：已查看最终中英文浅深色 sheet、禁用及长合成列表滚动截图；公共长标签 320×220 回归通过。原生输入两份未提交文本在切换后保留，未进入 patterns/types。字段边界使用 AppKit alignment rect，Toggle 语义节点仍用 AX 几何，均严格要求落在可见内容区。早期测试的动态本地化键构造、禁用属性读取及字段外框误判已修正；失败包保留。一轮签名子系统内部错误发生于测试启动前，保持参数重试成功，未改签名配置或删除旧产物。

**门禁与剩余范围**：最终两份 Swift 严格 SwiftLint、`git diff --check`、`check_workflow.py`、`quality_gate.py --profile static`（174 项脚本测试）及 `./scripts/build.sh` Debug 构建/验签通过；保留正常目标已有编译警告。为遵守本次隔离和定向范围，没有执行会启动整套测试的 auto / swift profile。本次仅消费既有样式，不改变公共 API、持久化语义或跨模块业务，不新增必需独立复核。A/B 的指定 Cursor verifier、正向键盘导航/持续按下、真人辅助功能、系统减弱效果、最终系统材质及其他历史缺口继续保留，整条控件路线仍部分验收，不重复相同补验。真实复制/粘贴、声音与监控路径本轮未验。

普通设置 `SettingsSections` 的登录启动、捕获来源、日历同步，以及其他隐私 Toggle 仅保留后续线索；须另核对形态、权限和失败处理。本阶段不迁移 Stepper、其他数值加减或上述控件，到此停止。未提交、推送、安装、发布，未修改全局设置、签名、权限或真实用户数据。

### 第三阶段 D：普通设置布尔控件（2026-10-01）

已实现并通过本阶段限定 XCTest 验收。生产仅修改 `SettingsSections.swift` 的登录启动、捕获来源和日历同步，逐项使用 `DaybookToggleStyle(.switchControl)`。修改前直接挂载真实 General/Sync 分节，保留 grouped Form 与原滚动修饰；原生节点为 `PlatformSwitch`，截图确认三处均为左侧文字、行尾滑动开关。`build/SettingsStageD-native-form.xcresult` 实际命中 1 项、4 次，中英文 × 浅深色通过。公共样式直接接入时会使滑块紧挨标签，因此仅在三个原生 Text 标签上增加撑满宽度的布局约束，恢复 Form 两端排列；没有新增公共 API、包装、状态或令牌。契约与消费者入口见[组件目录](component-catalog.md#第三阶段-d普通设置布尔控件)。

**隔离**：macOS 26.6.2 / Xcode 26.6 / Swift 6.3.3；沿架构文档的串行 XCTest 入口与构建锁，使用 `build/PrivacyQA`、`com.areachain.privacy-qa`、临时签名、生产 sandbox entitlement、`LSUIElement=NO`，清除六个真实钥匙串变量；正常测试目标编译全部源码，只由 XCTest 启动宿主。每例随机 UserDefaults suite 创建失败即失败，显式传入 AppPreferences；登录使用合成 Binding 与参数记录回调。核对了全部 `appPreferencesDidChange` 监听：AppDelegate 在 XCTest 下跳过服务装配，CalendarSync 的监听只在受测试守卫保护的 start 内注册；菜单栏及手记监听依赖未挂载的宿主，PanelWindowController 的偏好回调只刷新已有窗口外观。没有调用 start/refresh 或为测试改生产守卫。SettingsButtonTestSupport 将测试守卫前置，恢复初始化改变的 NSApp.appearance；测试另串行保存/恢复 CalendarSyncStatus 的 phase、时间戳、冲突 ID 和内容。

**最终结果包**：`build/SettingsStageD-acceptance.xcresult` 经 `xcresulttool get test-results summary` / `tests` 核对，24 项、57 次运行全部通过，0 失败/跳过。实际命中 SettingsToggleConsumerTests 的 6 项、全部 SettingsSectionPresentationTests / AppPreferencesTests、SettingsButtonConsumerTests 的通知/日历状态、登录批准和冲突回调三项，以及 DaybookToggleStyleTests 的绑定/语义、禁用、长标签、滑块回读像素、方框动作/像素及相邻输入焦点对照六项。

- 原生鼠标分别点击滑块和标签：登录接受/关闭各只请求一次正确布尔值，拒绝后回读关闭；外部 Binding 更新、错误说明、待批准说明及入口显隐保持。仅证明分节与合成宿主契约，真实 SMAppService 路径未执行。
- 捕获/日历往返切换即时写原键，每次一次原进程内通知；同 suite 重建 AppPreferences 及外部对象更新后控件跟随。对比整个测试 suite 的持久域，除对应键外保持原值，登录与通知回调不串改。启用日历后 denied/conflict 状态、重试/系统入口、双方对照及远端缺失说明仍在，不显示成功；没有启动同步。
- 禁用鼠标/程序化 AX 动作均不写入；相邻通知按钮只调用计数回调，点击开关不会触发它。严格辅助名称和值、按钮无重叠、Form 左右边界、至少 28pt 点击高度通过。中英文 × 浅深色，640×760 与原 420×560 窄窗、长登录错误/日历说明及滚动后完整边界通过；已查看对应原生缓存截图，公共长标签 320×220 也回归。截图在 QA 临时目录 `AreaChainButtonConsumersQA/settings-toggle-*`，原生基线留在 `build/SettingsStageD-native-images`；不据此宣称最终系统材质/真人辅助功能已验收。

**门禁与取证修正**：最终三份 Swift 严格 SwiftLint、`git diff --check` 及 `./scripts/build.sh` Debug 构建/静态验签通过，保留正常目标既有编译警告。最终 `check_workflow.py` 与 `quality_gate.py --profile static` 通过（174 项脚本测试，高风险/敏感日志候选均为 0）；按本次限定隔离范围不运行会启动整套测试的 auto / swift profile。首轮名称断言误把原生独立标签视为滑块自身名称；修正取证后基线通过，最终公共控件仍严格断言名称。该首轮 Xcode 还因磁盘不足无法完成诊断包，仅清理本轮未完成的冗余系统日志，测试日志/截图保留；后续使用 `-collect-test-diagnostics never`，不改变测试目标或隔离参数。新增测试辅助闭包的一次编译错误已修正，失败日志保留。

本次仅消费既有公共样式，未改变公共契约、持久化语义或跨模块业务，不新增必需独立复核。A/B 的指定 Cursor verifier、正向键盘导航/持续按下、真人辅助功能、系统减弱效果、最终系统材质及其他历史未验项继续保留；未重复条件未变的补验，整条控件路线仍部分验收。真实登录注册/注销与回读、通知权限/发送、系统设置打开、日历授权/同步/重试均未执行。后续仅保留 PrivacySetupSheet 的 legacy/system/master 三个 Toggle、ClipboardHistoryOptions 两个 Stepper 及其他数值控件线索。本阶段到 D 停止；保护并发查询领域改动，未提交、推送、安装、发布，未修改全局设置、个人签名、权限或真实用户数据。

### 第三阶段 E：隐私设置剩余布尔控件（2026-10-01）

已实现并通过本阶段限定验收。生产只在 `PrivacySetupSheet.swift` 的 `privacy.legacy.include`、`privacy.methods.system`、`privacy.methods.master` 各增加一行 `DaybookToggleStyle(.checkbox)`；`tagChoices` 保持现状，无公共 API、状态、包装、全局令牌、密码框或提交逻辑修改。修改前直接挂载生产 sheet，`probeSystem: false`，`build/PrivacyStageE-baseline.xcresult` 实际命中 1 项、4 次参数化运行；原生截图确认三者均为前置方形控件，系统方式、主密码方式、标签和旧遮罩选项的顺序保持，未套用 grouped Form 的行尾滑块结论。消费者与全业务清单见[组件目录](component-catalog.md#第三阶段-e隐私设置剩余布尔控件)。

**隔离与契约证据**：macOS 26.6.2 / Xcode 26.6 / Swift 6.3.3，沿架构文档的串行 XCTest 入口，使用构建锁、`build/PrivacyQA`、`com.areachain.privacy-qa`、本地临时签名、生产 sandbox entitlement、`LSUIElement=NO`，清除六项真实钥匙串变量。正常目标编译全部源码，只由 XCTest 启动宿主。新增 `PrivacySetupToggleTests` 直接复用 `SettingsButtonTestSupport`、`SystemPageHost`、`PrivacyButtonSheetHost` 的真实 sheet 与显式 locale；随机测试偏好、内存模型、合成标签/旧内容、MemoryVaultConfigurationStore 和 FakeSystemVaultKeys。管理配置直接注入合成值，不调用创建/解锁；等待私密标签初始化选中、sheet 位置稳定后断言。

- `build/PrivacyStageE-state.xcresult`：4 项、14 次运行全部通过，0 失败/跳过。创建未配置、管理已配置与创建已配置三种显隐；创建 includeLegacy 为 true、管理为 false；无方式、短密码、重复不一致时禁用 Apply，有效合成输入启用但不执行。系统/主密码往返保留原密码，系统单选说明随原条件显隐；includeLegacy 使候选数 1↔0、备份字段出现/隐藏，备份校验及隐藏后输入恢复保持。创建与管理取消后重开恢复初始化，标签选择不串改。
- 比较标签身份/名称/排序/颜色/私密/删除字段、手记快照及加密字段、测试偏好、配置、待清理集合、vault 代次/修订/认证状态、fake key 集合和待认证任务；模型 `hasChanges` 保持 false。仅夹具准备时保存内存合成模型，切换/取消不提交。没有点击 Apply、创建 vault、能力探测、认证、文件面板、备份、迁移或内容保护。
- `build/PrivacyStageE-regression.xcresult`：6 项、29 次运行全部通过，0 失败/跳过。命中原 `PrivacyInteractionTests/tagChoicesRemainLocalThroughCancelAndReopen`（PrivacyTagChoiceTests）及公共 Toggle 的绑定/语义、禁用、长标签、方框与文字点击、原生相邻输入焦点对照五项。两份结果包均经 `xcresulttool get test-results summary` / `tests` 核对，最终合计 10 项、43 次。复用 PrivacyButtonConsumerTests 的真实 sheet 宿主与输入/禁用取证方法；未为重跑整类引入其认证或保护场景。
- 严格中英文名称和值、文字尾部点击区、相邻控件无重叠及 480pt 宽度通过；外层 `.disabled(true)` 的生产 sheet 三项拒绝鼠标切换。中英文 × 浅深色的长说明、动态四个密码字段及滚动到底部后帮助/按钮边界通过，已查看原生缓存图。透明缓存用固定浅/深底色合成便于阅读，不将其当作最终系统材质证据。

**门禁与缺口**：最终两份 Swift 严格 SwiftLint、`git diff --check`、`quality_gate.py --profile static`、`check_workflow.py` 和 `./scripts/build.sh` Debug 构建/静态验签通过，既有正常目标编译警告保留。按限定范围不运行会启动全套场景的 auto / swift profile。初次测试比较表达式缺少括号导致编译失败已修正；一轮并发查询测试向 let 字段赋值导致全目标暂时失败，未修改/排除其源码，后续正常编译恢复。辅助属性误用对象返回调用曾导致测试崩溃，改为既有 KVC 布尔读取后通过；另一次系统设置前台导致焦点断言失败，未放宽断言。失败包/日志保留。

真实 `systemAvailable=false` 只能由被禁用的系统探测产生，未运行该分支；原禁用、说明和回退逻辑静态确认未变。busy 来源于未执行的 submit，外层禁用不冒充生产 busy 生命周期验收。正向键盘导航、持续按下、真人辅助功能、系统减弱效果、最终系统材质、A/B 指定 Cursor verifier 及其他历史未验项继续保留，整条路线仍部分验收。本次纯消费者样式接入不改变公共契约、持久化或跨模块业务，不新增必需复核，也未将不可用工具标为通过。

本轮定向检索生产 12 处业务 Toggle 均使用公共样式，滑动 5 处、方形 7 处（标签循环计一处定义）；公共实现内部原生 Toggle、测试对照、开发控制面板单独分类，未发现并发新增业务遗漏。后续仅记录 ClipboardHistoryOptions 两个 Stepper、其他数值控件、任务完成圆圈与子任务勾选，均未迁移。保留并发查询改动；到 E 停止，未提交、推送、安装、发布，未修改全局设置、签名配置、权限或真实用户数据。


### 第三阶段 F：公共数值加减与剪贴板（2026-10-01）

已实现，整体验收仍为部分完成：指定 Cursor verifier 没有可调用工具，不以其他代理替代；真实系统长按时序及辅助功能端到端仍有下述缺口。公共接口与两处消费者见[组件目录](component-catalog.md#第三阶段-f公共数值加减与剪贴板)。生产只新增 Theme 数值控件、键盘桥接和集中间距，ClipboardHistoryOptions 的两个 Stepper 直接替换；原 session setter、领域范围、Picker、Toggle、普通按钮和业务服务不变。

**原生基线**：`build/StepperStageF-native-observation.xcresult` 实际命中 2 项，0 失败/跳过。20 减不写；25 加到 35、减到 20；989 加到 999；990/995 加到 999；999 加不写、减到 989。0.35 加为 0.44999999999999996、减为 0.24999999999999997；1.9/1.95/2.nextDown 加到 2；2 加不写。挂载所有合法非对齐初值均不回写；越界操作先限制基值，再执行一步。公共整数保持该口径；小数仅在本次运算的目标端点以 8 ULP 量级消除尾差，避免 1→0.1 要求第十次微小操作，不把合法初值或中间值归一化。

**交互取证**：原生鼠标保留相邻编辑焦点；合成 1.2 秒按住只观察到一次写入，释放后无迟到写入，立即拖出仍保留按下时的一次写入，不能据此证明真实长按重复频率。原生 NSStepper 在本机全键盘导航关闭时仍接受显式焦点；上下方向在 keyDown/重复时操作，keyUp 不写，左右不写，空格沿最近的方向操作。公共控件用 NSStepper 键盘桥接避免 SwiftUI edit 焦点抢走相邻文本，桥接数值只是单次方向信号；业务唯一值仍为 Binding。鼠标按下先写一次，消费平台首次 Button 触发避免释放重复写入，持续重复由平台 Button 驱动，无自建计时器。后续用例独立核对拒绝写入、禁用、按住/拖出、释放、键盘及焦点，不能继承 Toggle 的结论。

**隔离与业务**：沿架构文档的串行 XCTest 入口与 `build/.build.lock`，使用 `build/PrivacyQA`、`com.areachain.privacy-qa`、临时签名、生产 sandbox entitlement、`LSUIElement=NO`，清除六项真实钥匙串变量。正常测试目标编译全部源码，宿主只由 XCTest 启动。消费者复用 ClipboardOptionsFixture 的随机目录/suite、nil pasteboard 和无副作用 gate，预写 32 条合成历史及合成图片字节；两条置顶不占名额，其余保留最新 20 条及顺序，成功后按原入口清理图片。在自有 `history.json.tmp` 建阻断目录注入失败，验证新 limit 仍保存、旧历史与图片保留、错误键不变；这与公共 Binding 拒绝写入分别测试。间隔只验证立即保存及同 suite 重建，不启动监控或验证真实重排程。取消只关闭；其他选项和未提交输入保留。

**最终证据**：`build/StepperStageF-acceptance.xcresult` 的 summary/tests 确认 18 项、40 次通过，0 失败/跳过，命中全部 DaybookStepperTests、DaybookStepperInteractionTests、DaybookStepperBaselineTests、ClipboardStepperConsumerTests 与 ClipboardOptionsConsumerTests。`build/StepperStageF-supplement.xcresult` 确认 7 项、10 次通过，覆盖最终上下界展示、鼠标后空格方向与四项 ClipboardHistoryRulesTests 裁剪/置顶回归。最后一处等价 lint 修正后，`build/StepperStageF-key-final.xcresult` 再次命中键盘用例 1 项通过；三份最终包合计 51 次运行、22 项去重用例，零失败/跳过。原生与公共控件在当前全键盘导航关闭时 Tab 均留在文本编辑器，正向 Tab 进入数值控件仍未验；显式 NSStepper 焦点后的上下/空格按下、重复、释放、禁用已验。公共按住 1.2 秒实际 11 次写入，拖出后保留 1 次、释放后不再写；还验证按住中禁用及恢复后下一次单击。

已查看本轮中英文 × 浅深色 440×560 sheet、长标签 320×220、焦点、滚动输入及 600×800 原有展示窗口截图；长标签换行，数值与按钮未重叠。消费者截图保存在 QA sandbox 的 AreaChainButtonConsumersQA 临时目录。最终严格 SwiftLint、工作流检查、`quality_gate.py --profile static`（175 项脚本测试）、检查器定向 55 项、全脚本 175 项及 `./scripts/build.sh` Debug 构建/静态验签通过；普通 Debug 沿已有开发签名配置只构建，隔离测试仍用 QA 临时签名。按本轮隔离边界不运行会启动整套测试的 auto/swift profile。保留正常目标既有编译警告。

早期两个结果包在并发 RoutineQueryPageTests 未完成时编译失败、零测试；待其修改后原命令重跑，未排除源码。第一次规则回归使用了错误 suite 名 ClipboardHistoryTests，结果包核对后改为 ClipboardHistoryRulesTests，四项均在 supplement 实际命中。SwiftUI edit 焦点抢占、空格方向的错误测试预期、边界禁用后指针临时状态未清理均在定向失败后定位并修正，旧失败包保留。指定 Cursor verifier 当前不可用，没有替代或宣称独立复核通过。

**保留的缺口**：真实监控重排程、真人 VoiceOver、系统减弱动态效果实时切换和最终系统材质未验；原生合成按住未触发重复，真实原生重复延迟/频率未确认。历史阶段未验项继续保留。仅在测试宿主强制语言/主题并关闭动画，不能将截图或焦点动作派发扩写成所有系统设置下的完整交互验收。未提交、推送、安装、发布；未修改全局设置、个人签名、权限或真实用户数据。数值检索剩余为 TaskDetailScheduleSection / TaskDetailDueTime 的日期 `.stepperField`，本轮不迁移日期、任务完成或其他控件。


### 第三阶段 F 补验：Stepper 重复触发与取消契约（2026-10-01）

本轮部分完成：已确认并最小修复拆卸后的迟到写入；原生与公共控件的系统长按重复等价仍未取得可信证据。上节原始 1 次／11 次及历史失败包全部保留，不用新记录覆盖原观察。

**对照方法与可证明范围**：正常测试目标、macOS 26.6.2（25G83）arm64、Xcode 26.6 / Swift 6.3.3，沿原隔离 XCTest 与 build/.build.lock 串行运行；没有排除源码、直接启动 QA App 或日用应用。合成初值统一为 500、范围 20...999、步长 10，分别检查增减方向、实际 key window 与命中位置。原生 NSStepper 实际 continuous/autoRepeat 均开启，cell 报告 delay=0.5s / interval=0.1s；内部 -2...2 是 SwiftUI 方向信号，不能误当业务范围。

`build/StepperF-delivery.xcresult` 中原辅助方法再次得到 1／11；改为按序排队、释放时现场创建时间戳，并把 Timer 明确加入 common / eventTracking，仍为 1／11。原生首写约 1ms，公共首写数 ms、首次重复约 0.48s、后续约 0.076s。观测到的首写/释放回调都在 default mode，不能据这些采样断言完整跟踪循环从未进入其他模式。`StepperF-pointer.xcresult` 中把系统指针对齐到命中点也未恢复原生重复；仅入口位置对齐不保证整个操作期间的系统输入状态。`StepperF-process-events.xcresult` 的仅本进程 CGEvent 投递两侧均 0 写入，因此不是有效长按证据，未尝试申请权限或扩大投递范围。这三个各命中 1 项的包只是取证，不是重复等价验收；诊断导出保留在对应 `*-diagnostics` 下。

正式测试辅助方法现在现场创建 down/drag/up，记录每次投递、收到的事件、相对时间、setter 方向和值；不再提前构造释放或同步 sendEvent 持有长按。应用内 NSEvent 没有建立系统 pressedMouseButtons 状态（本轮观察为 0），缺少可确认原生持续跟踪有效的系统长按输入；因此不能认定原生不重复，也不能把全部差异归因于工具。新 syntheticHoldComparison 明确输出 F_REPEAT_UNRESOLVED，只验证首写、方向/逐步值及释放后无写入，不断言重复等价或固定 1／11。100ms 首写采样窗低于原生 500ms 配置及公共约 480ms 观测，不是频率/墙钟计数容差。

**独立确认的缺陷与修复**：`StepperF-contracts-events.xcresult` 中拆离 NSHostingView 后，公共增减两方向都在释放后继续写，观察窗口内各 22 次；其余新场景通过。根因是 Button 重复回调没有原生窗口生命周期防线，onDisappear 的清理不足以覆盖宿主直接拆卸。仅在 DaybookStepper / DaybookStepperKeyboard 增加内部 attachment：AppKit viewWillMove/viewDidMove 同步关闭写入，异步刷新按钮禁用，dismantle 清空回调；不改变 DragGesture 首写、首次 Button 消费、buttonRepeatBehavior、最近方向、数值运算或消费者 setter。attachment 的同步事件防线与下一轮 UI 禁用刷新分开，避免在 AppKit 更新期间直接刷新 SwiftUI。最终键盘禁用场景仍有一次 SwiftUI “Modifying state during view update” 警告；核对未修改生产实现的 contracts-events 包，相同警告已存在，本轮未解决，不宣称零运行警告。

**最终验证**：`build/StepperF-final.xcresult` 的 summary 与 tests 树核对为 6 套、30 项、55 次运行通过，0 失败/跳过；实际命中 DaybookStepperBaselineTests、DaybookStepperInteractionTests、DaybookStepperTests、ClipboardStepperConsumerTests、ClipboardOptionsConsumerTests、ClipboardHistoryRulesTests。新增覆盖交替方向的 10 次快速点击、两方向按住/禁用/边界/拒绝写入、拖出与重新移入、释放、拆卸及同一 Binding 重建后下一次操作；既有整数/小数、键盘按下/重复/释放与两种最近鼠标方向、焦点及双语/主题/长标签回归通过。消费者沿本轮随机 ClipboardOptionsFixture 目录的 32 条合成记录验证裁剪、置顶、图片清理、保存失败及重开；没有读取真实历史或启动监控、粘贴、声音、权限流程。移除邻居焦点用例中的“至少一次”推论后，其首写/焦点断言保留，长按验证移入有逐次轨迹的新用例。没有扩大重复计数容差、合并保存或关闭重复。

最终严格局部 SwiftLint、`python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile static`（含 175 项脚本测试）、`./scripts/build.sh` Debug 构建/静态验签通过；构建日志为 `build/StepperF-debug-build.log`。按本轮隔离范围不运行会启动无关整套应用测试的 auto/swift profile。正常目标仍有既有弃用/actor 编译警告；首两次新增测试编译因默认参数的 actor 隔离失败，修正后正常目标重跑，未排除源码。最终增减两方向依然观测到 1／11，真实原生频率差异是否属于实现缺陷仍未确定；已确认的拆卸迟到写入已修复，没有把这项通过扩写成长按等价。

本轮仍保留指定 Cursor verifier 缺口，当前会话没有可调用入口且不以其他代理替代；真人辅助功能、正向 Tab、真实长按重复、监控重排程、减弱效果实时切换、最终系统材质及其他历史未验项不因此消除。未提交、推送、安装、发布，未改 session、范围、裁剪/保存规则、日期控件、全局设置、签名或权限。

### 第三阶段 G：公共任务完成控件与行内子任务（2026-10-01）

本轮只扩展 ModernCheckbox 并接入 TaskRowSubtaskInlineList；接口、尺寸、动作及下一阶段边界以[组件目录](component-catalog.md#第三阶段-g公共任务完成控件与行内子任务)为权威来源。保留前期/并发变更，ModernTaskTitle、TaskRow/检查器/四象限调用及 PendingCompletionManager 未修改。

原生基线在生产修改前运行：主任务行 14 项通过；新基线的四个参数组合发现旧子任务 AX 框是 12×12，而非声明的 14×14，空心圆中心合成鼠标事件不回调。保留截图于 build/CompletionG-before，诊断于 build/CompletionG-baseline-diagnostics。公共 contentShape 修正该命中区域，圆圈仍为 12；主任务仍 17/20。公共辅助元素需要显式 accessibilityAction 才能完成程序化激活，新增回调转接与禁用守卫，名称和选中 trait 保持。

**最终证据**：macOS 26.6.2（25G83）arm64 / Xcode 26.6 / Swift 6.3.3，正常目标完整编译，沿架构文档的 PrivacyQA 命令、build/.build.lock、QA bundle、临时签名、生产 sandbox entitlement、LSUIElement=NO 与六项真实钥匙串变量清除，串行运行 ModernCheckboxTests、InlineSubtaskCompletionTests、TaskRowInteractionTests、PendingCompletionTimingTests、QuadrantLayoutTests、SubtaskModelTests、ModelChangesTests、DaybookButtonInteractionTests。最终 57 项测试、含参数化共 81 次运行，零失败/跳过；结果包 `build/PrivacyQA/Logs/Test/Test-AreaChain-2026.10.01_22-31-47-+0800.xcresult`，日志 `build/CompletionG-final-tests.log`。已核对测试树中 4 项 PendingCompletionTimingTests 均 Passed，保留 400ms 真正驻留、期间反悔取消、批量延迟及减弱效果直提；未用普通测试默认跳过证明时序。

公共测试覆盖外部正反状态/拒绝后稳定缓存图、中心与边缘命中、禁用鼠标及辅助激活、重建/拆卸与动画后的动作次数。消费者使用内存容器与合成内容，点击第二个子任务只更新其 UUID；经实际 TaskRowFactory / DayBoardMutations / 仓储保存，可由新 ModelContext 读取；父完成/选择/标题编辑/检查器不触发，非空拖动 payload 的原宿主和相邻未提交 SyntaxTextField 保留。保存失败使用原 ModelChanges.transaction 的 save 注入：模型回滚且不重试；随后主动重投影快照验证显示恢复。该用例发现原生观察在回滚后可能保留旧投影，不能据此声称所有真实宿主自动刷新已验证，本轮未修改失败链。检查器完成/未完成与三个按钮边界、四象限真实页面的完成入口/持久化/非检查器动作通过；四象限行标识落在标题 AX 框，测试按真实相邻几何定位完成按钮。

**证据分层**：XCTest 内 NSApp.sendEvent 的合成鼠标事件与 accessibilityPerformPress 的程序化辅助动作已验证，均非真人操作。中英文 × 浅深色的 320pt 长标题/邻近草稿和 760×640 既有展示均有缓存图，已查看浅深色与双语样本；截图在 QA sandbox 临时目录 AreaChainButtonConsumersQA 的 settings-completion-* / settings-inline-completion-*。这些图不证明最终系统材质。另经原 interactiveGallery XCTest 入口保留 180 秒窗口（日志 `build/CompletionG-native-event.log`），外部原生工具按路径仍绑定同标识的已有应用窗口，未能唯一定位测试窗口，未发送点击并停止取证；该测试完成仅证明挂载，真实鼠标事件/拖动、真人 VoiceOver、硬件触感与系统减弱效果实时切换仍未验证。没有用网页或另建展示应用替代。

严格局部 SwiftLint、工作流检查、quality_gate.py --profile static（含 176 项脚本测试）、检查器定向 56 项与 git diff --check 通过。`./scripts/build.sh` Debug 构建/静态验签通过，日志 `build/CompletionG-debug-build.log`；沿已有本机签名配置构建，未改配置。仅运行本轮定向隔离测试，不运行会启动无关整套应用测试的 auto/swift profile。正常目标的既有弃用/actor 警告及运行警告保留；测试开发中修正过只读系统环境值、初始化访问与滚动/辅助框定位，不排除源码、不跳过断言。

指定 Cursor verifier 在本次工具清单不可用，未以其他代理替代，交付状态保留部分完成。Stepper 已确认的拆卸迟到写入修复独立保留；1/11 长按差异、运行警告及其他历史缺口未重复取证、未消除。停在 G：详情子任务需后续核对 TaskDetailSubtasksView 的完成、编辑、失焦与保存动作；日期及其他控件未迁移。未提交、推送、安装、发布或修改真实数据、全局设置、签名和权限。

### 第三阶段 H：详情子任务完成控件接入（2026-10-01）

本轮只迁移 SubtaskRowView.toggleCheckboxButton，新增 ModernCheckbox.detailSubtask，具体几何/反馈、真实消费者、稳定检查入口及完成操作清单见[组件目录](component-catalog.md#第三阶段-h详情子任务完成控件接入)。前期 F/G 与并发搜索改动保留；不改 ModernTaskTitle、详情删除线、DayBoardMutations、仓储或持久化架构，不迁移日期、分段或其他控件。

**迁移前取证**：正常目标完整源码，沿架构 PrivacyQA XCTest、build/.build.lock、QA 标识、临时签名、生产 sandbox entitlement、LSUIElement=NO 和六项真实钥匙串变量清除，串行运行，未直接启动日用/QA 应用。`build/CompletionH-baseline.xcresult` 确认中心点击往返、正确子项、禁用/程序化辅助及原编辑测试通过；260pt 长标题、中英文与浅深色截图保存在 `build/CompletionH-before`，完成框均 12×12。编辑时点击完成标记保持同一 firstResponder、未提交草稿和零标题提交。随后 `build/CompletionH-baseline-feedback2.xcresult` 补齐水平边缘/相邻区和反馈，临时拦截 NSHapticFeedbackManager.defaultPerformer 确认详情零次、默认/行内每动作 alignment 一次；拦截在每个测试后恢复，不改生产 API，也不等于硬件触感已验。补验首包因测试已知问题闭包中的抛错处理不正确编译失败，修正后正常目标重跑，未排除源码。

**原宿主失败与恢复**：旧实现 baseline 已发现完成保存失败时，模型恢复未完成，原 TaskDetailSubtasksView 的图形、标题删除线及计数仍停在完成/1/2；600ms 后未自动恢复。迁移后同一场景保留此缺陷，测试使用 withKnownIssue 明示，不归入自动回滚刷新通过。未手动重建或重新投影，下一次实际点击从已回滚模型提交完成，再点取消后控件/计数恢复一致；该证据只证明真实后续动作恢复，不证明失败即自动恢复。控件没有自己的镜像态；问题保留在已有 SwiftData 观察/宿主更新链，不在 H 扩大修复。

**相邻操作补充对照**：completionKeepsTagsDragRegionAndAdjacentActions 确认完成动作不修改标签、不触发编辑/删除/排序，标题拖动区域与完成框不重叠且仍保留原排序 payload；但随后合成鼠标点击标签没有移除标签。为区分迁移回归，临时只还原本轮完成按钮那一处编辑，正常目标重跑同一用例，`build/CompletionH-old-tag2.xcresult` 实际命中 1 项且同样失败，随后恢复新组件。标题覆盖层与原标签代码未改变；将这一旧合成鼠标问题单独标为已知问题，不扩展为所有真实标签操作失效的结论。第一次单方法筛选缺少括号，`build/CompletionH-old-tag.xcresult` 实际为 0 项，未算通过，修正筛选后才采用上述证据。

最终回归前的 `build/CompletionH-acceptance.xcresult` 因并发新增 RecordImageQueryPresenceTests 的方法语法错误未进入运行；待该文件修正后重跑正常目标，没有排除或修改并发源码。后续 acceptance2 包验证 108 次运行通过，另有上述标签失败和回滚刷新已知问题，不能当作最终全部通过。

**最终有效证据（跨日完成于 2026-10-02）**：macOS 26.6.2（25G83）arm64、Xcode 26.6 / Swift 6.3.3。`build/CompletionH-final.xcresult`、`build/CompletionH-title-final.xcresult` 与 `build/CompletionH-gallery-final.xcresult` 的 summary/tests 树已逐一核对；后两包覆盖最后修改的标题夹具及展示文案/控件。去重覆盖 11 套、73 项：71 项通过，2 项上述已知问题，0 跳过；含参数化的最终有效结果为 108 次通过、2 次已知问题，没有未处理的新失败。final 包自身仍含 1 项已被补验替代的失败，不能把它单独称为全绿：新增外部标题测试最初未输入内容就断言 Escape 零保存，观察到既有失焦保存；夹具恢复先核对外部初值、再实际输入草稿的路径，取消/零提交断言保留，title-final 的 5 项/6 次全部通过。gallery-final 的 8 项/27 次通过，展示标题中英文均补上详情表现。

实际命中 ModernCheckboxTests、ModernCheckboxFeedbackTests、DetailSubtaskCompletionTests、SubtaskTitleEditingTests、InlineSubtaskCompletionTests、TaskRowInteractionTests、PendingCompletionTimingTests、QuadrantLayoutTests、SubtaskModelTests、ModelChangesTests、DaybookButtonInteractionTests。包括真实详情/标签清单、正确子 UUID、单次动作、外部更新与拒绝、墓碑过滤/顺序/计数、编辑中完成保持焦点、Return 保存/失败重试、Escape 取消及失焦保存/失败草稿。标签辅助激活可移除且不触发完成，合成鼠标问题仍明确标记。PendingCompletionTimingTests 四项实际 Passed，保留 400ms 驻留、期间取消、批量时序与减弱效果直提；不是普通测试跳过延迟的推论。

迁移前后八张 en/zh-Hans × 浅深色 × 完成/未完成的 260pt 长标题图，以及原宿主回滚失败图，PNG 逐字节一致；已查看实际浅深色与双语样本。对应 `build/CompletionH-before` / `build/CompletionH-after`，当前截图仍在 QA sandbox 的 AreaChainButtonConsumersQA。760×640 原展示直接显示三种生产完成控件、两态禁用和外部更新，已查看最终画面；截图与程序化辅助/合成鼠标证据不扩写为真人输入、系统材质或真实拖动验收。标题指针区/排序 payload 与完成框分离；真实悬停操作及拖动排序仍保留历史真人验证缺口。

最终严格局部 SwiftLint、工作流检查、检查器定向 56 项、quality_gate.py --profile static（含全部 176 项脚本测试）及 git diff --check 通过；`./scripts/build.sh` Debug 编译/静态验签通过，日志 `build/CompletionH-debug-delivery.log`。只使用既有本机配置构建，QA 使用命令行隔离参数；未修改签名配置。遵照本轮隔离宿主范围不跑会启动无关整套应用测试的 auto/swift profile；定向测试没有排除源码。正常目标的既有弃用/actor 警告与历史运行警告继续保留。

指定 Cursor verifier 在本轮工具清单没有可调用入口，未替代或宣称通过，交付保留部分完成。Stepper 的长按差异与运行警告、真人输入/VoiceOver、硬件触感、真实拖动、系统减弱动态效果实时切换、最终系统材质和其他历史未验项继续保留，不重复相同取证。未提交、推送、安装、发布或修改真实数据、全局设置、个人签名及权限。

### 第四阶段 A：公共下拉选择器与剪贴板（2026-10-02）

本轮只建立 DaybookPicker 并接入 ClipboardHistoryOptions 三处；接口、默认值、缺失值策略与后续清单以[组件目录](component-catalog.md#第四阶段-a公共下拉选择器与剪贴板)为准。保留前期/并发修改，不改 ClipboardHistorySession 或真实数据、全局设置、签名、权限。

修改前 `build/PickerA-baseline.xcresult` 实际命中 1 项/4 次；补验 `build/PickerA-native-events.xcresult` 命中 2 项/5 次，均无失败/跳过。直接挂载生产 440×560 页面：标签在左，当前值/双箭头在右，SwiftUIPopupButtonCell 的原生入口高 24pt，选中项有勾。通过合成 NSEvent 打开/Escape 取消不写偏好；Return 重选当前项调用 setter 保存 13 个原键，↓+Return 从 mixed 切到 exact，pattern 输入焦点与未提交正文保留。菜单项程序化派发单独验证三者重选当前项；不将其当作真人点击证据。迁移后改用原生 NSPopUpButton + 公共菜单入口，高 28pt、无系统常驻灰底，双箭头与原生菜单继续保留，并显式提供控件名称。

运行沿原串行 PrivacyQA XCTest、build/.build.lock、正常完整目标及六项真实钥匙串授权清除；没有排除源码或直接打开 QA App。消费者复用随机目录/suite、nil pasteboard、无副作用 gate，只读写本例合成历史/偏好，不调用 shared/start/stage、监控、声音或系统权限。首轮 contracts 包的失败是 NSCell 启用属性读取方式返回 nil，改用 KVC 原生属性后保留禁用/零写入断言重跑；该包不当作通过。展示浅深色补验显式向外层宿主传入 scheme，避免宿主默认 light 覆盖展示的 dark 偏好。

**最终有效证据**：`build/PickerA-acceptance.xcresult` 的 summary/tests 树确认 ClipboardPickerConsumerTests、DaybookPickerTests、ClipboardOptionsConsumerTests、ClipboardStepperConsumerTests 共 4 套、15 项、46 次运行通过，零失败/跳过。最后新增的公共辅助/拒绝写入补验由 `build/PickerA-ax-tracking.xcresult` 覆盖（3 项/7 次全部通过）；替换旧公共测试结果后，最终去重仍为 15 项/46 次。AXPress 是程序化原生辅助操作，收到 didBeginTracking 后排队 Escape 并确认 didEndTracking，零 setter 写入；原生鼠标打开后的 ↓+Return 被拒绝时仍回显 Binding 原值。测试还覆盖相同显示文字的不同稳定值、重排及旧菜单、空/缺失选项、禁用/拆卸、每个枚举值的单项偏好变化、合成历史文件字节不变、取消重开和同 suite 新会话、未提交输入、双语/浅深色及长标签/滚动。

辅助补验首次单方法筛选得到零测试（`PickerA-accessibility`），没有当作成功或直接打开 App，已改用整套公共测试入口。`PickerA-public-final` 中 AXPress 异步开始导致预先排队的 Escape 未关闭菜单，后续断言受到残留菜单影响；仅修正测试的事件时序和失败清理，保留零写入/焦点/拒绝断言，最终由 ax-tracking 包取代，不抹掉失败记录。

本轮 `python3 -B scripts/check_workflow.py`、检查器定向 57 项、`python3 -B scripts/quality_gate.py --profile static`（含完整 177 项脚本测试）、相关文件严格 SwiftLint、文案解析与 `git diff --check` 通过。`./scripts/build.sh` Debug 编译/静态验签通过（`build/PickerA-debug-build.log`），生产编译后只追加了测试取证；没有安装或启动产物。Swift 运行验证使用上面的定向隔离命令，不调用会启动无关/非隔离宿主的 auto/swift 全量入口。已查看生产双语/主题、原展示以及 320pt 长标签位图；窗口位图不证明系统菜单材质。正常目标既有平台/actor/弃用警告保留。

指定 Cursor verifier 在本轮工具清单中不可调用，未用其他代理替代，最终保留部分完成。真人菜单/VoiceOver、系统材质、系统全键盘导航及最低支持系统未验；NSEvent 合成追踪、原生语义检查、菜单动作派发与窗口位图分别说明。H 的保存回滚后显示未自动刷新、标签合成鼠标点击问题继续登记；Stepper 1/11 长按差异、正常目标既有编译/运行警告及其他历史未验项不因本轮通过消除。本轮完成验证后停止，不提交、推送、安装或发布。
