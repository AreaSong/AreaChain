# 工程与维护

## 第十阶段 O：控件收口最终整合验收与总交接

### 最终工程收口（2026-10-08）

**最终状态：本轮界定的增量范围及下述有效源码快照上，公共控件重构的代码实施与本轮工程验证已收口；整体仍为 partial。** 未发现起点范围的确定漏接；唯一普通回归失败已定位并修正测试的 AM 输入，保留全部保存断言。最终按方法/受影响路径去重为97方法/193次：191通过、2项精确H已知失败，无未解决的普通测试失败。人工确认通过；指定复核、平台证据限制与历史未知保持独立。后续并发习惯状态功能及结束时的新改动不外推为已验收，不宣称整个最新工作区通过。

本节是本轮唯一汇总入口；下方 O/P 和 H、Stepper、习惯 Bool 原记录继续保留当时结果，不能把其中旧的“待人工续验”或“下一阶段”当作当前任务。目标仍是统一公共控件实现和维护入口，保留宿主的业务、输入、提交、保存、焦点及隐私语义。本轮不新增功能或组件体系，不提交、推送、安装、发布；桌面应用入口继续暂停。

**人工确认通过。** 用户在本轮明确确认上一轮人工操作均正常，包括旁白、取消、焦点、K 输入和 L 操作。此结论以用户确认作为人工证据，不要求重复操作，不重启 Gallery。没有采集到的逐事件日志、可靠释放时间或精确辅助语义不补造；人工通过不表示用户接受全部历史风险、整体交付或授权发布。

**真实增量与可用基线。** 原 `build/Controls10O` 和 `build/Controls10O-followup/B-refresh-after.json` 已不可用；不据这些失存路径重新计算或声称复查原结果包。仍存在的 `build/Controls10P/initial.json` 为1191文件清单，摘要 `a9ae5bee9789237982bfa858950632bb8f3af99447604266733a2bbac0d9b79b`，与原 O 补验及 P 起点记录一致，作为最后全局核验后的增量清单。当前 HEAD 为 `61f4ba2cca305b7879186a6f1cd919cd92caf887` 加完整工作区，起点1301文件摘要 `b1eff9068150c8a2e4f9aa1526218a871f4913d039b08a3122cdc86c905f896b`。原 `engineering-origin.json` / `engineering-increment.json` 保存逐文件身份和变化范围，不把当前 Git diff 当历史重构全集。

Features/Theme 共36个变化文件，其中16个直接声明 View；其余为控制器、文案、业务接线及 Stepper 原生桥。15个在基线不存在；7个能从 Git 历史取到与旧 SHA-256 完全匹配的内容；14个仅有可靠旧摘要而没有匹配的旧内容，采用完整当前实现和调用方检查，不伪造逐行旧差异。对应关系与可还原差异分别在 `engineering-ui-baseline.json`、`engineering-ui.diff`。H 的 `h-due-acceptance-after.json` / `h-due-boundaries-after.json`、Stepper 的 `stepper-final-focus-after.json` 和 `build/RM1/Bool-final-source-audit.json` 仍可核对；起点 H/Stepper 直接生产路径及旧 Bool 修复未变，各旧批结果只保持其原版本效力。运行中新增的状态命令及共享服务变化另见下方并发边界。

| 起点增量入口 | 公共实现与实际消费者 | 保持的差异与检查结论 | 验证映射（实际结果见下表） |
|---|---|---|---|
| 命令参数、表单和数值 | ParameterField → DaybookPicker / DatePicker / TimePicker / WeekdayPicker；ParameterText → DaybookInputShell / DaybookTextField 的统一搜索专用编辑器 | 数值必须保留空值、无效拼写、选区和撤销，不能换成只有有效数值的 Stepper；版本菜单、时间迟到事件及原生输入内核保留。未发现漏接。 | Operation 契约、原生编辑、时间生命周期与双宿主布局。 |
| 任务字段、两步计划、子任务、习惯修改/创建 | 原 PlanList / SettingSubmission；各 Submission → UnifiedSearchPlanButton → DaybookButtonStyle；标签效果及系统结果复用原 TaskTagSummary / TaskTagEffects / TaskExternalFeedback | 只读标题、事实类型对应的状态文字和业务布局不是平行公共控件；身份、命中、辅助标识、原回调及执行资格不变。未发现漏接。 | 各真实隔离命令消费者及未提交/unknown/保存后失败守卫。 |
| H 截止与旧习惯标题 | TodoScheduleSectionView → setDue / persist(save:) → ModelChanges；旧标题 → RoutineMutationService.callSucceeded | 保存依赖只替换最终 save；同步 Bool 与 afterCommit 的 saved 独立，不能互作成功回执。无新增接入修改。 | 默认/失败自然回显/同宿主重试、嵌套/外层失败和严格 saved。 |
| Stepper 与输入消费者 | DaybookStepperKeyboard、ClipboardHistoryOptions；四普通搜索、ClipboardHistoryBrowser、CaptureField | 延迟焦点只影响呈现；禁用和拆卸守卫同步。普通搜索空白、剪贴板 verbatim、Capture 组合保护各自保持。 | 焦点生命周期、实际选项消费者、换行/撤销、三种剪贴板模式和组合保护。 |
| 浮层、滚动、日期与周布局 | 原 Overlay / OperationBoundary；搜索 ResultsContent / OperationPreview 的直接 Configurator；ObjectPicker 的局部边界；原日历/详情公共装配 | 搜索直连为已有文档化归属策略；无新滚动实现。公共浮层/羽化实现未变，原生菜单、只读标题及业务布局合理保留。 | 搜索展开/候选切换、公共装配受影响宿主及日期/周键盘边界。 |

**本轮实现：生产源码无需修改；只修正一处测试输入。** 没有新增确定漏接，不为消除历史标记重构。`UnifiedSearchRoutineInteractionTests.nativeReminderAndPriorityControls(kind:)` 复用原TM2时间用例的右移/输入a，明确09:30的AM，并在准备保存前检查原生分钟为570；原保存、假授权、其他字段和打卡记录断言全部保留。另更新本 O 汇总、组件目录和技能路由；保留全部暂存、未暂存及并发修改。起点相对 HEAD 变化的61个文案键均有 en / zh-Hans，检查边界是资源覆盖，不替代全部文案视觉验收。

**自动执行与源码对应。** 产物继续放在原 `build/Controls10P/engineering-*`，每批 selection / command / before / after / execution、xcresult 及 summary/tests 可核对；`engineering-results.json` 按真实 Test Case / Arguments 计数，不把内部循环算新增覆盖。

| 批次 | 完整目标编译 / 当前产物验签 | 实际测试与有效范围 |
|---|---|---|
| core | xcodebuild=0、codesign=0 | **33方法/58次全部通过**，0失败/跳过/已知失败/Runtime Warning。H完整7方法/9次、Stepper及消费者13方法/25次、旧Bool/真实事务/原消费者13方法/24次。申请/锁后/结束均为起点 `b1eff906…f896b`。 |
| input-assembly | xcodebuild=0、codesign=0 | **23方法/60次全部通过**，0失败/跳过/已知失败/Runtime Warning。普通搜索换行/撤销、剪贴板三模式、Capture组合保护、搜索滚动、周布局及提醒/外层原生恢复。开始 `b1eff906…f896b`，运行后 `a91af99f…9b56b9`；不声称结束时整份源码重新编译通过。 |
| command-consumers | xcodebuild=65；codesign=0只验证此前旧包 | **0方法/0次**。稳定 `b4468f7b…f25d7f` 版本在并发 `RoutineCommandReader.swift:48` 的 Optional.map 返回类型推断失败。不是原 H/Stepper 回归失败。 |
| integration | xcodebuild=65、codesign=1（产物未签名） | 报错行由并发任务改成显式 `CommandTaskTagMutation?` 后，仅补一次既定消费者、受影响Bool、日期/羽化及H AX。稳定 `d0243d23…cae5a5` 版本仍在并发新增 `RoutineEnabledCommandTests.swift:32` 的 `#expect` 宏表达式类型检查失败，**0方法/0次**。 |
| integration-corrected | 完整目标编译成功、codesign=0；xcodebuild=65来自测试失败 | 并发修正宏表达式后，原样选择器实际**56方法/101次：98通过、2精确已知失败、1普通失败**；0跳过。唯一普通失败是习惯提醒kind=2，另有一个下述Locale运行警告。源码开始 `e9d294e4…8d3729`，结束 `f8865cb9…a304c6`，仅按未受变化影响路径保留证据。 |
| reminder-regression | xcodebuild=0、codesign=0 | 局部测试修正后**5方法/10次全部通过**，0失败/跳过/已知失败/Runtime Warning。原提醒方法全部三个参数、原TM2截止、时间版本失效、习惯unknown/发布失败和创建消费者。申请/锁后/结束均为1313文件 `ad8cd1e6162401e7bbc3084dcb4e479ca33d95c4d2c201a629fcdbacf8f5b1ad`。 |

**唯一普通失败的定位。** 本批原缓存图 `engineering-reminder-failure-rm1-field-2-preview.png` / `…-saved.png` 都显示21:30，预览已是07:00→21:30，保存并未把09:30改成21:30。原生空值起点来自 `DaybookNativeTimePicker.Coordinator.update` 的当前时刻；英文12小时制输入9、30未指定AM，保留了下午的PM。原 `UnifiedSearchTM2InteractionTests.dueAssignAndClearUseTimeControl` 已显式输入a，本轮原样复用该步骤，未改生产时钟/时间政策或把预期放宽到21:30。失败详情、图的取样时间、原测试内容和最小差异分别保留在 `engineering-reminder-failure.json`、原图、`engineering-reminder-test-before.swift`、`engineering-reminder-test.diff`；最后3参数严格通过。

**有效去重。** `engineering-results.json` 逐方法取最后有效结果，修正方法和重跑方法替换旧来源，不增加覆盖，最终97方法/193次（191通过、2已知失败）。不与原 O315/770、P60/174、H27/49或Bool47/131相加。H普通截止失败仍是最终依赖内、实际 `context.save()` 前的合成抛错；自然回显和同宿主重试通过，不称真实SwiftData或磁盘故障。原runner对非Gallery保留 `sessions: missing batch session evidence`，涉及并发的批次另保留源码变化，含已知失败批保留不完全Passed；两个编译失败包及原普通失败也不改写。没有修改执行JSON或伪造Gallery回执，判定依据是结果树、完整编译/验签及进程证据。

**并发边界与停止依据。** input-assembly期间只变更五个新搜索领域文件：RoutineCheckReading、RoutineQueryMatching、RoutineOccurrenceQueryEnumeration、ImageQueryTemporal、TrashQueryTemporal；原普通搜索/Clipboard/Capture、H、Stepper和日历装配没有变。其21方法/58次未受新查询算法影响；两个统一搜索滚动方法已由integration-corrected通过结果替换。其后新增习惯启停/执行日命令、共享Routine服务/仓储/目录和RoutineStateImpact / OccurrenceDate等UI；这些不归起点36文件的复用结论。受影响的旧Bool/事务及原命令消费者已参加完整补验；期间变化的RoutineCopy / Editing / Submission主要增加状态专用分支，原五字段及创建用例不进入这些分支，关键时间/unknown/创建又以最后稳定ad8cd1版本验证。新的状态功能不因完整编译而算运行通过。

最后成功完整编译/验签及短回归的有效快照是上述ad8cd1；随后观测为1313文件 `ead25c5a83d1dc2602bdf36cdf0c0c11a87ade03b4002ac3387e5a74d0e935e9`，又变更RoutineEditing、RoutineStateTests和RoutineTestSupport。该观测不是已编译版本，后续当前清单见 `engineering-final-source-audit.json`，不无限追赶或宣称最新工作区整体通过。不接管并发状态功能、不回退或排除其源码；原任务应为这些新变化保留自己的验收。

**环境与进程。** Xcode26.6（17F113）、macOS26.6.2（25G83）arm64；完整正常 AreaChain scheme / Debug PrivacyQA，原独立 `build/PrivacyQA-Controls10P`、`com.areachain.privacy-qa`、local/ad-hoc及原sandbox entitlements，LSUIElement=NO。六批原锁单次900秒上限内均立即取得，前后核对源码；只由XCTest启动、合成内存/临时数据和假系统依赖、六项钥匙串变量清除、原生串行。观察到 `69146:1791435419:155803`、`70593:1791435611:653791`、`78130:1791436993:499436`、`84863:1791438005:686782`，均以libproc内核启动身份确认退出；两个编译失败批没有测试进程。同路径最终无残留，不附着或关闭其他任务。SDK AX弃用、既有actor/尾随闭包及ad-hoc提示保留；中间未签名产物已被最后成功构建替换，最终包严格验签通过，不等于安装或发行。

**门禁与停止。** 起点159个相关Swift严格SwiftLint通过；并发183文件批曾报RoutineCommandReader超长行，修正后185文件通过；原失败日志保留。最终本轮测试修正后再次执行适用严格SwiftLint、工作流、严格static及工作区/暂存差异检查，证据为 `engineering-swiftlint-final.log`、`engineering-workflow-final.log`、`engineering-static-final.json` 和 `engineering-closeout-checks.json`，不把静态通过外推成运行通过。完成本轮后停止，不开新开发阶段、不重复人工验收、不无差异重跑。指定复核仍须等待实际能力；后续并发状态功能的对应版本验证留在其原任务范围。

最终187个相关Swift严格SwiftLint、工作流、严格static（234项隔离脚本测试）、工作区/暂存区差异及未跟踪文本空白检查均通过；该次结束采样与lint源码集合相同。此后另有并发RecurringToggleRepository / RoutineStateBoundaryTests编辑，未以旧lint或运行结果替其验收。四个有运行结果的选择器集合全部命中，四个本批进程均退出、同路径无残留，当次索引摘要与起点一致；没有操作暂存区。文档最终数字/边界补记后重跑受影响的工作流/static/差异检查，运行证据仍严格限定在前述有效快照。

**保留事项分类。**

- 已知问题：H两项 `outerTransactionAXClearRequiresOriginalDisplay(due:)` 本轮均实际Expected Failure，仍限于原false/true、所属分组清除按钮0≠1（DetailTimePickerTestSupport.swift:29）；模型恢复与零实际save保持普通断言，不计功能通过，未扩大 withKnownIssue。
- 运行警告：两步命令 `nativePlanOutputAndSecondConfirmation(failSecond:false)` 在SystemPageHost.swift:67保留一次“Environment&lt;Locale&gt;未安装时读取默认值”警告；严格业务断言通过，不能说零Runtime Warning，也没有证据将其归为本轮测试AM修正引入。不为消除该标记扩改命令呈现契约。
- 平台证据限制：真实SwiftData save/磁盘故障、其他macOS版本、窗口合成器/真实NSPopover、L精确释放时序及原日志未采集的细项没有新增证明；K历史同值API残留仍按原样本边界保留。用户人工确认已通过，不据这些限制重新要求旁白、取消、焦点、K或L操作。
- 历史未知：旧Capture回调差额、额外QA进程曾经产生的未确认副作用没有新证据，不重启调查、不读取真实数据追认。
- 指定复核：材料就绪、未执行；人工确认未扩大为整体风险接受或发布授权。

**指定 Cursor verifier：材料就绪、复核未执行。** 当前可调用工具元数据没有指定入口，未认证、安装或换其他代理代行。复核输入为本轮原始目标/边界、项目规则、上表及组件目录、上述可靠基线和实际增量、各批选择器/前后摘要/结果树/进程记录，以及下方原阶段证据。请返回具体问题、文件/符号出处与未覆盖项，不预设证明正确；重点核对公共入口与实际消费者、保留的数值/输入差异、默认保存兼容、Bool/saved 分离、两个 AX 已知失败的精确范围及人工/自动证据边界。

以下原阶段文字均为历史记录；当前结论以上方本轮结果和源码边界为准。

2026-10-06 至 2026-10-07。本节是控件收口的总交接入口，详细过程继续保留在原阶段记录。**2026-10-07 O 补验已将最后两个方法定位为测试装配／契约问题；本轮有效复验103方法／264次通过，按源码影响与实际方法重新去重为315方法／770次所选自动回归通过。人工、平台及指定复核仍有缺口，整体 partial；证据与边界见本节末的 O 补验记录。** 以下先封存原 O 结果：**接入闭环；所选自动回归未全部通过；整体 partial。** 第九阶段四类重复/漏接及第十阶段两处后补入口均有当前生产调用；总扫描未发现新增确定漏接。最终 A 留有第八阶段的两个历史失败方法／三次失败，B/C/D 通过；没有新确认的生产阻断。人工、平台和指定复核未完成，不能宣称全部运行验收完成。

**2026-10-08 当前兼容阻断收尾**：旧习惯标题嵌套事务Bool回归已最小修复，原失败断言及针对性回归严格通过；当前完整QA编译/验签通过，CommandExecutionRun为494行。唯一契约、源码身份、静态结果与指定Cursor材料见[习惯命令权威修复记录](unified-search-commands.md#旧习惯标题-bool-嵌套兼容修复2026-10-08)。[前批H收尾](#h-当前工作树收尾验证2026-10-08)的b5d4b2bc、旧504行和失败包保留历史效力；本轮不重验或关闭H两项嵌套AX，也不累加O315／770或P174。指定Cursor未执行，整体partial、用户未接受交付。

### 权威入口与当前消费者

P 收尾状态见[人工平台与交付判定](#第十阶段-p人工平台验收与最终交付判定)：首轮用户报告触控板及现有VoiceOver操作无异常，P最终5方法／9次定向检查通过；[P续轮](#p-续轮逐项人工操作与平台取证2026-10-07)新增实际QA截图、子窗口日志及普通搜索撤销／重做的人工反馈。精确长按时序、指定Cursor及H/K边界仍保留，续轮结束还发现并停止了非XCTest的QA进程。用户已明确决定：**保留 partial，暂不接受整体交付**。

下表为真实调用复查摘要；完整复用责任仍以[组件目录](component-catalog.md)为准。公共实现内部原生控件不算漏接；按钮间接手势链为重点抽查，不把符号扫描当完整运行证明。

| 家族 | 权威入口 → 真实消费者；保留边界 |
|---|---|
| 按钮、布尔、完成、Stepper、Picker、分段 | `DaybookButtonStyle`、`DaybookToggleStyle`、`ModernCheckbox`、`DaybookStepper`、`DaybookPicker`、`DaybookSegmentedControl` → ClipboardHistoryOptions、SettingsSections、PrivacySetupSheet、任务/子任务行、TagManagementPage、MenuBarPopoverView/Header、CalendarPage。系统菜单、完成控件三种呈现和宿主业务回调保持。 |
| 日期、时间、星期、月历、习惯月历、周头 | `DaybookDatePicker`、`DaybookTimePicker`、`DaybookWeekdayPicker`、`DaybookDateCell`、`DaybookWeekdayHeader` → DaySchedulePicker、详情排期/截止、ResidentsPage、CalendarMonthGrid、HabitCheckMonthView、CalendarWeekBoard。民事日、分钟、掩码与统计口径不互换，standingMenus 保留系统星期菜单。 |
| 普通/安全输入、搜索、捕获、编辑 | `DaybookInputShell`、FormTextField/SecureField、TextField/TextEditor、SyntaxTextField/Editor → 三类表单、安全弹窗、四普通搜索、ClipboardHistoryBrowser、CaptureField、手记/详情编辑。四搜索显式 searchWhitespace，剪贴板唯一 verbatim；捕获键盘与按钮共用 submitDiary，检查自有编辑器组合文本。UnifiedSearchFieldCell 专用分支保持。 |
| 静态/动态表面、候选、属性、预览、帮助、气泡 | `DaybookSurface` / `DaybookFloatingSurface` → 昨日两布局、两级 MenuBarFilterFlyout、SyntaxAutocompletePopup、CaptureAttributesView、两类实时预览、SyntaxExpandableCard、RowTitleBubble/RowNoteBubble。QuadrantTitlePreview 固定 `.rowBubble(isHovered: false, isCopied: false)`，原摘要与全文转交保持；手记标题独用 observingWindowHover，其余消费者不强迁移。 |
| 滚动、scope、羽化 | 两个 `daybookScroll` 重载 → 周列、甘特、任务/手记列表、Dashboard 外层；局部成对边界定位，Host 拥有装饰与羽化绑定。DashboardView 外层显式不羽化，两横图保持原生横向容器；实际 1/0/0 已在 C 核验。 |
| 计数、色点、连击、分组、空态 | `DaybookCount`、`DaybookStatusDot`、`DaybookSectionHeader`、公共空态 → TasksPage、BoardFilterBar、FooterBar、侧栏/标签管理、任务/工作台列表。连击两列复用局部 streakMetricColumn，整数全文不套 99+；分节全文数、完成比与月历数字各保留口径。 |

第九阶段[昨日卡](#第九阶段-b昨日事项静态卡片外壳)、[筛选浮层](#第九阶段-c菜单栏筛选浮层外壳)、[连击列](#第九阶段-d连击指标列复用)、[两处色点](#第九阶段-e两处标签色点接入)均已接入；第十阶段[四象限纯装饰](#第十阶段-b四象限标题预览纯装饰接入)及[Dashboard 外层](#第十阶段-cdashboard-外层垂直滚动接入partial)也已处理。旧段落“留待后续”属于当时范围，不再作为当前漏接清单。

### 源码身份与隔离

HEAD 为 `dba0982362f389c28b468e2d03420bfbe126d7d1`，叠加起点原暂存/工作区；起点 88 个暂存文件、3 个另有未暂存修改的文件，无未跟踪文件。未冻结提交、取消暂存、回退或复制工程。原暂存二进制差异 SHA-256 始终为 `3ffa32a99337dfd8d8faa82dfab5543af56e7ba5a674c5251492d75befa8c44b`。并发 `docs/architecture.md`、`docs/component-catalog.md`、`docs/unified-search-commands.md`、`skill-routing.md` 修改单列保留，不计 O 成果。

证据目录为 `build/Controls10O`：`initial.json`、每批 `*-before.json` / `*-after.json` 保存逐文件 SHA-256、HEAD、暂存摘要；`*-command.json`、`*-execution.json`、日志、xcresult 及 summary/tests 树可对应复查。聚合算法为路径→SHA-256 字典按键排序后 JSON 编码再 SHA-256，不以 HEAD 单独代表脏工作区。

| 最终身份 | 文件数 | 聚合 SHA-256 |
|---|---:|---|
| 生产目录，整个 O 保持相同 | 562 | `97884979339b482c4698fbc4c4694031691b4eeddb6ac353be7a999450a245c4` |
| 测试目录，含本轮两处测试修正 | 598 | `59258cbbadcdc5be74fee84d3cc8363a3247909c3faba9178cf0886c2f0599ea` |
| 受版本管理构建/脚本/SwiftLint 配置 | 21 | `972b74bf3138eaf496c6962c9da47ea090a22a01ced45205257fc29e7b0fd730` |

最终 1181 文件综合摘要为 `de9a227b0b0091bde0c85b69ec4b1e7d31ad1d3e48b7bfdc502083887f38d12f`。A 起点摘要 `9c1250ad9d924cdff9cd4a7d824fb42659d0781b3dc5501d50e53bd874b84507`；A-repair/B/C/D 为 `2d4e68e6474315e333b4fa0db1aa71e38604e29874a882127c5fec849583ec00`；D-repair/screen 为最终摘要。每批内部均无相关文件变化。两次跨批差异仅为下述局部测试方法，均重跑对应方法及必要同族回归；其余所选方法与生产/配置不变，可建立最终相关源码对应关系，不是混接不同生产快照。

完整正常 PrivacyQA 目标，macOS 26.6.2（25G83）arm64 / Xcode 26.6（17F113），独立 `build/PrivacyQA-Controls10O`、`com.areachain.privacy-qa`、local 临时签名、生产 sandbox entitlement、LSUIElement=NO。所有原生执行和最后验签均申请同一 `build/.build.lock`，单一等待者、上限900秒；本轮均立即取得，没有绕锁或干预其他会话。清除六项真实钥匙串变量，合成数据、隔离偏好和串行事件；保留桌面锁定/焦点门禁，无普通宿主替代、源码排除或 test-without-building。个人 Signing.local 仅三个签名键，无 include，生效字段均被 QA 命令显式覆盖；其额外摘要采于 B 开始后并保持，不冒充 A 批前采样，内容未修改。

### 原 O 封存回归与计数

实际选择器以 `selectors.json`、`*-resolved-selectors.json` 和每批命令为准；A–D 的 `*-selector-coverage.json` 对照源码测试声明与结果树，最终分别实际命中100/90/43/82方法，无漏选。参数次数指结果树 Arguments 叶节点加非参数方法的一次执行，不把内部循环另算参数。

| 批次 | 实际入口与覆盖摘要 | 方法：通过/失败/跳过 | 参数执行：通过/失败/跳过 |
|---|---|---:|---:|
| A 公共控件与呈现 | DaybookButton/Toggle/Stepper/Picker/Segmented/Time/Date/Weekday、ModernCheckbox、Surface/FloatingSurface/StaticCard、RowBubbleSurface、LivePreview、OverlaySurface、TagHelpSurface；Stepper 只选四个基本焦点/键盘/快速点击方法，不选无效合成长按。原 ControlsPreview、非命中、身份、显隐、布局均包含。 | 98 / 2 / 0（共100） | 240 / 3 / 0（共243） |
| B 输入与提交 | DaybookTextField/Search/Verbatim、SearchMultiline 三套、ClipboardVerbatim、CaptureSubmission/MenuBarCapture/Shortcut、InputSyntax、Form/安全输入及原 UnifiedSearchInput；PrivacySecureInput 仅布局、不同值忙碌重试、Return/取消三个方法，排除 K 诊断。 | 90 / 0 / 0 | 239 / 0 / 0 |
| C 滚动与日历 | ScrollContract/Lifecycle/Native、四套 Feather、ScrollAssemblyConsumer、DashboardScroll、ScrollFeatherConsumer、CalendarWeekLayout/Span/MonthNavigation/MonthGrid、HabitMonthInteraction；周列各1、甘特内外各1、Dashboard 1/0/0、迟到回调、上中下/resize、窄周、固定导航、逐列纵滚、首次按键与草稿隔离。 | 43 / 0 / 0 | 95 / 0 / 0 |
| D 消费者与最终修复 | Yesterday、MenuBarFilter、实际 MenuBarPopoverRendering/Help（包含扩展文件的方法）、Streak/TagDot、QuadrantPreview 三套、RowBubbleConsumer/Interaction、DiaryTitleHover、TaskRowBubble、TasksPageEmptyState；DetailTimePicker 七个正常方法含回调内失败恢复，不选嵌套AX旧失败。公开 Copy/More 沿现有安全注入，手记默认复制不点击。 | 82 / 0 / 0 | 193 / 0 / 0 |
| **最终去重** | **315 个不同方法；不累加历次阶段结果** | **313 / 2 / 0** | **767 / 3 / 0（共770）** |

无 Expected Failure 计入上表；H/K 已知问题没有借排除变为通过。A 的两个历史失败仍作为本轮所选回归失败保留，不能称“自动回归全通过”。

| 本轮实际包 | 方法数 / 参数次数 | 结果与统计用途 |
|---|---:|---|
| A | 86 / 201 | 83方法/194次通过，3方法/7次失败。初版把扩展文件名当 suite，以及四个方法未带完整签名，漏选部分公共浮层/Stepper；最终经源码/结果树核对并补齐，不将零命中算通过。 |
| A-repair | 15 / 46 | 全通过；其中14方法/42次为漏选补齐，1方法/4次替换展示定位旧失败。 |
| B、C | 90 / 239；43 / 95 | 均全通过，无重跑。 |
| D | 82 / 193 | 81方法/192次通过，1方法/1次在首轮挂载前查询失败。 |
| D-repair | 10 / 19 | 全通过；重跑整个 DiaryTitleHoverTests 和 RowBubbleConsumerTests。 |
| screen | 1 / 1 | 原 interactiveGallery 完整挂载、焦点与90秒窗口期通过；这是重复运行，不增加最终方法/参数次数，不代表取得屏幕。 |

原始包共327个方法运行、794次参数执行；其中12个方法运行/24次执行为上述重复，最终仍只报315/770。最初 ioreg 返回字典的预检适配错误发生在 xcodebuild 前，0测试，不计通过。只修改两个测试：`ModernCheckboxTests.existingGalleryShowsBothPresentationsAndExternalUpdate` 用既有 reveal 显露滚动视口外的完成控件及外部更新按钮；四参数严格通过。`DiaryTitleHoverTests.observedBubbleKeepsClickBoundaryAndUnmountCleanup` 在 prepareFocus 后补同类 settle：D 原失败在43ms、任何点击前未找到观察视图；补验保留非命中、精确一次复制、移除及重挂断言并通过。未改生产延迟、断言、共享助手或 withKnownIssue。

**内部重复单列，不加到770次**：时间分钟往返为3时区×1440＝4320次；B nativeMaterialMatrix 为7入口×2材料路径×17材料＝238次导入；剪贴板三模式精确结果主循环为3×9×2＝54次、模式切换另9次。核心 undo/redo 为 repeated 的42次、queued 的15次及三个门槛内9次，共66个往返。C Dashboard 重开循环2次，12参数里的双横图滚动24次。D 手记快速往返4参数×3＝12次、跨行相邻点4次，原 lower-row 诊断另2点；D-repair 再重复同量，归入重跑而非新增覆盖。其余既有布局/材料/等待循环不折算为统一测试总数；没有 -test-iterations 重复整个套件。

### 原 O 保留失败、限制与证据层级

- **第八阶段历史失败**：`TagHelpSurfaceConsumerTests/titleNativeHoverKeepsOriginalTagExclusion()` 一次仍见 All tags；源码两端为 LiveComposerPreviewHeader 的 `!isTitleHovered` 排除条件与 titleView.onHover，消费者来自 SyntaxAutocompleteView。当前证据是直接生产组件辅助树断言失败，未证明实际绘制/命中根因。`directHelpExitCommandOwnership(focusHost:)` 两次 expanded 仍 true，裸 SyntaxExpandableCard.onExitCommand 未收到有效关闭；不同于生产 MenuBar 的本地监视器。两者均在原[第八阶段 E](#e-修复一公共浮层描边不拦截内容点击)前后保留，未新确认生产回归，也未关闭。D 的真实帮助点击、防穿透、一次 Escape、优先级和生命周期严格通过，不重新笼统列为“帮助仍坏”。
- **H**：[原时间诊断与收尾](#第十阶段-h时间清除失败回显的复现与修复定界)两项“外层事务＋AX 提前渲染”显示恢复问题仍开放，不在本轮重跑或计正常通过。D 的普通提醒/重复事项回调内恢复及外层原生点击对照通过，与它们分开；普通截止真实 save 失败仍无等价注入，未制造真实库/磁盘故障。
- **K**：[安全输入同值残留](#第十阶段-k密码确认字段同值重试残留诊断)仍保留，无错误提交证据，不足以建议生产修复；未重复全部矩阵、未修改密码流程。
- **L**：[Stepper 持续按压基线](#第十阶段-lstepper-长按重复有效性核验)仍未建立；本轮没有重跑 syntheticHoldComparison 或把点击/键盘重复称为真实持续长按。
- **已关闭问题的本轮证据**：C 支持滚动错绑、羽化、窄周及首次按键修复；B 支持[搜索撤销](#第十阶段-i-修复一普通搜索换行与撤销边界)、[剪贴板政策](#第十阶段-i-修复二剪贴板搜索保真输入)和[捕获保护](#第十阶段-j捕获按钮组合文本提交保护)；D 支持[生产帮助](#e-修复二语法帮助遮罩与-escape-路由)和[手记向上气泡](#第十阶段-n手记向上标题气泡悬停保留修复)。这些不再作为笼统未解决项。
- **人工/平台/复核**：真人 IME、系统粘贴、触控板、VoiceOver、真实 NSPopover、其他系统版本仍未覆盖。指定 Cursor verifier 当前不可调用；本轮两项只读接入检索不替代它，没有认证或换机制冒充。屏幕阶段先确认本轮 QA 可执行路径的进程运行，再以该确切路径调用 cua.getApp，返回 `-10005 timeoutReached`，未取得当前辅助树/真实屏幕；不重复同条件尝试，不把 cacheDisplay 或自动几何结果当屏幕验收。桌面工具未投递输入。

### 原 O 门禁与交付状态

完整正常 QA Debug 编译已随测试完成，同一最终包 `codesign --verify --deep --strict` 通过，Bundle ID 为 com.areachain.privacy-qa，sandbox=true；没有理由再构建日用 Debug。ad-hoc 的 Hardened Runtime 提示及原 SDK/actor 警告保留；静态验签不是系统认证或发行。最终283个实际相关Swift文件严格SwiftLint通过；工作流、static质量门禁（228项脚本回归）与工作区/暂存差异检查的最终结果见本轮产物。源码存在或旧包通过均未充作本轮运行证据。

本轮成果仅两处测试定位/挂载修正、此总交接及组件目录当前状态引用；生产代码零修改。原暂存及并发修改保持。**已登记接入缺口闭环；所选自动回归仍有上述历史失败；无新增确定生产阻断；不能宣称全部运行验收完成。** 未提交、未推送、未安装、未发布，未操作真实数据、系统剪贴板、认证或系统配置；交接后停止，不创建后续任务。

### O 补验：最后两个失败方法的契约与宿主归因

2026-10-07。本轮只校正 [TagHelpSurfaceConsumerTests](../AreaChainTests/Theme/TagHelpSurfaceConsumerTests.swift) 中的两个方法及其局部诊断支持，不改生产和共享 helper。**两个方法均归为测试装配／契约问题；未确认新的生产缺陷。** 裸窗口任意焦点全局 Escape 不是当前帮助卡的产品承载契约。原 O 的 315 方法／770 次、其中 2 方法／3 次失败保持封存；下面是补验与重新去重结果，不倒改原失败。

**标题悬停归因**：`original` 原样命中 2 方法／3 次失败。直接宿主的组件逻辑几何在 `layout-trace` 中反复由 `(32,92.5,316,199)` 变为 `(32,174,316,36)`，高度减少 163pt、顶部移动 81.5pt；窗口仍为 380×320。这是标签退出后居中宿主重排引起的标题移位和悬停往返，并非仅凭 All tags 辅助节点推断生产失败。该记录也区分了布局几何和仍处于动画中的 AX 标题框。早期几次逐帧 AX 诊断遭遇指针移出，新增守卫按失败保留，不能当作完整悬停保持证据；记录屏幕坐标及不变窗口 frame 后确认这些取样后段确有指针移动。切换为原生布局通知取证后，已在指针仍位于标题时捕捉到反复重排，不继续重复原故障。

生产路径由原 `MenuBarPopoverView → CaptureField → SyntaxOverlay → SyntaxAutocompletePopup → LiveComposerPreviewHeader` 承载：原生编辑器输入合成长标题及六个标签，尾随空格自然结束候选；未设置私有 `isTitleHovered`。生产 Overlay 的首个记录锚点约 `(11.65,222.60,356.70,171.75)`，标题为 `(42,368,253.5,16)`，标签列表的可用高为 92pt，保留真实来源锚点、空间计算和顶部对齐。进入、保持、离开分别得到气泡出现／标签退出／标签恢复。直接测试现只给自身外层固定 256pt 高并顶部对齐，匹配生产面板的固定顶部责任；两个宿主各固定两轮，逐次要求指针仍命中、标题纵向位移小于 1pt、气泡全文精确匹配、退出后六标签恢复。关闭回调、挂载次数、草稿和模型不变；未点击默认复制。观察窗固定，不延长到通过。

**独立 Escape 归因**：原 `focusHost=false` 的 firstResponder 是 `NSWindow`；`true` 的 `makeFirstResponder(contentView)` 确实成功，链为 `NSHostingView → NSHostingController → NSWindow`，但没有卡内命令焦点。局部不吞事件的监视记录确认 keyCode 53 已到达；两者仍 expanded=true。`selectNextKeyView` 没有改变该事实；外包 `.focusable()` 虽得到 `KeyViewProxy`，也没有让位于其内部的退出命令可达。可达对照使用卡内现有“关闭”按钮公开的 `setAccessibilityFocused:`，只建立焦点、不激活按钮：链变为 `KeyViewProxy → NSHostingView → NSHostingController → NSWindow`，随后一次队列 Escape 触发原卡片 `onExitCommand`。最终测试要求焦点前后 expanded 仍 true、写回为 0；按键观测恰为 `[53]`，之后 expanded=false 且 Binding 恰写回一次，token/example 均无调用。AX 布尔焦点用 KVC 读取，避免把对象返回型 `perform` helper 用在原生 Bool getter 上；共享 helper 未修改。

生产帮助继续由 MenuBar 的本地键盘路由拥有 Escape：实际编辑器焦点下的一次关闭、组合文本优先、筛选先关闭、预览／候选后续 Escape、选区和草稿保留、窗口隔离、重开、卸载及修饰键不消费，均由原七个键盘／退出方法严格复验。独立卡内命令焦点的通过不等于承诺裸 NSWindow 的全局 Escape，也不替代生产路由的证据。未直接调用关闭回调、未写 expanded=false、未增加生产监视器或 Expected Failure。

**身份与隔离**：补验目录 `build/Controls10O-followup` 保存完整命令、每批前后 SHA-256、原结果树、诊断日志和去重来源。起点与 O 的文件清单完全一致，暂存二进制摘要始终为 `3ffa32a99337dfd8d8faa82dfab5543af56e7ba5a674c5251492d75befa8c44b`。过程中并发搜索／标题命令、测试和检查器改动独立保留，不能把整个生产目录说成未变；`source-comparison.json` 列出 29 项变化／新增。文案对照仅新增 45 个 `unified.title.*` 键，原键内容无变化。四个目标生产组件、MenuBar 帮助路由、其余控件生产实现和构建／签名配置身份保持；并发影响侧重新运行原 B 全批，检查器运行新静态回归。A/C/D 未受影响的方法沿原逐方法证据复用，regression 只替换实际复验的 13 方法，不拼接不同版本的受影响方法。

沿完整正常 PrivacyQA、原 `build/PrivacyQA-Controls10O` 独立目录和 `com.areachain.privacy-qa` 标识、local 临时签名及生产 sandbox entitlement；LSUIElement=NO、六项钥匙串授权清除、合成内存数据、隔离偏好和串行原生事件保持。每次只申请同一 `build/.build.lock`，900 秒有界等待，实际最长约149秒；不换锁、不排除源码、不用 test-without-building。一次并发新增类型尚未进入编译清单、一次诊断源字符串转义错误均为编译阶段 0 测试，修正或确认对应文件出现后才续验；各原包保留，均不算通过。

| 本轮有效最终证据 | 方法／参数执行 | 结果 |
|---|---:|---|
| corrected：两个校正方法首次完整验证 | 2／3 | 通过；后续 regression 重跑覆盖，不重复累计 |
| regression：全部 TagHelpSurfaceConsumerTests＋七个生产帮助退出／键盘方法 | 13／25 | 全通过，0失败／跳过／Expected Failure；中英文、浅深色、生产356/380宽度由原帮助回归覆盖，标题诊断保持英文浅色 |
| B-refresh：并发搜索变化后的原 B 选择器 | 90／239 | 全通过，0失败／跳过／Expected Failure |

最终有效复验为 **103 方法／264 次**；其余 **212 方法／506 次**沿未受影响的 O 证据复用。`current-results.json` 保存每个方法取自哪个结果包；`summarize.py` 由原六批结果树顺序覆盖，再仅用 regression/B-refresh 的实际方法替换，确认无新增、漏选或跳过。当前 A=100／243、B=90／239、C=43／95、D=82／193，合计 **315 方法／770 次，全部通过**。这是“所选自动回归通过”的准确结论，不是完整运行验收通过。原 O 的 313／315 方法、767／770 次通过及3次失败仍保持封存值。补验所有原始包合计117个方法运行／285次执行，其中14个方法运行／21次为诊断或已被最终严格复验覆盖的重复，不另加覆盖；两次编译0测试单列。两个标题宿主各两轮属于方法内部循环。

regression 与 B-refresh 的生产／测试／配置综合 SHA-256 前后均为 `a9ae5bee9789237982bfa858950632bb8f3af99447604266733a2bbac0d9b79b`，共1191文件；生产567文件摘要 `e9818b3d2be4a95f72a24a120c599ce366e104904f71848717dc6ec212a1a861`、测试603文件 `48fdbd4a2896ed4be7271cae6e13c4854a7456d7561fbb735f9cc6c475e507f7`、原配置范围21文件 `5af1ef8d240a452ede3be63b24ca676d80d5335327d29aaddec42b0eb648d0c0`。两批之间这些源码均未变化；B期间仅工程记录和并发统一搜索文档变更，单独记录，不冒充全部文件冻结。

**证据层级与限制**：事件层记录合成鼠标投递、真实桌面指针坐标、队列 Escape 及所属窗口；逻辑层直接验证公开预览状态、精确 Binding 写回、草稿与模型，私有悬停状态由原布局／显示变化推知，未宣称读取了私有布尔值。辅助树层验证精确全文、标签、焦点及恢复；早期过渡中仍有 NSScrollView，不用单个残留节点定责。缓存图层查看两个宿主的进入／保持／离开图，标题气泡与标签实际缓存绘制和辅助树一致；原居中失败图也确有标签绘制。实际屏幕层沿确切 QA 路径调用原生工具仍返回 `-10005 timeoutReached`，未取得屏幕合成器证据，不重复同条件尝试、不以 cacheDisplay 冒充。真人 IME、VoiceOver、真实 NSPopover、其他平台版本及指定 Cursor verifier 继续未验证；H/K/L 完全单列，不重新调查或关闭。

最终13个相关Swift文件严格SwiftLint通过；完整正常QA编译随测试完成，同一锁内 `codesign --verify --deep --strict` 通过（com.areachain.privacy-qa、sandbox=true）。最终工作流、static质量门禁（含228项脚本回归）与工作区／暂存区差异检查均通过，日志保存在补验目录；SDK弃用／actor及ad-hoc Hardened Runtime提示保留，不当作系统认证或发行通过。本轮未提交、推送、安装、发布或操作真实数据、系统剪贴板、系统权限／配置；完成即停止。

### 第十阶段 P：人工平台验收与最终交付判定

2026-10-07。本轮是原 O 总交接的人工／平台与指定复核收尾，不另建收口路线。接入缺口仍闭环；O 补验的 **315 方法／770 次所选自动回归通过**及原 O 的3次失败均保留，人工参与同意、窗口挂载和构建成功都不等于场景通过。P 的最终结果在下方按实际证据填写，不擅自修改生产。

**源码与并发基线**：P 起点 HEAD 仍为 `dba0982362f389c28b468e2d03420bfbe126d7d1`；105个已暂存文件、无未暂存／未跟踪文件。逐文件对照 `build/Controls10O-followup/B-refresh-after.json`，1191个生产／测试／原配置文件无变化，综合 SHA-256 同为 `a9ae5bee9789237982bfa858950632bb8f3af99447604266733a2bbac0d9b79b`。因此原逐方法结果可复用；当前暂存摘要不同于 O，仅凭暂存变化不能推断源码变化。本轮证据置于 `build/Controls10P`，`initial.json`、`source-comparison.json` 和逐批前后清单保存对应关系。期间并发更新 AGENTS、质量门禁、路由及组件目录的构建锁约定，并再次暂存了包含本轮测试支持在内的文件；这是外部 Git 状态变化，P 未执行暂存、撤暂存或提交，也不覆盖它们。

**最小测试支持**：原 [interactiveGallery](../AreaChainTests/Theme/DaybookButtonInteractionTests.swift) 仍是唯一人工启动入口；显式设置 `AREACHAIN_PLATFORM_QA=1` 才增加 [ControlsPlatformAcceptance](../AreaChainTests/Theme/ControlsPlatformAcceptance.swift) 工具条，`AREACHAIN_CONTROLS_PREVIEW_SECONDS=600` 仍受原600秒上限。直接复用原 Gallery、SearchMultilineFixture、CalendarWeekBoard、DashboardScrollTestSupport 和 DiarySummaryRow；没有新应用或正式导航。搜索／捕获用既有合成资料和计数回调，剪贴板 session 的 pasteboard=nil；本轮不读取、备份或写入系统剪贴板。手记行只做悬停观察，不点击其真实复制／菜单动作。辅助窗口一次一个，换场景清理，Gallery 结束移除监听并释放全部子窗口。

裸 NSStepper 与 DaybookStepper 使用同一500初值、20…999范围、10步长和600×300宿主。裸控件保留默认重复配置，逐次真实 target/action 与 Binding 写入分别记录；窗口局部监听只旁观真实 down/up 和按键元数据，不吞事件、不注入合成长按。`native-trackingReturned` 仅证明原生 tracking 返回；若缺少实际 mouseUp，不冒充精确释放时序。安全输入不记录正文／明文AX值；普通输入也只记录预定合成查询的相等布尔、组合状态和计数。

**隔离与能力**：每批均使用完整正常 PrivacyQA、独立 `build/PrivacyQA-Controls10P`、`com.areachain.privacy-qa`、local临时签名、生产sandbox entitlement和LSUIElement=NO；清除六项钥匙串授权变量，只经 XCTest 启动。原 `build/.build.lock` 单一申请最多900秒，取得锁前后及运行后核对源码，不用源码排除、日用宿主或 test-without-building。当前工具元数据无可调用的指定 Cursor verifier，没有认证、安装、换机制或代理替代。原生 cua 能力仍被暴露，但 O/O补验的确切QA路径连接超时没有已确认恢复条件，本轮未重复调用。当前QA进程4078、Gallery窗口35305的 `CGPreflightScreenCaptureAccess()` 返回false；未请求权限或尝试全屏／其他窗口截图。因此本轮没有窗口合成器截图，原cacheDisplay与几何证据继续按原层级保留。真实NSPopover安全隔离宿主不存在于本入口，不启动StatusItemController；其他macOS版本也未运行。

**人工观察（用户自述，不等于自动证据）**：用户先确认现在可以参与并愿意亲自粘贴合成文本，另确认愿意使用现有VoiceOver；操作后答复“触控板，都没问题”。针对当前日志没有子窗口打开记录这一差异再次核对，用户明确答复“已逐一打开子窗口并操作，VoiceOver也检查了”。据此按下表保留人工反馈，不将同意参与或笼统观察扩写成逐键断言。输入法名称、每个控件的逐项朗读、精确选择区间与每次长按时长未单独提供。

| 场景／QA来源 | 谁及输入方式 | 实际反馈与证据边界 |
|---|---|---|
| A 键盘、中文组词／取消、Return／⌘Return、正常提交、撤销／重做；Gallery及Capture | 用户；触控板，确认执行键盘／输入法清单 | 用户报告无问题；没有逐键操作记录与提交计数可逐项对应，不能据此声明完整IME时序断言通过。 |
| B 普通搜索与剪贴板；SearchMultilineFixture | 用户；亲自粘贴预先给定的真实换行`甲↵乙`及字面`甲\n乙`，触控板编辑 | 用户确认子窗口均操作且无问题；没有对应子窗口日志、文本或结果快照。按人工反馈记录多行／字面转义、选择编辑及撤销／重做，不将旧命名pasteboard证据当系统Cmd-V。 |
| C 窄周七列、Dashboard三轴及手记气泡；原生产隔离宿主 | 用户；触控板 | 用户报告无问题；没有逐列偏移或跨行轨迹记录，本轮未单独采集羽化绘制。保留实际触控板人工观察，原合成滚动／几何证据另列。 |
| D 控件名称／状态／值／焦点、安全输入、日期、开关；Gallery及子窗口 | 用户；现有VoiceOver，触控板 | 用户明确确认VoiceOver已检查、无问题；没有逐项朗读转录。合并元素Copy/More未取得单项结果，手记复制／菜单动作没有在本轮授权执行清单中，不计动作验收。 |
| L 裸NSStepper后Daybook的长按、释放与边界 | 用户；触控板 | 用户确认逐一进入并操作且无问题；没有原生action、down/up或节奏序列可对应，因此最多保留定性无异常反馈，精确系统长按基线与等价仍未建立。 |
| 中英文、浅深色、窄布局 | 用户；按清单观察 | 用户总体反馈无异常，没有逐状态截图／逐项结论，不能宣称完整视觉矩阵通过。 |

**人工日志差异**：已确认当前QA可执行路径与进程4078；只读取其沙盒内本次命名JSONL，原样保存为 `build/Controls10P/manual-events.jsonl`。163条记录包括ready、161条Gallery窗口35305事件及closed；只有4条按键元数据，均为组合状态false的Return，其余为鼠标事件，没有P子窗口`open`、`observation`或长按trace。用户反馈与机器日志无法逐项相互印证，原因本轮未证明；保留两种原始来源，不推断用户没有操作，也不补造窗口／时序证据。人工窗口实际保留600.08秒并正常退出，监听与辅助窗口均释放；这不是测试超时，也不能给本表各场景自动打勾。

**最后的测试支持复核**：追加 `platformToolbarOpensAndRecordsScene()`，在同样760×640的Toolbar＋原Gallery宿主中，先要求真实按钮在窗口界内，再向按钮实际位置发送一组队列鼠标事件；要求一次打开、无装配失败、辅助窗口存在，并直接读取自己的JSONL确认`open`已落盘。最终该方法通过，自动诊断窗口35357→35358及计数0→关闭均有记录（`toolbar-events.jsonl`）；不是把它移植为人工窗口35305曾打开过子场景的证据。另修正局部监听闭包的Sendable返回编译警告、增加只读可测记录字段；未改生产或操作行为。`platformFixturesMountAndRelease()` 对八个入口逐个挂载／切换／清理通过；裸NSStepper只读取配置，实测continuous=true、autorepeat=true、delay=0.5s、interval=0.1s，**没有真实按压action，配置值不等于实测重复节奏**。

| P实际结果包 | 方法／参数执行 | 结果与统计用途 |
|---|---:|---|
| `fixtures.xcresult` | 1／1 | 早期八夹具挂载／释放通过；后续裸NSStepper改为直接对照，以final的重跑作为最终支持证据。 |
| `manual.xcresult` | 1／1 | 原人工入口及600秒期限／清理通过；用户观察、机器时序与截图分别判断。 |
| `final.xcresult` | 5／9 | 原按钮禁用／快捷键2参数、Gallery中英文浅深色4参数、默认人工入口1次，以及夹具清理和实际工具条点击各1次，全通过。 |

P原始运行合计7个方法运行／11次执行，0失败、0跳过、0Expected Failure、0测试超时；这些是宿主／支持检查，不是11项人工场景通过。最终复用了O未受影响的312方法／763次，只以final中原有的3方法／7次替换对应来源，原O选择范围仍为 **315方法／770次所选自动回归通过**，新增2个支持方法单列。逐方法来源见 `build/Controls10P/current-results.json`，没有重跑整套770次或把H/K已知失败删成通过。

final运行前后1192文件综合摘要同为 `9716bbf18d27eb2a2327e8e8b624817a4aa34368d6ff35f10c3ff519e028d3fc`；生产567文件仍为O补验的 `e9818b3d2be4a95f72a24a120c599ce366e104904f71848717dc6ec212a1a861`，测试604文件为 `1c39d7e36b3725929da6e1f54b0fd6a0f4cd047a527dd910da08a6380596fb96`，原配置21文件为 `5af1ef8d240a452ede3be63b24ca676d80d5335327d29aaddec42b0eb648d0c0`。只增加本测试支持文件并修改原Button测试，生产与原配置无差异。manual源摘要 `6cf6d770b5da595b8fc2a9363aa21ce98646d086ae0334a92094331536fcf2bd` 单独保留，不冒充final源上采集的人工轨迹。三批均立即正常取得原锁，完整正常QA编译与同锁内严格验签通过；最终包标识为com.areachain.privacy-qa、sandbox=true、LSUIElement=false。SDK既有弃用／并发警告及ad-hoc Hardened Runtime提示继续保留；它们不是运行认证或发行通过。期间并发统一搜索文档更新单列，不计P成果。

| 项目 | 实际现象与触发条件 | 已有证据 | 未证明的风险与当前保护 | 建议及接受决定 |
|---|---|---|---|---|
| H | 测试外层事务仍working时，经嵌套AX提前渲染nil，模型回滚720/600后时间／清除按钮未自然恢复；普通截止自身save失败没有等价注入。 | [H最终版本](#h-最终版本复验2026-10-05最终测试分层版本已验证)的5方法／11次为9通过、2已知失败；O正常提醒／原生点击路径另有有效回归。 | 不泛化为普通清除故障。模型恢复与普通提醒回调内恢复有证据；普通截止真实保存失败的自然显示仍未知。 | 保留嵌套AX限制和截止注入缺口，不建议本轮改生产。若要按限制交付，须用户接受；不等于两项测试通过。 |
| K | 同值替换相关的原生安全输入同步边界：局部Binding已空，字段/editor仍有遮蔽内容；裸与公共承载一致。 | [K控制变量补验](#k-补验安全输入替换事务控制变量对照)：18轮观测，A/B共12次清空失败，C6次通过；生产锚点无错误重试参数或额外action。 | 可能误导清空状态；未证明错误提交、完整认证链、敏感内存擦除或平台内部唯一机制。原忙碌／取消／提交保护保持。 | 保留输入路径相关边界，现证据不足以选择生产修复；不重跑旧矩阵。按限制交付须用户接受。 |
| L | 旧合成事件不能建立系统持续按压基线；P只接受本次真实按压、action和释放证据。 | [L历史能力边界](#第十阶段-lstepper-长按重复有效性核验)及本节人工／原生记录分别保留。 | 重复数字本身不能证明精确节奏／释放等价；原attachment、拆离阻断及dismantle清理保持。 | 本轮有有效数据才缩小缺口；无可靠mouseUp则只记人工重复观察。按保留限制交付须用户接受。 |

**指定 Cursor verifier 复核包——已准备，未执行**：复核任务是核对原控件收口目标（复用生产公共组件、保留输入／保存／焦点／隐私差异）、[项目约定](../AGENTS.md)、[路由](../skill-routing.md)、[原O消费者表](#权威入口与当前消费者)和[组件目录](component-catalog.md)，查找可核验问题、出处与未覆盖项，不预设证明正确。源码以P最终逐文件清单和O补验快照为准；本轮实际差异仅测试支持和这些原文档。原O/B-refresh/regression的逐方法来源见 `build/Controls10O-followup/current-results.json`；P命令、前后身份、结果树、静态检查和人工日志见 `build/Controls10P`。H/K/L、系统截图、真实NSPopover、其他系统版本与人工记录未覆盖部分必须继续审查。拟交付声明限定为接入闭环、所选自动回归有效、已实际取得的人工观察；不声称全平台验收完成。

当前 `git diff` 不能代表全部历史控件修改：前期部分修改已经进入HEAD，也没有提供统一的“控件收口前”不可变提交。本包提供当前组件／消费者身份、阶段证据与P差异，不捏造完整历史补丁范围。指定工具恢复后需交付上述原始来源，并要求返回 `file:line`、符号、复现条件及未覆盖项；本轮没有复核返回结果。

**最终交付判定**：接入闭环和所选自动回归有效；人工已参与并提供无异常反馈，P未发现新的生产阻断。工具不可用（指定Cursor、实际屏幕）、未取得的人工时序／逐项证据、历史H/K限制与产品失败分开，不能统称失败或全部通过。2026-10-07，用户明确选择：**保留 partial，暂不接受整体交付**。H/K/L和未验标记保持，不视为风险已接受，也不自动启动补验、修复或发布。

最终两个Swift文件严格SwiftLint、`python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile static --format json`及工作区／暂存区差异检查均通过；static各检查均为passed。未修改检查器或构建脚本，不另加其私有验证流程。最后再次核对final受测范围无源码变化，P专用QA进程已退出；文档最终收尾后重跑受影响静态／差异检查。能力未运行、人工缺少逐项证据及历史问题不因静态通过而关闭。

剩余动作及条件：

- 人工反馈需绑定明确当前QA子窗口：在可参与的下一次有界窗口期确认一次`open`记录与实际标题一致，再集中取得输入／系统粘贴的计数或结果、需要复核的VoiceOver逐项观察；优先解决本次记录未对应的缺口，不重跑已关闭问题的完整诊断。
- L先在裸NSStepper取得真实持续按压、逐次action和可靠mouseUp／释放后观察，再用同组参数比较Daybook的增减、释放和边界。只有定性重复反馈时继续保留精确时序限制，不用点击或旧合成长按替代。
- 实际屏幕需已可用且明确归属QA窗口的采集通道；现有连接超时无恢复证据、QA只读预检false时不重试或修改权限。真实NSPopover须另有安全隔离宿主，其他系统版本须有对应验收环境；需要新增系统集成／权限／安装时另行授权。
- 指定Cursor verifier实际可调用后提交本节已准备材料；如要求完整历史补丁复核，另需可核验的收口前基线。H/K只按上表保留限制或另行定界补验，不以接受风险代替修复或测试通过。

本轮未提交、推送、安装、发布或改变系统／个人配置，代理未读取或覆盖系统剪贴板、真实数据和凭据；完成本次收尾后停止，不新建后续阶段或调度器。

#### P 续轮：逐项人工操作与平台取证（2026-10-07）

用户明确授权本次约10–15分钟人工配合，继续保留partial且不接受整体交付。以下是续轮新增证据；上方首轮反馈、日志不一致、历史失败及限制保持原样，不将本轮结果倒写为首轮通过。

**源码身份与复用范围**：HEAD仍为`dba0982362f389c28b468e2d03420bfbe126d7d1`，叠加原暂存、未暂存及未跟踪修改。与P首轮`final-after.json`比较，原受测集合29文件改变、另新增19文件，集中在并发统一搜索命令、服务／测试、语言资源及工作流检查器；本轮未修改任何Swift、资源、配置或启动脚本。原Gallery／ControlsPlatformAcceptance、SearchMultilineFixture、CaptureField、Daybook输入／滚动控件及周／Dashboard／气泡宿主无变化。O的315方法／770次保持其逐方法历史证据，不因本轮挂载就声称并发命令改动已获完整回归。

两批完整正常PrivacyQA运行前后1211文件源码集合完全一致，综合SHA-256为`98845e9bae5f17abdcf8232e1124cb6bba67350670eab6af575eda47602fadf4`；生产578文件为`773aaeafdf0ef61731e8792c3a77b349b43d649392994608e8373246e2f72093`，测试612文件为`36d6ef78f5064c952949f4e076fa99a4b8bf75cbd50b29e63f7654b47c4368f2`，其余21个原配置文件包含在综合身份内。每批`*-before.json`、`*-after.json`、`*-command.json`、`*-execution.json`、日志及结果树继续保存在`build/Controls10P`。

**实际启动与清理**：复用`build/Controls10P/run.py`，分别运行`continuation-manual`（`AREACHAIN_CONTROLS_PREVIEW_SECONDS=600`）及`continuation-search`（180秒），均设置`AREACHAIN_PLATFORM_QA=1`，唯一选择器为`DaybookButtonInteractionTests/interactiveGallery()`。仍使用`build/PrivacyQA-Controls10P`、`com.areachain.privacy-qa`、local临时签名、生产sandbox entitlement、LSUIElement=NO、六项真实钥匙串变量清除和串行XCTest；原锁两次均立即取得，无等待／抢占其他任务。完整目标编译及同锁内`codesign --verify --deep --strict`均成功。两包各1方法／1次通过、0失败／跳过／Expected Failure；去重为同一支持方法运行两次，不增加315／770覆盖数，不折算人工次数。日志窗口期分别600.113秒与180.092秒，两次均记录`auxiliaryReleased=true`、`monitorReleased=true`，测试PID 934／10032已退出，最终原锁空闲。

| 人工项目 | 本轮操作与可核对来源 | 结论及限制 |
|---|---|---|
| 子窗口归属 | 首轮主窗35475；用户先答“已出现该子窗口”，当时仍无`open`且辅助树／截图只见Gallery。代理通过现有Open按钮打开Capture后，窗口35511与`open`记录一致。 | 本轮已能绑定确切子窗口；此前反馈差异保留，代理打开不能算用户成功打开。原坐标点击未改变辅助树，随后使用已识别的按钮动作，均单列为工具操作。 |
| 中文组合与提交 | 窗口35511收到中文组词的`marked=true`事件及一次组合期间Return；另收到7次非组合Return、12次非组合⌘Return，最终待办／手记计数7／14。用户反馈“我没明白，我在里面输入回车没反应”。 | 夹具回调只累加计数，不清草稿或新增可见列表；“无可见反应”不能直接归为产品缺陷。组合期间⌘Return没有对应记录，输入法名称／候选与焦点未获具体确认，计数无逐次快照，不能证明组合提交保护通过。 |
| 普通捕获对照 | 代理重新打开空Capture窗口35559；用户确认输入`abc`并按一次Return。辅助树确见`abc`保留，但本窗日志实际为16次非组合Return、4次非组合⌘Return，最终计数16／4。 | 用户“一次”的反馈与事件次数不一致；没有事件的`isARepeat`字段，不能判定持续按键、重复按键或根因。仅确认回调可达，不宣称恰好一次提交或重复提交缺陷；不连续盲试。 |
| 普通搜索撤销／重做 | 首批窗口35581在操作前达到600秒上限，用户确认未完成。第二批代理打开窗口35614；日志依次出现普通输入、一次⌘Z和一次⇧⌘Z，用户明确答“正常，没有出现 / 乙”。 | 该窄场景按人工观察通过，按键元数据与窗口身份对应；未复现原多行“甲↵乙”触发条件，不能扩大为全部换行回归。用户随后继续编辑，结束时三种固定合成查询相等布尔均false，不等于最终文本错误；最终AX／屏幕读取超时，未核验最后正文或光标区间。 |
| 窄周 | 第二批在代理选择Search前，日志已有Capture35593和Week35595打开；Week有观察记录。 | 无逐列滚动／顶部中部底部／触控板方式的逐项反馈或偏移证据，只记录实际打开，不算滚动验收通过。 |

**工具观察、原生合成与屏幕分层**：本轮未生成旧合成长按、未重跑770次、未注入测试文本或读取／改写系统剪贴板。代理通过cua执行场景菜单、Open、Record与关闭子窗口等准备动作；输入与撤销键盘事件来自用户配合。`continuation-manual-events.jsonl`保存136条记录（ready 1、event 126、open 3、observation 5、closed 1），`continuation-search-events.jsonl`保存64条（1／53／3／6／1）。元数据不保存按键字符或密码内容，不能将所有鼠标记录统称人工证据。

cua应用清单本轮可读；其浏览器枚举另报`unsupported Codex auth method: apikey`，未认证或切换机制。确认PID 934运行后，以确切QA路径连接成功并读取Gallery／Capture／Search原生辅助树。`qaApp.getScreenshot()`实际返回1520×1344的“Daybook Controls (QA)”窗口图，显示当前工具条和合成预览；截图已显示在本对话工具结果中，未另存本地文件。这是本轮实际窗口截图，不是cacheDisplay旧图，亦不覆盖全部语言／主题／尺寸。QA内部`CGPreflightScreenCaptureAccess=false`与外部cua成功是不同进程能力，不能合并为QA自身获得截图权限；没有请求或调整权限。原缓存图只保留历史分类，本轮未新增缓存图。

**结束时的隔离边界异常**：最后一次`qaApp.getAXState()`发生在180秒窗口尾部并返回`-10005 timeoutReached`。随后只读进程／打开文件元数据发现，测试PID 10032已退出，而20:05:21（Asia/Shanghai）启动的PID 13023来自同一`PrivacyQA-Controls10P`路径，命令行无XCTest启动参数、未见测试插件，并持有QA容器`areachain.store`及WAL／SHM。它属于非XCTest的QA运行，不能当作内存隔离宿主；时间相关性不足以证明由cua自动重启还是其他动作引起。代理仅在核对PID与完整路径后向该进程发送SIGTERM，随后确认退出，没有停止其他QA／构建任务，未打开数据库内容或删除容器。**本轮不能宣称全程只有XCTest启动，也不能证明该额外进程没有执行启动期系统服务或写入QA持久库。** 这不是普通生产应用的有效验收，不计通过；后续读屏必须在测试进程仍存活且有足够剩余窗口期时执行，退出后不再调用可能重新解析／启动应用的桌面入口。来源和自动启动副作用仍待有界只读诊断，不能由静态验签消除此缺口。

**H／K／L与指定复核**：H外层事务＋嵌套AX显示恢复／普通截止失败注入缺口不变；K安全字段同值替换同步限制不变，本轮没有改事务、密码政策或安全生命周期。L没有本次真实down／可靠up／逐次action时序，未运行两种Stepper长按，保持基线未建立；没有重跑旧无效合成对照。当前实际工具元数据无指定Cursor verifier入口，既有复核材料加本节源码身份、结果包、用户原话、屏幕与隔离异常已准备，**复核未执行**，未由其他代理替代。

**未运行与下一项可执行动作**：系统粘贴／剪贴板三模式、组合期间⌘Return与恰好一次正常提交、Tab／Shift-Tab及星期激活、生产帮助外部关闭／防穿透／Escape优先级、跨行气泡进入保留离开、长列表羽化／各周列／甘特／Dashboard轴与resize、可靠Stepper持续按压、逐项VoiceOver、密码失败回显／取消重开及真实NSPopover均未取得本轮完整证据。现有Gallery安全字段只有遮蔽／外部清空，没有密码失败和取消重开场景；独立帮助卡未接生产全局Escape路由；Week的选择／检查回调为空，不能证明屏外日期键盘导航；气泡子窗默认复制未注入，因此未点击复制／菜单；本入口没有甘特与真实NSPopover人工场景。优先下一项是排查上述非XCTest重启来源并确保读屏不会越过测试生命周期，再在当前Capture合成宿主中用“一个按键→一次计数快照”取得可判断的提交证据；无需重跑全部自动回归或改变生产边界。

本轮仅就地更新此总交接，保留全部前期／并发／暂存修改。用户尚未接受整体交付；**状态继续partial**，所选历史自动回归、窄人工通过、测试宿主问题与平台限制分别报告，不将时间到达或材料准备写成验收完成。未提交、推送、安装或发布；代理未读取真实内容、凭据或系统剪贴板，额外QA启动期副作用按上段保留未知，不写成全程零副作用。`python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile static --format json`及工作区／暂存区差异检查通过；static包含229项脚本回归，所有检查均为passed。最后文案收尾仅重验受影响的工作流／差异检查，不重复未改变的Swift或脚本测试。静态通过不关闭上述人工和隔离异常。

#### P 诊断：QA 非 XCTest 进程来源与隔离边界（2026-10-07）

**状态仍为 partial，用户未接受整体交付。** 本轮只读诊断及续验方案准备，仅补此原 O/P 记录；没有启动 QA、调用桌面应用入口、人工输入、构建或重跑770次，也没有修改生产、安全流程、启动配置、签名、权限或认证。没有打开 store、执行数据库查询、读取真实偏好／正文／凭据／系统剪贴板，没有清理容器。原文“最后一次 AX 调用发生在180秒窗口尾部”由下述原始时间戳校正为：**调用时测试进程已退出约39秒**；保留旧段作为当时判断，不再沿用其时间结论。

**范围与身份**：沿现有 `build/Controls10P/run.py`、Gallery、ControlsPlatformAcceptance、原事件／结果树及应用入口核对。1211文件受测集合与 `continuation-search-after.json` 逐文件相同，综合 SHA-256 仍为 `98845e9bae5f17abdcf8232e1124cb6bba67350670eab6af575eda47602fadf4`，HEAD仍为 `dba0982362f389c28b468e2d03420bfbe126d7d1`；暂存二进制差异摘要为 `ca63f231f414f0b13219bc26b6ceab165c53f13056e1821e180ba3df7d2df973`。这证明所读源码与P续轮快照对应，不等同给已退出进程补采二进制身份。保留全部既有暂存、未暂存及未跟踪修改。只读源码调查由辅助代理提供出处，主代理抽查关键启动／存储／剪贴板路径；这不是指定 Cursor verifier 复核。

**原始来源与启动时间线**：除原 `build/Controls10P` 外，恢复了原会话 `01a1162f-796f-7682-8cb2-447102a2a2c6` 的工具原文及时间戳。原始来源为本机 `.codex/sessions/2026/10/07/rollout-2026-10-07T19-46-12-01a1162f-796f-7682-8cb2-447102a2a2c6.jsonl`，以下 S 行号只指该文件；没有复制整份会话或建立平行报告。系统日志仅查相关 PID／QA标识及窄时间窗，保留非敏感摘录于此。下表日期均为2026-10-07、时区 Asia/Shanghai；JSONL的uptime仍单列，不伪造其墙钟精度。

| 时间／顺序 | 已确认事实与出处 |
|---|---|
| 20:01:33.343 | S303，原 runner 以180秒窗口和单一 `interactiveGallery()` 选择器启动 `continuation-search`；命令见同名 `-command.json`。 |
| 20:01:35.163；20:01:39.184／.199 | `continuation-search-summary.json` 的结果包开始时刻；后者为 launchd 的10032 xpcproxy／AreaChain成功启动时刻，二者不是同一事件。S310后原 ps 显示完整路径及 `-NSTreatUnknownArgumentsAsOpen NO -ApplePersistenceIgnoreState YES`。 |
| uptime 279891.22314075 → 280071.314983375 | `continuation-search-events.jsonl:1,64`：PID10032、Gallery35592，实际窗口期180.091843秒，最后 `auxiliaryReleased=true`、`monitorReleased=true`。Search35614由第28行 `open` 绑定；这是宿主正常清理证据。 |
| 20:04:42.179；20:04:42.457 | runningboardd记录10032 `termination reported by launchd (0, 0, 0)`；后者为结果包finishTime，`continuation-search.log:4–6`也记录xcodebuild9926完成。不能说测试仍在20:05:21运行。 |
| 20:05:21.280 → 20:05:26.599 | S364／367，`call_KIFytvpSCXOWGPvJPqgRwxVJ`：仅 `await qaApp.getAXState()`，返回 `Computer Use server error -10005: timeoutReached`。没有新的显式getApp调用；App对象来自20:02:18.621的S315。调用开始距10032退出39.101秒。 |
| 20:05:21.366 → .391 → .394 → .406 | 系统日志：`SkyComputerUseService[49672] (LaunchServices) LaunchServices.launchViaCSUA`及 `LAUNCH: Asking CSUI to launch 0 items`；随后CoreServicesUIAgent25161发起 `LS launch com.areachain.privacy-qa`，launchd创建13023并记录 `Successfully spawned AreaChain[13023] because launch job demand`。ndjson元数据进一步确认Sky的两条请求与CSUI在.412738的 `com.areachain.privacy-qa starting stopped process` **共享activityIdentifier=47296500**。 |
| 20:05:21.560 | launchd日志明确 `requestor = SkyComputerUseS[49672]` 查询13023的 `com.apple.axserver`；不是只在时间上出现另一个无关进程。 |
| 20:05:57；20:06:35 | S375及382后的ps/lsof原输出：13023完整路径为 `/Users/as/Ai-Project/project/AreaChain/build/PrivacyQA-Controls10P/Build/Products/Debug/AreaChain.app/Contents/MacOS/AreaChain`；命令行只有此路径，PPID=1、启动20:05:21；过滤的打开文件列表未见AreaChainTests／XCTest，已见QA store/WAL/SHM。未记录其完整环境，不能断言六项授权变量继承状态。 |
| 20:07:09.429 → 20:07:33.486 | S391／395记录再次精确匹配命令行后发送SIGTERM；S399／402仅输出ps表头，确认13023已退出。当时未终止其他任务；本诊断另以完整可执行路径只读枚举，未发现该路径现存进程，不以历史PID复用判断身份。 |

**启动来源判断（A／B／C／D）**：A已定位到桌面工具服务：原工具文档S100明确写明 macOS `cua.getApp(...)` “launches the app in the background if needed”，Linux／Windows的“不启动”保证不能迁用。SkyComputerUseService请求与CSUI启动QA的日志共享activityIdentifier=47296500，再由OS启动链映射到13023，并有Sky查询新PID的AX记录，**足以确定此次额外进程的启动请求来自桌面工具服务，经CoreServicesUIAgent／LaunchServices与launchd执行，不只是时间相关性或PPID=1推测**。原会话该时段唯一桌面调用是已退出宿主的 `qaApp.getAXState()`，与上述链一致；JS调用ID没有出现在OS日志中，`getAXState`内部具体如何重新解析／调用启动逻辑仍未取得实现证据，不能推导每次AX调用必然重启或泛化所有工具版本。

B：`run.py:38–53` 只同步运行一次xcodebuild，之后验签／摘要／xcresulttool，finally释放原锁；没有open、重启、恢复或再次测试分支。`DaybookButtonInteractionTests.swift:78–101` 到期defer关闭；`ControlsPlatformAcceptance.swift:104–132` 清理辅助窗口／监听，不产生新进程。脚本没有显式重启路径，实际启动责任方亦已由OS日志定位，不将其归因于测试清理。C：原会话在故障点只有AX读取，没有用户或并发任务直接启动同路径应用的正面证据；没有扩大审计其他用户活动，也不把所有可能并发请求都宣称排除。D：历史资料并未全部丢失，本轮已恢复父进程、工具时间和同一activity的OS启动链；仍缺JS到服务内部的实现关联、13023环境、逐项服务调用／文件写入审计，保留限定而非重复启动补证。

窄日志可复查入口是 `/usr/bin/log show --style compact --info --debug`：启动责任方仅20:05:21–20:05:22、进程SkyComputerUseService或CoreServicesUIAgent且消息含launch；OS启动链仅20:05:20–20:05:23、消息含QA标识或13023且含launch／spawn／request；测试启停仅20:01:30–20:04:50、launchd／runningboardd／testmanagerd且含10032及启动／退出词。以上查询均显式使用 `+0800`。没有导出全系统日志或环境变量；日志将来过期时以此处摘录和本轮工具结果为已取得证据，不把无结果解释为未发生。

**测试识别与实际存储边界**：`AreaChainApp.swift:28,100`、`Persistence.swift:17` 及各shared服务主要只检测 `XCTestConfigurationFilePath` 是否存在，并不验证插件或QA bundle ID。存在时App创建内存容器且禁用autosave，AppDelegate跳过系统启动；夹具仍须自己注入内存数据、临时偏好、nil pasteboard和fake服务。`AREACHAIN_PLATFORM_QA`只选择Gallery工具条，窗口秒数只限制该测试方法；独立bundle ID负责命名空间，local签名负责签名能力，均不是内存开关。无该XCTest变量则选磁盘／真实服务，即使包仍叫privacy-qa。没有测试参数／未见插件只是辅助证据，本次打开磁盘库和实际通知查询进一步证明额外进程不能当作内存宿主。六项授权清除只约束runner传给xcodebuild的环境，不是所有后续系统启动的凭据访问拦截器。

`Persistence.makeSession` 使用 `ModelConfiguration("areachain", schema:)` 的默认URL，没有显式group或临时根；本次lsof实际定位至 `/Users/as/Library/Containers/com.areachain.privacy-qa/Data/Library/Application Support/areachain.store` 及 `-wal`／`-shm`。该路径与日用bundle容器不同，但同一privacy-qa标识的不同构建目录会共用它，不能把独立DerivedData当作独立数据容器。附件、剪贴板历史、隐私配置和日历ledger同样使用Application Support相对默认根（`AttachmentStore:18`、`ClipboardHistoryStore:9`、`VaultConfigurationStore:13`、`CalendarSyncStorage:7`），没有在这些入口发现显式日用容器／App Group共享根；系统剪贴板、日历及通知服务本身仍属外部依赖。

本轮对已有包只读 `codesign -d --entitlements :-`：sandbox=true，含calendar、user-selected.read-write、get-task-allow，以及测试注入的 `temporary-exception.files.absolute-path.read-only=["/"]` 与testmanager等mach例外；无application-groups／keychain-access-groups。这是**当前包**元数据，非13023启动时单独封存的签名；历史secinitd在20:05:21.433／.527确证13023请求并成功初始化AppSandbox。因此可以确认观察到的store落在QA容器，不能宣称“沙盒阻断了一切容器外读取”；临时只读例外也不等于已访问真实内容或绕过TCC。没有改动这些权限。

**副作用分类**（“未取得证据”不代表未发生；没有用文件修改时间代替事前基线）：

| 项目 | 源码可达条件 | 本次执行证据 | 写入／外部副作用证据 | 未知及边界 |
|---|---|---|---|---|
| 偏好／种子 | AppPreferences:142默认standard、legacy读取与live外观；AppDelegate:51调用FirstLaunchSeeder，已有重复事项或首次成功种子会写seeded标记，并尝试save。 | 未留逐键轨迹；后续通知启动支持AppDelegate已进入正常分支，但不证明每个异步步骤完成。 | 未证明某个偏好键或业务行写入。 | AppPreferences初始化读默认值不等于必然把所有默认值落盘；未读取实际值，原偏好存在与否未知。 |
| 数据库／维护 | Persistence:20–25先尝试隐私维护、SQLite补空notes，再开磁盘容器；:54–60仅文件存在且打开成功才执行两条UPDATE。PrivacyStoreMaintenance:37以后仅有cleanup标记时做WAL checkpoint／VACUUM／删除标记。 | 历史lsof确证store/WAL/SHM被打开；不是只凭源码猜测磁盘访问。 | **已证明文件打开／持有，未证明业务数据修改、迁移、UPDATE影响行数或清理发生。** | 无事前库／标记基线，不读内容或重新查询；ModelContainer失败回退内存也不能撤销此前维护。WAL存在不能证明由13023新建或写入。 |
| 通知 | NotificationScheduler:158启动，:301查询待发及权限；授权后才加载提醒并按差异增删，未授权且已有本应用通知也可能取消。 | 13023系统日志20:05:21.790查询pending，.791返回0项，随后查询并收到notification settings。 | **已证明系统通知服务查询**；未见通知新增／删除的正面证据。 | 权限值、后续排程完成与持久化结果未知；没有请求授权成功／展示通知的证明。 |
| 日历 | CalendarSync:23–55启动观察；syncCalendarEvents=true且存储健康才经Engine:68请求权限、读写EventKit／ledger。 | 没有本次同步执行轨迹。 | 未证明请求授权、读取事件、创建AreaChain日历或写事件。 | 新域默认false不能代替实际偏好；独立ID不产生隔离的系统日历数据库。 |
| 剪贴板／历史 | ClipboardHistorySession:17–24非测试选择general／standard／磁盘；:65–66加载历史，:78启动轮询。Monitor:17,22读取changeCount，:47–51变化才调用内容读取；Session:245–254先读取draft、后判断recording。 | 源码及正常启动链可达；无本次逐次changeCount／draft／保存回执。 | 未证明系统剪贴板正文已读取或历史写入；也不能证明没有。 | recording=false仍不能阻止变化后的内容读取；初次start不等于立即采集既有正文。未打开历史文件或剪贴板追认。 |
| 私密锁／钥匙串／认证 | PrivacyVault:16–19非测试选择FileVaultConfigurationStore，:59／67读取配置与pending IDs；:131装配生命周期。SystemVaultKeyStore服务名由bundle ID派生；真正SecItem读写／LAContext在显式动作中。 | 未取得配置内容读取或SecItem调用证据；构造真实对象不等于认证。 | 未证明密钥读取／新增／删除、解密、系统认证或真实数据转换。 | 授权变量仅守真实测试入口；QA私密服务名不同不代表取消所有真实系统调用。入口未发现自动unlock，不继续敏感调查。 |
| 菜单／窗口／后台 | AppDelegate:31–59设置accessory、状态栏、快捷键、panel、通知、undo、日历并隐藏杂窗；最后窗口关闭仍不退出(:65)。 | 20:05:21.667 ControlCenter记录Item-0；.704记录Item-1且clientRequestsVisibility=true；.665系统角色转为uielement。 | **已证明状态栏注册／可见性请求和系统进程角色变化**；这不是Gallery人工窗口通过。 | 全局热键实际注册结果、窗口恢复内容、计时器每次触发未留回执；不把无窗口当作进程未运行。 |

没有取得明确真实正文／凭据访问迹象；此结论只限已查元数据，不能写成额外进程零敏感访问。通知查询与状态栏注册已是确定的系统交互，所以本次全程隔离不成立；没有证据可授权或支持自行清理、回滚QA库。

**已有证据归属**：O及补验315方法／770次仍按原逐方法源码对应关系有效，不因后来的额外进程整体作废；不扩展到并发新功能的回归。P两次Gallery支持方法通过及正常清理仍有效，但只覆盖各自XCTest窗口期。末次AX超时没有返回最终正文／光标／截图，不能补计观察通过；首批取得的实际Gallery截图仍是当时窗口证据。

普通搜索abc保留窗口35614下的窄人工通过：`continuation-search-events.jsonl:38–42` 为预定输入键位及一次⌘Z／⇧⌘Z，原会话S369用户明确答“正常，没有出现 / 乙”；键位不能独立证明字符或选择区间，结果主要来自人工确认。它没有覆盖原“甲↵乙”的多行撤销故障，不扩写为完整人工验收。

捕获记录仍不足以判“恰好一次”或产品重复提交：`continuation-manual-events.jsonl:20,97–99,132–133` 分别绑定35511（7／14）与重开的35559（16／4）；前者Return元数据为组合1、非组合7、非组合⌘Return12，后者为16及4。两组Return的eventTimestamp各自不同，没有同一时间戳整行重复的正面证据；可按窗口分开，不能把两窗累计为一窗。`ControlsPlatformAcceptance.observe:196–214` 仅观察down/up/keyDown，不含keyUp、isARepeat、监听实例／事件序号；`SearchMultilineTestSupport:145` 回调仅累加计数，observation又没有逐次事件／动作关联。因而不能区分按键重按、长按repeat、重复监听、按钮动作与多次调用；35511的14对12差额也不能擅自归因。35559数字吻合只是总量相符，不证明一键一回调。它们发生于PID934窗口期，早于13023启动，不能自动把差异归咎于该额外进程。原用户“一次”与元数据差异两者均保留，捕获不判通过。

**最小下一步（仅方案，未实施）**：先做一份仅限 `build/Controls10P/run.py` 与原 `ControlsPlatformAcceptance`／Gallery测试支持的生命周期及事件取证改动，不改App入口、Persistence或安全策略。沿既有JSONL补run ID、PID＋启动身份、确切窗口号／标题、ready／closing／closed、单调截止时间，以及无正文的事件序号、isARepeat、keyUp、监听实例和回调前后计数／动作来源。原日志可读取这一能力已经由本轮静态读取及历史ready/closed事实核实；由测试进程自行记录窗口元数据，外部只读该批已知文件和进程表，**不会调用getApp或AX并自动启动应用**，但它不能提供屏幕合成器图片、AX朗读或光标完整证据，这些项目继续未验。

续验启动条件及停止规则：

- 后续获得测试支持修改／有限续验授权后，先审阅差异及合成生命周期测试：退出发生在读取前、预检后、读取中，旧PID／窗口／run ID及迟到结果都必须拒绝；模拟启动函数调用数始终为0，不能用真实可疑QA重演。需要构建时沿原锁单次最多900秒，申请前、取得锁后及结束后核对完整受影响源码集合；完整正常PrivacyQA、六项授权清除和合成依赖保持。
- 外部观察绑定本批XCTest的PID＋启动时间／可执行路径和ready run ID，再核对window ID及场景。遇到closed、身份变化、进程退出、读取超时或进入预定截止前停止余量（建议至少30秒，并覆盖已知读超时上限）即停止接收新观察；不延长到通过、不重新解析旧App对象、不再次getApp。单纯PID存活预检查存在检查后退出竞争，**不是充分隔离保证**。
- 目前cua文档未暴露macOS仅附着现存PID且绝不启动的保证，因此即使剩余窗口充足也不把该工具作为安全续验前提。若以后要恢复桌面读取，必须先有可审阅的仅附着契约／实现、绑定PID与启动身份、目标消失即失败且无LaunchServices回退，并验证退出竞争；能力缺失时沿日志观测，桌面读取保持停止。历史原因完全确定与否不能替代这个技术前提。
- 测试结束后以完整路径＋本批身份只读查残留；发现非XCTest实例立即中止人工与桌面调用，保留启动时间、命令行、父／责任方及必要打开文件元数据，不读取内容、不自动终止其他QA、不清理容器。终止额外进程须有该轮明确授权并再次核对身份，不能仅按旧PID杀进程。

H（嵌套AX／截止失败注入）、K（安全输入同值替换）、L（可靠持续按压基线）、其他人工未验及指定Cursor verifier缺口继续独立登记。复核材料可加入本节，但**材料已准备不等于复核已执行**。本轮 `python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile static --format json` 通过，static包含229项隔离脚本回归，各检查均passed；最后文案补齐后重跑工作流及工作区／暂存区差异检查，并复核源码与暂存摘要。1211文件仍无变化，但收尾检测到外部暂存操作，暂存摘要变为 `808888b46f309094be7219414b91192a786176d6418346f8c8066fc519c9521e`，已包含本诊断主体；本代理未暂存／撤暂存，保留此并发状态，不宣称索引全程未变。检查输出保留本轮工具记录，没有覆盖历史P日志。不以静态通过关闭隔离异常或接受整体交付。

#### P 完善：测试生命周期与逐事件证据（2026-10-07）

**整体继续 partial，用户未接受整体交付。** 本轮连续实施测试设施、定向自动验证与人工续验准备，仅修改测试支持、相关测试、原本地runner和原文档；保留前期/并发/暂存内容。生产源码、CaptureField、业务提交、保存、认证/安全生命周期、个人签名及权限均未改。上节已确定的SkyComputerUseService启动来源、QA store/WAL/SHM打开、通知查询、状态栏项注册和进程角色变化保持；历史业务写入及其他敏感副作用仍未知，没有读内容追认或重启异常路径。

**生命周期与原夹具**：ControlsPlatformAcceptance以idle/running/windingDown/closing/ended管理原Gallery。runner每批UUID、独立会话UUID、PID与内核启动秒/微秒、场景代次、窗口UUID/系统号及递增序号共同关联证据；窗口号不作路由键，绑定前生成的排队事件、旧对象/代次和迟到回调不归入新场景。ready/open/observation/scene-closed/winding-down/closing/closed分别记事实；墙钟关联日志、单调时钟管期限。重复start不重装监听/覆盖文件，close可重入；主/子窗关闭、切换、截止、取消及可捕获错误沿同一清理路径。Gallery由会话持有到终止，原defer继续兜底，结束后不能重开场景。30秒收尾期集中在windDownSeconds，供停止输入并核对计数，包含在原600秒总上限内；工具条/输入子窗显示收尾，其他子窗标题亦显示。无常驻、自动重启或轮询启动。

仅显式P的SearchMultilineFixture使用ControlsEvidenceWindow；SystemPageHost/SettingsButtonTestSupport增加默认nil的suppliedWindow，默认消费者不变。原SearchMultilineDraft的真实合成累加处发出Submission前后计数、回调类型及发生时刻；不提前累加、不吞键、不去重用户输入、不清草稿或增加真实保存。QA双语反馈显示场景/身份、待办/手记计数及最近回调，并明确“这是合成计数宿主；提交后保留草稿，不创建生产列表记录。”专用双语文案留在测试文件，不改生产文案资源。Stepper原probe/trace、NSStepper target/action和参数保持；记录/清理不改变数值或trace，旧Reset闭包核对所属probe，不能落入新场景记录。

**逐事件能力与限制**：只记Return/Enter、Tab、Escape的keyDown/keyUp及鼠标down/up，含事件时间、观察时间、修饰键、isARepeat、pressSequence/previousDownSequence和自有编辑器/marked状态。普通字符键位、正文、密码和剪贴板内容不进入新日志；marked不可读为unknown。同一NSEvent经监听与窗口时共用观察序号，真实重复keyDown保留。只有明确位于自有窗口同步派发范围的回调才带eventSequence；CFRunLoop进入tracking/modal等嵌套循环时撤销外层范围的关联资格，防止异步回调借尚未返回的栈误认旧按键。观察者与会话一起清理。dispatch-end只报告确切关联的回调数，0不证明所有未来异步操作均无回调；异步/无法确认的回调为unassociated。不以最近事件、NSApp.currentEvent或一次主队列延迟推断完成，也不证明所有异步因果。每次原回调独立记录，可区分已观察的无/多回调和多窗口；合成repeat仅检验记录器，不关闭L的真实持续按压缺口。

证据文件按批次/会话唯一名称O_EXCL创建。创建、序列化、写入或关闭失败均显示不完整状态并报告XCTest issue；仅打印固定错误阶段，不打印原始错误内容。文件关闭后才向XCTest标准输出发出CONTROLS_P_END回执，JSONL的closed不冒充句柄关闭成功。runner从本批xcresult导出的StandardOutputAndStandardError核对回执和原JSONL；不读取诊断导出附带的系统日志归档。缺失ready/closed、序号缺口、身份混合、未关场景、关联/次数不符或缺少成功关闭回执均判不完整；异常退出不能补造清理成功。

**runner与隔离**：仍为一次完整正常PrivacyQA xcodebuild test，独立build/PrivacyQA-Controls10P、原bundle/临时签名/生产sandbox entitlement/LSUIElement=NO、六项真实钥匙串变量清除及串行测试保持。原build/.build.lock单次最多900秒，取得后核对源码，变化即停止并先核对影响；正常/错误/取消均释放本任务持有的锁，未持有不改锁文本。结束复核源码、所选方法/参数结果树、会话终态和文件回执。proc_pidpath/proc_bsdinfo只读核对同一可执行路径，PID+内核启动身份另与本批证据绑定；发现已有/额外/归属不明进程立即停止验收，保留非敏感身份，不附着、点击、读数据、重启、清容器或终止其他任务。残留检查只说明检查时所见，不能证明此前零副作用。

**过程证据**：所有批次保留在build/Controls10P/lifecycle-*。compile批因MainActor默认参数编译失败；native批暴露事件名、未知编辑器前提及SwiftUI文本读取断言问题，均做定点修正。evidence/focused/focus-control保留原焦点未就绪失败，未删断言；window-diagnostic的原捕获与逐事件捕获对照均通过。随后测试Gallery按原宿主补显式激活并由会话持有，final批19方法/29次、18会话完整结束通过，等待原锁52.74秒后源码一致。后续closure批因SDK的CFRunLoopMode强类型参数编译失败，修正后进入verified批。没有覆盖这些过程失败或把它们标为Expected Failure。

| 最后证据包 | 实际结果及有效范围 |
|---|---|
| lifecycle-regression | 59方法/173次全部通过，20会话均核对JSONL/结束回执，验签通过。原runner按叶节点少计了带Runtime Warning子节点的一个通过方法，execution.json旧值172保留；当前按Test Case/Arguments重算为173并加脚本反例。运行中并发修改两份统一搜索标题测试，runner正确记录complete=false/source changed；不直接当整份最终源码通过。 |
| lifecycle-verified | 当前会话/记录器实现下21方法/32次：20方法/31次通过，新增嵌套循环反例1次失败。其associationScopeIntact=false已证明资格撤销；Timer未在该内层循环触发，计数0而预期1，不能当未关联回调已经通过。已将反例改为确定的嵌套entry回调，保留计数与未关联断言。 |
| lifecycle-complete | 修正版准备启动时桌面已锁定，runner在xcodebuild前停止，无QA启动、无测试执行。 |
| lifecycle-compile-final / lifecycle-compile-current | 原runner新增窄的--build-only选择build-for-testing，完整测试目标编译与严格验签通过；前者等待原锁185.00秒，后者立即取得。两批明确mode=build-for-testing、runtimeVerified=false，不补计运行次数。 |

**源码与有效结果**：HEAD仍为dba0982362f389c28b468e2d03420bfbe126d7d1；最近完整编译集合1216文件SHA-256为`1df858c55342cb2d08c8a7bd4146328c784edf45802bd60a8bb84acd4e844060`，两个编译批前后相同。生产578文件摘要仍为`773aaeafdf0ef61731e8792c3a77b349b43d649392994608e8373246e2f72093`，逐文件对照本轮origin无变化；该编译版测试616文件摘要为`c4cdeaaa201157b7ede3730e197968a4606faf73c11c3443be33bc17ad373a29`。暂存摘要与本轮origin相同；本代理未暂存/撤暂存。收尾仍有并发命令测试更新，复核时工作区摘要为`a577615dfcaf8a20daceba4f85f746c36d361a9c670d996a426e6f3cb509b65e`；最近编译后改变的是UnifiedSearchTaskChainTests、UnifiedSearchTaskFieldTests及UnifiedSearchTM1ContractTests。本轮9个测试支持/测试文件与已编译版一致，但**未将1df858…的编译通过扩写为a577…整个工作区通过**。已读取这些差异以及前述两份标题测试差异，合计五份并发命令测试不被所选P路径调用；保留它们，不归为本轮成果。

逐方法对应见build/Controls10P/lifecycle-current-results.json：verified的20方法/31次，加regression中代码路径未受后续记录器/并发测试变更影响的39方法/142次，共**59方法/173次有效通过；新增嵌套entry反例修正版1方法/1次待运行**。这不是“全部自动验证通过”，也不替代原O的315/770历史来源。剩余是桌面解锁后先补该反例及相关短时原生回归，再决定人工窗口。14项runner隔离测试、Python语法、9个本轮Swift文件严格SwiftLint、工作流和静态门禁通过；静态包含229项原脚本回归。最终文档收尾重跑受影响检查。结束核对同时检查本批PID的内核启动身份和同路径额外进程：PID已不存在/已复用才算原实例退出，身份不可读或仍匹配即拒绝通过，不仅凭路径缺失判断退出。只读检查确认8个已记录测试进程均退出、同路径额外进程为空；不据此断言历史无副作用。Stepper的keyboardSingleRepeatReleaseAndDisabled虽断言通过，结果树保留SystemPageHost.swift:67“Modifying state during view update”运行警告，未当作警告已消除；未证明它是本轮新增回归。SDK既有AX弃用及ad-hoc Hardened Runtime提示亦保留。

**人工首组准备，尚未复验**：须先补齐上段自动运行缺口，再重新确认用户当时仍方便，才以原interactiveGallery启动最多600秒窗口；以前“方便”不跨构建有效。本轮未启动长时人工窗口。首组由用户亲自选Capture并点击Open，核对子窗批次、scene代次和窗口ID；输入合成abc，只按一下Return，核对待办计数/最近回调，再用本批JSONL核对keyDown/repeat/keyUp和callback前后计数。随后按该场景原支持的⌘Return，核对手记计数。组合文本期间的Return/⌘Return与上屏后操作分别记录，保留输入法名称及用户观察；草稿保留是约定，不期望新增生产列表项。次数不一致立即停止该项，保存序号与未关联回调，不补成恰好一次。收尾期停止新场景，到期由XCTest自行清理，退出后只读本批日志/进程身份。捕获人工次数不一致问题本轮未真正复验，不能关闭。

**平台与指定复核**：本轮未调用任何桌面应用入口，包括旧app对象的AX、截图、打开/激活/关闭。恢复必须先有可审阅的仅附着且绝不启动契约/实现，绑定PID和启动身份，目标消失即失败、无LaunchServices回退，并验证退出竞争；PID预检查不能消除检查后退出窗口。测试状态机与run ID只用于关联证据，不提供安全认证，也不能阻止外部工具启动普通QA进程。原生cacheDisplay缓存图仅检验文字布局，不作为窗口合成器屏幕证据。H、K、L、未知历史副作用、真人IME/VoiceOver、真实NSPopover及其他系统版本独立保留。复杂测试状态/共享夹具接线触发指定Cursor verifier；当前工具元数据无该入口，未认证、安装或以其他代理替代。材料是本请求边界、项目规则/路由/组件目录、lifecycle-origin.json、实际差异、最终前后源码清单/结果树/会话日志及本节失败/未覆盖项；复核应返回可核验file:line、问题与未覆盖项，材料准备不等于执行。

本轮不提交、推送、安装或发布；不操作真实库/正文/附件、系统剪贴板、真实偏好、签名配置或权限。自动证据与人工/平台/指定复核的未完成状态分别交接。

#### P 最终反例与 Capture 续验（2026-10-07）

**整体仍为 partial，未获用户整体交付接受。** 继承上轮59方法／173次有效证据，本轮只在 `ControlsPlatformEventTests.nestedRunLoopCallbackRemainsUnassociated()` 补显式 `nestedEntries == 1` 和回调记录恰好一条的断言，保留原合成提交计数及未关联断言；不改生产、共享夹具或runner。原Timer反例失败、锁屏未运行和只编译批次全部保留。

**最终运行反例已通过**：`build/Controls10P/capture-auto-entry.xcresult` 真实运行10方法／10次，零失败、跳过或Expected Failure；包括六个事件方法、重复开始/关闭、切换/旧回调拒绝、截止/取消，以及原Gallery的2秒短会话。嵌套entry确实进入一次、原合成todo回调确实执行一次，事件3对应的回调4为 `unassociated/eventSequence=null/countBefore=0/countAfter=1`，dispatch-end 5为 `associationScopeIntact=false/synchronousCallbacks=0`；没有用资格撤销替代回调事实。同步窗口派发可关联，异步/嵌套回调不借外层事件归因；旧窗口/场景及会话结束后的迟到回调拒绝记录。11个会话的JSONL、CONTROLS_P_END文件关闭回执均完整，PID `3741:1791379810:166448` 已退出，同路径额外进程为空，严格验签通过。

**源码与计数**：上述自动批及第一批人工窗口均为完整正常PrivacyQA `test`，原锁立即取得，前后1216文件综合摘要一致：`41de6ef2199851c2e5bbd73b5f7b61d0d2f634860653c39e45a6981f3ae8a94e`。生产578文件仍为 `773aaeafdf0ef61731e8792c3a77b349b43d649392994608e8373246e2f72093`；测试616文件为 `5ccdc781cacbb61c97caa986e75146dca1603e2f9ef92d2c0cb593b74bc45cfb`。起点与最终编译旧版之间三份并发命令测试（TM1Contract、TaskChain、TaskField）已读差异，不被所选P路径调用，不归本轮成果。相较继承工作区，本轮只改变上述单个测试方法；原59方法路径不变，新增反例后去重为**60方法／174次有效自动通过**，重跑的9方法／9次及人工Gallery重复不重复累加。暂存摘要仍为 `808888b46f309094be7219414b91192a786176d6418346f8c8066fc519c9521e`；未操作暂存。原O的315／770继续作为其独立历史来源，不扩为全工作区或全应用通过。

**第一批人工**：用户当时明确“现在方便，开始”后运行 `AREACHAIN_PLATFORM_QA=1 AREACHAIN_CONTROLS_PREVIEW_SECONDS=600 python3 -B build/Controls10P/run.py capture-manual-1 'DaybookButtonInteractionTests/interactiveGallery()'`。批次 `DF963B81-B756-48BE-9C74-D2D84DFEEEDA`、会话 `8FEA074C-76FE-4D93-991A-67BC323F7F52`、进程身份 `5606:1791379919:397710`。用户亲自打开Capture；初窗g1／37202／`CD84A7E3-D691-4646-8A21-277A0DB6A516`在尚无回调时被用户重开，记录32确认0／0、33关闭；新窗g2／37217／`728007A4-6DA9-42CF-A981-B94A65355CE3`由记录34打开。用户明确确认自己使用scene 2，后续按该身份核对，不混合两窗计数。逐条原始证据见同目录 `capture-manual-1-8FEA074C-76FE-4D93-991A-67BC323F7F52-events.jsonl`。

| 人工步骤 | 本批事实与判断 |
|---|---|
| A 普通Return | 用户输入合成abc，报告待办1／手记0，并确认最近回调 `todo 0 → 1 · 同步派发 / synchronous`。keyDown 45的repeat=false、marked=false；callback 46确切关联45，todo 0→1；dispatch-end 47恰为1；keyUp 48的pressSequence=45，释放派发49为0。按下/释放时间差约86ms，一次观察事件对应一次真实合成回调。 |
| B ⌘Return | 保持g2。用户报告1／1并确认 `diary 0 → 1 · 同步派发 / synchronous`。keyDown 50的repeat=false、marked=false、Command修饰有效；callback 51确切关联50，diary 0→1；dispatch-end 52为1；keyUp 53的pressSequence=50，约79ms后释放。没有第二次回调。 |
| C1 中文组合尝试 | 用户指定微信输入法，但报告未看到候选/组合态；不记录其输入正文。Return事件54实际marked=false、repeat=false，callback 55为todo 1→2，dispatch-end 56为1，keyUp 57与54成对（约114ms），释放派发58为0；用户报告2／1。此操作是非组合提交，结果一致，**不能算组合保护通过**。组合期间Return／⌘Return及上屏后两条路径仍待真正覆盖。 |
| D 重开／搜索 | 本批g1→g2显示身份更新及旧窗0／0关闭，未在有提交后重开，不能替代完整D。普通搜索abc撤销／重做未进入，原多行触发条件人工缺口保留。 |

**第一批收尾及用户决定**：记录59在约570秒进入原30秒收尾期；代理要求停止新操作，之后没有新输入事件。60 closing、61最终2／1、62 scene-closed、63 closed，监听/Gallery/子窗释放为true；文件关闭后CONTROLS_P_END为 `fileClosed=true complete=true`。runner完整性通过、Gallery 1方法／1次通过、严格验签通过，原PID退出且同路径无残留；构建锁已释放。等待用户开始或续验答复期间不占锁。清理后重新询问是否仍方便继续中文核对，用户明确答复“先结束，中文步骤保留待验”；当轮没有启动第二批，也没有延长第一批窗口。后续用户重新要求启动的中文批次见下段；以后续验仍须重新确认当时方便。

**中文续批：当时未共同确认组合态，已正常结束**。随后用户明确要求“现在继续启动中文验证”，代理先核对桌面解锁、原QA路径无进程、源码与自动通过版本完全一致，再执行 `AREACHAIN_PLATFORM_QA=1 AREACHAIN_CONTROLS_PREVIEW_SECONDS=600 python3 -B build/Controls10P/run.py capture-manual-ime-1 'DaybookButtonInteractionTests/interactiveGallery()'`。批次 `844F7EC4-68A1-4CB4-9502-238E75CC7964`、会话 `A9AAF310-0181-4CF4-9C96-FCE486092193`、进程身份 `23057:1791381142:55946`；用户亲自打开Capture，记录7对应g1／37803／`8A0D075B-74C4-4C6D-AB17-F01C3854694E`。用户报告微信输入法为中文模式；经说明按键输入合成拼音、暂不按空格或Return后，当时答复“没有，只有字母”。这一答复及代理当时的判断保留；用户后来澄清未听明白“候选/组合态”的含义，并确认实际候选期操作，见下方补充。输入正文不写入本记录或JSONL。

本批日志未记录到Return／⌘Return控制键事件，没有业务callback；已观察到的Capture鼠标事件取样为editorExists=true、marked=false，但普通字符不在原记录范围内，**不能据此声称键入全过程marked=false，也不能确认输入法内部状态或根因**。代理因当时未能共同确认候选/组合态而停止中文人工项目，没有连续提交试探、切换其他输入法、改变系统偏好/权限或修改生产。当时提出普通原生文本框合成对照的建议，尚未执行；用户后续澄清提供了新的人工观察，不再单凭前述口头歧义认定输入法无法组词。尚无生产最小修复依据，A/B和旧次数差异结论不变。

用户按提示关闭子窗及主QA窗口，并确认仍为0／0、尚无回调。记录29最终0／0、30 scene-closed（window-closed）、31关闭鼠标派发返回且回调0、35 closing和36 closed（galleryClosed）；关闭在ready后约265秒，未到570秒收尾点，因此没有伪造winding-down记录或等待空窗口到期。XCTest沿原正常清理结束，三个释放字段为true，CONTROLS_P_END为 `fileClosed=true complete=true`。`capture-manual-ime-1-execution.json` complete/runtimeVerified=true、Gallery 1方法／1次通过、验签通过、无Runtime Warning；这只证明宿主及证据链完整，不代表中文组合保护通过。运行前后仍为 `41de6ef2199851c2e5bbd73b5f7b61d0d2f634860653c39e45a6981f3ae8a94e`，没有源码修改或并发变化；本批为重复Gallery覆盖，自动去重计数仍60／174。PID原启动身份已退出，同路径进程为空，锁已释放，全程没有桌面入口调用。文档更新后工作流、static及工作区/暂存差异检查输出为 `capture-ime-workflow.log`、`capture-ime-static.json`；未修改Swift或runner，未重复运行已有效的短回归。

**中文人工反馈补充（同日，窗口结束后澄清）**：用户理解测试目的后明确表示在 **Capture QA 子窗口实际试过**：中文候选期间按Enter由输入法处理候选，没有直接用拼音创建新数据条；此前是没有理解代理所说的“候选/组合态”。因此补记为“**候选期间普通Enter未误提交：用户人工观察通过**”。用户口语“按住enter”不作为持续长按或repeat证据；日常“按Enter”可指按下后释放，尚未记录精确按压时长。该反馈未定位到确切批次、窗口身份及事件序号；最近中文批JSONL未记录Return，与这条人工观察的关联仍缺证据，不能补造marked=true、keyDown/keyUp或判定记录器漏记，也不能否定用户观察。组合期间⌘Return、上屏后分别提交及事件关联的完整C验收仍待补；不扩大为全部中文保护或真实长按通过。此次只更新原记录与本地证据索引，没有再次启动窗口、改测试或生产，也没有新增自动执行次数；工作流、static及差异检查重跑。

**中文候选保护实际取证批（同日）**：用户再次明确“那现在进行测试”后，预检桌面解锁、QA路径无进程，源码仍为上述41de6e…a94e，沿原完整正常PrivacyQA运行 `AREACHAIN_PLATFORM_QA=1 AREACHAIN_CONTROLS_PREVIEW_SECONDS=600 python3 -B build/Controls10P/run.py capture-manual-ime-2 'DaybookButtonInteractionTests/interactiveGallery()'`。原锁立即取得，六项真实授权清除、隔离目录/签名及串行保持。批次 `C63FD362-7DB3-4209-B64C-B1F3CA1AA0A9`、会话 `089E9D06-6D32-476B-AC46-57D2F1CEF12E`、进程身份 `43256:1791382363:524031`；Capture只有g1／37859／`F116ACFB-9911-4E72-85C3-795083A7B66B`一个子窗。沿微信输入法合成材料操作，要求每组完成后再回对话报告，避免把中途切窗后的状态当作按键当时状态；未将此前口头歧义追认为已证实的焦点根因。

| C本批路径 | 实际事件、回调与人工观察 |
|---|---|
| 候选期间⌘Return | keyDown序号11、18、21、24、27、30、33、36、39、42、45、48、51、70、73、76、79共17次，全部marked=true、Command修饰有效、isARepeat=false，有逐次匹配的keyUp，各dispatch-end回调数0，全会话也无对应业务回调。用户报告快捷键前后候选词仍显示、候选期间计数未增加。**本路径取得真实组合态/事件/无回调及人工一致证据**；保留全部17次操作，不将其虚写为只按过一次，不作为L持续长按通过。 |
| 候选期间普通Return | keyDown 54、62、66共3次均marked=true、repeat=false；对应keyUp 56、64、68均marked=false，pressSequence成对，按下和释放派发均无回调。用户确认普通Return完成候选、待办/手记不增加。**本路径取得组合态到非组合态及无误提交证据**。 |
| 确认后的⌘Return与误触归因 | 紧随普通Return 54/56之后，keyDown 58为marked=false、repeat=false，callback 59确切关联58，diary 0→1，dispatch-end 60恰为1，keyUp 61匹配58。用户最初报告候选期间0／0且提到一次误触；代理提出上述具体事件和计数后，用户明确“对，这个是我误触的”。**本批额外一次手记已解释为候选结束后的独立快捷键触发**，没有单个事件多次回调证据；不归为组合保护失败。 |
| 确认后的普通Return | 用户明确反馈已经实际测试过：文字确认后一次普通Return新增一次待办，界面与回调同步；未要求重复。**人工观察通过**。本批没有marked=false的普通Return事件，最终待办仍0，故没有将该反馈虚配到本批；前批A证明的是合成abc的非组合单次提交。中文上屏后该路径的本批逐事件对应仍未补齐。 |

本批共21个Return keyDown和21个匹配keyUp，repeat均false；唯一callback为59。完整日志为 `capture-manual-ime-2-089E9D06-6D32-476B-AC46-57D2F1CEF12E-events.jsonl`。数次按键不等于持续repeat，不丢弃额外操作来满足单次描述。本批对已记录回调无未关联、重复记录、跨窗或单事件多回调证据；不能用它解释旧35511等窗口的历史差额。没有确认生产或测试设施缺陷，未修改生产、Swift测试或runner。

**本批收尾与有效性**：用户确认已关闭。记录88最终todo=0/diary=1、89 scene-closed、90关闭鼠标派发返回；91在约570秒进入原收尾期，随后只有主窗关闭鼠标事件92，93 closing/94 closed为galleryClosed，三个释放字段均true。CONTROLS_P_END核对fileClosed=true/complete=true，runner complete/runtimeVerified=true；Gallery 1方法／1次通过、严格验签通过、无Runtime Warning。前后源码一致，PID原启动身份退出且同路径额外进程为空，锁已释放；不附着、不调用桌面入口或清理容器。此为重复Gallery执行，原有效自动证据仍60方法／174次。D的有提交后重开和普通搜索撤销/重做没有进入；H/K/L、原Stepper警告和指定Cursor等缺口保持。仅更新原记录和本地证据索引，工作流、static（含229项脚本回归）及差异检查输出为 `capture-ime-2-workflow.log`、`capture-ime-2-static.json`，源码未变不机械重跑自动整批。

**当前归因与限制**：首批每个已观察Return均为非repeat、有成对keyUp、单一同步回调；无未关联业务回调、重复记录或跨窗串入的证据。旧次数差异仍为“未复现，旧原因未解决”；只有最新中文批的那次额外手记得到了具体事件及用户误触确认，不能倒推旧因。中文候选期间两条按键路径、确认后⌘Return已取得本批运行证据，确认后普通Return有人工作用确认但缺本批逐事件对应，因此不标记完整C证据全部闭环，也不要求用户机械重复已确认操作。桌面入口（旧app对象AX/截图/打开/激活/关闭）全程暂停，只读本批日志与进程身份。H/K/L、未知历史副作用、Stepper运行警告、其他人工/平台能力及指定Cursor verifier缺口仍保留；整体partial及未接受整体交付不变。

**已运行检查**：修改后该Swift文件严格SwiftLint、14项原runner隔离测试、工作流和工作区/暂存差异检查通过；static质量门禁通过，含229项原脚本回归。自动与人工结果树本批无Runtime Warning，不意味着旧Stepper警告消除；反例沿旧写法有未使用withDispatch返回值编译警告，SDK AX弃用及ad-hoc Hardened Runtime提示继续保留。最终记录编辑后重跑工作流/静态/差异检查，输出为 `capture-workflow.log`、`capture-static-final.json`；最终源码与暂存身份复核仍与本批通过版本一致。未变的整批Swift不机械重跑。

#### P 提交后重开、多行搜索与剪贴板输入补证（2026-10-08）

**整体继续 partial，最终接受仍由用户决定。** 继承 P 的60方法／174次与 O 的315方法／770次独立历史来源；没有将二者相加，也未重跑整套候选保护。本次只修改原测试支持、相关测试和原文档；保留暂存/并发修改，生产输入政策、匹配器、保存及安全流程不改。桌面入口（包括旧app对象AX、截图、激活/关闭）暂停，只有原PrivacyQA/XCTest启动窗口；系统剪贴板不由代理读取、备份、覆盖或恢复。

**入口、观测及预期**：Gallery 原普通搜索仅workspace，本次工具条暴露原workspace/menu/tags/diary夹具；剪贴板子窗直接绑定原session.searchMode，支持mixed/exact/regex，不走默认复制/粘贴回调。可选中段初值只在新建夹具时通过原Binding设置“头🧪尾”；用户将光标放在🧪之后，沿原repeatedUndoRedo测试核对UTF-16位置3→6→3→6。该设置是测试准备，不是观测，不为用户代做真实粘贴。Capture重开仍是新合成夹具，初始草稿空、计数0／0；旧窗提交后保留草稿，不能解释成生产持久化行为。

`ControlsPlatformEvents`仅增加Undo/Redo/Paste语义，修饰键限定⌘Z、⇧⌘Z、⌘V；普通字符及其他组合不记录，Command先释放时keyUp只配对已有操作。批次/会话/窗口/序号/时间和原同步回调边界保持。`SearchMultilineFixture.observedField`按实际locale和原placeholder唯一定位，`inputEvidence`从原Coordinator Binding读取查询（包括tags/diary私有状态所绑定的值），仅输出预定合成值相等布尔、查询/field/editor一致性、长度/选区、合成结果与计数。没有任意正文或正文哈希；合成结果预期沿原测试固定集合，regex字面反斜杠n按换行匹配，标签连续子串与其他搜索分开。原100ms生命周期tick与白名单事件前后取样，去重状态只保存这些标量；不改输入、选区、undo分组或焦点，不把时间相邻取样当事件因果，也不保证两次tick之间每个瞬态均可见。Record点击会切换焦点，连续输入不插入该操作。

**短自动回归**：`input-short-preparation`经原锁等待52.38秒后执行完整正常PrivacyQA，取得锁与运行后源码相同（`ff13cfc31d0642a1ce64b923ae9b61d064772c51227d2a1f04ba668ed45f0e69`）。17方法／21次全部通过，零失败/跳过/Expected Failure/Runtime Warning；其中新增5方法／9次，覆盖语义白名单/释放配对、四个普通搜索命名pasteboard→撤销→重做→再撤销输入x、中段初值/UTF-16、剪贴板两材料×三模式及提交后重开/迟到回调拒绝。原6个事件方法、4个生命周期方法及工作台两个原undo门槛一起通过；**命名pasteboard不是系统真实粘贴**。20会话JSONL、closed、文件关闭回执全部核对，PID55187的启动身份已退出，同路径无残留，QA严格验签通过。新增取样的重复调用保持原editor/UndoManager对象、输入/光标、groupingLevel及canUndo/canRedo；四普通入口还核对合成待办快照和临时历史文件不变、清理后目录不存在。没有运行真实系统复制/粘贴、偏好或安全授权。

| 项目 | 本轮人工步骤与证据状态 |
|---|---|
| 中文上屏后普通Return | 本批g1事件36/40（marked=false、repeat=false）成对，回调37为todo 0→1、派发38为1；用户确认可见1／0。人工观察与逐事件证据齐全。 |
| 提交后重开 | g1已提交后关闭44，g2打开48、状态49为空草稿0／0；新窗58/62成对Return、59为todo 0→1；用户确认新身份、空值及两次1／0。验证的是新建合成夹具契约，非生产持久化。 |
| workspace普通搜索 | 用户真实两行系统粘贴、撤销、重做、再撤销、x完整序列，事件/状态相符且人工明确正常无残留；该批主动终止缺正常收尾回执，局部输入事实保留。中段原自动通过，用户另明确人工正常，但本批没有对应中段窗口与UTF-16逐步样本，不能写成人工选区证据齐全。 |
| menu普通搜索 | 用户明确全序列正常。剩余批g1有真实Paste20、Undo25、Redo30及相符状态；34为全选、36为x，未有第二次Undo。保留人工观察通过、实际已取样步骤通过与“再撤销后输入”关联缺口的区别。 |
| tags普通搜索 | 命名pasteboard自动全序列通过，结果沿原连续子串；用户反复明确已亲自全部测试且符合预期，作为人工观察保留。本批无tags打开/状态记录，不虚构窗口或把其他消费者事件配给它。 |
| diary普通搜索 | 用户明确全序列正常。剩余批g2有真实Paste52、Undo56、Redo60和相符状态；64全选、65为x，未有第二次Undo。“再撤销后输入”的实际事件对应仍缺。 |
| clipboard mixed | A真实换行Paste86后88为queryIsLF、长度/光标3、原生/查询一致、结果符合预期；Undo94后96空/光标0、Redo98后100恢复。B用户人工明确通过，但本批没有queryIsLiteralEscape=true样本；自动两材料原文/撤销通过。 |
| clipboard exact | A模式状态103/112保持queryIsLF、长度/光标3及结果正确。第二次Paste119后121仍为LF，不是字面反斜杠n的正面证据。用户明确A/B及撤销/重做均正常，A在exact下撤销/重做与B的事件对应仍缺。 |
| clipboard regex | A状态106保持queryIsLF、长度/光标3与结果正确。用户明确B应匹配LF及两材料撤销/重做均正常，但没有B布尔或regex下Undo/Redo状态对应；不要求B三模式结果一致。 |

**第一组人工批**：用户确认当时方便后运行原runner `input-manual-capture`、interactiveGallery、600秒。批次`11A2CC96-0B4D-44DE-8EF4-2DE77C0F63E7`、会话`F8216C8F-11E7-45BE-83AA-5B6EF9A60E7B`、PID启动身份`60808:1791390466:827083`。g1窗口39387／`6C5080C5-FC81-4B93-AE85-C594B01BA0FA`，g2窗口39404／`E4A2D7CE-9956-4A20-8706-9F946276E802`。g1在35取到marked=false和非空长度2，Return36→回调37→派发38→释放40（约89ms）；g2 Return58→回调59→派发60→释放62（约132ms），两次均普通Return、非repeat且单一同步todo回调，释放派发均0。用户明确“均符合预期，已关闭两窗”，确认中文上屏后提交、重开空值和两次1／0；可见现象取自用户，不能由长度猜正文。g1还记录一对候选期Return23/26无回调，作为实际额外动作保留，不重做候选矩阵。

g3/g4空Capture、g5空Clipboard、g6/g7 NSStepper及g8窄周随后被打开/关闭，记录按各自身份保留；没有把打开场景、Stepper轨迹或用户额外探索算作普通搜索、剪贴板或L通过。全会话仅有上述2个业务回调，未见跨窗回调。用户反馈关闭后仍无主窗closing，代理按日志说明并停止新操作；最终232 winding-down、233 closing/234 closed为deadline，三个释放值true，文件关闭回执fileClosed/complete均true。Gallery 1方法／1次、QA验签通过、无Runtime Warning；原PID退出、同路径为空，锁已释放。原runner整体complete/runtimeVerified=false保持，唯一原因是运行中并发改变`UnifiedSearchOperationCopy`、`UnifiedSearchTaskFieldSubmission`及xcstrings中新增两个unified.field标签文案。已读差异，均属未装配的统一搜索命令展示，不改变本批Capture/搜索输入路径；本批人工事实有效，不能冒充最终整工作区通过。源码前`ff13cfc…f0e69`、后`0f6752…651c0`，完整清单与JSONL在build/Controls10P/input-manual-capture-*，没有覆盖历史结果或自行清理/重启。

**第二窗口局部事实与主动终止**：用户确认方便并愿意自行复制合成两行后运行`input-manual-search`（原锁立即取得、600秒），批次`98AF43FE-B797-4D40-8D0D-B2FAF508183D`、会话`FF40397F-0B5D-41E9-A199-30AA861CF969`、进程身份`73220:1791391343:986487`。只有workspace g1／39703／`ACD71E4A-A56C-4550-A39B-6A04B3A4EB67`打开：9空值/光标0；Paste20/23后22的queryIsSpace=true、长度/光标3、field/editor一致，24取得SPACE和SLASH结果；Undo25/28后27空值/光标0；Redo29/32后31恢复规范化值/光标3/结果相符；Undo33/36后35空；38为queryIsTypedX=true/光标1/结果空。用户随后明确“工作台全过程正常；我主动结束了测试”，确认系统真实两行粘贴、完整序列和无残留。37为marked=true期间query空、field/editor暂不一致，38在marked=false后同步；22结果尚未刷新，24已刷新，保留这些时序状态，不把瞬态直接判成生产失败。之后额外Undo39/42回到空，未冒充原序列唯一操作；全日志无业务回调、计数0／0。

该批在用户主动结束后原runner工具会话不可恢复，没有execution.json；JSONL止于42，缺scene-closed/closing/closed和文件关闭回执。原validate_session拒绝missing ready/closed；xcresulttool明确缺Info.plist，不能生成有效结果树或补算Gallery通过。原PID启动身份已退出、同路径为空、锁可非阻塞取得（只核对并释放，未改锁文本）；正常资源清理与文件关闭仍未证实。只保存本批已知JSONL的incomplete-events及interruption元数据，没有补造runner成功或删除残留文件。随后停止原生操作、不附着、不自动重启；用户另行明确确认“现在方便，启动剩余验收”后才开始新批。menu/tags/diary、中段和Clipboard未在此批打开，不用workspace推断它们通过。该批源码从启动到中断复核仍为`0f6752bf0b9e126f17f0d41eba462d00fb2da141f639f5de9cbb108e827651c0`。

**第三窗口实际取证与收尾**：用户再次明确确认方便后运行`input-manual-remaining`，批次`F9339105-BEA5-4B0B-879A-3330E6DB5468`、会话`D4937A49-53FF-41E5-B6CB-F33299971382`、进程身份`82203:1791391808:454528`。实际打开menu g1／39769／`F35E04FD-F65A-48C7-8E7D-013E59EEE112`、diary g2／39778／`66068E8B-8647-4965-A048-AC2E6CB8D873`、Clipboard g3／39787／`A6E6F151-1240-47DF-AA01-18D699480F18`。menu状态24/27/32/36及diary状态54/58/62/65分别取得规范化、空、重做、x，最终query/field/editor一致，结果符合本场景预期。两个x之前取到全选（34/64），没有第二次Undo，不能等同原“再次撤销后继续输入”条件。用户对“全部正常”的反馈再次明确为“我都按住你的都全部测试通过，与预想一致”；这份人工观察保留，不因当前日志缺窗口就否定，也不擅自判断夹具漏记、用户未做或生产失败。tags和中段没有本批open；缺少可确切归属的样本，本轮不再机械重复整组。

Clipboard A真实Paste86/89取得LF原文相等布尔；第一次Redo90没有证明状态变化，实际Undo94/97后96空、Redo98/101后100恢复LF。切换exact103、regex106、mixed109、exact112均保留LF，三模式结果相符；模式选择时有意点击控件，不声称这段焦点始终未变。第二次Paste119/122后121仍为LF、长度3，所有记录均没有queryIsLiteralEscape=true；不能用它证明字面反斜杠n已经进入查询，也不能推断生产把字面转义成了换行。用户明确两材料、三模式、撤销/重做均正常并已关闭窗口；B及exact/regex各自撤销的人工观察与现有状态取样覆盖分别保留。全批无业务callback、所有输入取样计数0／0；合成模型/临时历史隔离来自原夹具和短自动检查，未另做人工后的逐实体持久化取样。

最终126在原570秒进入winding-down，127 closing、128最终观察0／0、129 scene-closed、130 closed均沿deadline，三个释放字段true。用户反馈关闭后没有对应主窗关闭回执，记录以实际600秒到期自动清理为准，不虚写为主动关主窗终止。原runner核对JSONL与标准输出及文件关闭回执，complete/runtimeVerified=true；Gallery 1方法／1次通过、QA严格验签通过、零Runtime Warning。原启动身份退出、同路径无残留，锁已释放。第三窗口是第二批主动中断后再次获得明确授权才启动，未延长任一批上限。Gallery通过仅覆盖宿主/清理，不能替代上表的人工步骤与证据缺口。

**最终源码身份与并发影响**：HEAD仍`dba0982362f389c28b468e2d03420bfbe126d7d1`，当前及第三批前后1229文件源码集合SHA-256均为`0f6752bf0b9e126f17f0d41eba462d00fb2da141f639f5de9cbb108e827651c0`。生产582文件摘要`936969b39b852479a44962b22eb086fe1f5bea2c2d8006c86041c6edf61dcf8e`，测试625文件摘要`cf2ec508b3cf566f57740df4b0761264103d48f10601d825be79056239283629`；均按原runner路径→摘要映射、排序JSON计算。暂存摘要`7b7e60ec82f7e6b8e0361cc5659d2f84294d7bfb9a3ea79375a03a99c761509c`与本轮origin相同；冷启动期间已有外部暂存状态变化，本代理未操作索引。相较origin，外部改动为统一搜索ObjectSelection/OperationEditing/TaskFieldEditing三处路由，以及OperationCopy/TaskFieldSubmission和两个xcstrings标签文案，均已读差异，不在原Capture/四普通搜索/Clipboard装配链。本轮四个测试文件与短回归版一致；第三批完整正常QA重新编译当前目标并验签，但不声称并发功能运行已获覆盖。原P60／174继承来源保留，本轮17／21及新增5／9单列，重复Gallery不累加，O315／770不相加。

**剩余条件分类（分类不关闭，也不代表用户接受限制）**：

1. 现有隔离环境可补的仅是具体关联缺口：menu/diary的第二次Undo后输入x，tags完整序列的独立窗口，工作台中段UTF-16 3→6→3→6→4，Clipboard B字面反斜杠n在三模式的查询布尔/结果与选区，以及A在exact/regex下的Undo/Redo。原人工通过反馈有效保留，若继续只补这些对应，不重跑Capture候选矩阵或已闭环的提交后重开。workspace完整序列来自主动终止批，仍缺该批正常清理回执，不能通过新批关闭旧缺口。后续窗口须重新确认方便、用户自愿提供合成材料；不以打开或快捷键被看到判通过。
2. 需单独定界：H嵌套AX/截止失败注入、K安全输入同值替换、其他超出本轮输入范围的问题。本轮不修改这些生产路径。
3. 外部能力依赖：L真实持续按压可靠基线、指定Cursor verifier、真人VoiceOver/真实NSPopover及其他系统版本。工具元数据无指定Cursor入口，未认证/安装/替代；复杂观测材料包含原需求、规则、实际差异、原/本批清单、JSONL和通过/未覆盖项，材料不等于复核执行。
4. 历史未充分解释：旧35511等计数差额、历史额外QA系统交互与未知业务副作用、旧Stepper运行警告。新批正常不关闭旧因，无新来源不重复历史调查。

**收尾门禁**：最终4份相关Swift严格SwiftLint、原runner的14项隔离脚本测试、工作流检查、static质量门禁（230项脚本回归）、工作区/暂存区diff检查通过，输出为`input-swiftlint.log`、`input-workflow.log`、`input-static.json`及本轮工具记录。完整正常QA目标编译和严格验签以短回归、2秒Gallery及第三人工批为证；主动终止的第二批不算构建/测试成功。保留SDK AX弃用、既有actor隔离和ad-hoc Hardened Runtime提示，不将零Runtime Warning解释成历史警告已清除。未运行整套174/770回归、独立日用Debug或其他系统版本，没有安装/提交/推送/发布、真实数据/凭据/偏好访问或权限/签名配置调整。指定Cursor复核仍未执行；人工观察被接受为观察来源，不代表用户已接受整体交付。文档最终编辑后重跑受影响工作流/静态/差异检查，并复核源码身份与同路径进程。

#### 剩余平台验收：K、L与关键可访问性（2026-10-08）

本轮仍为 **partial，用户未接受整体交付**。继承习惯旧Bool兼容修复47方法／131次、H普通保存失败恢复和Stepper焦点修复的原证据；不重复Capture、搜索矩阵。范围只包括必要测试宿主、标量观测、相关短回归和原记录。桌面应用入口（包括旧app对象AX/截图/打开/激活/关闭）继续暂停，只由完整正常PrivacyQA/XCTest启动隔离窗口。

**准备与能力**：原Gallery缺少真实密码sheet人工场景，现以ControlsPlatformPassword组合原PasswordSheetProbe、PrivacyButtonSheetHost和生产PrivacyPasswordSheet。仅假action按首次30秒、重试12秒自动失败；busy期间输入仍由原生产实现允许。两条场景分别标注逐字和用户自愿粘贴的同值覆盖；人工材料为8位ASCII合成数字，区别于历史15字素／17 UTF-16的复杂Unicode样本，日志不写材料正文、字符键位或口令哈希。只在sheet打开、action入口、1秒稳定点、失败边界和关闭记录字段/editor必要UTF-16长度、字段局部身份、按钮enabled、相等布尔与次数；无逐字符取样，不直接读取生产私有State。取消重开单列，不能替代自然清空。

L继续初值500、范围20…999、步长10；原ControlsNativeStepper/ControlsTrackingStepper移至局部测试文件，不改系统autorepeat/continuous或delay/interval。逐次action/Binding原trace保留，导出补方向和收到的事件时间；只有控件内按下之后实际收到本地mouseUp才启动2秒释放后观察。trackingReturned不是释放，未收到mouseUp仍保留精确基线缺口；无全局事件钩子、权限变化或合成repeat补证。500/990/30按钮只准备合成值，排除在action次数外。

**原runner维护**：原O快照路径已缺失，首次准备在读取阶段失败，尚未申请锁或启动；两处历史输入改用现存原P的final-before.json/final-command.json，隔离命令参数一致。原14项mock脚本回归已运行；编译测试的命令夹具相应改为临时合成参数。没有重写runner、改锁或伪造旧产物。首个kl-preparation在编译时报新增默认参数跨MainActor读取错误，未启动XCTest；已改为init内部取默认值，原失败包保留，不计通过。

**准备验证**：kl-preparation-recheck另暴露测试闭包缺显式self，已修正；两个编译失败批均未启动XCTest，不计通过。kl-preparation-checked为12方法／23次；最后增加取消后不再采旧sheet、无释放不生成观察的守卫与测试，kl-preparation-final为 **14方法／26次全通过**，0失败／跳过／Expected Failure／Runtime Warning。完整正常PrivacyQA编译、codesign --verify --deep --strict均成功，14会话原JSONL／stdout／关闭回执一致；PID25297及启动身份1791428991:469676已退出，同路径无残留。最终源码集合摘要6bc00a8b6019780d94d259b469d333f5687db9142702b1a67627a9e3923f6e70申请/锁后/运行后相同，原暂存摘要保持；7个测试Swift变化、无生产变化。严格局部SwiftLint、原runner14项mock、工作流、static和两层diff检查通过，合成材料未出现在最终XCTest标准输出。日志、命令、身份、结果与审计均为build/Controls10P/kl-*；这26次是测试支持／自动回归，不能计为真人输入或长按通过。

**首批人工 kl-manual-k**：用户确认当时方便后启动600秒窗口，实际约448秒由用户关闭Gallery；run3155D826-EE9B-4843-8C4E-734CCF696745、session63EE9C7A-9216-4B0C-ACDD-A79EFA4F167A、PID27739／内核启动1791429277:66992、主窗43092。324行JSONL与stdout／文件关闭回执一致，完整QA编译验签通过，源码前后一致，同身份退出、同路径无残留。runner的1方法／1次通过只证明有界宿主正常结束。

K g1父窗43097有两次action且参数相等布尔均true；首次busy输入后两字段必要长度为8，重试后1秒、12秒失败前及其后取样均为0，字段局部身份保持。g2父窗43125第二次参数相等false，不能计入同值重试；g3父窗43151没有action。用户先报告预定corruptData错误文案，后报告“action一直没变”。核对发现新增宿主在构建时一次性生成说明／计数Text，未在SwiftUI body读取Observation；计数、阶段提示与重开按钮状态未实时刷新。该缺陷破坏人工步骤反馈，不能把局部零长度取样宣称完整真人路径未复现或通过；未取得同值整段覆盖及可靠的残留人工结论，历史API残留保留。没有记录用户输入正文或读取安全字段明文AX。

L g4父窗43172取得20次observed-down／native-mouseDown、45次native-action和45次Binding写入，其中一个26-action序列值20→270，首动作到第二动作约0.50347秒，后续逐点时间保存在原JSONL；tracking调用跨度约2.98368秒，**不是可靠按压时长**。用户未给出方向／释放逐项反馈。原数值Text也是一次性快照。仅收到两条observed-up，且可能是tracking已返回后其他点击的释放；这两条及其release-observation不作可靠释放或停止证据，不补造mouseUp。原生持续重复有动作证据，完整增减／端点基线仍未建立，公共对照及VoiceOver未执行。

**测试侧修正及复验**：反馈移到两个局部SwiftUI View的body，以原Observable状态呈现，不重建生产密码字段或修改Stepper重复机制。新增实际文字1→2、失败阶段、取消后真实点击重开、裸Stepper数值及重置回显检查；记录器在原生tracking返回后关闭未解决的按压关联，其他位置新down亦使旧关联失效，避免将后续up错认成原释放。kl-feedback-check的13方法通过／1方法失败（原busyFailureRetryAndParentClose的configuration1失去keyWindow，未弱化断言）；新增反馈与反例均通过。相同源码单独kl-feedback-focus为1方法／4参数全通过，最终有效所选范围14方法／26次，不能把原整包改写为通过。后一非Gallery包原runner保留missing batch session evidence和complete/runtimeVerified=false；按summary/tests、stdout、exit0及codesign0确认该方法通过，未伪造Gallery回执。该非Gallery进程没有在运行中取到内核启动身份，只有原runner前/后/最终同路径无进程，保留这项观测缺口。前一14会话／PID31373启动身份1791429824:432017均已核对退出。源码摘要91e559aaded93e7a66accec23c806365b322ffcaa5e7501a199f1139aec35f03，两个运行申请/锁后/运行后相同。严格局部SwiftLint、工作流/static及差异检查通过；SDK AX弃用／既有并发与ad-hoc提示仍保留。

修正后再次等待用户确认当时方便，期间未持锁；第二批尚未启动，未把未答复当作确认或拒绝。用户此前已确认可自行使用VoiceOver，但尚无实际朗读证据。最终只读核对当前生产内容与本轮开始相同、全部受测源码与kl-feedback-focus相同、同路径无残留；期间外部暂存操作已包含本轮部分测试和文档，索引摘要发生变化，代理未执行暂存、撤销或覆盖，现有暂存/未暂存均保留。指定Cursor verifier当前无可调用工具，未认证或替代。H两项嵌套AX、旧Capture差额、历史额外QA进程副作用未知和其他系统版本继续开放。

**第二批人工 kl-manual-k2（用户再次确认“当前就方便”后）**：沿原runner／完整PrivacyQA，仅interactiveGallery，600秒内含原30秒收尾，到期正常结束。run181D844D-2D5C-4FE9-B6FA-2F4320C5CC41、sessionE1C1E538-757C-4DDD-A887-2CAA558B8D12、PID36383／启动1791430570:933423、Gallery43423；57行原JSONL／stdout与关闭回执一致，exit/codesign均0，同身份退出、同路径无残留，源码申请/锁后/运行后仍为91e559aaded93e7a66accec23c806365b322ffcaa5e7501a199f1139aec35f03。1方法／1次只计宿主生命周期，不增加自动覆盖。

K g1父窗43428／sheet43429，两次action相等布尔true，第二次稳定点长度0；用户反馈“1→2；没有残留；重开为空”。但该窗首次失败前两栏长度0，未取得busy重填条件，故单列为该路径。用户关闭原父窗后从Gallery另开g2父窗43443／sheet43444，不能把此新场景为空算作同一父窗的取消重开回归。

K g2按再次解释的逐字步骤：初次action1参数相等；30秒失败前与之后两栏UTF-16长度[8,8]、末字段editor长度8，sheetKey=true，busy时Save/Cancel均false，失败后均true。用户明确确认“倒计时中两栏已重填并保留”；此时尚只有action1，代理据原日志澄清并等待第二次提交，没有凭用户概括反馈提前打勾。之后action2参数相等true；下一稳定点两栏[0,0]、末editor0、sheetKey=true、Save/Cancel禁用。12秒失败前及后仍[0,0]，但sheetKey=false：期间用户回聊天澄清“圆点”含义，**不称全程12秒无失焦观察**。用户最后报告“2，也就是隐藏符，都空了”。该具体真人逐字／busy重填／失败后逐字同值重填路径未复现隐藏符残留；结论由人工观察和上述有限取样共同支持，不扩大到整串同值覆盖、历史Unicode样本、生产私有State、真实认证或内存安全擦除。action共2，无额外提交；后续取消有dismissed回执，未取得g2同父窗重开取样。历史API残留继续保留，不建议据此更改生产清空策略。

本批未做同值整串粘贴、L或VoiceOver。用户在批次收尾后明确答“方便”，允许下一批集中L与VoiceOver；该批结果如下，授权本身不计作操作通过。

**第三批 kl-manual-l-ax**：runAF317469-F5B3-4860-A230-424033276705、session48A8314E-33F4-4E8D-8B9C-0638696EB7E4、PID39122／启动1791431255:284391、Gallery43544。600.056秒到期正常关闭，243行原日志／stdout／成功文件关闭回执一致，1方法／1次宿主通过，exit/codesign为0。原锁立即取得，源码申请/锁后/运行后保持91e559aaded93e7a66accec23c806365b322ffcaa5e7501a199f1139aec35f03；该启动身份已退出，前/后/最终同路径无残留。

L g1原生窗43547有2次实际observed-down/native-mouseDown、21次action及21次Binding写入：增加12次为510→620，重置500后减少9次为490→410，逐项步长10。首轮重复间隔约0.499秒，此后约0.100秒；第二轮首重复约0.502秒，此后约0.100秒，原逐点时间留在该JSONL，不用配置值或“约2秒”代替测量。用户先报告按压时长有误差、数值约410–440，再明确报告“松手之后就停止变动了”；实际记录与用户大致数值分别保存，不要求次数相同。两个tracking返回后均为release-unobserved，没有可靠mouseUp和释放后精确窗口；只能确认方向、逐次变化与用户观察的停止，**L精确基线仍未建立**。

L g2原生窗43572为端点操作，3次按下、16次action/Binding。用户报告“超过990之后，再点击一次就到20了，会跳到另一端”；日志在990准备后确有20起始序列，在30准备后有20、999、989等序列，保留原生回绕事实，未改默认配置。三次释放仍未观测到，不把端点动作或tracking返回当精确释放证明，不据此判公共组件重复缺陷。拖出/取消边界未独立执行。

g3公共窗43599原用于后续辅助检查，记录23次Binding写入：整数仅510、500两次，其他21次为小数样例；不能把全部23次当整数长按对照。这里有2条observed-up和1个release-observation，但没有有效的原生精确基线，也没有用户按同一长按方案操作的确认，故不判公共长按等价。用户随后询问“VoiceOver是什么”，说明本批没有实际VoiceOver朗读，相关普通点击不能计为VoiceOver通过。代理解释系统朗读功能后，用户另行确认“现在方便，尝试VoiceOver”，再启动下一批；未由代理开启或修改任何系统设置。

**第四批 kl-manual-voiceover**：用户确认后仍由XCTest启动，run6BE1B0CD-CFAA-48A3-9841-6E2881955A94、session8A2F7CBC-01C3-4E2F-A79F-FEBAA8504067、PID43485／启动1791432022:234232、Gallery43649，公共窗43667及43703。用户一度误以为新窗口也已关闭，经自行Mission Control找到当前窗，没有恢复桌面工具。实际600.162秒正常到期，142行日志与关闭回执一致、同启动身份退出、同路径无残留；exit/codesign=0，1方法／1次宿主通过。

本批用户最初开启的是麦克风／听写界面，不能算旁白。经用户自行Fn＋⌘＋F5开启macOS“旁白”后，用户明确反馈“可以读取界面名称了”，并对名称／设为500激活问题概括回答“是的，可以”。没有取得逐字名称、角色、数值朗读或可靠的逐项VoiceOver操作报告，因此只保留这份概括人工反馈，不宣称普通按钮全部辅助契约或Stepper增减已通过。日志中的重置／Binding动作不能自行归因于旁白；禁用、安全字段、焦点顺序／取消关闭归属仍待独立检查。

并发任务在批次间扩展习惯创建命令，运行中继续修改搜索、测试及语言资源。原runner保留source changed during test、complete/runtimeVerified=false；本批源码before为bc89849e3b786a6ccd3720c799cbc0d527abbd78dc763c68304f4bc88d0b6c19，after为1816f1a8e49d4d2bf57339f80c62d52682d8d7361f412140135cbe3285489258。沿实际差异核对，本次ControlsPlatform、PasswordSheetProbe、原PrivacyPasswordSheet、SecureField、Stepper及其宿主未改变，语言资源只新增16个unified.routineCreate键，既有键未变；实际控件观察可保留其限定范围，不把整份当前源码判通过。

用户随后明确同意最后一批旁白与自愿合成同值粘贴。kl-manual-final在完整目标编译阶段被并发新增UnifiedSearchRoutineCreateTests的Testing宏错误阻断（可选链被展开到非可选[UUID]），无XCTest窗口或人工输入；exit65／codesign1，源码期间又有变化，原失败结果保留。最新文件已被并发任务改成先取tagIDs再断言，代理未修改其实现；核对新搜索PlanList只增加习惯创建呈现后，沿原锁启动kl-manual-final-ready，以最新完整目标复验，不排除源码、不使用旧包或伪造通过。

**最后人工批 kl-manual-final-ready**：原锁单次等待102.742秒后取得，完整正常PrivacyQA编译成功后才出现Gallery44005；runD8194485-FC33-4167-84E5-13A8E29D11EF、session38F755D3-FFC4-4455-BEE9-72C07254DFFB、PID50434／启动1791433257:3193。仅一次密码同值覆盖场景，父窗44007／sheet44008。29行JSONL与stdout／成功关闭回执一致，600.526秒到期结束，exit/codesign均0、1方法／1次宿主通过，同启动身份退出、前/后/最终同路径无残留。运行期间并发修改两处习惯／任务创建呈现、相关测试和语言资源，原runner保持complete/runtimeVerified=false及source changed；源码before为0e286d897840c2c17ed25a1e2c6778498b49f6d27dfb47aab8a0d0788b14942e，after为70b62f2bbfbeb18784958f2df5c7c1b79afdc92edde12ffbc23071d5c096d034。本次密码/控件实现与宿主未变，不把本包当整份最新源码的最终通过。

K采用用户明确自愿的合成材料整段同值粘贴方案，代理未读取或改写系统剪贴板。action1/2参数相等布尔均true；首次busy失败前与之后字段长度[8,8]、末editor8，禁用/恢复按钮状态符合原流程。第二次提交同步入口尚为[8,8]，约1秒稳定点、12秒失败前及失败后均为[0,0]、末editor0，sheetKey均true、字段局部身份保持1/2。用户报告“统一材料，已经是action2了，没有隐藏符，取消重开为空”。**本次具体8位ASCII材料的人工同值粘贴路径未复现隐藏符残留**；同步入口暂有原值不能与稳定残留混为一谈，原生取样不是私有State直读。输入方式依据人工方案与反馈，未收集字符键位、口令正文/哈希或安全字段明文AX。与逐字路径分开保存，历史Unicode/API残留仍开放。

取消重开与旁白须另判：本批从action2到期限清理之间没有password-dismissed或新sheet-open。用户先概括报告取消重开为空，后明确澄清密码弹窗“没有消失”；因此**不把原概括反馈计为本批真实取消重开通过**。自动支持测试中的取消重开仍只保留自动证据。用户实际旁白听感为“读输入框未输入的固定字符，保存还是保存”；没有逐字安全角色/标签、禁用状态宣告或完整焦点顺序证据。再次尝试旁白激活取消时用户回答“没有”，但后续反馈未可靠绑定到尚有效的窗口期，日志随后核实本批已按deadline清理。代理立即撤回鼠标对照指令并要求停止操作旧/其他窗口；**旁白取消及关闭后的焦点继续未完成，不作为生产取消故障结论**。未执行有效的鼠标关闭对照，也没有新一轮去补造回执。

本轮真人结论：K两条具体路径均未复现稳定隐藏符残留，整段粘贴路径的稳定取样有完整keyWindow条件，逐字路径的长观察段存在失焦，边界分别保留。L取得真实增/减、逐次action/Binding与人工停止观察，但无可靠释放，精确基线未完成；端点回绕只作原生事实，不推出公共长按等价。旁白实际启用并有名称/提示朗读的概括反馈，关键角色、禁用、增减、取消及关闭焦点未完成。下一步若继续，应由熟悉旁白的操作者在同一隔离宿主做明确逐项复验；L需能可靠观察释放的既有平台能力，当前禁止增加全局钩子或权限，故不盲试；现证据不足以要求生产安全或重复流程修复。指定Cursor verifier不可用，H两项嵌套AX、旧Capture差额、历史QA未知副作用、其他系统版本及用户未接受整体交付均保持。

**本续轮最终门禁**：仅更新原工程记录，未改生产或测试代码。因并发源码变化，人工结束后沿原runner运行kl-continuation-compile的完整正常QA build-for-testing，原锁立即取得，源码申请/锁后/运行后均70b62f2bbfbeb18784958f2df5c7c1b79afdc92edde12ffbc23071d5c096d034，编译与严格验签成功，complete=true、runtimeVerified=false；没有再次启动XCTest或人工窗口。这补齐当时最新完整目标的编译证据，不把并发源码运行覆盖或前两包source-changed标记改成通过。工作流、static（含当前脚本回归）、工作区/暂存区diff检查通过；四个实际人工包的XCTest标准输出均未发现合成口令材料。每批原日志、关闭回执与进程启动身份退出均已核对，最终同路径无残留；未附着旧app、清理容器、关闭其他任务进程、提交、推送、安装或发布。当前仍partial，本轮停止人工验收，不代替用户接受整体交付。

编译完成后的只读收尾又发现并发更新UnifiedSearchParameterField、UnifiedSearchRoutineCreateTests并新增RoutineCreateLegacyNativeTests；本次ControlsPlatform/安全输入/Stepper相关源码未变。这些后续搜索变更不在上一个编译快照内，当前整份工作区的最新编译/运行状态不由该包证明，不反复追赶无关任务的动态源码。本任务不持锁；收尾时原锁由其他任务持有，未干预，QA同路径无进程。

鼠标对照问题的回复在收尾后到达，用户回答“可以”。保留此人工反馈；因最后批次已结束且原日志没有对应password-dismissed／重开回执，无法绑定到该批有效窗口期，不将其补写为本批取消／重开或旁白通过，也不继续操作旧窗口。

### 第十阶段剩余运行问题：Stepper 警告与 H 截止注入核对（2026-10-08）

**整体继续 partial，用户未接受整体交付。** 本轮不启动人工 Gallery，不使用桌面工具或旧 app 对象的 AX/截图/激活/关闭；只运行完整正常 PrivacyQA/XCTest。原输入人工反馈及未对齐证据、H 两项嵌套 AX、K 同值替换、L 真实长按、旧 Capture 差额与历史 QA 未知副作用分类保留，不由本次结果关闭。H 当前源码差异与缺失接点见[H 当前截止注入能力核对](#h-当前截止注入能力核对2026-10-08)。

**根因与单条件证据**：原样 `keyboardSingleRepeatReleaseAndDisabled()` 在 `stepper-original.xcresult` 为1方法/1次通过，但保留 `SystemPageHost.swift:67` 的“Modifying state during view update” Runtime Warning。`stepper-trace.xcresult` 用临时日志保存原方法事件、更新和状态写入顺序；该诊断改动单独保存在 `build/Controls10P/stepper-diagnostic.patch`，最终生产/原测试均无这些输出。初挂、取得焦点、方向/空格按下与重复/释放、鼠标及对应布局均没有该警告；禁用后的布局中出现 `focused true → false`，紧随警告，再返回焦点闭包。清理未再出现该警告。

同进程 `Thread.callStackSymbols` 明确为 `SwiftUI PlatformViewChild / AppKitPlatformViewHost.coreUpdateEnvironment → NSView.adoptEnvironment → NSControl/NSStepperCell/NSCell.setEnabled → NSWindow._realMakeFirstResponder → DaybookStepperKeyView.resignFirstResponder → focusChanged → DaybookStepper.@State focused`。这发生于 SwiftUI 自己传播环境，不能只在 `updateNSView` 周围加标志解决；不是 `resetDirection` 或测试 Probe 的数值/禁用赋值直接在更新中发布。SystemPageHost 的 settle 行只是当时发起布局的位置，未改 helper。

`stepper-focus-control.xcresult` 的 `disablingWithOrWithoutFocus(releaseFirst:)` 两参数均通过：false（仍持焦再禁用）带同一警告，true（先失焦再禁用）无警告；与前两批原方法复现相互对照。原数值、写入次数和禁用断言全部保留。现有证据确认公共桥接的呈现反馈时序缺陷；没有发现该警告同时造成值错写、禁用失效或生命周期断言失败，不将警告中的 undefined behavior 字样当作已经观察到其他损坏。

**最小修正**：生产只改 `DaybookStepperKeyboard.swift`。AppKit 接受/失去焦点仍同步返回，isEnabled 和 attachment 的同步防线及 DaybookStepper.adjust 不变；只将用于按钮描边的 focusChanged 放到主队列。通知执行时读当前 enabled/attachment/window.firstResponder，不捕获旧 true；每次焦点/接入变更推进代次，丢弃被取代的通知，dismantle 先失效再清空回调。附件按钮禁用的既有异步刷新保持。外部 Binding、数值/方向/次数、空格最近方向、原步长/端点、点击区域、辅助语义、相邻编辑提交和系统重复机制均未修改。原键盘测试最终与起点逐字一致。

新增 `DaybookStepperFocusTests` 保留上述两条件回归，并检查同一轮取得/失去焦点只发布最终 false、拆离不恢复旧 true、原 hosting view 重挂、拆卸丢弃待发通知及清空动作、多实例焦点转移不串 Binding/最近方向。原 Stepper/消费者回归继续覆盖实际窗口按键、按住禁用、取消/拆离及重建、边界与保存/草稿。新增桥接直接调用的拆卸断言属于局部生命周期证据，不冒充真人输入；原事件级拆离测试单独保留。

**执行证据**：全部证据沿原 `build/Controls10P/stepper-*` 保存，使用原 `build/PrivacyQA-Controls10P` 与 QA bundle ID、临时签名、生产 sandbox entitlement、LSUIElement=NO、六项真实钥匙串环境清除、串行测试和原锁单次900秒。对照批等待146.08秒后取得原锁，其他已完成定位批立即取得；每批启动前未锁屏且同路径无进程。原 P runner 固定要求 Gallery 的 CONTROLS_P_BEGIN/END，本轮刻意不挂 Gallery，故其 execution.json 保留 `sessions: missing batch session evidence` 和 complete/runtimeVerified=false；不修改结果树或伪造会话来消除此标记。非 Gallery 测试按真实 summary/tests、标准输出、codesign 及单独 `*-process-checks.json` 的 PID/内核启动身份退出证据判断。

首轮修正验证 `stepper-repaired-focus.xcresult` 为3方法/4次通过、零失败/跳过/已知失败/Runtime Warning。定位 trace 批期间并发更改了两份 UnifiedSearchSubtask 呈现源码及 Localizable.xcstrings，运行后摘要正确标记 source changed；已核对它们不在 Stepper/H 调用链，不把该批当整份最终源码通过。其他并发搜索测试和文档改动保留，不提交或改写暂存区。

**最终回归与计数**：`stepper-regression.xcresult` 实际21方法/46次全部通过，0失败/跳过/已知失败/Runtime Warning。范围为完整 DaybookStepperTests、DaybookStepperFocusTests、ClipboardStepperConsumerTests、ClipboardOptionsConsumerTests，以及原交互套件除 syntheticHoldComparison 外的6方法；未机械重跑174/770，也未将按住取消/重复事件断言当 L 物理长按基线。中英文、浅深色、320pt长标签和440pt生产选项均沿原矩阵执行。最终只删除新增测试文件的一处多余空行后，`stepper-final-focus.xcresult` 又完成焦点套件及原警告方法4方法/5次通过、零 Runtime Warning；其余17方法/41次代码未变。按方法/参数取最后有效证据仍为**21方法/46次**，不把定位/重复执行相加到 O/P 历史总数。原键盘方法的断言从未删减，最终与起点相同。

**源码与门禁**：最终 HEAD `61f4ba2cca305b7879186a6f1cd919cd92caf887`；扩大回归前后源码摘要均 `59711dc8675ed1f13791091811130a2271ed101d36fea6a6e71cebfbf879f56e`，最后焦点复验前后均 `20888895120db67602c37d399503307cb6db2a4296ead480221b232488f2a461`，跨批差异仅新增测试的空行。两批分别等待原锁29.21秒与31.24秒，未抢锁/换锁。暂存区一直为空（摘要 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`）；并发搜索代码、资源、测试与统一搜索文档全部保留，未计为本轮实现。正常完整 QA 重新编译、每批 codesign --verify --deep --strict 成功，没有排除源码或运行日用构建。

最终2个改动Swift文件严格SwiftLint通过；中途新增测试的一处重复空行曾令lint失败，已删除并补受影响运行。工作流、静态质量门禁（231项脚本回归）、工作区/暂存差异与新文件空白检查通过，日志沿 `stepper-swiftlint.log`、`stepper-workflow.log`、`stepper-static.json` 保存。静态profile避免启动普通测试宿主，Swift运行证据由上述完整隔离目标提供。编译仍有已有SDK AX弃用、actor隔离及ad-hoc Hardened Runtime提示；最终零Runtime Warning只限定所选方法。只读查看本批XCTest生成的焦点/禁用及中文深色长标签缓存图，确认描边/禁用和换行显示；不是桌面截图或窗口合成器/真人验收。

**收尾与缺口**：每批通过libproc只读记录同路径测试进程PID及内核启动身份，再核对原身份退出；共6个本轮观察进程均退出，同路径无残留，不附着/关闭/启动应用。指定 Cursor verifier 在当前工具清单仍无可调用入口，未认证、未用其他代理替代，公共控件独立复核继续未完成；以上测试不能代替该项。H普通截止保存失败、两项嵌套AX、L真实持续按压和原人工/历史缺口保持。下一项最有价值的代码工作是单独定界并授权 H 真实详情链的最小显式保存依赖接点，再补回调返回前恢复及同宿主重试；不需用户重复已反馈正常的输入。本轮无提交、推送、安装、发布、真实数据/系统剪贴板/个人偏好或签名权限变更。

**当前工作树收尾补记（2026-10-08）**：本轮 Stepper 焦点3方法／4次、原警告方法1／1、两个剪贴板消费者2／5，共6方法／10次通过，零Runtime Warning；覆盖通知取代、拆离／重挂、dismantle取消、双实例、默认零写入及双语浅深色保存／取消／重开。生产和相关测试／支持文件与此前通过版本相同，其他15个历史方法没有机械重跑，原21／46仅保持其原版本与影响核对效力。完整编译、并发新测试阻断、进程身份与最终门禁统一见[本轮 H 收尾补记](#h-当前工作树收尾验证2026-10-08)。不改变指定Cursor、L或人工缺口。

## 第十阶段 N：手记向上标题气泡悬停保留修复

2026-10-06。本轮仅处理 DiarySummaryRow 标题气泡的真实悬停与退出链；显示资格、截断、方向/偏移、样式、复制、隐私投影、选择/双击、菜单和原300/100/80ms延迟保持。组件与责任见[组件目录](component-catalog.md#第十阶段-n手记标题气泡窗口观测)。K、L、公开 Copy/More、真人辅助功能与其他历史问题保持独立。

**基线与原因**：完整正常目标首次编译被并发 `TaskMutationService+Title.swift:50/93` 的 String/[UUID] 不匹配阻断（baseline，退出65、0测试）；本轮未修改或排除该文件。身份检查发现并发修正后重新运行 baseline-resumed，4方法/10次中9通过、1失败，复现 M 的下部向上气泡。行窗口 `(32,151,316,57)`、标题 `(40,185,216,16)`；相邻点 `(153.29,207)` / `(153.29,209)` 均在气泡正文内。后一点 bubble 先 false，约84ms后 row/title 清零。已证实的是可见气泡与祖先行边界下的悬停回调不一致；未通过移除某个祖先修饰器的对照证明 SwiftUI 内部裁切实现，不把猜测写成内部根因。

**最小修复与清理**：DiarySummaryRow 显式启用 RowTitleBubble 的内部 `observingWindowHover`；其他标题消费者和备注继续原路径。RowBubbleHoverRegion 挂在当前气泡背景，只用所属窗口事件和当前圆角路径判定，重新换算真实几何并尊重窗口/滚动裁切，不使用祖先行的 visibleRect、不吞事件、不扩点击形状。SwiftUI 原 onHover 在该模式不写同一悬停状态；内部悬停仍驱动原动态边框和光标。布局/跟踪区更新只合并一次主队列复测，无轮询或全局注册表。窗口失活/关闭、SwiftUI onDisappear 和最终拆除均清理；代次拒绝迟到几何回调，淡出期间不继续持有观察。

BoardRowChrome 仅增加不触发重绘的手记标题指针记录和 resetTitleHover 清理入口。原行退出任务会在气泡持有时保留标题但取消标题退出任务；新的气泡退出回调在指针不在标题时重新走原100ms入口，从而释放该保留状态。手记身份/标题替换、显隐资格失效与卸载撤销标题任务；shouldShowTitleBubble 原条件未变。没有增加复制替身或访问真实内容。

**过程证据**：candidate 的首次打开有3次失败；加入5ms只读取样的 opening 六消费者均通过，但不能把取样后的时间延长当作原门槛通过。随后将即时指针记录改为不触发视图观察，原消费者严格通过。closure/trace-exit 暴露了测试将淡出期间残留的原生视图误算为未退出，并采用了标题下沿而非 M 的标题中心。记录显示离开后 row/title/bubble 已按原延迟清零；最终测试分开断言逻辑状态与原弹簧淡出后的拆除，返回路径复用原标题中心，同时把真实观察清理提前到 onDisappear。lifecycle 的7方法/16次全部通过，0失败/跳过；原 lower=true 失败及两侧相邻点严格通过，没有延长生产延时、强设悬停或标 Expected Failure。

**隔离与产物**：所有运行沿同一 `build/.build.lock` 单次最多900秒申请、完整正常 PrivacyQA、独立 `build/PrivacyQA-Diary10N` / `com.areachain.privacy-qa`、local临时签名、生产sandbox entitlement、LSUIElement=NO、六项钥匙串授权清除和串行原生事件。只由 XCTest 启动合成资料窗口；命令、结果包、日志、起点摘要与诊断导出存于 `build/Diary10N`。没有修改个人签名、权限、系统剪贴板或真实数据。指定 Cursor verifier 当前不可调用，独立复核缺口保留，不认证或替代。

**最终结果**：生产修复与原失败关闭已验证，完整验收仍 **partial**（实际屏幕与指定独立复核缺口）。regression 的25方法/56次全部通过，覆盖 RowBubbleConsumerTests、DiaryTitleHoverTests、RowBubbleInteractionTests、RowBubbleSurfaceTests、LivePreviewSurfaceTests、TaskRowBubbleTests；真实普通手记不点击默认复制，通用气泡只用合成 onCopy 验证单次回调、圆角外侧/阴影排除及移除后不再回调。新增滚动、行身份替换和直接观察生命周期也通过。screen 补验首次因合成标题尾部空格与生产 trimming 的精确定位不符失败；修正后 screen-final 的10方法/19次中18通过、1个同窗多行失败，原因是测试选择 first 原生视图，命中了上一行正在淡出的旧气泡。保留该失败，按原生对象身份排除旧视图后，screen-capture 的 rowsDoNotHoldEachOther 1方法/1次严格通过，两个行各自仅持有自己的气泡，离开后均清零。最终相关版本按方法/场景去重为 **26方法/57次通过，0失败、0跳过/Expected Failure**，不是跨版本累计计数。screen-final 同时重验了最终以原生气泡几何定位的原消费者；screen-capture 只修测试归属，生产源码与 regression 摘要一致。

状态清除先按原80/100ms政策及调度裕量检查，原 snappy 弹簧淡出的物理拆除另检查；没有延长任何生产关闭时间。原生鼠标事件覆盖上下展开、标题中心往返、行边界相邻点、20ms快速往返、两种标题长度/宽度/窗口高度、中英文浅深色、布局和NSClipView滚动后新几何、敏感隐藏/恢复、Command、内容/行身份替换、重挂、窗口失活/关闭与同窗多行及多窗口隔离。滚动位移通过隔离NSClipView设置，进入/离开仍通过原生指针事件，不冒充用户滚轮手势。其他行选择/双击接线和原点击shape静态未变；未真实打开手记窗口或用消费者默认复制验收系统剪贴板。

**证据层级与门禁**：缓存图 m-boundary-0.png / m-boundary-1.png 与 m-N-screen-boundary.png 已保存并检查，后者显示第一行气泡向上覆盖行外、第二行独立；透明宿主缓存不是桌面合成器画面。m-N-screen-boundary-ax.json 独立保存窗口身份、辅助树、原生几何；无新增公开辅助节点或Copy/More语义改动。桌面工具按确切QA路径取得辅助状态，但 getScreenshot / getAXStateAndScreenshot 两次都报 timeoutReached，未取得有效实际屏幕画面；不把缓存替代该缺口，不改权限或重试认证。固定40秒只用于隔离截图窗口期，期间不投递指针，默认自动回归不等待。

最终8个Swift文件严格局部SwiftLint、`python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile static --format json`、工作区和暂存差异检查通过。完整正常QA Debug编译通过，`codesign --verify --deep --strict` 验证QA包通过；原AX弃用/并发Sendable等编译警告保留。未运行全量应用测试、独立日用Debug构建、其他macOS版本、真实系统复制、真人辅助功能或K/L人工验收。起点/最终摘要保存在 `build/Diary10N`；暂存差异摘要保持，原BoardRowPointer、LiveDiaryComposerPreview、LivePreviewSurfaceTests、RowBubbleTestSupport与起点一致，其他并发修改未回退。未修改检查器，无对应检查器新增测试。未发现本范围仍可复现的原生运行缺陷；屏幕工具和Cursor复核缺口不宣称关闭。完成后停止，不提交、推送、安装或发布。

## 第十阶段 M：手记气泡与复制入口定向诊断

2026-10-06。诊断交付完成，产品验收仍 **partial**：预览正文定位与复制入口两项属于测试假设错误；`DiarySummaryRow` 下部宿主的向上气泡存在真实悬停保留缺陷。仅修改 [RowBubbleConsumerTests](../AreaChainTests/Theme/RowBubbleConsumerTests.swift)、[LivePreviewSurfaceTests](../AreaChainTests/Theme/LivePreviewSurfaceTests.swift)、原 [RowBubbleTestSupport](../AreaChainTests/Theme/RowBubbleTestSupport.swift) 及本记录，未修改生产代码。第八阶段 D/F 的历史失败不删除，以下证据补充其归属。

**隔离与身份**：macOS 26.6.2（25G83）arm64、Xcode 26.6；HEAD `dba0982362f389c28b468e2d03420bfbe126d7d1` 加原暂存/工作区。沿原 PrivacyQA 完整正常应用和测试目标、`build/PrivacyQA-Diary10M`、`com.areachain.privacy-qa`、本地临时签名、生产 sandbox entitlement、LSUIElement=NO；六项真实钥匙串变量全部清除，串行事件与焦点断言保持。六次命令都沿 `build/.build.lock` 单次最多900秒申请，均取得原锁，没有重建宿主、赋悬停状态、修改生产延时或排除源码。仅由 XCTest 启动 QA；内存模型、随机偏好、合成普通/敏感资料，复制始终显式注入。原 SystemPageHost 的动画事务设置保持，证据不覆盖生产动画每一帧。

**三项归属与辅助语义**：

| 遗留 | 本轮结论 | 仍须区分的边界 |
| --- | --- | --- |
| LiveDiaryComposerPreview 上下均找不到独立正文 | **测试定位错误，修正后生产呈现及进入保留通过**。原 `combine` 没有独立正文节点，改用测试已有 SyntaxViewAnchor 宿主约束与 Vision 从真实缓存文字取得几何；没有猜按钮位置或新增生产钩子。上下两处均实际显示、进入后仍有气泡正文。 | 不把文字识别当 AX 正文。合并元素仍不提供正文值；完整正文的朗读与真人 VoiceOver 未验，不提出辅助语义或隐私改动。 |
| DiarySummaryRow 的 lower=true 进入后不保持 | **真实事件/显隐生命周期缺陷**。生产行直接挂载，可见气泡越过行上边界后收到退出，随后原行退出清除标题。下部参数实际对应向上气泡，未混称“向下”。 | 精确到消费者行边界与气泡 hover 的不一致；没有通过源码 A/B 判定 SwiftUI 内部究竟在哪个修饰器裁切跟踪，不归因于复制、投影或共用计时器。 |
| diary.copy 无独立按钮，注入/反馈未验 | **测试定位错误，修正后公开命名辅助动作及注入链通过**。合并节点公开 `Copy` / `More` 自定义动作，Copy 的公开 handler 到达生产按钮接线。普通成功/失败、敏感参数、反馈/复位及候选装饰身份已验证。 | 没有默认系统剪贴板证据；辅助动作执行成功不等于复制 Bool 成功。更多关闭另为原生开菜单/Escape与原菜单动作派发，不冒充真人选项点击。 |

合并节点在未悬停时为 `AXStaticText`，value=`diary.preview.card`、无 label/独立正文/普通或自定义动作；悬停后为 `AXButton`，label=`diary.preview.card`、identifier=`ellipsis`、没有正文 value。旧式 `accessibilityActionNames` 仍为空，但公开 `accessibilityCustomActions` 提供本地化 Copy/More。首次取样只对声明遵循 NSAccessibilityProtocol 的对象读取 customActions，漏掉 SwiftUI AccessibilityNode；修正为按公开 selector 读取后确认动作存在。不能据旧动作列表为空判定不可访问。原生子视图遍历还能读到更多菜单 cell（AXMenuButton、AXPress）及宿主 AXShowMenu，但这些内部子视图不是合并元素的独立正文。

**几何与单变量路径**：窗口坐标为 AppKit 左下原点；屏幕坐标用 `window.convertToScreen` / `convertPoint(toScreen:)`，CG 指针按主屏高度翻转。SwiftUI `.global` 是宿主布局坐标，不能直接当 AppKit 屏幕纵坐标；`RowBubblePlacement` 的 `y > 260` 选择方向，实际方向再由缓存/AX几何验证。取样的57pt手记卡上部为 `(32,451,316,57)`、下部为 `(32,151,316,57)`；操作区既有48×22，复制原生焦点矩形22×22，更多AX cell为22×16。预览完整卡片缓存与这些宿主几何一致，实际桌面画面也显示标题、复制与更多。

固定下部普通手记（380×540内容、316行宽、32 padding、300 Spacer）：窗口原点屏幕 `(0,89)`，标题窗口 `(40,185,216,16)`、屏幕 `(40,274,216,16)`，行窗口 `(32,151,316,57)`。气泡实绘背景为 `(40,191,216,53)`，相对标题下边缘上移6pt、与原标题重叠10pt；正文AX约 `(64.51,196.50,177.56,42.01)`，位于标题上方，证明向上展开。背景界线由原缓存像素与生产 padding 交叉核对，不把正文AX矩形冒充全部气泡。

原路径从标题中心 `(148,193)` 到气泡正文中心约 `(153.29,217.51)`：标题停留时 `row/title/bubble=true/true/true`，说明已收到真实气泡进入状态；移动后立即 `true/true/false`，约84–85ms后 `false/false/false`，正文节点由2降到1，缓存气泡也消失。不是初始未绘制、未进入过、坐标翻转或在状态赋值后制造成功。

单变量对照保持同一窗口/行/气泡/横坐标，只将指针从 `(153.29,207)` 移到 `(153.29,209)`，屏幕分别约 `(153.29,296)` 和 `(153.29,298)`；两点均在取样的气泡正文内，分别距行上边界内/外1pt。内侧保留2个正文节点及三项true；外侧 bubble立即false，约85ms后row/title清除、剩1节点。5ms请求间隔只用于状态取样，不代表系统精度。`DiarySummaryRow+Bubbles` 的气泡 onHover 是该标志的写入点，`BoardRowChrome.handleRowHover(false)` 原80ms任务在气泡未持有时清标题，与记录吻合；100ms标题退出任务还会被该行任务取消。原始 SwiftUI 标题退出、行退出两个回调的同步先后没有公开注入入口，不能由异步状态反推其严格顺序；已证实的序列是气泡退出先于行/标题状态清除，不是“先移除再漏收进入”。

上部手记行有限对照：标题 `(40,485,216,16)`，气泡实绘 `(40,426,216,53)`，向下，原中心路径保留。任务预览上下场景都实测向下，正文AX分别约 `(86.5,428.5,213,42)` / `(86.5,128.5,213,42)`，原路径均保留；不将这些对照或直接气泡组件通过替代下部手记行。

**复制、投影与反馈**：桌面工具在 XCTest 已启动的确切 QA 路径上取得真实窗口截图，再按可见复制图标点击两次，普通成功/失败各收到一次正确合成标题＋false标志；没有按合并元素中心猜按钮。第三个敏感桌面步骤未在60秒限时完成，原测试明确超时，未重试这条桌面路径。后续自动检查只选择实际枚举出的命名 Copy，调用 `NSAccessibilityCustomAction.handler`，不直接调用 onCopy 或任意 selector。三场景回调计数严格1/2/3；普通参数为原解析标题、不含备注，敏感参数仅为 `Private note · hidden` 且标志true；中英文原敏感测试各自仅1次、对应本地化隐藏标题。显示和AX未暴露原合成标题/备注。此轮没有改变、扩展或宣称完整验收敏感判定矩阵。

公开动作返回true在三场景一致；注入复制Bool分别true/false/true。成功出现勾选与 Copied，失败不出现成功反馈；false→true→false候选装饰切换中缓存反馈、回调次数和同一锚点/onAppear=1保持，等待原1200ms周期后无Copied。双语敏感缓存分别可见 Copied / 已复制。旧“必须AX出现Copied”假设也不成立，改为分别记录合并语义和缓存反馈。中文OCR曾因英文语言优先漏字；对同一已存PNG的离线语言顺序对照证实实际已绘制，再按场景语言修正测试并重验。普通转敏感是新的合成场景，末次重验先自然移出/进入卡片，才读取悬停动作；此前静止指针切场景的动作缺失保留失败，不声称内容切换可自动保持悬停。候选装饰切换内部没有补悬停。

更多菜单用既有 MenuButtonTestSupport 从实际原生菜单cell几何打开，原生Escape结束追踪，onClose仍0；对取得的原菜单按已验证标题/启用状态派发Close后onClose=1、copies仍3。该项分别证明原生开关菜单和程序化原菜单接线，不是默认复制路径或真实系统剪贴板验收。

**实际运行与版本**（所有结果、日志、基线摘要和缓存归入原build产物目录 `build/Diary10M`，不新增报告体系）：

| 结果包 | 真实结果 |
| --- | --- |
| diagnostic.xcresult | 完整编译成功，但初次方法过滤漏参数，0测试，不能算验证。 |
| probe.xcresult | 2方法/8次：5通过、3失败，复现原两个预览AX定位失败及下部手记行保留失败。 |
| focused.xcresult | 3方法/9次：7通过、2失败。绘制几何定位后的两预览通过；剩下部行失败与桌面敏感阶段超时。桌面普通2次点击单独保留有效证据。 |
| verification.xcresult | 8方法/17次：15通过、2失败。命名动作普通/敏感三场景、菜单、身份、原备注与条件对照通过；失败为下部行及中文反馈OCR漏字。 |
| final.xcresult | 2方法/3次：2通过、1失败。语言修正后的中英文敏感原用例均通过；普通转敏感未重新进入时动作读取失败。 |
| copy-reentry.xcresult | 最终仅重验受影响的普通/敏感三场景1方法/1次，全部通过；没有扩大矩阵或重跑下部已知失败直到消失。 |

各包均0跳过/Expected Failure。最终相关证据按场景去重为8方法/17次中的16通过、1个下部手记行已知失败；不是将跨版本累计次数相加。最后修改仅影响命名动作测试的场景准备与反馈识别，行保留用例原失败断言未删除、未标预期失败；最终行版本的验证来自verification。严格SwiftLint（三文件）、`python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile static --format json`、工作区及暂存差异检查通过；静态门禁含228项脚本回归。编译仍有原AX弃用等警告，未另做Debug发行验签、全量应用测试或低版本系统检查。

**保护范围与证据层级**：起点记录全部生产/测试内容及暂存条目/二进制差异摘要；本轮七个直接生产文件（两预览、DiarySummaryRow及Bubbles、BoardRowChrome、BoardRowPointer、DaybookRowBubbles）终值均与起点相同。预览SHA-256为 `023bbb9ed1a5dba4184362cd5b0e22168b00174fb3c7f4f4ee8659a519e58c64`，手记行为 `6af32f7eb200fc53e776749e64a1412830aa42ac33a68edee9f71f88ae2a74c7`。期间 TaskTitleCommandPreviewReader、TaskCreateTagCatalogReader 与两个 TaskTitle 测试出现并发变化，本轮未编辑或回退，不宣称整个生产目录未变。暂存摘要保持；去掉本节后的工程记录与起点摘要一致。

程序化只读chrome、应用内合成NSEvent hover/menu、公开AX自定义动作、原菜单动作派发、缓存图/文字识别和桌面系统截图/点击各自记录。真实画面只取得当次预览及任务对照，手记行边界结论来自合成事件、状态与缓存；真人hover/VoiceOver、系统剪贴板、精确SwiftUI内部回调顺序仍未证明。K的平台边界、L的原生长按能力缺口、指定Cursor verifier及其余历史未验项分别保留；当前无指定工具，不替代、不认证。

**唯一最小建议**：下一小阶段仅修复 `DiarySummaryRow` 向上标题气泡越过行上边界后的hover保留。最小候选范围限定 [DiarySummaryRow](../AreaChain/Features/Diary/DiarySummaryRow.swift) 的祖先contentShape/onHover与标题overlay承载，以及必要时其 [Bubbles扩展](../AreaChain/Features/Diary/DiarySummaryRow+Bubbles.swift) 的装配；只让已绘制气泡接收正确的进入/退出。先验证具体修饰器责任，再选择不扩大点击形状的最小调整；不改BoardRowChrome延时、RowTitleBubble点击/光标、定位方向、敏感投影或复制接线。必须让本轮下部消费者原失败与1pt边界回归通过，并保持上部行/两预览有限对照、敏感/⌘禁显、退出清理、焦点与复制不多触发。当前没有证据需要辅助树或复制边界修复；若方案涉及这些边界，留主对话单独确认。本轮到此停止，不实施生产修复，不提交、推送、安装、发布或操作真实资料。

## 第十阶段 L：Stepper 长按重复有效性核验

2026-10-08续验准备见[原O/P的K/L平台记录](#剩余平台验收kl与关键可访问性2026-10-08)：本轮使用500、20…999、10，不沿用下文旧建议的0…1000；合成记录器回归及部分原生动作已取得；可靠释放和完整真实按压基线未成立，历史缺口不关闭。

2026-10-06。结果 **3：原生持续按压基线无法建立，长按等价验收 blocked**。本轮完成工具能力与源码诊断，只追加本记录，不修改生产 Stepper 或测试；第三阶段 F 的长按缺口不能关闭，也没有足够证据判定新增产品缺陷。

**范围与身份**：读取 DaybookStepper、DaybookStepperKeyboard、DaybookStepperInteractionTests、DaybookStepperBaselineTests（含 StepperNativeTestSupport / StepperEventTrace）及[第三阶段 F 补验](#第三阶段-f-补验stepper-重复触发与取消契约2026-10-01)。源码基于 HEAD `dba0982362f389c28b468e2d03420bfbe126d7d1` 加现有工作区/暂存修改；本轮开始已有多个其他任务的修改，不能把 HEAD 当全部被检源码。记录前保留暂存条目、暂存二进制差异及生产/测试目录内容 SHA-256 摘要。生产 Stepper 两文件摘要分别为 `117466996c546bcde54b381f7c964108fa7f581118b0969cfcc3f9b54bd77093` 与 `d10664a6d6df786c7990dd0cfcc56bcaa7c8086626f09ad2a59f42e6df36348c`。不展开剪贴板业务，也不挂真实消费者。

**能力门槛与停止原因**：本会话实际调用 `cua.getState()` 获取桌面工具文档与应用清单，没有选择或启动应用、投递输入。公开的原生 Target API 为 `click(target, {mouseButton, clickCount})`、`drag(from, to)` 等；没有持续按下/独立释放接口，没有 hold 时长参数、异常兜底释放契约或实际 down/up 时间回执。等待 API 本身不能把 click 变成持续按住；drag 也不能提供本任务所需的静止按压时长与可靠释放证明。因此“向明确 QA 窗口持续按住、保持真实间隔、可靠释放”的组合门槛未满足。清单中的 PrivacyQA 标识 `com.areachain.privacy-qa` 为未运行，没有确认可操作目标窗口；不据此猜测桌面锁定状态。浏览器清单另报 `unsupported Codex auth method: apikey`，它不是原生长按失败的证据，不尝试认证或改配置。没有改用系统事件注入、辅助功能权限或全局重复设置绕过能力缺口。

**与旧方法的区别**：这次先检查输入能力，未运行旧合成对照。原 `perform` 用 Timer 在 common / eventTracking 队列现场创建 NSEvent，再经 `NSApp.postEvent` 投递；真实经过时间不等于系统鼠标持续按下。`StepperEventTrace` 的 `down/up` 是投递前标记，`received-*` 是本地事件监视器采样，`write` 是 Binding setter 记录，均不能直接冒充系统实际按下/释放及裸 NSStepper 的逐次 action。`syntheticHoldComparison` 已明确打印 `F_REPEAT_UNRESOLVED`，只检查首写、方向/步长和合成释放边界。旧基线还是 SwiftUI Stepper 的原生桥接，不是本轮要求的先单挂裸 NSStepper；内部方向范围不能误作业务范围。

**原生配置与时间证据分层**：现有 `StepperNativeTestSupport.point` 只读取 `isContinuous`、`autorepeat` 和 `getPeriodicDelay`，没有为匹配公共组件而修改节奏。第三阶段 F 记录 continuous/autorepeat=true、delay=0.5s、interval=0.1s；这些是历史配置读数，不能当成本轮运行读数或实际重复频率。本轮未挂原生控件，未产生有效按压试次；action 次数、实际 down/up、首次 action、自动重复起点、逐次间隔和释放后观察序列全部为**未采集**，不能写作“原生 0 次”或“无迟到写入通过”。

| 证据类别 | 本轮实际执行及可用结论 |
| --- | --- |
| 原生系统/桌面工具持续按压 | 仅核对公开能力；0 个有效试次，时间序列未取得，基线未成立。 |
| 应用内合成事件 | 本轮未重跑。历史 1.2s 中原生 1 次／公共 11 次；原生首写约 1ms、公共首写数 ms、首次重复约 0.48s、后续约 0.076s，均仅转述原记录，不补造逐点数据。旧 pressedMouseButtons=0，不能证明系统长按等价或产品不等价。 |
| 程序化辅助调整 | 本轮未调用 AX 增减、setter 或 action 来造重复；这种证据即便存在也只证明相应调用路径。 |
| 键盘重复 | 现有 `key(...repeatKey: true)` 构造 `isARepeat` 事件；本轮未重跑，不是系统键盘节奏，也不能替代鼠标长按。 |
| 真人操作 | 未执行、无证据；不能把桌面清单或历史缓存绘制当真人验证。 |

**生产与边界判断**：公共鼠标路径仍为 DragGesture 首写、消费首次 Button 触发、平台 `buttonRepeatBehavior(.enabled)`；键盘仍由 NSStepper 桥接，未改首次触发、重复或取消语义。`adjust` 的 attachment 防线、窗口拆离同步失效及 dismantle 清理原样保留。本轮没有证明公共重复缺陷，不提出生产修复。由于持续按压门槛失败，增/减对照、第二时长、接近上下限、按住中禁用、释放、移出/重入和卸载后迟到写入均未进入本轮系统验证；历史合成回归仍保留其原有证据层级。没有设置或放宽任何时间容差。

**唯一后续建议**：在具备可靠释放与时间记录的人工/平台条件下，沿原完整正常 PrivacyQA、独立标识/目录、合成 Binding、串行焦点测试及同一 `build/.build.lock` 的 900 秒有界等待，先只挂裸 NSStepper；预先固定中间值 500、范围 0...1000、步长 10、增加方向、按住 1.2 秒、2 个试次，读取默认配置并记录窗口身份/实际按钮位置、实际 down/up 与每次 action 的单调时间和值，确认确实自动重复且释放后停止后，才另行推进同输入路径/宿主/焦点条件的公共对照。这里的次数和时长仅为后续固定预算，不是本轮执行结果；若仍无自动重复就停止，不追加试次直到结果相同。

**隔离与验证**：本轮在能力门槛处停止，没有启动 QA/日用应用或申请构建锁，因此 900 秒等待、正常目标编译与串行窗口运行均未执行；不是改用另一把锁。未增加 Swift 测试，不重跑明知无法建立基线的 syntheticHoldComparison，SwiftLint、定向 Swift 测试和应用构建不适用于本次仅记录修改。`python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile static --format json`（227 项脚本测试）及 `git diff --check` / `git diff --cached --check` 均通过。最终生产/测试目录内容、暂存条目及暂存差异摘要与本轮开始一致；移除本节后的工程记录摘要也与编辑前相同，保留了既有及并发修改。静态检查不证明长按通过。指定 Cursor verifier、真人辅助功能及其他历史缺口分别保留，不替代、不宣称通过。未操作真实数据、系统剪贴板、偏好、权限或签名；不提交、推送、安装、发布，记录完成后停止。

## 第十阶段 K：密码确认字段同值重试残留诊断

2026-10-08真人续验见[原O/P的K/L平台记录](#剩余平台验收kl与关键可访问性2026-10-08)：双字段、8位ASCII合成材料的具体逐字与自愿同值粘贴路径均未复现稳定隐藏符残留；逐字长观察段有失焦，同父窗取消重开尚缺有效人工证据，不能泛化。与下文Unicode历史样本分开，历史API残留保留。

2026-10-06，本轮仅补测试与本记录，未修改生产安全流程。直接使用 `PrivacyPasswordSheet`、原 `PasswordSheetProbe` / `PrivacyButtonSheetHost` 和可控制的合成异步 action；`DaybookSecureField` 与裸 `SecureField` 的局部绑定对照另列，不能替代生产 sheet。第七阶段 B 的失败、已知问题标记及不同值通过记录全部保留。

**范围与身份**：启动时工作区已有大量前期及并发差异，逐文件记录全部生产 Swift 摘要和暂存差异摘要；本轮未暂存。两处生产输入链 SHA-256 分别为 `PrivacyPasswordSheet=c940dd00ed715152e85b0826c48404442acd64e0c45ce61a3036ebc47d3dca4b`、`DaybookSecureField=cc9cd61edf726fdd49f303b455c2d80333fdc19d0078e60e79de8d0bd0327185`。只增加 [诊断矩阵](../AreaChainTests/Features/PasswordRetryDiagnosticTests.swift)、[分层取样与局部绑定探针](../AreaChainTests/Features/PasswordRetryDiagnostics.swift)，在原 [测试支持](../AreaChainTests/Features/SecureInputTestSupport.swift) 增加 action 入口观察和另一合成输入的布尔核对。原 `Secure.enter/fill`、原同值用例及所有生产源码不改。

**隔离与次数**：macOS 26.6.2（25G83）arm64、Xcode 26.6（17F113），完整正常 PrivacyQA 目标，`build/PrivacyQA-SecureInput10K`、`com.areachain.privacy-qa`、临时签名、生产 sandbox entitlement、LSUIElement=NO；只由 XCTest 启动。沿 `build/.build.lock` 单次900秒有界等待，四个运行均正常取得原锁，清除全部六项真实钥匙串授权变量，测试串行、焦点门禁不跳过。固定预算先为原同值用例两配置各3轮，再为生产矩阵24场景及局部对照4场景；观察器问题修正后追加一次完整复核及原定向回归。最后发现Return已经清除残留，只增加预先限定的两个无Return取消场景，不因结果失败再反复重跑。

| 运行包（均在 build） | 实际结果与归属 |
| --- | --- |
| SecureInput10K-baseline.xcresult | 原用例两双字段配置各3/3复现，共6次 Expected Failure；字段长度均为 `[0,15]`、编辑器为 `[-1,15]`，0正常通过、0环境失败、0跳过。退出0不能代表清空通过。 |
| SecureInput10K-diagnostic.xcresult | 2方法/28场景：20正常通过、4 Expected Failure、4失败、0跳过。双字段API同值6/6残留；其中2场景另有选区测试假设失败。单字段API同值2/2残留并有同一选区假设失败。键盘同值8/8未复现；双字段不同值/无busy输入的API和键盘共8场景未复现；局部4场景只作诊断记录通过。 |
| SecureInput10K-verification.xcresult | 修正观察器后6方法/40场景：30正常通过、8 Expected Failure、2失败、0环境失败/跳过。矩阵仍为双字段API同值6/6、单字段2/2残留；键盘同值8/8、双字段不同值/无busy输入8/8未复现。两失败只剩单字段残留原断言，选区/按钮假设错误已消除。原 busyFailureRetryAndParentClose 四配置、returnPathsAndIdleCancel 四配置及 externalUpdateEchoComparedWithNative 两配置通过；原同值两配置仍是已知失败。 |
| SecureInput10K-cancel.xcresult | 最终只调整r3取消分支顺序并定向复核2场景：均先确认稳定残留，再直接取消、重开为空、action仍为2；2 Expected Failure来自保留的清空断言，0新增失败/环境失败/跳过。不是把重开为空算作原字段自然恢复。 |

三轮诊断与一次取消补证合计76次测试执行，属于不同源版本及重复场景，不能写成76个独立需求通过。最终有效复核40+2次为30正常通过、10已知问题、2单字段残留失败。原标记保留间歇属性，但本次限定同值API重复中每次均复现，未发生环境失败。

**阶段证据**：`SecureK` 日志只输出阶段、局部身份编号、布尔、次数及必要长度；不输出输入正文，不读取安全字段的明文 AX value。初次输入完成、第一次 submit 的同步返回/下一主队列/180ms/再等待600ms、busy输入、失败返回、同值重填、第二次 submit 的上述阶段及成功后分别记录。两字段身份持续为1和3，共用的活跃 fieldEditor 为2；切换编辑字段会改变 currentEditor 归属，没有重建控件。所有矩阵阶段 key=true、marked=false。首提交通常同步返回仍可读旧原生值，到下一轮/action入口已空，说明同步 getter 不能作为私有 State 的同步探针。

第二次提交后，同值API的活跃末字段在下一轮、180ms及稳定阶段仍长15、等于合成样本，editor亦长15；双字段为确认字段，单字段为自身。成功返回后仍可观察到残留。图像 `build/SecureInput10K-visuals/diagnostic` 中双字段及单字段API残留为遮蔽圆点，键盘对照为占位符。它们是 `cacheDisplay` 原生缓存绘制，不证明系统合成器或真人看到的实际窗口；不能称纯像素残影，也不称数据泄露。

**宿主与绑定边界**：生产私有 `password/repeated/busy` 未被安全直接读取。源码先捕获 input，再清两字段，最后启动 Task；原生 getter、按钮及 action 只提供间接证据，不能把按钮禁用写成 repeated 已空。独立局部探针能直接记录自己的绑定：API整串同值插入明确触发 same=true 的 setter（不是完全没有 Binding 更新）；随后绑定两值已空，原生末字段/editor仍长15，裸与公共 SecureField 都复现。键盘逐字对照没有这一残留。局部宿主不是生产 State，不能把这层直接证据移植为生产私有状态已经证明。

**测试自身与实际影响**：API分支保留原点击/全量 `insertText`/180ms等待；逐字符键盘分支走原生选择及合成 NSEvent，每字符使用原180ms等待，不触碰剪贴板或强制失焦。提交鼠标序列与原 `Native.click` 相同，观察器增加下一主队列取样及稳定等待，没有增加提交、赋空、强刷或重建。残留是在任何后续Return、点击、删除及重开之前判定。action前两次均准确接收原样本；每轮矩阵22个后续输入场景准确接收另一合成样本；无额外action，全部重开为空。首轮新增观察器的 `accessibilityEnabled` 误用对象返回的 selector helper，导致记录全false，按钮结论全部作废；已改回原支持使用的KVC并校验读取有效及初次/重填为enabled。首轮“选择长度必大于0”也不成立，已保留失败并改为分开记录Return后、点击、选择、删除，选区只与当前editor的UTF-16长度比较。

修正后证据：busy时Save/Cancel禁用、失败后恢复，重试清错误，成功后Save禁用而Cancel可用。成功后Return不增加action，却使仍有残留的字段及同一editor归零；随后选择长度本来就是0，不能归功于Delete。Return后的仅主字段输入仍禁用Save，这只证明该时点的guard，不能反推之前repeated为空。原r3在Return后才取消，因此最后把这个分支移到Return之前；仅定向重跑 `cancelResidualWithoutReturn(configuration:)` 两配置，日志从仍长15的 `7-success` 直接进入为空的 `9-reopened`，没有 `7-after-return`，关闭一次且不新增action。原四配置父回调关闭、取消/Return语义的定向回归同样保留。没有证据表明旧值错误提交。

**判断与唯一建议**：已定位到“同值整串替换相关的原生同步边界”，不能认定公共外壳装配问题或纯测试误报。合成键盘与API对照同时改变入口、中间值和等待次数；不能把未复现扩写为真人输入已修复。唯一剩余取证建议：在现有局部绑定探针中固定 `insertText` 入口、实例、宿主清空和总等待策略，只比较整串同值覆盖与逐字符替换，以分离输入粒度与事件入口；此后再由主对话决定是否需生产修复。本轮不提出重建控件、禁用busy输入、改清空顺序或改安全状态所有权。

独立只读复核检查了实际测试、直接生产链及逐轮日志，确认没有在残留取样前清空，也指出上述输入粒度与取样扰动限制；它不是历史指定 Cursor verifier 的替代。本轮未改公共生产契约，不宣称历史复核缺口已补齐。真实认证、密码修改、备份/恢复、文件面板、系统剪贴板、系统权限、真人输入法/键盘、系统合成器、安装、发布及全量应用测试均未执行。

**验证与交付状态**：实际命令沿架构PrivacyQA参数，仅变更derivedData/resultBundle路径和上述 `-only-testing`，baseline另用 `-test-iterations 3`；没有排除正常目标源码。最终三文件严格SwiftLint、`python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile static --format json`（含227项脚本回归）、差异检查均通过。完整编译保留原AX弃用等警告；新增场景列表的actor隔离警告已消除。最终复核全部生产Swift内容与启动摘要一致，暂存差异摘要一致；只编辑上述三个测试文件和本工程记录。四个运行的合成输入日志检查未发现样本正文。取证交付结束，缺陷未修复、归因仍保留上述唯一控制变量缺口；不把诊断失败改成通过，不继续生产实现、提交、推送、安装或发布。

### K 补验：安全输入替换事务控制变量对照

2026-10-06。承接上节唯一控制变量缺口；上节的历史复现、混合入口限制和失败不删除。本轮只增补原三个测试文件及本记录，没有修改生产安全输入、密码清空或认证。沿 `PasswordBindingProbe` / `PasswordBindingContent` 增加单字段模式和局部合成 action 阶段；它不调用认证，也不读取或证明生产私有 State。原两字段/键盘矩阵不重跑，原 `Secure.enter/fill` 和生产同值用例原样保留。

**固定控制变量**：裸 `SecureField` 与 `DaybookSecureField` 分别建立干净单字段夹具，各条件预定3轮；一轮从准备到残留判定始终同一窗口、字段、editor，无重新点击、Return、Delete、pasteboard、直接设置原生 stringValue 或失焦。统一使用原合成样本（15个扩展字素、17个UTF-16单元），初次整串输入 → 宿主第一次清空/局部 action 等待 → busy整串输入 → 失败完成 → 对照重填 → 宿主第二次清空/局部 action 等待。成功完成只在结果之后，释放夹具不计为恢复。

| 条件 | 同一公开 insertText 入口中的操作 | 重试调用/不同中间全文数 | 公共组件：观测/清空通过 | 裸字段：观测/清空通过 |
| --- | --- | --- | --- | --- |
| A | 整串同值覆盖原整段 | 1 / 0 | 3 / 0 | 3 / 0 |
| B | 顺序按完整字素原位替换相同字符 | 15 / 0 | 3 / 0 | 3 / 0 |
| C | 首字替换整段，随后尾部追加其余字素 | 15 / 14 | 3 / 3 | 3 / 3 |

A/B结果相同后才通过独立 `-only-testing` 执行预定C，没有按失败追加次数。C的条件运行由本次命令选择保证，不是测试方法自身的自动分支门禁。`characterRanges` 使用 String 字素边界转换为 NSRange，原样本范围回转/连续/完整覆盖测试通过；不扩展字符材料。各轮重试前选区统一为整段，重试后均为 `{17,0}`。各组替换在同一个主线程操作段内完成，没有逐字180ms；每业务段只取同步、下一主队列、再等待180ms、再等待600ms四点，不强制布局或轮询到空。到结果均27次观测，缓存绘制后另读一次，不参与清空判定。

**实际计数与时序**：A重试的两类原生通知（字段/editor）各增加1，B/C各增加15；A/B的 Binding setter 增量都是0，C公共组件为15次异值写入，裸字段为15次异值及15次同值写入。两种承载的最终行为一致，setter节奏并非完全相同。本轮没有再次点击或切换字段，所以这项0写入事实不能替换上节旧K中“同值setter已触发”的历史证据。A/B有原生通知并不代表一定写入 Binding。

本机 macOS 26.6.2（25G83）arm64、Xcode 26.6（17F113），同一原样本、Debug QA、已经准备好编辑器后测得：重试操作段A为0.814–2.058ms，B为6.707–8.375ms，C为7.483–8.014ms；第二次清空到稳定取样A为794.218–803.369ms，B为794.472–806.349ms，C为806.001–815.409ms。数字包含诊断开销，只描述这6次/组的有限试验，不是性能预算或精确相同时序；没有额外延长等待来获得空值。

**分层结果**：18轮均保持字段1/editor2、currentEditor存在、key/appActive/active为true、marked=false。A/B第二次宿主清空后，局部 Binding 已空，但同一原生字段/editor在下一队列、180ms及稳定点均长15且等于样本，选区仍为`{17,0}`。C已在下一队列清空，同一字段/editor到稳定点保持长0、选区`{0,0}`；清空后的两类原生通知各再增加1。所有局部合成 action 均严格为2次、两次输入正确、一次失败、两次宿主清空；不将这些计数移植为生产认证证据。

18张稳定缓存图保存在 `build/SecureInput10K-control-visuals`，逐张汇总检查显示A/B仍为遮蔽圆点，C为占位符；缓存之后的原生空值布尔不改变。它们来自 `cacheDisplay`，透明背景和系统合成器不同，不证明真人看到的窗口、内存安全擦除或明文泄露。失败不是单纯绘制残影：字段和editor的原生内容本身未空。所有日志/断言仅输出布尔、必要长度、范围、次数与局部身份，未读取安全字段明文AX value；两包runner日志及本轮输出日志检查未发现合成样本正文，图像注释只有组别/承载/轮数。

**运行与计数**：继续完整正常 PrivacyQA、`build/PrivacyQA-SecureInput10K`、`com.areachain.privacy-qa`、local临时签名、生产 sandbox entitlement、LSUIElement=NO、六项真实钥匙串授权变量清除和串行焦点测试。两次都用同一个 `build/.build.lock` 单次900秒有界等待，分别等待0秒、124.883秒后取得；没有删锁、排除源码或干预其他宿主。精确命令和日志保存在各包同名 `-command.json` / `.log`，runner输出在对应 `-diagnostics` 下。

- `build/SecureInput10K-control-AB.xcresult`：2方法/3参数执行，字素范围1项通过，A/B方法的两承载参数失败；内部12轮全部观测完成，12个失败均为保留的原生清空要求，0前置/身份/焦点失败、0已知问题、0跳过。xcodebuild退出65，不能称AB验收通过。
- `build/SecureInput10K-control-C-anchor.xcresult`：2方法/4参数执行；C两承载参数包含6轮全部清空通过。原生产同值用例两配置各1轮仍为 Expected Failure，原生长度`[0,15]`、editor长度`[-1,15]`；重试传参正确、各2次action，结果后的Return不新增action。包退出0不表示这两项清空通过。

合计局部**18次观测完成、6次清空通过、12次清空失败**；另有2次生产锚点已知失败及1次字素范围检查通过，不能把方法数、参数执行数与内部试验轮数相加称全部通过。

**解释与唯一建议：保留明确平台边界。** 单独改变替换粒度不足以消除残留。B/C等待与取样相同、重试输入段的调用及通知增量相同且操作耗时重叠，观察到的区别伴随不同中间值和异值 Binding 写入，不能仅归因于更多等待、更多调用或更多通知。重试输入段观察到 Binding 写入差异，随后宿主清空向原生缓存的同步结果不同，最终绘制与原生内容一致；这不确定平台内部差异的最早发生位置；裸与公共组件同样复现，不支持外壳特有缺陷。C同时改变首段替换/尾插范围与光标轨迹，通知的内部时序也未被精确控制；因此尚未缩小到SwiftUI/AppKit内部的唯一机制，也不能断言所有可恢复路径都必须经过异值中间态。

当前风险证据是持续的遮蔽内容/原生缓存残留，可能误导用户对字段清空的判断；本轮生产锚点没有错误重试参数或额外action证据，不是完整认证链、敏感内存或真人输入验收。现有证据不足以选择生产同步/生命周期修复，不建议以强制重建、临时改值、重新赋空或测试屏蔽代替安全设计；本轮不提出或实施生产修改，也不再扩展材料/等待大矩阵。保留原失败门禁和上述平台边界，后续生产决策须单独定界与确认。

**验证与保护**：最终三文件严格SwiftLint、工作流、静态质量门禁（含脚本回归）、工作树与暂存差异检查通过；完整正常QA编译及 `codesign --verify --deep --strict` 通过，原AX弃用警告保留。独立只读核验确认AB只有清空要求失败、C六轮通过及生产锚点已知失败计数，并指出新旧setter事实、C范围轨迹、通知统计阶段及观测计数须结合失败清单解释；它不替代历史指定Cursor verifier。全部551个生产文件最终内容与启动摘要一致。本轮未执行暂存/提交；期间外部并发提交与暂存改变了HEAD/index，当前暂存中的本轮四文件仍精确等于启动时的原文，本轮增补保持未暂存，未回退或覆盖并发状态。真实密码、认证、系统剪贴板、系统权限、真人IME、安装和发布均未操作。补验观测完成，A/B清空要求仍失败；完成后停止。

## 第十阶段 I 修复二：剪贴板搜索保真输入

2026-10-06。用户确认 mixed/exact/regex 均保留真实换行，字面反斜杠+n保持原字符，匹配器原 trim 与正则语义不变。实现只在 Browser 搜索选择 `.verbatim`，公开 NSLayoutManager 控制字符排版令编辑与非编辑均单行显示；原始字符、选区索引和撤销事务不作投影转换。默认捕获、四处普通搜索、新统一搜索、CaptureField 的 J 保护不扩修。

证据保存在 `build/ClipboardVerbatimI2`。先用最小排版样例验证 CRLF/LF/Unicode 分隔符同一行且 storage 保真，再用原 DaybookTextField 验证 String/随机命名 pasteboard、UTF-16 光标及原生撤销重做，2 方法通过。初次样例编译因公开 API 的 Swift 类型名称修正后重跑；首次失败包保留。仅这些最小门槛通过后才接入生产 Browser。

完整正常 PrivacyQA 应用/测试目标，沿 `build/PrivacyQA-SearchMultilineI` 独立目录、com.areachain.privacy-qa、local 临时签名、生产 entitlement、LSUIElement=NO、六项真实钥匙串变量清除、原 build/.build.lock 900秒单一有界等待与串行测试。所有内容为合成记录，原 ClipboardOptionsFixture 使用 pasteboard=nil 和安全 gate；onCommit 只记录合成ID。工作台与历史小窗父层参数已静态核对，未触发父层系统复制/粘贴。

首轮 consumers 为23方法，21通过、2失败（4次参数失败）：三模式重新聚焦后尚未触发 AppKit begin-editing，以及一次未等待 SwiftUI 挂载便取字段。原 SearchMultilineMode/Boundary/Undo 三套全部通过，不能把新套件失败写成全绿。准备步骤改为沿原 settle 等待挂载；重新聚焦与恢复输入分开核对，实际插入后焦点传播、撤销原文、Escape 与提交次数仍严格断言。

缓存图另发现 cell 非编辑文本与原生 editor 叠印。修复只让活跃字段由原 editor 绘制，增加活跃 cell 像素为空反例；没有替换 glyph 映射或改写正文。透明缓存图的深色空白区 alpha=8/255，不能把预览底色当作真实窗口不透明底色。非编辑文字绘制保持原外壳背景所有权。

corrected 与 glyph-minimum 批次被并发 UnifiedSearchCompositionTestSupport 的 package 级 CGRect.center 编译错误阻断，均零执行；没有修改或排除该文件。所属并发修改修正后正常重试。最终 presentation-background 包为6方法／11次参数运行通过，零失败/跳过，包含原生最小门槛和生产 Browser。覆盖 String/命名 pasteboard、富文本选区替换、CR/LF/CRLF/其他换行、Unicode/emoji/组合字素/字面反斜杠、三模式精确结果、无效/零长度正则、trim边界、Return一次ID和参数、⌘Return/Shift+Return不新增提交、焦点/失焦/重开/Escape及合成组合取消。三轮撤销重做和UTF-16光标、换行后选择/编辑、长查询末端可达均通过。双语×浅深色×380/440pt产出16张编辑/非编辑缓存图，保持高度和边界；缓存图不是窗口合成器或真人输入法证据。

最终 regression-final 包为75方法／186次运行全部通过，零失败/跳过；包含 SearchMultilineModeTests、SearchMultilineBoundaryTests、SearchMultilineUndoTests、CaptureSubmissionTests、CaptureShortcutBoundaryTests、MenuBarCaptureSubmissionTests、DaybookTextFieldTests/SearchTests、DaybookFormTextFieldTests、DaybookSecureFieldTests、UnifiedSearchInputTests，以及原 ClipboardQueryMode/Boundary/HistoryRules 测试。与最终呈现包合计81方法／197次运行；重复批次和内部循环不累加。默认捕获首行/备注、四处普通搜索逐换行标量空格、统一搜索专用分支、J的组合态两条提交保护均有本轮回归证据。

本轮11个相关Swift文件严格局部SwiftLint通过；工作流、静态质量（含227项脚本回归）、工作树/暂存差异检查通过，新文件空白单独检查。正常完整QA编译及 `codesign --verify --deep --strict` 通过；Debug构建及静态验签通过，最终追加构建结果见 `debug-final.log`。所有精确命令、失败包、最终summary/tests树、缓存图和源码摘要均在上述build目录。原锁等待后正常取得，未移除锁或干预持有者；并发工作区与暂存改动保留。**交付状态：实现及本轮自动验收通过，指定复核与人工/系统证据仍为partial。** 指定 Cursor verifier 当前不可调用，保留复核缺口，不重复认证或替换；真实系统粘贴与真人 IME 不由命名 pasteboard 和程序化组合文本代替。未提交、推送、安装、发布或修改真实数据、系统剪贴板、个人签名及权限。


## 第十阶段 J：捕获按钮组合文本提交保护

2026-10-06。最小生产改动仅 CaptureField：按钮 action 与原生回调共用 `submitDiary()`，动作时从既有 autocomplete 弱编辑器关联读取原生保护状态；关联与原始提交语义见[组件目录](component-catalog.md#第十阶段-j捕获按钮组合文本提交保护)。共享 DaybookTextField、插入/换行事务、CommandReturnButton、ShortcutStore 和 AppShortcutModifier 均未修改。

**修复前证据**：`build/CaptureStageJ-baseline.xcresult` 的精确筛选未命中（0测试），不能作通过证据。随后 `build/CaptureStageJ-reproduction.xcresult` 完整运行 SearchMultilineModeTests，7方法/32次参数运行，其中31通过、capture原有已知失败1次。原生产 CaptureField 建立 marked、外部 Binding 更新 EXTERNAL、原队列 ⌘Return 后，记录 `native=0, diary=1, todo=0`；编辑器仍为 `甲\n乙`、marked=true、UTF-16选区{3,0}，草稿EXTERNAL、编辑器身份均保留，确认按钮绕过字段保护。原失败包和 diagnostics 保留，不再扩大 withKnownIssue。

**首次修复验证**：`build/CaptureStageJ-core.xcresult` 15方法/45次运行，43通过、2失败、0已知问题/跳过。原capture已变严格通过，菜单栏四种语言/主题组合及搜索/筛选6次通过。新增测试两处前提不成立：双窗口回切时额外原生鼠标点击正常完成组词，随后一次提交合法；撤销探针只设置外部初值，未建立原生编辑会话。测试改为明确断言正常完成后的提交，以及先真实插入、确认自有编辑器关联再测试undo/redo中间态，并补原插入历史往返；未改生产修复或放宽焦点/组合保护断言。

`build/CaptureStageJ-final-core.xcresult` 随后17方法/47次运行，46通过、1失败；上述双窗口与撤销前提已严格通过，唯一失败是新增快捷键测试误期望图形回车符。产品原显示为 `⌘⇧Return`／`⌘⇧回车`；按原本地化修正测试后，`build/CaptureStageJ-regression.xcresult` 70方法/147次运行全部通过，0失败/已知问题/跳过。覆盖 CaptureShortcutBoundaryTests、CaptureOverlayLayoutTests、SearchMultilineUndoTests/BoundaryTests、DaybookTextFieldSearchTests/Tests、InputSyntaxInteractionTests、DaybookFormTextFieldTests、UnifiedSearchInputTests、MenuBarSearchShortcutTests、ShortcutCatalogTests/StoreTests、ShortcutsPageTests；仅从此次计划中排除两组大材料循环，没有降低断言或扩大已知问题。

**最终自动验收通过，原 capture 已知缺陷在当前程序化组合＋原生队列证据范围内关闭。** `build/CaptureStageJ-acceptance.xcresult` 使用最终源码运行 SearchMultilineModeTests、CaptureSubmissionTests、MenuBarCaptureSubmissionTests：15方法/45次全部通过。与最终 regression 包合计 **85方法/192次运行，0失败、0已知问题、0跳过**；不累加此前重复/失败包。

原队列外部草稿＋marked 场景严格零提交，既有已提交前缀再组词、取消/完成后一次提交、按钮AX动作、原生字段先收到等效事件、真实合成鼠标与候选Return、搜索/筛选禁用入口均通过。双窗口中第二窗口正常提交不受第一窗口组合影响，第一窗口按钮仍受自身保护；鼠标正常结束组合后恢复一次提交。输入切换清掉原关联，卸载后队列不提交，重新挂载使用新字段。真实原生插入后undo/redo中间态按钮不提交，原始插入文本/选区和撤销历史往返保持。

生产 MenuBarPopoverView 沿原保存入口、内存库及非私密合成内容，en/zh-Hans × light/dark、356/380pt：组合期间任务与手记数量不变，草稿、编辑器、组合区和选区保持；完成后仅新增一条手记、捕获草稿按原逻辑清空。搜索/筛选两种门控均未触发捕获。此处是合成原生交互证据，不声明人工视觉或真人输入法全矩阵通过。

修复一关键回归包括四普通搜索中段UTF-16选区、反复undo/redo、队列⌘Z/⌘⇧Z及普通表单对照、捕获默认/首行备注政策、补全与统一搜索专用输入。共享三文件SHA-256与I最终记录一致；本轮源码摘要和最终实际命令在 `build/CaptureStageJ-source.json`、`CaptureStageJ-regression-command.txt` 与 `CaptureStageJ-acceptance-command.txt`，最终验收后摘要无变化。正常完整QA编译完成，原锁内 `codesign --verify --deep --strict` 通过、Bundle ID为com.areachain.privacy-qa、sandbox=true；静态签名不等于安装或发布。构建仍有既有SDK/actor警告，ad-hoc模式关闭Hardened Runtime的原提示保持。

最终六个本轮Swift文件严格局部SwiftLint、static质量门禁（含226项脚本测试）、工作流及工作区/暂存区差异检查通过。指定 Cursor verifier 当前工具不可调用，保留复核缺口，不重复认证或替换机制。程序化 marked、进程内原生队列、原生字段等效、AX按钮动作与合成鼠标分别记录，不冒充桌面工具按键或真人IME；本轮未执行后两类验收。改绑/停用沿随机 UserDefaults＋fake注册的独立Store、原生字段和原快捷键测试；未通过私有shared改变生产按钮绑定，完整按钮改绑端到端保留缺口。

只经 XCTest 启动正常完整 QA 目标，使用 build/PrivacyQA、com.areachain.privacy-qa、临时签名、生产sandbox entitlement、LSUIElement=NO，六项真实钥匙串授权清除和 build/.build.lock 的900秒单一有界等待。使用内存模型、随机偏好和非私密合成文本；无真实认证、系统集成写入、剪贴板新策略、安装或发布。原暂存及并发统一搜索改动保持。

## 第十阶段 I 修复一：普通搜索换行与撤销边界

### 最终原生续验：自动回归收口（2026-10-06）

**本轮修复一的授权自动验收已完成；首版中段重做和队列重做 11 次失败均有对应最终通过证据。** 指定 Cursor verifier、真人 IME、系统粘贴仍未完成，不能据此声明全部人工/复核验收通过。捕获按钮绕过 marked 保护的原有已知问题继续单列，不在本轮修复范围；剪贴板保真新政策和新统一搜索业务未接入。

最终生产代码未追加修改，四个普通搜索与原生插入事务保持初始修复版本。队列问题最终定位为测试事件构造：仅填 characters/charactersIgnoringModifiers 的 NSEvent.keyEvent 合成方式可不派发 redo action；字符变化、菜单更新、补 keyUp、等待结果都未解决。独立原菜单 action 对照通过；随后仅通过 XCTest 启动 QA，桌面工具向该既有 QA 窗口投递 ⌘Z/⌘⇧Z，`dispatch-desktop-live` 严格文本/光标/焦点通过，收到的字段为 z/z 与 z/Z。由此避免误改生产事务或菜单。

最终 `SearchMultilineBoundaryTests.key` **只对本轮撤销/重做键**采用 CGEvent 键盘构造再转 NSEvent，仍经原 NSApp.postEvent 入队；不调用 CGEvent.postToPid 或系统投递，不要求权限。实际事件窗口和 keyCode、一次接收、修饰键及 Shift 字符字段均严格校验。其余按键构造保持，文本、查询、回调、选区和焦点断言未放宽，未清撤销历史、替换编辑器或异步补写。三轮队列回归进一步核对同一 editor/firstResponder 和 active/key。临时桌面等待用例、探针、菜单控制及替代队列实验已全部撤回；只保留原单入口门槛、普通表单对照和窄的事件构造修正。

所有最终结果、源码摘要和命令在 `build/SearchMultilineIRepair/native-final-*`；沿原 PrivacyQA 正常完整目标、独立 Bundle ID/DerivedData、临时签名、生产 sandbox entitlement、六项钥匙串变量清除和原 build/.build.lock 的单一有界等待。等待期间不编译，取得锁后才执行，失败或结束释放；未删换锁或干预持有者。原测试只使用合成数据，命名 pasteboard 随机隔离，没有使用系统剪贴板。

| 最终证据 | 实际结果 |
|---|---|
| `native-final-core.xcresult` | 4 方法/4 次通过：visible/key/active 小场景、workspace 中段、workspace 队列、普通表单队列。清理后的最终测试版本，不沿用诊断结果。 |
| `native-final-consumers.xcresult` | 六个 SearchMultiline 文件的全部测试（其中两文件是支持代码）：23 方法/120 次参数运行，118 通过、1 个原有 capture 已知问题、1 次 capture 场景取编辑器时 key-window 准备失败。所有中段/队列撤销重做、四搜索实际结果及输入材料通过。 |
| `native-final-focus-recheck.xcresult` | 原 returnWhileMarkedDoesNotSubmit 方法的 6 个消费者全部通过，严格重验前包的准备失焦；没有跳过或删除断言。前包的 1 次环境准备失败单独保留，不算产品失败。 |
| `native-final-original-regression.xcresult` | 37 方法/52 次全部通过，0 失败/跳过：DaybookTextFieldTests、DaybookTextFieldSearchTests、InputSyntaxInteractionTests、DaybookFormTextFieldTests、FormInputConsumerBaselineTests、TagFormInputConsumerTests、ClipboardFormInputTests、UnifiedSearchInputTests。 |

按最终同源码的场景去重合计 **60 方法/172 次参数运行：171 通过、1 个既有已知问题，新增产品失败 0、未关闭环境失败 0、跳过 0**。核心 4 次和组合文本重验的重复 5 次不累加。材料循环另计：7 消费者×2 导入路径×17 材料=238，6 消费者×17 撤销材料=102，生产导入对照 10，剪贴板模式对照 12，共 362 次；另有非材料往返 66 轮（原参数与单入口门槛），静态捕获材料对照 7 次，不混算测试参数运行数。捕获默认首行/备注规则、剪贴板当前模式与普通表单保持原语义。

最终四包的全部生产/测试 Swift 摘要与 `native-final-source.json` 一致；DaybookTextField=`8787c3ae18c6decdece5529c6ab4d47cadd10a4d63cbf25cd4b7fe9705cd95b1`、DaybookTextEditing=`46d7b3924bbbbe912a43c2efa4d897bcd4aa390e29bd8ec97b1ace54c6a1e9fc`、DaybookNativeTextInput=`06ee2e626d06574a3e889001752ac6b8ca06deed6c08fa4c08c73a9ec84a151d`。完整正常测试目标已编译，QA `codesign --verify --deep --strict` 通过；15 个相关 Swift 文件严格 SwiftLint、静态质量、工作流与差异检查通过。无新增生产修改，不重复生产构建/安装。并发暂存变化原样保留，本任务没有执行暂存、提交、推送、安装或发布。

过程失败不抹除：历史锁屏 52 次、此前零运行、先前菜单路由诊断失败分别见下文。此次 dispatch-trace/submenu-update 仍复现队列问题；菜单控制与 delegate 诊断曾遇两次并发新统一搜索编译阻断，外部修正后同轮继续。dispatch-delegate-ready 的原菜单直接动作通过、队列失败；dispatch-wait-result 仍失败；dispatch-process-fields 证实 QA 沙盒内系统投递未收到事件。两次桌面对照未在时间窗内获得外部按键，均保留为外部驱动未就绪，最终 desktop-live 才实际通过。上述诊断或准备失败都不混入最终有效回归；底层合成事件工厂的具体私有实现差异未推测为产品事实。

交接时并发方又新增/修改新统一搜索业务文件，差异另存 `native-handoff-source-changes.json`；本轮 Daybook 输入实现与直接测试未再变化，以上验收绑定 `native-final-source.json`，不冒充后续并发业务快照的全仓验收，也不追改其实现。

本轮到此停止。指定 Cursor verifier 当前不可调用，未认证或替换机制；独立只读探索只提供定位线索。真人 IME、系统粘贴和生产真实数据仍未验，剪贴板新策略不实施，原 capture 已知按钮问题不扩修。

以下为初始修复及前期续验历史；其中 partial 和待验结论已由上节最终证据更新，历史失败仍保留。

2026-10-05，实施范围限于原 DaybookTextField、SyntaxTextField、小型 DaybookTextEditing 支持及四个普通搜索显式选策。通知只同步原生值，禁止在 marked/undo/redo 中间态改写文本；提交转换走原生编辑事务，外部同步不登记撤销。政策与消费者契约见[组件目录](component-catalog.md#第十阶段-i-修复一普通搜索换行与撤销边界)。下节 I 诊断是修复前历史，不能作为修复后验收结论；冻结的残留特征保留，生产测试只要求严格恢复。

本轮验证记录位于 `build/SearchMultilineIRepair`，沿原完整正常 PrivacyQA、独立目录/QA 标识、本地临时签名、生产 entitlement、六项真实钥匙串变量清除及 `build/.build.lock` 非等待串行互斥。只经 XCTest 启动合成窗口、内存模型、隔离历史与偏好；命名 pasteboard 使用随机名称，不访问 general。最小修复前重跑先遇到并发统一搜索缺失类型，再遇到该并发实现的编译错误；源码补齐后的申请遇锁忙，未排除或修改并发源码。因此本轮未取得修改前的新成功运行，根因沿原 I 诊断包和当前源码核对：直接导入为空格，撤销中间态才注入分隔符。

| 证据 | 实际结果与限制 |
|---|---|
| `repair-minimal.xcresult` | 首版仅移除通知转换并接提交政策，5方法/44参数，33通过、11失败、0跳过。五搜索及捕获/表单的空字段导入撤销、材料往返与撤销后输入已无残留；失败为六个普通字段中段重做光标落到全文末尾，以及五个队列重做未触发。没有焦点失败。此包不是最终实现的通过声明。 |
| 最小事务修正 | 普通字段增加固定 cell/editor，单行已提交 payload 与纯文本命名导入提前转换后只调用一次原生 insertText；保留原 UndoManager。选区/重做不靠异步补写、清空历史或丢焦。队列 helper 按 Shift 生成大写 characters，保留 charactersIgnoringModifiers。 |
| `native-transaction.xcresult` | 完整正常目标编译通过，6方法/52参数均在场景准备失败：foreground=com.apple.loginwindow、active=false、key=false，未进入产品断言。未放宽焦点要求；已请求解锁，后续只读系统状态仍为 screenIsLocked=true，没有循环重跑原生用例。光标修正和队列重做尚未有效运行验证。 |
| `nonfocus-contracts.xcresult` | 最终源码完整正常 QA 编译，14方法/14次通过、0失败/跳过：明确政策与 FocusState 兼容、默认捕获、原生 payload 的 Unicode/字符属性、多行开关、冻结旧残留特征及原 SyntaxAutocompleteTests。无焦点单元测试不替代生产窗口验收。 |
| 最终本地门禁 | 15个本轮相关 Swift 文件严格局部 SwiftLint、工作流与差异检查通过；static profile 含226项脚本回归通过，安全静态扫描无高风险或敏感日志候选。Debug 构建及原 development 静态验签通过，staticSignatureVerified=true、hardenedRuntime=true、distributionReady=false；QA 包另经 codesign --verify --deep --strict 通过。保留既有 SDK/actor 警告。 |

**交接状态为 partial**：最终四个生产搜索的列表、外部同步与 Return/⌘Return、UTF-16 选区、反复撤销/重做、合成组合通知、候选接受和剪贴板撤销的定向用例已补齐，但被锁屏阻断的最终原生回归尚未通过。原 DaybookTextFieldTests / DaybookTextFieldSearchTests 全套、InputSyntaxInteractionTests、表单及 UnifiedSearchInputTests 的完整最终回归仍待桌面恢复；不能沿用旧版测试或14项无焦点测试填补。解锁后先运行最小撤销/外部选区，再扩展六个 SearchMultiline 文件及这些原回归；保持同一正常目标、锁和严格焦点断言。

本轮仅在通知安全边界、显式政策、原生 payload 事务和必要测试/文档/组件守卫内修改，未改匹配器、标签创建/改名控件、普通表单、安全输入或新统一搜索业务。暂存区二进制差异与起点一致；并发统一搜索业务源码继续保留，详情见 source-before/source-tested/source-final 摘要。本轮没有执行任何 Git 暂存、提交、推送、安装、发布或真实数据操作。

指定 Cursor verifier 当前不可调用，保留必需复核缺口，不认证或替换。真人 IME、系统粘贴、真实数据/权限、安装和发布未运行；剪贴板真实换行保真政策不在本轮接入。

### I 修复一菜单路由续诊（2026-10-06）

本续轮保持原 PrivacyQA 与有界原锁，起点桌面未锁定；`route-trace`、`route-menu-target`、`route-character-control`、`route-unshifted-control`、`route-window-action`、`route-keyup` 的 queue 包均取得锁、完整编译并进入 workspace 队列门槛，6 方法运行均在严格重做结果断言失败，0 准备失败/跳过。每次三个往返，共 18 内部循环；字符对照另有四组独立合成菜单动作，不能计为产品通过。失败后均释放锁，没有扩大消费者回归。

新证据把字符匹配与动作派发分开：charactersIgnoringModifiers=Z 时原菜单拒绝；保留 Shift 大写 characters=Z、未修饰字符 z 时，原 SwiftUIMenu 和顶层 NSMenu 对 ⌘⇧Z 返回 true，但仍无文本恢复。窗口 IMP 探针确认 ⌘Z 实际进入 NSWindow.undo: 并留下 canRedo=true，而 ⌘⇧Z 没有进入 NSWindow.redo:；成对 keyDown/keyUp 对照仍失败。原 trace 读取的 enabled/target 在菜单 IMP 返回之后，不能反推匹配时的启用状态或实际派发目标。对 `NSTextView` 的方法查询可能返回祖先实现，日志标签不能当成经过该类 override 的证明。

下一项已收窄为同一次事件中 `NSApplication.sendAction(_:to:from:)` 的 selector/target/sender/返回，以及原菜单调用前后候选项状态；不应再推断插入事务损坏、菜单未到达或改用直接 UndoManager。独立只读探索核对了原始日志并指出上述证据限制；它不是指定 Cursor verifier，也不填补该复核缺口。

准备运行 `route-send-action` 时桌面重新锁定：执行前检测为 LOCKED，立即释放锁，未启动 xcodebuild，单列 1 次执行前桌面阻断（无结果包）。已请求用户解锁；等待期间未重复启动测试、修改系统设置或持锁等待。全部临时探针、字符和 keyUp 实验已恢复到本续轮起点，诊断差异与原日志留在 `build/SearchMultilineIRepair/route-*`；没有留下新的生产/测试实现。仅本记录新增，静态质量、工作流与差异检查通过。上一节最终受测源码身份和 partial 状态仍有效，历史 52 次、首版待关闭项及此前零运行不混算；当前需解锁后继续菜单 action 派发诊断，完成之前不扩大业务或消费者验收。

### I 修复一有界等待续验（2026-10-06）

**已取得锁并进入产品断言；最终工作台中段重做通过，队列重做未通过，自动验收仍为 partial。** 沿 scripts/build.sh 的同文件 flock 非阻塞尝试与 0.5 秒间隔、最多 900 秒等待；始终单一等待者，持锁后才写 PID 和启动原 PrivacyQA，结束/失败清理自己内容并释放。各批次实际均立即取得锁（0.0 秒），无等待超时；未删换锁、嵌套取锁或干预其他进程。完整正常目标、原 QA Bundle ID / DerivedData、临时签名、生产 sandbox entitlement、六项钥匙串变量清除及串行条件不变。

本轮生产零修改。SearchMultilineUndoTests 新增两个单入口门槛，直接调用原最终回归体，并增加普通表单队列对照；不改原断言，撤销后额外严格要求 canRedo。SearchMultilineBoundaryTests 只修正已核实的字符字段：未投递的原生 CGEvent → NSEvent 中，⌘⇧Z 的 characters 为 z、charactersIgnoringModifiers 为 Z，后者仍保留 Shift。最终继续 NSApp.postEvent、一次实际接收要求和严格文本/查询/光标断言，不直接调用 undoManager 替代队列。临时回调/菜单探针、无效菜单更新与替代投递实验均已撤回。

| 最终包 | 方法/运行与结果 |
|---|---|
| `bounded-final-smoke.xcresult` | 1 方法/1 次通过；原 workspaceNativeBaseline 通过 visible/key/active 与实际输入断言。 |
| `bounded-final-middle.xcresult` | 1 方法/1 次通过；workspace 门槛直接复用 repeatedUndoRedoRestoresTextAndSelection(.workspace, middle: true)。原初值 `头🧪尾`，UTF-16 位置 3 导入，三轮撤销选区 3、重做选区 6；field/editor/query、编辑器身份及撤销后继续输入严格通过。 |
| `bounded-final-queue.xcresult` | 2 方法/2 次失败；workspace 与普通表单（无换行 `甲 乙`）均收到队列事件，canRedo=true，但 ⌘⇧Z 后仍为空、光标 0。保留正确结果断言，没有允许不动作。 |

最终合计 **4 方法/4 次非参数化入口运行，2 通过、2 产品断言失败、0 场景准备失败、0 跳过**；门槛内部显式选择 workspace/form，不冒充完整参数矩阵。内部往返共 9 轮（中段 3、两队列各 3），材料矩阵循环 0。四搜索完整查询/结果、六文件适用方法、外部同步/Return/组合文本/候选，以及捕获、剪贴板、原 DaybookTextFieldTests / DaybookTextFieldSearchTests / InputSyntaxInteractionTests、普通表单与 UnifiedSearchInputTests 扩大回归均未运行，因为两条核心门槛未全部通过。

**失败定界与过程证据**：此前 `bounded-*` / `bounded-corrected-*` 的 smoke 和 middle 共 4 次通过；七次队列诊断（queue、corrected、trace、nativechars、menu、menuupdate、formcontrol）均在产品断言失败，合计 11 次运行，内部中段 6 轮/队列 21 轮，不和最终 4 次合并声称通过。原探针证实撤销后 editor.canRedo=true，⌘⇧Z 被派为 noop:；原 Edit 菜单存在，更新菜单也未解决。未采用本轮自定义编辑器的普通 SwiftUI 表单亦复现，因此根因不能归为换行转换，也不能据此扩大生产快捷键实现。

投递层对照 `bounded-processqueue-queue` 首先被并发新增 TaskCreatePreviewCompositionTests.swift:69 非法转义阻断，零运行、独立编译失败 1 次；没有修改或排除并发文件。并发方修正后，同轮继续 `bounded-processqueue-ready-queue`，完整编译通过，但尝试只向 QA 自身进程投递的两例均在事件接收等待失败，单列 **2 次事件投递准备失败**，不是重做产品证据；未请求或改变权限。实验撤回后才运行上述最终三包，故最终证据不依赖替代队列。

最终受测版本由同目录 `bounded-final-smoke-source.json`、`bounded-final-middle-source.json`、`bounded-final-queue-source.json` 与 `bounded-final-source.json` 标识，全部生产/测试 Swift 摘要一致。生产 DaybookTextField / DaybookTextEditing / DaybookNativeTextInput 保持下节摘要；最终 BoundaryTests SHA-256 为 `145788995109072d1b71253f76187fa94c94e69f25aec505415be60b7294f0c7`，UndoTests 为 `6319c0435bbd21c01ea31f56a2994ad272d36d3fc958ea230b4e7298ded9beae`。各次等待前/取得锁后摘要一致；暂存区与本轮起点一致，并发新增/修改原样保留。

最终两测试严格 SwiftLint、static profile、工作流及工作区/暂存区差异检查通过；最终完整正常测试目标编译通过，QA 包 `codesign --verify --deep --strict` 通过。保留既有 SDK/actor 警告；无生产修改，不另跑生产构建或安装。历史锁屏 52 次与此前零运行仍单列。首版 11 次失败中，仅 workspace 中段对应场景可凭最终门槛关闭；其余 5 个中段消费者未补验，5 个搜索队列仍未关闭，不能整批清零。

指定 Cursor verifier 不可调用，保留缺口，不认证或替换。真人 IME、系统粘贴未验；剪贴板新策略、匹配器和新统一搜索业务不修改。本轮没有提交、推送、安装、发布或操作真实数据、系统剪贴板及权限；最终锁已释放，到此停止。后续需继续定界真实队列/菜单快捷键路由，不能以契约或编译通过替代。

### I 修复一续验：原生插入事务与消费者（2026-10-06，上一续轮）

**状态仍为 partial，当前阻断是并发构建锁。** 只读 CGSession 检查显示已登录、位于控制台、未出现锁屏标志，前台为 Chrome；这不替代 QA 窗口的 visible/key/active 断言。计划先运行原 `SearchMultilineDiagnosticTests.workspaceNativeBaseline`，但两次非等待申请均在 `build/.build.lock` 处退出，未启动 xcodebuild 或 QA 宿主。第二次申请前已确认前一持锁进程退出；随后新进程取得锁，后续只读观察又见新的持有者，未循环投递测试、移除锁或干扰并发窗口。

本续轮仅更新本记录，未改生产或测试。`build/SearchMultilineIRepair/continuation-source-before.json` / `continuation-source-final.json` 保存全部生产及测试 Swift SHA-256；8 个相关生产文件与六个 SearchMultiline 文件均与上一轮 `source-final.json` 一致。关键身份：DaybookTextField `8787c3ae18c6decdece5529c6ab4d47cadd10a4d63cbf25cd4b7fe9705cd95b1`、DaybookNativeTextInput `06ee2e626d06574a3e889001752ac6b8ca06deed6c08fa4c08c73a9ec84a151d`、DaybookTextEditing `46d7b3924bbbbe912a43c2efa4d897bcd4aa390e29bd8ec97b1ace54c6a1e9fc`。这是待测源码身份，没有本轮有效原生受测版本。并发期间暂存区及两个 UnifiedSearchTaskCreate 测试文件发生变化，原样保留；起点暂存快照和差异摘要位于同目录 `continuation-*` 证据，不宣称暂存区未变化。

| 本续轮证据 | 统计与未完成要求 |
|---|---|
| 原生运行 | 方法 0、参数运行 0、内部材料循环 0；产品失败 0、场景准备失败 0、测试内跳过 0。两次构建锁拒绝单列为执行前环境阻断，不能算测试通过或产品失败。 |
| 核心与消费者 | `repeatedUndoRedoRestoresTextAndSelection`、`queuedUndoRedo` 均未运行，中段重做与队列重做未关闭；六个 SearchMultiline 文件的适用方法、四个普通搜索、捕获/剪贴板/表单对照，以及原 DaybookTextFieldTests、DaybookTextFieldSearchTests、InputSyntaxInteractionTests、普通表单、UnifiedSearchInputTests 受影响分支均未完成续验。 |
| 历史证据 | 上轮锁屏 52 次仍独立列为环境准备失败；首版 11 次失败仍全部待对应最终用例关闭，不与本轮零运行或静态结果混算。 |
| 静态门禁 | 15 个相关 Swift 文件严格 SwiftLint 通过；static profile（含 226 项脚本回归）、工作流及工作区/暂存区差异空白检查通过。日志为 `continuation-swiftlint.log`、`continuation-static.log`、`continuation-workflow.log`。 |
| 完整目标编译 | 因共享锁占用未执行本轮完整正常测试目标编译；不沿用旧编译结果。本轮无生产修改，未另跑生产构建/验签。 |

恢复入口仍是原 PrivacyQA 完整正常目标、原独立目录/标识、生产 entitlement、六项真实钥匙串变量清除与串行测试：先通过原 QA 小场景，再验证中段和真实队列两条核心回归，之后扩大消费者。当前工具目录无指定 Cursor verifier，保留缺口，不重复认证或换机制；真人 IME、系统粘贴仍未验，剪贴板新策略不接入。未提交、推送、安装、发布，未操作真实数据、系统偏好或权限；本续轮到此停止。

## 第十阶段 I：生产搜索多行输入复现与修复定界

2026-10-05，定向诊断，仅补 [生产装配夹具](../AreaChainTests/Features/SearchMultilineTestSupport.swift)、[回调探针](../AreaChainTests/Features/SearchMultilineTrace.swift)、[入口诊断](../AreaChainTests/Features/SearchMultilineDiagnosticTests.swift)、[输入边界](../AreaChainTests/Features/SearchMultilineBoundaryTests.swift)、[模式对照](../AreaChainTests/Features/SearchMultilineModeTests.swift)、[撤销诊断](../AreaChainTests/Features/SearchMultilineUndoTests.swift) 及本记录。**五个生产搜索在“命名 pasteboard 原生导入 → 撤销”中均复现了任务分隔符注入；直接导入完成时没有注入。** 这不是直接调用转换函数或手改 field 后通知 delegate 的复现，也不是系统剪贴板粘贴或真人操作。生产输入、解析、搜索、新统一搜索控制器与接线均未由本轮修改，问题未修复。

**隔离与证据来源**：macOS 26.6.2（25G83）arm64，英文浅色、700×600 单实例，原 SystemPageHost / SettingsButtonTestSupport / ClipboardOptionsFixture，完整正常应用与测试目标、`build/PrivacyQA-SearchMultilineI`、`com.areachain.privacy-qa`、local 临时签名、生产 sandbox entitlement、LSUIElement=NO、六项真实钥匙串变量清除及原 `build/.build.lock` 非等待串行互斥。第一次锁忙没有启动编译；只读确认无持有者后正常重试。仅 XCTest 启动，内存模型、独立偏好、临时历史目录与合成正文；剪贴板 session 的 pasteboard=nil，onCommit 只计数/记录合成 ID，未执行复制或粘贴。没有读取或覆盖 NSPasteboard.general，没有改签名配置、启用真实钥匙串、打开日用应用或操作真实数据。

起点状态、暂存差异和全部生产 Swift 摘要在 `build/SearchMultilineI/status-before.txt`、`index-before.txt`、`baseline.json`。命令、日志、结果包、导出诊断均在同一忽略目录。探针只包裹原 Objective-C IMP，记录 controlTextDidChange / editorDidChangeText / 原生命令的进入和返回，原 delegate、通知、Binding 和补全不替换，defer 恢复 IMP；无探针的材料矩阵另证实正常导入值相同。直接读取 coordinator.parent.text 是生产 Binding 的观察值，不建立镜像查询。私有标签/手记查询只在明确标识的外部同步对照中经原 Binding 写入。

| 真实消费者 | 原生 insertText 与命名 pasteboard 导入完成 | 空字段一次命名导入后撤销 | 查询与结果依据 |
|---|---|---|---|
| WorkspaceHeaderSearchCapsule | 均为 `甲 乙`，该输入路径未复现分隔符注入 | 已复现：中间 `甲 // 乙`，最终 `/ 乙` | 原 WorkspaceNavigation 与 WorkspaceGlobalSearchView；正文词从甲/乙变成含斜杠的查询，合成无斜杠任务不再命中。 |
| MenuBarSearchField | 同上 | 已复现，同上 | 原 toolbar、筛选 token、补全与 MenuBarSearchResults；token 未删除，未用替代搜索框。 |
| ClipboardHistoryBrowser.searchField | 同上 | 已复现，同上 | 原隔离 session.visibleItems、原三模式及生产列表；保留可见结果与无副作用提交回调。 |
| TagManagementPage.searchField | 同上 | 已复现，同上 | 原私有 query 与 displayed 列表，以合成 TAG_SPACE / TAG_SLASH 的实际 AX 可见结果核对；未创建、改名、选色或保存标签。 |
| DiaryPage.searchChrome | 同上 | 已复现，同上 | 原 SyntaxTextField(.tagSearch)、普通合成手记与生产卡片列表；原查询/隐私投影保持，未读取真实正文或解锁。 |

**确切注入点**：`NSTextView.readSelection(from:type:.string)` 接收仍含 LF 的命名 pasteboard 字符串。导入正常完成时，`cell.usesSingleLineMode=true` 的 AppKit 路径已把 LF 换成空格，第一次 controlTextDidChange 进入前 field/editor 就是 `甲 乙`。导入通常有两组 controlTextDidChange → editorDidChangeText，查询实际只从空变成空格文本一次。空字段的 insertText 后撤销只有一组文本变更，正确恢复空；同样的命名导入撤销则先恢复原始 `甲\n乙`，进入 **DaybookTextField.Coordinator.controlTextDidChange 的单行分支（sanitizeSingleLineText，再写 field.stringValue）**，当次返回前 field/editor/query 已变为 `甲 // 乙`、光标从 UTF-16 位置3移到6。随后原撤销动作仍删除原3个 UTF-16 单元，第二组回调发布 `/ 乙`、光标0。editorDidChangeText 看到的是已经插入分隔符的文本；它不是这次首个注入点。它自身的同类分支、Return、noop 命令提交及 onCommandReturn 闭包仍是后续必须统一处理的静态路径。观察到的多次回调是原实现行为，次数不冒充 SwiftUI body 渲染次数。

**材料与同步区别**：无探针矩阵覆盖七种真实控件 × insertText/命名导入 ×15串。普通单行、LF、多行、CR、CRLF、U+0085/U+2028/U+2029、空白行/前后空白、已有半角/全角分隔符、中文/组合字素/emoji、标签/优先级/时刻和字面反斜杠n均逐一核对 field/editor/query 与 UTF-16 光标。单行搜索和捕获的每个换行标量变成一个空格，CRLF产生两个空格，不修剪原有空白；不新增 `//`。普通 DaybookFormTextField 原样保留这些字符串，完全不经过任务转换。这些不是所有粘贴类型、系统 Cmd-V、语言主题/尺寸全矩阵的证明。

外部 Binding 单独更新为 `甲\n乙` 时，五搜索均原样同步，既不触发文本变更回调也不增加原生撤销历史；随后 Return 在 handleReturnSubmit 中转换为 `甲 // 乙`，实际列表转向有斜杠的合成记录。⌘Return 只有菜单栏搜索的原 onCommandReturn 转换；其他四搜索保留真实 LF，失焦也保留。此项仅作为同步/提交对照，不与命名导入撤销证据混算。原生插入中段 `头尾` 的光标1处后显示 `头甲 乙尾`、光标4；其撤销也可能经过原多行中间态后留下 `头/ 乙尾`，严格恢复断言保留。首轮连续两次程序化插入会落在同一隐式撤销组，不能据此判断单次操作边界；最终夹具使用无撤销记录的初值，表单初值在聚焦前装配，空字段一次导入另有独立对照。

**模式政策的实测依据**：BoardSearch 将 LF/空格当词边界，`//` 却是额外的普通搜索词；标签目录使用 trim 后的连续子串，不是按词 AND 搜索。剪贴板 mixed 是逐字符有序匹配，exact 是字面 contains，regex 原样编译正则；三个模式的外部真实 LF 都只命中合成 LF 记录。原生导入真实 LF 后，mixed 改命中空格及斜杠记录，exact/regex 改命中空格记录。字面 `甲\n乙`（反斜杠+n）原生导入不改变：mixed/exact 命中字面反斜杠记录，regex 命中真实 LF 记录。外部真实 LF 后 Return 会转换查询，三模式均把无副作用回调目标从 LF 记录切成 SLASH 记录。不能把 mixed 当作会自动忽略所有空白，也不能用“删除 //”代替明确的模式语义。

**输入法与捕获边界**：合成 setMarkedText 可暂存真实 LF，但该阶段没有 controlTextDidChange/editorDidChangeText；外部更新不覆盖组合区，搜索 ⌘Return 不提交。原生 insertText 正常提交组合串后先转为空格，再进入回调；Return/⌘Return 不再添加分隔符，剪贴板 Return 一次回调、⌘Return零次。Return 期间 marked guard 与标签候选优先级分别测试；候选初选是“工”的候选，测试经原生↓选中已有“工作”后再 Return，不改生产候选次序或关闭补全。合成 NSTextInputClient 调用不等同真人中文输入法。

原 CaptureField 证明：原生单行导入同样先变空格，而外部含LF的草稿经 Return 转为 `甲 // 乙`，原 parseTaskCapture 得到标题甲/备注乙；原首行/备注政策仍有适用范围，不能全局删除转换。捕获按钮自带的 ⌘Return 在本夹具中先于文本框路由，外部LF草稿保持原文；外部非空草稿启用按钮后，即便 editor 仍 marked，按钮回调仍可触发一次。这个已核实的相邻同步对照只用窄 withKnownIssue 保留“不应提交”断言，单列未修复，不推广为所有真人IME或搜索都失守。标签创建/改名存在同样 allowsShiftNewline=false 的静态线索，本轮没有操作或扩大诊断。

**唯一最小修复建议（不实施）**：在 DaybookTextField 增加由消费者明确选择的换行用途策略，将它与“Shift+Return 是否允许换行”分开；保留现有捕获默认与原表单。工作台/菜单栏/标签目录显式选择搜索空白策略，DiaryPage 经 SyntaxTextField 显式透传同策略；剪贴板三模式按现有匹配语义推荐选择真实换行保真策略，字面 `\n` 保持原字符、只由 regex 自行解释。搜索空白策略按当前原生行为替换换行标量为等长空格，不顺带 trim/折叠 CRLF/修改标签或匹配器。

统一应用点是原生已提交输入/命名导入的编辑事务、两条文本变更观察与所有提交入口，不能只修 sanitizeSingleLineText 或某个 onSubmit。**不得在 marked、undoManager.isUndoing/isRedoing 的中间态破坏性改写文本**；转换应与原输入操作共用一次原生撤销事务，回调观察中间态时不另造转换操作，最终查询跟随编辑器。选区按 UTF-16 替换映射保持，外部同步不应成为新增撤销操作；既有补全、焦点、Return、⌘Return、失焦及捕获标题/备注规则保持。剪贴板保真还须处理 AppKit 当前先行单行替换，不能只改 Swift 字符串函数；保持键盘提交与单行布局，不靠打开 allowsShiftNewline 绕过。主对话的最小产品决策仅是确认剪贴板允许真实换行作为查询字符（推荐允许，三个既有匹配模式都有有效含义）；确认前不把它写成已确定规范，不启用新的统一搜索状态/控制器。

**验证与停止状态**：所有问题恢复断言保持，诊断发现不等于生产修复。最初 workspaceNativeBaseline 误期望直接导入会插入分隔符，baseline.xcresult 1次失败；实际回调证据推翻该假设后改为严格空格断言。boundaries.xcresult 因测试把 ParsedCapture.notes 写成body而编译失败、零执行，修正测试字段后重跑。boundaries-run 因测试直接 sendEvent 未更新 NSApp.currentEvent，捕获提交读取 KitDefined.keyCode 触发 AppKit 异常而中断（73），日志/调用栈保留；仅本轮 helper 改用带接收次数断言的 postEvent 原事件队列，未改变生产快捷键。CRLF两个空格与表单原文是实测差异，材料断言分别保留；没有通过丢焦、关闭补全或调整 allowsShiftNewline 来获得结果。

`imports.xcresult` 的2方法/6参数全部通过，五入口两种导入与真实列表完整命中。中间 `final.xcresult` 为12方法/58参数：50通过、7失败、1 Expected Failure；其中材料矩阵、三模式、组合输入/提交、候选与同步对照有效，7失败来自中段撤销（含随后已修正的表单初值测试装配），Expected Failure 是上述捕获按钮对照。这个名为final的中间包不是最后版本的通过声明。`undo.xcresult` 独立14参数：8通过、6失败；六个 Daybook 消费者命名导入后撤销失败，空字段 insertText 后撤销及表单双路径通过。`keyboard.xcresult` 的2方法/19参数：8通过、11失败，新增的五入口队列⌘Z均在要求恢复为空的断言失败，但严格的中间注入、最终残留、光标、实际列表及后续键断言全部命中：Return 保留 `/ 乙`，剪贴板回调一次，⌘Return无额外回调，随后输入x成为 `x/ 乙`、光标1、合成结果归零。两包全程原生 focus 断言通过，未人工调用 delegate，命名导入仍不能冒充系统 Cmd-V。

**最后运行是 `acceptance.xcresult`**：完整正常目标编译成功，xcodebuild因断言失败退出65。6套、25方法、89参数执行，43通过、46失败、0跳过；按方法聚合是13通过、12失败。46个参数失败中，17个是保留的真实撤销恢复要求（中段6、命名导入6、键盘撤销5），另29个是场景准备或操作时的焦点断言失败；日志多次显示 foreground=com.google.Chrome、QA inactive/key=false，只说明当时状态，不推定谁触发了失焦。最后批次的全部五入口键盘撤销仍完成了缺陷与后续键的断言，普通表单初值/中段撤销也通过；两套原 DaybookTextFieldTests / DaybookTextFieldSearchTests 共11方法/12参数全部通过。没有放宽焦点断言，也没有在环境未确认变化时循环重跑；最终全套原生重验因此为 **partial**，历史有效参数不累计成最后全绿。

六个新增测试文件严格 SwiftLint、`python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile static`（224项脚本回归，安全扫描无高风险/敏感日志候选）、工作树与暂存区 diff检查、新文件空白/行数检查、QA包 `codesign --verify --deep --strict` 均通过。没有因只改测试额外生成发行包。保留既有 SDK 弃用/actor、测试中直接读取 FocusState 等警告，不把编译或验签当原生通过。

`source-tested.json` 与起点摘要比较：本轮涉及的全部生产输入/搜索文件无变化；仅检测到其他任务对 CommandTaskCreateContract.swift / TaskCreateCommandAdapter.swift 的并发变化，本代理未编辑，保留原有改动。暂存区二进制差异与起点逐字节一致。未改变公共生产契约，因此没有新开独立复核任务；历史指定 Cursor verifier 缺口保持。未运行真人IME/键鼠、真实系统粘贴、VoiceOver、其他系统版本、全语言主题尺寸矩阵、真实数据/钥匙串/日历、安装与发布。诊断与最小建议已定界，生产修复及焦点受阻的最终重验未完成，停止于本阶段，不提交、推送、安装或发布。

## 第十阶段 H：时间清除失败回显的复现与修复定界

2026-10-05，诊断轮仅补测试及本记录；未修改生产代码。下方“收尾”记录分层与有效历史回归，“H 最终版本复验”记录最后断言版本的当前门禁与待验状态，前段结果包保留为历史证据。结论限定为：**外层失败事务内执行 AXPress 会提前渲染 nil，随后模型回滚没有使这个已渲染的父读取重新失效；当前普通提醒失败对照未复现，截止真实保存失败仍有注入能力缺口。** 不据此修改 SwiftUI Binding、ModelChanges 或发布失败通知，也不关闭第五阶段 B 的两个已知问题。

**原失败重跑与身份**：起点 HEAD 为 `d24391ea2695bae2ccb397d3d277918f5f0279f9`，工作树/暂存区/未跟踪检查及逐文件 SHA-256 保存在 `build/TimeClear10H/source-before.json`。原完整方法 `AreaChainTests/DetailTimePickerTests/failedClearKeepsOriginalDisplay(routine:due:)` 在诊断轮未修改，源码 SHA-256 为 `456d357c00d6a5194470e58ce5770c92bc94c62e888159577747c228016e649f`。`original.xcresult` 实际命中 `(false,false)` 待办提醒、`(false,true)` 待办截止、`(true,false)` 重复事项提醒：前两次为 Expected Failure，第三次通过，零跳过。两次实际失败均在原 `DetailTimePickerTestSupport.swift:43:13` 的 `candidates.count == 1`，实际为 0；模型恢复断言先通过。原日志包含提醒/截止分组边界及另一分组尚存的清除按钮，不是取错同名按钮；顶层 Passed 不表示三个参数全部恢复。

**隔离与过程**：完整正常应用/测试目标、独立 `build/PrivacyQA-TimeClear10H`、`com.areachain.privacy-qa`、local 临时签名、生产 sandbox entitlement、LSUIElement=NO、六项真实钥匙串变量清除、原 `build/.build.lock` 非等待互斥与串行事件。首次锁忙未启动编译；随后只读确认无锁持有者及编译进程，才正常取锁执行。没有锁屏或并发编译失败。测试仅经 XCTest 启动，使用原内存模型、随机偏好和合成时间数据，原通知/日历 XCTest 守卫保持。实际完整命令、原生日志、summary/tests 树与结果包均在 `build/TimeClear10H`。

期间外部并发修改了 ModelChanges 的回滚错误分类：起点 SHA-256 `70c083959a237120bdfa4e129f93f3ff5fc43be5baa5996997425b1a3c6f00d1`，最终受测为 `e88104dd136689160447a79980cb5f3be1fa2ff47f7bcbf3825c64616cb393c3`（`source-tested.json`）。区别是从 `ModelRollback.failure` 返回错误类型判断，改为直接 `restore` 的 do/catch 判定恢复失败；恢复仍为 processPendingChanges → rollback → 各模型 fetch 重新物化。该文件原有暂存和未暂存内容均保留，本代理未编辑它；最终重跑仍得到原两个已知失败，不能把并发共享变化说成本轮修复或旧问题已解决。

| 实际路径 | 请求、返回与恢复边界 | 自然显示及重试 |
|---|---|---|
| 原待办提醒：外层 perform → AXPress → setRemind → 原仓储 | nil 请求；commit 因同 context 延迟，动作返回时 saves=0、phase=working、模型=nil；直接原入口对照内层 Bool=true，随后外层 save 抛错、Bool=false、rollback=returned。 | 原窗口/NSHostingView/模型实例不变；模型恢复720，但标题时间与清除按钮消失。重开仍为 Not set（当前分钟只是编辑起点），清除按钮仍缺失，无法原位再次清除。 |
| 原截止：外层 perform → AXPress → setDue → persist | setDue 直接赋 dueMinutes 后进入嵌套 perform，不调用 taskRepositoryProvider；内层返回true、外层保存失败后恢复600。 | 与提醒相同，父内容保留nil，重开Not set；提醒720和日期保持。 |
| 同两条外层路径改用窗口 NSEvent 点击 | 同样请求nil、内层延迟、外层失败；只替换动作派发，未改事务或回滚。 | 两项自然显示720/600，按钮存在，重开仍为旧值，同宿主再次清除成功。说明外层嵌套本身不是充分条件，AX同步渲染时序是关键。 |
| 待办提醒：原 taskRepositoryProvider 内失败 | 测试 DetailTimeFailureRepository 用与原 routine 设施相同的事务包装，仍执行 SwiftDataTaskRepository.setRemind 的真实修改/commit；保存边界抛错并恢复后才向 setRemind 返回，原入口 Bool=false。 | AX与NSEvent均恢复720和原按钮；重开720，改900失败也恢复；关闭后原位清除重试成功。真实仓储请求恰为 `[nil,900,nil]`，保存边界恰3次，没有重开/关闭的额外写入。 |
| 重复事项：原 RecurringToggleRepository | 保留原仓储失败设施，失败在原回调返回前完成恢复。 | AX与NSEvent清除失败都显示720；同宿主成功重试，请求恰为 `[nil,nil]`。 |

**显示脱节定位**：正常验收始终直接挂原 TodoScheduleSectionView / RoutineScheduleSectionView。独立只读 `parentReadDiagnostic` 用原 TodoScheduleSectionView.body 展开并反射其已生成的 TaskDetailRemindChips / TaskDetailDueTime 值，不修改模型、回调或镜像状态；探针不是正常宿主通过证据。AX动作返回前，记录顺序是旧720/600 → 对应子值nil；外层恢复后未再次读取旧值。在nil之后建立的一次 Observation 订阅也未收到恢复失效回调。NSEvent返回时父视图尚未读取nil，外层恢复之后才读取旧720/600。父节点读不到恢复值，子组件的标量分钟及其 Binding 捕获因此停在nil；无需打开时间选择器即可发生，不能归因为 NSDatePicker 自己把模型清空。

自然更新记录完成后另取四张原生缓存图（提醒/截止 × AX/NSEvent），确认AX对应分组确实没有绘制旧时间和清除图标，另一分组正常；与分组AX树及重开Not set一致，排除单纯辅助树合并/查询错误。图位于 QA 临时目录 `AreaChainButtonConsumersQA/settings-time-clear-10h-*`；缓存绘制没有使原AX症状恢复，且不被计为自然刷新或窗口合成器证据。全程没有重建检查器/窗口、随机id、重新赋旧分钟、成功通知或强制刷新。

**语义与证据限制**：原 `saveAndFailureAutomaticallyRestore` 三参数、补充两个有效900失败的详情标题断言，以及原 `emptyOpenCloseAndMidnight` 均通过，0保持真实午夜且nil表示未设置。截止只写dueMinutes，dayKey、remindMinutes、calendarEventID、ReminderPlanning及CalendarSyncStorage原等价断言保留；共享成功发布的通知/日历刷新职责不等于截止成为提醒。清除nil不申请提醒权限；有效分钟失败路径仍依赖原XCTest系统守卫，不进行真实授权。

原生产详情回调没有外层事务包住AX或NSEvent派发；本轮故障要求这个测试外层仍处于working时同步渲染nil，不能推广为普通清除都会失败回显。新的提醒对照只证明原仓储修改及“失败在UI回调返回前完成恢复”的边界，不是实际磁盘错误；SwiftDataTaskRepository.commit内部的真实save抛错未直接注入。截止没有可替换的仓储或等价save依赖，外层包装不能冒充其普通失败；截止原Void回调未被替换计数，内层Bool来自单独直接入口对照，不声称从原UI闭包读出了被丢弃的返回值。若要判定普通截止生产故障，唯一剩余取证需求是既有真实setDue自身保存边界失败且在回调返回前完成恢复的证据；本轮不新增生产注入API或制造磁盘/真实库故障。

**诊断轮交接建议（已由下方收尾落实测试分层）**：只在 `DetailTimePickerTests` 的测试故障注入层分开“普通回调内失败”与“外层嵌套＋AX提前渲染”两种契约；本轮已补前者的提醒对照和后者的时序证据，原方法/已知问题保持。当前不建议修改生产组件或共享回滚。回归要求继续保留原三个参数及两个已知失败，普通提醒/重复事项须严格检查旧显示、原位重试与精确写入数，截止须保留未取得普通save失败的限制；不能把known issue删除、nil保留或失败发布成成功作为修复。

**验证记录**：`diagnostic.xcresult` 为7方法/18次，16次通过、2次原已知失败；最终 `final.xcresult` 为10方法/25次，23次通过、2次原已知失败，零非预期失败/跳过。其中包括独立诊断方法，不把诊断通过数当作旧产品缺陷关闭数。辅助定位调用方补验 `helper-regression.xcresult` 为4方法/10次：9次通过，1次在 `DetailTimePickerLifecycleTests.nilLifecycleExactCallbacksDisableClearAndLateAction(due:false)` 的 `TimePickerNativeTestSupport.swift:15` 因弹出窗口 isKeyWindow=false 失败；原生焦点断言未删除，未在条件不变时重跑该批。该项为辅助回归的未完成证据，不能归为清除回滚失败或宣称整体验证全绿。

`editor-regression.xcresult` 的原 RecurringEditorTimeTests 为2方法/6次全部通过，零失败/跳过；helper批次中双语浅深色280/400pt详情布局、原快捷项和中文暂存/重开方法通过。本轮四个测试文件严格局部SwiftLint、工作流、静态质量（含223项脚本回归）、工作树/暂存区差异及新增文件空白检查通过；正常完整PrivacyQA编译与QA包静态验签通过，不另行构建/启动非QA宿主。最终来源摘要与受测版本比较保存在 `source-after.json`，暂存区哈希保持起点值；前期及并发修改未恢复。测试记录包含系统框架既有弃用/actor警告及辅助回归的AttributeGraph提示，不将其归因为本轮时间清除故障。

本轮诊断结论已定界，普通截止真实save失败与辅助生命周期焦点回归仍为 **partial**。没有改变公共契约或生产行为，不新增指定独立复核任务；历史Cursor verifier、真人输入/VoiceOver、低版本macOS及窗口合成器验收缺口保持。停止于本阶段，未提交、推送、安装、发布，未修改真实数据、系统偏好、签名配置或权限。


### H 收尾：失败注入分层与回归收尾（2026-10-05）

只调整原时间测试、直接测试支持及本记录。生产 TodoScheduleSectionView / RoutineScheduleSectionView、仓储、ModelChanges 和统一事务规范保持。A/B/C 的正常消费者直接挂载生产分节；反射和人工读取 body 只存在 D 的诊断宿主。未增加生产注入 API、真实磁盘故障或真实数据库操作。

| 分层 | 当前选择器（前缀 `AreaChainTests/`） | 历史映射与不变要求 |
|---|---|---|
| A：回调返回前完成失败恢复 | `DetailTimePickerTests/callbackFailureRestoresDisplayAndRetries(routine:native:)`，2 类提醒 × AX/NSEvent | 合并原 `failedClearKeepsOriginalDisplay(true,false)`、诊断套件 `reminderRepositoryFailureAndRetry` / `routineFailureAndRetry`；重复事项补齐重开及有效900失败。两者均要求旧720及标题行文字、分组唯一清除按钮、失败重开旧值、同宿主重试nil。精确仓储请求 `[nil,900,nil]`、注入保存边界3、真正 `ModelContext.willSave` 1；重开/关闭无额外写入，另一类模型、截止600与日期保持。 |
| B：外层事务＋AX 同步渲染 | `DetailTimePickerTests/outerTransactionAXClearRequiresOriginalDisplay(due:)`，提醒/截止 | 承接原 `failedClearKeepsOriginalDisplay(false,false/true)`，以及 `outerClearTiming(native:false)` 的消费者边界。模型720/600恢复和零真正save在 known issue 外断言；known issue 只包原分组唯一清除按钮断言，按钮若存在则旧文字仍按普通断言检查；不将nil保留当正确行为，不覆盖重开、保存或模型断言。两项旧问题继续开放。 |
| C：同外层事务＋原生合成点击 | `DetailTimePickerTests/outerTransactionNativeClearRestoresAndRetries(due:)`，提醒/截止 | 承接 `outerClearTiming(native:true)`；与B共用一个夹具/注入方法，只改派发。自然显示720/600、重开旧值及原位重试必须通过；失败后0真正save，成功重试后1，外层边界总2，派发请求总2。未替换原Void回调，派发次数不冒充生产回调调用/返回计数。 |
| D：诊断探针 | `DetailTimeFailureDiagnosticTests` 的 `parentReadDiagnostic(due:native:)`、`nestedReturnFacts(due:)`、`repositoryFailureReturnsFalse()` | 父body读取2×2、内外返回/阶段2、仓储返回1，共7次诊断。`outerClearTiming` 的事务阶段刻画并入 `nestedReturnFacts`，不重复运行消费者；反射读取成功不表示旧问题关闭。 |
| 原有效赋值与普通回归 | 原 `saveAndFailureAutomaticallyRestore(routine:due:)` 三参数和其他现存详情测试 | 原三个参数完整保留；`validTimeFailureKeepsDetailLabel(due:)` 的旧标题要求并入原方法，取消重复方法。nil/午夜0、另一时间字段/日期、截止的提醒与日历投影约束继续检查。 |

旧完整清除方法与旧诊断消费者选择器已由表中映射替代，不再同时运行旧/新用例或相加计数。公共 `DetailTimeSupport` 保留所属分组的唯一定位，进一步要求旧文字位于清除按钮的标题行，避免把12:00快捷项误作旧显示。打开时间控件继续要求全进程匹配唯一，并确认弹窗 parent 是本例宿主。保存观察者、替身失败标志与仓储 provider 用 defer 清理；失败夹具建立时也恢复已创建资源。

A 的提醒对照只证明真实模型修改后、失败及恢复在 UI 回调返回前结束时显示正常；仓储包装在真正 context.save 之前抛错，未制造磁盘保存故障，也不能覆盖所有生产保存失败。截止仍走 setDue / persist，普通截止回调内真实save失败缺口保留。B的两项嵌套AX问题未修复，D通过不参与其关闭判断。

**辅助生命周期先行补验**：临时只选择原 `nilLifecycleExactCallbacksDisableClearAndLateAction(due:false)`，`closeout-lifecycle-false.xcresult` 实际1方法/1参数通过、0失败/跳过，随后已恢复 `[false,true]`。日志只读记录QA标识、宿主/弹窗及parent、visible/key/active、步骤与前台应用；原 key 断言保留，没有插入新的抢焦或刷新。此次未复现原失败，不能判定旧偶发失焦唯一根因或宣称所有焦点问题已修复；相邻参数的最终结果另列。



**最新有效回归与统计**：`build/TimeClear10H/closeout-acceptance.xcresult` 的 summary/tests 树确认5套、20方法、51次执行：49通过、2嵌套AX已知失败、0非预期失败/跳过。按最后有效运行去重如下；初次单参、内部尺寸/快捷项循环及旧诊断轮不再相加。

| 层次 | 有效参数执行 | 结果 |
|---|---:|---|
| A：回调内提醒失败恢复 | 4 | 待办/重复事项 × AX/NSEvent 全通过；请求3、注入保存边界3、真正save1，失败重开/原位重试和字段隔离全部命中。 |
| C：外层事务原生点击 | 2 | 提醒/截止通过；恢复原显示与重开720/600，原位清除重试成功。 |
| B：外层事务嵌套AX | 2 | 两次 Expected Failure，实际失败仍是所属分组清除按钮数量0；不计功能通过。 |
| D：诊断刻画 | 7 | 父读取4、嵌套返回/阶段2、仓储返回1通过，不代表修复。 |
| 辅助生命周期 | 2 | due:false / true 均通过；原key断言、禁用/迟到action、nil与0及精确回调全部保留。 |
| 其他相邻回归 | 34 | 原详情有效赋值三参数、空值/午夜、快捷项、中文暂存/重开、双语浅深色布局，以及 RecurringEditorTimeTests、TimePickerConsumerTests 全部通过。 |

生命周期日志确认 popup.parent 为同例宿主，visible / popup.isKeyWindow / active 均true；NSApp.keyWindow 同时可能仍指向父窗口，日志分别记录，未混同这两种系统属性。原生事件保持串行，没有操纵其他窗口。此前 helper-regression 的失焦失败仍保留，本次补齐其回归证据，不宣称偶发根因已修复。系统框架弃用/actor警告和既有 AttributeGraph 提示不作为时间清除修复证据。

**最终编辑及阻断**：`closeout-regression.xcresult` 首次编译因本轮新增标题断言的throwing `&&` 缺try而取消；已拆为guard并通过上述完整回归，首包不计覆盖。随后主代理将B的 withKnownIssue 更严格限定为原唯一按钮断言，新增文字要求在按钮存在时单独按普通断言检查。最终 `closeout-boundaries.xcresult` 尝试复验A/B/C及返回事实，完整正常目标编译被并发生产 `CommandTaskCreateExecution.swift:80/95` 的 units setter不可访问、`:66` 的MainActor隔离调用错误阻断，测试未运行。未排除、修改或回退生产文件，未拿test-without-building替代最终源码编译；最后B断言范围编辑的运行验证仍待补。当前工作树的完整目标编译门禁因此 **partial**，此前完整目标编译成功只属于acceptance受测版本。

**源码与暂存身份**：起点/受测/最终摘要见 `closeout-source-before.json`、`closeout-acceptance-source.json`、`closeout-boundaries-source.json` 与 `closeout-source-after.json`。本轮起点和acceptance受测的 ModelChanges SHA-256 为 `e88104dd136689160447a79980cb5f3be1fa2ff47f7bcbf3825c64616cb393c3`；后续并发版本为 `63bcfb0ab798a4662ed01e6ab2b93d3920074f2099e813f60e95bda8857b2d19`（新增 hasActiveTransaction 只读查询），尚不能把旧运行算作该版本整体通过。并发还在修改任务创建协议/仓储/解析器与执行模块，逐文件差异按摘要保留；均非本轮修复。本代理生产源码零编辑、暂存区零操作，暂存差异SHA-256保持 `26c7506b62ce2330bd8e39f9a579303dc9f5980edcbca7dc24696b8b62937383`。

**交接边界**：测试分层、历史映射和辅助生命周期补验已落实；两项嵌套AX旧问题及普通截止真实save失败缺口继续开放。最终局部SwiftLint、差异/新增文件空白检查与静态门禁结果按收尾日志记录；并发解析器503行导致工作流/静态门禁失败，不能说全部通过。完成本轮允许的测试/记录工作后停止，可把其他独立问题另行定界；需要重新编译/验收时先解决并发构建门禁，不在本轮扩修生产事务、显示组件或任务创建。未提交、推送、安装、发布或修改真实数据、系统偏好、签名配置与权限。


### H 最终版本复验（2026-10-05，最终测试分层版本已验证）

本轮仅运行最终验证并更新本记录，未修改生产或测试源码、断言和失败注入。**完整正常 PrivacyQA 编译已恢复，最后收窄 withKnownIssue 的测试版本已取得运行证据，H 本轮最终版本验证完成。** 这不代表两项嵌套AX旧问题已修复，也不补齐普通截止真实save失败、指定复核或其他历史验收缺口。原 `closeout-acceptance.xcresult` 的49通过/2已知失败保留为历史版本，不累加到本轮。

**编译恢复与历史阻断**：上一轮 `final-version-compile.xcresult` 的 build-for-testing 退出65、零测试执行，准确阻断为 `TaskCreateCommandTests.swift:49:9` 的 `readTodos()` 和 `:79:9` 的 `state()` 缺少try；当轮停止后并发工作已修正。此前 NaturalLanguageParser 的503行门禁、检查脚本夹具 FileExistsError 均已有并发修正与最终静态通过记录，见原 `final-version-*` 证据。本轮开始亲自核对49、79行均已补try，未替并发任务改源码；沿原完整目标执行一次重新编译的 `xcodebuild ... test`，退出0，`final-resume-build-results.json` 为 succeeded、0错误、64项编译警告（含既有弃用API/actor诊断）。未排除任何源码、未使用 test-without-building，无需编译重试。

| 分层与实际完整方法（前缀 `AreaChainTests/`） | 实际参数及次数 | 最终结果 |
|---|---|---|
| A：`DetailTimePickerTests/callbackFailureRestoresDisplayAndRetries(routine:native:)` | `(false,false)`、`(false,true)`、`(true,false)`、`(true,true)`，4次 | 全部严格通过。旧720、标题行文字、原分组清除按钮、失败重开及900失败恢复、同宿主nil重试、请求`[nil,900,nil]`、3次注入边界/1次真正save及其他模型字段保持均获证据。 |
| B：`DetailTimePickerTests/outerTransactionAXClearRequiresOriginalDisplay(due:)` | `false`、`true`，2次 | 两次均为 Expected Failure；具体失败只落在 `DetailTimePickerTestSupport.swift:29:13` 的 `(candidates.count → 0) == 1`，对应提醒/截止的原分组清除按钮缺失。 |
| C：`DetailTimePickerTests/outerTransactionNativeClearRestoresAndRetries(due:)` | `false`、`true`，2次 | 全部严格通过。原生合成点击后恢复720/600、原窗口重开旧值及成功清除重试、请求/保存次数和其他字段保持通过。 |
| D：`DetailTimeFailureDiagnosticTests/repositoryFailureReturnsFalse()`、`DetailTimeFailureDiagnosticTests/nestedReturnFacts(due:)` | 无参1次；`false`、`true`各1次，共3次 | 全部严格通过。仓储返回false；两个嵌套入口均为内层true/saves=0/working，外层false/saves=1/rolledBack/rollback=returned，并恢复原模型。 |

`build/TimeClear10H/final-resume.xcresult` 的测试树实际为 **5方法、11次运行：9通过、2已知失败、0非预期失败、0跳过**。summary顶层的4通过/1已知失败是方法数，设备层9/2才是参数运行数；4个参数化方法共10次，再加无参1次。原生日志及 `final-resume-ax-activities.json` 确认两项已知失败真实出现，未伪造或扩大范围。`withKnownIssue` 仍仅包原分组唯一按钮定位；模型、日期、另一字段、请求/保存次数在普通断言中通过。按钮若恢复时的旧文字要求仍为普通断言，本轮两项按钮均缺失，故该条件分支未执行，不能冒充两项显示已恢复。

**隔离与执行状态**：沿原 `build/PrivacyQA-TimeClear10H`、`com.areachain.privacy-qa`、local临时签名、生产sandbox entitlement、LSUIElement=NO，清除六项真实钥匙串授权变量，原 `build/.build.lock` 非等待互斥和串行测试。原锁一次成功取得，无锁忙；本轮无编译失败、零执行或焦点阻断。未单独采集系统锁屏状态，原窗口激活/key-window及后续焦点断言完整保留且通过，不以跳过断言消除环境失败。仅经XCTest启动隔离宿主，使用原内存模型、随机偏好和合成数据；未直接启动QA或日用应用，不写真实钥匙串/日历。未重跑已有有效完整界面矩阵，未追加独立Debug/发行构建。

**源码身份**：HEAD为 `d24391ea2695bae2ccb397d3d277918f5f0279f9`。起点、取锁后受测、测试结束和最终摘要分别为原证据目录中的 `final-resume-source-before.json`、`final-resume-source-tested.json`、`final-resume-source-after-test.json`、`final-resume-source-final.json`。编译至测试结束所有纳入摘要的源码/配置/记录均无变化；最后仅本工程记录变化，生产与测试源码和受测版本一致。暂存区摘要始终为 `26c7506b62ce2330bd8e39f9a579303dc9f5980edcbca7dc24696b8b62937383`，未恢复或覆盖并发修改。

本轮受测SHA-256：

- `TaskCreateCommandTests.swift`：`bbb81094f0aea6d937a20aea8ccc8df3dfdfe8e4939c25d03e58b029052d06dd`。
- `DetailTimePickerTests.swift`：`c0fe70bd5e2e700da39f466820d51ed2521dcdb5d267cb0d0e2ad5e396e85147`，与上一轮最后断言版本相同。
- `DetailTimePickerTestSupport.swift`：`3b213337c691c4492313daee673c2f6d47a32b798d2e2bc535a43d65a09231e4`。
- `DetailTimeFailureDiagnosticTests.swift`：`2bcae5f9de1c89c7799da71c3d676ab61536ff8107947257a837ee1d49bd36cb`。
- `ModelChanges.swift`：`63bcfb0ab798a4662ed01e6ab2b93d3920074f2099e813f60e95bda8857b2d19`。

完整命令、退出状态、编译日志、summary/tests树、构建结果及原生诊断导出均保存于原 `build/TimeClear10H/final-resume*`。七个H测试/支持文件严格SwiftLint通过；最终 `python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile static --format json`（224项脚本测试）、工作树/暂存区差异及未跟踪文本空白检查通过。未将静态检查、顶层Passed或编译成功当作旧问题修复证据。

两项嵌套AX问题继续开放；普通截止回调内真实save失败仍缺等价注入；原历史生命周期有效结果、偶发焦点根因未定、指定Cursor verifier、真人输入/VoiceOver、低版本macOS及窗口合成器缺口保持。H最终测试分层版本的待补运行已完成，无本轮直接阻断；整体验收仍受上述历史缺口限制。完成后停止，不进入独立问题，不提交、推送、安装、发布，不修改真实数据、系统偏好、个人签名配置或权限。

### H 当前截止注入能力核对（2026-10-08）

本小节保留前次只读核对的历史事实；当前接点与验收状态以下方本日授权实施记录为准，不再把“没有注入入口”作为后续阻断。

本轮只读核对当前真实链路与原 H 分层，未重跑条件未变的旧诊断、未修改 H 生产或测试。`TodoScheduleSectionView` 的 `TaskDetailDueTime` 回调仍调用 `DayBoardMutations.setDue`；当前 setDue 在 `persist` 的 work 内委托 `TaskMutationService.assignDue`，后者仅执行 `todo.dueMinutes = RemindMinutes.clamped(minutes)`。这是共享赋值提取，不是新增保存依赖；不能沿用“源码逐字未变”的描述，但原截止赋值、保存与返回边界保持。

`DayBoardMutations.persist(context:_:)` 仍无 save/Boundary 参数，直接调用默认 `ModelChanges.perform`。ModelChanges 虽已有显式 `Boundary.preSave/save` 及事务事实，只有调用者显式传入或同 context 外层事务继承时才能使用；详情 setDue 不接 `taskRepositoryProvider`，也没有可替换的保存提供者。命令侧 `TaskMutationService.editField` 的依赖不能注入该真实详情链。将 AX 包进外层 transaction 仍会重新引入原 working/提前渲染时序，不构成等价入口。

**结论：仍缺普通 setDue 自身保存失败的等价注入能力。** 最小后续方案是另行定界一个仅供真实 setDue 内部保存调用使用、默认保持原行为的显式保存依赖，并让详情隔离宿主可装配；不能只给未被 UI 调用的重载加参数，也不应引入全局失败开关。影响至少为详情装配、setDue/persist 调用边界和其针对性测试，需验证失败及恢复在回调返回前完成、同宿主显示及重试、精确调用数和字段/投影隔离。本轮未实施该方案，也未新增生产保存 API。

未来若依赖在 `context.save()` 前抛错，必须归类为“保存调用前的替身抛错”；只有实际保存接口返回错误的证据才能描述为该层失败，仍不能自动称为真实磁盘错误。当前没有补齐上述运行证明，两项嵌套 AX 旧问题各自保持开放；原提醒对照、输入人工反馈、未对齐证据及整体 partial 分类不变。

### H 真实截止详情链的最小保存依赖与失败恢复验收（2026-10-08）

**整体继续 partial，用户未接受整体交付。** 本轮明确授权仅增加截止最终保存显式依赖、贯通真实详情回调及隔离恢复验收；不修两项外层嵌套 AX、不改 ModelChanges / ModelRollback、不新增失败发布或强制刷新。接手时工作区已有 saveDue / setDue(save:) / persist(save:) 三处最小实现，先核对再沿其补测，没有覆盖并发搜索/Stepper 修改或操作暂存区。

| 影响入口 | 最终选择与保持的边界 |
|---|---|
| TodoScheduleSectionView → TaskDetailDueTime | 局部 MainActor saveDue 默认 `try context.save()`，生产实际 Void 回调传递该依赖；不新增镜像状态、随机 id 或窗口重建。 |
| setDue → persist → ModelChanges.perform | 旧签名和函数引用保留；显式重载只透传最终 save。继续 todo.modelContext 及原回退、TaskMutationService.assignDue、原 Bool 及 UI 丢弃返回值。 |
| 原事务、其他消费者 | 不暴露 preSave/publish/reportFailure；已有 pending 预保存、修改/保存/回滚/反馈/成功发布顺序及外层提交者继承不变。提醒、日期、重复事项、通知/日历投影不接新依赖。 |

**证据方法**：内存合成夹具先完成准备保存，记录器之后才计被测 `ModelContext.willSave`。普通 AXPress / 原生 NSEvent 均无外层事务包装，最终依赖先确认本例 context、事务存在及原赋值，再记录并抛 `syntheticFinalSave`。每次动作在任何 await、settle 或后续 AX 查询前检查模型已恢复、事务已退出及反馈；完整顺序断言为 request → assigned/save → synthetic-throw → synchronous-return(600)，成功重试为 request → assigned/save → context.save-call → context.save-return → publish → synchronous-return(nil)。原分组文字/清除按钮、原时间弹窗、身份与再次提交另行验收。只读展开同一生产父 body 的 Void 回调检查与直接 setDue Bool 检查分开，不能把事件返回写成从 UI 得到了 Bool。

**首批记录**：`build/Controls10P/h-due-seam.xcresult` 编译/验签成功；6方法/8次执行中7次通过、1方法失败。失败来自新增测试误把原越界分钟政策写成压到0/1439；实测及原 RemindMinutes.clamped / TaskTM2 测试均为越界→nil，已只修测试预期。两条普通 UI 恢复/重试、Void 回调、预保存、嵌套提交者和两实例依赖隔离在首批通过；首批不作为最终源码验收，不覆盖或修改旧结果。

**H 定向结果**：以下为最后H测试源码、并发习惯命令变更前完整源码版本的去重证据，不叠加首批或原174/770次历史统计；当前全工作区门禁的后续阻断见本节收尾。

| 结果包（均在 build/Controls10P） | 实际命中 | 判定 |
|---|---|---|
| h-due-acceptance.xcresult | 24方法/45次 | 全部通过；新增 DetailDueSaveTests 7方法/9次，原详情7方法/19次，H诊断3方法/7次，详情生命周期1方法/2次，日期双语1方法/2次，以及原事务/赋值5方法/6次。 |
| h-due-boundaries.xcresult | 3方法/4次 | 两个准确命名的预保存方法通过；外层AX方法的 due=false/true 各一次 Expected Failure，仍仅为 DetailTimePickerTestSupport.swift:29:13 的 `(candidates.count → 0) == 1`。模型恢复和零实际save保持普通断言通过。 |
| 合计 | **27方法/49次** | **47通过、2已知失败、0非预期失败/跳过**；两项已知失败不计功能恢复通过。 |

每条普通截止 UI 路径的精确计数：请求 `[nil,900,nil]`、最终保存依赖尝试3、实际内存save1、错误反馈2、成功发布1。两次失败分别在同步事件返回处恢复600，原窗口/hosting view/模型身份保持；原分组与弹窗自然回显600，关闭零额外保存，取消失败开关后同宿主清除成功，新 ModelContext 读到nil。默认未注入详情的900/清除/午夜0与逐次重开为3次真实save、3次发布、0错误；旧函数引用及 persist 默认失败反馈单独通过。原提醒/重复事项、日期双语、en/zh-Hans×浅深色×280/400宽度的原详情矩阵及原赋值投影约束均有本批结果；这些 AX/原生程序事件与缓存布局检查不冒充真人或窗口合成器视觉验收。空 modelContext 的生产全局回退只核对表达式保持，未打开真实全局持久容器补测。

**选择与 runner 限制如实保留**：acceptance 请求中一个旧预保存方法名写错，XCTest忽略了该不存在选择；结果树守卫报 `missing selected test: TaskCaptureTransactionTests/failedPresaveKeepsExistingPendingChanges()`。随后 boundaries 用真实 `failedPresaveDoesNotEnterCreationOrDiscardPendingEdit()` 和 `legacySaveInjectionStillPresavesOutsideItsClosure()` 补齐，没有把缺席项计为通过。原 P runner 三批均保留 `sessions: missing batch session evidence`；boundaries 另保留拒绝 Expected Failure 的 `results: test result not fully passed`。不修改 runner 或旧执行JSON，不伪造 Gallery 回执；本轮非 Gallery 的判定依据是各包 summary/tests、XCTest标准输出、编译/验签及下面独立进程退出记录。

**隔离与源码身份**：完整正常 AreaChain scheme / PrivacyQA Debug、arm64、串行，独立 `build/PrivacyQA-Controls10P`，QA标识 `com.areachain.privacy-qa`，沿既有local/ad-hoc签名和原entitlements。六项真实钥匙串授权变量由原runner清除；仅XCTest启动，未启动Gallery/桌面入口或附着旧app。原 `build/.build.lock` 三次均在单次900秒预算内立即取得。HEAD `61f4ba2cca305b7879186a6f1cd919cd92caf887`，最终1257项源码集合摘要 `7a6bef04bcccf9243613f1559aaf1ae8f27695fc5b59a4c771668c26489fe5f9`，acceptance与boundaries申请/锁后/运行后集合一致，索引保持空差异摘要 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。每批 `*-command.json` / `*-before.json` / `*-after.json` / `*-execution.json` 保存命令、源身份与构建退出；最后两批xcodebuild=0、codesign=0，完整QA编译及 `codesign --verify --deep --strict` 通过，未运行普通日用构建或安装。既有AX弃用/无用变量及ad-hoc Hardened Runtime提示保留；最终结果树无Runtime Warning节点。

**本批进程退出**：从运行中libproc只读观察到 `74295:1791421747:891845`（首批）、`76985:1791421881:621431`（acceptance）、`78018:1791421998:143374`（boundaries），对应 `h-due-*-process-observed.json` 与 `h-due-*-process-checks.json`。三个原内核启动身份均已不存在，各批前/后及收尾同路径进程为空；不是只凭同路径消失判定，也不据此消除历史未知副作用。

**指定 Cursor verifier 材料已准备，复核未执行**：当前工具元数据无该入口，未认证、未用其他代理替代。材料为本轮用户原始授权（仅最终save、不动事务/安全/产品行为）、上表最小影响、三个生产文件实际差异、两个新测试、原 ModelChanges/assignDue 与H四层测试、上述源码摘要、结果树/逐阶段输出/进程记录。需独立核对：默认/函数引用及context回退兼容；真实生产Void回调确实贯通；保存依赖失败、回调返回和自然回显的证据边界；预保存/嵌套提交者及两项AX已知失败没有被扩大豁免。该复核缺口仍开放。

**并发收尾阻断**：上述运行结束后，其他任务新增习惯命令/修改服务并扩展 RoutineRepositoryProtocol（提供兼容默认实现）与 SwiftDataRoutineRepository；主代理检查差异，未覆盖或修复这些非H修改。H五个变更文件及原事务/截止路径未变，但全源码集合已变化。补跑完整QA目标及H/提醒/日期短回归，`h-due-concurrent-check.xcresult` 在编译阶段失败：新 `RoutineMutationService.swift:27–28` 从非隔离上下文读取 `ModelChanges.CommitFacts.save/phase`。该批申请/锁后/运行后源码摘要均为 `da97ec8965c4316acc084b75ca1f15a07818d06a71a5c4a3177a37f6c021ed2e`，xcodebuild=65，没有XCTest运行或新测试进程，不计入49次。runner的codesign=0仅核对先前QA包，不证明失败版本构建成功；`sessions: missing XCTest stdout` 亦如实保留。原锁仍在单次900秒预算内立即取得，前/后/收尾同路径无残留。

**静态收尾**：本批5个相关Swift文件严格局部SwiftLint、工作区/暂存区差异及新增文件空白检查通过。并发变更前工作流和静态门禁通过（含231项隔离脚本测试），保存于 `h-due-workflow.log` / `h-due-static-final.json`；最终全工作区重跑则因并发 `CommandExecutionRun.swift` 508行超过500行而失败，见 `h-due-workflow-final.log`、`h-due-static-closeout.json`，其余静态项通过。文档收尾后 `h-due-workflow-concurrent.log` / `h-due-static-concurrent.json` 再次确认同一阻断，不能将旧绿结果改写为当前全部通过。Swift运行证据仅来自上述正常PrivacyQA；未以会启动另一普通宿主的auto/swift profile代替隔离配置，原runner未修改。下一次最终全工作区验收须待并发工作修复其编译/行数门禁后，以当时源码身份补跑受影响短回归；这不要求重做H已证明的接点设计，也不关闭指定复核和整体partial。

**失败层级限定**：A 注入接点已贯通；B **真实详情链已到达最终保存依赖；该依赖的合成失败触发原回滚，并验证了自然回显和同宿主重试。** 错误在依赖闭包内、实际context.save之前抛出；C SwiftData自身save抛错与真实磁盘故障未直接验证。不得据此称所有截止失败路径通过或关闭两项嵌套 AX。原 H/K/L、真人/VoiceOver、低版本及其他历史缺口独立保留；不操作用户数据库、系统剪贴板/偏好、签名权限，不提交、推送、安装或发布。


### H 当前工作树收尾验证（2026-10-08）

**partial，用户未接受整体交付。** 本轮仅核对和验收，未改生产、测试、runner或索引；未启动Gallery、桌面应用入口、真实磁盘故障／密码修复或新人工矩阵。原H27方法／49次（47通过、2精确已知失败）与Stepper21／46分别保留原版本效力，不能当作本轮全量结果。

**影响与选择**：与H通过包 `h-due-acceptance-after.json` 对比，起点全源码新增／变化30路径，但 TodoScheduleSectionView、setDue/persist、ModelChanges/ModelRollback、assignDue、H测试与支持代码均逐文件摘要相同；与Stepper最终焦点包相比，公共Stepper、两处剪贴板数值消费者及其测试／支持也未变。直接路径不重新设计，重跑用户指定的恢复、默认、旧签名、预保存、嵌套提交及焦点生命周期。共享影响为 RoutineRepositoryProtocol 新增默认nil上下文及按ID查询、SwiftDataRoutineRepository 的对应实现；旧setRemind写入口未变，补选原普通／重复事项提醒与仓储回归。DayBoardMutations+Capture 的旧习惯标题入口被并发任务改接 RoutineMutationService，另选 `TaskTitleMutationTests/routineAndNotesConsumersRetainTheirOriginalSemantics()`，只核对、不修其业务。其余命令状态／搜索接线及新增51个文案键不在H／Stepper调用链，原文案键未变；它们仍参加完整编译，不排除源码。

所有本轮产物均在 `build/Controls10P/h-stepper-closeout-*`：

| 批次 | 完整目标与真实运行 | 源码／结果边界 |
|---|---|---|
| build | build-for-testing退出0，严格验签0；完整应用及测试目标成功，没有启动测试进程 | 申请／锁后／结束均 `fb65feb0131cefa17734a7ea298867c3283f1c7d87082c76222e27ba880ed1e6`，1269文件；原Modification已带@MainActor且原save/phase隔离错误解除。 |
| core | xcodebuild=0、codesign=0，18方法／28次全部通过，0失败／跳过／已知失败／Runtime Warning，所有请求选择均命中 | 开始同上；运行中并发新增RoutineCommandTestSupport、RoutineCommandTests，结束摘要 `133d9825bcc63d2c44601947a308c315d2787ff32af528e076fd08df8e25260d`。新增文件不被本批调用、没有顶层运行或改动共享支持；保留局部证据，不宣称整个结束版本重新编译通过。 |
| shared | xcodebuild=65，summary为unknown／0测试，无新测试进程 | 新RoutineCommandTests.swift:55的expect宏展开报 `operator can throw but expression is not marked with 'try'`，对应 `facts.savedTagIDs == expected && TagIDList.parse(try fixture.stored().tagIDs) == expected`。不是原Modification错误；未修改该并发文件。 |
| resumed | xcodebuild=65、summary unknown／0测试，无测试进程；完整目标未通过 | 前一缺try已由并发任务改为先读取storedIDs，核对后才补跑；新 UnifiedSearchRoutineTestSupport.swift:19:53 报 `value of type 'ContentQueryDateContext' has no member 'now'`。本批申请／锁后／运行后均 `b3b69631ec8b436953e24478d895ec6e1c531016276383544e9430818271f4bd`，不在同条件下重试。 |
| remaining | 完整编译／验签成功；7方法／10次：7通过、2精确已知失败、1非预期失败 | now修正后才重跑，前后稳定b5d4b2bc…b2d0f6；xcodebuild=65为下述旧习惯Bool断言失败，codesign=0。 |

core中H及原依赖为12方法／18次：DetailDueSaveTests全部7／9（AXPress和原生鼠标普通失败恢复／自然回显／同宿主重试、Void同步返回、默认未注入、旧函数引用、预保存、外层提交者、实例隔离）；两个精确预保存选择2／2；assignDue兼容1／1；原普通／重复事项提醒失败恢复及重试1／4；日期双语原保存1／2。Stepper为6／10，详见原Stepper补记。参数次数只按结果树，不增加内部动作次数。既有合成最终依赖失败证据不证明SwiftData自身save抛错或真实磁盘故障。

**剩余项实际补验**：resumed的now错误由并发任务改为显式DayKey日期后，才运行remaining。完整正常目标编译及严格验签成功，7个选择全部命中，7方法／10次中5方法／7次通过、1方法／2次Expected Failure、1方法／1次非预期失败，0跳过／Runtime Warning。通过项为原提醒emptyOpen／shortcuts两方法四次及仓储missing／check／fetch三方法三次。两项 `outerTransactionAXClearRequiresOriginalDisplay(due:)` 的false／true均仍准确落在DetailTimePickerTestSupport.swift:29:13的候选0≠1；模型恢复、零实际save继续普通断言，没有扩大豁免或意外通过。shared/resumed的零命中尝试保持原记录，不计本批次数。

**并发消费者新增回归**：`TaskTitleMutationTests/routineAndNotesConsumersRetainTheirOriginalSemantics()` 在TaskTitleMutationTests.swift:101:13的旧editRoutineWithSyntax Bool要求失败，其他断言无新增issue。源码原因可核验：DayBoardMutations+Capture.swift:99改为返回Modification.saved；RoutineMutationService.swift:25–31在外层尚未提交时为pending，afterCommit才置savedLocally，而测试在外层ModelChanges.transaction内部调用旧入口。旧工作已执行的Bool与新saved含义不同；不据此推断最终数据未保存。该项属于并发习惯入口兼容回归，不归入H普通恢复／Stepper或两项AX豁免，不修改命令业务或测试。remaining的xcodebuild=65来自这一断言，不能称编译或签名失败。

**后续兼容修复引用（2026-10-08）**：上述Bool阻断及旧504行门禁状态已由[习惯命令权威修复记录](unified-search-commands.md#旧习惯标题-bool-嵌套兼容修复2026-10-08)更新：原断言严格通过，当前494行及完整QA编译/验签通过。具体新证据只维护在该记录；本节旧包、两项AX与指定复核缺口不改，不扩大H／Stepper通过范围。

**源码有效性**：shared结束882d9b8f…737d4b，随后修正缺try并新增UnifiedSearchRoutineBoundaryTests／TestSupport，resumed稳定于b3b696…版本但编译失败。修正now后，remaining申请／锁后／运行后均为 `b5d4b2bc39d482b5818bc6980a7bfd427d9fcf599e3707a81e305ad6b9b2d0f6`，完整目标已编译并运行。这些新增／修正仅在独立习惯命令测试和支持，H／Stepper及本轮旧消费者、事务、仓储源码相对core前未变。因此core18／28对应当前局部路径；remaining对应当前完整编译及所选运行，旧编译错误不再是当前阻断。原H／Stepper未选中矩阵只保留各自历史效力，不称本轮全部重验、不累加成全应用总数。

**最终并发差异与停止边界**：remaining结束后源码变为 `aa758b1123857a884257ebe5ea2a5c896c84826cdf47dee3002bd19bc47496c8`（见final.json／final-checks.json）。六个变化路径为CommandExecutionRun、DayBoardMutations+Capture、RoutineCommandAdapter、RoutineCommandQueries、UnifiedSearchRoutineInteractionTests、RoutineCommandTestSupport。命令运行提取共同记录逻辑后为504行，仍越500；Capture仅新增空白输入拒绝，不改变本次非空输入的.saved失败路径，其严格局部SwiftLint已补跑通过。其余为独立习惯命令适配／查询及新测试支持，不在H／Stepper回归调用链。

本轮不追逐这些并发功能继续编译：完整目标成功严格限定b5d4b2bc已测版本，aa758b整树编译未验证；当前H／Stepper未变路径和两项AX的局部证据保持，新习惯Bool失败也只作为已测版本失败证据，不宣称空白检查已经运行验收。最终严格验签0核对remaining产物，两批内核启动身份均退出、同路径无残留；工作区／暂存区及未跟踪空白检查通过，索引未变。最终工作流及static确认同文件504行仍失败，其余静态项和231项脚本测试通过。

**隔离、产物与进程**：原完整正常PrivacyQA、`build/PrivacyQA-Controls10P`、com.areachain.privacy-qa、local/ad-hoc、生产entitlements、LSUIElement=NO、串行与六项真实钥匙串变量清除保持。原build/.build.lock单次900秒预算，build等9.07秒，core/shared/resumed/remaining立即取得；锁后身份复核不变，结束再记摘要。build/core及remaining的新编译产物严格验签成功；shared/resumed的codesign=0只核对前批遗留包，不能证明这两批失败版本成功。core由libproc观察到PID/内核启动身份 `83947:1791422652:855302`，以及remaining的 `86644:1791423021:875190` 均已明确退出，各批前后及收尾同路径无残留；build/shared/resumed没有测试启动。额外只读验签等待原锁34.74秒。只读进程检查没有附着、激活或启动应用。

**runner原始状态**：core的execution.json仍为complete/runtimeVerified=false，保留 `sessions: missing batch session evidence` 和 `source changed during test; evidence not final`；shared保留results非通过、missing XCTest stdout、编译失败及源码变化；resumed保留前述编译／无stdout错误，源码前后一致。remaining也保留complete/runtimeVerified=false、results非通过、missing batch session evidence和泛化test/build/signature failed；其codesign=0、真实XCTest已运行，不能将泛化错误文案当编译失败。独立remaining-selection-check.json确认7选择全部命中、7通过／2已知／1失败。未改旧execution.json、未伪造BEGIN/END。非Gallery的18／28由本批summary/tests、所选方法命中、XCTest标准输出、构建退出和独立process-observed/process-checks交叉核对。

**门禁与指定复核材料**：七个H／Stepper及四个受影响共享Swift文件严格局部SwiftLint通过；工作区／暂存区差异检查通过，索引持续为空（e3b0…摘要）。工作流及static初检准确失败于CommandExecutionRun.swift的508行超过500行，其他静态项及231项脚本回归通过；未压缩并发业务、删注释、提高门禁或降低并发检查。最终文档后门禁以 `h-stepper-closeout-workflow-final.log`／`h-stepper-closeout-static-final.json` 为准。指定Cursor verifier工具仍不可用、未执行，不以其他代理代替；材料沿本节用户范围、origin/各批before-after摘要、`h-stepper-closeout-review.patch`、实际结果树、原始日志和进程记录更新，需核对默认兼容、依赖失败层级、源码有效版本、两项AX及新增习惯Bool回归。原人工、H/K/L、SwiftData自身失败和其他历史缺口全部保留。无提交、推送、安装、发布或真实数据／系统剪贴板／个人偏好／签名配置／权限操作。

## 第十阶段 G：日历窄周布局修复

2026-10-05，仅 CalendarPage、CalendarWeekBoard 和 DaybookMetrics.WeekBoard 的布局/可见性变更。原七列、日期键、选择/检查/投放回调、列内纵向装配、页面层焦点协调均保留；公共导航、任务行、保存、scope 与羽化未改。使用说明与组件目录同步说明横向浏览。

**修复前测量**：`build/Calendar10G/baseline-measured.xcresult`、`baseline-diagnostics` 和 `baseline-images` 保留错误基线。420pt 生产页的下一周按钮 x=739.5、宽28、maxX=767.5；日期列头从 x22 到末列 maxX761.5，任务列146pt、空列65.5pt。直接周宿主420pt也从 x=-79 延伸到约500，证明是七列固有宽度传播而非导航自身样式。单列长标题+优先级+9:30时间测得内容至少240pt；240pt标题只剩5pt，280pt标题45pt、时间70pt，原48pt操作区保留。因此集中最小列宽280pt，七列加6×8pt间隙为2008pt；高于该宽度等分，低于时只有列区原生横滚。正常1000pt原图与420pt错误图保留，新增横向内容不作为页面越界。

**隔离及过程**：完整正常应用/测试目标、`build/PrivacyQA-Calendar10G`、`com.areachain.privacy-qa`、local临时签名、生产sandbox entitlement、LSUIElement=NO、六项真实钥匙串变量清除、原build/.build.lock互斥和串行测试。起点文件/暂存哈希见 `build/Calendar10G/source-before.json`。首次选择器零命中只计编译；随后基线4方法中，中文两次被焦点前提阻断，英文两次复现已知越界。最小修复 `minimum.xcresult` 双语×浅深色4次严格成功。`layout.xcresult` 的日期焦点整套与滚动装配通过，消费者旧屏外点击及新测试错误的“今天”前置条件失败，测试随后显式展示目标并修正序列，未放宽边界。`corrected.xcresult` 因并发 ModelChanges.swift 的主actor默认闭包错误在编译阶段停止，零测试执行；本轮未回退或排除并发源码。

**最终布局复测**：`final-layout.xcresult` 的 CalendarWeekLayoutTests / CalendarWeekConsumerTests 为8方法/14次，全部通过，无失败/跳过/已知失败。直接420pt、嵌入480pt内容宿主覆盖双语×浅深色，原生目标横向滚轮可从第一列到末列，选择与导航不随横滚改变；键盘屏外换日、Return检查归属、前后周/今天、跨年/闰日、快速连续外部选日、月周重挂均成功。280pt列中英文标题宽45/56pt，时间70/59pt，更多按钮x242、宽22，严格边界和互不重叠通过。等宽列在2100→2009→2007→420→2100的真实resize后，原七列NSScrollView及七个浮层对象保持身份。

真实 MainSplitWorkspaceView 两语言宿主（en/light、zh-Hans/dark）从780→1200→2400→780pt resize，周导航/周列实际内容视口分别520/940/2140/520pt、x244；导航宽度始终匹配视口，选中日完整可见。实际工作台修复前尚未取得运行测量，旧失败定位依据独立页面与直接周宿主，不把修复后的工作台数据冒充前置基线。

**过程失败保留**：`layout.xcresult` 为23方法/44次，20方法/38次通过、3方法/6次失败；失败来自旧屏外点击、测试错误的今天前置条件及直接clipView偏移后的可见性检查。最终用例显式展示原点击目标、修正今天序列，并用原生横向滚轮到端点，保留日期/边界/零写入断言。`corrected` / `updated-target` / `resumed` / `interface-resumed` 四包先后被并发主actor、事件闭包签名和新增事务测试的try错误阻断，均未计运行通过；并发任务自行修复后才恢复完整目标，不排除文件或改保存实现。Debug首轮同因失败，恢复轮遇原锁忙取消，最终构建结果另记。

八个本轮Swift文件严格局部SwiftLint通过；最终静态与扩大回归结果见下方补记。使用static配完整隔离QA，不运行会扩大到非QA宿主的auto/swift测试。`current-images`保留完整独立页面、各语言主题首末端和真实工作台缓存图；工作台侧栏的AppKit合成层缓存为空白，不将其视为完整窗口合成器证据。原始xcresult保留，导出诊断仅保留本轮文本，重复系统logarchive导出副本已清理。前期检查时暂存区哈希一致；收尾时检测到外部并发暂存（包含本轮文件），本轮未执行stage/unstage或撤回该状态。公共DaybookScroller/DaybookScrollScope内容哈希保持，ModelChanges/BoardEvents等并发差异保留。

**最终扩大回归**：`final-regression.xcresult` 25方法/45次全部通过：CalendarSpanConsumerTests、ScrollAssemblyConsumerTests、CalendarMonthNavigationTests、DateScheduleCalendarIsolationTests、DaybookScrollLifecycleTests、DaybookScrollFeatherLifecycleTests、DaybookScrollFeatherOwnershipTests。加上 `final-layout.xcresult` 的8方法/14次及 `drop-selection-rule.xcresult` 的1方法/1次，最终合计34方法/60次，无失败、跳过或已知失败。前次首次按键、原生组合文本、有效编辑器、草稿、跨窗口、零额外保存均回归；保存失败选择规则是纯规则证据，不能当作真实拖放失败路径。七列以具体任务行/日键追到各自NSScrollView及浮层，纵向事件保持其他列和横轴偏移，横向事件保持七列纵向偏移，重挂/resize/跨周后没有新增外层纵向浮层。QA `codesign --verify --deep --strict` 通过。既有辅助功能弃用、actor及系统桥接警告保留，不改变断言或测试目标。

**最终构建与静态门禁**：`./scripts/build.sh --no-wait` 的 `debug-final.log` 构建成功并通过静态验签，沿已有development配置，staticSignatureVerified=true、hardenedRuntime=true、distributionReady=false；不代表系统认证或发行。严格局部SwiftLint、static质量门禁（223项脚本回归）、工作流与工作树/暂存区差异检查通过，检查器本轮未改。收尾检测到并发App测试启动隔离编辑后，追加 `bootstrap-smoke.xcresult`：首次方向键与窄周可达性2方法/8次重复验证全部通过，最新QA包再次静态验签通过；不将重复样本累加为新覆盖，也不把本轮结果推广为整个并发事务改动的完整验收。

指定 Cursor verifier 当前不可调用，保留复核缺口，不认证或替换。缓存图、程序化横滚、合成原生键盘/滚轮/滑块事件分别计证据；真人触控板、真实拖放会话与窗口合成器像素尚未取得，不据回调或静态接线宣称完整拖放验收。未安装、发布或操作真实数据、系统偏好、签名配置及权限；完成后停止。

## 第十阶段 F：日历月周切换后的键盘焦点恢复

2026-10-05，生产只修改 CalendarPage：将 `spanPicker` 分支内的 `onChange(of: span)` 移到页面稳定的根 GeometryReader 后，实际范围变化仍只赋值 `keyboardFocus = .grid`。selectedKey、listFocusID、草稿、日期规则、检查器投影、保存和滚动路径不变；不增加键盘监视器，不调用 endEditing 或 makeFirstResponder。顶栏原显式 grid 赋值保留，因此菜单重选当前项仍恢复网格，分段同值重选仍保留列表路径。

**复现与根因**：完整当前目标的 `build/Calendar10F-reproduce.xcresult` 实际命中原 `windowGridAndListKeyboardPaths()`，1 次已知失败。仅 XCTest 运行的临时只读诊断记录：月列表 Return 后 keyboardFocus=list、listFocusID=选中日首项；切周时原 picker.disappear、新 picker.appear 均发生，picker.change 未发生，span=week 但 keyboardFocus 仍为 list。selectedKey 保持 2026-09-30、检查目标及 listFocusID 保持首项，firstResponder=NSWindow（非原生文本编辑器），第一次右键仍停在 9 月 30 日。原 Escape 将业务焦点恢复 grid 后，同一路径右键才进入 10 月 1 日。源码和实测共同确认观察者随条件分支卸载遗漏协调；不是 firstResponder 未返回窗口。最初 `baseline.xcresult` 因方法过滤少了括号零命中，不计作基线通过。

**最小对照**：`build/Calendar10F-minimal.xcresult` 的同一窗口方法严格通过。临时诊断记录 page.change 执行、keyboardFocus=list→grid，listFocusID 和 selectedKey 在切换当下不变，第一次右键直接进入 2026-10-01，Return 进入／检查该日相邻事项，Escape 沿原路径返回。原已知失败改为严格成功断言，移除补偿 Escape，但保留“切换后第一次方向键”要求。旧第四阶段失败说明和本次复现包保留；临时诊断及生命周期回调随后全部移除，最终生产差异仅移动原协调并说明原因。

**最终焦点回归**：`build/Calendar10F-focus-regression.xcresult` 为 **11 方法／21 次全部通过，零失败、零跳过、零预期失败**。直接挂载原 CalendarPage 和 WorkspaceHeaderBar，复用 CalendarSpanTestSupport。非嵌入 1000/420pt 分段用窗口鼠标事件；嵌入 1000/480pt 用真实顶栏直接／收纳菜单及其原 NSMenuItem 动作。菜单 helper 的 Escape 仅退出系统追踪，动作派发之后第一个日历按键仍为方向键；不以菜单程序化动作冒充真人选菜单。

| 边界 | 本轮实际证据 |
|---|---|
| 两种入口与双向切换 | en 浅色宽／zh-Hans 深色窄配对：月列表→周后第一次右键 2026-12-31→2027-01-01；周列表→月后第一次左键原路返回，切换本身保持选中日。分支重挂后仍立即生效。 |
| 网格／清单有效范围 | 原 CalendarGridKeys 仅 grid 启用，文本编辑及其他窗口事件继续放行；月清单仅 list 接焦点 Binding，周清单仅 list 且选中列接入。真实 Return、下键和再次 Return 确认首项及第二项次序／检查日期；Escape 后上下键仍 ±7 日。其他窗口及卸载事件没有改变日历日期或检查目标。 |
| 空日与重选 | 空日重复 Return 不产生检查目标或假列表焦点，随后第一次方向键仍换日；月范围空日检查投影为空。分段重选当前项后下键走清单第二项，菜单重选后下键走网格 +7 日，各自原行为保持。 |
| 输入与草稿 | 捕获输入随周布局卸载后 firstResponder 自然回到窗口，往返草稿原样保留。仍挂载的顶栏原生编辑器在月／周切换后保持同一 firstResponder；方向键移动光标，setMarkedText 合成组合文本期间方向键／Return 不换日或进入列表。原显式捕获 Return 仍只创建一次。 |
| 生命周期与数据 | 第二窗口分别覆盖 grid／list，原窗隐藏重开、页面卸载后事件均不误消费；共享导航在夹具清理时恢复。所有只切换／导航场景保存通知为 0，4 条事项与 1 个标签快照不变、手记数为 0、context 无待保存变化。 |

**隔离与证据位置**：macOS 26.6.2（25G83）arm64，完整正常应用／测试目标，独立 `build/PrivacyQA-Calendar10F`、`com.areachain.privacy-qa`，local 临时签名、生产 sandbox entitlement、LSUIElement=NO；原 `build/.build.lock` 非等待互斥、清除六项真实钥匙串变量、串行焦点测试。仅内存合成资料和随机偏好，未排除并发源码，未直接打开 QA 或日用应用。复现／最小对照／最终焦点 diagnostics 保存在同名 build 目录；原始工作区及暂存差异摘要见 `build/Calendar10F-source-baseline.json`。

**相邻回归与最终门禁**：`build/Calendar10F-adjacent.xcresult` 为 **20 方法／30 次全部通过**，包含 CalendarMonthNavigationTests、CalendarWeekConsumerTests、原周列头命中／焦点、DateScheduleCalendarIsolationTests、DateScheduleLifecycleTests、日期选择器导航／窗口按键、五项相关输入／组合／撤销方法，以及周列独立滚动目标和日期更新／resize 冒烟。与最终焦点包去重合计 **31 方法／51 次通过，失败 0、跳过 0、预期失败 0**；复现包与最小对照不重复计入。全图像矩阵明确未运行，原窄周已知断言仍存在，不计为已通过。

三个本轮 Swift 文件严格局部 SwiftLint、`python3 -B scripts/quality_gate.py --profile static --format json`（含 222 项脚本测试）、`python3 -B scripts/check_workflow.py`、工作树与暂存区 `git diff --check` 均通过；检查器未修改。按隔离范围使用静态 profile 加上述完整正常 PrivacyQA 定向测试，不调用 auto/swift 全量非 QA 测试。QA 包 `codesign --verify --deep --strict` 通过；`./scripts/build.sh --no-wait` Debug 构建及静态验签通过，沿现有 development 配置，staticSignatureVerified=true、hardenedRuntime=true、distributionReady=false，日志在 `build/Calendar10F-debug.log`。保留既有 AppKit 辅助功能／actor 编译警告和 Debug 多架构 destination 提示，不把 QA ad-hoc 或 Debug 静态验签写成系统认证／发行。本轮自身只编辑 1 个生产文件、2 个测试文件和 4 个原文档；暂存差异哈希不变，前期滚动／搜索源码与测试保持起点哈希，期间并发统一搜索文档变化保留，未撤回他人差异。

**保留与停止边界**：只关闭“范围切换后列表业务焦点未恢复 grid”缺陷。420pt 窄周越界和周事项标题挤压的原断言／记录继续保留，未重跑全部图像矩阵；时间清除、搜索换行、安全输入及其他历史问题未修改。指定 Cursor verifier 当前无可调用工具，独立复核继续 partial，未重新认证或以其他代理替代；真人输入法／键鼠、VoiceOver 和低版本 macOS 未运行，合成 marked text 不等同真实输入法会话。完成此范围后停止，不提交、推送、安装、发布，不修改真实数据、系统偏好、签名配置或权限。

## 第十阶段 E：滚动边缘羽化定位与更新修复

2026-10-05，完整正常 PrivacyQA 应用/测试目标，`build/PrivacyQA-ScrollFeather10E`、`com.areachain.privacy-qa`、local 临时签名、生产 sandbox entitlement、LSUIElement=NO；沿原 `build/.build.lock` 非等待互斥、清除六项真实钥匙串变量与串行测试。仅合成内存资料/独立偏好，没有直接打开 QA 或日用应用。命令、日志和结果包在 `build/ScrollFeather10E`，工作区起点摘要为 `source-before.json`。

**修复前证据**：`baseline.xcresult` 的完整生产装配实际 ScrollView / DocumentView / NSClipView 均已记录身份，视口 300×240、文档 300×1200（flipped=true）。偏移 0 / 480 / 960 时羽化 selected=nil，状态始终 false/false；clip bounds 已发两次通知，didLiveScroll 为零，内容变化又发 document frame 通知。原因是观察器未找到目标，并且仅监听全局 live-scroll 无法覆盖程序化视口及内容尺寸变化。不是本例几何计算错误；保留原 3/4pt 阈值，不重写坐标语义。原失败包和 diagnostics 原文保留，不作为修复通过。

**实现**：公共装配把羽化放入已有持有 scope 的 modifier，唯一目标来源为 Host.currentScrollView。目标/clip/document 身份变化先移除旧 token，再读取初值；仅观察所属对象的 bounds/frame/live-scroll。Host/边界原布局复核保留，状态主队列合并发布并校验代次；解绑/无目标清零，拆卸先撤回调。共享通知开关只开启不关闭。显式开关通过固定透明原生背景容器装卸观察者，掩膜保持同一渐变类型，禁用时不透明，不再切换正文；公开参数、系统指示器、浮层绘制/拖动/Timer、AppKit 文本和业务均未改。旧静态结构断言因羽化转入 scope modifier 调整，五种参数、上游策略、运行身份继续有独立断言。

**阶段性证据**：`initial-fix` 5 方法通过。`feather-matrix` 因测试误写只读 accessibilityReduceMotion 环境而未编译；后沿原 DaybookSegmentedMotionTests 在测试进程替换公开 getter 并恢复，不修改系统偏好。`feather-matrix-compiled` 4 方法通过、3 失败：原生 document 替换夹具未标记 Host 布局，开关掩膜类型改变导致旧浮层释放，以及事件场景焦点未就绪（foreground=com.openai.codex，未发送事件）。前两项分别明确布局入口并继续诊断开关重排；`lifecycle-correction` 又因合成草稿非 Equatable 编译失败，改为比较所有相关字段。失败包均保留，最终证据另列。

`lifecycle-correction-compiled` 和 `stable-background` 的开关诊断显示 Host/起点/ScrollView 身份保留、区间曾短暂返回 nil；`stable-background` 中真实 Tasks/Diary 双语底部点击、直接 scrollWheel、窗口滑块和双语/减弱动态效果渐变通过。首次扩大 `final-regression` 共 51 方法，50 通过、1 失败、零跳过：失败为原 DaybookScrollNativeTests 的开启羽化两种调用形式在内容更新后重装浮层，是本轮回归，未放宽原断言。`notification-binding-only` 证实仅取消通知中的重复定位仍不足。最终将成对边界移到掩膜外侧，让渐变状态更新不再改变局部区间，同时通知只消费 Host 已确认绑定；实际浮层仍是 ScrollView 子视图，绘制/拖动代码不变。`boundary-outside-mask` 全部通过，开关诊断的 Host、起点与浮层身份前后相同；新增开关测试已恢复严格同一浮层断言，原 D 内容/resize/释放断言保持。

**最终验证**：`final-confirmed.xcresult` / `final-confirmed-summary.json` / `final-confirmed-tests.json` 为 **51 方法／81 次全部通过，零失败、零跳过、零预期失败**。完整原 D 选择器加本轮五个测试类；修复前及中间失败包保留，不计入最终通过。源码对应 `source-final-tested.json`，测试结束后生产与测试文件无变化；之后只有本轮文档和并发统一搜索文档变化。

| 验收点 | 最终证据 |
|---|---|
| 自动边缘 | 标准 1200pt 内容／240pt 视口，在 0／480／960 为 false/true、true/true、true/false；程序化滚动只等待主队列，不调用 checkEdges 或主动 layout。长→短→长、视口 500→180pt 溢出切换通过。 |
| 绑定与清理 | 并列双开、一开一关、嵌套内外、多窗口均按实际 document 内标记核对目标身份；替换、歧义、无目标、禁用、拆卸/重挂、旧目标通知及排队发布均通过。原生 document 替换测试显式触发原 Host 布局，不能声称无布局时任意 document 替换也有独立通知。 |
| 原 D | 周列每列1、甘特内外各1、Dashboard外层1／趋势0／热力图0；五种调用／三种上游策略、对象身份、内容变化、resize、拆卸与迟到安装保护通过。侧栏/Dashboard关闭羽化。搜索直连、ObjectPicker及精确+1／lease／旧source拒绝断言全部回归。 |
| 真实消费者 | TasksPage/DiaryPage双语明暗配对，上中下正确、底部条目可见并收到窗口单击；合成模型与未提交草稿字段无额外变化。Dashboard原日期导航和周/甘特选择继续有原测试证据。 |
| 视觉/事件 | en浅色、zh-Hans深色 × reduceMotion false/true，共12张静态缓存图保存于 `build/ScrollFeather10E/images`。中间红通道约0.946不变，上缘羽化样本约0.215、下缘约0.291；上下实际渐变已查看，尺寸和指示器保持。直接 scrollWheel 偏移80pt并自动更新；窗口命中滑块拖动及消费者单击通过。缓存位图不等于窗口合成器截图；窗口级滚轮、真人触控板/鼠标、VoiceOver及动画实时曲线未运行。 |
| 构建和门禁 | 完整正常 PrivacyQA 编译、QA `codesign --verify --deep --strict` 通过；`./scripts/build.sh --no-wait` Debug构建与静态验签通过，未安装/启动。11个受影响Swift文件严格局部SwiftLint、102项工作流定向、222项脚本回归、静态质量、工作流、工作树/暂存差异检查通过。保留既有辅助功能弃用警告与一条SystemPageHost QoS运行警告。 |

**关闭与缺口**：本轮 false/false、自动更新和浮层身份回归均已关闭。指定 Cursor verifier 仍无可调用入口，未认证或替换，整体独立复核/人工验收为 partial；下一项明确阻断为该指定复核及上述真实输入/合成器证据，不再以已修复的羽化状态为阻断。开始暂存区为空；期间外部操作暂存了阶段性内容，本代理未执行暂存/撤暂存，最终工作树包含后续修复，验收不能套用于旧暂存快照。未提交、推送、安装、发布，未改真实数据、偏好、签名配置或权限。

周布局、时间清除、搜索换行和其他历史问题不在本轮范围。



## 第十阶段 D：公共滚动浮层目标归属修复

2026-10-05，隔离环境为 macOS 26.6.2 arm64 / Xcode 26.6，完整正常 AreaChain 应用/测试目标；`build/PrivacyQA-ScrollOwnership10D`、`com.areachain.privacy-qa`、local 临时签名、生产 sandbox entitlement、LSUIElement=NO、六项钥匙串变量清除，原 `build/.build.lock` 非等待申请与串行 XCTest。仅合成内存数据、独立偏好和原生产宿主；没有直接打开 QA/日用应用或变更系统偏好/签名/权限。首次锁忙未执行，随后磁盘满导致 baseline 编译退出 73、测试零执行；用户释放空间后继续。原失败日志与各批准确命令保存在 `build/ScrollOwnership10D`。

**已复现原因**：`baseline-resume.xcresult` 命中 ScrollAssemblyConsumerTests 两方法/双语四次预期失败。周列的 Configurator 背景宿主分别位于独立绘制分支；上升到共同页面 NSHostingView 后，旧算法每次从兄弟列表起点递归，七次都选到首列，归属 `[7,0,0,0,0,0,0]`。甘特内层 Configurator 位于外层 document 分支，`enclosingScrollView` 第一条捷径已选中外层，内层候选尚未检查，归属 `[2,0]`。`baseline-native.txt` 保留每级父链、候选尺寸/内容框、选中对象和浮层父对象身份；旧失败没有删除。

**实现边界**：主要修改 Theme 的 Configurator/Host 与新增私有 scope；另将 ObjectPicker 原候选列表的一处私有装配改用该 scope，原因见下文。成对标记提供局部归属，相同目标复用浮层；目标丢失/更换、离开窗口和拆卸清理自己的装饰，代次/失效位阻止排队回调复装。不新建内容宿主，不移动业务状态。两重载的默认与指示器策略、浮层绘制/拖动/动画、AppKit 文本、羽化观察器均保持；消费者生产页面未为定位改结构。接口与测试入口见[组件目录](component-catalog.md#第十阶段-d公共滚动浮层目标归属)。

**阶段性验证**：`scoped-minimal.xcresult` 两方法/四次通过，周列 `[1,1,1,1,1,1,1]`、甘特 `[1,1]`。最初选择器省略方法括号未命中 Dashboard，未计其通过。`lifecycle-events.xcresult` 为 13 方法/33 次（30 通过、3 失败、0 跳过）：Dashboard 三方法/14 次及公共参数/更新通过；双语七列窗口命中自有浮层后的拖动通过。失败为测试误断言 NSScrollView 只有 clip 子视图，以及混用 resize 前后偏移：甘特 126.844pt 经 resize 原生取整为127pt；后改用浮层父链/弱释放，并把 resize 取整与横滚后精确偏移分开，未改生产几何。`focused-recheck.xcresult` 的生命周期与周/甘特共七方法/11 次通过，新增搜索两项失败另追踪。

**搜索回归定位**：首次兼容路径把结果展开后的 AppKit 只读正文 scroll 误当结果列表目标，这是本轮新回归，未归为历史。已恢复 document 内直连的原 enclosing 归属；公共嵌套仍只走成对 scope。测试也曾误把补全浮层的 Configurator 算入操作预览，现按原 UnifiedSearchOperationBoundary 父链识别。`search-scope-check.xcresult` 证实旧 ObjectPicker 说明区与候选列表并列，单背景直连无法可靠选目标，新解析按歧义拒绝安装；仅将候选列表原一处私有装配换成相同 scope，不新增接入、改业务或页面结构。`search-final.xcresult` 两项新归属/清理、原候选五项和原结果六项通过；共14方法中唯一失败是原 `blurMasksAndRefocusRequiresRead()` 的 buffer version 0→1 整值比较。`search-blur-original.xcresult` 在原锁内恢复 HEAD 的旧 make/update/layout/定位/装配及原 ObjectPicker 后，同一方法以相同版本差异失败（1项、零跳过），证明并非本轮桥接造成。为编译完整新测试目标只保留未执行的 scope/dismantle 类型入口及只读属性可见性，未排除源码；finally 按字节校验恢复当前两文件。该业务/测试不扩修。最终批次结果见本节续记。


**最终编辑后的验证**：`final-regression.xcresult` / `final-summary.json` / `final-tests.json` 实际命中 **42方法／66次运行：41方法／65次通过、1方法／1次失败、0跳过、0预期失败**。失败仅为上文已与旧桥接同场对照的搜索失焦版本断言。通过范围：DaybookScrollContractTests、DaybookScrollNativeTests、DaybookScrollerTests、DaybookScrollLifecycleTests、ScrollAssemblyConsumerTests、DashboardScrollTests、TaskListScrollTests、CaptureOverlayLayoutTests、UnifiedSearchScrollOwnershipTests、UnifiedSearchObjectInteractionTests；另含 CalendarWeekConsumerTests 的外部选择/禁用/多实例及 GanttInteractionTests 两项原生选择，原结果交互其余6项通过。没有排除正常源码，没有跳过焦点或归属断言。

| 本轮声明 | 最终证据 |
|---|---|
| 周列错绑关闭 | 双语均 `[1,1,1,1,1,1,1]`；按各日期真实任务行的 enclosingScrollView 对应目标。12/16/20/24/28/32/36项生成七种 knob 高度约227.83→75.59pt；14次窗口命中自有浮层后拖动，各列偏移约50.57→147.40pt，邻列不动。选日/resize 后身份及单浮层保持。 |
| 甘特错绑关闭 | 双语均 `[1,1]`，inner.enclosingScrollView 为 outer；2次窗口滑块事件令内层移动126.844pt，外层不动。缩窄后外横滚与内纵偏移精确独立；未新增横向公共滑块能力，外层装配仍保留。 |
| Dashboard 接入保持 | 三方法／14次通过，外层1、趋势/热力图0；正常/小/大视口、双语浅深色、空/有内容、更新/resize/重开/导航及三轴独立保持。 |
| 生命周期与兼容 | 自有 overlay 父链与弱释放、相同目标复用、目标替换、起点临时移除/恢复、歧义、并列移除、重挂、拆卸后迟到回调及跨窗口拒绝通过。五种调用×三种上游策略、长→短→空→长、草稿焦点/内容身份、无羽化默认及原系统指示器策略通过。 |
| 三类滚动证据 | 程序化 scroll/定位、直接 NSScrollView.scrollWheel、窗口 sendEvent 合成鼠标命中/拖动分别通过并记录；后两者不等同真人触控板或窗口级滚轮命中。 |

`final-native.txt` 保存目标/浮层身份、父链、视口/内容尺寸、16次核心滑块事件及 Dashboard 记录。九个相关 Swift 文件严格局部 `swiftlint lint --strict --quiet --no-cache`、`check_workflow.py`、静态 `quality_gate.py --profile static`、差异与未跟踪文件空白检查通过；检查器定向102项、完整脚本222项通过。完整正常 QA Debug 编译及 `codesign --verify --deep --strict` 通过（独立 QA 标识、ad-hoc）；`./scripts/build.sh --no-wait` Debug 构建与原 development 配置静态验签通过，hardenedRuntime=true、distributionReady=false，产物仅保存在 build。原弃用/并发警告及弱引用测试的 var 提示保留，不影响上述门禁。

**交接仍为 partial**：实现和本轮目标归属/事件/生命周期自动验收完成；指定 Cursor verifier 当前无可调用工具，按原规则保留独立复核缺口，不认证或替代。真人鼠标/触控板、窗口级滚轮、输入法/VoiceOver及窗口合成器像素未验。羽化观察器仍使用自己的旧定位，本轮显式羽化测试记录仍为 lastTop=false/lastBottom=false；羽化、周窄布局、时间清除等不修。下一项验收阻断是指定复核，以及另行处理原搜索失焦 buffer version 断言（旧桥接同样失败）；本轮没有把它改为已知失败或放宽业务。用户如另启滚动后续阶段，羽化定位仍是独立未关闭项。保留前期与并发修改，本轮不提交、推送、安装、发布或改真实数据、系统偏好、个人签名和权限；到此停止。

### D 收尾：搜索失焦版本契约校验与最终回归

2026-10-05。本次只修订 [UnifiedSearchResultsInteractionTests](../AreaChainTests/Features/UnifiedSearchResultsInteractionTests.swift) 及本工程记录；上文的失败、旧桥接对照和当时停止结论保留为历史。本次未修改生产搜索、滚动、输入、许可、隐私或统一搜索规范，也未修改共享测试 helper。

**契约核对与复现**：当前 [UnifiedSearchController.changed](../AreaChain/Features/Search/UnifiedSearchController.swift) 与[权威 §9.62](unified-search-commands.md#962-阶段-3a-3b3b普通设置共同提交的原生接线) 一致：仅 `invalidated && session.isMasked` 推进输入 buffer 版本，不换 lease、不清文本、不增加 privacyRevision；未遮罩模型重读不推进输入版本，privacyInvalidated 另走清空及隐私修订路径。[ReadSession](../AreaChain/Services/ContentQueryReadSession.swift) 的 receive / loseFocus 在 revokeReferences 已发送撤显示通知时不补发；resumeDisplay 只解除遮罩，必须重新 prepare / evaluate / publish。`closure-blur-baseline.xcresult` 在当前完整正常目标中单独复现原失败：只有 version 0→1 与旧整值相等断言不符，其余字段相同，确认是过时测试契约，未回退滚动修复。

**新增保护**：保留原隔离宿主、focus 通知和 session；以完整期望 buffer 断言 version 精确 +1，lease、text、privacyRevision、operation、selectingObjects、plan、planItem 均不变，并观察到恰好一次 `.invalidated`。遮罩后和 resumeDisplay 后均无保留结果，presentation 精确拒绝 `stalePermit`；恢复没有旧许可、自动读取、提交或查询修改。失焦前捕获 source 和有效结果版本，通过原 browse / actions.intent / actions.edit 入口验证旧请求被拒绝，原 reads / opens 计数和完整 CommandOwnedHost（含 query / operations / plan / execution）保持。重新发布后额外用“旧 source＋当前结果版本”排除仅结果版本过期的偶然拒绝；当前 source＋旧结果版本仍拒绝，当前双版本可选择并只记录一次合成 open intent，不打开真实记录。新增 `unmaskedModelInvalidationKeepsInputVersion()` 沿 `.boardDidChange` → refresh 验证普通模型失效及重读保持完整 buffer，只更新结果版本；原隐私锁定清空输入、撤结果、privacyRevision 增加的用例继续回归。

所有本次结果包、对应 `*-command.json`、`*-summary.json`、`*-tests.json` 均留在 `build/ScrollOwnership10D`，未覆盖旧包。仍用原 `run.py` 的 `build/.build.lock` 非等待互斥、完整正常目标、原 PrivacyQA 目录/标识、local/ad-hoc、生产 entitlement、六项真实钥匙串变量清除和串行事件。

| 本次批次 | 实际结果 |
|---|---|
| `closure-blur-baseline` | 1 方法／1 次失败，0 跳过；保留原 version 断言复现。 |
| `closure-focused` | 2 方法／2 次：1 通过、1 失败，0 跳过；本次新增断言误以为 presentation 抛 masked，实际 validatePermit 因许可已撤先抛 stalePermit。其余断言无失败；按源码修正精确错误类型，未改生产。 |
| `closure-focused-corrected` | 2 方法／2 次全部通过，0 失败／跳过／预期失败。 |
| `closure-lifecycle` | UnifiedSearchResultsInteractionTests 全部 8 方法／8 次通过，0 失败／跳过／预期失败，含原锁定、展开、分页、输入导航和 Tab。 |
| `closure-final-regression` | **43 方法／67 次全部通过，0 失败／跳过／预期失败**。原 42 方法／66 次完整命中并通过，加新增模型失效对照 1 方法／1 次；不累加前面的批次。 |

最终扩大批次只更换 `final-regression-command.json` 的结果包路径，逐参数核对原选择器与隔离参数相同；新增对照由原类选择器自然纳入。summary、设备层和 tests 树均无失败／跳过／预期失败；按 Test Case 去重，参数执行仅计 Arguments，不把 Runtime Warning 节点当作运行。**第十阶段 D 扩大自动回归通过**。完整正常 PrivacyQA 应用及测试目标编译通过，无源码排除，不额外重复发行、安装或日用构建。结果树保留 `DaybookScrollLifecycleTests.swiftUIRemovalRemountAndFocusedContentKeepIdentity()` 中 `SystemPageHost.swift:69` 的一条 QoS 优先级倒置运行警告；前面定向编译的既有辅助功能弃用警告也保留，未据此改变生产或测试时序。

源码证据为同目录 `closure-source-before.json`、`closure-source-tested.json`、`closure-source-after.json`：开始时记录已跟踪及未跟踪文件和暂存区摘要，最终批次前冻结测试源码，批次结束时核对除本工程记录外无变化。本轮目标测试 SHA-256 为 `6c8bdfea51e49c8dac50e893a8ada5e7d49bfcf0b5e58cabf8773e3b99d88e67`；527 个 `AreaChain/` 生产文件的路径→摘要映射（键排序、紧凑 JSON）的 SHA-256 为 `f2086187e41524f13451b04fcb2ee46ac01b662c1b80cc702cf594713047c22b`，前后相同。清单逐项包含 Controller、InputState、ReadSession、DisplayUpdates、DaybookScroller、DaybookScrollScope 与搜索消费者，确认本轮没有改变搜索或滚动行为，暂存区保持。

交付前再次检查发现 `UnifiedSearchFileSettingInteractionTests.swift`、`UnifiedSearchFileSettingRecoveryTests.swift` 在上述批次后有并发修改，只涉及未被本批选择的设置测试方法中的动作/断言；本轮没有编辑或回退它们。`closure-source-after.json` 单列这两个文件及前后摘要；本批选中用例、共享 helper 和全部生产源码仍与测试快照一致。扩大回归的通过结论对应 `closure-source-tested.json`，不声称随后这两个设置测试的修改已获完整重编译或运行验证，也不盲目重跑整批追赶并发工作。

最终检查：目标测试文件 `swiftlint lint --strict --quiet --no-cache`、`git diff --check`、`python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile static` 均通过；静态门禁包含当前工作区适用的 222 项脚本回归。证据为 `closure-workflow.log`、`closure-static.log`，测试文件最终编辑后已重新编译并完成上述隔离回归；文档更新不复用旧静态检查结果。

滚动归属已关闭的周列 `[1,1,1,1,1,1,1]`、甘特 `[1,1]`、Dashboard `[1,0,0]` 及安装/更新/resize/重挂/拆卸/迟到回调，均由原 D 选择器回归通过。指定 Cursor verifier 仍无可调用入口，未认证、未以其他机制替代；真人鼠标/触控板、窗口级滚轮、输入法/VoiceOver和窗口合成器像素缺口不因测试修正而消失。可以另轮定界下一项独立运行问题修复，搜索旧断言不再阻断；整体治理及人工验收仍为 partial，不等于全应用验收完成。羽化仍为独立未关闭项，本轮到此停止，不修羽化或其他历史问题，不提交、推送、安装、发布或变更真实数据、系统偏好、签名配置和权限。

## 第十阶段 C：Dashboard 外层垂直滚动接入（partial）

**2026-10-05 续验（以下结果更新上一轮状态）**：完整正常 `PrivacyQA-Dashboard10C` 的 `Dashboard10C-resume-compile.xcresult` 已完成 `build-for-testing`，应用与完整测试目标编译通过，未排除源码。开始检查时 `FileSettingCommandTests` 两处调用已由并发工作改为可编译表达式，本轮未修改该文件；原 `publishOnlyCompleteStatesAndLocalFactPrecedesObservationAndEffects()` 在 `Dashboard10C-resume-ownership.xcresult` 实际执行通过，原观察顺序和断言得到运行证据。该包另含事件前的生产 Dashboard 归属门禁，共 2 项通过、0 失败/跳过。

本轮继续沿原锁非等待申请、独立目录/标识、local 签名、生产 entitlement、六项真实钥匙串变量清除及串行 XCTest。只修改 Dashboard 两个测试文件和本节/组件目录/路由；生产仍为下方原有一行。测试先识别分区日期按钮和原生父链，再保留三个 NSScrollView 身份，更新/滚动后的检查不重新要求辅助节点可见。所有已执行场景焦点有效；未绕过锁或修改系统配置。

**实际自动回归**：`Dashboard10C-resume-regression.xcresult` 经 summary/tests 树核对为 32 个方法、53 次运行全部通过，0 失败/跳过/expectedFailures，包含 DashboardScrollTests、DashboardRenderingTests、DashboardInteractionTests、DashboardProjectionTests、DashboardProjectionEquivalenceTests、DaybookScrollContractTests、DaybookScrollNativeTests 和 DaybookScrollerTests。随后仅固定合成事项 UUID，消除同日活动排序造成的前后图差异；受影响 Dashboard 在 `Dashboard10C-resume-final.xcresult` 重新执行 3 方法／14 次全部通过。最后收敛大视口后，`Dashboard10C-resume-sized-final.xcresult` 再次完整编译并执行 Dashboard 3方法／14次通过。最终有效口径为 sized-final 包 3／14 加 regression 包未受影响的 29／39，仍为 **32／53**，不把重跑累加成额外覆盖。生命周期方法内部两次重开、每次三次布局/三档 resize 不计为独立测试；公共五种装配的上游策略内部循环亦单列为场景。

- **实际归属**：12 个参数场景及生命周期场景均为外层 1、趋势 0、热力图 0；仅外层隐藏原系统垂直条，两横层保留 false/false；羽化观察器为 0。无错绑，无需调整接入位置或公共搜索/拆卸机制。更新合成内容、反复布局、resize 后三个对象保持身份，原浮层实例不重复；重新创建窗口仍只有一个外层浮层。
- **滚动与内容**：程序化顶部/中间/底部严格核对合法偏移，最后合成活动或空态处于外层视口；大视口短内容不强求滚动。外层定向 scrollWheel 从零起点移动且两横层不变。300pt 宿主实际横层宽 268pt，趋势 document 328pt、热力图 739pt，分别移动 x=60／80pt，另一横层及外层偏移不变；正常/大视口横层无溢出另作记录。合成今日完成数 12/0、模型快照和无未保存修改断言通过。
- **窗口鼠标与安全导航**：原 NSApp/sendEvent 的滑块点击保持起点，窗口 mouseDown/Dragged/Up 使外层 y=0→约60.57pt，两横层不变。趋势及热力图生产按钮实际窗口点击分别传递测试今日 `2026-10-05` 与 `2026-10-03`，正确进入 calendar，控件中心命中不被浮层拦截；不点击默认活动/手记动作，导航状态用原 preserveState 恢复。这些是合成窗口事件；定向 scrollWheel、程序化 scroll 和真人触控板/鼠标不能混算。正文所有边缘的逐点命中与真人操作未全量覆盖。

**基线、视觉与过程记录**：`resume-baseline` 的 12 次参数运行均在最后活动定位处失败：SwiftUI 将活动分区标识传播至行，不能依赖原行标识；修正为最后一项合成标题及实际视口位置，未改生产辅助树。`resume-baseline-verified` 与固定身份后的 `resume-stable-baseline` 均为 1 方法／12 次通过，补齐原焦点和300pt条件下的定向滚轮证据；历史无焦点准备的单次未移动不抹除。每次临时撤回只移除自有一行，finally 按锚点恢复；DashboardView SHA-256 均恢复为 `66412d1ceac3460b75db1343d7f78b796efe5830c3bdf4cd276b42a86f3263f6`。没有恢复 HEAD 或改动暂存区。

`build/Dashboard10C-resume-images` 保存固定身份后完整的 72 对 PNG（12 个双语/浅深色/尺寸场景 × 顶中底 × 内容区/完整窗口），未裁剪错误区域；对应截图索引、原生身份、视口和 document 几何保存在结果包 diagnostics。已查看全矩阵联系图及正常/窄窗口原图，正常/窄视口分区布局一致；原窄布局截断保持，预期外层指示器可见性不同。完整像素不是逐字相同：除指示器外有悬停高亮差异；请求1200pt高度被系统分别约束为950／953pt外层视口，大视口不能按同尺寸整图比较。`resume-image-comparison.json` 和 `resume-geometry-comparison.json` 如实保留差异，不把不等尺寸或悬停状态写成通过。最后将大窗口夹具收敛到1200×900以补同条件证据；数次原锁忙均未启动构建，锁释放后 `Dashboard10C-resume-sized-baseline.xcresult` 的1方法／12次与 `Dashboard10C-resume-sized-final.xcresult` 的3方法／14次全部通过，0失败/跳过。最终 `build/Dashboard10C-resume-sized-images` 的72对完整PNG尺寸全部一致，12对完全相同，52对仅右侧指示器区域不同，8对另有可见悬停高亮差异。`resume-sized-geometry-comparison.json` 的180条对应记录完全一致，正常/窄矮/大视口的布局、分区间距、偏移与document尺寸保持。已查看顶中底联系图和原图；不把整图像素相等或缓存图当作窗口合成器屏幕证据。旧不等尺寸和随机身份图仍保留为过程证据，不计最终比较。

**静态与收口**：最终编辑后严格局部 SwiftLint、static quality gate、workflow 和工作区/暂存区差异检查通过；未跟踪测试文件亦纳入局部 lint 和空白检查。`Dashboard10C-resume-signature.json` 为 staticSignatureVerified=true、local、com.areachain.privacy-qa、hardenedRuntime=false、distributionReady=false，沿原 verify_app 执行 codesign --verify --deep --strict。人工鼠标/触控板、窗口合成器截图、指定 Cursor verifier 及历史独立问题仍不当作通过；第十阶段 A 第二处漏接现按实际归属与相关自动回归证据标为已处理；这不代表人工、指定复核和全应用验收完成。标题保留partial以反映这些独立缺口。未提交、推送、安装、发布、操作真实数据或系统配置，不进入历史滚动修复。

**上一轮历史记录（其中编译阻断与归属未验已由上述证据更新）**：

2026-10-05，生产仅 DashboardView 外层 ScrollView、原 frame 之前新增 `.daybookScroll(featherEdges: false)`。两横向图表、DaybookPage、分区布局、日期/导航/统计/读取和公共滚动代码保持。接口与保留的两类入口见[组件目录](component-catalog.md#第十阶段-cdashboard-外层垂直滚动接入partial)。

沿原 `build/.build.lock` 非等待申请、完整正常应用/测试目标、独立 `build/PrivacyQA-Dashboard10C`、`com.areachain.privacy-qa`、local 临时签名、生产 sandbox entitlement、LSUIElement=NO、六项真实钥匙串授权环境变量清除与串行 XCTest。只用 SettingsButtonTestSupport 的内存库、独立偏好和相对 DayClock 测试今日的 24 个合成事项（12 个完成）；不触发默认活动动作，导航状态沿原 preserveState 恢复。不直接打开 QA 或日用应用，不读取真实数据或修改偏好/权限/签名配置。

**修改前真实基线**：`build/Dashboard10C-baseline-resolved.xcresult` 的 8 个参数场景中 7 通过、1 失败，0 跳过。前两包 baseline / identify 的定位断言均失败：SwiftUI document 下没有分区 AX 标识；改从生产页面辅助树的日期按钮框与嵌套视口交叉识别，公共父链确认外层。未改生产视图层级或加定位容器。基线日志保存在 `build/Dashboard10C-baseline-resolved-diagnostics`。

| 原版场景 | 外层实际视口 | document / 内容高 | 定向 wheel 结果 |
|---|---|---|---|
| 960×640 嵌入，有数据 | 928×581 | 971 | 场景 2 为 y=80；场景 0 未移动并严格失败 |
| 960×640 嵌入，空数据 | 928×581 | 679 | y=80，空态仍需滚动 |
| 960×640 独立，空数据 | 928×532 | 679 | y=80，原页头保留 |
| 360×360 嵌入，有/无数据 | 328×301 | 999 / 693 | 外层 y=80，热力图 x=80，各自不串动 |
| 请求 1200×1200 的大窗口，空数据 | 1168×948（系统约束后的实际值） | 679 | 无溢出，y=0 |

三个原生对象初始偏移均为零；趋势和热力图的 enclosingScrollView 是同一外层，外层无上级滚动。原外层系统策略 vertical=true / horizontal=false，两横层 false/false，三者公共浮层均 0。两横层内容分别 328×95 与 739×95；360pt 宿主趋势恰好无横向溢出，不能据此宣称趋势横向移动已验。全部场景严格检查合成今日完成数 12/0 与 context 无未保存修改。上述为程序化原生定向 scrollWheel，非窗口命中或真人触控板。

**阻断**：最后基线探针补原 NativeSyntaxUI.prepareFocus、300pt 窄宿主和顶部/中间/底部 cacheDisplay 采集后，`Dashboard10C-baseline-complete.xcresult` 被并发 `AreaChainTests/Services/FileSettingCommandTests.swift:85,89` 的未处理抛错表达式阻断，测试未执行；没有修改/排除该源码。已有原版几何记录后才写入一行接入。`Dashboard10C-ownership.xcresult` 同样编译失败，接入测试 0 执行，不能当作功能失败或通过。

**最终静态/编译证据**：`build/Dashboard10C-qa-build.xcresult` 的完整正常 QA 应用 build 成功；这是应用编译，不是测试目标或运行验收通过。`build/Dashboard10C-signature.json` 经原 signing.validate_settings / verify_app 核对 staticSignatureVerified=true、local、com.areachain.privacy-qa、hardenedRuntime=false、distributionReady=false，包含 codesign --verify --deep --strict。三个本轮 Swift 文件严格局部 SwiftLint、`quality_gate.py --profile static`、`check_workflow.py`、工作区与暂存区 `git diff --check` 通过。检查器未改，脚本回归不适用；未运行发行构建、安装或真实系统认证。

**未完成门槛**：最终归属、去重、更新/resize/重开、顶部/中间/底部和最后活动可达、两横层独立溢出响应、滑块点击/拖动、内容点击/阴影命中、安全日期导航的生产回归均未完成。原 DashboardRenderingTests、DashboardProjection/Interaction、DaybookScrollContract/Native 定向回归尚未在最终代码执行。新增探针最终版本也未获得运行通过；原版单次滚轮失败仍保留，焦点准备后的结果不能猜测。缓存位图、前后视觉比较、实际屏幕和真人事件均未取得，不以编译或几何替代完整验收。

公共两个重载及默认值经源码核对未改，尚无 Dashboard 错绑证据，不能推断必须修改公共搜索；未加防回退规则，不改变既有检查器。指定 Cursor verifier 缺口保留，本轮公共契约未改，只做局部差异自查。第十阶段 A 第二处漏接**尚未关闭**；当前直接阻断是完整测试目标无法编译，其后仍必须验证实际外层归属。周列/甘特、窄周、时间清除、搜索换行、安全输入、手记气泡和原羽化等历史问题继续独立登记。本轮停止，不提交、推送、安装、发布。


## 第十阶段 B：四象限标题预览纯装饰接入

2026-10-05，仅 QuadrantTitleLayout.swift 的 QuadrantTitlePreview 背景/描边接入既有静态 rowBubble；契约及下一处 Dashboard 外层滚动线索见[组件目录](component-catalog.md#第十阶段-b四象限标题预览纯装饰接入)。不改公共组件、其他消费者、摘要算法、复制/反馈、定位或历史问题。

验证沿完整正常应用/测试目标、`build/PrivacyQA-Quadrant10B`、`com.areachain.privacy-qa`、local 临时签名、生产 sandbox entitlement、LSUIElement=NO、原 `build/.build.lock` 和六项钥匙串授权变量清除。合成摘要刻意不同于全文；直接生产预览/overlay 回调只记录次数与字符串，页面只安全悬停，不点击默认 NSPasteboard 路径。新测试不复制完整预览业务，旧装饰复用 OriginalRowBubbleSurface 的冻结默认绘制。

修改前过程：`Quadrant10B-baseline.xcresult` 被并发 PreferenceObservation.swift:51–57 的显式 self 编译错误阻断，0 用例执行；并发自行修正后重试。本轮测试探针与旧私有类型重名导致 `baseline-ready` 编译失败，已仅重命名本轮探针。`baseline-consumers` 13 项中 11 通过、2 失败、0 跳过；两处失败是新断言误将生产标识传播后的 AX 文字/提示框当成 260pt 装饰框。修正为直接生产预览布局框和完整像素定位对照，标识及点击严格断言保留。一次构建锁忙未启动测试，未抢占并发验收。

补跑 `baseline-geometry` 的 overlay 参数组 3/4 通过、1/4 悬停回调未达；该次按方法名过滤的页面用例零命中，不计通过。测试改为原 SystemPageHost.settle 完成布局后向实际外壳中心发事件，并按整个 QuadrantLayoutTests 类运行，未修改生产时序或削弱断言。`Quadrant10B-baseline-verified.xcresult` 8 项全部通过、0 失败/跳过，覆盖完整四象限类与 overlay；此前直接预览成功项仍保留原版证据。

**最终通过**：`build/Quadrant10B-final.xcresult` 的 28 项全部通过，0 失败、0 跳过、0 expectedFailures。实际命中 QuadrantPreviewSurfaceTests / InteractionTests / OverlayTests、QuadrantLayoutTests、DaybookFloatingSurfaceTests 与 RowBubbleSurfaceTests，含原 ControlsPreview。完整正常应用与测试目标编译通过；本轮未为并发问题排除或修改无关源码。

- `build/Quadrant10B-before` / `after` 共 72 对完整 PNG、72 对 JSON 全部逐字节一致；画布包含圆角、居中描边和完整外缘，冻结装饰另以越界内容验证阴影只施加在背景形状。覆盖 en/zh-Hans、浅深色、长短/六行摘要、提示开关、普通/悬停/复制/复位、更新/重挂，以及 320×240、640×420 容器的上下/左右位置。短摘要提示关/开高 26/41pt，六行高 96/111pt，复制反馈高 26pt；宽度 260pt，原 padding8/6 保持。两语言/主题的普通、悬停、复位整图完全相同，复制边框仍为静态 90%／0.8pt。
- 原生 mouseMoved、sendEvent/postEvent down/up 路径严格验证内容/内边缘单击只调用一次，圆角外侧及阴影不扩大命中；复制反馈出现、正常复位、外部摘要更新和反馈中卸载/重挂不额外回调，onAppear 只在真实重挂增加。生产 overlay 显示摘要、转交不同的合成全文；原标识、零尺寸锚点和 offset 定位通过直接生产预览参照的整图校验。AX 标识传播到文字/提示，其框不当作装饰尺寸。
- 页面只进入/离开合成长标题，验证原单行、对应锚点、显隐以及任务、检查日、选择和上下文无未保存修改；没有点击页面默认复制，没有新增生产保存。缓存图已查看，包含英文浅色六行及中文深色复制反馈。上述合成原生事件和 Void 复制回调不证明系统剪贴板写入成功，也不替代真人或窗口合成器屏幕证据。
- 六个本轮 Swift 文件严格局部 SwiftLint、`quality_gate.py --profile static`、`check_workflow.py`、工作区/暂存区差异检查通过。窄规则/反例沿原检查器，最终检查器定向 99 项、脚本回归 219 项通过。静态验签复用 signing.validate_settings / verify_app，对本轮 QA 命令行配置核验：`Quadrant10B-signature.json` 为 staticSignatureVerified=true、mode=local、bundleIdentifier=com.areachain.privacy-qa、hardenedRuntime=false、distributionReady=false；另有 codesign --verify --deep --strict 通过。未另跑 development Debug、全量应用测试或发行构建，本轮完整正常 QA 编译已覆盖必要编译。

**范围与保留缺口**：生产差异逐字核对只有一处装饰替换和两个旧绘制属性删除；DaybookSurface、DaybookRowBubbles、QuadrantPage 与 DashboardView 哈希未变。既有 Cursor verifier、真人鼠标/VoiceOver、低版本系统和历史滚动/羽化/手记辅助树/气泡/复制缺口保留，不把本轮通过解释为全应用验收。Dashboard 外层 ScrollView 仍是下一处确定漏接，本轮停止。暂存区在并发任务中继续变化，本线程未执行暂存或提交，也未重置并发内容。没有系统剪贴板读写、真实数据、系统偏好、个人签名配置或权限修改，没有提交、推送、安装或发布。


## 第九阶段 E：两处标签色点接入

2026-10-05，仅 WorkspaceSidebarView.tagRow / TagManagementPage.tagRow 的 Circle、fill、frame 改为既有 DaybookStatusDot，分别显式传 8 / 10pt。颜色继续使用原 tagMark；侧栏隐藏色点辅助元素，管理行保留原颜色名称和 combine。公共组件、标签业务及其他生产组件未改。接口与第九阶段四类发现的当前状态见[组件目录](component-catalog.md#第九阶段-e两处标签色点接入)。

**原实现与最终验证**：原 PrivacyQA XCTest、完整正常应用/测试目标，独立 `build/PrivacyQA-TagDots9E` / `com.areachain.privacy-qa`、local 临时签名、生产 sandbox entitlement、LSUIElement=NO、原 `build/.build.lock`、六项真实钥匙串变量清除和串行事件。只用合成内存标签/任务及隔离偏好，不直接启动日用应用。`build/TagDots9E/baseline-final.xcresult` 的 6 项通过与 `baseline-actions.xcresult` 的最后一项通过合并，原实现为 **7 项／17 次通过，0 最终失败、0 跳过**。两处替换后 `current.xcresult` 同样 **7 项／17 次全部通过**；标识和命令保存在该目录的 current-tests.json / current-command.json。实际命中 TagDotConsumerTests 两方法、WorkspaceRenderingTests 独立侧栏/检查器、WorkspaceMenuConsumerTests 原颜色菜单/合并取消，以及 TagCatalogTests 使用计数和 TagRepositoryTests 创建/颜色/快照两方法；零命中的旧选择器不计入通过。

- 中英文、浅深色；侧栏 220/260pt、管理页 480/720pt，均高 760pt。短/长名称、未选/选中、六种颜色令牌、空值和未知值回退、管理页三个预设分类。侧栏原 liveTaskTags 排除预设，不为验收改变生产可见范围。实际色点横纵实色区域核对 8/10pt；管理行原合并节点为 AXUnknown，颜色名一次、标题与使用计数完整，未拆出色点辅助节点。
- 侧栏色点中心、标题区域和行右端的原生合成点击都选择正确 UUID，悬停/呈现/选择/取消改名无保存及模型变化。管理页色点区域通过原 NSTableView 选择；工具栏出现后重新取得行位置，双击原标题进入原字段，Escape 取消。一次合成 batchSetTagColor 沿原仓储保存一次，原两个宿主自然回显、未选标签及预设颜色不变。原颜色菜单用例另外验证生产菜单动作与多选范围；未操作真实标签、偏好或剪贴板。
- **152 对完整窗口 PNG 解码后逐像素一致，304 对几何/辅助记录一致**，无缺失或多余文件，见 comparison.json。产物沿原沙盒临时 AreaChainSurfaceQA 的 `9e-baseline-*` / `9e-current-*`。已查看深色中文管理页与浅色英文侧栏代表图；这是原生 cacheDisplay 证据，不是窗口合成器屏幕截图或真人 VoiceOver 验收。不同令牌场景间侧栏滚动条会按原时序淡出，不能用跨时刻整窗差异推断回退色不同；同场景新旧整窗比较包含滚动条，未裁图来取得通过。

颜色专项在上述原图中按实际行几何检查：32 组均区分六种普通色，128 对空/未知值回退行与 moss 默认行完整像素一致，336 对预设行在普通标签切换颜色期间保持一致，见 color-contract.json。这里的行区域仅用于不同颜色场景间比较，前后等价仍以上述 152 对未裁整窗为准。

**过程失败与校正**：首轮辅助定位误把短名称当作长名称的子串，误要求管理合并行为 AXStaticText；动态本地化键的插值及跨色彩空间原始分量比较也使测试误判。最终采用唯一原行语义、动态完整键、实际像素直径与同宿主前后完整图对照。原列表同步 mouseDown 等待 mouseUp 的一次测试被中断，保留 sample.txt；改用原生队列成对投递，按实际选择验证，不要求 NSTableView 追踪循环消费的 mouseUp 再经过外层监视器。选中后的工具栏推移行位置，改名坐标改为重新读取。SwiftData 查询刷新会额外使 Observation 失效，失效次数不冒充写入次数；保存次数、模型值、未保存状态和呈现前后的零变化分别断言。过程失败包不算通过。

另有一次构建锁忙未启动测试，及完整目标因并发 LocalPreferenceFileConcurrencyTests 抛出调用而编译失败；未修改或排除该文件，待工作区修正后重跑。静态预检曾发现并发 §9.58 引用尚未落齐，后续预检通过；这些过程状态不替代最终门禁。QA 完整目标最终编译及 `codesign --verify --deep --strict` 通过，既有 SDK/并发弃用警告保留。

**最终门禁与局部自查**：四个本轮 Swift 文件严格局部 SwiftLint 零违规；`python3 -B scripts/quality_gate.py --profile static`（含 215 项脚本回归）、`python3 -B scripts/check_workflow.py`、工作区/暂存区 `git diff --check` 通过，未跟踪测试另查末尾换行及尾随空白。两处生产文件除指定色点替换外逐字相同；DaybookChip、DaybookPalette、CatalogModels 和 Catalog 未变。暂存补丁 SHA-256 与任务起点一致，前期与并发改动保留。完整 QA 构建已覆盖必要编译，不机械运行全量筛选、系统集成或额外构建；路由、架构、检查器与签名配置未由本轮修改。

本轮局部等价接入由主代理自查，不新增复核流程；既有 Cursor verifier、真人鼠标/VoiceOver、窗口合成器及其他历史验收缺口继续保留，全应用验收不因四类接入完成而通过。原生加载器、不同数字口径、标签胶囊和空态的合理差异保持。可以进入第十阶段全应用复用清单与最终验收规划，但本轮在 E 停止。未提交、推送、安装或发布，未改真实数据、系统偏好、个人签名配置及权限。

## 第九阶段 D：连击指标列复用

2026-10-04，仅 `TaskDetailScheduleSection.swift` 的当前/最佳两列共用私有 `streakMetricColumn(title:systemImage:value:)`；本地化键、整数 Text 插值、两列及分隔线布局保持。原 `.card` 自动悬停、状态优先级、检查日说明、配置和连击计算不变。接口与剩余标签色点线索见[组件目录](component-catalog.md#第九阶段-d连击指标列复用)。没有 Theme、公共 API、路由或检查器规则变化。

**基线与验证**：直接挂生产 TaskDetailStreakCard，复用 SettingsButtonTestSupport、HabitMonthTestSupport 与既有图像/鼠标支持，不复制业务卡片。原五状态测试只构造 View/求值 body；新增 StreakCardRenderingTests 实际查询辅助文字、图标位置和卡片几何。`build/StreakColumn9D/baseline-verified.xcresult` 与 `current.xcresult` 各 **5 项／9 次通过，0 失败、0 跳过**，包括原 StreakInspectionStatusTests、原 `taskDetailStreakCardAllFiveStatusStates()`。核对真实测试标识；首次未带括号的旧方法选择器未命中，不计为旧用例通过。

- 280/320pt 原检查器宽度，28pt 原外侧/分区边距，中英文与浅深色；0/1、1/99、99/100、100/7、123456789/9876543210 五组分别呈现标题、图标、完整数字和两个单位。
- 暂停、跳过、完成、非计划日、待打卡五状态保留，包括冲突标志的优先级；非今日附日期、今日不附日期。外部配置先单独更新当前、再单独更新最佳，原宿主自然更新；`.card` 合成原生移入后像素变化、几何不变，移出恢复原像素。测试宿主禁用动画，未验证真人悬停时序。
- 原 RoutineHabitSectionView 中英合成场景显示传入的 17/203，仍显示跳过及非今日说明；模型快照、记录数、context.hasChanges、保存/观察计数和检查器导航均无变化。未执行打卡、完成、复制或系统动作。
- 沙盒临时 `AreaChainSurfaceQA/9d-{baseline,current}-*` 的 **92 对完整窗口 PNG 解码后逐像素一致**，覆盖完整卡片、分隔线、空闲/悬停及两个宿主；**184 对 JSON 几何/辅助文字记录一致**。图像为原生宿主 cacheDisplay，非窗口合成器屏幕截图。正常数字和长数字图像经查看。

**历史表现与测试校正**：修改生产代码前，测试发现原 Text 整数插值含本地化千位分组，首次无分组字符串断言不成立；超长数字原本完整换行，列高不同使标题高低不同，不能要求始终同高。系统火焰辅助名称也随语言变化，改为指标行几何定位并由完整像素核对图形。修正测试后取得全部基线才做生产抽取；没有增加缩写、截断、格式化或布局修复。初次失败结果包保留，不算最终通过。

**静态门禁**：三个本轮 Swift 文件的严格局部 SwiftLint、`python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile static`（含 214 项脚本测试）与工作树/暂存区差异检查通过；未跟踪测试文件另查尾随空白与末尾换行。Swift 编译和原生测试由上述完整正常 PrivacyQA 提供，不另跑会扩大测试范围的默认 Swift profile。

**编译与边界**：完整正常应用/测试目标沿 `build/PrivacyQA-StreakColumn9D`、`com.areachain.privacy-qa`、local 临时签名、生产 sandbox entitlement、LSUIElement=NO、原 build/.build.lock、六项钥匙串授权变量清除及串行 XCTest；只用合成数据及隔离偏好。最终正常目标编译通过，QA 产物 `codesign --verify --deep --strict` 通过；既有测试中的弃用/并发警告保留。本轮私有等价抽取由主代理自查，不增加复核流程；既有 Cursor verifier、真人鼠标/VoiceOver、窗口合成器及其他历史验收缺口不因此消失。ControlsPreview 继续专注共享控件，本轮直接生产卡片矩阵已覆盖，不另建展示应用。保留前期及并发修改，暂存区内容哈希前后一致；未提交、推送、安装、发布，未改真实数据、系统偏好、个人签名或权限。完成后停止，标签色点留下一阶段。

## 第九阶段 C：菜单栏筛选浮层外壳

**范围与实现**：仅 MenuBarFilterFlyout.level1CategoryCard / level2OptionCard 的 background/overlay 接入 `daybookSurface(floating: .filterFlyout)`。公共 DaybookSurface 保留前期暂存静态卡片、动态气泡与全部默认入口；新预设使用 regular/continuous、页面底色、65%／0.8pt strokeBorder 内描边、仅背景 floating 阴影及装饰描边非命中政策，其他浮层仍用原居中 stroke。布局、220ms Task、类别 Binding、规则/计数、滚动和写回/关闭均留在原组件。宿主、键盘、状态栏和 NSPopover 生命周期未改。接口见[组件目录](component-catalog.md#第九阶段-c菜单栏筛选浮层外壳)。

**修改前基线**：完整正常 PrivacyQA 直接挂生产组件并经原筛选按钮打开宿主。`build/FilterSurface9C/baseline-complete.xcresult` 中卡片/宿主 2 项／8 次通过，覆盖双语浅深色、任务两级/手记单级、空/长/24 标签、三类别；循环内记录 72 张直接组件图、8 张宿主图。旧实现原生悬停、级联跨隙、重入取消、离开延迟与卸载取消见 `baseline-actions.xcresult` 的 3 项／7 次通过。任务卡片 110/175pt、手记175pt、整体295/181×171、二级175×165、原指示器均核对；padding/spacing及宿主左12/底44/zIndex30由源基线和原生几何共同核对。

**基线诊断边界**：早期 helper 的坐标及随后语义定位鼠标未切换宿主页签，补选中断言后确实失败，旧“手记”截图作废；场景准备改用原生产页签辅助动作并读回选中，筛选入口/选项/遮罩仍为原生合成鼠标。未改变页签生产实现。宿主跨页/搜索出现2次草稿观察通知，而正文和模型保持，`baseline-isolation.xcresult` 的零总通知断言2次失败；最终按各筛选操作前后检查不写草稿，跨页初始化与搜索挂卸载单独记录，未改生产初始化。首次同名 Priority 辅助节点定位失败改为一级卡片范围定位，未宽松选择第一个节点。

**公共与消费者证据**：`current.xcresult` 55 项／105 次通过、0失败、0跳过。公共冻结完整外缘像素一致，居中描边和正文整体阴影负对照确实不同；send/post按钮单次命中、阴影不扩区、isPresented 身份/onAppear、无自动悬停及旧预设/静态卡片回归通过。生产日期/优先级/标签精确 applied/cleared、分 tab 清除、内外类别所有权、草稿与合成模型隔离通过。原生 mouseMoved 加实际游标定位证明类别变化、4pt跨隙不误关、220ms离开关闭、及时返回取消及卸载无迟到回调；类别程序赋值只计 Binding 证据。

**像素分类**：`production-pixels.json` 比较80对，72对直接生产卡片完整缓存图相同；8对完整宿主图不同，不算整图通过（含手记夹具生成时间、过渡及按钮状态）。公共层旧装饰仅在测试保留；生产无第二套装配。缓存图不是窗口合成器屏幕截图，真人操作与屏幕像素未验。ControlsPreview 原入口增加新预设及生产两级/单级展示。

**最终复验**：`final.xcresult` 16项／33次通过、2项／4次失败、0跳过：新增宿主几何断言读到过渡旧节点，新增快捷键夹具的实际字符误设为大写F。沿既有450ms过渡观察窗、原characters=f / charactersIgnoringModifiers=F修正测试后，`recheck.xcresult` 4项／12次全部通过；生产实现没有为测试改时序或事件。最后一项标签滚动后原生点击精确写回、帮助原鼠标/键盘回归通过。`candidates.xcresult` 8项／12次全部通过，含原 OverlaySurfaceConsumerTests 和 UnifiedSearchLayoutTests 的候选原生命中、双布局最小尺寸/语言主题与滚动，不迁移搜索代码。按最近同名结果去重：**75项／137次通过，0失败、0跳过**（`latest-summary.json`、`latest-tests.json`）；过程失败不计通过。原规则测试仍有State宿主类运行警告，帮助旧HelpKeyResponder测试有NSHostingController子视图警告，未以断言通过消除警告。

**最终门禁**：9个本轮Swift文件严格局部SwiftLint、工作流、暂存/工作区差异检查、严格static profile通过；检查器94项定向及214项脚本回归通过。`debug-build.log` 记录 `./scripts/build.sh --no-wait` Debug构建及既有development静态验签通过：staticSignatureVerified=true、hardenedRuntime=true、distributionReady=false，保留原SDK/actor编译警告。生产消费者除两段外壳替换外逐字相同，三个宿主文件、公共旧静态/交互表面代码及完整暂存补丁哈希与起点相同；`docs/unified-search-commands.md`的并发工作区编辑保留，未修改/排除并发文件换取通过。原生几何最终确认任务二级x129/手记x15、y47，即原左12/底44加3pt外padding；第一级与级间尺寸沿直接组件及源基线验证。已查看ControlsPreview深色、任务/手记代表缓存图，未声称真实屏幕验收。

**门禁与边界**：隔离沿 `build/PrivacyQA-FilterSurface9C`、`com.areachain.privacy-qa`、local临时签名、原sandbox entitlement、六项钥匙串变量清除、原构建锁与串行事件，不直接打开QA App。指定 Cursor verifier 当前不可调用，整体保留 **partial** 复核缺口，不认证或替代；真实NSPopover、VoiceOver、真人鼠标/输入法未验。历史滚动归属、羽化、手记AX、下方气泡保留及复制不扩修；连击指标、标签色点继续留待后续。未提交、推送、安装、发布，未改真实数据、系统偏好、个人签名或权限。

## 第九阶段 B：昨日事项静态卡片外壳

2026-10-04，仅 DaybookSurface 增加 `daybookStaticCardSurface()`，TasksPage 两种昨日布局替换完整 background/overlay；接口与保留责任见[组件目录](component-catalog.md#第九阶段-b昨日事项静态卡片外壳)。公共层没有状态、自动悬停、选中、阴影、动画、布局或颜色配置；背景/0.8pt 内描边非命中。原 `.card` 自动悬停/选择与 floating 不变。普通 padding 8、外水平 1/底部 8/transition，居中 padding 10、外水平 4 和标题边距保持；布局条件、投影、行与逐项移动未改。原 ControlsPreview 增加静态/交互卡片对照。

**基线与像素**：修改生产前，原 SystemPageHost/SettingsButtonTestSupport 直接挂 TasksPage，以合成内存模型、原昨日按钮展开/收起；`build/StaticCard9B/baseline.xcresult` 为 1 项/2 次通过，内部覆盖两分支×中英文×浅深色×356/480pt 共 16 场景。`baseline-actions.xcresult` 为 2 项/6 次通过，含正文鼠标检查、真实移动按钮鼠标/辅助动作、按钮左侧空白不移动。完整缓存图与滚动几何在 before/after，16 对生产整图逐像素相同，统计 `production-pixels.json`；公共冻结只保留旧装饰，不复制业务。图含透明宿主区域，不能当窗口合成器截图；已查看普通/居中代表图。

**过程证据**：`acceptance.xcresult` 首轮 36 项/72 次：33 项/67 次通过，3 项/5 次失败，0 跳过。公共完整外缘、圆角/内描边/无阴影、静态悬停与原 `.card` 动态反馈、两布局移动成功/失败链、原投影/空态/滚动及 ModelChanges 通过。身份读取早于 onAppear、完成按钮误用正文坐标两处测试问题已修正：等待原 settle、通过实际 AX 完成按钮且按行定位；未改生产。floating 两次 key window 丢失保留失败，不删焦点断言。

`recheck.xcresult` 为 8 项/20 次通过、0 失败、2 项跳过。公共身份/按钮边界、原 ControlsPreview、习惯正文检查与完成/跳过昨日、待办逐项移动、真实 ModelChanges 保存失败/回滚/反馈与重试均通过。MonthGridMoveRepository 原接口直接复用、未扩展；月格两测试因原环境条件跳过，不算通过。该轮 floating 方法筛选没有命中，不能覆盖首轮失败。内容矩阵已扩展到中英文/浅深色/宽窄，新增空昨日及壳/行悬停区分；最终合并回归第一次因原构建锁忙未执行，不绕过锁。

**最终验证**：锁释放后 `final.xcresult` 实际命中 11 套、**60 项/133 次，全部通过，0 失败、0 跳过**；清单在 `final-tests.json`，命令在 `final-command.json`。完整 DaybookFloatingSurfaceTests 已重跑，覆盖首轮焦点失败及此前零命中的筛选，不改变旧测试。除公共静态/交互表面外，真实 TasksPage 在两种分支、两语言、两主题、356/480pt 下覆盖单条、长标题、仅习惯及混合 3/24 条，保留 48 份扩展矩阵图；空态、展开/收起、今日输入变化后的原分支往返、5pt 正文水平差、滚动与零模型变化通过。壳内边距悬停整图不变、进入原行有反馈；原菜单栏和工作台合成宿主全套通过，但不将通用宿主回归写成完整宿主中的昨日专项动作。重新比较最终 16 对生产完整图仍逐像素相同，未裁外缘；已查看长标题、仅习惯及 ControlsPreview 代表图。

**最终门禁**：7 个本轮 Swift 文件严格局部 SwiftLint、工作流、差异与 static profile 通过；检查器定向 93 项、完整脚本回归 213 项通过。`./scripts/build.sh --no-wait` Debug 构建及静态验签通过，沿既有 development 配置：staticSignatureVerified=true、hardenedRuntime=true、distributionReady=false；编译仍有既有 SDK/actor 等警告。源差异核对确认两处消费者除完整绘制替换外逐字保持，旧表面代码逐字保持，TasksPage/Actions 哈希不变，暂存区完整补丁哈希与起点相同。未修改/排除并发代码换取通过。

**边界与未验**：整体交接 **partial**，范围内实现及上述自动验证完成；指定 Cursor verifier 当前不可调用，保留复核缺口，不认证或替代。原生测试沿完整正常 PrivacyQA、独立 `build/PrivacyQA-StaticCard9B`、`com.areachain.privacy-qa`、local 临时签名、原生产 sandbox entitlement、六项钥匙串变量清除及串行事件。鼠标证据是原生 sendEvent/postEvent 合成事件，辅助按下及菜单 action 单独计；真人鼠标、VoiceOver、窗口合成器屏幕像素未运行。过程中的失败、跳过与未执行不计入最终通过数。第九阶段筛选浮层、连击指标、标签色点，以及第八阶段手记 AX、下方气泡保留、瞬态悬停、滚动归属、羽化等历史缺口均未修。保留前期暂存及并发修改；不提交、推送、安装、发布或操作真实记录、系统偏好、签名配置和权限。

## 第八阶段 F：标题与备注气泡动态外壳

以下保留接入轮的原始结果；2026-10-04 最终版本事件补验及最新去重状态见本节末的“F 补验”。

2026-10-04，本轮实施范围仅 DaybookRowBubbles 的两处装饰及重复边框映射、DaybookSurface 的纯呈现预设。直接生产气泡修改前基线见 `build/SurfaceStageF-baseline.xcresult`（6 项 / 15 次通过、0 失败/跳过）；保留动画与反馈中卸载补验见 `SurfaceStageF-motion-baseline.xcresult`。原生事件只调用直接气泡注入的计数回调，无系统剪贴板操作。完整 PNG/几何/文字/回调记录在 `build/SurfaceStageF-before`；冻结旧代码仅为装饰，不复制生产气泡。

**已实现、部分验收（partial）**：公共动态入口及责任边界见[组件目录](component-catalog.md#第八阶段-f标题与备注气泡动态外壳)。两处外壳和两处颜色映射收口；复制反馈优先、small/continuous、0.8pt 居中描边、背景形状阴影及非命中描边集中维护，箭头不被包入装饰。三消费者文件与任务起点哈希相同；去掉本轮扩展后的公共表面哈希与起点一致，保留 E 帮助/事件修复和全部前期/并发改动。旧壳补验仅在原构建锁内临时恢复本轮拥有的 RowBubbles 段，finally 核对并还原，无并发覆盖。

**实际证据**：

- `SurfaceStageF-motion-baseline.xcresult`：3 项 / 12 次通过，直接气泡保留原动画，真实 mouseMoved/down/up、nil/有回调、单次调用、反馈中进出、正常复位、卸载/重挂和反馈中卸载；不是私有状态赋值。初始直接气泡事件覆盖 en/light，后续全语言/主题事件扩展的状态见下条。
- 新壳 `SurfaceStageF-focused.xcresult`：12 项 / 32 次，11 项 / 29 次通过，1 项 / 3 次失败，0 跳过。通过含公共四状态政策、完整外缘冻结对照、UUID/onAppear/几何、动态描边内容点击、直接气泡事件与箭头边界、TaskRow 回调装配。失败与修正夹具后的 `SurfaceStageF-consumer-original.xcresult` 相同：LiveDiaryComposerPreview 的 combine 辅助树仅暴露 diary.preview.card，两个位置找不到正文节点；DiarySummaryRow 下方场景进入气泡后正文未保留。不能据辅助树缺少正文断言实际没有绘制，不改消费者。
- `SurfaceStageF-note-original.xcresult`：原任务预览备注上下两位置进入、保留、候选排除和往返共 1 项 / 2 次通过。新壳该新增事件用例尚未运行。手记敏感投影/原条件检查通过；输入草稿、焦点、选区、候选接受、帮助鼠标/一次 Escape 的本轮事件组合回归未运行，旧阶段结果不替代。
- 扩展双语浅深色反馈后，`SurfaceStageF-feedback-matrix-original.xcresult` 为 3 项 / 12 次：静态矩阵 4 次通过，事件 8 次因 foreground=com.apple.loginwindow、key=false、active=false 失败。只读会话检查确认锁屏，未跳过焦点断言、改变系统设置或直接打开应用。完整反馈矩阵当前仍未验收；用户尚未提供桌面恢复信息，不重复无效运行。
- 最终非事件回归 `SurfaceStageF-visual-regression.xcresult`：14 项 / 34 次全部通过，0 跳过；完整正常应用/测试目标编译，覆盖公共三政策与四状态、isPresented 身份、五静态预设完整外缘、原帮助裁切、row 叠层、两实时预览、候选/只读属性、双语浅深色长短正文与上下箭头以及原 ControlsPreview。状态汇总在 `build/SurfaceStageF-status.json`，不把不同包重复项相加。

**视觉与时间分开**：`build/SurfaceStageF-before` / `after` 保存完整缓存图、几何、文字与回调次数。初始新旧 58 对图的几何/文字/次数一致，57 对整图逐像素相同；一对备注复制提示文字 359 像素最多差 1 灰阶，边框/几何无差异，属于动态取样差异，不计静态失败或静态通过。统计 `SurfaceStageF-comparison.json`。公共合成内容四状态的严格整图冻结比较单独通过，包含 32pt 外缘、背景阴影和越界图形。已查看直接标题复制反馈、深色长备注及浅色 ControlsPreview 的四状态/外部箭头；缓存图不是窗口合成器截图或真人操作。1200ms Task 与原动画代码未变，事件断言验证反馈出现及等待后复位，不声称精确量测了每一过渡帧或系统复制成功。

**门禁**：7 个本轮 Swift 文件严格 SwiftLint、工作流、差异检查通过；检查器只扩展原稳定入口与反例，92 项定向、212 项脚本回归及静态 profile 通过。`./scripts/build.sh --no-wait` Debug 构建与静态验签通过，日志 `SurfaceStageF-debug.log`；沿既有 development 配置，staticSignatureVerified=true、hardenedRuntime=true、distributionReady=false，不是安装/发行。正常编译仍有原 SDK 辅助 API 警告。

指定 Cursor verifier 无可调用入口，保留复核缺口，不认证或替换。第八阶段原明确登记的标题/备注装饰重复已接入，未发现本次登记范围的确定遗漏；不同点击形状、箭头及内容高度是合理差异。B 的滚动归属、D 的复制按钮辅助树、悬停/定位/窗口边缘及其他历史问题继续保留。未验证系统剪贴板、真人输入法、VoiceOver、低版本系统或真实数据；不提交、推送、安装、发布，不修改系统偏好、签名配置与权限。


### F 补验：最终版本事件回归与收尾

2026-10-04，本轮四类定向事件证据已补齐。生产源码未改；仅修正两个测试文件并更新原工程记录与 `build/SurfaceStageF-status.json`。工作区原有、未跟踪及并发改动均保留，暂存区未改。独立 `build/PrivacyQA-Surface8F-Final`、原 QA 标识、临时签名、生产 sandbox entitlement、LSUIElement=NO、完整正常应用/测试目标、六项钥匙串授权变量清除及 `build/.build.lock` 串行保持。一次锁忙未启动测试。只读会话检查不再显示 loginwindow；`final-probe.xcresult` 的生产帮助搜索小场景 1 项通过，诊断明确 window=7235、visible/key/active=true、前台为 QA，之后才运行正式组。下列结果包均使用 `build/SurfaceStageF-` 前缀。

| 补验目标 | 最终有效证据 |
|---|---|
| 直接气泡完整反馈矩阵 | `final-feedback.xcresult`：`RowBubbleInteractionTests.nativeFeedbackAndNilCallback(note:callback:)` 1 项 / 4 参数运行通过；每次内部循环 en、zh-Hans × light、dark，共 16 场景。真实合成进入/离开、单次计数回调、nil、反馈期间进出、复位后悬停、卸载/重挂及反馈中卸载均通过，保留原动画和等待。`final-bubbles.xcresult` 的 `nativeContentCornersArrowAndShadow(note:upward:)` 4 参数运行也通过。 |
| 新壳备注消费者 | `final-bubbles.xcresult`：`RowBubbleConsumerTests.taskNoteHoverCandidateExclusionAndRetention(lower:)` 的 false/true 两位置通过。沿生产备注指示器进入、气泡保留、候选排除及恢复；继续使用 `Synthetic // Synthetic note`，无强设悬停、宿主重建或生产条件改动。此宿主没有编辑器，输入焦点证据由下一组提供。 |
| 输入组合 | `final-composition.xcresult`：8 项 / 12 次通过。`LivePreviewCompositionTests.nativeDraftAndSelectionSurviveCandidateTransitions(diary:acceptance:)` 的 false/true × return/mouse 验证两类预览候选往返、同一编辑器/焦点/选区、精确替换范围和一次接受；原 `InputSyntaxInteractionTests` 补多行鼠标、标签中部 false/true、独立撤销替换、列表及多行组合文本；`DaybookTextFieldSearchTests.returnDuringChineseCompositionDoesNotCommitAutocomplete()` 与 `DiaryComposerInteractionTests.chineseCompositionAndTagCompletionTakePriorityOverSubmission()` 补单行 Return 和手记 ⌘Return。无额外提交；合成标签夹具的初始保存另计。 |
| 帮助鼠标与一次 Escape | `final-help.xcresult`、`filter-keyevent.xcresult` 加探测方法按最新同名结果去重，13 项 / 24 次通过。capture 单项/综合精确替换，search 空串、`query`、`query ` 精确追加，nil 综合无动作，卡片空白/内部操作及外部关闭不穿透；双语浅深色 356/380pt 的一次 Escape 保留草稿、查询、预览、原编辑器和选区，下一次才交还输入。程序化 marked text、候选、筛选优先级、双窗口、重开、修饰键及卸载通过。帮助均经生产 FooterBar 菜单打开；sendEvent/应用队列与额外 capture AXPress 参数分别取证。 |

**失败与测试修正**：`final-bubbles` 首轮 3 项 / 10 次中 9 次通过、1 次失败：备注/nil/中文/深色在复位离开后再次收到 true，复制已复位，窗口 key/active 正常。该次未记录实际光标位置，原因未定，不归为锁屏或已证实产品回归。发现原复位产物缺少类型/主题导致覆盖，遂仅在 RowBubbleInteractionTests 补全场景文件名及光标诊断，原断言、计数、时序不变；完整方法重跑 16 内部场景通过。原失败仍保存，不能声称修复了悬停产品问题。

帮助筛选方法在 `final-help` 与未改测试的 `final-filter` 两次止于“筛选未打开”的前置断言，未执行到优先级断言。仅构造、未派发的原生 CGEvent/NSEvent 显示 ⌘⇧F 的 characters=f、charactersIgnoringModifiers=F；旧 helper 调用两者都填 f。MenuBarHelpKeyboardTests 只在该用例按原生字段构造事件，再沿原应用队列和等待发送；`filter-keyevent` 同一完整方法通过。共享 helper、生产路由、断言均未改，最新结果替代两次前置失败，不重复计数。

**去重与证据边界**：本轮 **24 个 Swift Testing 方法 / 46 次全部通过，0 跳过**；XCTest 负责启动宿主，未选择传统 XCTestCase。方法的完整签名、参数、来源和内部循环另记在原状态汇总 `finalVerification`。与仍有效的新壳 focused / visual-regression 合并后为 **41 项 / 91 次，40 项 / 88 次通过，1 项 / 3 次既有失败**。三次仍为手记预览两位置 AX 正文定位及手记行下方保留，未重跑扩修；旧/新同失败不是通过，AX 节点缺失不证明未绘制。历史 loginwindow 的 8 次环境失败单列，不与恢复后数据混算。无新增已确认生产回归。

`build/SurfaceStageF-final-events` 保留本轮合成缓存图与几何/文字/回调记录。最终反馈 16 场景 × 6 状态共 96 图/记录，缩略拼图已查看；按每图气泡左侧中段两列、七行原始 RGBA，56 组复制优先/复位对应关系无差异。此为局部描边取样，非完整整图对照、逐帧时长或窗口合成器截图；旧完整静态矩阵未失效，不重复运行。程序化 setMarkedText 与真人输入法分开；系统剪贴板、真人键鼠/输入法、VoiceOver、真实 NSPopover、低版本和全部系统矩阵未验。

最终两测试文件严格 SwiftLint、工作流、static profile（内含 212 项脚本测试）、JSON 解析及差异检查通过；修改后的测试已随完整正常目标编译，并重跑各自受影响方法。并发修改的 UnifiedSearchObjectInteractionTests 保留，最后正常目标编译已包含该版本。未额外重复 Debug 构建或静态图矩阵。第八阶段登记的接入范围无新增确定遗漏，可由主对话另行进入第九阶段剩余组件核验；本轮到此停止。指定 Cursor verifier 仍不可用，未认证或替换，整体验收保留复核与人工缺口；既有滚动、复制辅助树、悬停/定位等问题不因补验消失。未提交、推送、安装、发布或改变真实数据、系统偏好、签名配置及权限。

## 第八阶段 E：标签详情与语法帮助卡外壳

2026-10-04，macOS 26.6.2 arm64、Xcode 26.6 / Swift 6.3.3、Python 3.9.6。范围见[组件目录](component-catalog.md#第八阶段-e标签详情与语法帮助卡外壳)。仅接 tagDetailBubble / SyntaxExpandableCard 最外壳：tagDetail / syntaxHelp 共用页面底色、60% / 0.8pt 居中 stroke 与背景形状阴影，保留 regular/medium continuous。帮助原 clipShape 在装饰之后，公共层没有布局、裁切、命中、状态或事件。原三预设的 70% / 0.7pt、阴影及 isPresented，旧 row/card/panel/banner 均保留。

**隔离与差异**：完整正常 AreaChain XCTest、`build/PrivacyQA-Surface8E`、`com.areachain.privacy-qa`、原 `build/.build.lock`、local 临时签名、生产 sandbox entitlement、LSUIElement=NO；清除六项真实钥匙串变量，串行执行。仅合成内存库、随机偏好 suite 和原宿主，不直接打开 QA App 或日用应用。初始工作区、暂存区和未跟踪为空，随后 Services 偏好/窗口及搜索文档出现并发修改，均保留并参与正常构建。关键路径 SHA-256 基线保存在 `build/SurfaceStageE-source-baseline.json`；MenuBarPopoverView、DaybookRowBubbles、手记预览、SyntaxOverlay、SyntaxAutocompleteView、UnifiedSearchOverlay、DaybookScroller 均相对本轮基线未变，两个消费者剩余代码由差异核对。

**修改前及对照**：`SurfaceStageE-baseline.xcresult` 命中 8 项 / 19 次，6 项 / 14 次通过、2 项 / 5 次失败、0 跳过。通过原预设、标签临界/溢出与候选往返、直接帮助回调；生产帮助入口未打开。普通/控制器宿主的 ⌘/、鼠标菜单追踪、AX 菜单按下和空菜单读取均有失败记录，不当作生产动作通过。最终复用原 NSHostingController 隔离宿主，通过真实 NSPopUpButtonCell 点击装配 NSMenu，取消追踪后派发原帮助项 action；不设置私有帮助状态。440pt 高度基线会挤出原 490pt 固定内容，后续保留原高度并用 356/380pt 宽度矩阵。`original-comparison` 在构建锁内只临时恢复两段迁移前外壳，结束自动恢复本轮接入；同宿主原生鼠标动作、Escape 与标题悬停断言在原外壳下也失败，未修业务。

**最终 Swift 证据**：主包 `build/SurfaceStageE-acceptance.xcresult` 命中 16 套、91 项 / 140 次：86 项 / 131 次通过，5 项 / 9 次失败，0 跳过。随后 `gallery`、`settled-consumers`、`hover-final`、`escape-final` 只补/重跑对应展示、悬停与关闭检查。按测试树逐项以最新结果覆盖旧结果，合计 **92 项 / 142 次：86 项 / 132 次通过，6 项 / 10 次失败，0 跳过**，清单 `build/SurfaceStageE-latest-test-status.json`。没有零命中或排除正常源码；构建保留原 SDK/actor 等警告。

通过公共五预设的完整 32pt 外缘静态逐像素对照（含越界图形，以区分正文整体阴影与背景阴影）、旧表面默认、isPresented 不增 onAppear/不重建身份/不改几何及关闭后无装饰对照。帮助外壳后裁切与原顺序逐像素相同，并验证它不同于公共完整阴影。标签短/长、刚好放下/溢出、多于五项、标题/计数/原顺序/无重复行及候选往返通过；原输入编辑 API、选区、焦点、零提交/零写入和定向原生滚轮移动通过。C/D 的候选、只读属性、两类实时预览、菜单栏捕获/搜索、共享统一搜索隔离宿主及 ControlsPreview 均实际回归（D 复制失败另列）。

生产帮助 **辅助动作** 的 en/zh-Hans × 浅深色 × 356/380pt 矩阵通过：capture 单项/综合示例替换整份草稿并恢复焦点；search 三种空格前缀追加 token 并聚焦搜索，nil 综合回调保持无动作；原筛选、捕获草稿、候选暂停、零模型/标签写入成立。直接卡片两条回调路径次数通过。这是原菜单 action 和 AXPress 的证据，不能代替下述鼠标结果。原菜单栏其他搜索/页签路径由 MenuBarPopoverRenderingTests 回归，帮助打开时从手记切任务的完整专项链未新增验证。

**保留失败**：① 公共 medium 命中样例的旧/新中心按钮均未响应，轨迹相同但点击断言保留；② 真实帮助鼠标点击单项/综合示例未替换草稿，后续 token 点击未完整走通；③ 关闭按钮/外部遮罩检查经过，但 Escape（已使用真实 escape 字符和延长等待）仍未关闭，生产帮助正向悬停呈现也缺少可靠观察；④ 标签标题悬停未稳定观察到标签详情移除；⑤ 直接帮助卡的正向悬停示例 AX 断言未通过；⑥ D 的 diary.copy 仍未进入辅助树。悬停实际尝试 CG 指针定位及原生 mouseMoved，在恢复指针前等待过渡并检查；早期“默认文案不在树中”的弱断言不作为通过证据，最终改查示例正向存在，未设置 hoveredToken、删除断言或强制生产状态。上述定位/时序/命中失败不单独证明产品回调错误；没有改业务、复制、滚动或显示条件。

**像素、几何和展示**：`build/SurfaceStageE-before-original` / `SurfaceStageE-after` 保留完整缓存图和滚动几何 JSON。68 对静态同输入图（64 个标签场景、4 个真实帮助 capture 场景）整图像素与记录几何全部相同；4 个搜索同名图的捕获草稿不同、3 个悬停图含动态/定位差异，排除于静态等价结论。统计见 `build/SurfaceStageE-static-comparison.json`。未把动态手记时间计入整图一致。已查看标签溢出、原生帮助及悬停对照；原 ControlsPreview 的公共完整阴影/真实帮助裁切展示经浅深色定位检查通过，图 `build/SurfaceStageE-after/e-gallery-light.png`、`e-gallery-dark.png`。均为缓存位图/几何/合成事件，非窗口合成器屏幕截图或真人输入。

**门禁与状态**：9 个相关 Swift 文件严格局部 SwiftLint、工作流、差异检查和 Debug 静态验签通过；Debug 沿原 development 配置，staticSignatureVerified=true、hardenedRuntime=true、distributionReady=false。检查器只增加本轮稳定预设/帮助入口与反例；定向 89 项及最终静态 profile（含 209 项完整脚本回归）通过，结果见 `build/SurfaceStageE-workflow-tests-final.log` / `SurfaceStageE-static-complete.log`，过程中的并发状态下失败日志保留，不覆盖成通过。**整体部分完成（partial）**：指定 Cursor verifier 不可调用，不认证或替换；原生鼠标/悬停/Escape 仍有上述缺口。实际屏幕、真人输入/IME、VoiceOver、窗口边缘完整矩阵未验，B 的周列/甘特错绑及羽化定位、D 的复制反馈/更多菜单缺口保留。标题/备注仍是 small/continuous、0.8pt 动态边框、背景阴影、箭头与偏移，不能直接套本轮静态预设；只登记后续线索。到 E 停止，未提交、取消暂存、推送、安装、发布，未修改真实数据、系统偏好、个人签名或权限。

### E 补验：中心命中与事件归属

2026-10-04，定向诊断，整体 **partial**。只修改 [DaybookSurfaceTests](../AreaChainTests/Theme/DaybookSurfaceTests.swift)、[MenuBarHelpSurfaceTests](../AreaChainTests/Features/MenuBarHelpSurfaceTests.swift)、[TagHelpSurfaceConsumerTests](../AreaChainTests/Theme/TagHelpSurfaceConsumerTests.swift)，增加本轮专用 [SurfaceEventTestSupport](../AreaChainTests/Theme/SurfaceEventTestSupport.swift)。生产及两个原共享 helper 相对本轮起点哈希不变；上文 92 项 / 142 次是迁移轮历史汇总，不与拆分后的本轮测试相加。

**起始失败映射**：读取 latest 状态及 acceptance / original-comparison / escape-final 的 summary/tests，没有重读全部长日志。

| 完整测试名 | 场景与旧/新结果 | 原执行边界及缺口 |
|---|---|---|
| `DaybookFloatingSurfaceTests/decorationDoesNotExpandPointerInterception()` | 五预设内部循环；medium 旧/新均 `inside == 1` 失败 | 五点已投递；缺真实按钮区域、无装饰及事件接收证据。 |
| `MenuBarHelpSurfaceTests/productionHelpActionsAndClipping(locale:scheme:)` | en/zh-Hans × light/dark；旧/新 capture 单项、综合替换失败 | 首个 356pt 已到单项/综合；前置失败阻断部分 search token 和后续宽度。 |
| `MenuBarHelpSurfaceTests/productionHelpDismissalAndNativeHover()` | en；旧/新 Escape 后标题仍存在 | 关闭、外部、Escape、悬停串联；现拆成独立 pointerDismissal / EscapeEventOwnership / NativeHover。 |

**中心命中**：英文浅色 280×160，同一真实 plain Button / 灰底宿主。AX 文本按钮为 `(111.25,72,57.5,16)`，外框 180×72；原中心 `(140,80)` 确实在按钮内。中心、AX 中心、标签内缩 2pt 三点均测；无装饰在 sendEvent / postEvent 两路各回调 3 次，冻结原/当前 medium 均 0；边界五点不触发按钮，灰底分别回调 5 / 4 / 4 次。窗口 visible/key/active、前台与 bundle 均为 QA，记录三种坐标、down/up 窗口号与时间戳、实际接收顺序、firstResponder。公开 hitTest 只能到 NSHostingView。消融为“仅背景 1、仅描边 0、仅在测试中禁用描边命中 1”，定位到原 medium stroke 命中层；未证明坐标错误，不加生产 contentShape，不删中心成功断言。消融通过只证明归因，不代表完整外壳交互通过。

**生产鼠标**：沿 FooterBar cell 装配菜单、取消追踪并发送原菜单项 action；didBegin/didEnd 均观察到，返回原 QA keyWindow，固定等待 transition 后定位。当前 capture 只有一个匹配按钮，矩形 `(22,330,336,29)`，点 `(190,344.5)` 在其中，内容坐标为 `(190,145.5)`。旧/新壳的同步与队列点击均“帮助消失、草稿未替换”；AXPress 则整份替换并保持输入焦点。结合 [syntaxHelpOverlay](../AreaChain/Features/MenuBar/MenuBarPopoverView.swift) 的 scrim `zIndex(20)`、帮助卡未设对应层级、仅遮罩关闭路径不改草稿，归因到既有遮罩层级。没有重复节点证据，不改共享定位器。关闭按钮坐标与外部坐标分别关闭成功，但前者不能区分按钮 action 与覆盖它的遮罩 action。无生产插桩，不伪称观察到了 SwiftUI 内部接收器。

**Escape**：旧/新打开后 firstResponder 为 NSTextView、无 marked text、菜单已结束；capture 的 preview/presentation=true，但浮层事件监视器已移除。keyCode=53、characters=[27]、modifiers=0 经队列进入正确窗口；第一次只清 preview/presentation，第二次才撤销输入焦点，两次帮助仍在。对应 [DaybookTextField.Coordinator](../AreaChain/Theme/DaybookTextField.swift) 的 `control` → `handleAutocompleteCommand` / `handleEscapeAndDismiss`；[MenuBarPopoverView+Keyboard](../AreaChain/Features/MenuBar/MenuBarPopoverView+Keyboard.swift) 只处理筛选抽屉 Escape。直接卡片普通宿主与额外 makeFirstResponder(host) 对照中，旧/新 `onExitCommand` 均未改变绑定；AppKit 宿主焦点也未证明 SwiftUI Exit 可达。原生产焦点路径单独保留，不强制焦点、监听或调用关闭回调。生产私有帮助状态未直接读取，可见标题及关闭后浮层监视器重现仅作旁证；直接卡片另观察绑定。

**测试修正**：拆分事件路径，增加当前上下文、可见边界及唯一目标断言。未发现原“第一个按钮”实际选错，因此不修改共享 SurfaceConsumerUI。原鼠标长例中 nil 综合按钮被错误关闭后，先保留无动作/显隐断言，再恢复 search 上下文、沿原菜单重开，让 token 精确空格追加断言独立执行。无生产修复。最小建议为另开产品修复：装饰描边不参与命中；明确卡片/遮罩层级；在拥有帮助状态的既有键盘路径核对帮助优先级、IME 与 Exit 焦点作用域。建议均未实施。

**隔离与证据**：完整正常 AreaChain XCTest、`build/PrivacyQA-Surface8E-Recheck`、`com.areachain.privacy-qa`、原构建锁、local 签名、生产 sandbox entitlement、LSUIElement=NO、六项授权变量清除、串行合成数据。`build/SurfaceStageE-recheck-current.xcresult` 为 10 项 / 28 次：4 项 / 14 次通过，6 项 / 14 次失败，0 跳过；`original` 为只临时还原生产帮助装饰的 5 项 / 10 次：2 项 / 5 次通过，3 项 / 5 次失败，0 跳过，锁内 finally 恢复且哈希相同。`search-continuation` 为最后搜索恢复步骤修正的重跑，去重状态与各轮统计见 `build/SurfaceStageE-recheck-status.json`。当前/原事件摘录在对应 `*-events.log`，原始输出保留于 xcresult diagnostics。两次并行源码/测试编译错误均零命中；一次锁忙未执行，条件改变后才重跑，未排除正常源码。

**保留与交接**：鼠标、Escape 行为仍失败，不称交互验收通过。指定 Cursor verifier 缺口保留，不认证或替代。悬停仅整理历史证据，拆出的生产悬停未运行；标题/直接帮助悬停、D 复制/更多菜单、B 错绑/羽化、真实屏幕/真人/IME/VoiceOver 缺口保留。建议先单独修复既有命中与键盘归属问题，再决定 F。本轮停止，不迁移标题/备注，不提交、推送、安装、发布或修改真实数据、系统偏好、签名配置与权限。

**最终补记**：search-continuation 1 项 / 4 次均失败，确认双语×浅深色×两宽度下，24 次 token 点击均到达精确追加断言，无 require 提前中断；三种前缀仍原样未追加，nil 示例显隐失败同样保留。它替换 current 中同名用例后，最新公共壳去重仍为 10 项 / 28 次（14 通过、14 失败、0 跳过）；六轮累计执行 58 次（27 通过、31 失败、0 跳过），不将重复尝试算成新增覆盖。最终四个测试文件严格 SwiftLint、工作流、差异及 static profile 通过，后者包含 210 项脚本回归。完整正常 PrivacyQA 已编译并运行，测试断言失败不能写成测试通过；本轮未另行运行普通宿主构建/启动，也不将临时签名说成发行验签。

### E 修复一：公共浮层描边不拦截内容点击

2026-10-04。本轮明确修复旧问题，以上迁移及补验失败历史保留。唯一生产行为改动为 `DaybookFloatingSurfaceModifier.border` 的 stroke 视图增加 `allowsHitTesting(false)`；公共契约是“浮层装饰性描边不参与命中，内容与宿主继续负责交互”。五预设共用，不针对 syntaxHelp 特判，不改整个面板、背景命中、内容形状、row/card/panel/banner 或任何消费者生产接线。

**复现与严格对照**：`build/SurfaceStageE-fix1-baseline.xcresult` 命中 2 项 / 9 次：5 次通过、4 次失败，0 跳过；无装饰两路均在中心、AX 中心、文字内侧各回调 1 次，冻结原壳和当时公共壳均 0 次，三项消融再次定位描边。修复后 `focused.xcresult`（同一前缀）2 项 / 9 次全部通过；冻结 medium 精确断言 0，仅作为旧故障刻画，不计作旧功能通过。公共壳严格要求三点各 1 次、内容不穿透，五个边界点不触发内容。五预设 × sendEvent/应用队列各运行 plain/frozen/current/hidden 四场景，外框空白由保留的背景决定拦截，圆角外侧、边缘与阴影继续由原灰底宿主各接收 1 次；无装饰及 isPresented=false 的五点均交宿主。down/up 接收顺序仍由原 SurfaceEventTestSupport 核对，未改共享点击 helper 或冻结装饰。

**受影响回归**：`build/SurfaceStageE-fix1-regression.xcresult` 为 33 项 / 76 次，初次 74 次通过、2 次新测试计数失败。原鼠标宿主走 state.commit，字段 onCommitAutocomplete 仅属 Return/Tab；新组合测试曾错误要求鼠标也走该字段回调。按原契约修正为鼠标 0、Return 1，同时两路严格断言恰好一次 NSText.didChangeNotification、精确替换字符串/光标、原输入焦点、零提交和零存储修改。`acceptance-count.xcresult` 重跑整个 LivePreviewCompositionTests 3 项 / 6 次全部通过；按最新同名结果覆盖后，受影响集合 **33 项 / 76 次全部通过，0 跳过**，不把重跑相加。

候选单次鼠标接受、两种编辑器原替换范围/撤销、只读属性关闭与草稿/几何、任务主卡关闭/候选并存、标签原临界显隐/顺序/滚轮、手记原 row 叠层/装饰开关/稳定身份均通过。直接 SyntaxExpandableCard 的单项、综合示例、nil 回调和关闭在 send/queue 两路精确通过（4 次）；生产帮助宿主另列，不混入。统一搜索沿原隔离宿主回归标准/紧凑、双语主题/最小宽度、上下呈现、68pt 列表与单次接受/焦点，业务和生产接线未改。

**视觉与身份**：修改前 `visual-before.xcresult` 3 项 / 12 次通过，修改后沿相同场景重跑。`build/SurfaceStageE-fix1-before` / `after` 与 `comparison.json` 保存完整缓存图和几何：136 对非动态整图逐像素相同，184 对几何相同，48 对含手记 Date() 的图单独记录动态差异。没有裁掉 32pt 外缘/阴影；公共五预设浅深色冻结对照、帮助外壳之后的原 clipShape（并区别于完整阴影）、row 悬停叠层对照均通过。页面底色，regular/small/medium，70%/0.7pt 和 60%/0.8pt 居中 stroke、背景/整体阴影位置、尺寸/padding/裁切均保留；isPresented 往返的 UUID、状态读取、onAppear=1、几何与关闭装饰像素通过。原焦点及 transition 接线未改，图像为缓存位图而非窗口合成器屏幕；已查看公共完整外缘和原 ControlsPreview 的裁切展示。

**独立历史检查与未验项**：`hover.xcresult` 两项 / 两次仍失败：标题悬停后 All tags 未移除，直接帮助悬停后未观察到 #life 示例；不计入上述通过数，不扩展修复。生产 MenuBarPopoverView 帮助鼠标及 Escape 本轮未复跑、未修改，保留补验原失败；直接卡片 Exit 也未复跑。D 复制、更多菜单与默认系统剪贴板路径未运行，未宣称复制或全部悬停验收完成。指定 Cursor verifier 无可调用工具，未重试认证或用其他机制替代，整体仍为 **partial（修复及受影响回归通过，指定复核/历史缺口保留）**。真人/IME/VoiceOver、真实屏幕和低版本系统未验。

**隔离与门禁**：完整正常 AreaChain XCTest 目标，`build/PrivacyQA-Surface8E-Fix1`、独立 QA 标识、原 build/.build.lock、local 临时签名、生产 sandbox entitlement、LSUIElement=NO、清除六项真实钥匙串变量；事件/焦点测试串行，仅合成库和随机偏好。四个本轮 Swift 文件严格局部 SwiftLint、最终静态质量门禁（含 210 项脚本回归）、工作流和差异检查通过；未修改检查器。`./scripts/build.sh --no-wait` 的 Debug 构建及静态验签通过（`build/SurfaceStageE-fix1-debug.log`），沿既有 development 配置：staticSignatureVerified=true、hardenedRuntime=true、distributionReady=false，不代表系统解锁或发行验收。当前工作区前期/并发改动、未跟踪文件及空暂存区保留；源基线与最新状态分别见 `build/SurfaceStageE-fix1-source-baseline.json`、`build/SurfaceStageE-fix1-latest-test-status.json`。本轮生产文件去除新增命中行与注释后，哈希与起点相同；冻结绘制、两个共享事件/点击 helper、帮助宿主/键盘、标题备注气泡及其他消费者生产文件均未改。

下一轮仅处理帮助宿主遮罩/card 层级及输入预览、焦点与 onExitCommand 的 Escape 路由；产品动作和草稿规则需继续保持。本轮到此停止，不迁移 RowTitleBubble/RowNoteBubble，不修滚动错绑/羽化或复制，不提交、推送、安装、发布，不改变真实数据、系统偏好、个人签名配置或权限。

### E 修复二：语法帮助遮罩与 Escape 路由

2026-10-04。仅修改 MenuBarPopoverView 与其 Keyboard 扩展：帮助作为根 ZStack 的单一 20 层，内部遮罩 0、卡片 1，筛选 30 保持；卡片空白命中留在宿主。原宽度、92pt 偏移、clipShape、阴影与 transition 不变，卡片不再被错误遮罩叠暗。沿原唯一键盘监视器，在有效可见宿主内先处理筛选，再处理无 Command/Shift/Option/Control 且当前 NSTextInputClient 无组合文本的帮助 Escape。只收起唯一 showingSyntaxHelp 并消费事件，不清空草稿、预览或焦点；卸载移除监视器并清窗口引用。原 FooterBar 上下文、任务示例替换、搜索追加和 nil 综合回调逐字保持。

**原失败与最小回归**：上文失败基线保留。`build/SurfaceStageE-fix2-baseline-current.xcresult` 实际命中 3 项 / 5 次：capture send/queue、search token 与一次 Escape 共 4 次失败，AXPress 1 次通过，0 跳过。前两次正常编译被并发 UnifiedSearchSettingTestSupport 抛错宏阻断，另一次本轮嵌套 require 编译错误已修正；这些零命中不算通过。外部修复后才取得有效基线，未排除正常源码。`build/SurfaceStageE-fix2-focused.xcresult` 同三条原失败加编辑器/空白防穿透共 5 项 / 9 次全部通过，0 跳过。

**隔离**：完整正常 AreaChain XCTest，`build/PrivacyQA-Surface8E-Fix2`、`com.areachain.privacy-qa`、原 `build/.build.lock`、local 临时签名、生产 sandbox entitlement、LSUIElement=NO，清除六项真实钥匙串变量，串行焦点测试。仅原 NSWindow/NSHostingController 生产视图挂载、合成内存库与随机偏好；通过原 FooterBar 菜单动作打开帮助，不直接设置私有状态。未启动 StatusItemController 或日用 NSPopover。

**原生事件与计数**：`regression.xcresult`（同前缀）实际命中 39 项 / 69 次，初次 68 次通过，1 次新候选前置断言失败。原生菜单会自然收起候选，因此改为帮助已打开后，由仍聚焦的原生编辑器 insertText 输入 `#`，不直接修改补全状态；`final-help.xcresult` 重跑完整帮助 16 项 / 30 次全部通过，按最新同名结果覆盖后为 **39 项 / 69 次通过，0 跳过**。先前修饰键测试只计 keyDown，遗漏 AppKit performKeyEquivalent，已补齐原生响应者两条接收路径并重验；过程编译/前置失败不计作功能通过。

鼠标覆盖 capture 单项/综合、search 空串/无尾空格/有尾空格的精确追加、nil 综合无动作、关闭按钮、卡片空白、外部遮罩及背景筛选/页签/手记创建不穿透；sendEvent/应用队列与 AXPress 分开。MutationProbe 观察真实草稿每次恰好一次写入、nil 为零，并观察 ModelContext.willSave 为零；候选用例的初始合成标签保存另计，帮助操作后模型身份/数量不变。任务/手记草稿、筛选及原菜单/搜索/页签快捷键回归通过。

一次 Escape 前后保持同一原生编辑器、firstResponder、选区、文本和预览/候选状态，帮助关闭后 syntaxOverlayHost 恢复；下一次 Escape 才进入原输入处理。程序化 marked text 期间保留帮助、组合文本和编辑器，unmarkText 后下一次关闭；不是真人输入法验收。更高层筛选只关闭自己；原生窗口响应者、四类修饰键、双实例、帮助重开、隐藏窗口迟到事件、窗口重新显示和卸载后事件通过。无窗口处理函数补测只是旁证，主证据来自生产 FooterBar 菜单和窗口事件。生产帮助悬停自然通过，不扩大到标题/备注或直接卡片历史悬停。

**外观核验**：首次检查缓存图发现原测试只给子视图 preferredColorScheme，外层 AppChrome 的 system 偏好导致标为 dark 的图实际仍浅色；该批不计深色视觉通过。本轮测试改为显式设置随机 suite 的 appearance，并断言实际 window.effectiveAppearance，不改系统/个人偏好或共享 helper；`build/SurfaceStageE-fix2-appearance.xcresult` 完整重跑帮助 16 项 / 30 次全部通过，实际浅深色断言成立；替换前包同名结果后仍为 39 项 / 69 次通过、0 失败、0 跳过。一次构建锁忙未执行，锁释放后才运行。已查看中英文 capture/search 的浅深色缓存图，保存于 `build/SurfaceStageE-fix2-visuals`；卡片不再叠加遮罩颜色，356pt 宿主仍沿原固定 380pt 内容居中裁切，不改菜单栏尺寸。缓存图与几何不等于窗口合成器屏幕或真人证据。

**门禁与边界**：六个本轮 Swift 文件严格局部 SwiftLint、静态质量门禁（含 211 项脚本回归）、工作流与差异检查通过；本轮未修改检查器。`./scripts/build.sh --no-wait` 的 Debug 构建与静态验签通过，日志 `build/SurfaceStageE-fix2-debug.log`；沿原 development 配置，staticSignatureVerified=true、hardenedRuntime=true、distributionReady=false。前期/并发差异和未跟踪文件保留，暂存区未动。指定 Cursor verifier 不可调用，不认证或替换，整体保留 **partial** 复核缺口。真人输入法、实际状态栏生命周期、VoiceOver、低版本系统未验；标签标题/直接卡片悬停、复制、滚动等其他历史缺口未修。本轮只解除帮助点击/Escape 阻断，F 需另行任务推进；此处停止，不提交、推送、安装、发布或修改真实数据、系统偏好、签名配置与权限。

## 第八阶段 D：两类实时预览主外壳

2026-10-04，macOS 26.6.2 arm64。范围与参数见[组件目录](component-catalog.md#第八阶段-d两类实时预览主外壳)。任务 mainRow 仅替换背景/边框为 suggestions，保留水平 10pt、36pt 及独立/伴随候选的自身外壳；手记仅删除 floatingBackground/floatingBorder，在原 row 后使用 smallBackground / !showsSuggestions。新预设与 suggestions 共用背景阴影装配；small/continuous、页面底色和 70% / 0.7pt 居中描边不变，readOnly 继续整体阴影。没有新增布局、裁切、命中、状态、回调或生产消费者，历史 Theme 组合未搬文件。

**隔离**：完整正常 AreaChain XCTest、build/PrivacyQA-Preview8D、com.areachain.privacy-qa、build/.build.lock、本地临时签名、生产 sandbox entitlement、LSUIElement=NO；清除六项真实钥匙串变量并串行执行。仅由 XCTest 挂载生产组件，合成内存数据和随机偏好 suite；不排除源码、不直接打开 QA/日用应用。保护前期及并发修改、未跟踪文件与暂存区。SHA-256 确认 SyntaxAutocompleteView、SyntaxOverlay、UnifiedSearchOverlay、CaptureAttributesView、DaybookScroller、DaybookRowBubbles、SyntaxHelpCard 相对本轮基线全未变；两个预览剩余代码由实际差异逐项核对。

**修改前基线**：首包 PreviewStageD-baseline 被并发 CommandProtectedTextView 的 NSTextStorage.EditActions 编译错误阻断，零测试；本轮未修改该源码。对方修正后，`build/PreviewStageD-original.xcresult` 的 summary/tests 树确认 3 套、10 项 / 20 次：9 项 / 18 次通过，1 项 / 2 次失败，0 跳过。通过原两预设完整像素/几何、关闭装饰/命中对照、生产 SyntaxOverlay 上下宿主/候选单次鼠标/两次 Escape/外部点击/失焦/卸载，以及直接预览双语、浅深色、240/356pt、长标题/多标签/溢出、锚点身份与 onAppear。敏感预览读取复制按钮失败，复制并未触发；不把该项写成通过。

**过程与最终结果**：baseline-supplement、baseline-complete 与 regression 包先后被并发搜索的 greatestFiniteMagnitude / willCloseNotification 错误阻断，均未命中测试。并发源码修正为 CGFloat.greatestFiniteMagnitude 后，`build/PreviewStageD-acceptance.xcresult` 命中 **16 套、84 项 / 120 次：83 项 / 118 次通过，1 项 / 2 次失败，0 跳过**。通过 DaybookSurfaceTests、扩展后的 DaybookFloatingSurfaceTests、LivePreviewCompositionTests、OverlaySurfaceConsumerTests、CaptureOverlayLayoutTests、DiaryComposerInteractionTests、MenuBarPopoverRenderingTests、SyntaxOverlayPlacementTests、SyntaxAutocompleteTests、InputSyntaxInteractionTests、UnifiedSearchInput/Layout、原共享搜索呈现/接受及 ControlsPreview 的 galleryRenders；LivePreviewSurfaceTests 的双语/主题矩阵与身份/任务关闭通过，复制用例失败。

新公共预设与冻结手记装饰在静态合成内容、完整 32pt 外缘、越界图形下逐像素一致；三预设的 isPresented 不增加 onAppear，不改尺寸、本地状态/身份，关闭时与无装饰内容相同，原命中轨迹保持。row 的程序化 hovered/presented 四组合在浅深色下与原叠放完整像素一致。两类原生输入候选出现/消失保留草稿、选择范围、同一编辑器与焦点；一次 Return 只接受一个候选，按原 trigger.range 替换且零提交。任务关闭只 dismissPreview，保留候选、属性状态和草稿；原菜单栏/工作台捕获、手记入口、marked text、撤销与共享搜索许可沿既有测试回归。没有新增模型写入或标签创建。

**复制与悬停缺口**：原基线与接入后均无法从辅助树取得 diary.copy。copy-hover 包尝试原生 mouseMoved/追踪区进入仍失败；copy-action 包的嵌套 Testing 宏触发 Swift 编译器断言，拆开后 copy-combined 包确认该树没有合并复制动作。最终 `build/PreviewStageD-copy-pointer.xcresult` 在移动测试指针、派发合成 mouseMoved 并退出恢复原指针后仍有 1 项 / 2 次失败，0 跳过。最新测试保留失败断言，未加生产复制替身、未改显隐或 .accessibilityElement；不能由测试未找到节点推定产品复制回调失败。onCopy 注入虽已装配，但实际尚未触发，因此敏感复制参数、复制反馈跨装饰切换和实际悬停操作未验；更多菜单呈现/关闭也未验。所有默认 NSPasteboard 动作均未点击，真实剪贴板未测试。

**图像与几何**：`build/PreviewStageD-before` 保存 140 张完整缓存图及 JSON；`build/PreviewStageD-after` 从 acceptance 时间段提取 160 张。132 个共同场景已记录的锚点/滚动几何均相同，80 张整图像素相同。差异全在手记：36 个同输入场景有 Date() 时间字形及后方标签位置变化；另 16 个长手记夹具从换行改为原 // 显式备注语法，不作为同输入像素对照，修改前独立备注证据缺口保留。即 **116 个同输入场景几何相同，其中 80 张整图相同**，不能把几何写成整图一致。公共三预设及 row 对照的另外 28 张静态图在测试内逐像素通过，完整阴影/边缘未裁切。已查看四类主卡独立/伴随候选的全外缘对照 `build/PreviewStageD-comparison.png`（中性底合成、完整缓存图缩放），以及窄任务溢出/长手记基线；它们不是窗口合成器截图，不宣称与正式列表像素统一。原任务双层与手记伴随候选无自身浮层装饰保持。

**门禁**：8 个相关 Swift 文件严格局部 SwiftLint、Swift 语法、check_workflow、git diff --check 通过；原检查器只增 smallBackground/两预览稳定入口与反例，定向 **87 项**通过。`quality_gate.py --profile static --strict` 通过，包含 **207 项**隔离脚本回归，日志 `build/PreviewStageD-static-final.log`。初次 Debug 同并发错误失败；最终 `./scripts/build.sh` 的 `build/PreviewStageD-debug-final.log` 成功，沿原 development 配置，staticSignatureVerified=true、hardenedRuntime=true、distributionReady=false。完整正常目标保留原 SDK 弃用/actor 等警告；不改签名配置。文档最终回填后重跑静态/工作流与差异检查。

**状态：部分完成（partial）**。已实现并验证主外壳接入，仍有上述 1 项 / 2 次复制入口验收失败；没有以旧通过、跳过或构建代替。公共身份、程序化状态/row 悬停、合成鼠标、原生编辑/marked text、缓存图及实际 visible/key 窗口挂载分别取证；真人输入/IME、VoiceOver、真实屏幕截图、窗口边缘完整矩阵和实际复制未验。指定 Cursor verifier 当前不可调用，不重复认证或替换机制。B 的周列/甘特浮层错绑、羽化定位与滚动命中缺口继续保留。ControlsPreview 原样例已扩展；剩余标签详情（140pt、60%/0.8pt）、标题/备注动态边框及帮助卡参数只登记线索。到 D 停止，不迁移其他控件，不提交、取消暂存、推送、安装、发布，未改真实数据、系统偏好、个人签名或权限。

## 第七阶段 D：隐私设置安全输入接入

2026-10-03，macOS 26.6.2 arm64。生产只修改 PrivacySetupSheet 的四处 SecureField → DaybookSecureField，并移除 roundedBorder；已有四个稳定标识继续使用。原 valid、submit、authenticate、clearPasswords、task/probeSystem、候选统计和 busy 规则保持。公共输入/输入壳与 B/C 消费者不改；接口和剩余清单见[组件目录](component-catalog.md#第七阶段-d隐私设置安全输入接入)。

**基线与隔离**：沿完整正常 AreaChain XCTest / PrivacyQA、build/PrivacyQA-Setup7D、com.areachain.privacy-qa、原 build/.build.lock、临时签名/生产 sandbox entitlement、LSUIElement=NO、六项真实钥匙串变量清除、串行与 -jobs 2；没有排除源码。原 SetupFixture 直接挂生产 sheet，probeSystem:false，MemoryVaultConfigurationStore、FakeSystemVaultKeys、内存模型和随机 suite，等待原 task 选中合成标签再稳定窗口。测试入口补齐工作区中已有引用但缺失的 SetupSecureTestSupport；保留原隐藏恢复断言，字段按独立 AXSecureTextField 身份再对应原生编辑器，不按重复文案或固定下标定位。

修改前 `build/Setup7D-current-native.xcresult` 命中 10 项 / 35 次，9 项 / 31 次通过；4 次失败仅是新测试错误要求原 SecureField 必须有 accessibilityLabel，原生实际由 placeholder 提供名称。调整为检查名称/占位符原生来源后，`build/Setup7D-native-supplement.xcresult` 的 4 项 / 9 次全部通过（含新增标签候选归零/恢复）；`build/Setup7D-native-locale.xcresult` 的 1 项 / 1 次通过，额外证明语言切换后的四份 600 Character 长草稿及合法状态保留，均无跳过。初次编译另修正 Swift Testing 宏与 allSatisfy 键路径写法的不兼容；同名旧结果包拒绝覆盖的一次命令未运行测试，后续改用独立结果名，旧包不计本轮证据。

原版四字段原生尺寸均为 432×24pt，展开 sheet 为 480×548pt，滚动区 432×430pt。原初始焦点可能在字段外或备份首字段，未把它固定成自动聚焦契约；主动编辑后 Tab 顺序为主密码→主确认→备份→备份确认→主密码。原 Return/⌘Return 不提交，Escape/取消关闭与重开初始化正常。中文深色四字段实际可见窗口由 CUA 只读取得，安全值仍遮蔽；缓存图另存 build/Setup7D-visuals/native，不将它等同全部窗口材质验收。

本轮只允许 Setup 的提交前状态及原内存回退提前失败：测试进程保存/设置/恢复 StoreHealth.shared.isUsingMemoryFallback，合法键盘和 Apply 前先确认保护，guard 位于所有配置、认证、文件面板和迁移动作之前。提前失败验证 storageFailure、四字段清空、错误和 busy 恢复；回读配置、fake keys、vault 代次、模型快照/数量、标签及测试偏好无变化。不能推广为成功应用、备份取消、迁移中失败或完整认证链证据；外部 disabled 也不代表异步 busy 全生命周期。界面清空不表示 Swift String/内存安全擦除。

**接入后首轮**：`build/Setup7D-migration.xcresult` 命中 11 项 / 37 次，10 项 / 33 次通过。四次失败均来自本轮新增的固定模型数量断言：原 initialShapeAndModeRules 在同一 support 库逐次创建夹具，记录自然累积。改为保存各夹具建立时七张表数量再对照，未删除检查或重建宿主。隐藏/恢复、独立校验、语言变化、键盘、取消与提前失败均无新增行为失败。原生字段改为 422×16pt，外壳 28pt；四字段 sheet 仍为 480×548pt，滚动区仍为 432×430pt。 已查看原/新缓存图的四字段与错误状态，缓存中出现浅紫底/透明背景；CUA 后续取得实际英文深色四字段、中文深色备份组及英文管理无字段画面，实际四字段为深色表面并保持原生遮蔽，没有复现缓存浅紫底。此有限可见窗口证据不覆盖所有语言/主题状态或真人输入。



**最终有效证据**：`build/Setup7D-regression.xcresult` 已核对 summary 和 tests 树，实际命中 8 套、23 项 / 76 次：22 项 / 74 次通过，B 的 sameValueDuringBusyRetainsOriginalNativeReadbackBoundary 为 1 项 / 2 次已知预期失败，0 新增失败、0 跳过。Setup 两套共 8 项 / 23 次全通过；另覆盖原标签选择、Setup 校验/真实 sheet 取消、DaybookSecureFieldTests、B 的两套输入/编辑测试、原密码按钮与 ControlsPreview 的完整 galleryRenders 选择器。公共层新增测试用计数回调复现 B 的函数引用与 C 的闭包 onSubmit 修饰形式，Return 各传播一次、⌘Return 不提交；C 生产接线及公共输入/壳/B 消费者 SHA-256 相同，未重跑 C 的认证链，不能将计数回调写成认证验收。

最终 Setup 覆盖创建/管理与配置组合、无字段/主密码/备份/四字段、两组空值与 11/12 Character/不匹配、组合 Unicode、12 空格不 trim、两组可不同、单字段只更新对应 Binding、隐藏恢复/标签/includeLegacy/系统方式互不串改、长输入、原生安全角色/占位符、禁用环境、语言切换后草稿及校验、Return/⌘Return、Tab、Escape/取消重开、滚动编辑/帮助及底部按钮。安全断言输出布尔、次数或长度，未读取明文 AX value；截图只保留遮蔽。初始焦点实测前后都有字段外/备份字段两种情况，没有引入自动聚焦。原成功清空和后续安全流程仅做逐字差异核对，不声称执行过。

**最终门禁**：五份相关 Swift 严格局部 SwiftLint、82 项工作流检查器测试、工作流/差异检查、`quality_gate.py --profile static --strict`（含 202 项脚本回归）通过。检查器沿原 COMPONENT_ENTRIES 增加 Setup 接入和四个身份，点分身份不能被更长的确认字段身份替代，反例保留。`build/Setup7D-current-debug.log` 为原 ./scripts/build.sh Debug 构建与静态验签成功；沿既有 development 配置，只生成产物。完整正常目标保留原 AppKit 弃用等警告，没有排除源码或启动普通测试宿主；文档收尾后复跑静态/工作流检查。

**状态：partial**。指定 Cursor verifier 当前不可调用，未重复认证或替换。B 的双字段特定 busy/失败重试残留仍由原断言记录，未重建宿主、额外清空或删除断言来改成通过。原生 SecureField 装配/外部更新/语言刷新可能空值回写的公共对照继续保留；本轮 Setup 指定隐藏恢复和语言场景通过不能消除该一般限制。真人输入法、系统粘贴、真人撤销、VoiceOver、低版本系统及完整实际窗口绘制矩阵未运行；周布局/切周焦点、真实拖放和其他控件 Tab 等历史缺口保留。异步 busy 全生命周期、成功应用、备份取消、迁移中失败与完整认证链均未执行。生产安全输入静态清单收齐七字段，搜索/任务/手记编辑器只登记线索；没有提交、推送、安装、发布，未改真实数据、系统偏好、个人签名配置或权限。到第七阶段 D 停止。

## 第七阶段 C：解锁面板安全输入接入

2026-10-03，macOS 26.6.2 arm64。生产差异仅 PrivacyUnlockView 一处 SecureField → DaybookSecureField 并移除 roundedBorder；原认证、清空、busy、取消、Presenter 和 PrivacyAccess 逐字保持。公共组件/输入壳、PrivacyPasswordSheet、PrivacySetupSheet 的阶段前后 SHA-256 相同。接口与后续四字段线索见[组件目录](component-catalog.md#第七阶段-c解锁面板安全输入接入)。

**隔离与基线**：完整正常 AreaChain XCTest 目标、build/PrivacyQA-Unlock7C、com.areachain.privacy-qa、原 build/.build.lock、临时签名/生产 sandbox entitlement、LSUIElement=NO、六项真实钥匙串变量清除及串行测试。只由 XCTest 启动，所有 View/request 显式注入 MemoryVaultConfigurationStore / FakeSystemVaultKeys；仅合成密码和内存模型，原 Presenter 的 shared locale 只读，实际为 en。直接 View 另注入 en/zh-Hans、浅深色；不能写成 Presenter 双语验收。

`build/Unlock7C-baseline-host.xcresult` 在生产替换前命中 2 套、7 项 / 22 次，全通过、无跳过。同一测试和宿主用于接入后比较。三配置原实际 Presenter 内容高度为 password 222pt、system 172pt、both 260pt，宽均为 390pt；原始创建参数仍为 390×300pt，NSHostingView 按内容调整面板。原字段为 346×24pt。初始焦点不在密码字段，点击字段后 Tab 留在字段；Return 只提交一次，空字段 Return 仍进入原 wrongPassword 路径，⌘Return 不提交。测试按原限流等待后再试，没有修改时钟、限流或密码规则。

直接 View 验证三配置、稳定安全 AX 节点、占位符/标签、原文 UTF-8、错误和忙碌长说明；onCancel 计数只代表回调。原 Presenter 验证密码/替身系统成功、失败保留同一面板后重试、空闲及 busy 的取消/Escape/performClose。取消前使用已解锁 vault 强制请求，取消后锁定来自原 Presenter，未手动 lock 冒充接线；释放 fake 等待后，旧结果未恢复有效会话。测试失败清理也只关闭本例归属面板并释放 request/替身 continuation。

**过程问题**：初次完整编译被并行 UnifiedSearchOperationPreview 缺少 return 阻断；后续可见检查又遇到并行 UnifiedSearchObjectInteractionTests 的辅助 API 编译错误。本轮没有改这些源码、排除文件或更换目标；对方更新后继续正常完整编译。早期原控件试跑的测试假设（直接 View 自动聚焦、无父窗口的 NSPanel 激活）失败，改为记录真实初始焦点、明确点击空字段，并沿 PrivacyAutolockTestSupport 建立隔离父窗口后才得到上述有效基线。一次命令模板曾误替换两个 PHASE 环境变量名，其结果不计有效证据；有效基线与回归均清除六个原变量。

**接入后有效证据**：`build/Unlock7C-regression.xcresult` 实际命中 8 套、28 项 / 81 次：27 项 / 79 次通过，B 的 sameValueDuringBusyRetainsOriginalNativeReadbackBoundary 为 1 项 / 2 次已知失败（原断言保留，lengths=[0,15]），0 新增失败、0 跳过。已逐项核对 summary 与 tests 树，包括 DaybookSecureFieldTests、PrivacySecureInputTests、PrivacySecureEditingTests、两套解锁新测试、原 PrivacyAutolockPickerTests、四个选定 PrivacyButtonConsumerTests 方法和 ControlsPreview 的完整 galleryRenders(locale:dark:) 选择器。解锁直接 View / 原 Presenter 共 7 项、22 次在同一宿主/配置/操作下全部通过；旧 B 失败不计为清空通过。

**布局与呈现**：密码配置实际 Presenter 内容高度 222→226pt，双方式 260→264pt，仅系统仍 172pt；长 reason 加错误 345→349pt，宽均保持 390pt。28pt 公共外壳的原生内字段由 346×24pt 变为 336×16pt，标签/按钮分组及系统全宽入口保持。双语浅深色直接视图和真实 en Presenter 的长说明、busy、错误、底部取消边界检查通过，未发现新增几何裁切；未修改 Presenter 初始尺寸或窗口机制。初始均未自动聚焦，明确点击后 Tab 仍留字段，未误触相邻系统入口。NSSecureTextField、AXTextField/AXSecureTextField、稳定标识和遮蔽保留，辅助名称/帮助/标题不包含合成密码。已查看 build/Unlock7C-visuals/native 与 migrated 的遮蔽、长文案/错误缓存图，复用原 ControlsPreview 安全输入样例，没有新应用入口或真实认证展示。

**最终检查**：四份本轮 Swift 的严格局部 SwiftLint、原检查器 81 项定向测试、工作流/差异及静态质量门禁（--profile static --strict，含 201 项脚本回归）通过，最后文档编辑后复跑。稳定守卫只沿原 COMPONENT_ENTRIES 增加解锁接入和 privacy.master.input 及反例；没有新执行器。`build/Unlock7C-debug.log` 对应原 ./scripts/build.sh Debug 构建/静态验签通过，沿现有 development 配置，不安装/直接启动，不等同发行。完整目标保留既有 AppKit 弃用警告；没有排除源码。验证命令继续采用静态 profile 配合独立隔离 Swift 测试，未另起普通测试宿主。

**验收状态：partial**。指定 Cursor verifier 不可调用，未重复认证或替换机制。接入前后受控可见面板的 CUA 读取均超时；ControlsPreview 与缓存截图不证明实际窗口材质、真人输入法/粘贴/撤销或 VoiceOver。B 的同值重试确认字段残留保留原断言与归属，不计为通过；历史周布局、拖放和其他控件 Tab 等缺口不扩修。真人输入法、系统粘贴、真人撤销、VoiceOver、低版本系统和真实安全业务未运行；程序化编辑、应用事件、窗口 performClose 均只算对应隔离证据。完成后停在 C，没有迁移 Setup/搜索/任务/手记编辑器，没有提交、推送、安装、发布或真实数据/系统偏好/签名配置/权限修改。

## 第七阶段 B：公共安全输入与通用密码弹窗

2026-10-03，macOS 26.6.2 arm64、Xcode 26.6 / Swift 6.3.3。接口、四种配置及后续边界见[组件目录](component-catalog.md#第七阶段-b公共安全输入与通用密码弹窗)。生产只新增 Theme 的 DaybookSecureField，并替换 PrivacyPasswordSheet 两个字段/移除 roundedBorder。原 submit、Task、密码规则、busy、错误和生命周期保持逐字一致；两父页只读取参数和关闭责任，没有执行 changePassword、disableSystemUnlock、认证、文件面板、备份或恢复。

**隔离与基线**：沿原 build/.build.lock、完整正常 PrivacyQA XCTest 目标、独立 build/PrivacyQA-SecureInput7B 与 com.areachain.privacy-qa、临时签名/生产 sandbox entitlement、LSUIElement=NO、六项真实钥匙串环境清除及串行执行。只由 XCTest 启动宿主，SettingsButtonTestSupport 提供内存模型/随机 suite，旧 PrivacyButtonConsumerTests 使用原 PrivacyFixture；没有直接打开 QA 或日用 App。`-jobs 2` 只限制编译并发，不排除源码。

修改前直接挂载生产 PrivacyPasswordSheet。`build/SecureInput7B-original.xcresult` 中布局/角色/Return/取消/重开与安全编辑 3 项、13 次通过；busy 的单字段 2 次通过，双字段 2 次因同值重试后的原生 getter 非空而失败。首轮 `baseline` 另有错误的直接 NSSecureTextField AX 角色、⌘Return 提交次数和 action 时刻画面清空假设，均保留失败结果。改用不同的等待期输入以验证新旧输入隔离后，`build/SecureInput7B-original-retry.xcresult` 四种配置全部通过。没有改原提交逻辑来适配测试。

**原生基线与尺寸**：原控件 NSSecureTextField 自身为 AXUnknown，SwiftUI 辅助节点为 AXTextField / AXSecureTextField；cell.echosBullets 为 true。原生字段 392×24pt、13pt 字体；新公共壳 28pt，内部原生字段 382×16pt、字体仍 13pt，sheet 保持 440pt。主密码单字段原 en/zh 为 203/187pt，双字段 241/225pt；备份单字段 219/187pt，双字段 257/225pt。迁移后单字段分别增加 4pt、双字段增加 8pt。两种语言、浅深色、长说明/错误/第二字段及按钮边界使用隔离真实 sheet 验证；缓存图有透明背景，不代表系统材质验收。

**提交和原生事件**：初始聚焦首字段，双字段 Tab 从第二回第一；Return 在任一字段提交一次，⌘Return 不提交。空值/不匹配禁用，按钮走同一入口；提交先捕获并清宿主字段，Task 调 action，成功才 onComplete。画面刷新与 action 启动不保证同一时刻，测试在刷新后查清空，不把 AppKit getter 当作宿主 State 的同步探针。busy 输入仍可编辑，新旧值在闭包内比较布尔，等待后复核原 input 未变；busy 的按钮/Return/⌘Return/Escape/performClose 不重入或关闭。失败显示原错误、不自动重试；新编辑保留错误，重试才清错误。成功可以留在 sheet，也可由注入父回调关闭；空闲取消/Escape 关闭，同一父窗口重开输入为空。performClose 与 Escape 是程序化原生事件证据，不宣称真实手势关闭已测。

**证据边界**：输入 API 的特殊字符、空格、Unicode 字节序列及选区/长输入通过；原生键入事件单独测试。查询到原生 Copy/Cut 菜单不可用、UndoManager 可用，但未执行复制、剪切、真人撤销或程序化 marked text。外部 Binding 更新与本地化刷新可能触发原生 SecureField 空值回写，公共层不拦截原生编辑引擎；公共/直接原生对照记录次数，不套用普通 TextField 的零回写假设。没有明文 AX 读取、密码日志或持久输入采集；截图保留原生遮蔽。字段清空不代表 Swift String/内存安全擦除。

**原有失败保留**：双字段 busy 期间重新输入与已提交值相同的内容，注入失败后按原值重试，原生确认字段可能仍显示遮蔽字符。迁移前 original 包有两次失败，迁移后 final 包的 lengths=[0,15] 及截图再次确认；宿主保存已禁用，Return 不会再次提交。测试保留精确断言并标记已知问题，不用重建窗口、额外 Binding 镜像或修改 submit 掩盖。常规等待期新旧不同输入的清空/隔离场景已通过；不能把它扩写为所有重试都清空成功。

**过程中的检查结果**：原生 getter/⌘Return/AX 假设、外部更新回写次数及测试完成计数曾使新增测试失败，已按原生对照定位；`migrated` 包为 26 次通过、4 次外部回写假设失败，`final` 包为 34 次通过、4 次新测试的对照布局/回写/成功计数失败。gallery 初次选择器未命中，随后使用完整 `galleryRenders(locale:dark:)` 并在结果树确认，不以零命中算通过。`verified` 最终复跑遇到用户锁屏，38 次全部在原焦点门禁失败，前台 com.apple.loginwindow；没有跳过焦点断言，待用户手动解锁后复跑。

**最终有效证据**：用户解锁后，`build/SecureInput7B-unlocked.xcresult` 实际命中 5 套、11 项 / 38 次：10 项 / 36 次通过，1 项 / 2 次为上述原有已知失败，0 新增失败、0 跳过。已核对 summary 和 tests 树，范围为 DaybookSecureFieldTests、PrivacySecureInputTests、PrivacySecureEditingTests、原 PrivacyButtonConsumerTests.passwordValidationBusyFailureAndRetry，以及 ControlsPreview 的 galleryRenders。相关用例在同一原宿主刷新，只有生命周期用例主动卸载/重建。已知失败保留原断言与 withKnownIssue，不计为清空通过。

本次原生语言更新对照中，公共字段 setter 次数 3→4，直接 SecureField 为 6→8，回写均为空值；单独外部清空无额外 setter，二者均不提交。不同次数属于实测原生装配差异，不宣称每次调用数完全相同。普通业务只读写原宿主 State，没有新增过滤/去重/清空策略。实际输入及确认字段辅助名称、原生遮蔽、运行时语言切换、禁用/多实例、拒绝 Binding、外部清空、重建/拆卸检查通过。

已查看 `build/SecureInput7B-visuals/original` / `migrated` 中的原/新双字段、公共聚焦/失焦/禁用、长说明错误和同值残留缓存图；均只含原生遮蔽及合成说明。实际 sheet 缓存图还出现局部输入底色差异，保留真人窗口绘制补验，不用缓存图宣称系统材质或清空后绘制全部通过。严格局部 SwiftLint（本轮 9 个 Swift 文件）、工作流、差异检查、79 项检查器定向测试及静态 profile（含 199 项脚本回归）通过；原 `./scripts/build.sh` Debug 构建/静态验签通过，沿既有 development 配置，没有安装/直接启动。完整目标仍有原有编译警告。输入壳与普通表单未改，未机械重跑全输入系统；auto/swift profile、全量应用测试、真实安全业务和指定复核未运行。

**状态**：本阶段整体 partial，指定 Cursor verifier 当前不可调用，未重复认证或替换。真人输入法、系统粘贴、真人撤销、VoiceOver、低版本系统及历史周布局/切周焦点/真实拖放/其他控件 Tab 缺口继续保留。PrivacySetupSheet、PrivacyUnlockView、搜索、任务/手记编辑器均未迁移；没有提交、推送、安装、发布、真实数据/系统偏好/个人签名/权限变更。


## 第七阶段 A：普通表单输入与三个输入框

2026-10-03。实现入口与责任分工见[组件目录](component-catalog.md#第七阶段-a普通表单输入与三个输入框)。仅修改普通表单组合与两处生产定义，未修改 DaybookInputShell、DaybookTextField、搜索或安全输入。使用原 build/.build.lock、独立 build/PrivacyQA-FormInput7A、com.areachain.privacy-qa、临时签名/生产 sandbox entitlement、六项真实钥匙串变量清除、完整正常目标与串行 XCTest；不直接打开 QA 或日用应用。

修改前直接挂载原消费者：`build/FormInput7A-baseline-lowjobs.xcresult` 实际通过 8 项 / 23 次，含原标签弹窗、ClipboardOptionsConsumerTests 和 DaybookInputShellTests，0 跳过。新增按键刻画被测试辅助点击阻塞：同步 mouseDown 进入 NSTextField 的选区跟踪，mouseUp 尚未派发；采样定位后中断本轮 QA 进程，改为先排队完整事件，未改共享 SettingsButtonTestSupport。该中断不能算通过。最初的辅助代码编译错误已修正；另一次完整编译因临时空间不足失败，降低构建并发后成功进入运行。后续补充基线编译遇到并发统一搜索新定义尚未齐备，未排除或改写无关源码。

并发目标恢复可编译后，仅暂时恢复本轮拥有的两个消费者片段；`git diff --exit-code` 确认与修改前版本一致，再直接挂载原消费者。`build/FormInput7A-original.xcresult` 补测 3 项 / 9 次全部通过，0 失败、0 跳过，随后恢复迁移。原标签 roundedBorder 的原生字段为 208×24pt，sheet 为 240×118pt；迁移后壳高 28pt、内部字段 198×16pt，sheet 为 240×122pt。剪贴板原 plain 内部字段高 16pt、横向 369.5pt，迁移后壳高 28pt、内部字段宽 355.5pt；页面仍为 440×560pt，添加按钮仍与字段同行。

**最终运行**：`build/FormInput7A-final.xcresult` 实际命中 11 套、32 项 / 64 次，全部通过，0 失败、0 跳过；已核对结果包 tests 树。范围为 DaybookFormTextFieldTests、DaybookFormNativeParityTests、FormInputConsumerBaselineTests、ClipboardFormInputTests、TagFormInputConsumerTests、DaybookInputShellTests、ClipboardOptionsConsumerTests、TagRepositoryTests、ClipboardHistoryRulesTests，以及 DiaryButtonConsumerTests 的原标签弹窗和 DaybookButtonInteractionTests 的 galleryRenders。完整正常目标按架构文档参数执行，额外 `-jobs 2` 仅限制编译并发，`-only-testing` 限定执行，不排除源码。原 `build.sh` Debug 构建与静态验签通过，沿既有开发签名配置，未安装/启动。

**原生事件与输入分层**：前后实测初始标签字段获焦，剪贴板长列表 sheet 未聚焦文本字段；点击可进入原生编辑。Return / ⌘Return 不创建或添加，Escape 关闭 sheet，⌘Escape 保留标签 sheet。当前系统键盘导航配置下，标签 Tab 留在唯一文本字段，剪贴板 Tab 在正则/类型字段间轮转；未把它推广为所有键盘导航设置通过。原生 NSEvent 普通键入、选择替换、外部 Binding 更新、拒绝写入后重建回读、禁用和多个实例通过。原生 UndoManager 撤销/重做恢复连续编辑的合并组，测试起初误以为仅撤销最后一段，已按观测修正；程序化 setMarkedText/insertText 的中文组合完成通过。原生插入 API 对照保留反斜杠、括号、`# @ ! //`、Unicode、换行与 Tab，没有套用任务文本归并；这是合成粘贴负载证据，不是系统剪贴板粘贴或真人输入法验收。

**真实消费者**：标签空白禁用、预设名拒绝、回调失败保留、编辑清错、重试成功、取消及重开初始化通过；待办/习惯创建关联和新建重复事项的原标签即时保存均经过隔离库回读。重复事项使用真实外层 sheet，取消后已创建标签仍在，事项未创建。剪贴板有效/无效/重复正则、空白/重复/sealedTypes 类型拒绝、成功清空与失败保留、字段独立、编辑不保存、添加后偏好回读、取消重开及同 suite 重建通过。Bool 仅表示原校验接受/拒绝，没有新增或宣称磁盘保存失败回滚契约。

**布局与视觉**：中英文、浅深色、240pt 标签 sheet、440×560pt 剪贴板和原 ControlsPreview 均运行；长文本保持单行水平编辑。原正则错误与原生字段 AX 边界相交，迁移后位于字段下方 9pt，不与字段/添加按钮重叠。缓存截图保存于忽略目录 `build/FormInput7A-visuals/original` 与 `migrated`，已查看原/新剪贴板错误、标签字段、公共聚焦/失焦/禁用和长文本样例；部分 sheet 缓存含透明背景，不据此宣称系统材质通过。没有新展示应用。

**静态检查**：严格局部 SwiftLint、差异/未跟踪文件检查、`python3 -B scripts/check_workflow.py`、77 项检查器定向测试及 `python3 -B scripts/quality_gate.py --profile static` 通过，后者收尾复跑包含 198 项脚本回归。检查器仅扩展公共入口和两个消费者的稳定符号守卫及反例，不证明运行时语义。期间并发 ContentQueryReadSession 的 505 行超限曾使工作流失败，后续对方更新后恢复通过，本轮未修改该文件。首轮迁移回归的两项失败均为新测试假设（撤销分组、辅助 Bool 读取）并已修正重跑；没有删除产品规则或排除源码。完整测试编译仍含无关历史警告。auto/swift profile 和全量应用测试未运行，以免另起普通宿主或扩大范围。

**整体 partial**：指定 Cursor verifier 不可用，未重新认证或替换；真人输入法、系统剪贴板粘贴、真人键盘撤销/VoiceOver、低版本系统，以及历史周布局/切周焦点/真实拖放/其他控件 Tab 等缺口继续保留。不读取真实数据、生产剪贴板或历史，不启动监听；不提交、推送、安装、发布或改签名配置与权限。到第七阶段 A 停止。

## 第六阶段 E：周视图日期列头接入

2026-10-03，macOS 26.6.2 arm64、Xcode 26.6 / Swift 6.3.3。接口和剩余范围见[组件目录](component-catalog.md#第六阶段-e周视图日期列头接入)。使用完整正常 PrivacyQA XCTest 目标、原 build/.build.lock、独立 Bundle ID/DerivedData、临时签名与生产 sandbox entitlement，清除六项真实钥匙串变量，保持串行。只使用合成内存数据，导航/BoardSelection 由原夹具保存恢复；没有直接打开 QA 或日用应用。

修改前 `build/WeekE-baseline.xcresult` 实际命中 9 项：7 项通过、2 项已知失败（共 19 次，14 次通过、5 次已知失败），0 非预期失败、0 跳过。直接挂载原 CalendarWeekBoard 与 CalendarPage。列头 caption semibold/title 两行左对齐，间距 2pt，quiet 原内边距上下 3/左右 6pt；实测按钮高 41pt，1100pt 测试窗口扣除 20pt 外边距后列头宽 132.5/133pt，空/非空一致。原列内 6pt、列头到列表 6pt、列间 8pt。两侧边缘可点，列间隙/列表/底部空白不选日；按下有像素变化，点击保持原 firstResponder。原全尺寸截图在 `build/WeekE-visuals/baseline`，包含双语浅深色、1100/420pt 直接宿主及 1000/420pt 生产页面。420pt 原周越界、标题挤压和列表切周焦点仍属历史问题，未修复、未算通过。

**接入与原生对照**：`build/WeekE-regression.xcresult` 实际命中 18 套、43 项 / 96 次：41 项 / 91 次通过，2 项 / 5 次为原有已知失败，0 非预期失败、0 跳过。`build/WeekE-preview.xcresult` 在最后增加展示宿主定位后重跑 DaybookWeekHeaderTests，3 项 / 9 次通过；替代前包该套证据后，最终有效范围 44 项 / 100 次，其中 42 项 / 95 次通过、2 项 / 5 次已知失败。未使用零命中或已知失败充当通过。结果包的 tests 树已逐项核对，命令均使用架构文档的 PrivacyQA 参数、`-parallel-testing-enabled NO` 及完整正常目标，仅用 `-only-testing:AreaChainTests/<套件或完整方法签名>` 限定执行范围。

公共周列头 32 组像素/边界对照覆盖两语言、浅深色、两种按钮宽度及今天/选中四态，全部与冻结旧列头一致；另有 Gregorian/Buddhist/Hebrew 与 Auckland 环境对照，保留 shortStamp 默认日历、日号/完整辅助日期环境日历的差异。16 组生产周看板的七列 AX 几何及边缘命中记录与修改前完全相同。完整宽窗口截图有单列背景/描边差异，与未修改的 DaybookSurface 悬停外观一致，因此没有宣称宽窗口整图像素一致，也未裁切以消除差异；12 张窄窗口全图一致仍不表示旧越界通过。截图保留在 `build/WeekE-visuals`，已查看公共列头、真实周页及原 ControlsPreview 的周列头可见区域；离屏缓存不证明真人或系统材质验收。

周消费者实际覆盖重选两次回调、拒绝更新、外部跨周/闰日更新、禁用、两个宿主隔离、跨月跨年与闰周、周日/周一起始输入及刻意逆序、原标识/完整日期/选中语义。真实列表点击保留目标 UUID 与所属列日期，生产 CalendarPage 的前后周、选日、Return 检查目标和检查日、Escape 返回网格、编辑输入与未提交草稿通过；新测试的合成快照无额外保存。原 CalendarSpanConsumerTests 两项旧失败断言未改、未强制焦点绕过。

共享回归实际命中 DaybookDateCellTests、DaybookDatePickerTests、DaybookHabitDateCellTests、CalendarMonthGridTests/LayoutTests、CalendarMonthPageTests、CalendarMonthNavigationTests、HabitMonthLayoutTests/InteractionTests、DayScheduleButtonConsumerTests、DateScheduleLifecycleTests、DateScheduleCalendarIsolationTests 和 ControlsPreview 原 galleryRenders。覆盖 picker 选日/键盘、月份与今天辅助语义，monthGrid 尺寸/计数/重选/外部更新/投放呈现，habit 两位日号/五态/原命中/检查日及真实检查器，排期暂存/关闭/失败边界；日期 picker 今天下划线仍见原展示。未机械重跑无关时间或设置套件。

**拖放分层**：静态差异确认列级 dropDestination、TodoDragToken 解码、回调参数及整列接收范围不变；TodoDragTokenTests 两项通过。周 onDropTodo 的直接程序化派发未运行，不用该方式替代原生拖放；月格 isDropTarget 注入呈现已随公共日格矩阵回归，但周列系统投放高亮和真实拖动均未验。此次 quiet 承载和实测命中未变，条件未变时没有重复此前失败的真实拖放尝试。

**最终检查**：严格局部 SwiftLint、差异/未跟踪文件静态检查、`python3 -B scripts/check_workflow.py`、76 项检查器定向测试及 `python3 -B scripts/quality_gate.py --profile static` 通过，静态 profile 包含 196 项脚本回归。`./scripts/build.sh` 仅构建 Debug 并静态验签成功，未启动/安装；沿既有开发签名配置，无签名配置修改。完整测试编译仍有无关历史弃用警告。自动/swift profile 未启用，以免另起普通宿主。

**整体 partial**：指定 Cursor verifier 缺失，未认证或替换复核机制。周布局越界/标题挤压/切周焦点、D 的 Tab 激活、真实拖放、人工 VoiceOver、输入法/撤销、低版本系统及其他历史缺口继续登记。第六阶段接入范围已列于组件目录，不代表全面验收；建议后续单独界定历史周问题及补证任务。到 E 停止，不提交、推送、安装、发布或修改真实数据、系统偏好、签名配置及权限。

统一搜索 2J-2A 的纯排序已实现并完成本地定向验证：72 套 Swift 回归 504 passed / 0 failed / 0 skipped（其中 27 项新增排序测试），Debug 构建/验签、严格局部 lint、工作流与静态门禁通过，静态含当前 179 项原脚本回归。Domain 与其测试在最终回归前后摘要一致；证据位于忽略目录 build/ContentQuerySortQA。唯一规则、接口和完整交接见[权威设计第 9.29 节](unified-search-commands.md#929-阶段-2j-2a安全聚合结果的相关性与最近排序)。指定 Cursor verifier 未执行，整体 partial，历史验收缺口保留；未接片段/UI/分页/缓存/真实读取，未提交、推送、安装或启动生产应用，停在 2J-2A。

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

### 原应用缺失的同身份重装（2026-10-08）

用户报告安装目录缺失、私密锁配置仍存在时被安装脚本拦截，并同意先核验原包、沿同身份重装和完善脚本。新增显式原包身份来源，复用候选验签、安装锁、暂存替换和失败回退；不自动选择历史包、不清理数据或改变签名。参数和历史归属限制集中在[签名文档](signing.md#原应用缺失时重装)，入口及测试索引见[组件目录](component-catalog.md#安装身份恢复入口)。

- 自动证据：`python3 -B scripts/quality_gate.py --profile static --strict` 通过，含 **258 项隔离脚本测试**；`python3 -B scripts/check_workflow.py`、直接受影响 Shell 入口的 `bash -n`、Python 解析和差异空白检查通过。本次只改安装脚本与文档，因此显式选择 static，未将并发 Swift 改动带入全量应用测试。
- 新增回归覆盖显式同身份重装、各身份字段不一致、无参数仍阻止遗留锁重装、损坏或非受管原包、路径／权限／符号链接、备份改变／替换／消失、现用应用重新出现、取消、安装锁、失败恢复缺失状态及含空格的参数透传。外部命令均模拟，应用和用户资料使用临时合成目录。
- 本机操作证据：5 份常规安装备份完整性通过且与当前开发候选身份一致；另有一份更早的非标准备份损坏，未使用。显式选择最近的有效原包后，只读预检通过；经当前用户授权以 `--no-build --no-open` 安装已有 Debug 成功。安装后状态为 installed=true、running=false，完整验签通过，代码哈希与候选一致，原备份仍存在。没有启动应用、操作真实钥匙串或清理数据；应用本体恢复不等于数据恢复或系统解锁验收。
- **指定复核未执行，整体交付保留 partial。** 当前未发现可调用 Cursor verifier 工具；本机 Cursor CLI 的一次状态查询报告未登录，未执行登录或换其他代理代行。待复核材料为原始请求、本节范围、[实际脚本](../scripts/app_manager.py)、[新增反例](../scripts/tests/test_app_recovery.py)、[参数透传](../scripts/tests/test_app_commands.py)及上述自动／安装证据；重点核验原包来源、历史归属假设、候选与旧包验证差异、替换前复查和失败恢复，不预设证明方案正确。冷启动、系统解锁和当前并发工作区的完整运行验收未运行。

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

[DaybookControlsPreview.swift](../AreaChain/Features/Settings/ControlsPreview/DaybookControlsPreview.swift) 仅在 Debug 测试 target 中，直接装配生产按钮。它没有正式导航或应用启动入口，避免 Canvas 经生产 App 初始化触及服务。窗口可切换中英文、浅深色、禁用、长标签、减弱动态效果；鼠标悬停/按下、Tab 焦点、Command 高亮及 ⌘Return 使用真实原生事件。Tab 遍历受 macOS 的键盘导航设置影响，测试不修改全局设置。所有动作只增加本地计数。

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

### 第四阶段 B：普通设置下拉选择器接入（2026-10-02）

本轮只接 GeneralSettingsSection 的三处 Picker，公共层最小增加 formRow 对齐能力，默认剪贴板布局保持；契约与复用见[组件目录](component-catalog.md#第四阶段-b普通设置下拉选择器接入)。AppPreferences、AppChrome、枚举/偏好键、语言解析、外观应用和截断规则未改。

迁移前 `build/PickerStageB-baseline2.xcresult` 命中 1 项/4 次，中英文 × 浅深色 420×560 grouped Form：标签靠左、当前值与双箭头靠右；菜单选项及选中勾正确，合成鼠标打开/Escape 取消零写入，Return 重选当前项保存原键并发一次通知，另外两项/登录回调不变。已查看双语主题截图，保存在 `build/PickerStageB-before`。首包 baseline 因原生 Form Picker 的辅助字段名不能被旧菜单名称查找命中而失败；改用原辅助标识获取基线。迁移后仍严格按目标语言字段名定位，不以英文兜底。

运行沿架构文档 PrivacyQA XCTest、build/.build.lock、QA 标识、临时签名、生产 sandbox entitlement、LSUIElement=NO、串行及六项真实钥匙串变量清除。正常目标不排除源码，没有直接启动 QA 包或日用应用。测试直接挂载生产分节，随机 suite/内存模型、无副作用登录回调，不挂载 SettingsView；AppDelegate 在 XCTest 跳过服务启动，CalendarSync.start/refreshIfEnabled 另有测试守卫，其他偏好订阅者只在相应宿主/服务创建时登记。动态宿主显式注入测试偏好并消费原 AppChrome，读实际环境探针与 NSApp/window 外观；结束恢复 XCTest 进程外观。

接入初轮在 grouped Form 暴露辅助框覆盖整行、真实原生按钮只位于右侧的问题（hit 包记录辅助宽 360pt、原生语言按钮宽 70pt），合成鼠标落在空白而未进入菜单追踪。formRow 增加独立辅助容器后保持子菜单边界，默认 inline 不变；最终几何断言允许公共水平内边距，但要求原生入口被包含、辅助框中心实际命中原生入口、28pt 高度和右边缘对齐。没有靠更换成 action 派发绕过鼠标追踪。首个 consumers 包因合成 TodoItem 缺 dayKey 参数未编译，已在测试夹具修正。

**既有外观传播缺口**：`build/PickerStageB-original-appearance2.xcresult` 实际命中原生产三处 Picker 的外观测试 1 项，失败点唯一为 dark→system 后 SwiftUI 环境未返回初始浅色。临时只还原本阶段三处生产接入，测试定位使用原辅助标识；结束自动恢复新组件和严格目标语言定位。初始环境、light/dark、当前值/选中勾、存储/单次通知、NSApp.appearance 路径和窗口有效外观均检查；system 已写入原键、resolvedColorScheme 为 nil、NSApp.appearance 清空，窗口为 aqua，但原 AppChrome 的视图环境等待一秒后仍 dark。NSHostingView 与生产同类 NSHostingController 均复现。新组件保留同一现象，测试仅在该已复现条件对返回浅色的环境断言使用 withKnownIssue；不计为 system 动态传播通过，不修改 AppChrome，不将当前系统状态外推为系统设置实时联动已验。

补验 geometry-system、original-appearance 首包和第一次正常 Debug 构建被并发 ContentQueryBatch 的未完成类型/参数阻断，未排除源码或修补其他任务；待其所属改动完成后重新运行。早期 consumers4 的辅助框等于原生框断言误忽略了公共水平内边距，最终改为包含/中心命中检查，仍能拒绝上述整行辅助框。所有失败包保留为过程证据，不并入最终通过数。

**最终有效证据**：`build/PickerStageB-final.xcresult` 实际命中上述九套、39 项；其中 groupedFormSelectionAndCancellation 的辅助树/几何断言由最终 `build/PickerStageB-final-geometry.xcresult`（1 项/4 次通过）替换。去重有效结果为 **38 项通过、1 项已知外观问题，0 跳过**；参数化共 **95 次通过、1 次已知问题**。final 首包自身仍含已被补验替换的失败，不单独宣称全绿。辅助标识须沿 NSObject 动态辅助树读取，原 SystemPageHost.identifiers 的协议转换在此宿主返回空集；最终按实际节点严格检查三个原标识，未用文案或测试 marker 代替。公共菜单内边距存在原生光学偏移，中心无需完全重合，但辅助框中心必须位于原生按钮范围；原 360pt 整行框仍会失败。

实际覆盖 SettingsPickerConsumerTests、AppPreferencesTests、DaybookPickerTests、ClipboardPickerConsumerTests、ClipboardOptionsConsumerTests、ClipboardStepperConsumerTests、SettingsToggleConsumerTests、SettingsSectionPresentationTests、SettingsButtonConsumerTests。语言经真实菜单项动作英文→中文，再以合成 ↓/Return 中文→英文；严格使用新语言定位，字段名、当前值、重新展开的全部选项和相邻说明随 AppChrome 更新。system 语言保存原值并核对当前解析结果，不改系统语言。外观 light/dark 的实际环境和原进程路径通过；system 的存储/nil 语义通过，环境残留按上文保留。截断 tail/middle、同 suite 新偏好对象、关闭重开、原映射及合成模型标题原文/无脏写均检查。打开/取消零写入、重选一次通知、三项单键写入、禁用、外部更新、无登录/捕获/日历串改以及 A 阶段公共/剪贴板回归通过。

已查看 420×560 双语/浅深色、动态中文、长说明及滚动后的窗口位图；截图位于 QA sandbox 的 AreaChainButtonConsumersQA，原布局四图保存在 build/PickerStageB-before。位图不证明菜单系统材质，合成 NSEvent 鼠标/键盘追踪、程序化菜单项/辅助动作与真人操作分别报告，本轮没有真人菜单或 VoiceOver 操作证据。

最终六个 Swift 文件严格 SwiftLint、14 个原文案键双语解析、git diff --check、check_workflow.py、58 项检查器定向测试、178 项完整脚本回归及 quality_gate.py --profile static 通过。`./scripts/build.sh` 正常配置 Debug 构建/静态验签通过，日志 build/PickerStageB-debug-final.log；后续只修测试取证与文档，未再改生产源码。正常目标保留既有 actor/AppKit 弃用及运行警告，不排除源码；按限定隔离边界以静态门禁、严格局部 lint 和上述定向 QA XCTest 替代会启动无关/非 QA 宿主的 auto/swift 全量入口。

**交付状态为部分完成**：指定 Cursor verifier 当前工具清单无可调用入口，未执行或替代；system 环境残留未修复，未验系统外观设置实时联动、真人菜单/VoiceOver、系统全键盘导航、最低支持系统与系统菜单材质。H 的保存回滚后显示未自动刷新、标签合成鼠标点击问题、Stepper 1/11 长按差异及其他历史缺口继续登记，不计通过。保留并发查询源码/文档；没有提交、推送、安装、发布，未改系统偏好、个人签名、权限或真实用户数据。到第四阶段 B 停止；后续仅登记 TagManagementPage.mergeSheet 的合并目标、PrivacySettingsSection 自动锁定、CalendarPage 的 calendar.span 与 DaybookSegmentedBar 分段入口，均未迁移。

### 第四阶段 C：标签合并目标选择器接入（2026-10-02）

本轮只扩展公共选项的 verbatim 原文入口并接入 TagManagementPage.mergeSheet；接口、UUID 身份、原 Binding 与后续边界见[组件目录](component-catalog.md#第四阶段-c标签合并目标选择器接入)。DaybookControlsPreview 沿原展示加入原文选项，无新展示应用。本地化初始化及 A/B 的 inline/formRow 兼容；未改普通合并规则、仓储、权限或其他生产页面。

隔离沿已确认的 PrivacyQA XCTest、build/.build.lock、QA 标识、本地临时签名、生产 entitlement、LSUIElement=NO 与串行选项，清除全部六项真实钥匙串变量。正常应用/测试目标不排除源码；只由 XCTest 启动宿主，不直接打开 QA 或日用 App。SettingsButtonTestSupport 提供内存 ModelContainer/随机偏好 suite。合成提交确认 catalogRepositoryProvider 为 nil，原 mergeTags 走该 context 的 SwiftDataCatalogRepository / Catalog / ModelChanges；BoardEvents 在 XCTest 跳过通知排程及日历刷新。数据均为本例普通标签、事项、子任务、重复事项与普通手记，没有真实库、凭据或系统设置操作。

首包 `build/PickerStageC-contracts.xcresult` 命中 16 项/30 次，13 项通过、3 项失败（23 次通过、7 次失败），零跳过。原文/UUID 和合成提交通过；旧合并呈现断言重复把公共 Picker 的辅助名称节点作为相邻文本，导致同一几何自交。最终字段名改由精确本地化菜单定位校验，标题/说明及菜单/按钮边界仍检查，未弱化实际相邻节点防重叠。另有一次旧公共中文用例在开菜单前失焦，原焦点断言保留；首包不并入最终通过证据。

**最终有效证据**：macOS 26.6.2 arm64 / Xcode 26.6 / Swift 6.3.3。`build/PickerStageC-acceptance.xcresult` 经 xcresulttool summary/tests 核对九套共 **43 项：42 项通过、1 项已知问题；参数化 89 次通过、1 次已知问题，0 失败、0 跳过**。覆盖 DaybookPickerTests、WorkspaceMenuConsumerTests、TagCatalogTests、TagRepositoryTests、SettingsPickerConsumerTests、AppPreferencesTests、ClipboardPickerConsumerTests、ClipboardOptionsConsumerTests、ClipboardStepperConsumerTests。已知问题唯一为 B 的 appearanceUsesProcessAndHostEnvironment，dark→system 不计为通过；首包失焦用例本次保留原断言通过。

原文测试直接挂载生产组件，逐字/UTF-8 核对 common.save、中英文、符号、组合字符、长名及同名不同 UUID；改名、重排、外部选择、动态语言、空/缺失值和旧菜单不回写。合并消费者中英文×浅深色的 360pt sheet 验证初始顺序/目标、另一项的显示与勾、打开/Escape 零模型改变、取消实际关闭、重开恢复 beginMerge 初值；在打开的 sheet 中换语言保持原文与所选项，重开也按新语言显示界面文案。一次普通内存合成提交从两个同名 UUID 中选择第二项，经原按钮/业务路径确认第二 UUID 保留、来源软删，事项原关联去重且无关标签保留，子任务/重复事项/普通手记均转入所选目标，预置及未选择标签保持。原合并会对传入四表编码归一化，沿原 TagCatalog 回归，不改算法。

A/B 回归保留本地化选项、默认 inline / formRow 布局、原偏好持久化、拒绝写入回读、禁用/拆卸、动态语言与重开。最终五个 Swift 文件严格 SwiftLint、git diff --check、check_workflow.py、59 项检查器测试、179 项完整脚本回归和 quality_gate.py --profile static 通过。`./scripts/build.sh` 正常目标 Debug 编译/静态验签通过（build/PickerStageC-debug.log），未安装或启动产物；既有 actor/AppKit 弃用警告保留。按用户限定以静态门禁＋严格局部 lint＋上述隔离定向 XCTest 代替会启动非 QA/无关宿主的 auto/swift 全量入口。

**证据层级**：NSEvent 合成鼠标打开、↓/Return 选择、Escape 关闭及取消/合并按钮点击实际进入系统追踪/生产动作；NSMenu.performAction 与 AXPress 是单列的程序化派发，不宣称真人菜单操作。已查看最终双语/主题 360pt sheet、公共长原文及原 ControlsPreview 位图；透明背景的窗口缓存只证明内容排版，不证明系统菜单材质。完整原文的菜单/辅助值严格断言通过，窄窗当前值允许原生尾截断。真人菜单、VoiceOver、系统全键盘导航、最低支持系统与系统材质仍未验。

指定 Cursor verifier 当前会话无可调用入口，未执行或替代，交付保留部分完成。B 的 dark→system 环境残留、H 的保存回滚后显示未自动刷新/标签合成鼠标点击两项、Stepper 1/11 长按差异及其他历史缺口继续保留。完成后停在 C；自动锁定与分段切换未迁移，没有提交、推送、安装或发布。

### 第四阶段 D：自动锁定时长选择器接入（2026-10-02）

生产仅替换 PrivacySettingsSection 的 privacy.autolock Picker，复用既有 DaybookPicker.formRow；秒数、选项和状态归属见[组件目录](component-catalog.md#第四阶段-d自动锁定时长选择器接入)。差异核对确认该文件其余内容逐字未变，原 Binding 完整保留，包括 run、force: true、传入 vault、busy 和错误处理；没有新增公共 API、认证绕过、配置/保存改动或并发修改覆盖。本轮是局部接入且没有改变公共契约、持久化或权限边界，主代理自查，不新增指定复核要求；前期公共控件的 Cursor verifier 缺口仍保留，不宣称复核通过。

**基线与隔离**：正常应用/测试目标包含全部源码，沿 build/.build.lock 和架构 PrivacyQA 命令串行测试；独立 QA Bundle ID、隔离 DerivedData、本地临时签名、生产 sandbox entitlement、LSUIElement=NO，并清除六项真实钥匙串环境变量。仅经 XCTest 启动宿主，App 初始化走内存数据库，AppDelegate 跳过服务启动；没有直接打开 QA 或日用 App。PrivacyFixture 提供内存模型和合成配置，显式核对 MemoryVaultConfigurationStore / FakeSystemVaultKeys 类型及模型配置；独立 suite 偏好传给生产隐私页。原 Presenter 将指定 vault 交给 PrivacyUnlockView，按钮只调用该 vault 的 fake key storage；面板 locale 沿原 shared 偏好只读解析，没有修改共享或系统偏好。无设置探测、文件面板、备份提交、迁移或保护操作。只关闭本例创建且属于该 Presenter 的面板，再释放 fake pendingRead，使取消后的迟到结果结束；测试失败也执行清理。

`build/PickerStageD-native-confirmed.xcresult` 经 summary/tests 确认原 Picker **2 项、6 次通过，0 失败/跳过**：记录双语/主题 420×560 布局、初始 300 秒、三个菜单选项、打开/Escape 零提交、不同项与当前项重新认证、等待零保存和成功回读。基线截图保存在 build/PickerStageD-before，已查看实际画面。首个 baseline 包是测试宏编译错误，baseline-run 是旧原生 Picker 辅助名称定位不匹配，native 包是测试用 NSObject.perform 读取 Bool 的方式错误；最终基线改用原辅助标识与 KVC 读取布尔值，未改生产 Picker 或禁用断言。接入后的定位恢复严格本地化名称，并独立验证原辅助标识与 systemPageMarker。

**最终有效证据**：macOS 26.6.2（25G83）arm64 / Xcode 26.6 / Swift 6.3.3。`build/PickerStageD-acceptance.xcresult` 的 summary/tests 树确认 PrivacyAutolockPickerTests、PrivacyButtonConsumerTests、DaybookPickerTests（含原文扩展）、ClipboardPickerConsumerTests 共 **25 项、65 次通过，0 失败、0 跳过**。D 消费者自身 7 项、15 次通过。已解锁与重选均打开原重新认证面板；fake 受控等待期间配置和当前值保持 300，busy 禁用整组，重复 target/action、禁用入口鼠标与认证按钮重复点击不产生第二次认证代次。成功提交 60/900 秒及重选 300 秒，显示、菜单勾选和新 vault 回读一致。取消面板与等待中取消均保留旧配置、显示 cancelled 并锁定；释放迟到 fake 结果不保存。fake 认证失败仍留原面板、页面保持 busy 和旧值，原错误可见，重试成功；配置保存失败则关闭已成功认证的面板、vault 保持解锁、页面显示 storageFailure，旧值不变且可以重试。外部三档值自然回显，JSON 编解码/validate/新 vault 回读通过，1/5/15 作为秒数被原配置校验拒绝。没有把分钟文字当保存值。

**强制派发的限制**：consumer 和 wait-diagnostic 包记录，在 disabled 后直接调用 NSMenu.performActionForItem，会由 AppKit 先强制选中菜单项，再到已拒绝提交的公共回调；因此辅助值可暂变为 15 minutes，而 Binding/配置仍是 300。新增的派发前断言通过，失败只发生在上述强制预选之后；此证据不证明用户能操作禁用菜单。最终防重入改为原 target/action 派发，另加真实入口的合成鼠标点击，等待实际值断言保持严格，认证结果返回后按原 Binding 回读。该强制派发现象未修复、不计入显示一致性通过，不改超出范围的公共控件。

双语×浅深色的生产 420×560、原分组/相邻说明、长字段 formRow 与滚动到底后返回菜单均通过；辅助框须包含真实 NSPopUpButton、中心落在其范围且高度为公共 28pt，未用整行框冒充入口。已查看生产双语/主题、长字段和滚动边界位图，最终截图位于 QA sandbox 的 AreaChainButtonConsumersQA。长字段样例仅证明公共布局；本轮认证链没有使用通用异步 Binding 替身。NSEvent 合成鼠标、↓/Return、Escape 实际进入原生追踪和生产回调；NSMenu、target/action、AXPress 程序化派发单列，未执行真人鼠标/键盘、VoiceOver、真实系统认证或最低支持系统验收。自动锁定消费者的主密码方式未新增端到端交互，原 PrivacyButtonConsumerTests 密码/fake 系统方式回归通过，不冒充真实凭据认证。

最终三份 Swift 严格 SwiftLint、原四个文案键的双语解析、单处差异/Binding 等价检查、git diff --check、check_workflow.py 及 quality_gate.py --profile static（含 **179 项**原脚本测试）通过。按本轮仅隔离宿主的边界，以静态门禁、严格局部 lint 和上述定向 QA 替代会启动非 QA/无关宿主的 auto/swift 全量入口。`./scripts/build.sh` 正常配置 Debug 编译/静态验签通过，日志 build/PickerStageD-debug.log；未修改个人签名或启动产物。既有 actor/AppKit 弃用和运行警告不计为消除。

本轮接入与上述隔离验证已完成；人工/真实系统层及强制派发现象仍有明确缺口。B 的主题回退、H 的回滚后刷新与标签合成鼠标两项、Stepper 1/11 长按差异、既有公共复核及其他历史缺口继续登记，未扩修。生产普通原生下拉 Picker 静态核对未发现遗漏；CalendarPage.calendar.span 的原生分段和 MenuBarPopoverView+Header 的 DaybookSegmentedBar 留作后续独立任务。停在 D，不提交、推送、安装、发布，不操作真实数据或系统偏好/权限。

## 控件收口第四阶段 E：通用分段与菜单栏

**已实现，整体部分完成**：新增 Theme 的 DaybookSegmentedControl / DaybookSegmentOption，强类型 Binding、稳定值与本地化标题/help 分离；DaybookSegmentedBar 原调用兼容，仅适配 BoardTab，不重复绘制。集中 DaybookMetrics.Segmented 与 DaybookMotion.segmented；普通模式保留原 0.28/0.75 弹簧，减弱时关闭继承动画事务。菜单栏 Header 原 `$tab` 和计数参数无需修改，计数仍不展示。公共层没有快捷键、业务会话、保存或动画结束派发。接口、空/缺失策略、长标题与下一阶段边界见[组件目录](component-catalog.md#第四阶段-e通用分段与菜单栏)。

**最终证据**：macOS 26.6.2（25G83）arm64，沿架构的 PrivacyQA 命令、build/.build.lock、独立 QA 标识、临时签名、生产 sandbox entitlement、LSUIElement=NO 与串行 XCTest；清除全部六项真实钥匙串授权变量。正常目标包含全部源码，只由 XCTest 启动宿主，无真实状态栏控制器或服务启动。复用 SettingsButtonTestSupport / SystemPageHost、MenuBarPopoverRenderingTests 辅助方法和原 ControlsPreview；内存模型、随机偏好 suite、合成正文、显式草稿/筛选与 fake vault。手记页面保留原先的预置标签确保逻辑，夹具预先建立预置标签后严格比较身份集合。

`build/SegmentE-acceptance.xcresult` 经 xcresulttool summary/tests 核实 **17 项、27 次运行全部通过，0 失败/跳过**。实际命中 DaybookSegmentedControlTests（4 项）、DaybookSegmentedMotionTests（1 项双参数）、MenuBarPopoverRenderingTests/segmentedConsumerPreservesDraftsFiltersSearchAndCounts(locale:scheme:)（双语×主题）、MenuBarToolbarStateTests（9 项）、MenuBarSearchShortcutTests（1 项）、原 galleryRenders(locale:dark:)（双语×主题）。公共测试覆盖自定义枚举与 Int、同名选项、重排/语言变化零写入、外部值、拒绝更新、重选一次、禁用鼠标/辅助动作、空数组/缺失值、独立实例、快速切换/重建/拆卸、辅助名称/help/选中和 200pt 长标题。菜单栏覆盖鼠标与 AXPress、宿主 Command-Left/Right、两类草稿/筛选、搜索优先与 Command-Return 不提交、返回事项焦点、浮层关闭、拆卸监视器和零额外事项/手记/标签；380pt 页头有边界断言。

**原版对照与失败归属**：曾临时用 HEAD 的原 DaybookSegmentedBar 在同一隔离命令下运行相同消费者测试，finally 恢复本轮适配器，不改变业务源码。原版与重构均发现测试按同名“手记”按钮误点捕获提交；改为专属 help 唯一定位，不唯一立即失败。随后识别旧 DiaryPage 首次挂载会补齐预置标签，夹具预置后比较标签身份，未修改产品行为。原版最终 `build/SegmentE-baseline-acceptance.xcresult` **1 项、4 次通过**。初轮公共双语预期把动态键当插值资源、一次夹具缺 sortOrder 的编译错误均已修正并重跑。并发 ContentQueryDisplay 初始化编译错误曾阻断测试，原工作修正后正常目标重跑；本阶段未修改或排除查询源码。所有失败包仅作为诊断，不计通过。

**证据边界**：鼠标/键盘为 XCTest 内合成 NSEvent；辅助操作为 accessibilityPerformPress，均非真人。动效测试临时拦截本测试进程 NSWorkspace 减弱效果读取，真实观察 SwiftUI 环境 false/true，保留动画事务与真实等待，随后恢复原实现并发送刷新通知；没有修改系统偏好，也不证明真人系统设置实时切换或逐帧滑块运动轨迹。按钮专用预览开关未被当作分段联动证据。已查看 QA sandbox 的 AreaChainButtonConsumersQA/settings-segment-* 原生缓存位图：双语/主题菜单栏、搜索态与长标题；日期/状态/分段无重叠，长标题截断但完整辅助名/help 保留。缓存位图不证明最终系统材质；原 ControlsPreview 展示运行通过，未新建应用。

严格局部 SwiftLint、工作流检查、检查器定向 **60 项**、全脚本 **180 项**、quality_gate.py --profile static 和 git diff --check 通过；`./scripts/build.sh` 正常 Debug 构建/静态验签通过（build/SegmentE-debug.log）。按用户限定以静态门禁、严格局部 lint、上述正常完整目标的定向隔离 XCTest 代替会启动非 QA/无关宿主的 auto/swift 全量入口。保留既有 actor/AppKit 弃用警告。

指定 Cursor verifier 当前无可调用工具，未替代或宣称复核通过。真人 VoiceOver/全键盘导航、真实系统减弱效果切换、最低支持系统和最终材质仍未验；B 的主题回退、H 的保存回滚后刷新与标签合成鼠标两项、Stepper 长按 1/11 差异、强制派发禁用菜单的显示现象及其他历史缺口继续登记。CalendarPage 的月/周选择器未迁移；后续可用 Binding<CalendarSpan> 接通用核心，仍需单独核对宿主导航、焦点及布局。到 E 停止，不提交、推送、安装、发布或操作真实数据、系统偏好、签名配置及权限。

E 的展示补验：随后只调整测试取证，给紧凑长标题宿主补 Daybook 底色，并在原 galleryRenders 滚动前核对分段标题、截图独立实例。静态 Text 使用 accessibilityValue 而不是 accessibilityLabel；首轮取错字段的失败不计通过。最终 `build/SegmentE-gallery-delivery.xcresult` 经 summary/tests 核实 **5 项、11 次通过，0 失败/跳过**，覆盖最终公共组件测试和原展示四种语言/主题组合；已查看双语浅深色分段展示及有底色的紧凑长标题。生产源码未再变化，前述菜单栏、动效、构建证据继续有效。最终相关 Swift 严格 lint、工作流/静态门禁与差异检查重跑通过。

### 第四阶段 F：日历月/周分段接入（2026-10-02）

生产修改仅 CalendarPage：spanPicker 直接消费公共 DaybookSegmentedControl / DaybookSegmentOption；CalendarSpan.titleKey 改为唯一字符串资源键，分别显式适配公共选项和原顶栏菜单。保留默认 month、稳定 month/week、原 Binding、220pt 上限、非 embedded 条件、onChange 及菜单动作。分段增加明确的本地化辅助组名；未改公共核心、菜单栏适配、日历日期格、日期/投影、拖放、保存或键盘系统。接口、复用及第四阶段定向清单统一见[组件目录](component-catalog.md#第四阶段-f日历月周分段接入)。

隔离沿原 PrivacyQA XCTest、build/.build.lock、独立 QA 标识、临时签名、生产 sandbox entitlement、LSUIElement=NO、串行与六项真实钥匙串变量清除；正常目标不排除源码，只经 XCTest 启动宿主。CalendarSpanTestSupport 直接挂载生产 CalendarPage / WorkspaceHeaderBar，使用内存模型、随机偏好 suite 和合成事项/标签；保存并恢复 BoardSelection 的日期/手记/取消标志，以及受影响的 WorkspaceNavigation 路由、搜索、列表会话、选择、检查器和投影。原 CalendarMonthNavigationTests 同步复用恢复入口。展示仍沿 E 的 ControlsPreview，无新应用或检查执行器。

**原生对照**：修改前先运行原生产 Picker；后用锁内临时恢复原 CalendarPage、finally 校验并还原本轮文件的方式补齐相同测试。`build/CalendarF-native-verified.xcresult` 为最终原生对照，实际命中 8 项、16 次运行：11 次通过、5 次已知问题，0 非预期失败/跳过。原生选项为 AXRadioButton、选中值来自 accessibilityValue，calendar.span 节点本身无辅助名称，组名由相邻可见标签呈现；公共版本为带选中状态的 Button 和显式命名的辅助组。两版点击分段后的实际 firstResponder 均为 NSWindow，左右键由原窗口日历处理，未凭控件类型推断按键归属。原生 mouseDown 同步追踪要求先投递释放事件；初版测试顺序卡住后用进程采样确认，只结束本轮测试进程。初期定位、标签字段类型、菜单隐藏占位与组名读取错误均为夹具问题，诊断结果不计通过。

**两项旧日历问题保留**：从列表进入周视图后，原 spanPicker 分支中的 onChange 未能恢复 grid，firstResponder 已为 NSWindow 但方向键未换日；Escape 返回网格后原路径继续可用。420pt 周布局的七列及右导航超出窗口，长标签会进一步放大；月布局和分段本身仍可操作。两项在原生和公共版本同场景复现，分别归属原 CalendarPage 状态回调生命周期及 CalendarWeekBoard/周布局最小宽度，不在 F 重写。测试以 withKnownIssue 保留失败断言，每次仍执行；不能把结果包 Passed 或已知问题数算作这些要求验收通过。 后续焦点修复及严格首次按键证据见[第十阶段 F](#第十阶段-f日历月周切换后的键盘焦点恢复)；本段保留第四阶段失败事实，窄周问题未关闭。

日历测试覆盖月→周→月、当前日期、原月/周导航、未提交草稿零创建、合成事项完整快照不变、窗口网格与列表/返回路径、输入光标方向键与显式 Return 只提交一次、非嵌入宽/窄分段、嵌入直接/收纳菜单、顶栏值/文案/实际检查器投影，以及中英文×浅深色、September 长月份标题与三组跨月周。可见入口结合原生祖先隐藏状态、辅助父链、窗口边界和唯一匹配定位，不改 ViewThatFits 来回避测试。

**最终证据**：macOS 26.6.2（25G83）arm64，`build/CalendarF-final.xcresult` 经 xcresulttool summary/tests 核实 **42 项、60 次运行：55 次通过、5 次已知问题，0 非预期失败/跳过**。命中 CalendarSpanConsumerTests、CalendarMonthNavigationTests、DaybookSegmentedControlTests / MotionTests、MenuBarPopoverRenderingTests 的 segmentedConsumerPreservesDraftsFiltersSearchAndCounts、MenuBarToolbarStateTests、MenuBarSearchShortcutTests、原 galleryRenders、WorkspaceHeaderStateTests、WorkspaceBoardGapsTests 与 DayKeyTests。菜单栏双草稿、筛选/搜索、Command-Left/Right、Command-Return 搜索优先、返回输入焦点、零额外记录和默认 380pt 布局回归通过；公共默认 API 未改。

原 CalendarMonthNavigationTests 的月份条定位同时排除隐藏祖先与空可见区域；最终该项以 `build/CalendarF-navigation.xcresult` 单独重跑，实际命中 **1 项、2 次通过，0 失败/跳过**。这是测试定位补强，生产源码及其余回归对象未再修改；相关严格 lint 和工作流/差异检查重跑通过。

已查看最终 QA 原生缓存位图的双语浅深色宽/窄月周组合，分段选中/未选中可辨且不与月份标题重叠；窄周越界按上述缺口保留。原生和公共的 1000pt 周图均出现带标签事项标题被挤压的现象，属于原周列内容布局，未扩修；缓存位图仍不代表最终系统材质。原始对照位图保存在 build/CalendarF-native-layout，最终位图在 build/CalendarF-shared-layout。四个本轮 Swift 文件严格 SwiftLint、git diff --check、check_workflow.py 与 quality_gate.py --profile static 通过，后者包含 **181 项**脚本回归；原检查器接口/规则不变。按本次隔离启动边界，以静态门禁＋严格局部 lint＋完整正常目标的定向 QA XCTest 替代会启动非 QA/无关宿主的 auto/swift 全量测试。`./scripts/build.sh` 正常 Debug 构建与静态验签通过（build/CalendarF-debug.log），保留现有 development 配置及既有 actor/AppKit 弃用警告；没有安装或启动该产物。

真人 VoiceOver、系统全键盘导航/输入法组合、最低支持 macOS 与最终系统材质仍未验。指定 Cursor verifier 当前无可调用工具，未替代或标为通过；本轮没有扩展公共核心契约，主代理核对同文件文案适配及行为差异，前期公共复核缺口继续保留。B 的主题回退、H 的回滚后刷新与标签合成鼠标两项、Stepper 长按 1/11 差异、强制派发禁用菜单现象及其他历史未验项均未扩修。第四阶段已识别的八个下拉、菜单栏分段、日历分段及其顶栏适配静态收齐；原生 Menu、公共 NSPopUpButton 承载和测试原生对照不算遗漏。到 F 停止，不提交、推送、安装、发布或修改真实数据、系统偏好、签名配置及权限。

### 第五阶段 A：公共时间选择器（2026-10-02）

生产仅增加 Theme 的 DaybookTimePicker / DaybookNativeTimePicker / DaybookTimePresentation，两个首批消费者保留分钟动作链与原默认设置、清除和即时提交；接口、nil/坏值呈现及后续边界见[组件目录](component-catalog.md#第五阶段-a公共时间选择器与首批消费者)。展示扩展原 DaybookControlsPreview，未增加验收应用或生产导航。独立复核仍指定 Cursor verifier；当前会话工具清单没有该能力，未替代，整体部分完成。

**原生基线**：macOS 26.6.2（25G83）arm64，Xcode 26.6；沿 build/.build.lock 与架构 PrivacyQA XCTest、独立 QA 标识、隔离 DerivedData、本地临时签名、生产 sandbox entitlement、LSUIElement=NO，清除六项真实钥匙串变量。正常目标完整编译，没有排除源码，仅由 XCTest 启动宿主。测试入口明确断言 XCTest 环境，AppDelegate 跳过服务启动；BoardEvents 跳过通知/日历，NotificationScheduler.ensureAuthorization 在系统中心＋XCTest 时直接返回。使用 SettingsButtonTestSupport 的内存库与随机偏好 suite、合成任务/重复事项和既有 ModelChanges/仓储失败注入，没有真实权限或日历服务。

`TimePickerA-native-baseline.xcresult`（1 项、3 次）与 `TimePickerA-boundaries.xcresult`（2 项、4 次）确认原 NSDatePicker 为 textFieldAndStepper/hourMinute、continuous=false，隐藏可见标签仍有 Time/时刻辅助名。en 为 12 小时，zh-Hans 及当前 en_CN 为 24 小时；00:00/12:00/23:59 正确。nil、-1、1440 原先显示当前时间回退，零写入。只赋 dateValue 不调用 Binding，另行 target/action 才提交。合成鼠标进入字段，方向键切换字段/增减；719→720、1439→0及逆向均沿原生进位。小时 4 即时有效；接着 9 不形成合法 49。单数字分钟 4 先暂存，失焦时原生将合法单数字完成为 04 并提交；完整分钟49即时提交，Escape/Tab不撤销已提交值。未把程序化赋值当作文本输入。

**迁移对照**：`TimePickerA-original-consumers.xcresult` 使用两个消费者原始源码、其余相同正常目标及夹具，结束后恢复本轮源码；初始化、保存、清除、关闭和自动失败恢复共8次通过，中文辅助名4处断言失败。迁移首轮 `TimePickerA-consumers.xcresult` 同样复现这项旧缺口。只在本轮两个弹出层显式传 locale 后，`TimePickerA-lifecycle.xcresult` 的10项/23次全部通过、0失败/跳过；包含两个消费者保存失败自动回显720，没有依赖手动重建。任务行失败复用原外层事务 save 注入，重复事项由原仓储注入点在真实模型变更后失败，二者回读时序分别取证。

**证据边界**：NSEvent 是合成原生键鼠事件；dateValue＋target/action 只证明程序化适配及业务链。截图是原生宿主位图缓存，展示页有实际纸底；弹出层系统材质的透明缓存不能代表最终合成画面。没有真人键鼠、输入法组合、VoiceOver、物理长按或低版本 macOS 验收。历史日历列表切周焦点/窄周布局、主题回退、H两项、Stepper长按及其他未验项原样保留，不在本轮扩修。详情提醒、截止时间、DaySchedulePicker源码均不迁移；没有提交、推送、安装、发布、真实数据/系统偏好/签名配置/权限变更。

**最终闭环**：`build/TimePickerA-final.xcresult` 的 summary/tests 树确认以下12套全部实际命中：TimePickerNativeBaselineTests、DaybookTimePickerTests、DaybookTimePickerLifecycleTests、TimePickerConsumerTests、ReminderPlanningTests、TaskRowInteractionTests、RecurringToggleConsumerTests、ModelChangesTests、DaybookTokenTests、WorkspaceLayoutTests、DaybookButtonInteractionTests、DaybookPickerTests；共77项、115次运行，0失败/跳过。结果日志确认两消费者 automaticDisplay=720，未手动重建；原生鼠标上下箭头原版/公共版均提交780→720。覆盖1440个分钟的适配往返、空值/午夜/越界、格式切换、外部更新、拒绝、禁用中暂存、拆卸/窗口关闭、空值初始化失败、清除失败、相邻草稿与标题保存。普通时分基线与公共版的NSEvent输入独立于dateValue赋值取证，未称为真人操作。

补测 `TimePickerA-original-pending.xcresult` 复现两个原消费者 Escape 关闭时补交暂存分钟4的旧行为，标题则确认为弹出层取得焦点后沿失焦保存。仅靠viewWillMove不能提前拦住关闭补交，因此公共原生层监听所属NSPopover/NSWindow的willClose，先撤销动作资格，拆离及dismantle移除观察者和回调。`TimePickerA-popover-lifetime.xcresult` 及最终包确认关闭不补交，普通失焦仍将合法单数字分钟完成为04，有效已提交值不撤销。这是为满足本轮明确的关闭边界而修正的旧行为，不改变消费者事务或新增确认保存。中文辅助名旧缺口仅在本轮两入口显式传locale修正。

最终截图位于 QA 容器临时目录 `AreaChainButtonConsumersQA/settings-time-*`，已核对原生输入与展示的中英文/浅深色，展示直接包含有效值、未设置编辑起点和禁用午夜，长辅助名不挤压字段。原padding12/minWidth180保留，时分外壳统一为28pt；nil/无效状态另有说明行。原Picker展示测试补滚动定位外部更新按钮，保留其断言。首个基线包因测试辅助的可选Calendar编译错误、首个public包因新增文案未写入而失败，均已修正并重跑，失败包不作通过证据。

`./scripts/build.sh` 的Debug构建/静态验签成功（现有development配置，未修改签名配置，未启动该产物）；最终严格局部SwiftLint、check_workflow.py、quality_gate.py --profile static及184项scripts/tests通过。因用户只授权隔离XCTest宿主，没有运行会另起普通宿主的auto/swift全量profile。既有Xcode辅助API弃用及Swift6模式隔离提示仍是编译警告，不在本轮扩修。指定Cursor verifier缺失及前述真人/系统/历史缺口仍使整体验收为部分完成；本轮在第五阶段A停止。

### 第五阶段 B：详情提醒与截止时间（2026-10-02）

生产变更仅限 TaskDetailRemindChips 自定义时间弹出层/Binding 和 TaskDetailDueTime：分钟 Binding 直接接公共 DaybookTimePicker，显式 locale、padding 12 和原字段名称保留。未修改 Theme、领域、服务、日期、星期或日历布局。接口、四处时间入口及真实消费者见[组件目录](component-catalog.md#第五阶段-b详情提醒与截止时间接入)。详情空值打开不初始化，与阶段 A 两消费者的打开即初始化有意不同。

复用架构 PrivacyQA XCTest 命令、build/.build.lock、正常完整目标（不排除源码）、独立 QA 标识和 DerivedData、内存模型及随机偏好；仅由 XCTest 启动宿主。通知授权与 BoardEvents 的现有 XCTest 保护经源码核对，未改生产守卫，未启动通知/日历/权限流程。两详情提醒继续 setRemind，截止继续 setDue，新建表单只改草稿。失败使用原 ModelChanges/RecurringToggleRepository 注入；显示恢复在原宿主自然更新后断言，不重建视图。

首轮 `build/TimePickerB-first.xcresult` 实际执行 6 项/16 次，13 次通过、3 次失败、0 跳过。失败来自新增测试误将非可选 calendarEventID 的空字符串当作 nil；已改为与操作前值比较，另增加截止前后 ReminderPlanning.catalog 与 CalendarSyncStorage.local.load 的合成投影等价断言。该失败包不作全部通过证据。

本次为已有公共适配的局部接入，不新增公共接口、持久化语义或跨模块业务规则；主代理核对范围与调用链。阶段 A 公共关闭行为指定的 Cursor verifier 当前工具仍不可用，原必需复核缺口保留，不用其他代理冒充通过。程序化 dateValue/action、合成 NSEvent/文本输入、原生缓存截图与真人操作分别记录。没有真人键鼠、输入法、VoiceOver、物理长按或低版本 macOS 证据；历史日历焦点/周布局、主题回退、H 两项与 Stepper 长按保持未验，不扩修。

**清除失败的已知缺口**：`TimePickerB-final-detail.xcresult` 与补充尺寸矩阵的 `TimePickerB-final-matrix.xcresult` 均为 9 项/24 次，22 次通过、2 次失败。进一步 `TimePickerB-clear-diagnostic.xcresult` 确认失败发生在操作后：待办提醒/截止模型已恢复原值，但对应清除按钮消失，原宿主仍显示空值；并非同名按钮取错。`TimePickerB-original-clear.xcresult` 用迁移前两份生产源码、同一完整测试目标/夹具/失败注入，3 次中同样两处失败，重复事项通过；对照结束已恢复本轮代码。第十阶段 H 已把这两项收窄为“外层失败事务＋AX 同步提前渲染 nil 后，模型恢复但显示未自然恢复”；普通回调内提醒与重复事项对照通过，不能概括为普通生产清除失败不回显。普通截止真实 save 失败仍缺等价注入。仅在这个已证实的原版/迁移版场景使用 withKnownIssue 保留断言，不手动重建、不修改生产保存/刷新机制；不能将已知问题计为自动回显通过。时间弹出层有效赋值失败的回显测试仍为普通断言且通过，两者证据不可混用。

**静态收口**：Features 仅四处 DaybookTimePicker，hourMinute/textFieldAndStepper 仅在公共原生承载。仅日期的 DaySchedulePicker 及 TaskRow、TaskDetailDateChips、DiaryNoteCard、DiarySummaryRow 调用保留；星期和日历布局未改。布局矩阵覆盖真实详情分组的 280/400pt、中英文/浅深色及新建表单；320pt 首轮截图也保留。原快捷项在窄详情中省略、设时刻换行，原代码未变，不据此扩修布局。公共长辅助名和 12/24 小时显示沿原展示/原生基线回归。原生位图缓存中的透明系统材质不代表屏幕最终合成效果。

**最终验证**：`build/TimePickerB-final-verified.xcresult` 的 summary/tests 树确认 13 套全部实际命中：DetailTimePickerTests、DetailTimePickerLifecycleTests、RecurringEditorTimeTests、RecurringItemEditorTests、TimePickerNativeBaselineTests、DaybookTimePickerTests、DaybookTimePickerLifecycleTests、TimePickerConsumerTests、ReminderPlanningTests、ModelChangesTests、RecurringToggleConsumerTests、DaybookTokenTests、WorkspaceLayoutTests。共 66 项、107 次运行：105 次通过、2 次已知问题、0 非预期失败/跳过。不能用 summary 顶层 Passed 抹去设备层的两次 expectedFailures。覆盖 nil 打开关闭零回调、午夜、快捷项重选/原清除、独立截止及通知/日历投影、实际赋值失败回显、草稿失败重试/取消、时间字段 Return 不提前创建、合法单数字失焦、Escape 不补交、禁用/外部更新/重开/迟到 action，并回归阶段 A 两消费者。

截图位于 QA 容器临时目录 `AreaChainButtonConsumersQA/settings-detail-time-*`、`settings-recurring-time-form-*` 及原 `settings-time-gallery-*`，交互结束后核对缓存图；en 的 AM/PM、中文 24 小时、浅深色与长辅助名沿原展示验证。程序化 dateValue/action 与 AXPress 证明适配/业务链；完整分钟输入和 Return/Escape/失焦为合成原生键鼠，仍不等于真人证据。

最终严格局部 SwiftLint、`python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile static`（含 186 项脚本测试）及 `git diff --check` 通过。`./scripts/build.sh` Debug 构建/静态验签通过，沿既有 development 配置，不安装或启动产物；已有弃用 API/Swift 6 隔离编译警告不扩修。因仅授权隔离 XCTest 宿主，未运行另起普通宿主的 auto/swift 全量 profile，Swift 证据由上述完整目标的隔离定向回归提供。整体验收仍为 partial：两处外层事务＋AX 时序旧问题、普通截止真实 save 失败证据、指定复核、真人与历史未验项保留；最新测试分层与生命周期补验见本页第十阶段 H。已在 B 停止，无提交、推送、安装、发布、真实数据、系统偏好、签名配置或权限变更。

## 第六阶段 A：公共日期选择器与排期弹窗

范围和接口见[组件目录](component-catalog.md#第六阶段-a公共日期选择器与排期弹窗)。2026-10-02，macOS 26.6.2 arm64，沿原架构 PrivacyQA XCTest、build/.build.lock、独立 QA 标识/DerivedData、本地临时签名、生产沙盒 entitlement、串行测试和六项真实钥匙串环境清除；完整源码目标，不直接启动 QA 或日用应用。AppDelegate、Persistence、BoardEvents 和 NotificationScheduler 的现有 XCTest 隔离入口保持；测试仅内存模型、合成记录、独立偏好、原 PrivacyFixture/仓储与保存失败替身。

原生基线 `build/DatePickerA-baseline.xcresult`：5 项/8 次通过，含原 DayScheduleButtonConsumerTests。`DatePickerA-navigation-baseline` / `DatePickerA-month-baseline` 实际命中原生月份箭头：2026-12 翻到 2027-01 后 dateValue 仍为 2026-12-31，再返回不变；月份截图人工核对。左右键 ±1 天、上下键 ±7 天，可跨年；独立宿主 Return/Escape/失焦不提交，确认才提交当前日期。原生月份箭头没有独立 AX 子节点，合成鼠标坐标来自原生截图；原程序化 dateValue＋action 证据与鼠标/键盘分别记录。冻结原实现仅在 DatePickerNativeBaselineTests 作合成对照。

首轮公共测试 `DatePickerA-integration` 发现跨月格焦点接续及测试 AX 文本读取问题；同时发生磁盘空间不足，未视作通过。改用稳定网格焦点，并沿现有 NSObject AX 读取路径检查实际月份标题。用户释放空间后继续定向验证。

**最终验证**：`build/DatePickerA-queue-verification.xcresult` 为最终测试源码，30 项/45 次参数运行通过，0 失败、0 跳过。实际命中 DaybookDatePickerTests、DayScheduleButtonConsumerTests、DateScheduleLifecycleTests、DateScheduleCalendarIsolationTests、DayKeyTests、WeekdayMaskTests、DatePickerNativeBaselineTests 及原 galleryRenders。覆盖 4/5/6 周、周日/周一起始、闰年二月、跨月跨年、月末、今天/选中辅助语义、外部更新、拒绝写入、禁用和启用状态拆卸。任务行沿 Factory → Mutations → 仓储，并覆盖原 ModelChanges 保存失败仍关闭语义；详情沿真实 TodoScheduleSectionView 保存，手记卡片和行沿原 moveDiary。原提交次数及数据断言保留，没有更改正文/标签/提醒/截止/完成态逻辑。未逐一注入其余三个消费者的保存失败，原失败路径以源码兼容核对为证据。

键盘焦点载体与日格为兄弟节点，避免跨月格移除丢焦或全部日格误画焦点；不注册全局按键监视器。最终方向键/Return/Escape 经应用事件队列运行，生产 CalendarPage 的真实 TaskRow 弹出层不改变背后日历选中日、列表选中任务和合成数据。原宿主空白区队列鼠标点击关闭浮层，连续两次重开恢复原日键且不提交。最初直接 sendEvent 的外部关闭试验失败，已修正测试派发路径，不修改生产关闭策略。

最终静态质量门禁 `python3 -B scripts/quality_gate.py --profile static`、工作流检查、68 项检查器测试、188 项脚本回归、14 个本轮涉及文件的严格 SwiftLint 与 `git diff --check` 通过。Swift 证据由上述隔离定向回归和 `./scripts/build.sh` Debug 构建/静态验签提供；仅授权隔离宿主，未跑另起普通宿主的全量 Swift profile。构建沿已有个人配置，不修改配置、不安装或启动。既有 AppKit 弃用及 Swift Testing actor 警告保留。

原 ControlsPreview 扩展生产日期控件、今天/选中、禁用和外部更新，galleryRenders 中英文/浅深色四次命中并人工检查原生位图；另检查长月份、4/5/6 周和长确认按钮。独立日期宿主 280pt，弹出层使用公共 252pt 日期内容和原 12pt 内边距。系统材质透明缓存不代表最终屏幕合成；带 Daybook 纸底的展示图用于核对颜色和焦点。没有新展示应用或检查执行器。

指定 Cursor verifier 在当前工具清单不可用，独立复核仍 partial，不以其他代理替代。真人键鼠/VoiceOver、低版本 macOS、原生旧弹出层失焦与重开完整基线未取得，保留缺口。历史时间清除失败回显、日历列表切周焦点/窄周布局、主题回退、H 两项、Stepper 长按及其他未验项继续登记，不在本轮扩修。无提交、推送、安装、发布、真实数据/系统偏好/个人签名或权限修改。


## 第六阶段 B：主日历月网格接入

接口、共用日键身份和后续边界见[组件目录](component-catalog.md#第六阶段-b主日历月网格接入)。2026-10-02，macOS 26.6.2 arm64；沿原 PrivacyQA XCTest、完整正常目标、build/.build.lock、独立标识/DerivedData、本地临时签名、生产 sandbox entitlement、六项真实钥匙串变量清除和串行测试。只用内存模型、合成资料及原隔离偏好，不直接启动 QA 或日用应用。

**基线与外观**：修改前冻结原 CalendarMonthGrid，在同一 360×500 宿主内以 20pt padding 挂载 320pt 六周网格。七列宽 42/42.5pt、间隙 4pt；内容声明 52/28 不含 regular 按钮左右各 6pt、上下各 3pt。普通按钮实高 58pt，六周日期区域 368pt；紧凑通常 35pt，六位计数换行的格为 46pt，这组六周日期区域实高 241pt（不含星期行）。首轮误把紧凑预期设为 34pt 的断言失败，修正了测试预期，未改生产高度。首次 String 附加值丢失原数字分组符，图片比对发现后改为 `Text?` 保留原本地化插值。最终普通/紧凑×双语四组新旧 RGBA 像素差异均为空，全部 31 格边界一致；零计数占位、今天边框、选中底及长数字换行保留。图片在 `build/MonthGridB-visuals`；透明缓存不代表最终系统材质。

**最终通过**：`build/MonthGridB-final-regression.xcresult` **43 项/71 次参数运行，0 失败、0 跳过**。核对结果包实际命中 CalendarMonthGridLayoutTests、CalendarMonthGridTests、CalendarMonthPageTests、DaybookDateCellTests、DaybookDatePickerTests、DayScheduleButtonConsumerTests、DateScheduleLifecycleTests、DateScheduleCalendarIsolationTests、DayKeyTests、WeekdayMaskTests、MenuBarToolbarStateTests，以及 DaybookButtonInteractionTests.galleryRenders。包含 4/5/6 周、周日/周一起始、双语浅深色、跨年/闰日、长数字、今天/选中/投放表现组合、边缘/间隙/空白/禁用、重选回调、外部与拒绝更新；生产页面 1100/480 宽、760/520 高，原导航/今天/计数和合成快照不变。日期选择器方向键/翻月/选日与排期暂存/确认/关闭、任务行/详情/两类手记消费者均回归；没有把程序化动作当系统拖放。原 ControlsPreview 扩展同一日格样例，另直接挂载样例核对全部 16 个尺寸/状态格，已人工查看最终公共状态、宽窄页面、双语样例和原展示位图。

**拖放仍未验**：原 `.dropDestination(for: String.self)`、TodoDragToken 首个有效令牌、无回调/无效输入拒绝、回调参数及 dropKey 更新逐行保留，Theme 只接投放高亮值。保存成功/失败选中日的纯规则测试通过；实际系统投放、高亮接线、参数及生产保存/失败回滚未取得通过证据。合成 NSDraggingInfo 直接派发触发 AppKit `_lastDragDestinationOperation` 私有会话字段异常，该适配已移除；仅应用队列事件虽能结束公开拖动会话，也未触发投放。随后用 XCTest 等待原生控制工具执行真实拖动：工具可列出应用，但按名称/完整路径读取 AX 均超时，macOS API 不支持按精确窗口 ID 绑定。`MonthGridB-final-drag.xcresult` **2 项/3 次失败**，断言为 source.started=false；不能计作功能回归已证实或接线通过。途中 loginwindow/SecurityAgent 抢占焦点的失败也保留，没有跳过焦点断言、操作系统认证、改权限或停止其他进程。

该真实拖放入口为 `CalendarMonthGridDropTests`：仅在上述原隔离 XCTest 命令外显式设置 `TEST_RUNNER_AREACHAIN_MONTH_GRID_DRAG_QA=1` 时启用，避免普通测试等待外部操作。`MonthGridDropTestSupport` 在测试临时目录发出含合成日键、窗口与坐标的请求，等待公开 NSDraggingSession 实际结束；最终断言仍由测试执行，超时请求清理。它不是新的应用或生产入口，也没有直接启动宿主。修复原生控制工具连接后应补跑；不得以直接调用回调替代。

**静态与构建**：最终 `./scripts/build.sh` Debug 构建/静态验签通过（`build/MonthGridB-debug-final.log`），沿既有 development 配置，未启动产物。`check_workflow.py`、严格局部 SwiftLint、`git diff --check`、静态质量门禁及检查器/脚本回归通过；本轮检查器回归 71 项，完整脚本回归数量见最终 `build/MonthGridB-quality-final.log`。仅授权隔离 XCTest，未跑另起普通宿主的 auto/swift profile。并发查询代码/测试曾导致完整目标编译失败，未修改或排除这些来源，后续最终完整目标已通过。既有 AppKit 弃用/Swift 6 隔离警告不扩修。

指定 Cursor verifier 无可调用工具，未以其他代理替代；真实拖放和指定复核使整体验收保持 **partial**。真人 VoiceOver、低版本 macOS、系统材质及历史周布局越界、列表切周焦点、时间清除失败回显、主题回退、H 两项、Stepper 长按等未验项继续登记。停在 B，习惯月历仅保留 HabitCheckMonthView 线索；无提交、推送、安装、发布、真实数据、系统偏好、个人签名配置或权限变更。


## 第六阶段 C：习惯月历接入公共日期格

2026-10-02，macOS 26.6.2 arm64。接口见[组件目录](component-catalog.md#第六阶段-c习惯月历接入公共日期格)。只沿 build/.build.lock、完整正常 XCTest 目标、原 PrivacyQA 的独立 Bundle ID/DerivedData、临时签名、生产 sandbox entitlement、六项真实钥匙串变量清除与串行测试。没有排除无关源码，不直接打开 QA 或日用应用。只使用原 SettingsButtonTestSupport 内存库、独立合成偏好和合成习惯；共享导航、BoardSelection 和时钟保存/恢复。

**修改前基线**：直接挂载未改的 HabitCheckMonthView，检查器正常 320pt/最小 280pt，扣除 16pt 外边距和分区 12pt 内边距，日历可用宽 264/224pt。顶部仅检查日名称，七列、4pt 间隔、两位日号、micro（9pt medium）、xxs（2.5pt）圆角；22pt 最小内容行高，透明日期的 AX/按钮命中边界仅文字高 11pt，有底色高 22pt。五行日期区布局高 126pt，选中前景/底色覆盖状态色，今天不添加装饰。原截图保存在 build/HabitC-visuals；直接查看原月历与真实检查器。首轮把全部 AX 高度预期成 22pt、用 AX label 读取静态文字的断言失败，修正测试读取和测量预期，生产未改。HabitC-baseline-measured.xcresult 的 3 项/6 次运行通过；标题基线首次方法过滤实际 0 命中没有计作通过，随后静态文字定位失败，改读其 AX value 后 HabitC-title-measured.xcresult 实际 1 项通过。标题和备注点击日期均保留编辑焦点及草稿，显式失焦才按原规则保存；原导航且无编辑的合成快照不变。这些是应用事件/程序化输入证据，不是人工键鼠或 VoiceOver 验收。

**回归覆盖**：原 ControlsPreview 增加公共习惯五态×选中×今天样例。测试直接挂载 HabitCheckMonthView、TaskDetailDrawer 和公共日格，以宿主祖先与完整日键定位。40 组旧/新像素和全部日格 AX 边界一致，覆盖双语浅深色、280/320pt、五态各自选中；两位日号、原紧凑尺寸、今天无独立装饰均保留。另验 4/5/6 周、周日/周一起始、跨年闰月、局部日历与完整日期/状态辅助语义；导航测试涵盖重选、外部/跨月更新、outside、padding/间隙/禁用、其他习惯隔离、真实状态展示及关闭，合成快照确认无额外打卡。原标题/备注的点击保留焦点及失焦保存测试接入后通过。冻结旧绘制仅用于测试对照，生产没有第二套日格。已查看原月历、接入后的中英文浅深色月历/检查器、公共样例及原 ControlsPreview 位图；离屏缓存不能证明真实系统材质或人工交互。

**实际通过**：`build/HabitC-debug.log` 对应 `./scripts/build.sh` Debug 构建与静态验签通过，未启动产物。本轮 10 个 Swift 文件严格 SwiftLint、`git diff --check`、工作流检查、73 项检查器定向测试，以及静态质量门禁/193 项脚本回归通过，最终静态日志为 `build/HabitC-quality-final.log`。原 AppKit 弃用和 Swift Testing actor 警告保留。检查器只在原稳定符号清单增加 DaybookHabitDateState / HabitMonthGrid，并更新原反例测试，没有新执行器。

**失败与未运行**：`HabitC-regression.xcresult` 在测试插件 CodeSign 内部错误处失败，实际测试 0 项；随后的 `HabitC-verified.log` 明确报告磁盘空间耗尽，结果包未能完整生成，静态脚本同次也因临时文件无法写入失败。只清理本轮两个失败基线包，先保留其 `build/HabitC-baseline-failures.json` 摘要、通过的基线包和截图，未清理其他任务或前期产物；空间恢复后脚本重跑通过。`build/HabitC-final.xcresult` 的完整正常测试目标被并发新增的 `AreaChainTests/Theme/UnifiedSearchTestHost.swift` 写入只读 accessibilityReduceMotion 环境值的编译错误阻断，未修改/排除该文件。

**最终有效 Swift 证据**：并发来源随后修正，条件变化后重新运行完整正常目标。`build/HabitC-complete-target.xcresult` 命中 59 项/100 次运行；其中 3 项新测试因动态本地化键被误用插值构造、标题只读取 AX label 而失败，生产配色/像素和导航未报回归。修正测试为实际动态 key、读取静态文字 AX value，生产代码不变；`build/HabitC-focused.xcresult` 重跑全部三个习惯测试类，**9 项/19 次通过，0 失败、0 跳过**。

前一结果包中其余 **50 项/81 次通过**，实际命中 DaybookHabitDateCellTests、ManualOrderConversionTests、DayKeyTests、WeekdayMaskTests、WorkspaceItemsPageTests、DaybookDateCellTests、DaybookDatePickerTests、CalendarMonthGridTests、CalendarMonthGridLayoutTests、CalendarMonthPageTests、DayScheduleButtonConsumerTests、DateScheduleLifecycleTests、DateScheduleCalendarIsolationTests 和 `DaybookButtonInteractionTests/galleryRenders(locale:dark:)`。覆盖 picker 今天下划线/选中/焦点/方向键/翻月、排期暂存/确认/取消与任务/手记消费者，monthGrid 普通/紧凑高度、计数、今天边框、重选/外部更新和投放高亮呈现，以及 annotation 原本地化显示。两包合计最终有效范围 **59 项/100 次**；不把前一整包称为通过，失败已由后一包替代相应证据。程序化控件/应用事件队列和合成模型验证不等同人工键鼠、系统拖放或 VoiceOver。方法筛选使用完整参数签名，零命中未算通过。

**整体 partial**：指定 Cursor verifier 缺失，当前无可调用工具，不重复认证、不替换机制。B 的真实拖放未在条件不变时重试；本轮没有修改 picker/monthGrid 按钮承载、命中或 dropDestination 路径。人工键鼠、VoiceOver 与低版本系统未验；历史周布局、切周焦点、时间清除失败回显、主题回退、详情子任务、Stepper 长按等缺口继续保留，不扩修。本阶段停止于 C，无提交、推送、安装、发布、真实数据、系统偏好、签名配置或权限变更。

## 第六阶段 D：公共星期多选与三个消费者

2026-10-03，macOS 26.6.2 arm64。接口见[组件目录](component-catalog.md#第六阶段-d公共星期多选与三个消费者)。沿原 PrivacyQA XCTest、完整正常目标、build/.build.lock、独立 Bundle ID/DerivedData、临时签名和生产 sandbox entitlement；清除六项真实钥匙串变量，保持串行，只用原内存夹具与合成资料。不直接启动 QA 或日用应用，不改系统偏好/个人签名。

**旧实现基线**：生产修改前 `build/WeekdayD-baseline.xcresult` 实际命中 6 项 / 18 次运行，0 失败、0 跳过。七个 AX 圆点各 25×25pt、相距 4pt；圆左缘可点，方框角落与间隙不响应，按下有像素变化。标题显隐、两种语言、三个真实消费者的窄/正常窗口与长合成文案完成检查，截图在 `build/WeekdayD-visuals/baseline`。新建标题/备注及管理行标题、详情标题/备注在点击星期后继续持焦、保留草稿；即时保存的标题/备注直到显式失焦才提交。管理行与详情星期保存成功、真实事务失败后的同宿主自然回显与重试均通过。

**实现与回归**：生产只移动圆点并集中几何；WeekdayMask、三个消费者、保存入口及任务行原生星期子菜单不变。测试替身增加 weekdayWrites 与模型变更后的事务失败注入，未修改生产仓储。`build/WeekdayD-regression.xcresult` 完整正常目标实际命中 30 项 / 65 次运行，0 失败/跳过，包括 WeekdayMaskTests、原新建/启用/提醒测试替身消费者与本轮星期测试。最终只改测试后，`build/WeekdayD-final-focused.xcresult` 重跑受影响的三个测试类，9 项 / 21 次运行，0 失败/跳过；包括原值 0/越界位展示不写回、按原 toggling 操作、草稿取消最后一天回传 0 与恢复、非空最后一天重复回传原值、连续操作、外部更新、拒绝更新、禁用及多实例。运行时中英文与周日/周一起始切换不改变掩码身份。

**真实消费者证据**：新建清空后原提示/禁用保留，标题 Return 的独立保存校验拒绝空星期；恢复选择、取消、保存失败保留标题/备注/星期/启用/提醒与重试通过。真实 sheet 中失败不关闭，取消或成功保存关闭；不只测试无 dismiss 宿主。管理行与详情各自通过真实回调验证成功、事务失败后同宿主自然恢复、重试和最后一天未变化仍调用两次。启停、打卡、检查日导航、提醒与标签没有额外写入。原标题/备注输入期间的点击保持焦点与草稿，显式失焦提交语义保留。

**视觉与操作证据**：32 组冻结旧绘制/当前适配的 RGBA 像素、七个 AX 边界和标题 6pt 间距对照通过；另有 16 张旧/新基线与真实消费者 PNG 完全相同，包含中英文、浅深色、440/560pt 表单和管理页、280/320pt 详情。辅助动作和应用事件鼠标点击有实际回调/状态断言；按下反馈及边缘/角落/间隙与原实现一致，管理行时间按钮不重叠。原 ControlsPreview 共用四个星期样例，空/非空/禁用/独立实例的截图在 `build/WeekdayD-visuals/current`。当前系统设置下，新旧 Tab→空格均没有回调（`[[], []]`）；这只证明路径一致，**不算键盘激活验收**，未改变系统键盘偏好。图片缓存与程序化事件也不代表人工鼠标、完整输入法/撤销、VoiceOver 或系统材质验收。

**静态与构建**：最终 13 个本轮 Swift 文件严格局部 SwiftLint、`git diff --check`、工作流检查、75 项检查器定向测试及 `quality_gate.py --profile static --strict` / 195 项脚本回归通过。`build/WeekdayD-debug.log` 对应 `./scripts/build.sh` 的 Debug 构建和静态验签通过，沿既有 development 配置，未启动产物；不把签名成功解释为真实系统解锁或发行。检查器只在原稳定清单新增 DaybookWeekdayPicker、WeekdayPicker 几何和 TaskDetailWeekdayPicker 兼容入口及反例，没有新执行器。初次局部 lint 发现测试基线文件多余尾部空行，修正后通过；没有 Swift 用例失败或跳过。保留既有 AppKit/Swift 6 警告和构建目标架构选择提示。

**整体 partial 与停止范围**：指定 Cursor verifier 无可调用工具，未重复认证或以其他机制替代。键盘激活、人工输入/VoiceOver 和低版本 macOS 未验；历史真实拖放、日期格/习惯月历其他未验项、周布局、切周焦点、时间清除失败回显、主题回退、H 两项和 Stepper 长按继续保留，不无条件重试。旧 RepeatWeekdayPicker 后续线索已修正为当前圆点适配和 standingMenus 原生菜单的区别；第六阶段剩余只登记周布局与已有缺口，不启动下一阶段。无提交、推送、安装、发布、真实数据、系统偏好、签名配置或权限修改。

## 第八阶段 B：公共滚动装配去重

2026-10-03，macOS 26.6.2 arm64 / Xcode 26.6。生产仅改 DaybookColor / DaybookScroller，接口矩阵见[组件目录](component-catalog.md#第八阶段-bdaybookscroll-公共装配)。原默认值、指示器策略及具体 modifier 链保持，未改任何生产消费者、浮层绘制/事件/Timer、目标搜索/拆卸、边缘计算、AppKit knob 或统一搜索直接接入。

**隔离与原基线**：全部沿原 PrivacyQA XCTest，`build/.build.lock` 串行，`build/PrivacyQA` / `com.areachain.privacy-qa`、本地临时签名、生产 sandbox entitlement、LSUIElement=NO，清除六项真实钥匙串授权变量。正常应用与完整测试目标编译，没有排除并发搜索源码。SettingsButtonTestSupport、CalendarWeekTestSupport、原捕获及甘特宿主只用内存库、随机偏好与合成内容；只经 XCTest 启动，不直接打开 QA 或日用应用。

- `build/ScrollStageB-baseline-symbols.txt` 保存六个生产消费者原 `.o` 经 `nm -u` / `swift-demangle` 得到的单参数调用符号。`ScrollStageB-baseline.xcresult` 的真实五种接口调用反射确认：前三种 A，后两种 B；false/false/true/true/false 与 7/7/7/13/13。首次诊断测试错误地猜测系统内部类型名而失败 1 项；原安装/列表 4 项通过。随后公共结构契约通过，最终测试使用冻结的原完整链类型对照，避免依赖系统私有类型名。
- `ScrollStageB-native-baseline.xcresult`：原生 15 组装配显示 A 始终关闭系统指示器，B 在上游 hidden 时关闭、visible/automatic 时有系统指示器。内部 Environment 探针始终 automatic，不能用来测当前 SDK 的 scroll storage 策略；移除无效探针，改查真实 NSScrollView。短/空内容 knob 几何为零，但 alpha 可为 1，alpha 不等于实际有绘制。
- `ScrollStageB-consumer-baseline.xcresult`：23 个测试通过、2 个失败，0 跳过（40 参数化运行中 36 通过、4 失败）。错误断言分别为：零宽空内容的 SwiftUI 原生层级会移除、周列浮层不是一列一个。保留原结果；公共稳定视口补 maxWidth 后重新建立基线，没有改生产。原 TaskListScroll、CaptureOverlayLayout、GanttInteraction 在此通过。
- `ScrollStageB-stable-baseline.xcresult`：公共更新 5 组参数运行通过；正确周列/甘特归属 4 次已知失败；合成滑块窗口派发失败。`ScrollStageB-drag-baseline.xcresult` 延长等待到浮层 alpha≥0.05 后仍失败，保留为事件验收缺口，不修改事件机制，也不据此认定真人拖动必然失败。

**原有问题与实际边界**：周看板原生 7 个 NSScrollView 各自接受直接投递的滚轮事件，邻列偏移不变；7 个浮层却全部归首列。甘特外横/内纵分别滚动（窄宿主偏移各 80pt），但外层有 2 个浮层、内层 0。测试既固定原数量防扩大，也用 withKnownIssue 保留正确归属失败，不把旧错误称为通过。侧栏一个浮层、系统条关闭、直接 wheel 后偏移 80pt。公共启用羽化的合成宿主中，观察器存在但顶部/中间/底部 lastTop/lastBottom 都为 false；没有修其搜索。程序化 scroll、直接 scrollWheel、窗口合成鼠标派发和截图分别记证据，未取得真人滚轮/触控板或滑块拖动证据。

公共长→短→空→长、重复布局、无关状态更新和真正 window resize 以同一原生对象/浮层身份、onAppear 次数、原偏移与几何记录比较。原 SettingsButtonTestSupport 位图保存双语、浅深色、880/640 甘特及 1120/840 周列样例到 `build/ScrollStageB-baseline-images`；窄周仍越界且部分行文本未进入缓存，不能宣称完整视觉验收。原 ControlsPreview 未增加重复展示体系。

**本轮最终验证**（结果包均核对实际命中，零跳过）：

- `ScrollStageB-regression.xcresult` 命中 DaybookScrollContractTests、DaybookScrollNativeTests、DaybookScrollerTests、ScrollAssemblyConsumerTests、TaskListScrollTests、CaptureOverlayLayoutTests、GanttInteractionTests、CalendarWeekConsumerTests：28 项通过、2 项已知失败、1 项测试标记失败；参数化运行 42 通过、4 已知失败、1 失败。唯一普通失败为滑块已移动、却未触发旧 withKnownIssue，不是滚动失败。52 个公共/消费者记录场景与 stable-baseline 的原生数量、几何、偏移、系统策略和边缘状态逐行一致；拖动场景由 0 变为 363.46pt，不能归功于装配去重。
- 显式设置测试进程 regular/activate，并同场挂载原 A 冻结链与生产入口后，`ScrollStageB-final-native.xcresult` 两种窗口派发滑块拖动均为 363.46pt，完整链类型、单浮层安装也通过；周列和甘特仍 4 次预期归属失败。该包另有 5 组 resize 断言失败：测试误要求按内容取宽的原 ScrollView 横向填满宿主，实际 94.5pt 与原基线一致。
- 最后改为分别核对真实窗口宽 260、视口高 200、原内在宽度与浮层几何，`ScrollStageB-resize-check.xcresult` 2 项/7 参数运行全部通过（五种调用的 15 组上游策略循环及新旧滑块对照），0 失败/跳过。测试没有再修改生产行为，也未跳过焦点断言。真人触控板、窗口级滚轮命中与复杂嵌套滑块接线仍未验收。
- 两种甘特和中文深色周图 PNG 前后字节一致；英文浅色周图人工并排查看只有旧截图行悬停底/动作按钮差异。已有窄周越界、标题截断与缓存文字缺失仍在，不用截图替代交互或完整视觉验收。
- 最终 `quality_gate.py --profile static`、`check_workflow.py`、`git diff --check`、五个本轮 Swift 文件的严格局部 SwiftLint 通过；检查器定向 84 项、脚本回归 204 项通过。检查器首次漏补隔离目录夹具的稳定入口文字，3 项失败已修正并重跑；文档新增锚点也已补齐。稳定检查沿原 COMPONENT_ENTRIES 和反例，没有新执行器。
- `./scripts/build.sh` Debug 构建及静态验签通过，沿现有 development 配置生成候选物，hardenedRuntime=true、distributionReady=false；不修改签名配置、不安装或启动。保留 Xcode 原生辅助 API 弃用/actor 警告与多 destination 提示，不视为新错误。

指定 Cursor verifier 当前不可调用，完整验收状态保持 **partial**；不重复认证、不以其他机制替代。公共去重已实施，原边缘定位、周列/嵌套浮层归属和未验项未解决。未提交、推送、安装、发布或修改真实数据、系统偏好、签名配置及权限。

**停止边界**：浮层外壳的候选/属性承载仍留下一阶段；可从 SyntaxAutocompletePopup、CaptureAttributesView 和 SyntaxOverlay 的重复装配追踪，但不能将其关闭/提交语义一并统一。第八阶段 A 的命中扩区、拆卸、嵌套目标、固定动画/减弱效果和搜索双指示器疑点继续保留；搜索换行、周布局、拖放、Tab、密码残留和人工验收缺口不在本轮处理。

## 第八阶段 C：候选与只读属性浮层外壳

2026-10-03。本轮公共入口、表现差异、两个已迁移消费者与未迁移边界见[组件目录](component-catalog.md#第八阶段-c候选与只读属性浮层外壳)。已有统一搜索与滚动修改原样保留，未操作暂存区。

迁移前先冻结两处原外壳到测试支持，并增加直接组件双语/浅深色/240 与 356pt 矩阵，以及原 SyntaxOverlay 的上下展开与受限空间组合。完整正常 PrivacyQA 的 `build/SurfaceStageC-baseline.xcresult` 编译失败：CommandHandoffCoordinator.swift:52 找不到并发代码引用的 CommandDraftCheckpoint；没有执行测试，不能作为基线通过。未修改或排除无关文件。

**隔离与基线**：macOS 26.6.2（25G83）arm64，正常完整应用/测试目标，沿 build/.build.lock、build/PrivacyQA、com.areachain.privacy-qa、本地临时签名、生产 sandbox entitlement、LSUIElement=NO；清除六项真实钥匙串变量并串行运行。只用合成内容/内存库/独立偏好。并发缺失类型补齐后，临时只撤回本轮两处接入，核对两消费者与 HEAD 无差异，再运行原绘制；未改并发代码。`SurfaceStageC-original.xcresult` 73 项中 71 通过、2 失败：空态误用可见控件查询，以及公共属性预设误将默认角解释为 circular。SDK swiftinterface 证实当前默认 continuous；改为保留原默认构造，空态改查零尺寸/无滚动。`SurfaceStageC-baseline-complete.xcresult` 7 项、12 次运行全部通过，0 跳过。随后恢复两处公共接入。

**最终有效证据**：`build/SurfaceStageC-regression.xcresult` 的 summary/tests 树确认 76 项、103 次运行通过，0 失败/跳过，实际命中 DaybookSurfaceTests、DaybookFloatingSurfaceTests、OverlaySurfaceConsumerTests、SyntaxOverlayPlacementTests、SyntaxAutocompleteTests、CaptureOverlayLayoutTests、InputSyntaxInteractionTests、DiaryComposerInteractionTests、MenuBarPopoverRenderingTests、UnifiedSearchInputTests、UnifiedSearchLayoutTests 和原 galleryRenders。`build/SurfaceStageC-shared-search.xcresult` 另命中操作宿主的双布局/双语/主题/宽窄循环及原候选接受/过期拒绝，2 项通过，0 失败/跳过。`build/SurfaceStageC-gallery.xcresult` 的 interactiveGallery 通过，原 ControlsPreview 只经 XCTest 挂载并等待 45 秒，无真人输入证据。

**呈现与几何**：`build/SurfaceStageC-before` / `build/SurfaceStageC-after` 保留完整宿主位图与 JSON。56 个直接场景（含 8 个空态）、12 个生产 SyntaxOverlay 合成来源场景和 8 张冻结/公共壳对照共 76 张；76 份几何按标识、frame 和 bounds 完全相同。属性宿主的原生遍历顺序有变化，但面板、关闭按钮、列表和锚点几何相同；该合成属性来源按内在宽度布局，仅 90pt，作为极窄约束证据，正常属性宽度由直接矩阵及真实 CaptureOverlayLayout 宿主补充。公共两预设的完整外缘、角部、居中描边、越界图形与阴影在浅深色下逐像素一致；装饰开关不增加 onAppear、不改变尺寸，关闭时与无壳内容像素一致。76 张中 56 张像素全同；其余 20 张均含未修改的手记当前时间，时间字形变化也会移动后方标签，不能写作整图一致。共享搜索 19 张、捕获宿主 5 张全同；原输入宿主 8 张中 6 张全同，另 2 张保存后的手记时间变化。`build/SurfaceStageC-comparison.png` 将四张完整位图合成在中性底上展示阴影，未裁掉外边缘；它是原生缓存位图，不是窗口合成器截图。

**行为层级**：原 NSWindow / NSHostingView 已实际挂载并要求 key/visible；NSApplication 合成鼠标验证候选单次回调、圆角边缘/外侧阴影不扩大拦截，真实捕获输入保持原替换范围、光标与撤销；原属性按钮开/关/重开/再次切换、关闭按钮与 Escape 保持零标签创建和未保存草稿。新增原宿主测试分别验证候选 Escape 留预览、再 Escape 关预览；外部点击/窗口失焦/来源卸载仍按原路径清候选而保留预览状态。程序化 state 更新、setMarkedText/insertText 和合成应用事件不是真人输入。检查器的最近宿主单一事件监视器、菜单栏/工作台捕获、手记捕获/小窗以及搜索 customRow、68pt 计算、列表限制、上下定位和接受路径均沿原测试回归。没有新增模型写入、标签创建或第二个补全宿主。

**门禁**：最终局部严格 SwiftLint（8 个本轮 Swift 文件）、Swift 语法、静态 profile、check_workflow、git diff --check 通过；检查器首次定向 85 项、脚本回归 205 项通过；最终静态 profile 随当前并发工作区重跑脚本 206 项通过，最终定向检查器 86 项通过（SurfaceStageC-workflow-tests-final.log）。`./scripts/build.sh` Debug 与静态验签通过，沿既有 development 配置，hardenedRuntime=true、distributionReady=false；未改个人签名。保留 SDK 原辅助 API 弃用/actor 警告。

**未覆盖**：完整验收状态为 **partial**。未取得窗口合成器实际屏幕截图；真人输入法、VoiceOver、触控板/窗口级滚轮与动画进行时仍未验。位图、几何、应用事件、程序化状态、实际窗口挂载分别取证，不相互替代。外壳无新滚动接线；现有滚动归属/羽化/窗口边缘缺口没有修复，不能由这次通过推定消失。指定 Cursor verifier 当前不可调用，保留复核缺口，不重复认证或用其他机制替代。第八阶段 B 周列七浮层归首列、甘特外层双浮层/内层缺失、羽化定位及真人滚轮/触控板等历史未验项继续登记，不扩修。未提交、推送、安装、发布、直接打开 QA/日用 App，未修改真实数据、系统偏好、个人签名或权限。


## 普通偏好聚合后端（3A-3B1）

本阶段仅显式临时目录的文件后端与提交核验；没有迁移、生产后端切换或指令/UI 接线。实际命令、最终证据、故障注入与真实进程中断的区别，以及指定 Cursor verifier 的 partial 缺口只维护在[权威 §9.58](unified-search-commands.md#958-阶段-3a-3b1版本化聚合文件后端与提交恢复)。后端 writer.lock 和 build/.build.lock 各自独立，正常非等待取锁不抢占其他验收。


## 普通偏好隔离迁移（3A-3B2A）

独立 suite、逐键来源注入及显式临时目录用于迁移、故障和同进程重开；原 FileStore 锁/提交/noChange 测试继续回归。唯一命令、结果和未覆盖项见[权威 §9.59](unified-search-commands.md#959-阶段-3a-3b2a旧四键隔离迁移重开与恢复判定)。指定 Cursor verifier、真实进程中断、跨进程竞争和掉电实验分别报告；不由故障注入替代，不接生产迁移或整份内存发布。


## 普通偏好聚合发布（3A-3B2B）

临时文件后端、隔离 suite 与注入外观/事件用于 AppPreferences 的启动、整份发布、Binding、失败与显式核验回归。复用完整正常 QA 目标和原构建锁，静态 profile 配定向隔离测试，不启用真实系统授权。唯一实际命令、结果、并行编译阻塞、指定 Cursor verifier 与历史验收缺口见[权威 §9.60](unified-search-commands.md#960-阶段-3a-3b2bapppreferences-聚合后端整份发布与展示事件)。生产后端、用户迁移、指令组执行、安装和发布均未接线。

### 普通偏好组执行验收（3A-3B3A）

本轮仅显式临时文件后端和注入展示效果。FileSettingCommand 五套测试串行验证真实 Parser→Draft→Plan→文件提交→Run，使用后端实际入口/替换计数、原四键快照、文件清单及 Observation 观察完整组；同时回归后端、AppPreferences、原子组和旧单项。完整正常 QA 目标、独立标识/DerivedData、六项真实钥匙串变量清除、原 build/.build.lock 非等待申请；静态门禁与运行证据分开。实际结果及剩余缺口统一记于[权威 §9.61](unified-search-commands.md#961-阶段-3a-3b3a普通设置组准备共同执行与回执)，指定 Cursor verifier 缺口保留，无生产窗口/迁移/安装/发布。


### 普通设置组原生验收（3A-3B3B）

采用正常完整目标、显式临时文件与随机 suite、注入展示、独立 QA 标识和 DerivedData，原测试锁非等待申请并保持串行；六项真实钥匙串授权清除。服务/控制器、原生行为、截图、最终 Debug/验签与静态证据分别登记，计数和缺口以[权威 §9.62](unified-search-commands.md#962-阶段-3a-3b3b普通设置共同提交的原生接线)为准。不迁移用户设置、不切换生产默认后端；指定 Cursor、人工、C2B 和历史外观缺口不因本轮通过而关闭。


### 普通捕获 3T-1A 的验证交接

[权威 §9.64](unified-search-commands.md#964-阶段-3t-1a普通捕获共享新增与事务局部边界) 保存本轮完整证据：正常 PrivacyQA 中 57 方法／74 次运行通过；随后最终回滚事实与发布辅助函数补充的重验因原测试锁占用停止。最终静态/脚本通过，最终 Swift 重验、独立 Debug 构建及指定 Cursor verifier 保留缺口，状态 partial；不重试锁、不接 handler、不进入 3T-1B。


3T-1A 最终验收续轮：原遗留增量已在正常 PrivacyQA 中通过 23 方法／37 次运行；随后发现并窄修正“原始 ModelRecoveryError 被误认为本次恢复失败”的事实分类，新增一项必要回归。修正后原锁忙，立即停止；最终新增修正、正常 Debug 构建/验签仍未完成，保持 partial。分版本证据只见[权威 §9.64 E1](unified-search-commands.md#e1-最终验收续轮已验证内容与新发现2026-10-05)。


3T-1A 再次续验已通过最终源码 24 方法／38 次运行（含回滚事实新回归），受验源码哈希一致；随后正常 Debug 构建因原锁忙退出 3，未执行独立静态验签，不重试。当前测试缺口已补齐，构建/验签与指定复核等缺口保留；唯一当前证据见[权威 §9.64 E2](unified-search-commands.md#e2-最终源码定向测试通过debug-构建仍受锁阻塞2026-10-05)。


3T-1A 本地验收收口：最终受验源码哈希保持一致，沿用最终 24 方法／38 次执行通过证据；`./scripts/build.sh --no-wait` 正常 Debug 构建退出 0，静态验签 staticSignatureVerified=true。前述本地构建/验签缺口已补齐，指定 Cursor、C2B、人工与历史缺口不变；当前结论只维护于[权威 §9.64 E3](unified-search-commands.md#e3-本地最终验收收口2026-10-05)。未安装、发布或进入 3T-1B。


### 最小普通创建指令隔离执行（3T-1B）

单个 title＋day 的 TaskCreateCommandAdapter 复用原捕获与 SwiftData 事务，固定 UUID、原运行占用、私有事件/fake 消费者及最终证据统一见[权威 §9.65](unified-search-commands.md#965-阶段-3t-1b最小普通-todocreate-的隔离真实适配)。完整正常 PrivacyQA、原锁非等待申请、独立标识/目录及六项授权清除保持；指定 Cursor、C2B、人工和历史缺口独立保留。不接生产、其他参数或原生执行 UI，完成后停止。


## 设置控件预览（2026-10-08）

本项是新增产品功能，独立于此前公共控件重构收口与 O/P 历史验收结论。设置外观区新增可见入口，共享展示迁入生产目标；单窗复用、关闭释放、合法窗口登记及局部状态契约见[组件目录](component-catalog.md#设置控件预览)。旧测试仍挂载同一展示；平台 QA、测试夹具及 runner 留在测试目标。

**实现与边界**：生产设置区的真实按钮进入单一预览窗，原 Gallery 与纯 Samples 共用生产目标下的展示。AppKit 可延后释放 hosting controller，所以关闭时先将其根视图置空，再解除内容与窗口引用；测试刻意保留容器，核对原生输入脱离窗口、旧菜单 target/action 解除、样例节点卸载与重开初值。预览减弱动态效果的环境值移除原 DEBUG 限制，默认仍为 false，系统辅助功能设置不被覆盖。

**实际验证**：所有原生运行只由 XCTest 启动，沿原 `build/.build.lock`（最多等待900秒）、完整正常 PrivacyQA、独立目录 `build/PrivacyQA-SettingsControlsPreview`、独立标识及六项钥匙串授权清除。没有启动日用应用或旧 QA 应用。

- 新入口的 SettingsControlsPreviewTests / ControlsPreviewInteractionTests 共5方法、9次参数化执行已取得通过记录：打开／重复打开、两种关闭顺序、重开、其他登记窗口保留、关闭卸载、局部输入／重置／禁用、双语／浅深色、760×640及680×560、日期／时间弹窗、Tab焦点、跨窗口⌘Return、零业务事件与零系统剪贴板写入。
- 原 Gallery、日期格、习惯格、周标题、星期、普通输入、Picker、Stepper、完成控件、表面与复制回调消费者均使用共享展示并回归。所选检查按方法和参数取最后有效结果汇总为92方法／211次；这不是单次全量测试，也不外推为所有并发功能均已验收。原始结果包与源码摘要保留在 `build/SettingsControlsPreview` 的 regression、entry-final、completion、presentation-recheck 批次；早期失败记录不删除。
- 严格 SwiftLint、`python3 -B scripts/check_workflow.py`、static profile、脚本回归和 `git diff --check` 已实际运行。完整 QA 应用编译与 `codesign --verify --deep --strict` 通过。Release 按 build.sh 同等参数、既有 development 配置及原锁构建；`scripts/signing.py verify --configuration Release` 通过，Hardened Runtime 为 true，未带测试目标，`distributionReady` 仍为 false。Release 起止全源摘要一致。
- 已查看 XCTest 导出的中英文、浅深色和最小尺寸原生视图缓存图；这些不等同系统窗口合成器截图或真人 VoiceOver／输入法验收。本轮没有重做用户已确认的历史人工矩阵。

**失败定位与并发**：初期纠正展示复制闭包的显式初始化参数、可访问性根标识覆盖与计数角色、截图附件的既有 `settings-` 文件名前缀；完整窗口关闭后测试重新打开时补齐生产激活／show，再保持原焦点断言。旧静态表面悬停失败已原断言复验通过。并发新增代码曾阻断编译／500行门禁，经用户明确授权，仅补 BatchCommandEnvironment 三处 self 限定，并将 CommandExecutionRun.creationOutput 原样移入同职责扩展，保留私有 setter；相关执行结果和批量命令隔离回归通过。部分运行期间其他命令源码／测试变化单独记录，不将该批结果当作最新整个工作区的同一快照证明；控件相关文件未被这些并发编辑改写。最终 presentation-recheck 与 Release 全源摘要均一致。随后 window-final 的8次场景通过、1次矩阵失焦保留原记录；只增加失焦动作／前台标识诊断，原断言不变，focus-recheck 的4组矩阵全部通过，零失败／跳过，完整 QA 重新编译及验签通过，起止全源摘要一致。Release 之后新增的搜索源码与文案属于并发任务；本功能生产源码未变，已逐键对比 Release 内 en／zh-Hans 各61个预览文案值与当前资源，完全一致，不将该 Release 外推为后续并发搜索代码的最新发行物。现有暂存改动保留。

**保留缺口**：指定 Cursor verifier 当前没有可调用工具，未执行独立只读复核；材料为用户原始需求、当前差异、组件契约及上述证据，不以其他代理替代。实现与已列自动验证完成，整体保留 partial 复核缺口。没有执行提交、推送、安装、发布、真实认证或真实业务数据操作。


## 工作台公共框架调整（2026-10-09）

**状态：实现与所选验证已交付，整体 partial。** 固定单行顶栏、主内容区居中且身份唯一的搜索、真实内容宽度操作收纳、详情空间门禁、侧栏固定顶部与局部滚动羽化已实施。入口及状态责任以[组件目录](component-catalog.md#3-feature-级复合组件)和[公共顶栏架构](architecture.md#工作台公共顶栏)为准；标签管理原 List 补接同一滚动装配，备注合并同一草稿的失焦/卸载保存尝试。原生产搜索与事务未替换；已有统一搜索暂存和并发修改保留。

验证使用完整 AreaChain scheme / Debug 测试目标，独立 `com.areachain.workspace-shell-qa` / `build/WorkspaceShellQA`，原锁单次最多900秒、六项真实钥匙串变量清除、合成内存数据和串行事件。环境为 macOS26.6.2 arm64。所有命令、日志、源码清单与 xcresult 位于本地忽略目录 `build/workspace-shell-evidence`，不作为可发布产物。

- `shell-regression-compiled`：32方法／53次通过，3项失败。搜索输入缩放的唯一身份、选区、组合文本、撤销/重做；原生菜单状态/嵌套/单次动作；标签创建与失败；标题草稿和备注失焦/卸载去重通过。两个新整窗夹具崩溃在对齐原 WorkspaceRenderingTests 的外观承载和 fullSizeContentView 拆卸后由 `inspector-diagnostic` 2方法复验通过；不将修正夹具写成修复生产崩溃。
- `shell-final`：35方法／56次通过，7项失败。6项在焦点准备阶段报告前台 `com.apple.loginwindow`，未跳过/降低断言；主工作台搜索在侧栏缩放和详情收起时的完整焦点联动仍未通过最终验收。另有未改动的 WorkspaceLayoutTests 原生字体断言失败：编辑器回退 PingFangUITextSC-Semibold，字段为 AppleSystemUIFontDemi，同为16pt；保留问题，不借本轮布局扩改输入实现。
- `noninteractive-verified`：13方法／27次通过，0失败/跳过，覆盖原页面矩阵、羽化契约/归属/生命周期、顶部位置/短内容/卸载，以及仅顶部策略和降低透明度。方法级筛选曾未命中，零命中批次不计通过；修正为实际 Swift Testing 方法标识后，`selectors-verified` 4方法／11次通过，含长标题无空菜单、实际详情收起/恢复、侧栏与9类页面独立滚动、标签页双宿主及中英文/浅深色/默认与最小尺寸页面矩阵。重复项目不累加。
- `host-compatibility`：3方法／5次通过，覆盖菜单栏搜索绑定、侧栏唯一羽化、非工作台甘特保持默认无羽化及周列独立轴。只证明合成事件/控件API，不冒充真实触控板或系统键盘验收。
- `./scripts/build.sh` 正常 development Debug 构建和静态验签通过；申请、持锁和结束源码一致，生产及构建源摘要为 `9920f6cb9f92616be40988a0445cf225aecc426c6e0726aed0450c5fb305b420`。其后仅调整 ScrollAssemblyConsumerTests 的侧栏新预期，生产未再修改。最后 QA 全源摘要为 `bc2f48bde79484bd121ad7895e2910427e8a1780fa55208ca0b7ad30b2915235`。构建不代表系统解锁或发行通过。

本轮静态门禁使用 `quality_gate.py --profile static` 加独立隔离 QA，避免 auto profile 启动普通测试宿主；`check_workflow.py`、其119项定向脚本测试、包含262项脚本回归的静态门禁、相关严格 SwiftLint 和工作区/暂存差异检查通过。最终文档编辑后重跑受影响静态检查。

原生缓存图在 `before-images` / `after-images`，均来自合成 QA。整窗缓存未绘出系统侧栏材料和窗口按钮，不能据此断言窗口合成效果；`workspace-sidebar-content-*.png` 单独证明侧栏内容。没有真实全屏/退出全屏、窗口拖动、详情自动收起时组合输入、完整失败磁盘保存或真实辅助技术的新证据。

最终发现本任务 QA 可执行路径下残留 PID8295（启动时间2026-10-09 12:23:55，父进程为1），lsof 未显示 XCTest 加载证据。核对可执行路径和启动身份后向该进程发送 SIGTERM，随后确认退出，记录为 `qa-process-cleanup.json`；未读取其数据或据测试通过推断没有副作用。该进程启动来源及运行期间是否触发非测试系统服务未确认，属于本轮新增隔离验收缺口；不通过删除数据、重启 QA 或读取真实内容追认。

指定 Cursor verifier 当前不可调用，**指定复核未执行**；未认证、安装或换代理替代。桌面控制入口保持暂停；锁屏导致的焦点缺口、字号断言、残留 QA 进程异常和指定复核独立保留。未主动读取或修改正常用户数据/偏好、签名配置或全局设置，未安装/启动正常应用、提交、推送或发布。

### 工作台验收收尾（2026-10-09，本轮）

**仍为 partial，未满足完整门禁。** 字体断言已修正；详情标记、组合草稿和焦点生命周期已修复，真实工作台的标题/备注收起、恢复、继续编辑及显式保存通过合成原生检查。最后相关回归在启动前被新的并发源码变化拦住，最终稳定源码的回归与正常 Debug 门禁仍待完成。以下补充不覆盖上一轮失败，也不把不同源码的局部通过拼成当前工作区全部通过。

本轮证据统一在 `build/workspace-shell-evidence`。接手时 1,381 个源码/测试/构建文件与上轮最终清单完全一致，完整摘要为 `bc2f48bde79484bd121ad7895e2910427e8a1780fa55208ca0b7ad30b2915235`，见 `closeout-initial-source.json`。摘要算法为 Git 已跟踪及非忽略未跟踪的 AreaChain、AreaChainTests、AreaChain.xcodeproj、Config、scripts 文件逐项 SHA-256，再对按键排序 JSON 求 SHA-256；不是 HEAD 或缩写。

本任务最后通过组合闭环的完整源码为 `33064380f88e7602ef563d750fffb1af50801c68c90ff1903d1ac77604156f1d`，见 `closeout-composition-end-source.json` / `closeout-composition-end-after-source.json`。其后另一项统一搜索工作持续修改创建输出、Command Plan/Run、适配器及创建服务；首批 13 个路径，随后仍有新增变化。已读相关差异，未覆盖本任务 8 个 Swift 文件，未替其他工作修改、回退或移动文件。并发及收尾瞬时完整清单见 `closeout-concurrent-source.json`、`closeout-handoff-source.json`；变化中的快照不等于稳定发行身份。

收尾快照采于 2026-10-09 14:52:58（Asia/Shanghai），1,388 个文件，完整摘要 `6d6731f734e392fa848f14111a6873efa96f1fd0b5d0624ea2cb45248443c0dc`。连续两次快照相同，但相比受测源码已有 44 个并发变化路径；本任务 8 个 Swift 文件全部仍与受测版本一致。摘要、时间、当前进程盘点和暂存区摘要见 `closeout-handoff.json`，不将这瞬时一致性外推为构建期间稳定。

上轮实际 xcresult、命令和前后源码清单已核对，详见 `closeout-historical-audit.json`：noninteractive-verified 全源为 `b2d9d16e8c0c012bf44916cd9cafbd382d46f648445a8b3be353080d5ae6ceb4`，selectors-verified 为 `e069a2d750f32a33164e4075a1b8eeb1adb42e7dc3b8c55aaa37dc088f7c4f21`，host-compatibility 才与接手全源一致。未再修改的滚动、操作收纳等范围保留对应证据，没有重跑全部历史矩阵。

#### 历史进程与本轮隔离

`qa-process-cleanup.json` 直接记录 PID 8295 的路径为 `build/WorkspaceShellQA/Build/Products/Debug/AreaChain.app/Contents/MacOS/AreaChain`，启动于 12:23:55，匹配路径/启动时间后 SIGTERM，随后 `after:null`。父 PID 1、未发现 XCTest 映像只剩上轮文字记录，没有完整原始父链/映像清单，不能重新认证历史状态。

实际 shell-final 于 12:21:33.719 结束，PID 8295 晚约 141 秒启动；noninteractive-final 到 12:24:36.749 才开始，且编译失败、0 测试。不能把它归为上述任一批的正常测试宿主。没有找到期间确切启动命令，也未留存本任务旧 runner；单独启动与框架恢复无法区分，不能归因某个工具或断言旧 runner 没有 finally。

历史路径属于本任务 QA 产物，命令声明 bundle ID 为 `com.areachain.workspace-shell-qa`；这不能证明该实例进入 XCTest 模式。`AreaChainApp.init` / `AppDelegate.applicationDidFinishLaunching` 依赖 `XCTestConfigurationFilePath` 决定内存库与服务启动；缺失标志时可进入持久化、剪贴板、通知、日历及快捷键初始化。关闭最后窗口返回 false，本来就不会自动退出应用。QA 标识/沙盒通常提供独立容器，但旧实例的实际签名、环境、数据 URL 与系统服务情况未留存；历史副作用仍未知，不读取真实数据追认。

本轮仅由完整 AreaChain scheme / Debug XCTest 启动，保留原 QA 标识/目录、原锁单次 900 秒、六项钥匙串授权清除及串行事件。当前 Info.plist、源入口及测试内 `xctest=true` 元数据对应；夹具用内存库、独立 UserDefaults suite 和注入事务/发布回调，共享偏好处于 QA 应用域。AppDelegate 的 XCTest guard 阻断真实系统服务启动；合成保存内容不含请求提醒权限的语法。

补留的 `run.py` 最初复用原 Controls10P runner 的锁与只读 proc 身份读取。收尾发现该临时依赖文件已不可读，故将相同职责就地保留为自包含实现，不依赖其他任务的 build 目录，也不调用 LaunchServices；检查编译清单、启动前盘点、pid/start/path、退出、超时/中断和运行后源码。已有实例或源码不匹配即拒绝启动，只按本批再次核对的身份清理。`test_run.py` 的 11 项隔离检查覆盖成功、失败、超时、中断、预存实例、身份不明、PID 复用、退出竞争、锁释放及锁超时保留其他持有者；每批 `*-lifecycle.json` 留实际结果和 runner 依赖摘要。

本轮实际 PID 为 34075、37908、40174、42193、43987、44537、47345、48620、49191、51990、54795，均在测试退出后确认不再存在，无需补发结束信号。收尾无可确认属于本任务的残留实例；这不替代历史 PID 8295 的未知项。

#### 修复与契约

- 字体原失败是 `WorkspaceLayoutTests.nativeFieldKeepsTheDeclaredSizeAndWeightWhenEditing()` 旧文件第 23 行，不是任务/手记正文字体测试。实际 `.PingFangUITextSC-Semibold 16pt` 与字段 `.AppleSystemUIFontDemi 16pt` 对象不等。本轮在解锁前台、可见且编辑中的唯一目标再次复现；宿主 360×70，中文合成内容，旧夹具未显式指定主题/locale。CoreText 对同一声明字体的中文回退与实际字体完全一致，详见 closeout-baseline-diagnostics 的 StandardOutputAndStandardError.txt。仅改测试，英文/中文各检查 regular 正文和 semibold 标题的显示态、实际编辑态、精确字号/traits、delegate、first responder 与唯一可见目标；不放宽容差或改生产字体。修正及工作台任务/手记正文检查在 closeout-repair、closeout-verified 通过。
- 原备注去重只在单次挂载记文本；生产 TaskDetailSections 已用记录 `.id` 隔离，因此不跨记录共享。显式保存绕过去重，继续编辑清掉上一尝试，失败保留 EditDrafts。新增测试经实际 `DayBoardMutations.updateNotes` 嵌套注入 `ModelChanges.Boundary`，核对保存一次、失焦/卸载去重、失败零发布与重试、新内容再保存、不同记录同文本、外部更新保护及恢复；未替换事务或改变保存成功含义。
- 组合输入基线失败实际是原生缓冲未进入保留草稿，保存调用为 0，不能称为已发生提前保存。原焦点对象无条件接收 make/update 的弱标记，真实窗口测量候选释放后标记为 nil；closeout-trace / closeout-owner 保留诊断。现在只登记已挂载窗口的标记、按实例清理，用字段编辑器所属字段定位区域。收起前经原委托同步缓冲，保留字符后结束即将隐藏的组合会话；瞬时标志让标题/备注保留原草稿、不提交，并在实际重新呈现时重置，不依赖 NSView 重建。
- 标题曾在 makeFirstResponder(nil) 返回 true 后又回到隐藏字段，closeout-title-trace 保留即时释放与后续失败。最终同步撤销焦点绑定、结束原生组合会话，并把确实来自详情的焦点交给原可见搜索入口；查询、选择、检查日保持，已在搜索的焦点不动。这是“收起后合理位置”的局部落实，不接入新搜索。最终两种真实详情均验证手动重开、恢复、继续编辑、NSEvent Return/⌘Return 显式保存及清除草稿；真实中文输入法仍未验证。

实现涉及 MainSplitWorkspaceView、WorkspaceInspectorPresentation、TaskDetailNotesView、TaskDetailHeaderSection；测试涉及 WorkspaceLayoutTests、WorkspaceInspectorSizingTests、WorkspaceNotesLifecycleTests、WorkspaceWindowLifecycleTests。组件目录、架构和技能路由同步边界。标题 Escape 仍回滚；备注沿原失焦保存，不新增取消政策、平行草稿或业务状态机。

#### 原 6 项焦点检查与运行账本

上一轮六项都是已启动后焦点前置条件失败，前台 loginwindow，不是产品断言失败。本轮准确结果如下，没有跳过首次按键或 first responder 检查。

| 方法 | 本轮结果 |
|---|---|
| WorkspaceHeaderInteractionTests.failedTagCreationRetainsDraftAndMarkedTextDoesNotSubmitOrCancel() | closeout-baseline 通过；该路径未再修改 |
| WorkspaceHeaderInteractionTests.globalShortcutWinsOverDiaryLocalSearchAndClearingRestoresSource() | closeout-baseline 通过；该路径未再修改 |
| WorkspaceHeaderInteractionTests.titleDraftSurvivesFailedSaveAndUnmountWithoutExtraSubmission() | baseline、verified 及后续局部回归通过；最终稳定工作区回归待补 |
| WorkspaceHeaderSizingTests.overflowKeepsNativeMenuStateHierarchyAndOneCallback() | closeout-baseline 通过；操作收纳未再修改 |
| WorkspaceHeaderSizingTests.resizingKeepsEditorSelectionMarkedTextAndUndo() | closeout-baseline 通过；唯一输入、选区、marked text、撤销/重做检查保留 |
| WorkspaceInspectorSizingTests.searchKeepsFocusAcrossSidebarResizeInspectorCollapseAndBodyReplacement() | baseline 与多次修复回归通过；最后实现后的回归在启动前被并发源码门禁拦住 |

完整摘要、测试树、命令、源码及进程在 `closeout-run-audit.json` 和各同名前缀文件。统计方法与执行次数分开，所有批次零跳过：

| xcresult 前缀 | 方法数 | 执行次数 | 通过 / 失败 |
|---|---:|---:|---:|
| closeout-baseline | 12 | 12 | 10 / 2 |
| closeout-repair | 13 | 15 | 12 / 3 |
| closeout-native-buffer | 9 | 10 | 8 / 2 |
| closeout-dismissal | 2 | 3 | 1 / 2 |
| closeout-trace | 1 | 2 | 0 / 2 |
| closeout-owner | 1 | 2 | 0 / 2 |
| closeout-verified | 13 | 14 | 13 / 1 |
| closeout-focus-binding | 9 | 10 | 9 / 1 |
| closeout-title-trace | 1 | 2 | 1 / 1 |
| closeout-acceptance | 9 | 10 | 9 / 1 |
| closeout-composition-end | 1 | 2 | 2 / 0 |

共涉及 18 个唯一方法，参数变体包括标题/备注及浅/深色；含诊断和重跑共 82 次实际执行，不计作新增覆盖。原正文及交接写作“92 次”，最终门禁续验核对原 11 批明细、测试树和 `closeout-run-audit.json` 后更正；没有删除或新增历史执行。历史失败未删除；名字含 verified/acceptance 的中间包仍是失败。最终组合闭环只在完整摘要 `330643…` 对应的 1 方法/2 次通过，不能称 18 个方法都在该版本通过。

计划中的 closeout-regression 在编译源码身份检查阶段退出 1，没有 xcresult、没有启动 QA，不是测试断言失败或通过。源码稳定后仍需完整 QA 重新编译并运行 WorkspaceNotesLifecycleTests、标记反例、搜索焦点、标题失败/取消、全屏这 9 个方法/9 次回归；已通过的最终组合用例不因纯文档编辑重跑，相关源码再变则重新评估。

相关严格 SwiftLint、静态 quality_gate（含 262 项脚本回归）、check_workflow 和差异检查已执行，收尾证据为 closeout-lint.log、closeout-static.json、closeout-workflow.log。使用 static profile 配独立完整 QA，避免 auto profile 启动普通宿主。closeout-composition-end-prepare 是最终固定源码的完整 QA build-for-testing 通过。

最近正常 `./scripts/build.sh` Debug/静态验签通过，但其请求/持锁/结束清单都是 `6d974e6192a5d67b6a1b1c723b975c0c9443567b7046462f172630d725bf0f3b`，早于最终组合会话/重新呈现修复，**不作为最终实现的正常 Debug 通过证据**。本地只读代理在原 build.sh 获锁后记录源码再调用原 xcodebuild，没有换锁或改签名。最终稳定源码的正常 Debug 门禁仍缺失。

#### 外观、真实交互与指定复核

fullScreenRoundTripPreservesHeaderAndSearchIdentity() 收到真实 NSWindow 全屏进入/退出通知，核对 styleMask、单行高度、主区搜索居中、操作不重叠、同一输入对象与查询保留。它是 API 驱动的系统全屏往返，不是人工操作；完整材料/安全区域视觉仍无实际合成截图证明。

composedWindowAndScrollStates(scheme:) 在浅/深色、默认/原最小尺寸检查可见原生关闭/最小化/缩放按钮、滚动位置及固定顶栏几何。12 次截图前置检查均报告已有屏幕捕获权限缺失，未申请权限、未启动 screencapture，composed-images 无图；不能把几何通过写成截图通过。原 before-images/after-images 均为缓存图，侧栏子图只是子视图渲染，不能证明完整系统窗口合成。程序化顶部/下移/返回与旧羽化证据保留，没有真实触控板连续观察，也没有拼接按钮或制造截图。

真实窗口拖动、控件区域不误拖动、真实中文输入法和人工窗口材料观察仍未执行。桌面控制入口继续暂停，未改锁屏、安全或显示设置，未提高最小窗口尺寸。需具备获准的单窗截图入口，以及完整隔离 QA 的人工操作条件。

工具清单仍无 Cursor verifier，**指定复核未执行**。没有安装、认证、改配置或用其他代理替代；只读历史进程调查不算指定复核。材料集中在本节、原架构/组件目录和实际差异：单行/主区中心、动作顺序与身份、空间收起与手动恢复、备注去重/失败重试/记录 `.id`、组合草稿/焦点、ScrollScope 归属清理、所有失败及进程未知项。复核应返回文件/符号/行号、触发条件、实际影响、已有证据关系和未覆盖项，不预设正确或要求改代码。

剩余门禁：稳定当前源码的相关回归与正常 Debug/验签、指定 Cursor 复核、真实输入法/拖动、完整系统窗口合成及必要人工观察。历史 PID 来源和副作用不可恢复部分永久保留未知，不用未来通过追认。本轮停止在验收收尾，不创建下一阶段；没有安装、启动正常应用、提交、推送或发布。

### 工作台最终门禁续验（2026-10-09）

**当前源码尚未完成原 9 项相关回归及正常 Debug/验签，整体 partial。** 本续轮未改生产实现、Swift 测试、runner 或其他任务的暂存区；只整理原证据并更新本记录。原锁屏失败、修复前失败、历史 PID 8295 来源/副作用未知和指定复核缺口继续保留。

#### 源码对应与影响范围

沿原 `run.py.snapshot()` 口径：Git 已跟踪与非忽略未跟踪的 `AreaChain/`、`AreaChainTests/`、`AreaChain.xcodeproj/`、`Config/`、`scripts/` 文件逐项 SHA-256，再对 `json.dumps(mapping, sort_keys=True)` 求 SHA-256。文档与忽略目录下的证据/runner 不纳入该摘要；runner 另记文件摘要。个人签名配置没有修改。

- 最后组合闭环受测身份经原前后清单交叉验证为 `33064380f88e7602ef563d750fffb1af50801c68c90ff1903d1ac77604156f1d`，未使用提示词里的重复转录值。
- 本续轮初始身份为 `e95e43f5f1b8ae7413b0bbfa1b36d07f3cf79b88b693dc689771aad9e43a1e7b`（1,390 文件），相对受测版 47 路径变化，相对原交接快照 4 路径变化。
- 完整 QA 编译的请求、获锁、结束清单一致，身份为 `1578098f2947a23fa325da1d4dcac6d591b3186f68ad668be807277e2bd3e09c`。新增的两个搜索测试已在这次编译输入内；早期尚未看到日志时的“仍待锁/可能拒绝”观察不替代最终 runner 结果。
- 15:17:22（Asia/Shanghai）再次采集身份为 `f1605c1b74b7fda5158d571c6e60f2169e804a46d6d63efc53aa41bb9b2cc04f`（1,392 文件）。相比最后受测版 51 路径变化，相比原交接快照 11 路径变化；源码仍可能被其他任务继续修改，这不是发行身份。
- 静态检查后又观察到两个搜索测试继续编辑；续轮最终清单为 `2d0c61dad39c78aaefab7336bff06639ace2a10cae4cf3285d91488991b94260`（1,392 文件），采集时间见 `final-gates-handoff.json`。原15:17清单保留于 `final-gates-post-prepare-source.json`；最终清单仍有51个相对受测版变化路径，原工作台八文件不变，没有将此次瞬时摘要当作已受测源码。
- QA 编译结束后 6 个输入变化：`CommandRoutineCreateFacts.swift`、`CommandSubtaskFacts.swift`、`CommandPlanDependencyTests.swift`、`UnifiedSearchMultiPlanOutputRecoveryTests.swift`、`scripts/check_workflow.py`、`scripts/tests/test_check_workflow.py`。前四个属于实际应用/测试输入，不能只按文档变化处理。尚未启动 9 项回归，不能把该编译产物当作当前源码。

| 分类 | 核对结果与复用边界 |
|---|---|
| 工作台公共框架、共享输入/主题、详情生命周期 | 原收尾 8 个 Swift 文件及既有 Workspace、Theme、App 文件与最后受测清单一致，继续复用原搜索身份、EditDrafts、详情焦点标记与 ScrollScope；未新增业务入口 |
| 并发业务与共享服务 | 创建输出、Plan/Run、搜索多项计划、适配器、任务/子任务/习惯服务及文案变化；其中部分服务是完整目标的共享编译输入，未将这些改动归为本任务修复 |
| 测试与检查器 | 新增/修改统一搜索、领域和服务测试，以及工作流检查器/反例；原工作台测试未变 |
| runner | 当前为原记录所述自包含实现，历史组合批次仍引用旧 runner 摘要；不把旧生命周期摘要当作当前 runner 身份。本续轮只读核对后重新运行原 11 项隔离检查，通过 |
| 文档 | 不计入原源码摘要。现有工作区/暂存区差异包含并发文档，本轮只改本节及历史累计数笔误 |

完整路径、摘要和限制在 `final-gates-source-comparison.json`、`final-gates-handoff-source.json`、`final-gates-handoff.json`。历史清单只有逐文件哈希，没有全部旧源码正文；已读取当前相关实现和 Git 差异，但 Git 差异的基线是 HEAD/暂存区，不能冒充最后受测版的逐行差异。无法还原的旧正文差异明确保留限制。

#### 原 9 项的准确范围

原文明确指定 WorkspaceNotesLifecycleTests 全部五方法，再加标记反例、搜索焦点、标题失败/取消与全屏各一方法；已与 `closeout-acceptance-command.json`、acceptance/verified 测试树和当前方法声明核对。原 `closeout-regression` 在写命令文件前已退出，未留下独立命令文件；本次恢复依据与精确筛选在 `final-gates-plan.json`，没有用其他测试替换，也没有把组合闭环的双参数方法塞入这九项。

表内所有项目本续轮均为**阻断、未运行**；需要重跑的共同原因是最终收起/重新呈现修复后的同一当前源码尚无该组完整证据。上一轮最后通过只证明表中历史批次，不能证明当前源码。

| 完整测试标识 | 验证行为 | 上一轮最后状态 | 本次需要运行的原因 | 解锁桌面/前台焦点 |
|---|---|---|---|---|
| `AreaChainTests/WorkspaceNotesLifecycleTests/successfulBlurAndUnmountPublishOnce()` | 同草稿失焦与卸载只保存/发布一次 | acceptance 通过 | 最终生命周期修复后补回归 | 是 |
| `AreaChainTests/WorkspaceNotesLifecycleTests/failedBlurCanRetryAndNewEditingCanSave()` | 失败零发布、显式重试、新编辑可再保存 | acceptance 通过 | 同上，保留失败重试要求 | 是 |
| `AreaChainTests/WorkspaceNotesLifecycleTests/failedDraftSurvivesUnmountAndDifferentRecordWithSameText()` | 失败草稿跨卸载保留，同文本不跨记录去重 | acceptance 通过 | 同上，核对记录隔离 | 是 |
| `AreaChainTests/WorkspaceNotesLifecycleTests/collapseDuringMarkedNotesRetainsDraftWithoutSaving()` | 合成 marked text 收起保留草稿且不保存 | acceptance 通过 | 最终组合会话处理后补回归 | 是 |
| `AreaChainTests/WorkspaceNotesLifecycleTests/externalUpdateDoesNotOverwriteUnsavedDraft()` | 外部值不覆盖本地未保存草稿 | acceptance 通过 | 最终草稿生命周期后补回归 | 是 |
| `AreaChainTests/WorkspaceInspectorSizingTests/unattachedMeasurementCannotReplaceWindowMarker()` | 离屏测量不替换真实窗口标记 | acceptance 通过 | 核对实际标记归属 | 否，仍随本组串行 |
| `AreaChainTests/WorkspaceInspectorSizingTests/searchKeepsFocusAcrossSidebarResizeInspectorCollapseAndBodyReplacement()` | 搜索唯一身份、焦点与文本跨缩放/详情收起/内容替换保留 | acceptance 通过 | 最终隐藏焦点转移后补回归 | 是 |
| `AreaChainTests/WorkspaceHeaderInteractionTests/titleDraftSurvivesFailedSaveAndUnmountWithoutExtraSubmission()` | 标题失败保留、重挂无额外提交、Esc 回滚 | acceptance 通过 | 最终标题焦点与呈现修复后补回归 | 是 |
| `AreaChainTests/WorkspaceWindowLifecycleTests/fullScreenRoundTripPreservesHeaderAndSearchIdentity()` | 系统全屏通知、顶栏几何、搜索身份/文本往返保持 | verified 通过 | 最终工作台实现补系统窗口回归 | 是 |

计划范围 9 个唯一方法/9 次执行，0 个参数化方法；本续轮实际原生执行 0 方法/0 次，重跑 0 次，无新 xcresult。不是 9 次通过，也不是 9 项断言失败。原历史累计经测试树与审计核对为 18 唯一方法、82 次含诊断/重跑执行，详见 `final-gates-historical-count-check.json`；不计为本续轮覆盖。

#### 实际命令与门禁

- `python3 -B build/workspace-shell-evidence/test_run.py -v`：退出 0，11 项通过；日志 `final-gates-runner-tests.log`。覆盖原成功/失败/超时/中断和精确进程身份清理；没有新增或弱化断言。
- `python3 -B build/workspace-shell-evidence/run.py final-gates-prepare build`：退出 0，沿原 `build/.build.lock`、最多900秒等待、完整 AreaChain Debug build-for-testing、独立 `com.areachain.workspace-shell-qa` / `build/WorkspaceShellQA`、六项真实钥匙串变量清除。展开命令、日志、前后源码和生命周期见 `final-gates-prepare-*` / `final-gates-prepare.log`；产物为 `build/WorkspaceShellQA/Build/Products/Debug/AreaChain.app`。这只是上述 `1578098f…` 的 QA 编译，没有执行原生测试或单独 QA 验签。
- `./scripts/build.sh check-signing`：退出 0，当前配置为 development，输出 `final-gates-signing-settings.json`；仅核对配置，未改个人身份，不等于产物静态验签。
- `python3 -B scripts/check_workflow.py`、`git diff --check`、`git diff --cached --check`：退出0；`python3 -B scripts/quality_gate.py --profile static` 退出0，含当前263项脚本回归。日志为 `final-gates-workflow.log`、`final-gates-static.log`。期间变化的两个并发 Swift 测试没有被原生执行，静态门禁不为其运行行为背书；本轮未修改检查器。最终仅补写本文后重跑文档/工作流与差异检查。
- 当前源码的正常 `./scripts/build.sh` **未运行**，正常 Debug 产物/日志/验签通过证据均未新增。编译后的相关输入又变化，已请求用户协调上述五个源码根目录约5–8分钟稳定窗口；尚未收到确认，因此未重新排程，不通过重复编译碰运气。文档可继续编辑。原有一次有依据的重排额度尚未使用，不能从构建锁推导源码锁定。

本续轮没有启动任何 QA 实例，运行前后本任务可执行路径进程盘点为空；没有新残留或补发结束信号。历史 PID 8295 的来源和副作用仍未知，不从本续轮零实例推导历史安全，也未继续无边界追查。

#### 人工、外观与指定复核

只读 `CGPreflightScreenCaptureAccess()` 在本轮命令进程返回 true，桌面 sessionOnConsole=1、screenLocked=false；与先前权限观察不同，但命令进程权限不能替代 QA 宿主自身的预检。本轮尚未在对应当前源码启动 QA，未运行截图、未取得系统合成图、未改权限或尝试其他截图入口。原缓存图仍只证明视图缓存，不证明完整系统窗口材质/按钮合成。

真实中文输入法（搜索、标题、备注）、未确认组合文本跨实际收起的精确时序、窗口拖动/控件不误拖动、人工材料观察均**未运行**。当前没有“已准备完毕且对应当前源码”的有界人工窗口，未要求用户在窗口前等待，也未启动 Gallery。待源码窗口具备并完成隔离产物核验后，才可准备有界人工入口，再一次确认用户当时是否方便；未收到人工结果不写作用户已通过或明确无法配合。合成文字可统一为“合成搜索/合成标题/合成备注”，必须记录鼠标/拖动是否先正常确认了候选；已确认文本恢复不能顶替未确认组合文本恢复。

当前可调用工具目录无指定 Cursor verifier，**未执行指定只读复核**，未安装、认证、更换模型/权限或用其他代理替代。待审材料仍为本节、原实际差异/源码清单、原失败和本轮命令证据；检查范围保持字体回退比较的敏感性、测量标记隔离、隐藏焦点、草稿唯一所有者、失败重试与记录去重、选择/检查日与手动重开规则、ScrollScope 所有权/清理。材料可供复核不等于复核通过。

**交接条件**：先协调源码稳定窗口，再进行准确九项与同源码正常 Debug/验签；人工入口、单窗合成图和指定复核分别补证。当前未修复生产代码，未提交、推送、安装、发布或启动正常应用，未给其他线程发送指令或终止其工作；整体继续 partial，不新增产品阶段。
