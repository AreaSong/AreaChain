# AreaChain 质量门禁与完整开发闭环

本页是 AreaChain 的工程质量入口。它把需求、实现、注释、复用、安全、性能、测试、构建、交付和维护连接起来；它不把“规则存在”写成“运行证据已经通过”。具体产品语义仍以 [产品与功能](features.md)、[架构文档](architecture.md) 和 [使用说明](usage.md) 为准。

## 使用方式

用户只需用自然语言描述目标。代理自行读取 [项目规则](../AGENTS.md)、[技能路由](../skill-routing.md)、[组件目录](component-catalog.md) 和相关源码，再根据影响选择门禁；不要求用户提供技能名或路径。

从仓库根目录运行默认入口：

```bash
python3 -B scripts/quality_gate.py
```

常用范围：

```bash
# 只做文档、规则和本地静态门禁
python3 -B scripts/quality_gate.py --profile static

# 纯 UI / 视图微调：加 SwiftLint 和 Xcode 编译验签，只跑同名或引用测试，没有则豁免
python3 -B scripts/quality_gate.py --profile ui

# 任意场景仅验证编译通过，跳过运行测试套件
python3 -B scripts/quality_gate.py --profile swift --build-only

# Swift 业务逻辑变更：加 SwiftLint 和定向 Swift 测试（按变更推导，或显式指定目标）
python3 -B scripts/quality_gate.py --profile swift --only-testing AreaChainTests/DayBoardLogicTests

# 性能相关变更：核对基线并运行登记的性能测试
python3 -B scripts/quality_gate.py --profile performance

# 明确需要全量回归时：执行完整 Swift 测试套件
python3 -B scripts/quality_gate.py --profile full

# 明确需要候选包时：在 Swift 验证后构建并核验 Release
python3 -B scripts/quality_gate.py --profile release
```

`auto`（默认）根据当前差异选择最小适用范围。需要机器读取时加 `--format json`。定向测试由 [swift_test_scope.py](../scripts/swift_test_scope.py) 按变更文件逐个推导，不限文件数，改什么测什么，两类取并集：① 同名测试（`Foo.swift` → `FooTests.swift` 里声明或扩展的套件）；② 引用测试——变更文件声明的类型被哪些测试套件直接引用，夹具文件再展开一跳；只含扩展的文件（如 `extension UnifiedSearchController`）按扩展块里非私有、非通用的成员名直接匹配（不经夹具再展开），不把被扩展类型的全部使用者带上；出现在 30 个以上测试文件里的常见成员名（如 `accept`）没有区分度，跳过并在说明里列出。两类都找不到时不再按层目录兜底，列为无法推导：只编译并给出 `swift-test-scope` 提示。被大量测试引用的核心文件（超过 60 个测试类）不再跑全部直接引用，只跑同名测试加一组固定冒烟集（`SMOKE_SUITES`，覆盖统一搜索、任务、手记、隐私、菜单栏），说明里列出省略的引用数；整次推导超过 120 个测试类时同样收敛到同名测试（含被改测试文件自己的套件）加冒烟集。经协议、夹具链、运行时或被省略的引用间接受影响的测试，留给用 `--single` 替换日常应用之前的那次 `--profile full`。只看推导不运行时加 `--plan-only`（可配 `--format json`）。夹具无论单独成文件还是写在套件文件里（非 private 顶层类型）都会展开。改动测试文件时跑它声明或扩展的套件，加上经其共享夹具受影响的套件；删除的测试文件不需要运行。`AreaChain/` 下的非 Swift 资源按文件名找读取它的测试（如 `Localizable.xcstrings`），找不到算无法推导。兜底原因写进 `swift-tests` 的说明。

全量只由 `--profile full` 或 `release` 触发，平时各批只跑定向测试；全量只在用 `--single` 替换日常应用之前或用户明确要求时跑一次。

**已知既有失败登记表**：[`scripts/known_test_failures.json`](../scripts/known_test_failures.json) 逐条记录测试标识（类.方法）、首次复现提交与原因摘要。测试照常全部运行、不跳过；汇总时只有在各轮都正常跑完（退出码 0 或 65）的前提下，命中登记表的失败才单列为“已知”，不计入本次失败、不触发重新对照；登记表外的失败照常失败；登记用例本次实际运行且通过时，在 `swift-tests` 的问题里提示“可从登记表移除”。构建失败、超时或无法解析失败清单时不归类。

全量之外，无法推导的变更（没有同名或直接引用测试的文件、工程配置）不会静默退回全量或整层，而是报 `swift-test-scope` 警告并列出文件，同时仍编译验签；需要时用 `--only-testing` 指定或改跑 `--profile full`。纯 UI 变更（只涉及 `AreaChain/Features/`、`AreaChain/Theme/`）推断为 `ui`：编译验签后只跑同名和引用测试（单个文件引用超过 60 个时只跑同名）；都没有时豁免测试，ui 下无法推导的文件只写进说明，不报警告。

Swift 测试分两轮执行，各起一次标准隔离 QA 测试（`build.sh qa`：标识 `com.areachain.privacy-qa`、目录 `build/PrivacyQA`，首次全编译后增量复用，不碰日用应用的偏好；不带批次是因为隐私／钥匙串测试的宿主守卫要求标识精确等于它）。QA 宿主保持沙盒开启、不转发 Phase1 日志目录，所以登记的性能测试仍走 `build.sh test`（关闭沙盒、写 `phase1-logs`）以保持基线环境。测试只证明 QA 配置（`AREACHAIN_QA`）；门禁另跑一次 `build.sh build` 给日用配置的编译与验签证据：**前台轮**先跑需要前台 key window 的测试（模拟键鼠、输入法、焦点），期间不要操作电脑；**后台轮**只跑标了 `.tags(.backgroundWindow)` 的套件，窗口开在其他应用之后、不激活应用，可以照常用电脑。macOS 14 起应用让出前台后无法再强行抢回（`activate(ignoringOtherApps:)` 不再生效），所以两类不能混在一个测试进程里，也不能“先后台、要发事件再切前台”。套件里只要有一个用例发键鼠事件就不能打这个标签；标签是唯一开关：`SystemPageHost` 开窗、`UnifiedSearchNavigationFixture.start` 和 `UnifiedSearchTestHost.start` 读当前用例的套件标签，标了就只排窗不激活；导航夹具误发键鼠会直接报错，`SettingsButtonTestSupport.click` 等要求 key window 的动作也会失败。打标签前还要查 `extension 套件名` 所在的其他文件，扩展里有键鼠用例的套件不能进后台轮。混合套件（大部分程序化、少数发键鼠）的做法：原套件打标签留在后台轮，把发键鼠的用例移到同文件新建的前台套件（命名如 `UnifiedSearchNavigationClickTests`），用例内容不改。测试进程启动时系统仍可能把它拉到前台一次，点回自己的窗口即可。`build.sh qa` 默认开启前台守护（只选中 `.backgroundWindow` 套件时自动关闭，`--no-keep-front` 手动关闭；门禁前台轮显式 `--keep-front`、后台轮显式 `--no-keep-front`）：测试期间挂起 [keep_front.py](../scripts/keep_front.py)，只在用户空闲 5 秒以上、QA 应用正在运行却不在前台时，从测试进程外用 `open -b` 把它切回前台（macOS 14 起应用自己申请会被拒，Claude 等前台应用不让出时测试会一直等人点）；只接受 `com.areachain.privacy-qa…` 标识，开发宿主与日用应用同一标识，绝不激活；前 5 次切回在输出里记时间和原前台应用，结束时汇总总次数。测试结束、被中断（trap）、父进程被强制结束（守护每秒自查）或运行满 4 小时，守护都会退出。每轮测试超时：定向 30 分钟，`full`／`release` 3 小时。`build.sh test`／`qa` 用 `--skip-testing` 排除后台套件；直接调用 `build.sh` 时不会自动分轮。

推导只看源码文本：经协议、泛型或运行时间接使用的测试可能漏选，由替换日常应用之前的那次 `--profile full` 兜住。也可以通过 `--only-testing` 显式限定测试目标，或通过 `--build-only` 仅编译而不跑任何测试。脚本中的 `security-static` 和 `comment-contract` 分别守住可机械判断的安全与注释契约。SwiftLint、Xcode 编译和测试只属于 `swift`/`ui`/`performance`/`full`/`release` profile，静态 profile 不依赖 macOS 工具链，便于 Ubuntu CI 执行。非严格模式只扫描 `AreaChain` 与 `AreaChainTests`，不把 `.build` 生成文件混入历史债务；严格模式只阻断本次变更涉及的 SwiftLint 文件。警告默认不会伪装成失败，也不会阻断低风险文档任务；合并或发布前可使用 `--strict` 将警告升级为失败。

## 并发构建与测试

后续任务默认复用仓库的 `build/.build.lock`：锁忙时在同一次申请中等待最多 900 秒，取得锁后继续；超时才停止本次构建或测试并报告未完成，不自动另起一轮等待。用户在当前任务明确要求非等待时才立即退出。历史阶段的“锁忙停止”“非等待申请”及其结果保留为当时记录，不作为新任务的默认策略。

- 常规构建与测试使用 [build.sh](../scripts/build.sh) 的默认等待模式，不默认传 `--no-wait`。原 PrivacyQA 隔离命令继续使用同一把锁及相同的有界等待策略，保持完整目标、独立标识/目录、合成数据、真实授权变量清除和原生事件串行等原有要求；不能为套用普通测试命令而丢失隔离配置。
- 不删除锁文件、换锁路径或终止其他任务来绕过等待。锁文件存在或其中的 PID 文本不能单独证明锁仍被占用；文件锁的实际状态才是依据。等待期间可继续无关只读检查，并及时报告等待状态。
- 申请前记录本轮相关源码、测试、资源和构建配置的文件集合及内容摘要；取得锁后、启动构建或测试前再次核对，包括新增和删除的文件。若发生变化，先读取差异并调整受影响的测试范围，以当前源码建立本轮基线；存在会改变范围或验收结论的未决冲突时停止依赖该冲突的验证并说明原因，不覆盖他人的修改。
- 执行后再次核对同一范围。构建锁只协调遵守它的构建/测试进程，不阻止其他对话编辑源码；运行期间相关文件改变时，不把该批结果直接算作最终源码通过，查明影响后重跑受影响检查。
- 源码摘要与影响核对由执行验证的代理负责，`build.sh` 目前不自动完成这些步骤。脚本已有的 [锁竞争测试](../scripts/tests/test_build.py) 覆盖默认等待成功和显式非等待退出；这些隔离测试不证明所有对话已遵循规则，也不替代实际原生验收。

## 状态语义

| 状态 | 含义 |
|---|---|
| `passed` | 已运行并通过，或静态契约已满足 |
| `warning` | 已运行但发现需要处理的债务/人工复核项；不能写成全部通过 |
| `failed` | 检查发现可复现的问题，必须修复或明确授权暂缓 |
| `blocked` | 环境、权限或必要材料缺失，不能推断通过 |
| `skipped` | 根据影响明确不适用，不能写成未运行的通过 |

总结果只在没有 `failed` 或 `blocked` 时允许继续交付；存在 `warning` 时必须在交接中列出。`--strict` 会把 `warning` 也作为失败退出。

## 生命周期闭环

| 阶段 | 必须回答的问题 | 主要证据 |
|---|---|---|
| 需求与范围 | 目标、非目标、受影响入口、验收结果和高风险边界是什么 | 用户目标、影响/复用表、产品/架构来源 |
| 上下文与复用 | 哪个现有入口是权威实现，哪些是真实消费者 | `skill-routing.md`、`docs/component-catalog.md`、符号检索 |
| 设计与契约 | 输入、输出、状态所有权、错误、保存和兼容语义是否明确 | 架构说明、调用方、测试和必要的决策记录 |
| 实现与注释 | 责任是否留在正确层，注释是否解释不明显的原因和不变量 | Swift 源码、注释门禁、差异审阅 |
| 安全与隐私 | 是否引入秘密、敏感日志、权限扩大、数据泄露或不安全依赖 | `scripts/quality_gate.py` 安全扫描、隐私/签名规则、人工复核 |
| 性能与可靠性 | 真实热点、规模、冷/热状态、耗时/内存预算和失败恢复是否有证据 | [`performance-baselines.json`](performance-baselines.json)、定向测试、故障路径 |
| 测试与构建 | 相关行为、失败、取消、兼容和 UI 状态是否实际执行 | 脚本测试、Swift 测试、构建/验签命令及结果 |
| 原生验收 | 键盘、输入法、焦点、双语、主题、窗口和最小尺寸是否在原生宿主验证 | `areachain-verify`、隔离原生场景、截图/交互证据 |
| 文档与交接 | 组件目录、规则、快捷键、限制和变更证据是否同步 | 文档引用检查、交接记录、未覆盖项 |
| 交付与维护 | 候选物是否可追溯，发布、回退、诊断和重访条件是否明确 | [签名文档](signing.md)、下文“诊断与反馈”、授权后的发行证据 |

不是每个任务都运行所有阶段，但每个不适用或未运行的阶段都要有理由。真实钥匙串、日历、安装、数据恢复、签名身份和正式发布属于独立授权门禁。

## CI 与本地证据

`.github/workflows/quality.yml` 在 push 和 pull request 上运行不依赖 Swift 工具链的无凭据静态门禁，以及 macOS Debug 构建加全库 SwiftLint。macOS job 使用 `macos-15` 和 Xcode 16+ 能打开的工程格式；GitHub `macos-14` 会因 objectVersion 77 打不开本仓库。Swift 测试只在 `workflow_dispatch` 中运行，范围是 `HEAD^` 到 `HEAD` 差异推导出的定向测试，走 `build.sh qa`，不再因推导失败退回全量；该作业带 `--strict`，出现 `swift-test-scope` 警告会直接判失败，需要改用 `--profile full` 手动重跑。托管 runner 上该套件可能因无交互桌面而把 `build.sh test` 拖到 1800s 超时，不能把那次失败写成代码回归；全量 Swift 以本机质量门禁和隔离 PrivacyQA 为准。push 与手动 `workflow_dispatch` 使用不同的 concurrency 组，避免互相取消。`ci-contract` 只是关键标记守卫，不能替代 YAML 语义和远端执行验证。`main` 的分支保护只要求静态检查 `Static quality gates`，不要求评审，也不强制管理员遵守（避免检查名错误时锁死仓库）；它约束合并进 `main` 的 pull request，管理员直接 push 仍可绕过。工作流文件存在不等于 runner 已通过。

CI 与本地统一调用 `scripts/quality_gate.py`，不维护第二套检查逻辑。第三方 action 使用不可变 revision；修改 action、runner 或触发条件时要重新核对来源、权限和成本。

## 注释与代码可读性

- 注释解释“为什么”、不变量、平台限制、安全边界或暂时的兼容取舍；不重复代码已经表达的“是什么”。
- 公共共享组件、领域规则、跨模块契约和复杂并发/恢复路径应有简洁的契约说明；普通局部代码不要求逐行注释。
- `TODO`、`FIXME`、`HACK` 和 `XXX` 必须说明后续动作与可追踪标识；没有实际事项时不要留下占位注释。
- `token-exempt`、`control`、静态检查禁用和其他豁免必须写明原因与范围，禁止无理由的文件级关闭。
- 注释不写批次、检查点、阶段或文档章节编号，进度只放在 git 历史和文档；`check_workflow.py` 的 `progress-notes` 只在注释里匹配这些字面模式（不拦决策代号），同一行写 `progress-note-exempt: <原因>` 可豁免。
- 代码质量检查不能判断注释是否真正准确；人工差异审阅仍是必需证据。质量脚本只守住可机械判断的格式和豁免契约。

## 安全与隐私

- 不把凭据、私密正文、附件内容、用户标题、令牌或完整外部响应写入日志、测试产物或提交。
- 新的系统权限、钥匙串访问、加密、迁移、删除、外部写入和依赖引入必须按高风险边界单独核对。
- 静态扫描发现高置信秘密或私钥时失败；疑似敏感日志先报告警告并要求人工确认，不用脆弱正则替代安全审计。
- 真实安全扫描、依赖公告、系统认证和漏洞披露不由普通开发任务自动执行；缺少环境或授权时报告 `blocked`。

## 性能与可靠性

- 任何性能数字都必须关联设备/系统、构建配置、数据规模、冷/热状态、样本和测量方法。
- 现有局部阈值登记在 [`performance-baselines.json`](performance-baselines.json)；启动、大库重开、合成加密恢复、测试进程 RSS 安全网和重开增长目前是 Debug 合成数据的 `provisional` 上限。NSApplication 完整冷启动、独立 App 峰值内存和真实恢复仍未建立，不能猜数字。
- 性能优化必须同时通过功能、取消、资源释放和隐私回归；一次测试很快不等于没有泄漏或规模退化。
- 失败、重试、部分提交、迟到结果、取消和恢复路径要说明状态所有者及可重复证据。

## 覆盖缺口

各列独立：有方法不等于已自动化，已自动化不等于本次运行通过。“未运行”不是“不适用”。

| 环节 | 现有方法与自动化 | 未覆盖或不适用 |
|---|---|---|
| 需求、范围与验收 | 用户结果→入口/契约→适用验收；[产品与功能](features.md)；需要判断，未自动判定需求 | 无已授权真实业务任务的全链路试跑 |
| 架构、依赖与状态 | [架构边界](architecture.md#开发时的边界与状态核对)，沿符号追踪消费者；Domain 导入守卫 | 完整符号依赖图、所有权不由文本扫描证明 |
| 实现、共用代码与重构 | 模块内→项目共享→跨项目库按实际收益选择；相关仓储/解析测试；本地行为测试与静态门禁可运行；远端执行未取证 | 尚未以新标准完成真实重构；不强行提取跨项目库 |
| 界面、语言与交互 | [原生验收](architecture.md#隔离验收与真实启用门禁)、项目 UI/验证技能；Theme/Features 隔离测试已有 | 真实键盘/输入法/系统集成不可用离屏样例替代 |
| 环境、配置与依赖 | 下文环境记录；核对工程、清单、来源/许可证、定向回归；部分构建配置检查；无工具链固定/CI | 尚无认证过的支持版本矩阵；无第三方包时不制造锁文件 |
| Git、评审与 CI | 下文检查顺序；跨模块只读复核只走 Claude Code `verifier`（见技能路由）；本地检查与 `.github/workflows/quality.yml` 已接入；push/PR 跑静态和 macOS 编译+SwiftLint，完整 Swift 测试仍手动触发 | 完整 Swift 测试不在每次 push 上跑；分支保护仍只要求静态检查；管理员可绕过 |
| 测试、构建与验签 | `quality_gate.py`（Swift 测试走隔离 `build.sh qa`）、构建/验签；见 [signing.md](signing.md)；本地质量入口与脚本回归已接入 | 编译/候选包/原生运行是独立证据，不等于发行 |
| 数据、迁移与恢复 | `ModelChangesTests`、`SnapshotImportValidationTests`、`PrivateBackupTests`、迁移夹具；有内存/临时磁盘测试 | 全历史升级、真实恢复、RPO/RTO 与应用进程被 SIGKILL 未验收；进程内 VACUUM 由进度回调中断覆盖语句中途失败/取消后的标记保留；独立 `sqlite3` SIGKILL 覆盖辅助进程被杀后库仍可读、随后 `finish` 成功 |
| 错误、并发与资源 | 日历 generation、事务后清理、草稿/窗口生命周期；按故障注入验证；对应局部测试已有 | 排程真实失败、生产等待时序和长期泄漏未覆盖完整 |
| 性能与成本 | 1000 天连击、行交互、空库打开、2000 条重开、合成加密恢复、测试进程 RSS 安全网与重开增长；见下文；登记测试已纳入 performance profile | NSApplication 完整冷启动、独立 App 峰值内存、长期泄漏和真实恢复仍未建立 |
| 安全、隐私与供应链 | 按变更范围安全审查、依赖公告/来源核对、日志字段检查；静态候选扫描已接入本地/静态 CI | 仓库根 `LICENSE` 为 Apache-2.0；真实系统验收和完整漏洞审计仍待做 |
| 正式发行、安装与回退 | [签名文档的发行准备](signing.md#发行准备)；`distributionReady` 明确为 false；候选验签/本体回退脚本；无公证/上传流水线 | 渠道、许可证、Developer ID/公证、升级/发行验收未落实 |
| 运行诊断、故障处置 | 本地脱敏取证→复现/定位→获准修复→回归；无统一诊断导出或监控管线 | 不自动加入云遥测；止损/恢复动作需独立授权 |
| 升级、废弃、反馈与文档 | 下文“诊断与反馈”；版本支持、消费者、回访条件；引用检查已有本地入口；维护决策非自动化 | 尚无正式发布说明和全历史支持窗口；不自动创建工单/定时任务 |
| 云端账号、多租户、服务部署 | [README 的边界](../README.md#明确不做)；不适用 | 当前无自建云端/计费；设置里的 iCloud 说明不代表已实现同步 |

## 环境、配置与依赖

- 最低要求以 [README](../README.md#构建与运行) 为准：macOS 14+、Xcode 16+、Python 3.9+。本机实际工具版本不是低版本兼容通过的证据。
- 工程中的 `SWIFT_VERSION = 5.0` 是语言模式，不是本机编译器版本。`MACOSX_DEPLOYMENT_TARGET = 14.0` 也不证明已在 macOS 14 真机运行。
- 当前工程未声明第三方 Swift Package 产品依赖，脚本使用 Python 标准库。未来引入依赖时才维护对应清单/锁文件，并核对传递依赖、构建脚本、许可证、平台和升级/回退；不为“工程化”添加空包配置。
- 配置隔离仍沿 `Config/Signing.xcconfig` 和未入库的个人配置；本手册及检查器不读取个人签名内容、凭据或用户数据库。实际构建/验签由签名工具按授权读取必要有效参数。
- 每次需要环境证据时在当前环境重新查询 `python3 --version`、`xcodebuild -version`、`xcrun swift --version`；构建证据还须关联源码、配置及产物，不只记录工具存在。
- 当前工程默认版本为 `1.0.0` / build `1`；在打上发行标签之前不把构建号当成发布史。仓库根 `LICENSE` 使用 Apache-2.0；若要更换，替换该文件即可，不同时保留第二份许可证。

## 检查器的范围与边界


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

## 运行可靠性

- 日历协调通过代次与串行合并处理取消/迟到结果，局部提交失败保留基线供重试；相关 [CalendarSyncEngineTests](../AreaChainTests/Services/CalendarSyncEngineTests.swift) 使用 fake 外部服务，不证明真实 EventKit 写入。
- 草稿、窗口、附件已有生命周期/失败测试；普通测试仍跳过 400ms 驻留，[PendingCompletionTimingTests](../AreaChainTests/Features/PendingCompletionTimingTests.swift) 关闭跳过后覆盖单次、批量与减弱动态效果时序。这仍不是真人勾选的生产动画验收。
- [TaskRowInteractionTests](../AreaChainTests/Features/TaskRowInteractionTests.swift) 有行回调 100ms 阈值，[DayBoardPageProjectionTests](../AreaChainTests/Domain/DayBoardPageProjectionTests.swift) 有 40 个习惯加待办的页面投影 200ms 阈值（Debug、UTC、热身后 3 次取样取中位数），[HabitStreakEmpiricalTests](../AreaChainTests/Domain/HabitStreakEmpiricalTests.swift) 有 1000 天连续打卡 200ms 阈值（Debug、UTC、热身后 3 次取样取中位数），[HabitStreakEquivalenceTests](../AreaChainTests/Domain/HabitStreakEquivalenceTests.swift) 另有 10000 天空稀疏对照 NaiveCursor 的 200ms 上限；连击索引的产品 RSS 未建立。[LifecycleBaselineTests](../AreaChainTests/Services/LifecycleBaselineTests.swift) 另有空库打开 3000ms、2000 条重开 5000ms、合成加密恢复 8000ms，以及 2000 条重开时测试进程 RSS 安全网与 8 次重开增长上限。它们都是 `provisional`。RSS 条目测量的是 Debug 测试进程，不是独立 App 峰值；XCTest 下 AppDelegate 会提前返回，因此也不是 NSApplication 完整冷启动。已登记的局部 ID（含 `agenda-overdue-routines-1000-days`、`dayboard-month-unfinished`、`dashboard-heatmap-365`、`board-search-overdue-20x1000`、`catalog-listed-routines-40x365`）以 [`docs/performance-baselines.json`](performance-baselines.json) 为准，本段不另写预算。
- [NotificationScheduler](../AreaChain/Services/NotificationScheduler.swift) 的排程日志当前只保留请求标识、目录计数、授权状态和错误 domain/code，不输出任务标题、提醒分钟、具体触发时刻或原始错误描述；这不替代日志保留策略审查和完整安全审计。

## 诊断与反馈

1. 从用户症状、准确版本、最近变化和影响范围收集最小脱敏证据；[StoreHealth](../AreaChain/Services/StoreHealth.swift) 和 [MutationFeedback](../AreaChain/Services/MutationFeedback.swift) 是现有入口，不能把它们当成完整诊断系统。
2. 区分输入/业务拒绝、暂时失败、权限/认证、完整性损坏和部分成功。只在安全幂等且预算明确时重试；权限失败或读库失败不能伪装为空数据继续写入。
3. 用合成数据、可注入时钟/系统接口和小范围测试验证假设。暂停服务、改配置、清理缓存/数据、恢复或修复都要符合当前授权；仅诊断不实施。
4. 将明确问题转成需求或缺陷，说明优先级/影响→获准修复→回归→获准交付→用户确认；无法复现、技术债和暂缓项记录理由、责任与重访条件，不默认创建外部工单。
5. 依赖/OS/工具链升级先查兼容与安全公告；废弃接口/功能前查消费者与历史数据。影响架构/公共契约的决定就地记录，发布时再维护实际版本说明，不为每个小任务创建 PRD/ADR。

本地应用默认采用本地脱敏诊断；不自动引入遥测、云监控、日志上传或定时巡检。安全问题的审查范围、外部披露与修复/发布分别授权。

## 交接最小格式

每次实现或验收交接至少列出：

1. 改动和保持不变的契约。
2. 复用的组件/权威规则及真实消费者。
3. 实际执行的命令和结果。
4. 警告、失败、阻塞、跳过和未运行项。
5. 剩余风险、回退条件和需要重访的基线。

计划中的命令、存在的测试、构建成功或静态检查通过，都不能单独替代运行时、原生界面、恢复或正式发行证据。
