# 共享组件与复用目录

## 第十阶段 C：Dashboard 外层垂直滚动接入（partial）

[DashboardView](../AreaChain/Features/Dashboard/DashboardView.swift) 的实际外层 ScrollView 在原 frame 之前调用 `daybookScroll(featherEdges: false)`：选择原单参数隐藏系统指示器策略，明确不新增羽化。DaybookPage、VStack、四分区间距、投影、数据读取和导航保持；公共装配、Configurator、目标搜索、拆卸及绘制未改。

DashboardTrendSection 与 DashboardHeatmapSection 的横向 ScrollView 继续各自 `showsIndicators: false`，不接公共浮层；这是明确保留的不同入口。预期视觉变化仅为外层指示器统一，不能将指示器差异解释为布局可改变。

[DashboardScrollTests](../AreaChainTests/Features/DashboardScrollTests.swift) 与[合成宿主](../AreaChainTests/Features/DashboardScrollTestSupport.swift) 直接挂生产页面，复用 SettingsButtonTestSupport、CalendarSpanTestSupport 状态恢复和原 CGEvent 滚动事件方式。按生产日期按钮的真实纵向区域及 NSScrollView 父链定位两个横层和共同外层，不取第一个滚动对象。合成数据相对测试今日，无数据与有数据分开。

**续验状态**：完整正常测试目标编译阻断已解除，原设置合成方法实际通过且未被本轮修改。生产归属严格证实为外层 1／趋势 0／热力图 0，系统指示器策略和零羽化观察器通过；更新、resize、重开、两横层真实溢出独立滚动、外层顶中底/最后活动可达、滑块合成窗口事件和安全日期导航已验。有效 Dashboard/公共回归为32方法／53次通过，重跑不累加。最终1200×900大视口与正常/窄矮矩阵同条件补验通过，72对完整缓存图等尺寸、180条几何完全一致；预期指示器与少数悬停高亮差异保留。第二处漏接按归属及相关自动回归证据标为已处理，人工、窗口合成器和指定复核缺口保留；完整证据见[工程记录](engineering.md#第十阶段-cdashboard-外层垂直滚动接入partial)。生产仍只有原一行，不修改公共滚动或历史问题。


## 第十阶段 B：四象限标题预览纯装饰接入

[QuadrantTitlePreview](../AreaChain/Features/Quadrant/QuadrantTitleLayout.swift) 仅将背景与描边替换为既有 `daybookSurface(floating: .rowBubble(isHovered: false, isCopied: false))`，没有公共预设或参数扩展。small/continuous、页面底色、仅背景形状 floating 阴影、border.default 的 90%／0.8pt 居中描边保持；悬停与复制反馈不传给 rowBubble。公共装饰描边继续不参与命中，原 contentShape 接收事件，不扩大到圆角外侧或阴影。

水平 8／垂直 6pt padding、最大宽度 260 和左对齐、原圆角 contentShape、onHover / onTapGesture / task 顺序均保持。摘要、showsHint、原文字颜色与 1200ms 反馈 Task 仍归本组件；没有图标、箭头、光标、动画或关闭能力。它不替换为 RowTitleBubble，两者的正文、提示及定位契约不同。

QuadrantTitleOverflow 保留六行、360 字符预览探测、80 字符溢出探测及 isPartial 算法。QuadrantPreviewOverlay 保留零尺寸锚点、offset、260pt 宽度、上下 6pt 与水平限制、`quadrant.titleBubble.<UUID>` 及悬停回调；显示 excerpt，点击仍调用无参 onCopy，再由 overlay 转交 preview.title 全文。Void 回调与“已复制”只证明反馈和转交，不证明系统剪贴板成功。

[直接呈现](../AreaChainTests/Features/QuadrantPreviewSurfaceTests.swift)、[原生事件](../AreaChainTests/Features/QuadrantPreviewInteractionTests.swift)、[生产 overlay](../AreaChainTests/Features/QuadrantPreviewOverlayTests.swift) 和 [合成宿主](../AreaChainTests/Features/QuadrantPreviewTestSupport.swift) 沿 SettingsButtonTestSupport、SurfaceEventTestSupport 与 PrivacyQA。旧代码仅复用 OriginalRowBubbleSurface 的冻结默认装饰，不复制完整预览业务。原 [QuadrantLayoutTests](../AreaChainTests/Features/QuadrantLayoutTests.swift) 补页面安全显隐/定位及模型、选择和检查器不变断言；默认 NSPasteboard 路径不点击。原检查器补静态调用窄守卫，只有声明、注释调用或动态 isCopied 均不能作为接入通过。

本轮实际证据及未验项见[工程记录](engineering.md#第十阶段-b四象限标题预览纯装饰接入)。下一处确定漏接仍是 [DashboardView 外层 ScrollView](../AreaChain/Features/Dashboard/DashboardView.swift)；本轮不接入，不修复历史滚动归属、羽化、手记辅助树、气泡及复制运行问题。

## 第九阶段 E：两处标签色点接入

[WorkspaceSidebarView.tagRow](../AreaChain/Features/Workspace/WorkspaceSidebarView.swift) 与 [TagManagementPage.tagRow](../AreaChain/Features/Workspace/TagManagementPage.swift) 直接复用既有 [DaybookStatusDot(color:size:)](../AreaChain/Theme/DaybookChip.swift)。公共组件未改，没有新增包装、状态、配置或颜色算法。

| 消费者 | 保留的呈现与责任 |
|---|---|
| 侧栏标签行 | 显式 8pt；原 `DaybookPalette.tagMark(name:token:)`；`accessibilityHidden(true)`。标题、整行按钮/矩形命中、选中背景与导航不变。原 `Catalog.liveTaskTags` 继续排除手记预设分类。 |
| 标签管理行 | 显式 10pt；同一原颜色来源；保留 `colorTitle(tag.resolvedColorToken)` 及 `.accessibilityElement(children: .combine)`。预设色仍按名称优先解析；颜色辅助名仍表达原 resolvedColorToken，两者不强行合并。选择、双击改名、计数、菜单和保存留在原页面。 |

测试直接挂载生产消费者，复用 SettingsButtonTestSupport / SystemPageHost、原生事件及原图像支持；[TagDotConsumerTests](../AreaChainTests/Features/TagDotConsumerTests.swift) 与 [合成支持](../AreaChainTests/Features/TagDotTestSupport.swift) 补双语/浅深色、两档宽度、六令牌/回退、实际直径、完整行与原生交互。管理行按原合并节点检查颜色名一次、标题和计数，不要求暴露独立色点。原 WorkspaceRenderingTests、WorkspaceMenuConsumerTests 和标签目录/仓储测试补直接消费者回归；前后证据、过程失败和缺口见[工程记录](engineering.md#第九阶段-e两处标签色点接入)。不新增全局检查器规则、公共框架、展示应用或重复复核。

第九阶段原登记四类发现的当前接入状态：昨日静态卡片已在 B 接入，筛选浮层已在 C 接入，连击指标列已在 D 局部复用，两处标签色点已在 E 接入。下文 B/C/D 的待办描述是当时记录。接入清单收口不等于全应用最终验收：原生加载器、不同数字口径、标签胶囊与空态的合理差异保留；滚动归属、羽化、手记辅助树、下方气泡与复制等历史运行问题，以及既有指定复核/人工缺口继续保留。可进入第十阶段的复用清单和最终验收规划，本轮到 E 停止，不执行第十阶段。

## 第九阶段 D：连击指标列复用

[TaskDetailScheduleSection.swift](../AreaChain/Features/Workspace/TaskDetailScheduleSection.swift) 的 `TaskDetailStreakCard` 仅在 Feature 内共用私有 `streakMetricColumn(title:systemImage:value:)`。当前列传 `drawer.streak.current` / `flame.fill` / `currentStreak`，最佳列传 `drawer.streak.best` / `trophy.fill` / `bestStreak`；标题为 `LocalizedStringKey`，数值沿原 `Text` 整数插值，单位仍是 `drawer.streak.days`。不使用 DaybookCount，不增加动画、镜像状态、计算或公共 API。

列仍为左对齐 VStack、spacing2、无限宽左对齐；标题 micro/次要色，数值行 spacing4，图标 body bold/pending，数字 16pt bold rounded/主要色，单位 badge/次要色。两列之间 spacing12、28pt 分隔线，卡片标题、状态/日期行、padding10 与原 `.card` 自动悬停表面均保持。新入口不读取时钟、模型、仓储或导航，也不保存或回调。

直接消费者仍为 [RoutineHabitSectionView](../AreaChain/Features/Workspace/TaskDetailSections.swift)，继续接收原检查器传入的 `StreakResult`；配置、检查日和暂停→跳过→完成→非计划日→待打卡的优先级未改。验证沿 [StreakCardRenderingTests](../AreaChainTests/Features/StreakCardRenderingTests.swift)、[合成装配支持](../AreaChainTests/Features/StreakCardTestSupport.swift)、原 StreakInspectionStatusTests 与五状态构造测试，直接挂载生产卡片建立前后基线，不复制业务卡片。

长数字原本按环境分组并完整换行，两列行数不同可使标题高低不同；本轮只保持原表现。结果与既有验收缺口见[工程记录](engineering.md#第九阶段-d连击指标列复用)。D 当时登记的两处标签色点漏接已由上节 E 收口；D 本身没有新增全局指标组件或展示应用。

## 第九阶段 C：菜单栏筛选浮层外壳

[DaybookSurface.swift](../AreaChain/Theme/DaybookSurface.swift) 的 `DaybookFloatingSurface.filterFlyout` 沿既有 `daybookSurface(floating:isPresented:)` 装配 regular/continuous、fill.page、border.default 的 65%／0.8pt `strokeBorder` 内描边与仅背景形状的 floating 阴影。装饰描边不参与命中；不增加布局、裁切、contentShape、状态、悬停、事件或任意颜色参数。其他浮层仍用各自原居中 `stroke`、透明度、宽度和阴影；静态卡片及 row/card/panel/banner 默认不变，isPresented 只开关装饰并保留内容身份。

仅 [MenuBarFilterFlyout.swift](../AreaChain/Features/MenuBar/MenuBarFilterFlyout.swift) 的 `level1CategoryCard`、`level2OptionCard` 接入。任务 110/175pt 两级，手记 175pt 标签单级；4pt 级间距、3pt 外 padding、内容 padding4、二级 maxHeight165 和隐藏滚动指示器不变。原组件持有 externalCategory/internalCategory 选择、220ms dismissTask、选项生成与计数，BoardFilters 保留分 tab 写回，选项 applied/cleared 后仍走一次原 onDismiss。状态、悬停、滚动、清除和关闭均不下沉公共层。

[生产宿主](../AreaChain/Features/MenuBar/MenuBarPopoverView+Drawer.swift) 仅核对：左12pt、底44pt、zIndex30，原 FilterDrawerScrim 外部关闭和底栏穿透、按钮再次切换、筛选优先于帮助及 Escape 均不改。验证沿 [生产卡片](../AreaChainTests/Features/MenuBarFilterConsumerTests.swift)、[精确选择与原生悬停](../AreaChainTests/Features/MenuBarFilterInteractionTests.swift)、[宿主](../AreaChainTests/Features/MenuBarFilterHostTests.swift) 和原 DaybookFloatingSurfaceTests、MenuBarHelpKeyboardTests、BoardFilterBarTests；合成准备见 [测试支持](../AreaChainTests/Features/MenuBarFilterTestSupport.swift)。原 ControlsPreview 展示公共预设及生产两级/单级。实际结果和历史缺口见[工程记录](engineering.md#第九阶段-c菜单栏筛选浮层外壳)。连击指标、标签色点留待后续；不借此迁移统一搜索或修复原滚动/羽化/手记 AX/下方气泡/复制问题。

## 第九阶段 B：昨日事项静态卡片外壳

[DaybookSurface.swift](../AreaChain/Theme/DaybookSurface.swift) 的 `daybookStaticCardSurface()` 只绘制 medium/continuous 圆角、cardSurface 底色和 border.subtle 的 0.8pt strokeBorder 内描边。背景与描边不参与命中；不增加布局、裁切、状态、悬停、选中、阴影、动画或任意颜色参数。原 `daybookSurface(.card)` 仍自动跟踪悬停及外部选择；row/card/panel/banner 和 floating 全部默认接口保持。

仅 [TasksPage+Sections.swift](../AreaChain/Features/Tasks/TasksPage+Sections.swift) 的 `yesterdaySection` / `centeredYesterdaySection` 接入，分别保留 padding 8/10、标题原边距、外水平 1/4；普通分支底部 8 和 transition 不变。原 TasksPage 决定展开、空态及今日为空时的分支选择，原行决定悬停、检查目标/检查日、完成与跳过；标题、计数与 moveAllYesterdayTodosToToday 留在 Feature。全部移动仍只遍历昨日待办、逐项调用原移动入口，不变为批量原子事务。

验证复用 DaybookSurfaceTests、DaybookFloatingSurfaceTests、TasksPageEmptyStateTests、DayBoardPageProjectionTests、TaskListScrollTests 和 MonthGridMoveRepository / ModelChanges 失败设施；新增 [公共静态表面测试](../AreaChainTests/Theme/DaybookStaticCardTests.swift)、[生产布局测试](../AreaChainTests/Features/YesterdayCardConsumerTests.swift)、[生产操作测试](../AreaChainTests/Features/YesterdayCardActionTests.swift)，合成输入沿 [原生宿主支持](../AreaChainTests/Features/YesterdayCardTestSupport.swift)。修改前直接挂生产 TasksPage 经原昨日入口取基线，冻结仅限装饰。实际证据与未验项见[工程记录](engineering.md#第九阶段-b昨日事项静态卡片外壳)。

第九阶段其他三类发现继续登记：筛选浮层、连击指标、标签色点；本轮均不接入。第八阶段手记 AX、下方气泡保留、瞬态悬停、滚动归属与羽化等历史缺口仍保留，不由本轮外壳结论覆盖。

## 第八阶段 F：标题与备注气泡动态外壳

[DaybookSurface.swift](../AreaChain/Theme/DaybookSurface.swift) 的 `DaybookFloatingSurface.rowBubble(isHovered:isCopied:)` 沿原 `daybookSurface(floating:isPresented:)` 接收纯呈现值：复制反馈 `accent.base.opacity(0.7)` 优先于悬停 `cardBorderHover`，普通 `border.default.opacity(0.9)`。small/continuous、页面底色、0.8pt 居中 stroke 与仅背景形状的 floating 阴影集中维护；描边沿 E 修复一 `allowsHitTesting(false)`，不增加布局、裁切、contentShape、事件或本地状态。原五预设及旧 surface API 保持兼容。

| 接入入口 | 留在消费者的责任 |
|---|---|
| [RowTitleBubble](../AreaChain/Theme/DaybookRowBubbles.swift) | 水平 8/垂直 5.5 padding、最大宽度 260、多行排版、圆角 contentShape、growsUpward 兼容参数 |
| 同文件 RowNoteBubble.noteCardContent | 水平 9/垂直 7 padding、宽度 210、八行正文/行距/headerTitleKey；箭头在装饰外，方向、5pt 高度、偏移与 arrowPadding 不动 |
| 两气泡共同保留 | 原 onCopy/onHover、光标 push/pop/卸载、isHovered/isCopied、Task、1200ms 复位及动画、compositingGroup/zIndex；备注外层 Rectangle 命中及 fixedSize 不动 |

三处直接消费者仍是 DiarySummaryRow+Bubbles、LiveComposerPreviewHeader、LiveDiaryComposerPreview。截断、显隐、候选互斥、敏感投影、上下位置及偏移留在原宿主；不新增生产消费者或复制替身。Void onCopy 只证明调用发生，反馈不能证明系统复制成功。

验证沿原 PrivacyQA、TaskRowBubbleTests、DaybookFloatingSurfaceTests、LivePreviewSurfaceTests / LivePreviewCompositionTests、OverlaySurfaceConsumerTests 及手记行宿主；新增 [动态外壳](../AreaChainTests/Theme/RowBubbleSurfaceTests.swift)、[直接原生气泡](../AreaChainTests/Theme/RowBubbleInteractionTests.swift)、[消费者](../AreaChainTests/Theme/RowBubbleConsumerTests.swift) 和[冻结装饰/合成支持](../AreaChainTests/Theme/RowBubbleTestSupport.swift)。原 ControlsPreview / DaybookFloatingSurfaceSamples 展示四种状态及外部箭头。原生点击只在直接气泡的无副作用回调上计数；无安全注入点的消费者不点击复制。实际结果与缺口见[工程记录](engineering.md#第八阶段-f标题与备注气泡动态外壳)。

第八阶段原登记的标题/备注外壳与两处边框映射已接入；C/D/E 的未迁移描述是历史状态。两种点击形状、箭头、内容高度及反馈归属是合理差异；B 的滚动归属、D 的复制按钮辅助树、已有悬停/窗口边缘与定位属于运行问题，不能当作本轮遗漏继续修复。这里不宣称全仓库不存在其他未审计重复。


## 普通设置原生提交（3A-2）

- [UnifiedSearchSettingEditing](../AreaChain/Features/Search/UnifiedSearchSettingEditing.swift) 的 `requestOperationSubmit` 扩展原 Controller；可选显式注入 LocalSettingCommandAdapter，点击与原生 ⌘Return 共用入口。prepare 只在开始/恢复/编辑或明确重新读取时采集缺失基线，发布新 buffer；参数、计划及运行仍唯一属于 Coordinator。
- [UnifiedSearchSettingSubmission](../AreaChain/Features/Search/UnifiedSearchSettingSubmission.swift) 在原 OperationPreview 中呈现实际回执、原值/当前/拟修改值及受控冲突操作；ParameterField、PlanList 共用值展示，按钮复用 UnifiedSearchPlanButton。原 ReadSession 继续负责撤显示，服务最后写入门禁也核对显式传入的同一 ReadSession。
- [LocalSettingCommandAdapter](../AreaChain/Services/LocalSettingCommandAdapter.swift) 增加活动单草稿 readiness、实际 report 投影和 canReturnToPlan / canRetryPresentation；复用原严格映射、受限返回和 Run 资格，不复制执行状态机。prepare 支持尚未填写值的普通设置，真实提交仍严格要求完整参数。
- 消费者为原标准/紧凑隔离宿主及 UnifiedSearchSetting 四套测试；旧参数、计划、服务与设置页继续回归。只装配 language / appearance / truncation / captureSource，多项和执行后撤销关闭；生产搜索未启用。完整接口、运行事实保留和实际证据见[权威 §9.56](unified-search-commands.md#956-阶段-3a-2四类普通设置的原生提交冲突和反馈)。

## 普通设置单项指令适配（3A-1B）

- [LocalSettingCommandAdapter](../AreaChain/Services/LocalSettingCommandAdapter.swift) 显式注入原 AppPreferences 与 CommandHandoffCoordinator；prepare / readiness / submit / execute 只开放四项普通设置。默认 preferences 为 nil，目录及生产搜索仍关闭；没有可编辑偏好副本或第二套计划。
- [LocalSettingCommandMapping](../AreaChain/Services/LocalSettingCommandMapping.swift) 复用目录、参数/目标校验，严格映射 choice 与 Bool；[CommandPreferenceBaseline](../AreaChain/Domain/CommandPreferenceEvidence.swift) 保存真实标量来源、原始键、内存/存储值和逐字段修订，随原草稿/计划迁移，实际签发登记仍由适配器核验。
- Coordinator 的 claimPreferenceInvocation / completePreferenceInvocation 在调用前占用原 operation/attempt，完成只归原 run；Run 增加 noChange、preferenceWrite、preferencePresentation 事实。未提交单项通过 returnUnsubmittedToPlan 返回原计划身份，rereadConflict / resolveConflict 绑定一次证据；未知/已提交不能返回重放，retryPresentation 不写偏好。
- 原设置页继续四 Binding 即时保存。消费者是五套 LocalSettingCommand 服务测试与共享隔离夹具，旧协议、偏好、事件与设置分节回归；没有生产 UI 装配。结果映射、验证及多项事务前置只维护在[权威 §9.55](unified-search-commands.md#955-阶段-3a-1b普通设置单项真实适配与隔离验证)。

## 第八阶段 E：标签详情与语法帮助卡外壳

**E 修复二**：MenuBarPopoverView 将原遮罩和卡片组织为根 ZStack 的同一 `zIndex(20)` 层，层内卡片为 1、遮罩为默认 0；原筛选仍为 30。卡片空白由宿主局部点击区域接住，外部关闭不穿透；尺寸、92pt 偏移、原裁切与 transition 保留。原 setupTabKeyMonitor 限定有效可见宿主，先走筛选，再由内部 dismissSyntaxHelpForEscape 处理无核心修饰键且无 marked text 的 Escape；只改变唯一 showingSyntaxHelp，卸载移除监视器并清宿主引用。输入、草稿与原回调不变，帮助关闭后恢复原输入路由。回归沿原 [帮助测试](../AreaChainTests/Features/MenuBarHelpSurfaceTests.swift) 及宿主内的 [键盘回归](../AreaChainTests/Features/MenuBarHelpKeyboardTests.swift)、[鼠标回归](../AreaChainTests/Features/MenuBarHelpPointerTests.swift)；实际结果见[工程补记](engineering.md#e-修复二语法帮助遮罩与-escape-路由)。

**E 修复一（2026-10-04）**：公共浮层装饰性描边不参与命中，内容与宿主继续负责交互。唯一生产修复是在 `DaybookFloatingSurfaceModifier.border` 的 stroke 视图上设置 `allowsHitTesting(false)`，同时覆盖五预设；背景命中、内容真实点击范围、isPresented 身份、绘制顺序及原 row/card/panel/banner 不变。冻结外壳继续记录旧 medium 故障，公共外壳改为严格成功与边界次数断言，不再要求故障路径点击轨迹相同。直接帮助卡的鼠标证据不代表生产帮助遮罩或 Escape 已修复；下一轮只处理宿主层级和键盘路由。实际回归、静态对照及缺口见[工程补记](engineering.md#e-修复一公共浮层描边不拦截内容点击)。

复用 [DaybookSurface.swift](../AreaChain/Theme/DaybookSurface.swift) 的 `DaybookFloatingSurface` / `daybookSurface(floating:isPresented:)`，两个明确预设共享页面底色、border.default 的 **60% / 0.8pt 居中 stroke**（边缘内外各 0.4pt）及背景形状阴影。

| 预设与消费者 | 保留的呈现和责任 |
|---|---|
| `tagDetail`：[LiveComposerPreviewHeader.tagDetailBubble](../AreaChain/Theme/LiveComposerPreviewHeader.swift) | regular/continuous；padding 7、宽 140、列表上限 120、行样式/指示器、位置与两层 transition 原样。原 canFit、多标签、候选及标题悬停条件仍由消费者决定。 |
| `syntaxHelp`：[SyntaxExpandableCard](../AreaChain/Theme/SyntaxHelpCard.swift) | medium/continuous；宽 popoverWidth - 24；原 clipShape 仍在整个浮层装饰之后，实际帮助卡会裁掉外部阴影，不能与公共预设完整外缘要求混为一谈。 |

公共层不增加 padding/frame/clip/mask/contentShape、状态、事件或任意颜色配置。suggestions / readOnly / smallBackground 保留 70% / 0.7pt 和各自圆角、阴影位置；isPresented 及 row/card/panel/banner 默认兼容。标签解析、顺序、草稿、滚动、复制及主卡不归本轮外壳；帮助 isExpanded/context/onSelectToken/onSelectExample 不改。

[MenuBarPopoverView](../AreaChain/Features/MenuBar/MenuBarPopoverView.swift) 是帮助真实入口，沿原 FooterBar 打开：⌘/，暂停 syntaxOverlayHost，capture 示例替换整个草稿，search token 按原空格规则追加；单项优先示例回调，底部 nil 可选回调保持无动作。原页签、关闭、焦点、延迟和快捷键分支均保留。

原 ControlsPreview / [DaybookFloatingSurfaceSamples](../AreaChainTests/Theme/DaybookFloatingSurfaceSamples.swift) 展示新预设完整阴影与实际帮助裁切。验证扩展原 DaybookFloatingSurfaceTests / OverlaySurfaceTestSupport，并增加 [标签与直接回调刻画](../AreaChainTests/Theme/TagHelpSurfaceConsumerTests.swift) 和 [生产菜单栏入口](../AreaChainTests/Features/MenuBarHelpSurfaceTests.swift)；实际证据见[工程记录](engineering.md#第八阶段-e标签详情与语法帮助卡外壳)。下节 D 的未迁移项是历史记录，以本节更新接入状态。

下一阶段线索仅登记：[RowTitleBubble / RowNoteBubble](../AreaChain/Theme/DaybookRowBubbles.swift) 使用 small/continuous、背景阴影和 **0.8pt 动态边框**，还有复制反馈、箭头、方向与偏移。不能直接套本轮静态预设；本轮不预增动态边框配置、不迁移气泡、不修复制或滚动。

## 第八阶段 D：两类实时预览主外壳

沿 [DaybookSurface.swift](../AreaChain/Theme/DaybookSurface.swift) 的 `daybookSurface(floating:isPresented:)`，仅扩展纯呈现预设并接入两个原有主外壳；不新增生产预览消费者。下节 C 的未迁移清单是当时记录，本节更新两处主卡接入状态。

| 入口 | 接入与保留差异 |
|---|---|
| [LiveComposerPreviewHeader.mainRow](../AreaChain/Theme/LiveComposerPreviewHeader.swift) | 直接复用 `suggestions`：regular/continuous，背景阴影；水平 10pt、固定 36pt，独立及伴随候选时均绘制，保留原叠层。 |
| [LiveDiaryComposerPreview.body](../AreaChain/Theme/LiveDiaryComposerPreview.swift) | 使用 `smallBackground`：small/continuous、背景阴影；原 row 表面之后、contentShape/onHover/geometryObserver 之前装饰。`isPresented: !showsSuggestions` 同时关闭背景、边框与阴影，不分支重建内容。 |

三个 floating 预设共用页面底色、70% 边框及 0.7pt 居中 stroke；`smallBackground` 与 suggestions 共用装配，readOnly 保留原默认圆角构造及整体阴影。原 isPresented、row/card/panel/banner 兼容，不开放任意颜色或阴影参数，不加布局、裁切、命中或事件。

两预览仍是 Theme 历史业务组合；解析、敏感投影、标签/时刻、复制、关闭、悬停、气泡及定位仍归原组件。SyntaxAutocompletePopup / SyntaxOverlay / UnifiedSearchOverlay 不改组合、宿主或接线。手记仍使用 Date()，不宣称与正式列表或完整动态截图像素统一。

后续线索仅登记：任务 tagDetailBubble 为 140pt、regular/continuous、背景阴影，但边框是 **60% / 0.8pt**，不能直接套 suggestions；标题/备注沿 [DaybookRowBubbles](../AreaChain/Theme/DaybookRowBubbles.swift) 的 RowTitleBubble / RowNoteBubble：small/continuous、背景阴影，但为 0.8pt 动态边框，另有复制反馈、箭头与偏移；[SyntaxExpandableCard](../AreaChain/Theme/SyntaxHelpCard.swift) 为 medium/continuous、60% / 0.8pt、背景阴影及原 clipShape。均不能直接换成当前预设，不在本轮迁移。标签胶囊、滚动装配与 B 的历史问题保留。

验证复用 DaybookFloatingSurfaceTests、OverlaySurfaceConsumerTests / OverlaySurfaceTestSupport，新增 [生产预览基线与状态测试](../AreaChainTests/Theme/LivePreviewSurfaceTests.swift)。展示扩展原 [DaybookFloatingSurfaceSamples](../AreaChainTests/Theme/DaybookFloatingSurfaceSamples.swift) / ControlsPreview。完整证据和未验项见[工程记录](engineering.md#第八阶段-d两类实时预览主外壳)。

## 第八阶段 C：候选与只读属性浮层外壳

公共入口为 [DaybookSurface.swift](../AreaChain/Theme/DaybookSurface.swift) 的 `daybookSurface(floating:isPresented:)` / `DaybookFloatingSurface`，仅负责装配绘制，不建立平行 Popover 框架。

| 表现 | 几何与阴影 | 已迁移消费者 |
|---|---|---|
| `suggestions` | regular / continuous；floating 仅施加背景形状 | [SyntaxAutocompletePopup](../AreaChain/Theme/SyntaxAutocompleteView.swift) |
| `readOnly` | small / 原 RoundedRectangle 默认角样式（当前 SDK 为 continuous）；floating 施加整个面板 | [CaptureAttributesPopup](../AreaChain/Theme/CaptureAttributesView.swift) |

两者共用页面底色、border.default 的 70% 和 0.7pt `stroke`，沿边缘内外各 0.35pt；不改成 `strokeBorder`。原 row/card/panel/banner 的接口、默认、内描边和 modifier 均保留。新外壳不加 padding、frame、clip、mask、contentShape、悬停/焦点/事件监听、状态或回调。消费者原 frame/foreground → 外壳 → transition/辅助语义顺序保持。

候选仍承载仅候选与预览＋候选；仅预览传 `isPresented: false`，保留内容身份；两者皆无仍不显示。[LiveComposerPreviewHeader](../AreaChain/Theme/LiveComposerPreviewHeader.swift) 和 [LiveDiaryComposerPreview](../AreaChain/Theme/LiveDiaryComposerPreview.swift) 自有外壳不迁移，原任务预览的叠层、手记预览的条件描边及分隔线不变。后续任务实时预览的 regular/continuous/背景阴影可复用 suggestions；手记 small/continuous/背景阴影仍需届时明确预设差异，本阶段不预增配置。

SyntaxOverlay 保留锚点、尺寸、来源优先级、最近宿主、事件和关闭责任；候选/属性内容和 daybookScroll 保持。属性关闭仍是 state.dismiss()，不创建标签或保存。共享的 [UnifiedSearchOverlay](../AreaChain/Theme/UnifiedSearchOverlay.swift) 仍只在已有统一搜索宿主回归：customRow、68pt 行高、列表高度上限、原锚点宽度和向上优先、接受许可不变，不接生产搜索。

复用 DaybookSurfaceTests、SyntaxOverlayPlacementTests、CaptureOverlayLayoutTests、SyntaxAutocompleteTests、InputSyntaxInteractionTests、DiaryComposerInteractionTests、MenuBarPopoverRenderingTests、UnifiedSearchLayoutTests / InputTests。新增 [完整外缘与生产宿主矩阵](../AreaChainTests/Theme/OverlaySurfaceConsumerTests.swift) 和 [冻结绘制支持](../AreaChainTests/Theme/OverlaySurfaceTestSupport.swift)，原 ControlsPreview 增加 [合成浮层样例](../AreaChainTests/Theme/DaybookFloatingSurfaceSamples.swift)。实际运行、失败及指定复核缺口见[工程记录](engineering.md#第八阶段-c候选与只读属性浮层外壳)。

## 统一搜索计划列表（4A-3B2）

| 入口 | 责任与消费者 |
|---|---|
| [UnifiedSearchPlanList](../AreaChain/Features/Search/UnifiedSearchPlanList.swift) | 原 OperationPreview 下方列表，复用参数字段、对象选择和摘要；标准/紧凑隔离宿主共用。默认紧凑、单项就地展开，有界滚动，不注册补全层。 |
| [UnifiedSearchPlanButton](../AreaChain/Features/Search/UnifiedSearchPlanButton.swift) | 列表的编辑/顺序按钮复用既有按下/释放事件约定；捕获原回调，收起后返回原编辑按钮焦点。 |
| [UnifiedSearchPlanEditing / UnifiedSearchPlanMerge](../AreaChain/Features/Search/UnifiedSearchPlanEditing.swift) | Controller 从协调者派生 plan / editingDraft；原 lease＋plan/item/draft stamp 派发 enqueue、edit、remove、reorder、merge。合并提议只持身份。 |
| [UnifiedSearchPlanDependencies](../AreaChain/Features/Search/UnifiedSearchPlanDependencies.swift)、[PlanLinks](../AreaChain/Features/Search/UnifiedSearchPlanLinks.swift) | 展示前置/声明输出，选择兼容 todo 创建输出，明确解除或逐项刷新引用；复用 CommandPlanValidation.acceptsReference，不生成占位对象。 |
| [UnifiedSearchPlanCopy](../AreaChain/Features/Search/UnifiedSearchPlanCopy.swift)、[OperationCopy](../AreaChain/Features/Search/UnifiedSearchOperationCopy.swift) | 类型化错误映射及活动/计划共用参数格式；无原始错误、正文或敏感元数据调试输出。 |

唯一计划是 CommandHostSession.plan；不把计划项复制到 operations.active。移出退回 retained，收起保留修改。静态校验不是执行许可，没有封存、执行、回执或真实设置写入。版本接续、原生证据与剩余输入能力统一见[权威交接 §9.49](unified-search-commands.md#949-阶段-4a-3b2待执行计划与就地编辑)。入口守卫由原 check_workflow 及其反例维护。

## 第七阶段 D：隐私设置安全输入接入

- [PrivacySetupSheet](../AreaChain/Features/Settings/PrivacySetupSheet.swift) 四处输入直接使用既有 [DaybookSecureField](../AreaChain/Theme/DaybookSecureField.swift)，移除表单 roundedBorder，复用 28pt DaybookInputShell；480pt 宽度、maxHeight 430 滚动区与底部按钮结构不变。公共 API、输入壳和安全输入内部均未改。
- 主密码/确认仍绑定原 master/repeated，仅在 `creating && !vault.isConfigured && useMaster` 时显示；备份密码/确认仍绑定 backupPassword/backupRepeated，仅在原 candidates/selected/includeLegacy 决定的 count > 0 时显示。四个稳定身份为 `privacy.setup.master`、`privacy.setup.master.confirmation`、`privacy.setup.backup`、`privacy.setup.backup.confirmation`，确认字段不能只按相同文案或数组下标定位。
- valid 原样保留：已配置分支、至少一种方式、启用主密码时与存在候选时分别至少 12 个 Swift Character 且匹配；同时启用系统方式不跳过主密码校验。两组可使用不同口令，不新增 trim、规范化、字节长度或密码镜像。
- 没有 onSubmit、自动聚焦或自动跳字段。submit 捕获 newPassword/backupInput 后不立即清空；原成功、catch、取消与 onDisappear 才调用 clearPasswords。busy 禁用整个 ScrollView、取消/应用及交互关闭，与 B/C 的输入/取消差异保留。界面清空不代表 Swift String/内存安全擦除。
- [Setup 四字段验证](../AreaChainTests/Features/PrivacySetupSecureInputTests.swift) 与 [稳定身份支持](../AreaChainTests/Features/SetupSecureTestSupport.swift) 复用原 [SetupFixture/Toggle 测试](../AreaChainTests/Features/PrivacySetupToggleTests.swift)、PrivacyTagChoiceTests、PrivacyButtonSheetHost 与 SecureInputTestSupport；展示复用原 ControlsPreview 安全样例。仅隔离合成数据、probeSystem:false；合法键盘/Apply 用测试进程临时内存回退状态保护，只验证原 storageFailure 提前失败，恢复状态且不进入配置、认证、文件面板或迁移。结果和缺口见[工程记录](engineering.md#第七阶段-d隐私设置安全输入接入)。
- 当前生产安全输入清单：PrivacyPasswordSheet 两字段、PrivacyUnlockView 一字段、Setup 四字段均接入公共入口；公共内部原生 SecureField 是合理承载。搜索保留 WorkspaceHeaderSearchCapsule / MenuBarSearchField 线索，任务/手记继续沿 DaybookTextField / SyntaxTextField / SyntaxTextEditor / DaybookTextEditor，各自提交契约留后续核对，不在 D 修改；B 的特定 busy/重试残留、原生空值回写、指定复核/人工和历史缺口继续登记。

## 第七阶段 C：解锁面板安全输入接入

- [PrivacyUnlockView](../AreaChain/Features/Diary/PrivacyUnlockPresenter.swift) 的唯一密码字段直接复用 [DaybookSecureField](../AreaChain/Theme/DaybookSecureField.swift) 及既有 28pt DaybookInputShell；保留 `privacy.master.placeholder`、`privacy.master.input`、原标签/按钮分组与唯一 `.onSubmit { authenticate(system: false) }`。没有新增公共接口、密码镜像或外壳。
- 密码/系统入口仍分别由 `hasMasterPassword` / `hasSystemUnlock` 决定。密码按钮按 `busy || password.isEmpty` 禁用，但 authenticate 只 guard `!busy`，聚焦空字段的 Return 仍进入原认证。与 PrivacyPasswordSheet 的空值/匹配校验不同，不统一两者提交算法。
- 开始认证仍先 busy、清错、捕获 input、清空 password，再进入 Task；成功检查 vault.isUnlocked 后回调，失败保留原错误映射。busy 禁用两种认证按钮、字段仍可编辑；取消仍可用，与密码 sheet 的 busy 禁止取消不同。onDisappear 仍清字段；不恢复已提交密码或增加清空补偿。
- View 的 onCancel 仅回调；关闭、锁定及 continuation 完成由原 Presenter 负责。原 request/show/finish、窗口代理、PrivacyAccess、vault/代次/限流/钥匙串/加密均未改。原 Presenter 只读 shared locale；直接 View 双语证据不能替代 Presenter 双语。
- [直接视图对照](../AreaChainTests/Features/PrivacyUnlockSecureInputTests.swift) 与 [原 Presenter 接线](../AreaChainTests/Features/PrivacyUnlockPresenterInputTests.swift) 共用 [隔离支持](../AreaChainTests/Features/PrivacyUnlockSecureTestSupport.swift)，沿 SecureInputTestSupport、SettingsButtonTestSupport 和 PrivacyAutolockTestSupport 的归属/清理方式，所有请求显式注入 MemoryVaultConfigurationStore / FakeSystemVaultKeys。展示复用原 ControlsPreview 安全样例；实际结果及缺口见[工程记录](engineering.md#第七阶段-c解锁面板安全输入接入)。
- 下一阶段仅作线索：PrivacySetupSheet 的 master/repeated 在 `creating && !vault.isConfigured && useMaster` 时显示，backupPassword/backupRepeated 在候选 count > 0 时显示；两对各自至少 12 字符且相等，方法另要求至少一种可用。submit 捕获 newPassword/backupInput 后进入原流程，字段在成功、失败、取消和消失时清空，并非本解锁面板的提交前立即清空；busy 禁用滚动输入区及取消。Setup、搜索及任务/手记编辑器本轮均不迁移。

## 第七阶段 B：公共安全输入与通用密码弹窗

- [DaybookSecureField](../AreaChain/Theme/DaybookSecureField.swift) 组合原生 SwiftUI SecureField、DaybookInputShell.search 的既有 28pt 配置、DaybookType.body 和语义色。普通表单组件与输入壳不改；不新建安全外壳或颜色参数。
- `init(_:text:)` 接本地化键，`init(verbatim:text:)` 接已解析文字，两者都提供占位符和辅助名称；稳定标识沿调用方 `.accessibilityIdentifier`。外部 Binding 是唯一密码来源；内部只持瞬时焦点，不做校验、trim、Unicode 规范化、密码镜像、提交、清空、明文切换、复制、缓存或 IO。
- 本阶段仅 [PrivacyPasswordSheet](../AreaChain/Features/Settings/PrivacyPasswordSheet.swift) 两个字段接入，保留 title/confirmation/explanation/action/onComplete，以及两处 `.onSubmit(submit)`。440pt 宽度和原分组保持。宿主继续决定空值/匹配校验、busy、清空、异步错误/重试、取消和关闭；输入区域 busy 时仍可编辑。
- PrivacySettingsSection 的主密码操作确认、关闭系统解锁不确认；DataBackupView 的导出确认、恢复不确认。父页成功清 dialog 并更新状态；本轮仅静态核对父页，测试只注入可控 action，不执行认证、钥匙串、文件面板、备份或恢复。
- [公共输入测试](../AreaChainTests/Theme/DaybookSecureFieldTests.swift)、[生产弹窗对照](../AreaChainTests/Features/PrivacySecureInputTests.swift)、[安全编辑/长说明](../AreaChainTests/Features/PrivacySecureEditingTests.swift) 复用 SettingsButtonTestSupport 和 PrivacyButtonSheetHost；后者可选外部 presentation Binding 只用于同一宿主关闭/重开。原 [ControlsPreview](../AreaChainTests/Theme/DaybookControlsPreview.swift) 增加 [合成遮蔽样例](../AreaChainTests/Theme/DaybookSecureInputSamples.swift)。实际证据与缺口见[工程记录](engineering.md#第七阶段-b公共安全输入与通用密码弹窗)。
- 后续 PrivacySetupSheet 可复用键/Binding 入口，但需保留配置组合、至少 12 字符规则和迁移/备份流程；PrivacyUnlockView 须保留自己的 placeholder、稳定标识、原 onSubmit 认证、取消回调与 Presenter 生命周期。本轮两者均未迁移，搜索与任务/手记编辑器也不接入。


## 第七阶段 A：普通表单输入与三个输入框

- [DaybookFormTextField](../AreaChain/Theme/DaybookFormTextField.swift) 是普通表单的公共组合：外部 `Binding<String>` 为唯一草稿来源；内部只有 `FocusState` 等瞬时呈现状态。`LocalizedStringKey` 初始化保留环境本地化，`verbatim:` 接收已解析文字，两者同时提供占位符和辅助名称；用户内容不参与资源查找。
- 内部保留 SwiftUI `TextField` 原生单行承载，plain 样式只消除重复边框；复用未修改的 DaybookInputShell 与标准 search 尺寸配置（28pt、水平 7/垂直 4pt 内边距）、DaybookType.body 和 DaybookPalette。search 在这里仅是紧凑外壳尺寸，不引入搜索状态、语法或提交算法。没有自动聚焦、全局键盘监听、挂载/失焦规范化、长期草稿镜像或保存入口。
- 两个生产定义、三个字段全部接入：[TaskDetailTagSelector.newTagSheet](../AreaChain/Features/Workspace/TaskDetailClassificationSection.swift) 的名称字段以 `verbatim: L10n.string(...)` 进入；[ClipboardHistoryOptions.addRow](../AreaChain/Features/Clipboard/ClipboardHistoryOptions.swift) 的正则与类型名保留本地化键。三处稳定标识分别为 `drawer.tag.create.name`、`clipboard.patterns.add`、`clipboard.types.add`。公共组合内部的原生 TextField 不算生产遗漏。
- 标签消费者仍清空打开/取消草稿，编辑清错，仅创建时 trim；保留名不回调，回调失败保留输入和弹窗，成功清空关闭。待办/习惯详情走原 addTag 创建及关联；RecurringItemEditor 经 resolveTaskTag 立即保存标签，再更新事项草稿，取消新事项不会回滚已经创建的标签。
- 剪贴板两个草稿互不覆盖；addPattern/addType 仍在原 session 校验、trim 并即时保存偏好，成功才清空。正则拒绝提示不随输入清除，类型拒绝不新增反馈；取消只关闭，未添加输入不提交。错误文字从原行底部 overlay 改为同一行下方占位，避免覆盖输入和添加按钮；240pt 标签弹窗及 440×560pt 页面约束不变。
- [公共测试](../AreaChainTests/Theme/DaybookFormTextFieldTests.swift)、[消费者事件刻画](../AreaChainTests/Features/FormInputConsumerBaselineTests.swift)、[标签链路](../AreaChainTests/Features/TagFormInputConsumerTests.swift) 和 [剪贴板添加](../AreaChainTests/Features/ClipboardFormInputTests.swift) 沿 SettingsButtonTestSupport / ClipboardOptionsFixture 与 PrivacyQA；展示扩展原 [ControlsPreview](../AreaChainTests/Theme/DaybookControlsPreview.swift)，样例含普通、禁用、长文本及多个实例。实际执行和缺口以[工程记录](engineering.md#第七阶段-a普通表单输入与三个输入框)为准，测试存在不代表已通过。
- 普通输入不解析 `# @ ! //`、反斜杠、括号、Unicode 或资源键形状的原文；粘贴/换行保留原生输入约束。任务语法仍由 DaybookTextField / SyntaxTextField / SyntaxTextEditor 负责，搜索仍由各搜索宿主负责，安全输入仍保留 SecureField 与原认证边界。本阶段不迁移上述入口或手记编辑器；后续安全输入实际线索为 Features/Settings 下的 PrivacyPasswordSheet / PrivacySetupSheet，以及 Features/Diary 的 PrivacyUnlockPresenter，须重新核对其宿主及授权。

## 第六阶段 E：周视图日期列头接入

- [DaybookDateCell](../AreaChain/Theme/DaybookDateCell.swift) 的 `weekHeader(shortStamp: String)` 是唯一周日期按钮呈现。公共层绘制 caption semibold 短日期、title 日号、左对齐与 regular quiet 按钮；[DaybookMetrics.WeekHeader](../AreaChain/Theme/DaybookMetrics.swift) 集中 2pt 行距。按钮原上下 3pt、左右 6pt 内边距沿 DaybookButtonSize，无固定列头高度、选中填充、今天下划线、月格计数/边框或习惯紧凑日号。
- [CalendarWeekBoard](../AreaChain/Features/Calendar/CalendarWeekBoard.swift) 保留 `calendar.week.<完整日键>`，覆盖公共默认标识；完整日期辅助名称、今天 value 与外部选中语义由公共层提供，按钮不包含整列列表。多个实例须限定宿主祖先与完整日键。默认 picker、monthGrid、habit 及 `annotation: Text?`、`statusDescription` 兼容。
- 格式来源刻意保留：Feature 的 `DayKey.shortStamp(day, locale:)` 仍使用默认 calendar；公共第二行日号和完整辅助日期使用环境 calendar。未统一系统日历/时区、未改 DayKey。异日历历史显示差异单独登记；纯显示参数不允许 Feature 自绘 View。
- Feature 继续负责 days 顺序、selectedKey/todayKey、整列选中背景、6pt 列内边距/列头列表间距、8pt 列距、查询/列表投影、滚动、焦点、onInspect 所属日、onSelect 重选及列级拖放。TodoDragToken 解码、onDropTodo、接收区域和保存链原样保留。直接宿主仍是 CalendarPage.weekLayout；公共层无模型、导航单例、额外选择状态或键盘监听。
- [公共对照与展示](../AreaChainTests/Theme/DaybookWeekHeaderTests.swift) 扩展原 ControlsPreview；[生产基线](../AreaChainTests/Features/CalendarWeekBaselineTests.swift)、[周消费者](../AreaChainTests/Features/CalendarWeekConsumerTests.swift) 复用 [隔离支持](../AreaChainTests/Features/CalendarWeekTestSupport.swift)、CalendarSpanTestSupport 和原日期消费者。稳定呈现/几何沿 check_workflow.py 与反例维护，实际结果见[工程记录](engineering.md#第六阶段-e周视图日期列头接入)。

### 第六阶段剩余范围

| 范围 | 当前状态 / 后续边界 |
|---|---|
| 日期选择与排期、主月历、习惯月历、星期圆点、周列头 | A–E 已接入各自唯一公共入口；运行验收仍有下述缺口 |
| 只读星期标题、任务行原生星期子菜单 | 合理保留为 DaybookWeekdayHeader / standingMenus，不强改成圆点 |
| 周看板业务布局与列表 | 继续归 CalendarWeekBoard / CalendarPage，不是待搬进 Theme 的重复控件 |
| 周运行问题 | 420pt 越界、标题挤压、列表切周焦点未解决，单独确定修复范围 |
| 验证缺口 | Cursor verifier、真实拖放、D 的 Tab 激活、人工 VoiceOver、输入法/撤销及既有日期/时间等历史缺口 |

清单仅用于判断后续范围，不表示第六阶段全面验收完成；E 完成后停止。

统一搜索 2K-8 的 [TagUsageContentQueryReads](../AreaChain/Services/TagUsageContentQueryReads.swift)、[TagUsageContentQueryCapture](../AreaChain/Services/TagUsageContentQueryCapture.swift) 与 [TagUsageContentQueryStatistics](../AreaChain/Services/TagUsageContentQueryStatistics.swift) 复用四类元数据及全标签目录、TagUsage.subjects/records 和家庭同批装配，唯一消费入口为 ContentQueryReadSession.prepareTagUsage。TagQueryUsageSummary 将次数展示与精确时间内部计算分离；TagQueryProvider、聚合排序、摘要和分页共同消费。实际消费者为四套同名隔离服务测试，完整性、门禁、旧口径与 partial 证据只见[权威设计 §9.44](unified-search-commands.md#944-阶段-2k-8全来源标签使用统计的只读存储适配与受门禁发布)。

统一搜索 2K-7 新增 [TrashContentQueryReads / Plan / Details](../AreaChain/Services/TrashContentQueryReads.swift)、[墓碑同批装配](../AreaChain/Services/TrashContentQueryReader.swift) 与 [TrashContentQueryCapture](../AreaChain/Services/TrashContentQueryCapture.swift)，复用六类现有枚举依赖、ImageContentQueryCapture 的物理行核验和 DiaryContentQueryBodies 的受控保护检查。ContentQueryReadSession.prepareTrash 内部持有唯一许可与 ReadOwner；TrashTombstoneInput 保留无父子任务的身份缺口和同批对象级图片保护资料，2H 继续负责安全投影、级联、匹配、分组与恢复条件。实际消费者仅四套 TrashContentQuery 隔离服务测试，旧 live-only 与正文路径保持独立；完整契约和验证见[权威设计 §9.43](unified-search-commands.md#943-阶段-2k-7完整墓碑只读适配与受门禁回收站搜索)。原组件守卫和反例同步扩展，没有生产接线或操作 handler。

统一搜索 2K-6 新增 [ImageContentQueryReads / Plan](../AreaChain/Services/ImageContentQueryReads.swift) 与 [ImageContentQueryCapture](../AreaChain/Services/ImageContentQueryCapture.swift)，经 ContentQueryReadSession.prepareImages 内部许可装配唯一图片源、主拥有者快照和标签 metadata。DiaryContentQueryBodies 的 DiaryImageProtectionFacts 只保留对象级保护结论，ImageOwnerResolver / BatchAssembly / ContentQueryImageRead 共同消费；没有另建 canBrowse 或附件索引。消费者为 ImageContentQuery 四套隔离服务测试，复用原内存库、fake vault、排序/摘要/分页/发布。实际读取、覆盖、授权和验证缺口见[权威设计 §9.42](unified-search-commands.md#942-阶段-2k-6图片元数据只读适配同批图片查询与-hasimage)。

统一搜索 2K-5 扩展 [ClipboardHistoryStore.readHistory / ClipboardHistoryReadResult](../AreaChain/Services/ClipboardHistoryStore.swift)，新增 [ClipboardContentQueryReader](../AreaChain/Services/ClipboardContentQueryReader.swift)，复用原记录格式、ClipboardQueryRecords / Provider / ModeRequest、Batch / Options。[ReadSession.prepareClipboard](../AreaChain/Services/ContentQueryReadSession.swift) 使用协调者当前查询与内部独占 ReadOwner；实际消费者仅 ClipboardHistoryReadTests、ClipboardContentQueryReaderTests、ClipboardContentQueryLifecycleTests 及合成临时目录夹具，旧 load 调用兼容。格式、按需和发布边界统一见[权威设计 §9.41](unified-search-commands.md#941-阶段-2k-5剪贴板历史文件只读适配与受门禁发布)。原组件守卫及反例同步维护，无生产来源选择或监听。

统一搜索 2K-4D 沿 areachain-workflow → 架构治理 → areachain-verify；ContentQueryBodyReads、ContentQueryReadSession.prepareBodies 和 DiaryContentQueryReader 共同将正文留在内部许可与唯一冻结所有者中，复用 DiaryContent.read 同批目录校验。外部 Batch 仍仅 metadataOnly；无生产接线。实际接口、授权、生命周期、性能/内存限制和 partial 验证状态统一见[权威设计 §9.40](unified-search-commands.md#940-阶段-2k-4d受搜索生命周期门禁约束的手记正文读取)。

统一搜索 2K-4C 新增 [ContentQueryReadSession](../AreaChain/Services/ContentQueryReadSession.swift) 与 [ContentQueryReadNotifications](../AreaChain/Services/ContentQueryReadLifecycle.swift)，复用 PrivacyVault 实际通知/Observation、ReadOwner、Handoff lease/send 和原分页浏览；专用 privacyInvalidated 只清查询。当前消费者仅四套隔离生命周期/领域测试，没有生产入口；唯一事件、线程、外部副本与 partial 交接见[权威设计 §9.39](unified-search-commands.md#939-阶段-2k-4c搜索隐私失效查询清理与结果发布门禁)。原组件守卫与反例同步维护。

统一搜索 2K-4B 新增 [DiaryContentQueryReader / Reads / ReadDetails](../AreaChain/Services/DiaryContentQueryReader.swift) 和 [DiaryContentQueryTagPrivacy](../AreaChain/Services/DiaryContentQueryTagPrivacy.swift)，复用仓储静态全枚举、TaskFamily 同批装配、TagContentQueryReader 全目录及 ContentQueryTagNames 公开名字规则；实际消费者仅 DiaryContentQuery 四套隔离服务测试与夹具。旧入口默认关闭，元数据仅经 DiaryQuery / ReadOwner / 排序摘要分页消费，不读取正文或真实统计。唯一接口、覆盖及 partial 交接见[权威设计 §9.38](unified-search-commands.md#938-阶段-2k-4b手记元数据只读适配同批标签装配与隔离回归)，原组件守卫和反例同步维护。

统一搜索 2K-3 新增 [TagContentQueryReader / Reads / ReadDetails](../AreaChain/Services/TagContentQueryReader.swift)，经 CatalogRepositoryProtocol / SwiftDataCatalogRepository 完整枚举 TagItem，原值投影 TagQuerySnapshot；[TaskFamilyContentQueryReader](../AreaChain/Services/TaskFamilyContentQueryReader.swift) 将标签与任务类装入同一 Batch。ContentQueryTagNames.project 复用原按 ID 的保护/歧义规则，全目录与关联名字同批需要时共用一次 fetch。统计仅接受显式 injectedUsage，来源标为 injected；不生产全来源统计。消费者仅 TagContentQuery 四套服务测试与夹具、既有任务家庭测试；复用原内存容器及 ReadOwner/展示分页。接口、覆盖和验收缺口唯一见[权威设计第 9.36 节](unified-search-commands.md#936-阶段-2k-3标签目录的-swiftdata-只读适配与同批装配)，原组件守卫及反例同步维护，不接生产 UI。

统一搜索 2K-2 新增 [TaskFamilyContentQueryReader](../AreaChain/Services/TaskFamilyContentQueryReader.swift)，复用 TaskContentQueryReader.readSources、[RoutineContentQueryReader](../AreaChain/Services/RoutineContentQueryReader.swift) 与 [RoutineContentQueryReads / Observation / CheckPlan](../AreaChain/Services/RoutineContentQueryRead.swift)；[ContentQueryTagNames](../AreaChain/Services/ContentQueryTagNames.swift) 被旧任务入口与家庭入口共同消费，一次读取合并关联 ID。消费者仅 RoutineContentQuery 的 Reader/Coverage/Observation/Failure 测试及 TaskFamilyContentQueryIntegrationTests，复用 TaskRepositoryFixture 内存库。Batch 的 checkSourceProblem 仅承接不能按习惯定位的输入缺口/读取失败，局部覆盖仍沿 RoutineCheckCoverage；原组件守卫和反例同步维护。唯一契约与验收见[权威设计第 9.35 节](unified-search-commands.md#935-阶段-2k-2习惯与打卡的-swiftdata-只读适配及任务类同批装配)。

统一搜索 2K-1 新增 [TaskContentQueryReader / TaskContentQueryReads / TaskContentQueryReadResult](../AreaChain/Services/TaskContentQueryReader.swift)。`readTasks(session:requestID:options:)` 复用 TaskRepositoryProtocol.fetchAllTodos(includeDeleted: true)、真实 snapshot、Batch 与 ReadOwner；子任务独立完整 fetch，标签按关联 ID 读取。实际消费者仅 Services 的 TaskContentQueryReaderTests / FailureTests / IntegrationTests；原任务仓储和新测试共用 TaskRepositoryFixture 内存 schema。上下文所有权、覆盖、失败及冻结限制唯一见[权威设计第 9.34 节](unified-search-commands.md#934-阶段-2k-1任务与子任务的-swiftdata-只读快照适配)。原组件守卫增加此稳定 Services 入口及反例测试，不建立新执行器。

统一搜索 2J-3C 新增 [ContentQueryReadOwner / Task / Ticket / Publication](../AreaChain/Domain/ContentQueryReadOwner.swift)，由唯一所有者保留冻结 Batch；[ContinuationPolicy / Remainder](../AreaChain/Domain/ContentQueryContinuation.swift) 从原 RoutineOccurrenceQueryCoverage 筛选输入、工作、结果预算余量。求值串联原 BatchReader → Sorter → Presenter → DisplayBuilder；发布只调用原 Pagination.reset，其 `preservingActiveVisibility` 可选参数默认 false，2J-3C 显式启用稳定活动身份的最小前缀扩展。实际消费者为 ContentQueryContinuationTests、ContentQueryReadLifecycleTests、ContentQueryReadPublicationTests、ContentQueryReadSnapshotTests，QueryReadFixture 继续复用 Batch/Sort/Presentation/Trash 夹具；原分页消费者回归。所有权、预算上限、无进展、取消/失效与完整证据唯一见[权威设计第 9.33 节](unified-search-commands.md#933-阶段-2j-3c预算续读同快照重新求值与结果发布协调)。没有生产消费者或新检查器入口。

统一搜索 2J-3B 的 [PaginationState / Policy / Event / Stamp](../AreaChain/Domain/ContentQueryPagination.swift) 仅控制既有 DisplaySource 的单位、命中和上下文前缀，内部组合原 BrowseState，通过 publish/apply 接续选择与展开。[PaginationStatus](../AreaChain/Domain/ContentQueryPaginationStatus.swift) 区分已知展示余量与原提供者未处理工作；[DisplaySnapshot](../AreaChain/Domain/ContentQueryDisplay.swift) 的 sourceID、revisingVisibility、sharesSource 绑定同一不可变安全来源。实际消费者为 ContentQueryPaginationTests、ContentQueryGroupPaginationTests、ContentQueryPaginationBrowseTests、ContentQueryPaginationStatusTests，夹具 QueryPaginationFixture 复用原 Batch/Sort/Presentation/Trash 夹具。额度、版本、上下文可达性、锚点和 2J-3C 缺口唯一见[权威设计第 9.32 节](unified-search-commands.md#932-阶段-2j-3b展示分页组内分段与浏览状态接续)。无生产 UI、IO、续读调度或新检查器入口。

统一搜索 2J-3A 的 [ContentQueryDisplayBuilder.build](../AreaChain/Domain/ContentQueryDisplayBuilder.swift) 消费同批 Presenter 响应；[DisplaySnapshot / Unit / Visibility](../AreaChain/Domain/ContentQueryDisplay.swift) 保留稳定组、命中和上下文引用，以及显式可见单位/成员；[BrowseState / Event / Effect](../AreaChain/Domain/ContentQueryBrowse.swift) 处理浏览选择、展开与版本拒绝，仅输出打开/焦点意图。复用 ordered、TrashQueryGroup.source/context、CommandObjectReference 和 ExpansionReference；ContentQueryMatchField 仅补 Hashable 以组成控件身份。实际消费者为 ContentQueryDisplayTests、ContentQueryBrowseTests、ContentQueryDisplayProtectionTests；无生产 UI 调用方。唯一契约、验证及 2J-3B 接口见[权威设计第 9.31 节](unified-search-commands.md#931-阶段-2j-3a展示分组可见命中序列与键盘选择)。原检查器和脚本测试复用，不新增执行器。

统一搜索 2J-2B 新增 [ContentQueryPresenter.project](../AreaChain/Domain/ContentQueryPresenter.swift)、[展示契约](../AreaChain/Domain/ContentQueryPresentation.swift)、[Snippet](../AreaChain/Domain/ContentQuerySnippet.swift)、[Evidence](../AreaChain/Domain/ContentQueryPresentationEvidence.swift)、[EvidenceRules](../AreaChain/Domain/ContentQueryPresentationEvidenceRules.swift) 与 [Details](../AreaChain/Domain/ContentQueryPresentationDetails.swift)。直接复用 ContentQuerySortedResponse/BatchMatch、ContentQuerySortFields、同批 SortContext、DiaryQueryPresentation、ClipboardQueryModeEvidence 和 TrashQuery 安全关系。实际消费者为 ContentQueryPresentationTests / ContentQueryPresentationBoundaryTests / ContentQueryPresentationProtectionTests / ContentQuerySnippetTests；原排序消费者回归。唯一规则与验证见[权威设计第 9.30 节](unified-search-commands.md#930-阶段-2j-2b安全摘要命中片段与高亮映射)；不新增检查器接口，不接生产 UI/IO/执行，指定复核仍 partial。

统一搜索 2J-2A 的纯排序入口：[ContentQuerySorter / ContentQuerySortedResponse](../AreaChain/Domain/ContentQuerySort.swift) 消费同批 [ContentQuerySortContext](../AreaChain/Domain/ContentQuerySortContext.swift) 与原 BatchResponse；[ContentQueryRelevance](../AreaChain/Domain/ContentQueryRelevance.swift) 校验条件/替代项证据并分四档，[ContentQuerySortFields](../AreaChain/Domain/ContentQuerySortFields.swift) 只短暂访问已有公开字段，[ContentQuerySortTime](../AreaChain/Domain/ContentQuerySortTime.swift) 保留 createdAt/copiedAt/执行日的真实精度。实际消费者为 ContentQueryRelevanceTests、ContentQuerySortTimeTests、ContentQuerySortIntegrationTests；没有生产 UI 调用方。source 保留原 matches/readings/groups/完整性，ordered 只含身份与解释；不以平面顺序替代墓碑布局。唯一规则及 2J-2B 前置见[权威设计第 9.29 节](unified-search-commands.md#929-阶段-2j-2a安全聚合结果的相关性与最近排序)。

统一搜索 2J-1 的 [ContentQueryBatch](../AreaChain/Domain/ContentQueryBatch.swift) 与 [ContentQueryBatchReader.read](../AreaChain/Domain/ContentQueryBatchReader.swift) 是同步注入聚合入口；[Assembly](../AreaChain/Domain/ContentQueryBatchAssembly.swift) 为九个原提供者装配同一 Session、分型主源与辅助资料，[Result](../AreaChain/Domain/ContentQueryBatchResult.swift)、[Completeness](../AreaChain/Domain/ContentQueryBatchCompleteness.swift) 和 [Identity](../AreaChain/Domain/ContentQueryBatchIdentity.swift) 保留原安全投影、来源反馈、覆盖及冲突隔离。当前消费者仅 ContentQueryBatchSelectionTests / ContentQueryBatchCompletenessTests / ContentQueryBatchProtectionTests / ContentQueryBatchOccurrenceTests；原提供者不改算法或生产调用方。批次一致性实际范围、平面子任务唯一来源、保护/墓碑/记录计数、临时顺序及指定复核缺口只见[权威设计第 9.28 节](unified-search-commands.md#928-阶段-2j-1同步批次跨提供者类型化结果与完整性汇总)。既有检查器接口不变，沿原脚本回归验证，不接真实库/UI/执行或后续排序分页。

统一搜索 2I 新增 [RoutineOccurrenceQueryProvider.read / Matching](../AreaChain/Domain/RoutineOccurrenceQueryProvider.swift)、[请求/独立结果/覆盖/预算](../AreaChain/Domain/RoutineOccurrenceQueryRead.swift)、[单习惯输入与周期采样](../AreaChain/Domain/RoutineOccurrenceQueryInput.swift)、[有界枚举](../AreaChain/Domain/RoutineOccurrenceQueryEnumeration.swift)。真实消费者仅四套 RoutineOccurrenceQuery Domain 测试与共用合成夹具。复用 Session、日期/类型分析、RoutineCheckReading、RoutineScheduleHistory 和 RoutineOccurrenceEvaluation；[History.segments](../AreaChain/Domain/RoutineQueryEvaluation.swift) 仅开放既有分段方法，不改变定义存在性或旧看板/写入语义。身份为 routineOccurrence＋习惯 UUID＋民事日；确定结果与未知区间/待核对行/预算剩余范围分开。唯一接口、文本与所属字段缺口及验证见[权威设计第 9.27 节](unified-search-commands.md#927-阶段-2i显式日期窗口内的习惯执行情况只读提供者)。

统一搜索 2H-2 新增 [TrashQueryProvider.read](../AreaChain/Domain/TrashQueryProvider.swift)、[TrashQueryRequest / Response / Match / Group](../AreaChain/Domain/TrashQueryRead.swift)、[安全字段匹配](../AreaChain/Domain/TrashQueryMatching.swift)、[字段视图](../AreaChain/Domain/TrashQueryFields.swift)及 [routine 证据适配](../AreaChain/Domain/TrashQueryTemporal.swift)。Reader 内最小扩展 ImageOwnerProjection 父属性和手记标签合法性标记；身份、删除关联、保护与恢复描述仍由原 TrashTombstone 层负责。实际消费者只有六套 TrashQuery 测试及共享夹具；无仓储/UI/业务执行。完整支持、计数、辅助输入和验证只在[权威设计第 9.26 节](unified-search-commands.md#926-阶段-2h-2显式墓碑只读搜索与命中归组)维护。

统一搜索 2H-1 新增 [TrashTombstoneInput / TrashReadCoverage](../AreaChain/Domain/TrashTombstoneInput.swift)、[TrashTombstoneReader](../AreaChain/Domain/TrashTombstoneReader.swift) 与 [TrashTombstoneResponse / RestoreConditions](../AreaChain/Domain/TrashTombstoneRead.swift)。复用现有六类快照/元数据、SoftDelete 精确同戳规则及 DiaryQueryPrivacy 安全投影；索引与保护投影分别在 TrashTombstoneIndex / TrashTombstoneProjection。实际消费者只有 TrashTombstoneRelationTests、CoverageTests、PrivacyTests、CompatibilityTests；没有接 TrashPage、普通图片提供者或执行器。覆盖、唯一身份、分组/计数与 2H-2 限制只在[权威设计第 9.25 节](unified-search-commands.md#925-阶段-2h-1回收站墓碑删除关联与恢复条件的只读契约)维护。

统一搜索 2G 的 [ClipboardQueryProvider.read](../AreaChain/Domain/ClipboardQueryProvider.swift)、[互斥请求与记录覆盖](../AreaChain/Domain/ClipboardQueryRequest.swift)、[最小结果与负载说明](../AreaChain/Domain/ClipboardQueryRead.swift)及 [ClipboardQueryMatching](../AreaChain/Domain/ClipboardQueryMatching.swift)，当前仅四套 ClipboardQuery 领域测试消费。旧 ClipboardHistoryRules.filtered / highlightRanges 与新提供者共用 [ClipboardTextMatching](../AreaChain/Domain/ClipboardTextMatching.swift)；旧 Session.visibleItems 和 ClipboardHistoryBrowser 高亮间接沿原入口消费。目录 clipboard.search 的 query 最小改为可省略，mode 仍显式必选；sourceApplication 仅扩充 clipboardEntry 的真实字段绑定。完整性、范围、模式/正则参数边界、验证和 partial 状态见[权威设计第 9.24 节](unified-search-commands.md#924-阶段-2g显式剪贴板历史的只读搜索提供者)。没有存储、系统剪贴板、UI、聚合、执行或新检查器入口。

这是 AreaChain 的复用导航，不是新的设计系统，也不是把所有 `struct` 都承诺成公共 API。新任务必须先查本目录，再查看声明和真实调用方；如果目录与代码不一致，以代码、测试和 `AGENTS.md` 的当前契约为准，并在同一任务中修正目录。

## 1. 复用原则

1. 先复用已有令牌、基座、领域规则、仓储和事务入口，再考虑局部扩展。
2. 相似外观不代表相同业务契约。任务、手记、搜索、剪贴板捕获和独立窗口的提交与快捷键语义不能只靠一个布尔参数抹平。
3. 只有一个真实消费者时，默认保留在所属 Feature；多个消费者共享同一语义并需要同步演进时，才提取到公共层。
4. 新公共组件必须有明确归属、至少一个真实调用链、相关测试和本目录条目。
5. `Theme` 负责令牌和通用展示基座；业务复合视图原则上放在所属 `Features`，不要把新的业务视图塞进 `Theme`。当前 `LiveComposerPreviewHeader` 和 `LiveDiaryComposerPreview` 是历史例外；新增消费者不得继续扩大这两个例外，迁移它们需要单独的架构重构授权和回归证据。
6. 目录条目只说明复用边界，不替代类型检查、调用方检查或原生运行验收。

## 2. 令牌与视觉基座

| 类别 | 入口 | 文件 | 适用范围与必须保持的行为 |
|---|---|---|---|
| 语义色 | `DaybookPalette`、`DaybookColor` | [DaybookPalette.swift](../AreaChain/Theme/DaybookPalette.swift)、[DaybookColor.swift](../AreaChain/Theme/DaybookColor.swift) | 使用语义色，不在 Feature 写裸系统色；状态、文本、表面和热力图颜色从这里取。 |
| 尺寸/字号/间距 | `DaybookMetrics`、`DaybookTokens` | [DaybookMetrics.swift](../AreaChain/Theme/DaybookMetrics.swift)、[DaybookTokens.swift](../AreaChain/Theme/DaybookTokens.swift) | 复用高度、间距、圆角、字号和描边；不要用局部常量悄悄改变全局基线。 |
| 阴影/动效 | `DaybookElevation`、`DaybookMotion` | [DaybookElevation.swift](../AreaChain/Theme/DaybookElevation.swift)、[DaybookChrome.swift](../AreaChain/Theme/DaybookChrome.swift) | 遵守浅深色和减弱动态效果；动效调整须检查取消和快速重复操作。 |
| 输入外壳 | `DaybookInputShell`、`DaybookInputKind` | [DaybookInputShell.swift](../AreaChain/Theme/DaybookInputShell.swift) | `composer`、`search`、`editor` 是外壳类型，不改写内部控件的 Return、Escape、撤销或组合文本行为。颜色和聚焦边界由基座管理。 |
| 普通文本输入 | `DaybookTextField`、`DaybookTextEditor` | [DaybookTextField.swift](../AreaChain/Theme/DaybookTextField.swift)、[DaybookTextEditor.swift](../AreaChain/Theme/DaybookTextEditor.swift) | 原生 AppKit 输入桥接；需要核对焦点、输入法、撤销和最小尺寸。 |
| 语法输入 | `SyntaxTextField`、`SyntaxTextEditor` | [SyntaxTextField.swift](../AreaChain/Theme/SyntaxTextField.swift)、[SyntaxTextEditor.swift](../AreaChain/Theme/SyntaxTextEditor.swift) | 任务/手记语法高亮和候选输入；必须提供正确的 `SyntaxInputContext`，搜索不能借此创建标签。触发检测和高亮正则编译一次。同一 `NSTextStorage` 在文本、字体、默认色和外观未变时不整段重建属性。外观键取自该 storage 所属文本视图或窗口的 `effectiveAppearance`，没有宿主时才回退 `NSApp`。 |
| 候选与浮层 | `SyntaxAutocompletePopup`、`SyntaxOverlay` | [SyntaxAutocompleteView.swift](../AreaChain/Theme/SyntaxAutocompleteView.swift)、[SyntaxOverlay.swift](../AreaChain/Theme/SyntaxOverlay.swift) | 就近消费输入锚点，保留 Esc 先关闭候选、焦点和定位；不要在多个宿主重复呈现同一浮层。 |
| 按钮 | `DaybookButtonStyle`、`DaybookIconButton`、`CommandReturnButton` | [DaybookButtonStyle.swift](../AreaChain/Theme/DaybookButtonStyle.swift)、[CommandReturnButton.swift](../AreaChain/Theme/CommandReturnButton.swift) | 复用尺寸、禁用、悬停、可访问性和 Command 反馈；图标按钮需有语义标签。`daybookMenuLabel` 与按钮共享内部视觉基座，保留 `fitsLabel` 和系统菜单语义；文字仍按内容加边距，图标为 28/22/18 正方形。原生焦点与显式 `isFocused` 均可显示焦点环，减弱动态效果禁用按下缩放。测试专用 `DaybookControlsPreview` 的开发展示见[工程手册](engineering.md#按钮开发展示与验收)。 |
| 启用开关 | `DaybookToggleStyle` | [DaybookToggleStyle.swift](../AreaChain/Theme/DaybookToggleStyle.swift)、[DaybookMetrics.swift](../AreaChain/Theme/DaybookMetrics.swift) 的 `Toggle` | 默认显示原标签；紧凑布局传 `hiddenLabel: LocalizedStringKey`，同时提供辅助名称，并保留消费者 `labelsHidden` / help 意图。原生 Toggle 的 button 样式承载鼠标与辅助操作；显式焦点容器独占空格按下/释放，临时按下态不镜像业务布尔值。统一轨道、滑块及反馈，无保存、导航或权限行为。几何 34×20、滑块 16、点击高度 28 集中维护；不提供颜色覆盖。消费者含新建重复事项、管理行、隐私标签多选与三个表单布尔项、剪贴板及普通设置各三项偏好；表现及提交差异见本页第三阶段 A–E。 |
| 表面与分组 | `daybookSurface`、`DaybookChip`、`DaybookSectionHeader`、`DaybookDivider` | [DaybookSurface.swift](../AreaChain/Theme/DaybookSurface.swift)、[DaybookChip.swift](../AreaChain/Theme/DaybookChip.swift)、[DaybookSectionHeader.swift](../AreaChain/Theme/DaybookSectionHeader.swift) | 共享表面、芯片、分节头和分隔线；不要在 Feature 自绘同义基座。 |
| 分段选择 | `DaybookSegmentedControl`、`DaybookSegmentOption` | [DaybookSegmentedControl.swift](../AreaChain/Theme/DaybookSegmentedControl.swift)、[菜单栏适配](../AreaChain/Theme/DaybookSegmentedBar.swift)、[日历接入](../AreaChain/Features/Calendar/CalendarPage.swift) | 核心只读写强类型 Binding。菜单栏保留 BoardTab 适配；日历直接传 CalendarSpan。快捷键、草稿、日期和投影属于宿主，详见第四阶段 E/F。 |
| 页面和工作台布局 | `DaybookPage`、`DaybookPageHeader`、`WorkspaceLayout`、`WorkspaceSidebarRow` | [DaybookPage.swift](../AreaChain/Theme/DaybookPage.swift)、[WorkspaceLayout.swift](../AreaChain/Theme/WorkspaceLayout.swift) | 页面页头、侧栏和内容宽度遵循已有宿主；`workspaceEmbedded` 只表达能力/布局差异，不切换颜色、字体或主题。 |
| 空态与周期栏 | `DaybookEmptyState`、`DaybookPeriodBar` | [DaybookChrome.swift](../AreaChain/Theme/DaybookChrome.swift) | 区分无数据、筛选无结果和失败；可见文案走本地化。 |
| 任务完成反馈 | `ModernCheckbox`、`ModernTaskTitle` | [ModernComponents.swift](../AreaChain/Theme/ModernComponents.swift) | `ModernCheckbox` 默认 task，行内子任务使用 inlineSubtask，详情行使用 detailSubtask；外部 isDone/action，提交由消费者管理。几何在 DaybookMetrics.Completion；契约与反馈差异见本页第三阶段 G/H。ModernTaskTitle 不变。 |

`CaptureAttributesView`、`SyntaxHelpCard`、`MenuBarStatusImage` 和 `KeyWindowHost` 也是已有专用基座，但它们分别绑定属性捕获、语法帮助、菜单栏状态图标和原生窗口宿主；复用前必须检查其宿主契约：

- [CaptureAttributesView.swift](../AreaChain/Theme/CaptureAttributesView.swift)
- [SyntaxHelpCard.swift](../AreaChain/Theme/SyntaxHelpCard.swift)
- [MenuBarStatusImage.swift](../AreaChain/Theme/MenuBarStatusImage.swift)
- [KeyWindowHost.swift](../AreaChain/Theme/KeyWindowHost.swift)

第二阶段 A 的消费者接入：手记小窗 [DiaryWindowView.swift](../AreaChain/Features/Diary/DiaryWindowView.swift) 的置顶使用 `.active / .subtle`，显示正文和保存使用 `.prominent`（均 compact）；[DiaryCardComponents.swift](../AreaChain/Features/Diary/DiaryCardComponents.swift) 的编辑保存使用 `.prominent`、取消保留 `.quiet`（compact）；[TaskDetailClassificationSection.swift](../AreaChain/Features/Workspace/TaskDetailClassificationSection.swift) 的标签创建/取消使用 `.prominent / .quiet`（regular）。均直接使用 `DaybookButtonStyle`，已有图标按钮及快捷提交入口保留。系统 `confirmationDialog` / `alert` 内按钮继续由系统承载；标签芯片、输入框及其他特殊选择控件不在本次迁移范围。回调、禁用、快捷键、授权和草稿语义不变。消费者回归见 `DiaryButtonConsumerTests`，不替代[第一阶段未验项](engineering.md#第一阶段-b-补充验收2026-10-01)。

第二阶段 B 的消费者接入：[PrivacyUnlockPresenter.swift](../AreaChain/Features/Diary/PrivacyUnlockPresenter.swift) 仅 `PrivacyUnlockView` 的系统验证、密码解锁使用 `.prominent`，取消使用 `.quiet`；[PrivacyPasswordSheet.swift](../AreaChain/Features/Settings/PrivacyPasswordSheet.swift) 的保存/取消及 [PrivacySetupSheet.swift](../AreaChain/Features/Settings/PrivacySetupSheet.swift) 的应用/取消使用 `.prominent / .quiet`，均为 regular。系统验证保留全宽，其他按钮保留原对齐与弹窗尺寸。解锁取消不随 busy 禁用，另外两个 sheet 的取消仍随 busy 禁用；认证、校验、快捷键、密码清空和关闭语义保持不变。直接消费者测试为 [PrivacyButtonConsumerTests.swift](../AreaChainTests/Features/PrivacyButtonConsumerTests.swift)，复用 `PrivacyFixture`、内存配置、`FakeSystemVaultKeys` 与 `SystemPageHost`，Setup 始终传 `probeSystem: false` 且不执行 Apply 提交；具体证据与未测范围见[工程手册](engineering.md#第二阶段-b隐私弹窗按钮接入2026-10-01)。普通设置、快捷键等按钮尚待后续独立迁移，开关、密码框、加载指示器及系统弹窗按钮不在此阶段。

第二阶段 C 的消费者接入：[SettingsSections.swift](../AreaChain/Features/Settings/SettingsSections.swift) 的系统设置入口、通知测试、日历重试/冲突查看使用 `.quiet`，通知申请使用 `.prominent`；[ProjectSupportSections.swift](../AreaChain/Features/Settings/ProjectSupportSections.swift) 的帮助、问题报告、功能建议使用 `.quiet`，仓库/许可证使用 `.subtle`；[HotKeyRecorder.swift](../AreaChain/Features/Settings/HotKeyRecorder.swift) 的录入使用 `.quiet`、原 `listening` 时切换 `.active`，单项重置 `.subtle`；[ShortcutsSettingsView.swift](../AreaChain/Features/Settings/ShortcutsSettingsView.swift) 全部重置 `.quiet`，均为 regular。直接复用 `DaybookButtonStyle`，不设置 Form 根样式，不新增公共 API 或平行状态；业务回调、条件、禁用、通知防重入、链接交接、热键冲突/持久化/注册和监听释放保持原实现。消费者测试复用 `SystemPageHost`，快捷键同时隔离偏好及 fake `HotKeyCenter`；系统按钮仅取呈现和静态回调证据，详见[工程手册](engineering.md#第二阶段-c普通设置快捷键和项目支持按钮接入2026-10-01)。隐私主页、备份、Picker、Toggle、输入框及其他页面不在此阶段。

第二阶段 D 的消费者接入：[PrivacySettingsSection.swift](../AreaChain/Features/Settings/PrivacySettingsSection.swift) 的首次设置、标签管理、锁定/解锁、系统验证方式、主密码设置/移除、清理重试及退出使用 `.quiet`；[DataBackupView.swift](../AreaChain/Features/Settings/DataBackupView.swift) 的普通导入/导出和加密备份/恢复使用 `.quiet`，既有 destructive 重置入口使用 `.destructive`，均为 regular。只增加 14 处 `DaybookButtonStyle`，保留 Form/HStack、回调、角色、禁用、状态和原确认/密码弹窗语义；不新增主次层级、API、包装或令牌。系统 alert、confirmationDialog、NSAlert、文件面板内部按钮仍由系统承载。消费者测试复用 `PrivacyButtonConsumerTests`、`SettingsButtonTestSupport` 与 `SystemPageHost`，隔离范围和未执行链路见[工程手册](engineering.md#第二阶段-d隐私主页与数据备份页按钮接入2026-10-01)。

### 第二阶段 E：按钮接入与全应用静态清单（2026-10-01）

[DiaryPage.swift](../AreaChain/Features/Diary/DiaryPage.swift) 的 `quickComposer` 解锁使用 `.prominent`、丢弃入口使用 `.quiet`；[DayScheduleMenu.swift](../AreaChain/Features/Tasks/DayScheduleMenu.swift) 的 `DaySchedulePicker` 确认使用 `.prominent`，均为 regular，直接复用 `DaybookButtonStyle`。仅新增三行样式；指定 vault、restore/焦点、丢弃确认及角色、临时日期、`initialKey`、`confirmTitle`、`DayKey`、`onPick` 和宿主关闭/保存语义保持。日期本体不变。测试为 `DiaryButtonConsumerTests` 与 `DayScheduleButtonConsumerTests`，证据及限制见[工程手册](engineering.md#第二阶段-e剩余按钮接入与全应用清单核对2026-10-01)。

核对覆盖 `AreaChain/**/*.swift` 的 `Button`、`buttonStyle`、`Menu`、`menuStyle`、公共封装、AppKit 按钮/弹框与点击入口；可疑项沿实际父容器核对。下表路径省略 `AreaChain/`，同一文件可同时包含不同组；不是运行验收或所有间接手势链的证明。

| 组 | 文件与符号/入口 | 分类依据 |
|---|---|---|
| A 公共基座 | `Theme/DaybookButtonStyle.swift`（`DaybookIconButton` / `daybookMenuLabel`）、`CommandReturnButton.swift`；`Features/Board/BoardCommandStrip.swift`（`BoardCommandStripButton/Menu`） | 统一外观的权威实现和薄封装。 |
| A Theme 消费者 | `Theme/DaybookChrome.swift` 日期导航、`DaybookPage.swift` 提交、`SyntaxAutocompleteView.swift`、`LiveComposerPreviewHeader.swift`、`LiveDiaryComposerPreview.swift` 复制/更多 | 显式公共样式/封装；预览的历史业务边界不扩大。 |
| A 任务/手记/菜单栏 | `Features/Tasks/TaskRow+Menus.swift` 复制/更多、`TaskRow+CommandStrip.swift`、`BatchActionBar.swift` 普通操作、`BoardFilterBar.swift`；`Features/Diary/DiaryQuickComposerView.swift`、`DiaryCardComponents.swift`、`DiaryWindowView.swift`、`PrivacyUnlockPresenter.swift`、`DiarySummaryRow.swift` 复制/更多及本次两处；`Features/MenuBar/FooterBar.swift`、`MenuBarSearchResults.swift`、`MenuBarSearchField.swift` 搜索/清空、`MenuBarFilterFlyout.swift` | 使用公共按钮或公共菜单标签；菜单展开项另归 B。 |
| A 设置/剪贴板 | `Features/Settings/SettingsSections.swift`、`ProjectSupportSections.swift`、`HotKeyRecorder.swift`、`ShortcutsSettingsView.swift`、`PrivacySetupSheet.swift`、`PrivacyPasswordSheet.swift`、`PrivacySettingsSection.swift`、`DataBackupView.swift`；`Features/Clipboard/ClipboardHistoryOptions.swift`、`ClipboardHistoryPanel.swift`、`ClipboardHistoryPage.swift` | 已有 A–D 阶段接入或原公共封装。 |
| A 工作台 | `Features/Workspace/ResidentsPage.swift`、`WorkspaceHeaderBar.swift`、`WorkspaceHeaderSearch.swift` 清空、`WorkspacePendingView.swift`、`WorkspaceAllItemsView.swift` 清筛选、`WorkspaceFilteredListView.swift` 批选/父任务、`RecurringItemEditor.swift`；`TaskDetailHeaderSection.swift`、`TaskDetailDrawer.swift`、`TaskDetailSubtasksView.swift` 添加/操作、`TaskDetailNotesView.swift`、`TaskDetailClassificationSection.swift`、`TaskDetailScheduleSection.swift` 提醒、`TaskDetailDueTime.swift`、`TaskDetailSections.swift` | 显式公共样式/封装。`TagManagementPage.selectionActions` 的还原/删除/合并继承 `selectionToolbar` 样式；该证据不覆盖 sheet 或 Menu label。 |
| A 其他页面 | `Features/Dashboard/DashboardSummarySection.swift`、`DashboardActivitySection.swift`、`DashboardTrendSection.swift`、`DashboardHeatmapSection.swift`；`Features/Calendar/CalendarMonthGrid.swift`、`CalendarWeekBoard.swift`；`Features/Attachments/AttachmentBrowserPage.swift`；`Features/Search/BoardSearchHitRow.swift` 的 `.list`；`Features/Trash/TrashPage.swift` 还原/删除 | 普通操作已使用公共入口；日期/内容单元的选择行为另判断。 |
| B 系统菜单内容 | `TaskRow+Menus`、`DayScheduleMenu`、`DiaryOrganizeMenus`、`DiarySummaryRow`、`LiveDiaryComposerPreview`、`WorkspaceHeaderMenuItem`、`FooterBar`、`ClipboardHistoryPage/Browser`、`AttachmentBrowserPage` 的菜单项；下表 D 类 Menu 展开项 | 实际位于 `Menu` / `contextMenu` 中；**不据此豁免页面上的 Menu label**。 |
| B 系统确认/命令 | `Theme/TrashConfirm.swift`；`TrashPage`、`TagManagementPage`、`DiaryPage`、`DiaryWindowView`、`DiaryNoteCard`、`DataBackupView` 的 alert/confirmationDialog；`App/AreaChainApp.quitAlert/AreaChainCommands`、`Services/MutationFeedback`、`DiaryWindows.closeAlert`、`AttachmentPicker`、`PrivacySettingsSection` 的 NSAlert | 系统弹框、CommandGroup 的原生语义。`Services/StatusItemController.setupStatusItemButton` 是系统状态项；`WorkspaceHeaderSearch` 隐藏快捷键桥接不属可见外观。 |
| C 完成/日期/分段 | `Theme/ModernComponents.ModernCheckbox`、`TaskRowSubtaskMiniViews.TaskRowSubtaskInlineList`、`TaskDetailSubtasksView.toggleCheckboxButton`；`TaskDetailScheduleSection.TaskDetailWeekdayPicker`、`Theme/DaybookSegmentedBar.tabButton`、`HabitCheckMonthView.dayCell`、`TaskDetailQuadrantGrid` | 分别承担完成、星期掩码、分段滑块、日格和象限选择，不能批量改普通按钮样式。 |
| C 行/芯片/内容 | `Theme/WorkspaceLayout.WorkspaceSidebarRow`、`WorkspaceSidebarView.tagRow`、`WorkspaceGlobalSearchView.attachmentRow`、`BoardSearchHitRow.workspace`、`QuadrantPage.titleButton`；`DayBoardSections`/`WorkspaceFilteredListView.completedSection`；`Theme/DaybookChip`、`TasksPage+Header.activeFilterTag`、`MenuBarSearchField.tokenChip`；`Theme/CaptureAttributesView.CaptureAttributesButton`、`SyntaxHelpCard` 条目/`complexExampleBar`、`AttachmentThumbnails` | 导航/整行选择、折叠、状态角标、属性浮层或内容预览点击区。`DiaryNoteCard.addTagMenu` 与标签芯片并列，18pt 胶囊随已有标签切换文字/加号，留标签控件阶段。 |

**D：E 阶段记录的未接入清单（已由下述 F 阶段接入）**

| 精确入口 | E 阶段当时的证据 |
|---|---|
| [TagManagementPage.swift:316](../AreaChain/Features/Workspace/TagManagementPage.swift) `mergeSheet` 的 `Button("alert.cancel")` | 自定义 sheet 的 HStack 普通按钮，无公共样式；相邻合并按钮样式只修饰自身。 |
| [BatchActionBar.swift:145](../AreaChain/Features/Tasks/BatchActionBar.swift) `dateAdjustmentMenu` | 页面 HStack 的 Label 只有字体，未调用 `daybookMenuLabel`。 |
| 同文件 `statusAdjustmentMenu`（157 行） | 同上；展开后的系统菜单项保留。 |
| 同文件 `tagAssignmentMenu`（170 行） | 同上；标签菜单触发器没有芯片本体结构。 |
| [WorkspaceAllItemsView.swift:93](../AreaChain/Features/Workspace/WorkspaceAllItemsView.swift) `scopeMenu` | `controls` 的三处筛选菜单共用此定义；label 只有文本/字体，未继承公共菜单外观。 |
| [TagManagementPage.swift:229](../AreaChain/Features/Workspace/TagManagementPage.swift) `colorMenu` | 父级 `DaybookButtonStyle` 不等于 Menu label 接入；只有系统 `.borderlessButton`。 |

E 阶段结束时共余 1 处普通 Button、5 处 Menu 定义（`scopeMenu` 有三个呈现入口）。该历史缺口已由 F 阶段接入；系统 `.borderlessButton` 本身仍不是公共外观证据。特殊控件和间接手势不据此宣称全覆盖。

### 第二阶段 F：菜单入口与标签合并取消（2026-10-01）

上表六处均直接接入公共基座：`TagManagementPage.mergeSheet` 取消使用 `.quiet / .compact`，与相邻 `.prominent / .compact` 合并按钮配合；`colorMenu`、`BatchActionBar` 三个菜单及 `WorkspaceAllItemsView.scopeMenu` 均在原生 Menu 的 label 内容上使用 `daybookMenuLabel(size: .compact, fitsLabel: true)`，保留字体、文字、图标、menuStyle、Section 和系统展开项。

六处定义对应八个逻辑入口（取消、颜色、三个批量菜单、三个筛选）。批量菜单由 `WorkspaceBatchActionBar` 经 `MainSplitWorkspaceView` 的底部 overlay 供标签清单、待处理、全部事项三个宿主消费，共九个菜单/宿主组合，仍受能力和标签非空条件约束；全部事项有独立的事项类型、待办状态、重复事项状态三个入口。颜色工具条的横/竖布局候选是同一个逻辑入口。批量栏采用既有 `ViewThatFits` 模式：宽时横排，窄时将计数/操作、菜单、启停和说明分行，避免新增菜单边距后逐字换行或隐藏文字；不增加公共 API、状态、令牌或保存路径。

F 后复查仍沿上面的 A/B/C 分类：20 个 Menu 定义中，13 个使用公共标签、6 个属于系统展开子菜单，1 个是 `DiaryNoteCard.addTagMenu` 标签胶囊控件。未发现确定遗漏的普通按钮/页面 Menu；21 处 plain 样式继续归完成、日期、星期、象限、分段、导航行、折叠、芯片和内容选择。该结论只覆盖当前静态清单，不能代表全应用运行验收。第三阶段保留 C 类特殊控件，不在 F 迁移。

消费者回归直接挂载生产组件，复用 `SystemPageHost`、`SettingsButtonTestSupport` 及内存模型；入口为 [BatchMenuConsumerTests.swift](../AreaChainTests/Features/BatchMenuConsumerTests.swift)、[WorkspaceMenuConsumerTests.swift](../AreaChainTests/Features/WorkspaceMenuConsumerTests.swift)，菜单事件辅助仅在 [MenuButtonTestSupport.swift](../AreaChainTests/Features/MenuButtonTestSupport.swift)。真实追踪/Escape 与原菜单项动作派发分开取证，结果及剩余运行缺口见[工程手册](engineering.md#第二阶段-f菜单入口与标签合并取消2026-10-01)。

F 补修在 `TagManagementPage.body` 的合并 sheet 边界显式传递宿主 `locale`，复用相邻 `TaskDetailTagSelector` 的环境注入模式；文案键与标签原文、Picker、选择/取消/提交/保存语义不变。`WorkspaceMenuConsumerTests` 保留严格语言断言，覆盖 en/zh-Hans × 浅深色五处文案、360pt 长标签布局、实际取消无提交，以及测试环境语言切换后重开。原中文失败保留在旧包，已由 `ButtonStage2F-locale-matrix.xcresult` 和七组 `ButtonStage2F-locale-regression.xcresult` 消除；完整证据与第二阶段仍部分验收的边界见[工程手册补修记录](engineering.md#f-补修标签合并弹窗语言传递2026-10-01)。

### 第三阶段 A：公共启用开关与重复事项

[RecurringItemEditor.swift](../AreaChain/Features/Workspace/RecurringItemEditor.swift) 使用默认 `DaybookToggleStyle()`，仅修改 `draft.isEnabled`，取消不创建，保存失败保留草稿。[ResidentsPage.swift](../AreaChain/Features/Workspace/ResidentsPage.swift) 使用 `DaybookToggleStyle(hiddenLabel: "residents.enabled")`，原 `enabledBinding` → `DayBoardMutations.setRoutineEnabled`、暂停/恢复及标题失焦保存规则保持。公共组件没有统一两种提交方式。

展示仍在 `DaybookControlsPreview`，开/关、禁用、隐藏标签、长中英文、主题与外部更新使用本地合成状态。上方减弱效果预览仅针对按钮；开关只读取系统减弱动态效果。测试为 `DaybookToggleStyleTests`、`RecurringToggleConsumerTests`，复用现有原生宿主与仓储/事务失败注入；证据与缺口见[工程手册](engineering.md#第三阶段-a公共启用开关与重复事项2026-10-01)。其他 Toggle（设置、剪贴板、隐私）、普通复选框与任务完成圆圈均未迁移；后续须分别核对权限、提交、拒绝更新和焦点契约。

### 第三阶段 B：公共方形复选框与隐私标签多选

`DaybookToggleStyle(.checkbox)` 是方形多选入口，`Presentation.switchControl` 为默认滑动开关；原 `DaybookToggleStyle()` 与 `hiddenLabel:` 调用兼容。两种表现共用原生 Toggle、Binding、禁用、空格与辅助操作路径，只分开图形及标签顺序。`DaybookMetrics.Checkbox` 集中 18pt 方框、4pt 圆角和 1.5pt 勾线，点击高度仍为 28pt；只复用 `CheckmarkShape` 纯绘制，不使用任务完成业务或反悔队列，无任意颜色覆盖。

[PrivacySetupSheet.swift](../AreaChain/Features/Settings/PrivacySetupSheet.swift) 仅 `tagChoices` 替换样式。原 selected 集合、UUID、排序/过滤、初始化、lock/tag 图标、用户标签原文、busy 禁用与取消保持；切换仅修改表单选择，提交和内容保护链不变。其他隐私 Toggle 保持原生，父容器不设置样式。

展示复用 `DaybookControlsPreview`，包含选中/未选中、禁用、长中英文、浅深色和独立外部更新按钮。`DaybookToggleStyleTests` 参数化覆盖两种表现，原生 checkbox 单独作为焦点对照；`PrivacyTagChoiceTests.swift` 扩展 `PrivacyInteractionTests`，复用原 `PrivacyButtonSheetHost` 和内存宿主，只测试选择/取消/重开，不点击 Apply。阶段证据与未验项见[工程手册](engineering.md#第三阶段-b公共复选框与隐私标签选择2026-10-01)。

### 第三阶段 C：剪贴板选项布尔控件

[ClipboardHistoryOptions.swift](../AreaChain/Features/Clipboard/ClipboardHistoryOptions.swift) 的 `clipboard.ignoreUniversal`、`clipboard.plainByDefault`、`clipboard.playSound` 在隔离原生 440×560 宿主中确认为前置方形复选框，逐项接入 `DaybookToggleStyle(.checkbox)`，保留原文、字体与排列；父容器不设置样式。绑定继续调用 `session.setIgnoreUniversal` / `setPlainByDefault` / `setPlaySound`，立即保存偏好；顶部取消只 dismiss，不撤销。会话仍是唯一状态，未提交的 pattern/typeName 不因切换提交或清空。

消费者回归为 [ClipboardOptionsConsumerTests.swift](../AreaChainTests/Features/ClipboardOptionsConsumerTests.swift)，复用 `SettingsButtonTestSupport`、`SystemPageHost` 与显式传递 locale 的 `PrivacyButtonSheetHost`。会话使用本轮新建空目录、独立随机 UserDefaults suite、nil pasteboard 和无副作用 paste gate；不使用 shared/start/stage 或真实复制粘贴。持久化核对实际测试偏好、取消后重开与同 suite 新会话；证据及历史缺口见[工程手册](engineering.md#第三阶段-c剪贴板选项布尔控件2026-10-01)。Stepper、Picker、输入及按钮不迁移；普通设置和其他隐私 Toggle 继续留待后续，不能从本次证据推导权限、失败回滚或系统操作已验收。

### 第三阶段 D：普通设置布尔控件

[SettingsSections.swift](../AreaChain/Features/Settings/SettingsSections.swift) 的 `settings.login`、`settings.capture.stamp`、`settings.calendar.sync.toggle` 在真实 General/Sync 分节的隔离 grouped Form 中均呈现行尾原生滑动开关，逐项接入 `DaybookToggleStyle(.switchControl)`。原生标签仅增加 `frame(maxWidth: .infinity, alignment: .leading)`，使公共样式继续保持左侧文字、右侧滑块；保留文字、字体、标识、帮助及分组，不向父容器设置 ToggleStyle，不新增公共 API、包装或状态。

登录仍经原 `launchesAtLogin` Binding 和 `onUpdateLoginItem` 回调，由 `SettingsView` 注册/注销后回读；失败或待批准不会在控件内锁住乐观值。捕获来源与日历同步仍直接绑定 `AppPreferences`，立即保存原键并发布原进程内通知；日历布尔值只表示启用意图，不代表授权或同步成功。系统服务、权限、同步状态/冲突/重试、Picker 和按钮均未改变。

消费者测试为 [SettingsToggleConsumerTests.swift](../AreaChainTests/Features/SettingsToggleConsumerTests.swift)，复用 `SettingsButtonTestSupport`、`SystemPageHost`、原呈现/按钮/偏好与公共 Toggle 测试。仅挂载真实分节，显式注入随机 suite 的偏好与合成登录回调；不调用 CalendarSync start/refresh，进程外服务不参与。夹具恢复 `NSApp.appearance`，合成日历状态串行保存/恢复；实际证据及继承缺口见[工程手册](engineering.md#第三阶段-d普通设置布尔控件2026-10-01)。

后续仅记录：`PrivacySetupSheet` 的 `privacy.legacy.include`、`privacy.methods.system`、`privacy.methods.master` 仍为原生 Toggle，须分别核对内容保护和认证方式的表单契约；`ClipboardHistoryOptions` 的条数/文本上限 Stepper 及其他数值控件未迁移。任务完成圆圈和子任务勾选继续保持各自业务，本阶段到 D 停止。

### 第三阶段 E：隐私设置剩余布尔控件

[PrivacySetupSheet.swift](../AreaChain/Features/Settings/PrivacySetupSheet.swift) 的 `privacy.legacy.include`、`privacy.methods.system`、`privacy.methods.master` 已在生产 sheet 的隔离宿主确认均为前置方形复选框，逐项接入 `DaybookToggleStyle(.checkbox)`；系统方式、主密码方式、标签、旧遮罩选项的顺序和 480pt 表单宽度保持。`tagChoices` 原样保留，不在父容器设置样式，不新增公共 API、包装、状态或令牌。

绑定仍分别属于 `includeLegacy`、`useSystem`、`useMaster`；创建/管理初始化、系统不可用禁用和回退、密码与备份校验、候选计算、busy、取消和密码清空时机均沿原实现。切换不保存、不创建 vault、不认证或保护内容。测试为 [PrivacySetupToggleTests.swift](../AreaChainTests/Features/PrivacySetupToggleTests.swift)，直接复用 `SettingsButtonTestSupport`、`SystemPageHost`、`PrivacyButtonSheetHost`，显式 locale、内存模型/配置、合成旧内容和 fake keys；所有 sheet 均传 `probeSystem: false`，只编辑与取消，不点击 Apply。原标签与公共 Toggle 回归、实际证据及未验项见[工程手册](engineering.md#第三阶段-e隐私设置剩余布尔控件2026-10-01)。

阶段 E 定向清单：生产业务共 12 处 Toggle 定义，均已使用公共样式。重复事项 2 处与普通设置 3 处为滑动开关；剪贴板 3 处、隐私 3 处及标签循环 1 处为方形复选框。`DaybookToggleStyle` 内部 `Toggle(configuration)` 属公共实现，测试原生对照及 `DaybookControlsPreview` 控制面板另列，不机械迁移。检查时未发现并发新增的业务遗漏；该清单不证明其他手势控件已统一。下一阶段仅保留 `ClipboardHistoryOptions` 两个 Stepper、其他数值控件、任务完成圆圈与子任务勾选线索，本轮到 E 停止。

### 第三阶段 F：公共数值加减与剪贴板

[DaybookStepper.swift](../AreaChain/Theme/DaybookStepper.swift) 是 Theme 的数值加减入口，提供 `Binding<Int>` / `Binding<Double>`、闭区间、步长和 ViewBuilder 标签两个重载；整体禁用走环境。标签与当前值、辅助增减操作属于同一个语义元素。按钮复用 `DaybookButtonStyle(.icon)` 的 28pt 点击区、颜色、字号、按下与减弱效果；专用间距在 [DaybookMetrics.swift](../AreaChain/Theme/DaybookMetrics.swift) 的 `Stepper`。没有数字输入、单位选择或持久化状态。键盘桥接在 [DaybookStepperKeyboard.swift](../AreaChain/Theme/DaybookStepperKeyboard.swift)，仅保存瞬时方向信号并复用 NSStepper 响应；鼠标点击不改变相邻文本焦点。桥接同时提供内部窗口接入标记，拆卸后不能向原 Binding 继续写入；这不改变首写、数值或重复频率。

每次操作回读 Binding；原生对照确定最后一步截到端点（990/995→999，25→20），不把初值对齐步长。整数防溢出；小数保留合法中间精度，只消除本次数值运算在目标端点的舍入尾差，显示格式不参与运算。生产仅 [ClipboardHistoryOptions.swift](../AreaChain/Features/Clipboard/ClipboardHistoryOptions.swift) 的 limit / interval 两处接入：20…999 / 10 / 默认 200，0.1…2 秒 / 0.1 / 默认 0.5；继续使用原 `clipboard.limit` / `clipboard.interval` 标签。

业务范围仍由 `ClipboardHistoryRules` 维护，写入仍走 `session.setLimit` / `setInterval`。limit 立即更新偏好并尝试裁剪；历史保存失败保留旧历史、图片和错误提示，但不回滚 limit。置顶不占名额，成功才按原顺序裁剪并清理图片。interval 保存后只重排已有 monitor；取消只关闭，不撤销偏好或恢复裁剪。其他选项及未提交 pattern/typeName 保留。

展示直接扩展 `DaybookControlsPreview`；验证入口为 [DaybookStepperTests.swift](../AreaChainTests/Theme/DaybookStepperTests.swift)、[原生基线](../AreaChainTests/Theme/DaybookStepperBaselineTests.swift)、[交互测试](../AreaChainTests/Theme/DaybookStepperInteractionTests.swift) 与 [ClipboardStepperConsumerTests.swift](../AreaChainTests/Features/ClipboardStepperConsumerTests.swift)。消费者复用 ClipboardOptionsFixture 的随机目录、suite、nil pasteboard 和无副作用 gate，预写合成历史；不调用 shared/start/stage。实际证据和未验项见[工程手册](engineering.md#第三阶段-f公共数值加减与剪贴板2026-10-01)。现存日期 `.stepperField` 及任务完成等控件不迁移。

### 第四阶段 A：公共下拉选择器与剪贴板

[DaybookPicker.swift](../AreaChain/Theme/DaybookPicker.swift) 提供 `DaybookPicker<Value: Hashable>`：本地化 title、唯一 `Binding<Value>` 和 `[DaybookPickerOption<Value>]`。选项 value 同时为稳定 id，必须唯一；label 为独立 `String.LocalizationValue`，按环境 locale 解析。顺序由调用方提供，不从翻译或位置推导业务值，不提供搜索、多选、分组或注册表。

入口复用 `daybookMenuLabel` 的 regular 高度、间距/颜色/悬停，标签间距集中在 `DaybookMetrics.Picker`；原生无边框 NSPopUpButton 负责双箭头、菜单、勾选与键盘追踪，保留弹出选择器角色、名称、当前值与辅助操作。入口按最长选项预留宽度，窄窗原生尾部截断并保留完整 tooltip/菜单文字。挂载/外部更新不写；原生基线中再次选择当前项仍提交一次，setter 返回后立即回读 Binding，拒绝时恢复原选中态。空列表显示“无可用选项”并禁用；值缺失显示“当前选项不可用”的禁用占位项、无选中勾，仍允许主动选择有效项。取消、禁用、旧菜单及拆卸后的迟到动作不提交。

第四阶段 A 的生产消费者为 [ClipboardHistoryOptions.swift](../AreaChain/Features/Clipboard/ClipboardHistoryOptions.swift) 的三处：searchMode（mixed/exact/regex，默认 mixed）、panelAnchor（cursor/center，默认 cursor）、clickAction（copy/paste，默认 copy）。继续使用原标签、枚举 rawValue、areachain.clipboard 偏好键与 setSearchMode/setPanelAnchor/setClickAction；立即保存，取消只关闭，重开/重建读取偏好。公共层不接触筛选、定位、监控或复制粘贴；原 Toggle、Stepper、按钮、输入及页面 440×560 保留，单行选择高度由原生 24 调整到共享 regular 28。

展示直接扩展 [DaybookControlsPreview](../AreaChainTests/Theme/DaybookControlsPreview.swift)，保留原控制面板，新增默认、禁用、长标签及外部更新。验证为 [DaybookPickerTests](../AreaChainTests/Theme/DaybookPickerTests.swift)、[ClipboardPickerConsumerTests](../AreaChainTests/Features/ClipboardPickerConsumerTests.swift) 与原剪贴板 Toggle/Stepper 消费者；沿 ClipboardOptionsFixture 随机目录/suite、nil pasteboard、无副作用 gate，只经隔离 XCTest 启动。稳定入口由 check_workflow.py 守卫；实际证据及 Cursor verifier 缺口见[工程手册](engineering.md#第四阶段-a公共下拉选择器与剪贴板2026-10-02)。

普通设置三处已由下述第四阶段 B 接入。后续清单只登记：TagManagementPage 的合并目标；PrivacySettingsSection 的自动锁定；CalendarPage 的 calendar.span 原生分段及菜单栏 DaybookSegmentedBar 各自核对后再迁移。展示控制面板语言 Picker 仍为原生；本轮到 A 停止。

### 第四阶段 B：普通设置下拉选择器接入

[GeneralSettingsSection](../AreaChain/Features/Settings/SettingsSections.swift) 的语言、外观、四象限截断直接使用 DaybookPicker / DaybookPickerOption，分别绑定 prefs.language / appearance / quadrantTitleTruncation；保持 system/chinese/english、system/light/dark、tail/middle 的类型化身份、顺序、本地化键、辅助标识和原 grouped Form 分组/说明。没有页面镜像状态或保存包装，立即保存与通知仍由 AppPreferences 执行；语言沿 AppChrome，外观沿 applyAppAppearance，截断沿原 textTruncation。

公共选择器增加 `layout: .formRow`，在标签与 28pt 入口之间加弹性间距，并用独立辅助容器保留子菜单真实边界，以维持 Form 两端对齐；默认 `.inline` 维持 A 阶段剪贴板布局。没有任意颜色/字体参数，菜单原生桥接与提交逻辑不变。重选当前项仍提交一次，打开/Escape 取消不写入。

[SettingsPickerConsumerTests](../AreaChainTests/Features/SettingsPickerConsumerTests.swift) 与 [SettingsPickerTestSupport](../AreaChainTests/Features/SettingsPickerTestSupport.swift) 直接挂载生产分节，复用 SettingsButtonTestSupport 随机 suite/内存库和 PickerNativeTestSupport。SystemPageHost.preferenceWindow 显式注入测试 AppPreferences，通过生产 AppChrome 提供动态 locale/主题，使用与生产同类的 NSHostingController 承载环境，未固定 window.appearance；静态宿主允许注入测试偏好，未传时的默认行为保持。只经串行隔离 XCTest 启动，通知不启动真实服务，结束恢复 XCTest 进程外观。回归覆盖原 DaybookPickerTests、剪贴板 A 消费者、设置测试及 AppPreferencesTests；证据和公共 Cursor verifier 缺口见[工程手册](engineering.md#第四阶段-b普通设置下拉选择器接入2026-10-02)。formRow 的静态入口由原检查器及反例测试守卫，不能代替运行验收。

### 第四阶段 C：标签合并目标选择器接入

[DaybookPickerOption](../AreaChain/Theme/DaybookPicker.swift) 保留 `init(_ value: Value, _ label: String.LocalizationValue)`，新增 `init(_ value: Value, verbatim label: String)`。内部 Label 明确区分 localized/verbatim，只有前者调用 L10n；原文包括与本地化键同名的名称均逐字传给原生菜单、当前值、辅助值与 tooltip。`Value: Hashable` / id 仍与显示文字分离，同名选项、改名、重排和语言切换不改变稳定身份。inline 默认布局、formRow、禁用、拒绝写入回读、旧菜单拒绝、拆卸清理及空/缺失值占位不变；挂载和选项变化不自动写回第一项，没有新显示闭包或桥接。

唯一新增生产消费者是 [TagManagementPage.mergeSheet](../AreaChain/Features/Workspace/TagManagementPage.swift)：`ordinarySelection.map { .init($0.id, verbatim: $0.name) }` 保留原过滤与顺序，原 mergeTarget Binding、beginMerge 初始选择、360pt 宽度、显式 locale 和按钮样式不变。选择只改本地 UUID，取消不保存，重开重新初始化；点击合并仍调用原 commitMerge → DayBoardMutations → SwiftDataCatalogRepository → Catalog。用户名称不翻译，字段标题与空/不可用提示仍本地化。现有 UUID 缺省、目标校验和失败处理没有调整。

测试复用 DaybookPickerTests（[原文扩展](../AreaChainTests/Theme/DaybookPickerVerbatimTests.swift)）、[WorkspaceMenuConsumerTests](../AreaChainTests/Features/WorkspaceMenuConsumerTests.swift) 的原合并 sheet 宿主、PickerNativeTestSupport 与 TagCatalogTests / TagRepositoryTests；合成提交仅使用内存普通标签、事项、子任务、重复事项和普通手记。展示沿 [DaybookControlsPreview](../AreaChainTests/Theme/DaybookControlsPreview.swift) 增加原文例子。原检查器只增加 verbatim 稳定入口和反例，不代替运行验证。证据与指定 Cursor verifier 缺口见[工程手册](engineering.md#第四阶段-c标签合并目标选择器接入2026-10-02)。自动锁定和分段切换仍留后续；B 的 dark→system、H 两项及 Stepper 长按差异仍保留。

### 第四阶段 D：自动锁定时长选择器接入

[PrivacySettingsSection.configuredControls](../AreaChain/Features/Settings/PrivacySettingsSection.swift) 的 `privacy.autolock` 直接接入 DaybookPicker / DaybookPickerOption，使用既有 `.formRow` 维持 grouped Form 两端布局。选项依次为 60 / 300 / 900 **秒**，文案仍为 privacy.idle.1 / privacy.idle.5 / privacy.idle.15；字段、辅助标识、systemPageMarker、分组和整组禁用保留，没有公共 API 或配置格式变化。

原 Binding 全文保持：读取 vault.idleSeconds，经 run → authenticate → vault.setIdleSeconds 提交。authenticate 仍向原 PrivacyUnlockPresenter 传 force: true 和指定 vault；已解锁也必须重新认证，busy 防重入、取消锁定、错误反馈、成功后保存及配置失败恢复仍属于原页面/服务。公共控件不缓存候选时长，不去重认证，也不拥有配置或权限。

[PrivacyAutolockPickerTests](../AreaChainTests/Features/PrivacyAutolockPickerTests.swift) 与[隔离支持](../AreaChainTests/Features/PrivacyAutolockTestSupport.swift) 复用 PrivacyFixture、MemoryVaultConfigurationStore、FakeSystemVaultKeys、SettingsButtonTestSupport 和原 PickerNativeTestSupport，直接挂载生产隐私页及原 Presenter。内存模型、独立偏好、fake 等待/失败和仅本例面板清理保证隔离；长字段样例只算公共 formRow 布局证据。基线、认证/保存回读、强制 NSMenu 派发的取证限制及历史缺口见[工程手册](engineering.md#第四阶段-d自动锁定时长选择器接入2026-10-02)。没有新验证执行器或展示应用。

D 后生产源码的普通原生下拉 Picker 未发现剩余项；原生 Picker 仅余 CalendarPage 的 calendar.span 分段，菜单栏 MenuBarPopoverView+Header 仍调用 DaybookSegmentedBar。两者保留各自切换/焦点/宿主契约，未在本轮迁移；测试展示的语言 Picker 不属生产遗漏。

## 3. Feature 级复合组件

这些不是全局通用控件，而是带业务语义的可复用组合。新入口优先复用它们的状态和回调契约，不复制内部筛选或保存逻辑。

| 领域 | 入口 | 文件 | 复用边界 |
|---|---|---|---|
| 任务清单 | `TaskRow`、`TaskRowState`、`DayBoardList` | [TaskRow.swift](../AreaChain/Features/Tasks/TaskRow.swift)、[TaskRowState.swift](../AreaChain/Features/Tasks/TaskRowState.swift)、[DayBoardList.swift](../AreaChain/Features/Tasks/DayBoardList.swift) | 任务/子任务展示、选择、键盘和完成反馈；不要在新页面另写父子级联或重复事项完成规则。`TasksPage` 与 `DayBoardList` 各自一次 body 只建一份 `DayBoardPageProjection` / `DayBoardListIdentity`，父子不共享。筛选、空态和计数断言走 `DayBoardPageProjection.project`，不要从 `TasksPage` 再投影一次。行上连击和附件走该次索引，不要每行再扫 checks 或附件表。今日和浮层任务清单由 `TasksPage` 滚动：短清单只把内容的最小高度铺满视口，便于点空白取消选中；条目超出视口时内容继续增高，不能把高度固定成视口。今日清单多选后，空格和 Delete 只动焦点行。 |
| 行铬与命令条 | `BoardRowChrome`、`BoardCommandStrip` | [BoardRowChrome.swift](../AreaChain/Features/Board/BoardRowChrome.swift)、[BoardCommandStrip.swift](../AreaChain/Features/Board/BoardCommandStrip.swift) | 任务行与手记摘要/卡片共用悬停、选中和快捷操作条；不要在新行控件再写一套铬层。 |
| 回收确认 | `PendingTrash`、`confirmMoveToTrash` | [TrashConfirm.swift](../AreaChain/Theme/TrashConfirm.swift) | 任务、手记、附件、工作台清单和回收站共用确认绑定；不要再做一个平行的删除确认状态。 |
| 手记清单 | `DiaryPageListModel`、`DiarySummaryRow`、`DiaryNoteCard` | [DiaryPageListModel.swift](../AreaChain/Features/Diary/DiaryPageListModel.swift)、[DiarySummaryRow.swift](../AreaChain/Features/Diary/DiarySummaryRow.swift)、[DiaryNoteCard.swift](../AreaChain/Features/Diary/DiaryNoteCard.swift) | `DiaryPage` 一次 body 只建一份 `DiaryPageListModel`：`parseQuery`、活条目、标签计数、`listedDiaries` 和 `DiaryPrivacy.isSensitive`。空查询仍列出全部未删除项，不与搜索 `hits` 空结果对齐，也不读保险箱；`!优先级`/`@时刻` 整组退出。行上不要再 snapshot 或重跑 `isSensitive`。键盘事件会另建一份，不与 body 共享。不改捕获保存、快捷键或解锁语义。 |
| 任务筛选 | `BoardFilterBar`、`BoardFilterChoices` | [BoardFilterBar.swift](../AreaChain/Features/Tasks/BoardFilterBar.swift)、[BoardFilterChoices.swift](../AreaChain/Features/Board/BoardFilterChoices.swift) | 使用 `BoardFilter` 的现有字段和交集语义；手记入口不能伪造任务属性。标签、优先级、提醒和来源经 `BoardFilterCodec` 写入偏好，日期范围不写入。 |
| 工作台清单 | `WorkspaceItemsList`、`WorkspaceHeaderBar`、`WorkspaceSidebarRow` | [WorkspaceItemsList.swift](../AreaChain/Features/Workspace/WorkspaceItemsList.swift)、[WorkspaceHeaderBar.swift](../AreaChain/Features/Workspace/WorkspaceHeaderBar.swift)、[WorkspaceLayout.swift](../AreaChain/Theme/WorkspaceLayout.swift) | 复用工作台布局、搜索入口、页头和侧栏状态；不在页面内创建第二套导航状态。`WorkspaceItemsList` 自己滚动，页头和筛选留在外面，调用方不要再套一层 `ScrollView`。一次 body 只建一份 `WorkspaceItemsListIdentity`：UUID 查表、`DayBoardCheckIndex`、`TaskCatalogContext` 和连击。行上不要再 `compactMap` checks 或 `first(where:)` 找回模型。待处理/全部事项先各建一份页面模型再交给清单；标签专属清单仍用 `WorkspaceFilteredListView` 自己的滚动。失效条件是当前入参，不是跨 body 可变缓存。 |
| 检查器 | `TaskDetailDrawer`、子任务/备注/截止/月历 | [TaskDetailDrawer.swift](../AreaChain/Features/Workspace/TaskDetailDrawer.swift)、[TaskDetailSubtasksView.swift](../AreaChain/Features/Workspace/TaskDetailSubtasksView.swift)、[TaskDetailDueTime.swift](../AreaChain/Features/Workspace/TaskDetailDueTime.swift)、[HabitCheckMonthView.swift](../AreaChain/Features/Workspace/HabitCheckMonthView.swift) | 保留草稿、取消、失败、外部修改和隐私行为；不要复制保存会话。截止时刻只在待办检查器，不进提醒或日历。习惯月历只切换检查日。子任务拖动走 `ManualOrder`，令牌前缀与清单排序分开。 |
| 菜单栏 | `MenuBarPopoverView`、`CaptureField`、`MenuBarSearchField`、`MenuBarFilterFlyout` | [MenuBarPopoverView.swift](../AreaChain/Features/MenuBar/MenuBarPopoverView.swift)、[CaptureField.swift](../AreaChain/Features/MenuBar/CaptureField.swift)、[MenuBarSearchField.swift](../AreaChain/Features/MenuBar/MenuBarSearchField.swift)、[MenuBarFilterFlyout.swift](../AreaChain/Features/MenuBar/MenuBarFilterFlyout.swift) | 任务/手记草稿、焦点、快捷键和窗口关闭策略由现有状态对象管理；不要把浮层当成普通页面复制。 |
| 搜索结果 | `BoardSearchHitGroups`、`BoardSearchHitRow`、`WorkspaceGlobalSearchView`、`SearchResultsView` | [BoardSearchHitRow.swift](../AreaChain/Features/Search/BoardSearchHitRow.swift)、[WorkspaceGlobalSearchView.swift](../AreaChain/Features/Workspace/WorkspaceGlobalSearchView.swift)、[SearchResultsView.swift](../AreaChain/Features/Search/SearchResultsView.swift) | 分组与命中行共用；打开方式由调用方决定。没有独立搜索页。工作台顶栏用 `BoardSearchHitGroups`（`presentation: .workspace`）就地打开检查器。`SearchResultsView` 只服务菜单栏，打开任务走日历。不要把菜单栏路由复制进工作台。工作台和菜单栏一次 body 先 `parseQuery`，空查询不建 snapshot；非空才 map snapshot 并 `hits(parsed)`。附件文件名复用同一份 `textKeywords`。含 `!优先级`/`@时刻` 的查询不建手记 snapshot。打开附件只 snapshot 命中的那一条拥有者，不整表 map 后再 `first(where:)`。每个字符仍会因 query 变化重算，但同一次 body 不再重复解析。 |
| 日历 | `CalendarPage`、`CalendarMonthGrid`、`CalendarWeekBoard` | [CalendarPage.swift](../AreaChain/Features/Calendar/CalendarPage.swift)、[CalendarMonthGrid.swift](../AreaChain/Features/Calendar/CalendarMonthGrid.swift)、[CalendarWeekBoard.swift](../AreaChain/Features/Calendar/CalendarWeekBoard.swift) | 使用 `DayKey` 和已有日计数；月/周切换只在日历页。只允许临时待办拖到另一天或另一周列，不能复制同步规则。行上排序放下在没有排序项时不安装，避免挡住周列改期。 |
| Dashboard | `DashboardView` 及其统计/热力图分节 | [DashboardView.swift](../AreaChain/Features/Dashboard/DashboardView.swift) | 使用既有投影和日期统计；Dashboard 不是第二个可编辑事项清单。一次 body 只建一份 `DashboardSnapshot`；热力列分组在 `DashboardHeatmapLayout` 内只切一次。 |
| 剪贴板历史 | `ClipboardHistoryBrowser`、`ClipboardHistorySession` | [ClipboardHistoryBrowser.swift](../AreaChain/Features/Clipboard/ClipboardHistoryBrowser.swift)、[ClipboardHistorySession.swift](../AreaChain/Services/ClipboardHistorySession.swift) | 工作台「内容 → 剪贴板」和剪贴板历史小窗共用这一份会话。忽略、排序、搜索、置顶字母和条数只走 `ClipboardHistoryRules`。历史不跟隐私锁走。不要把历史写成待办，也不要并进 `ClipboardCapture`。菜单栏 Option 单击只切换记录开关，普通点击仍开关浮层。 |

工作台公共顶栏由 [WorkspaceHeaderContent.swift](../AreaChain/Features/Workspace/WorkspaceHeaderContent.swift) 的 `WorkspaceHeaderAction` / `workspaceHeader` 传递页面动作和动态状态，`WorkspaceHeaderBar` 只负责呈现与固定优先级收纳，搜索输入 `WorkspaceHeaderSearchCapsule` 在 [WorkspaceHeaderSearch.swift](../AreaChain/Features/Workspace/WorkspaceHeaderSearch.swift)。今日、待处理、日历、标签清单、标签管理、剪贴板、回收站提供各自原有操作；其他页面只用公共标题/帮助。`workspaceInspectorTargets` 由今日、待处理、全部事项、日历、安排、四象限、标签清单和搜索登记当前投影对象。回归见 `WorkspaceHeaderStateTests`、`WorkspaceHeaderInteractionTests`、`WorkspaceRenderingTests`，并覆盖菜单栏和独立输入宿主。菜单文字点击区复用 `daybookMenuLabel(fitsLabel: true)`，默认仍是原有图标正方形；`DaybookPeriodBar.todayLabel` 默认回到今天，安排页显式回到本月。`DaybookProgressRing.showsPercentage` 默认保留百分比，顶栏紧凑进度只关掉环内数字，旁边保留完成数/总数。

## 4. 领域、服务与变更入口

| 语义 | 权威入口 | 文件 | 规则 |
|---|---|---|---|
| 指令目录与参数 | `CommandCatalog.standard`、`CommandDescriptor`、`CommandParameter`、`CommandCatalogValidation`、`CommandArgumentValidation` | [CommandCatalog.swift](../AreaChain/Domain/CommandCatalog.swift)、[CommandDescriptor.swift](../AreaChain/Domain/CommandDescriptor.swift)、[CommandParameter.swift](../AreaChain/Domain/CommandParameter.swift)、[CommandCatalogValidation.swift](../AreaChain/Domain/CommandCatalogValidation.swift)、[CommandArgumentValidation.swift](../AreaChain/Domain/CommandArgumentValidation.swift) | 阶段 1A 的唯一纯领域目录；当前消费者仅 Domain 契约测试，后续解析、补全、草稿须复用稳定 ID、参数和能力声明。范围不限制全局指令发现，特殊选择器必须解释限制。全部适配未接线；结构校验不是业务权限或真实对象校验。完整映射、命名与证据只在[权威设计](unified-search-commands.md#96-阶段-1a-目录决策与证据)维护。 |
| 指令路径与补全 | `CommandPathParser`、`CommandPathResult`、`CommandPathCandidate` | [CommandPathParser.swift](../AreaChain/Domain/CommandPathParser.swift)、[CommandPathResult.swift](../AreaChain/Domain/CommandPathResult.swift) | 1B-1 纯领域独立输入，复用上述目录/参数与 TagSyntax 保护区间；当前仅 CommandPathTests / CommandPathConflictTests 消费。UTF-16 局部替换只生成编辑意图；规则和 partial 验收见[权威设计](unified-search-commands.md#97-阶段-1b-1-指令路径解析与补全)。 |
| 日期 | `DayKey` | [DayKey.swift](../AreaChain/Domain/DayKey.swift) | 使用民事日期语义；不要用 UTC 时间戳替代日键。 |
| 解析 | `NaturalLanguageParser`、`TagSyntax` | [NaturalLanguageParser.swift](../AreaChain/Domain/NaturalLanguageParser.swift)、[TagSyntax.swift](../AreaChain/Domain/TagSyntax.swift) | 任务、习惯、手记和剪贴板的输入契约分别核对；搜索不创建标签。 |
| 筛选/搜索 | `BoardFilter`、`BoardFilters`、`BoardSearch` | [Classification.swift](../AreaChain/Domain/Classification.swift)、[BoardPage.swift](../AreaChain/Domain/BoardPage.swift)、[BoardSearch.swift](../AreaChain/Domain/BoardSearch.swift) | 关键词与结构化筛选取交集；日清单和昨天/即将芯片用 `matchesListedRow`，不要在页面再写一套日期判断。逾期筛选下一次 `hits` 对入围习惯只调一次 `AgendaProjection.overdueRoutines`，不为每个习惯重建闭合索引。`hits` 可吃已解析的 `BoardSearchQuery`；手记命中共用一次 `TagNameIndex`，不为每条手记再规范化标签名。手记页列表走 `listedDiaries`：空查询返回全部未删除项，与 `hits` 空查询返回 [] 不同。 |
| 待处理投影 | `AgendaProjection` | [AgendaProjection.swift](../AreaChain/Domain/AgendaProjection.swift) | 逾期、即将、当前/下一排定日和批量能力使用同一投影。 |
| 日看板投影 | `DayBoardPageProjection`、`DayBoardDayProjection`、`DayBoardCheckIndex` | [DayBoardPageProjection.swift](../AreaChain/Domain/DayBoardPageProjection.swift)、[DayBoardCheckIndex.swift](../AreaChain/Domain/DayBoardCheckIndex.swift) | 今日清单、昨天/即将芯片和当日 open/done 共用一份快照与 first-wins 闭合索引。失效条件是传入的 routines/checks/todos 或筛选变化，不是跨 body 的可变缓存。`TasksPage` 嵌套 `DayBoardList` 时各自建一份，不把结果跨视图缓存。 |
| 总览投影 | `DashboardProjection`、`DashboardSnapshot` | [DashboardProjection.swift](../AreaChain/Domain/DashboardProjection.swift)、[DashboardModels.swift](../AreaChain/Domain/DashboardModels.swift) | 今日、趋势、热力图和活动只用这一份；视图不另写公式。日统计在一次 `project` 里共用闭合日键和打卡索引。快照值与计算分文件，只为遵守单文件行数上限。`DashboardView` 把这一份快照绑在 body 局部常量上，不要用计算属性让每个分节再投影一次。 |
| 标签清单 | `Catalog` | [Catalog.swift](../AreaChain/Domain/Catalog.swift) | 标签匹配、附件聚类和标签清单口径只用这一份。`matchingListedRoutines` / `openCount` 对当天打卡做 first-wins 闭合集合；闭合语义与看板相同，不走待处理「任一条闭合」。活附件按拥有者分组走 `CatalogAttachmentIndex`，不要每行再扫整表。 |
| 任务变更 | `DayBoardMutations` | [DayBoardMutations.swift](../AreaChain/Features/Tasks/DayBoardMutations.swift)、[DayBoardMutations+Batch.swift](../AreaChain/Features/Tasks/DayBoardMutations+Batch.swift) | 完成、打卡、标签、改期、回收站和批量动作沿现有事务入口。 |
| 附件拥有者 | `AttachmentAccess`、`AttachmentOwnerIndex` | [DiaryPrivacy.swift](../AreaChain/Domain/DiaryPrivacy.swift) | 回收站/浏览按 owner key 走 context predicate；工作台搜索拥有者仍用整表清单建索引，附件只 `@Query` 活行。选图/保存走同一套 id descriptor。重复 UUID 不可用。不能用「未删除 ID 集合」替代 `isSingleLive`。 |
| 事务和通知 | `ModelChanges` | [ModelChanges.swift](../AreaChain/Services/ModelChanges.swift) | 保存成功后才发布变更；失败保留草稿和用户上下文。 |
| 窗口路由 | `AppWindows`、`DiaryWindows` | [AppWindows.swift](../AreaChain/Services/AppWindows.swift)、[DiaryWindows.swift](../AreaChain/Features/Diary/DiaryWindows.swift) | 工作台、菜单栏和手记小窗沿既有激活/复用策略，不新增平行窗口装配。设置从应用菜单、⌘, 和浮层进入工作台设置页。 |
| 项目支持 | `ProjectSupport` | [ProjectSupport.swift](../AreaChain/Domain/ProjectSupport.swift) | 版本、使用说明、问题报告、功能建议、仓库和许可证链接只用这一份。问题报告只含应用版本、构建号、macOS 版本和界面语言，不接收手记、附件或密码。 |
| 快捷键 | `ShortcutCatalog`、`ShortcutStore` | [ShortcutCatalog.swift](../AreaChain/Domain/ShortcutCatalog.swift)、[ShortcutStore.swift](../AreaChain/Services/ShortcutStore.swift) | 可重设组合、默认值和冲突只在目录里决定。全局热键默认不绑定，只在打开浮层、剪贴板加今天、全局打开工作台和剪贴板历史之间互相占用；应用内命令单独占用。浮层与剪贴板加今天仍用原来的 UserDefaults 键，缺键表示未设置。方向键、空格、回车、Delete、Esc 和备注 ⌘Return 不进目录。 |

## 5. 新组件决策清单

新功能需要一个看起来相似的控件时，按以下顺序回答：

1. 是否只是颜色、尺寸、文字或状态变化？优先使用现有令牌或现有基座的参数。
2. 是否已有同一业务语义的 Feature 组件？复用它的状态和回调，不复制内部规则。
3. 是否只有一个消费者？留在所属 Feature，并用具体名称表达职责。
4. 是否有多个真实消费者且契约完全相同？再提取到合适的共享层。
5. 新组件是否会引入新的持久化状态、快捷键、焦点或保存语义？若会，先做架构/契约评估，不能仅以“控件复用”名义加入。
6. 新增后必须补：调用方列表、边界测试、双语/主题验证（若可见）和本目录条目。

禁止事项：

- 不为一个页面复制 `DaybookInputShell`、`BoardFilter`、`ModelChanges` 或 `DayKey` 的替代实现。
- 不在 Feature 中写裸颜色、字号、圆角、阴影或第二套按钮样式。
- 不把 `Theme` 中的业务复合预览、持久化或隐私决策继续扩散到新宿主。
- 不因组件名称相似就跨越任务、手记、搜索和菜单栏的提交契约。

## 6. 目录维护

修改共享组件、公共规则或路由时，必须同步检查：

- 本目录中的文件链接和契约描述；
- 所有真实消费者及其定向测试；
- `docs/architecture.md` 的分层边界（若责任发生变化）；
- `python3 -B scripts/check_workflow.py` 和受影响测试。

本目录是冷启动导航的单一入口之一，不记录一次性任务的临时方案，也不替代产品文档和测试结果。

统一搜索 1B-2A 的纯领域查询契约：`ContentQueryParser` / `ContentQuery`（[结构](../AreaChain/Domain/ContentQuery.swift)、[解析](../AreaChain/Domain/ContentQueryParser.swift)）、`ContentQueryDates`（[日期](../AreaChain/Domain/ContentQueryDates.swift)）、`ContentQueryScopeContract` / `ContentQueryApplicability`（[范围与字段](../AreaChain/Domain/ContentQueryScope.swift)）。由 `ContentQueryTests` / `ContentQueryContractTests` 及下述 1B-2B reducer 和测试消费；复用 CommandPath、TagSyntax、DayKey、PriorityToken 与提醒规则，没有接 BoardSearch 或真实提供者。来源与边界见[权威设计第 9.8 节](unified-search-commands.md#98-阶段-1b-2a内容查询语法范围与日期契约)。

统一搜索 1B-2B 新增 [ContentQueryPageContext / Mapping](../AreaChain/Domain/ContentQueryPageContext.swift)、[ContentQueryCondition](../AreaChain/Domain/ContentQueryCondition.swift)、[ContentQuerySession / Event / Intent](../AreaChain/Domain/ContentQuerySession.swift)、[ContentQueryReducer](../AreaChain/Domain/ContentQueryReducer.swift) 与 [PageProjection](../AreaChain/Domain/ContentQueryPageProjection.swift)。复用既有解析、范围、日期、BoardFilter 和 ItemsListing 枚举，只由三份对应 Domain 测试消费；原始文本、条件来源、访问寿命与 extended 投影不能通过旧 BoardFilter 有损往返。没有生产页面、操作草稿或执行接线；提供者要求和 partial 验收见[权威设计第 9.9 节](unified-search-commands.md#99-阶段-1b-2b页面查询上下文与纯状态转移)。

统一搜索 1C-1 的 [CommandDraft / Stamp / Check](../AreaChain/Domain/CommandDraft.swift)、[CommandDraftTargets / Baseline](../AreaChain/Domain/CommandDraftTargets.swift)、[CommandDraftSession / Reducer](../AreaChain/Domain/CommandDraftSession.swift)、[CommandHostSession](../AreaChain/Domain/CommandHostSession.swift) 复用目录、参数和查询会话；新增真实消费者为 CommandDraftTests、CommandDraftProtectionTests、CommandHostSessionTests。固定目标、原值和版本保护仅在 Domain，正文只由操作参数持有；retained 可枚举恢复但不是执行队列。没有生产 UI、保存或隐私接线，1C 分阶段边界与 partial 证据见[权威设计第 9.10 节](unified-search-commands.md#910-阶段-1c-1操作草稿固定目标与编辑保护)。

统一搜索 1C-2 的 [CommandPlan / Item / Snapshot](../AreaChain/Domain/CommandPlan.swift)、[CommandPlanValidation](../AreaChain/Domain/CommandPlanValidation.swift)、[CommandPlanSemantics](../AreaChain/Domain/CommandPlanSemantics.swift)、[CommandExecutionContract](../AreaChain/Domain/CommandExecutionContract.swift) 和 [CommandExecutionRun](../AreaChain/Domain/CommandExecutionRun.swift) 经原 [CommandHostSession](../AreaChain/Domain/CommandHostSession.swift) 组合。复用原草稿、参数、固定目标与基线；显式转移所有权，retained 不自动入队。新消费者为 CommandPlanOwnershipTests / CommandPlanDependencyTests / CommandPlanMergeTests / CommandExecutionTests / CommandAtomicPlanTests；已有草稿、宿主、目录、参数和查询回归继续执行。纯状态协议不授予执行、事务、重试或撤销能力，全部目录仍 unwired；唯一契约与 partial 证据见[权威设计第 9.11 节](unified-search-commands.md#911-阶段-1c-2待执行计划依赖与纯生命周期协议)。

统一搜索 1C-3 的 [CommandHandoffCoordinator](../AreaChain/Domain/CommandHandoffCoordinator.swift) 和 [票据/所有权/宿主事件契约](../AreaChain/Domain/CommandHandoffContract.swift) 复用上述 HostSession、DraftSession、Plan、ExecutionRun 和 ContentQuerySession / Reducer。仅增加运行内唯一登记、双方原子接管、身份/引用迁移及冻结查询来源；没有窗口、执行器或权限持久化。实际消费者是 CommandHandoffTests / CommandHandoffIdentityTests / CommandHandoffBoundaryTests / ContentQueryHandoffTests；后续生产入口必须验证同一协调者的 lease，值副本不授予提交能力。资格、资源确认、源撤权与 partial 证据见[权威设计第 9.12 节](unified-search-commands.md#912-阶段-1c-3跨入口主动转交与唯一所有权)。

阶段 1D 复用以上接口新增四套领域集成测试，不新增生产入口；CommandPlan 的多消费者旧引用修复及 CommandValue 描述脱敏、最终验证和阶段 2 交接只维护在[权威设计第 9.13 节](unified-search-commands.md#913-阶段-1d领域链路集成验证与最小修正)。产品、真实执行和提供者仍未接线。

统一搜索 2A 新增 [TodoQueryProvider.read](../AreaChain/Domain/TodoQueryProvider.swift)、[请求/结果/命中依据](../AreaChain/Domain/TodoQueryRead.swift) 及 [TodoQueryMatching](../AreaChain/Domain/TodoQueryMatching.swift)。消费者仅为四套 TodoQuery Domain 测试；输入沿 Session 有效条件和 TodoSnapshot，结果为 live todo 子集。直接复用 BoardSearch.matches、TagSyntax/TagIDList、日期/范围/适用性和原页面投影；[ItemsListing.hasTag](../AreaChain/Domain/ItemsListing.swift) 由原列表与新提供者共用，Classification.matchesDate 的注入 Calendar 默认值兼容旧调用。未知条件/辅助数据不得放宽结果，重复身份隔离，正文描述脱敏；真实库/UI/执行未接入。支持清单、诊断及后续复用仅维护在[权威设计第 9.14 节](unified-search-commands.md#914-阶段-2atodo-只读快照提供者与类型化结果)。

统一搜索 2B 新增 [SubtaskQueryProvider.read](../AreaChain/Domain/SubtaskQueryProvider.swift)、[请求/结果/覆盖与诊断](../AreaChain/Domain/SubtaskQueryRead.swift) 和 [SubtaskQueryMatching](../AreaChain/Domain/SubtaskQueryMatching.swift)，只由五套 SubtaskQuery Domain 测试消费。自身标题/标签/完成态/创建时间与父级日期及类型化页面约束分开；身份为 subtask＋自身 UUID，另带父 todo 引用。2A / 2B 共用 [ContentQuerySnapshotMatching / Validation](../AreaChain/Domain/ContentQuerySnapshotMatching.swift) 的值匹配与校验、[TodoQueryPageRules](../AreaChain/Domain/TodoQueryPageRules.swift) 的父项页面入围；原 ContentQueryMatchEvidence 等类型继续留在 TodoQueryRead.swift，仅增 parent 字段。真实消费者回归包含原四套 TodoQuery 测试，没有仓储/UI/执行接线；规则、完整性、缺口和证据见[权威设计第 9.15 节](unified-search-commands.md#915-阶段-2b活子任务独立结果的只读快照提供者)。

统一搜索 2B-R 扩展 [ContentQueryTypeAnalysis / TypeValidation](../AreaChain/Domain/ContentQueryTypeAnalysis.swift)、[页面字段绑定](../AreaChain/Domain/ContentQueryScope.swift) 和 [taskPriority 页面谓词](../AreaChain/Domain/ContentQueryCondition.swift)，由 Session、todo/subtask 提供者及 ContentQueryTypeAnalysisTests / ContentQueryPagePriorityTests 消费。结构诊断与按类型语义分析分离，旧匹配算法、页面映射/投影、Reducer 与转交继续复用；响应不以空 matches 代替状态或覆盖。对象字段、兼容变化与保留缺口只维护在[权威设计第 9.16 节](unified-search-commands.md#916-阶段-2b-r父级页面条件与按类型可满足性)。

统一搜索 2C-1 在原 Parser / Validation / Session / TypeAnalysis 扩展 on/skipped；[ContentQueryOccurrenceDay](../AreaChain/Domain/ContentQueryOccurrenceDay.swift) 保留唯一执行日，独立于 [ContentQueryDateWindow](../AreaChain/Domain/ContentQueryDateWindow.swift) 的 date 窗口。[RoutineCheckReading / Coverage](../AreaChain/Domain/RoutineCheckReading.swift) 归并注入记录并报告不完整/重复/冲突；[RoutineScheduleEvidence / History](../AreaChain/Domain/RoutineScheduleEvidence.swift) 和 [RoutineQueryEvaluation](../AreaChain/Domain/RoutineQueryEvaluation.swift) 组合有界历史证据、日期存在性和单日状态。新读取接口仅由四套 Domain 测试消费；原 todo/subtask 提供者负责拒绝新不适用条件。旧看板/逾期索引、CheckSnapshot 和仓储写入均不接新归并器。2C-2 输入与 partial 证据只维护在[权威设计第 9.17 节](unified-search-commands.md#917-阶段-2c-1习惯执行日历史证据与只读状态契约)。

统一搜索 2C-2 新增 [RoutineQueryProvider.read](../AreaChain/Domain/RoutineQueryProvider.swift)、[请求/定义结果/诊断](../AreaChain/Domain/RoutineQueryRead.swift)、[匹配器](../AreaChain/Domain/RoutineQueryMatching.swift) 与[旧页面适配](../AreaChain/Domain/RoutineQueryPageRules.swift)，仅由 RoutineQueryProviderTests / RoutineQueryTemporalTests / RoutineQueryPageTests / RoutineQueryBoundaryTests 消费。复用完整 Session、类型分析、快照值匹配、2C-1 的有界历史与记录读取、Classification/ItemsListing/AgendaProjection；最小追加公共命中字段及存在性原因，todo/subtask 和旧投影回归同步验证。支持/不确定性/旧页面边界与 partial 证据只在[权威设计第 9.18 节](unified-search-commands.md#918-阶段-2c-2习惯定义只读快照提供者)维护，不接仓储/UI/执行。

统一搜索 2D 新增 [DiaryQueryProvider.read](../AreaChain/Domain/DiaryQueryProvider.swift)、[请求/安全投影/覆盖/诊断](../AreaChain/Domain/DiaryQueryRead.swift)、[匹配器](../AreaChain/Domain/DiaryQueryMatching.swift) 和[局部三态/敏感判定](../AreaChain/Domain/DiaryQueryEvaluation.swift)，实际消费者仅五套 DiaryQuery Domain 测试。复用 DiarySnapshot、DiaryPrivacy、完整 Session/Applicability/日期窗口、快照值匹配和 TagSyntax/TagIDList；contentTypes 最小允许 diary，公共命中字段仅追加 diaryBody/diaryDay，已有提供者同步回归。隐藏分支没有正文或正文证据存储位，未知对象与类型覆盖/严重度分开。输入辅助事实、旧行为差异、指定复核 partial 与后续真实适配只见[权威设计第 9.19 节](unified-search-commands.md#919-阶段-2d手记只读快照提供者)；不接真实库、vault、UI、附件或执行。

统一搜索 2E-1 的 [ImageAssociationReader](../AreaChain/Domain/ImageAssociationReader.swift)、[输入与覆盖](../AreaChain/Domain/ImageAssociationRead.swift)、[拥有者解析](../AreaChain/Domain/ImageOwnerResolution.swift)及[所属属性投影](../AreaChain/Domain/ImageOwnerProjection.swift)只由四套 ImageAssociation / AttachmentBrowseCompatibility 领域测试消费，为后续图片与记录 has:image 提供类型化基础；尚未接提供者或 UI。[AttachmentBrowseFacts](../AreaChain/Domain/AttachmentBrowseFacts.swift)由原 AttachmentAccess.canBrowse 和新读取器共用，旧实际消费者仍是附件中心、工作台搜索与相关列表。完整性、墓碑、公开/受保护及后续接口只维护在[权威设计第 9.20 节](unified-search-commands.md#920-阶段-2e-1类型化图片拥有者关联完整性与只读可浏览投影)，不能拿活 UUID 集合或可浏览列表推导 has:image 的否定。

### 第三阶段 G：公共任务完成控件与行内子任务

公共入口仍为 [ModernCheckbox](../AreaChain/Theme/ModernComponents.swift)，`isDone/action` 旧调用兼容，新增 `presentation: .inlineSubtask`。默认 `.task` 保留圆圈 17、点击框 20、1.5 边框/1.8 勾线、0.5 纵偏移及原悬停/点击缩放；行内子任务保留圆圈 12、点击框 14、1.2 边框/1.4 勾线，无主任务缩放与悬停改色。尺寸集中在 [DaybookMetrics.Completion](../AreaChain/Theme/DaybookMetrics.swift)，没有颜色覆盖或第二份完成态。圆圈、CheckmarkShape、状态色及矩形命中共用；两种表现各点击一次调用 action、触感各一次；辅助激活动作显式转接同一入口，并受 isEnabled 守卫。系统减弱效果与已有展示环境值只影响动效，不改变提交。原子任务空心图形的 AX 范围为 12，中心合成鼠标点击未命中；本次共用 contentShape 后 14pt 点击框含空心区域，这是明确的命中修正，视觉尺寸不变。

[TaskRowSubtaskInlineList](../AreaChain/Features/Tasks/TaskRowSubtaskMiniViews.swift) 删除独立圆圈/勾线/描边/颜色/动效绘制和额外触感调用，只传外部快照与 UUID；onToggle 为 nil 时仍无保存动作。行组合、长标题、ModernTaskTitle 留在原处。动作仍经 TaskRow.dispatch → TaskRowFactory → DayBoardMutations.toggleSubtask → 原仓储/事务；不接 PendingCompletionManager，不改变父子级联、日期、排序、计数、失败处理。

默认消费者为 TaskRow、TaskDetailHeaderBar、QuadrantChip，调用不改。TaskRow 自行使用 PendingCompletionManager；四象限继续显式 `isDone: false`，不由公共控件推断。G 阶段时详情子任务尚未接入；后续接入及原宿主失败刷新差异见本页第三阶段 H。日期和其他控件不在 G/H。

验证入口：ModernCheckboxTests、InlineSubtaskCompletionTests、TaskRowInteractionTests、PendingCompletionTimingTests（显式关闭延迟跳过）、QuadrantLayoutTests；复用 [DaybookControlsPreview](../AreaChainTests/Theme/DaybookControlsPreview.swift) 展示普通/紧凑、双状态、禁用与外部更新。正常测试目标及原串行 PrivacyQA XCTest 启动，实际证据与未验项见[工程手册](engineering.md#第三阶段-g公共任务完成控件与行内子任务2026-10-01)。`check_workflow.py` 只守卫稳定入口/几何，不代替行为测试；独立复核仍指定 Cursor verifier。

### 第三阶段 H：详情子任务完成控件接入

[SubtaskRowView.toggleCheckboxButton](../AreaChain/Features/Workspace/TaskDetailSubtasksView.swift) 改为 `ModernCheckbox(isDone:presentation:action:)` 的 `.detailSubtask`，消费者删除独立 Button、circle/checkmark.circle.fill 图标、字体及状态颜色。公共实现保留 SF Symbol 固有布局；字号由 `DaybookMetrics.Completion.detailSubtaskSymbolSize` 复用 subtitleSize（12pt），当前 QA 辅助框及中心/水平边缘命中为 12×12，没有改成主任务 20 或行内 14 的矩形点击框。未完成为 text.secondary、完成为 accent.base；没有触感、缩放、悬停改色或勾线生长，默认/行内的既有反馈继续保留。使用公共中英文辅助名称及选中状态，程序化激活与鼠标共用一次动作和禁用守卫。

原行仍由 [TaskDetailSubtasksView](../AreaChain/Features/Workspace/TaskDetailSubtasksView.swift) 与 [WorkspaceFilteredListView.subtaskSection](../AreaChain/Features/Workspace/WorkspaceFilteredListView.swift) 两处组合；后者随同一生产行复用表现，没有另迁移页面。公共控件只消费外部 Bool 并派发原动作，不保存、不镜像模型状态、不引入 PendingCompletionManager。双击标题、Return/Escape、失焦保存/失败草稿、外部标题刷新、标签、拖动排序及删除仍留原行；ModernTaskTitle 和详情删除线不改。

复用 ModernCheckboxTests / InlineSubtaskCompletionTests / SubtaskTitleEditingTests / TaskRowInteractionTests / PendingCompletionTimingTests 和模型/事务回归；新增 [DetailSubtaskCompletionTests](../AreaChainTests/Features/DetailSubtaskCompletionTests.swift) 与[同一原生宿主夹具](../AreaChainTests/Features/DetailSubtaskCompletionSupport.swift)直接挂载真实行、详情与标签页。[ModernCheckboxFeedbackTests](../AreaChainTests/Theme/ModernCheckboxFeedbackTests.swift) 在串行测试内临时拦截系统 performer 并恢复，核对反馈调用次数，不以禁用动画证明无触感；没有生产反馈注入 API。展示仍是 [DaybookControlsPreview](../AreaChainTests/Theme/DaybookControlsPreview.swift)，加入详情、双状态禁用及外部更新。`check_workflow.py` 守住原公共入口、detailSubtask 与 detailSubtaskSymbolSize；不证明运行时契约。失败基线、最终证据及指定 Cursor verifier 缺口见[工程手册](engineering.md#第三阶段-h详情子任务完成控件接入2026-10-01)。

H 定向完成操作清单：TaskRow、TaskDetailHeaderBar、QuadrantChip、TaskRowSubtaskInlineList 和 SubtaskRowView 均使用 ModernCheckbox。批量完成/取消仍是 BatchActionBar 的系统菜单命令；键盘及 CompletionUndo 是原动作入口，没有独立圆圈组件。DayBoardSections 的完成分节、TaskRowSubtaskBadge 的计数/展开图标、TaskDetailScheduleSection 的检查日状态及搜索结果等是状态/导航展示，不当作遗漏迁移。日期、分段和其他控件停在原实现；此清单是定向静态核对，不等于全应用交互验收。

统一搜索 2E-2A 新增 [ImageQueryProvider.read](../AreaChain/Domain/ImageQueryProvider.swift)、[请求/结果/覆盖](../AreaChain/Domain/ImageQueryRead.swift)、[文件名与所属属性匹配](../AreaChain/Domain/ImageQueryMatching.swift)和[日期/状态适配](../AreaChain/Domain/ImageQueryTemporal.swift)，实际消费者仅五套 ImageQuery Domain 测试。它成为 ImageAssociationReader / ImageBrowseProjection / ImageOwnerProjection 的真实消费者，复用完整 Session、SnapshotMatching/Validation、OccurrenceDay/DateWindow、RoutineScheduleHistory/CheckReading/OccurrenceEvaluation；不接真实库或图片 IO。Applicability 新增按图片拥有者分支求值，contentTypes 最小允许 image；History 增加身份/创建日标量初始化，旧调用保留。公共证据追加 filename/owner 字段及 ownerObject；todo/subtask/diary/routine 一并回归。唯一支持矩阵、覆盖/保护与 2E-2B has:image 交接见[权威设计第 9.21 节](unified-search-commands.md#921-阶段-2e-2a公开图片元数据的只读搜索提供者)。原检查器接口/规则不变，复用既有检查与脚本回归，无新增专项执行器。


统一搜索 2E-2B 的共用入口为 [ContentQueryImageInput / Read](../AreaChain/Domain/ContentQueryImageRead.swift) 与[三类求值适配](../AreaChain/Domain/ContentQueryImageEvaluation.swift)，由 TodoQueryMatching、RoutineQueryProvider / Matching、DiaryQueryProvider / Matching 实际消费。每次 read 使用当前主请求拥有者快照，Diary 复用唯一 metadata，调用原 ImageAssociationReader / association(for:)；不接受旧响应、另一份 owner/隐私表或文件句柄。Todo 新增[对象三态组合](../AreaChain/Domain/TodoQueryEvaluation.swift)及未知对象/诊断影响，Routine/Diary 沿原组合器；没有 has:image 时不扫描附件。四套 RecordImageQuery 合成测试及原提供者/2E-1/2E-2A 回归覆盖新入口，契约和 partial 状态只见[权威设计第 9.22 节](unified-search-commands.md#922-阶段-2e-2b三类记录的图片存在性查询)。无新检查器接口/规则或生产接线。

统一搜索 2F 新增 [TagQueryProvider.read](../AreaChain/Domain/TagQueryProvider.swift)、[只读快照/请求/结果](../AreaChain/Domain/TagQueryRead.swift) 与[使用统计覆盖](../AreaChain/Domain/TagQueryUsage.swift)，当前仅四套 TagQuery 领域测试消费。原 TagUsage.filtered 与新提供者共用 [TagUsage.filteredValues / TagListFacts](../AreaChain/Domain/TagUsageFiltering.swift)，旧消费者为 TagManagementPage.displayed/unusedTags；TagUsage.records/subjects 统计口径和生产页面未改。公共 contentTypes 最小增加 tag，命中字段增加 tagName；其余提供者及旧目录共同输入回归。原名/关联条件、完整性、显式排序与 partial 验收唯一维护在[权威设计第 9.23 节](unified-search-commands.md#923-阶段-2f活标签只读快照搜索提供者)。无仓储、UI、聚合、写入或新检查器入口。

## 第四阶段 E：通用分段与菜单栏

- [DaybookSegmentedControl / DaybookSegmentOption](../AreaChain/Theme/DaybookSegmentedControl.swift)：`Value: Hashable`，`selection: Binding<Value>`、`options: [DaybookSegmentOption<Value>]`。选项以唯一稳定 value 为身份，标题 `String.LocalizationValue` 与可选 help 独立；省略 help 时使用完整标题。不可用文字或数组位置作为值。
- [DaybookSegmentedBar](../AreaChain/Theme/DaybookSegmentedBar.swift) 保留 BoardTab、tasksCount、diariesCount 的原调用，只装配原事项/手记顺序和标题/help，不显示计数；唯一生产消费者仍是 MenuBarPopoverView+Header 的 `$tab`。核心不依赖 BoardTab、CalendarSpan、导航或会话。
- 几何集中于 DaybookMetrics.Segmented；绘制沿 Daybook 字体、语义色、圆角和 raised 阴影。DaybookMotion.segmented 保留 0.28/0.75 弹簧，系统 accessibilityReduceMotion 时取消动画事务。每实例持有独立 Namespace，无本地选中镜像或完成回调。长标题单行截断，辅助名称/help 保留全文；空数组不绘制，缺失值无选中滑块，不自动写回。
- 操作只同步写一次 Binding，重选仍写一次；禁用不写入。外部更新和拒绝写入按 Binding 显示；没有全局快捷键、方向键截获、提交或保存。父级 onChange、FooterBar 关闭筛选、搜索优先级、两类草稿/筛选和计数继续归原宿主。
- 展示扩展原 DaybookControlsPreview，包含独立 Int 选中实例；按钮专用减弱预览开关不代表分段的系统联动。验证见 DaybookSegmentedControlTests 和 MenuBarPopoverRenderingTests 的 segmentedConsumerPreservesDraftsFiltersSearchAndCounts；证据与未验项见工程手册。
- E 阶段未迁移日历；后续接入与原生对照见下述第四阶段 F。

## 第四阶段 F：日历月/周分段接入

[CalendarPage.spanPicker](../AreaChain/Features/Calendar/CalendarPage.swift) 直接复用 DaybookSegmentedControl / DaybookSegmentOption，保留 `$span`、month/week 顺序、默认 month、220pt 上限及原 onChange 将 keyboardFocus 设为 grid 的意图。只有非 embedded 的宽/窄月布局和周布局显示分段；工作台仍经原 `workspaceHeader` 的 month/week 菜单与动作切换，没有重复入口。分段明确提供 `calendar.span` 本地化辅助组名与稳定标识，选项沿公共核心提供选中状态。

`CalendarSpan.titleKey` 是唯一字符串资源键来源；公共选项显式转 String.LocalizationValue，顶栏显式转 LocalizedStringKey。无调试描述解析、重复文案表或新的业务适配组件；公共核心、MenuBar 适配器、CalendarGridKeys、DayKey、投影、日期格、拖放及保存均未修改。selectedKey、草稿、listFocusID、检查器有效范围和日期导航沿原页面。原生对照发现分支中的 onChange 在列表切周时未恢复网格，以及 420pt 周内容/右导航越界，均属旧实现，本轮保留并以已知失败取证，不当作迁移成功项。

验证直接挂载生产页面与 WorkspaceHeaderBar，复用 SettingsButtonTestSupport、SystemPageHost、MenuButtonTestSupport 和原公共分段/菜单栏测试；新增 [CalendarSpanConsumerTests](../AreaChainTests/Features/CalendarSpanConsumerTests.swift) / [隔离夹具](../AreaChainTests/Features/CalendarSpanTestSupport.swift)，并补齐原 CalendarMonthNavigationTests 的共享状态恢复。可见入口须通过辅助父链、原生祖先可见性、边界和唯一性检查；隐藏的 ViewThatFits 候选不能靠同名匹配被点击。截图、合成 NSEvent、菜单项派发与真人验收分开记录，证据见[工程手册](engineering.md#第四阶段-f日历月周分段接入2026-10-02)。展示仍沿 E 的 DaybookControlsPreview，无新展示应用或检查执行器。

F 定向静态清单：

| 已识别入口 | 公共核心 / 业务适配 | 原生承载或测试对照 |
|---|---|---|
| ClipboardHistoryOptions 三个下拉 | DaybookPicker；原枚举与 set 方法 | 公共 NSPopUpButton 桥接 |
| GeneralSettingsSection 三个下拉 | DaybookPicker.formRow；原偏好 Binding | 公共 NSPopUpButton 桥接 |
| TagManagementPage 合并目标 | DaybookPicker；UUID 与 verbatim 标签名 | 公共 NSPopUpButton 桥接 |
| PrivacySettingsSection 自动锁定 | DaybookPicker.formRow；原认证/保存 Binding | 公共 NSPopUpButton 桥接 |
| 菜单栏事项/手记分段 | DaybookSegmentedControl；DaybookSegmentedBar 仅适配 BoardTab | 公共 Button，宿主保留快捷键 |
| 日历月/周及工作台顶栏 | DaybookSegmentedControl 直接消费 CalendarSpan；顶栏共享 titleKey | 非嵌入公共 Button；嵌入仍为系统 Menu |

上述下拉/分段生产入口已收齐；测试展示语言 Picker、原生对照分支不是生产遗漏。日期选择器、月历日期格、星期掩码等其他控件不纳入 F。历史主题回退、H 两项、Stepper 长按、强制派发禁用菜单现象和既有公共复核缺口继续保留。

### 第五阶段 A：公共时间选择器与首批消费者

[DaybookTimePicker](../AreaChain/Theme/DaybookTimePicker.swift) 接收本地化辅助名称及 `minutes: Binding<Int?>`。唯一业务值为 0..<1440 或 nil；[RemindMinutes](../AreaChain/Domain/ReminderPlanning.swift) 继续负责有效范围与分钟转换。挂载、外部更新和格式变化零写入；nil 不等于午夜，nil/越界值保留当前分钟作为编辑起点，并分别显示“未设置/无效时刻”，不自动修正来源。控件不提供清除、确认、快捷时刻、保存或系统权限能力。

[DaybookNativeTimePicker](../AreaChain/Theme/DaybookNativeTimePicker.swift) 使用 NSDatePicker 的 textFieldAndStepper/hourMinute 引擎，保留字段暂存、校验、方向键及跨小时/午夜进位；不复用 DaybookStepper。外壳沿 DaybookInputShell.search，字体/颜色沿 DaybookType/DaybookPalette，几何集中在 DaybookMetrics.TimePicker。locale、calendar 来自 SwiftUI 环境；DaybookTimePresentation 复制日历标识、使用 UTC 与固定参考日（2001-01-01 12:00 UTC）承载时分，Date 从不进入持久化。这只隔离展示日的夏令时缺口，不修改真实提醒排程的时区规则。渲染戳仅判断外部变化，setter 始终使用 Binding，原生动作后回读实际值，避免拒绝/回滚留在乐观值；不主动请求焦点。所属 NSPopover/NSWindow 的 willClose 提前撤销动作资格，防止关闭时补交尚未完成的字段；普通失焦保留 AppKit 合法单数字完成规则。

第五阶段 A 接入 [TaskRow.timePicker](../AreaChain/Features/Tasks/TaskRow+Actions.swift) 和 [ResidentEditorRow](../AreaChain/Features/Workspace/ResidentsPage.swift)。任务行继续 dispatch(.setRemindMinutes)，重复事项继续 setRemind → DayBoardMutations；空提醒点击“设时刻”仍由调用方先写当前分钟，已有提醒不重写。有效修改即时提交，关闭不撤销，清除仍写 nil；原弹出层 padding 12/minWidth 180 保留。标题编辑、重复规则、授权和失败处理不移入 Theme。

展示沿 [DaybookControlsPreview](../AreaChainTests/Theme/DaybookControlsPreview.swift)，直接挂载有效值、nil、禁用午夜及外部更新。测试入口为 [原生基线](../AreaChainTests/Theme/TimePickerNativeBaselineTests.swift)、[公共契约](../AreaChainTests/Theme/DaybookTimePickerTests.swift) 和 [真实消费者](../AreaChainTests/Features/TimePickerConsumerTests.swift)，复用 SettingsButtonTestSupport、SystemPageHost、原仓储与 ModelChanges 失败注入。稳定入口由原检查器及反例守卫；实际证据和缺口统一在[工程记录](engineering.md#第五阶段-a公共时间选择器2026-10-02)。

第五阶段 B 的详情接入见下节。DaySchedulePicker 仍是日期/确认契约，不应通过这个纯时分接口迁移。


### 第五阶段 B：详情提醒与截止时间接入

[TaskDetailRemindChips](../AreaChain/Features/Workspace/TaskDetailScheduleSection.swift) 与 [TaskDetailDueTime](../AreaChain/Features/Workspace/TaskDetailDueTime.swift) 的自定义弹出层直接使用 DaybookTimePicker 的 `minutes: Binding<Int?>`，删除本地 Date 转换；显式传 locale，保留原字段名称、padding 12、快捷项格式/排列及清除入口。空值打开/关闭不写入，午夜 0 与 nil 分离；公共控件的当前分钟仅是编辑起点。

真实消费者为 [TodoScheduleSectionView / RoutineScheduleSectionView](../AreaChain/Features/Workspace/TaskDetailSections.swift) 与 [RecurringItemEditor](../AreaChain/Features/Workspace/RecurringItemEditor.swift)。详情提醒继续走 setRemind，截止继续走 setDue；新建只修改 draft.remindMinutes，保存才创建、取消不提交、失败保留草稿。09:00、12:00、15:00、18:00、20:00 的重选清除和选中反馈不变。关闭沿公共生命周期保护，不补交暂存输入；普通失焦由原生字段完成合法输入。

隔离测试复用 TimePickerConsumerTestSupport、原仓储与 ModelChanges 失败注入；新增 [详情测试](../AreaChainTests/Features/DetailTimePickerTests.swift)、[定位支持](../AreaChainTests/Features/DetailTimePickerTestSupport.swift)、[详情生命周期](../AreaChainTests/Features/DetailTimePickerLifecycleTests.swift)、[新建时间测试](../AreaChainTests/Features/RecurringEditorTimeTests.swift)。同名按钮按所属标题区域唯一定位，不手动重建宿主证明回滚。实际证据见[工程记录](engineering.md#第五阶段-b详情提醒与截止时间2026-10-02)。验证入口/公共 API 不变，不增加检查器或展示应用。

四处纯时间输入已静态收齐：任务行、重复事项管理、详情提醒（含新建表单）、详情截止；NSDatePicker 仅保留在公共原生承载。日期阶段仍有 DaySchedulePicker 及任务行、详情日期、DiaryNoteCard、DiarySummaryRow 的调用，星期和日历布局不在本阶段。

## 第六阶段 A：公共日期选择器与排期弹窗

- [DaybookDatePicker](../AreaChain/Theme/DaybookDatePicker.swift) / [DaybookDateCell](../AreaChain/Theme/DaybookDateCell.swift)：`selection: Binding<String>` 为民事日键，`todayKey: String?` 可注入展示日；locale/calendar 来自环境。月份浏览为局部瞬时状态；初始化、翻月和失焦不写 Binding，选日/方向键只提出日期更新，不保存。外部更新切回对应月份，拒绝写入不形成乐观选择，禁用/拆卸不写入。异常值按原 DayKey 解析能力展示回退，不修订全局规则或反写规范化值。
- `DaybookDateCell` 集中今天下划线、选中/焦点和完整日期辅助名；日期身份及辅助标识为完整日键。月份/闰年/网格复用 DayKey，星期排序与名称复用 WeekdayMask，月份导航复用 DaybookPeriodBar；几何仅在 `DaybookMetrics.DatePicker`。
- [DaySchedulePicker](../AreaChain/Features/Tasks/DayScheduleMenu.swift) 保留 initialKey / confirmTitle / onPick；本次暂存日键在打开时按原解析与当前日期回退初始化，仅确认提交。TaskRow、TaskDetailDateChips、DiaryNoteCard、DiarySummaryRow 只补来源 locale/calendar，保留原保存和关闭策略及快捷项。
- [DaybookDatePickerTests](../AreaChainTests/Theme/DaybookDatePickerTests.swift)、[原确认消费者](../AreaChainTests/Features/DayScheduleButtonConsumerTests.swift)、[生命周期消费者](../AreaChainTests/Features/DateScheduleLifecycleTests.swift) 直接挂载生产控件，原 ControlsPreview 扩展正常/禁用/外部更新日期样例。指定 Cursor verifier 缺口与本轮证据见[工程手册](engineering.md#第六阶段-a公共日期选择器与排期弹窗)。
- 阶段 A 不迁移主月历；阶段 B 接入见下节。习惯月历、周布局及星期选择仍留后续；公共层没有计数规则、范围、多选、拖放处理或模型能力。

## 第六阶段 B：主日历月网格接入

- [DaybookDateCell / DaybookDateCellPresentation](../AreaChain/Theme/DaybookDateCell.swift) 的默认 `picker` 保留阶段 A 的今天下划线、焦点及 inline 按钮；`monthGrid(DaybookMonthGridDensity)` 保留今天边框、选中底色、regular 按钮边距和外部 `isDropTarget` 描边。`annotation: Text?` 只显示调用方算好的文字并保留原本地化插值，nil 在月格保留原空白行；不接模型、计数规则、拖放事件或保存。两者共用日期字形、完整日期辅助名、今天值、选中语义和 `daybook.date.<日键>` 标识。
- [DaybookWeekdayHeader](../AreaChain/Theme/DaybookWeekdayHeader.swift) 为两个宿主唯一星期标题入口，复用环境 calendar/locale 和 WeekdayMask，保留 `daybook.date.weekday.<星期序号>` 及完整辅助名称。排序仍从 firstWeekday 开始。`DaybookMonthGridDay.month` 仅包装原 DayKey.monthGrid 的可选日键，两个宿主 ForEach 以完整日键而非格子偏移量维护身份，空白保持独立占位。
- 几何在 [DaybookMetrics.MonthGrid](../AreaChain/Theme/DaybookMetrics.swift)：内容最小高度 52/28，附加行字号 9、间距 2；实际高度仍受文字和按钮上下各 3pt 内边距影响。320pt 六周网格实测普通 58pt，紧凑普通计数 35pt、六位数换行 46pt，不锁成声明值或统一最终高度。
- [CalendarMonthGrid](../AreaChain/Features/Calendar/CalendarMonthGrid.swift) 接口不变，仍读取外部 dates/counts，拥有 dropKey、TodoDragToken 解码、回调及拒绝条件；重新点击也调用 onSelect，不复制选择状态。空白仍不是相邻月份日期且不可交互。生产 CalendarPage 继续负责统计、导航、选日更新、改期和保存失败后的日期规则；CalendarGridKeys 保持原宿主。
- 展示沿原 ControlsPreview，样例 [DaybookDateCellSamples](../AreaChainTests/Theme/DaybookDateCellTests.swift) 直接使用公共日格。隔离测试包括 [几何对照](../AreaChainTests/Features/CalendarMonthGridLayoutTests.swift)、[月格交互](../AreaChainTests/Features/CalendarMonthGridTests.swift)、[拖放接线](../AreaChainTests/Features/CalendarMonthGridDropTests.swift) 和 [生产月页面](../AreaChainTests/Features/CalendarMonthPageTests.swift)。实际命中与缺口见[工程手册](engineering.md#第六阶段-b主日历月网格接入)。
- 阶段 B 未迁移习惯月历；阶段 C 接入见下节。星期选择与周布局继续保持原入口。

## 统一搜索 4A-1：公共原生输入与斜杠补全

- [UnifiedSearchInput](../AreaChain/Theme/UnifiedSearchInput.swift) 组合 DaybookInputShell.search 与 DaybookTextField 的显式搜索适配；standard/compact 预设只控制可用宽度与候选高度。实际消费者仅 [UnifiedSearchTestFixture](../AreaChainTests/Theme/UnifiedSearchTestHost.swift) 的工作台和菜单栏隔离宿主，不替换 WorkspaceHeaderSearchCapsule / MenuBarSearchField。
- [UnifiedSearchBuffer / UnifiedSearchCompletion](../AreaChain/Theme/UnifiedSearchInputState.swift) 携带宿主原 lease、缓冲版本和选区；编辑、候选接受、焦点与提交意图由宿主回调，CommandPathParser / Result 是唯一指令解析与接受入口，没有业务参数镜像。
- [UnifiedSearchFieldCell](../AreaChain/Theme/UnifiedSearchNativeInput.swift) 提供专用原生 field editor 和独立 UndoManager；隐私事件只清本控件缓冲、组合状态、候选与撤销，不触碰窗口其他历史或 ContentQueryReadSession。
- [unifiedSearchOverlayHost](../AreaChain/Theme/UnifiedSearchOverlay.swift) 复用 SyntaxOverlayPlacement、SyntaxAutocompleteState / Popup 的选择、滚动和按钮；仅补全，不使用原捕获层的键盘监听。未来预览在宿主下方独立布局，不能重复挂载补全层。
- 唯一契约、实际证据及未验项见[权威设计的 4A-1 交接](unified-search-commands.md#945-阶段-4a-1公共原生搜索输入与斜杠补全)。检查器仅验证公共入口存在，不代表原生交互验收。


## 第六阶段 C：习惯月历接入公共日期格

- [DaybookDateCell](../AreaChain/Theme/DaybookDateCell.swift) 增加 `habit(DaybookHabitDateState)`，五种纯呈现值 checked/skipped/missed/open/outside 集中状态前景与底色；选中优先 onAccent/accent.base。保留两位日号、DaybookType.micro、DaybookRadius.xxs 和 plain 按钮，今天无独立装饰。原 picker 默认、monthGrid 尺寸、`annotation: Text?` 和投放高亮契约不变。
- [DaybookMetrics.HabitMonthGrid](../AreaChain/Theme/DaybookMetrics.swift) 集中 22pt 内容最小高度、4pt 列/行距和 6pt 标题间距。原生基线中有底色按钮的 AX（辅助功能）边界高 22pt，透明日期仅文字高 11pt；布局行距仍按 22+4pt。不能通过加 contentShape 或公共按钮内边距改变它。
- [HabitCheckMonthView](../AreaChain/Features/Workspace/HabitCheckMonthView.swift) 直接消费公共日格与 DaybookMonthGridDay，保留原 Query、HabitMonth.mark、状态到呈现映射、业务状态本地化、DayClock 和 `WorkspaceNavigation.shared.inspectTask(routine.id, dayKey: day)`。重选继续导航；outside 保持可检查，padding 无操作。没有新打卡、保存、筛选、历史推断或镜像选择。
- `calendar: Calendar = .current` 局部兼容参数传给网格、HabitMonth 和子日格环境；生产默认与原调用一致，不跟随无关父级 calendar，不改 DayKey/DayClock。公共层只从环境读取 calendar/locale。完整日期只在公共 label 朗读一次；`statusDescription: String?` 为习惯的已本地化状态 value，其他呈现仍沿今天值。outside 沿原 habit.month.open 文案。选中与完整 `daybook.date.<日键>` 标识由公共层维护；习惯宿主标识为 `habit.month.<routine UUID>`，多个同习惯实例还须限定实例祖先。
- 直接宿主 [RoutineHabitSectionView](../AreaChain/Features/Workspace/TaskDetailSections.swift) 和 [TaskDetailDrawer](../AreaChain/Features/Workspace/TaskDetailDrawer.swift) 原样保留。测试直接挂载生产组件、真实检查器及原 [ControlsPreview](../AreaChainTests/Theme/DaybookControlsPreview.swift)；[基线](../AreaChainTests/Features/HabitMonthBaselineTests.swift)、[像素/几何与日历](../AreaChainTests/Features/HabitMonthLayoutTests.swift)、[导航和隔离](../AreaChainTests/Features/HabitMonthInteractionTests.swift)、[公共状态展示](../AreaChainTests/Theme/DaybookHabitDateCellTests.swift) 分别提供证据，运行结果及缺口见[工程手册](engineering.md#第六阶段-c习惯月历接入公共日期格)。稳定符号继续由原 check_workflow.py 守卫。
- C 未迁移星期选择；D 的实际圆点入口见下节。旧线索 RepeatWeekdayPicker 在当前源码中不存在；任务行实际为 TaskRow+Menus.standingMenus 原生星期子菜单。DaybookWeekdayHeader 仅是只读标题，周布局继续留后续。

## 第六阶段 D：公共星期多选与三个消费者

- [DaybookWeekdayPicker](../AreaChain/Theme/DaybookWeekdayPicker.swift) 是唯一生产圆点实现：外部 `selection: Int`、`onUpdateSelection`、`allowsEmpty` 和独立的 `accessibilityTitle: Text`；无模型、仓储、长期镜像选择或自动写回。环境 locale/calendar/isEnabled 就近传播；稳定身份为 1…7，完整辅助名称和选中状态由公共层提供，多个实例由宿主限定，不能按英文重复短字符定位。
- `allowsEmpty=true` 以 WeekdayMask.containsSelection 展示草稿 0，取消最后一天回传 0；false 以 contains 展示并沿 toggling 规范化，取消最后一天仍回传原值，不去重。挂载、外部更新、日历/语言变化和关闭不回调，禁用也拒绝辅助动作写入。没有新增颜色覆盖、动画、矩形点击面或方向键机制。
- [DaybookMetrics.WeekdayPicker](../AreaChain/Theme/DaybookMetrics.swift) 集中直径 25、圆点间距 4、适配标题间距 6pt；badge medium、accent.base/onAccent 与 cardSurface/text.primary 不变。原生测得 AX 边界为 25×25pt，但方框角落与间隙不响应；保留 Circle 与 plain 的实际命中和按下反馈。
- [TaskDetailWeekdayPicker](../AreaChain/Features/Workspace/TaskDetailScheduleSection.swift) 保留 `resolvedMask / onUpdateMask / showsTitle / allowsEmpty / accessibilityTitle`，仅负责原业务标题和转交。三个调用点原样接入：[RecurringItemEditor](../AreaChain/Features/Workspace/RecurringItemEditor.swift) 只改草稿，空值提示、按钮禁用及保存校验各自保留；[ResidentsPage](../AreaChain/Features/Workspace/ResidentsPage.swift) 与 [RoutineScheduleSectionView](../AreaChain/Features/Workspace/TaskDetailSections.swift) 继续 DayBoardMutations.setWeekdayMask → 原仓储/ModelChanges，不暂存或新增确认。
- [TaskRow+Menus.standingMenus](../AreaChain/Features/Tasks/TaskRow+Menus.swift) 是另一种系统菜单形态，沿 WeekdayMask 与原 dispatch；[DaybookWeekdayHeader](../AreaChain/Theme/DaybookWeekdayHeader.swift) 是只读星期标题。两者不改成圆点、不与多选强行合并。周布局及其他控件未纳入 D。
- 原 [ControlsPreview](../AreaChainTests/Theme/DaybookControlsPreview.swift) 接入 [星期样例与像素对照](../AreaChainTests/Theme/DaybookWeekdayPickerLayoutTests.swift)。[公共状态测试](../AreaChainTests/Theme/DaybookWeekdayPickerTests.swift)、[真实消费者刻画](../AreaChainTests/Features/WeekdayConsumerBaselineTests.swift) 和 [草稿/保存测试](../AreaChainTests/Features/WeekdayEditorConsumerTests.swift) 使用原 PrivacyQA、SettingsButtonTestSupport 和合成内存库。[RecurringToggleRepository](../AreaChainTests/Features/RecurringToggleRepository.swift) 的 weekdayWrites 及事务失败注入仅用于测试。旧绘制仅冻结在测试基线，不是第二个生产入口。结果与指定复核缺口见[工程记录](engineering.md#第六阶段-d公共星期多选与三个消费者)。

## 统一搜索 4A-2：公共受门禁结果列表

- [UnifiedSearchResults / UnifiedSearchResultsBoundary](../AreaChain/Features/Search/UnifiedSearchResults.swift) 为标准/紧凑宿主共用原生结果边界；仅隔离测试宿主消费。每次呈现经 ContentQueryReadSession.presentation，失效同步拆除原生结果及只读展开树。
- [UnifiedSearchController](../AreaChain/Features/Search/UnifiedSearchController.swift) 组合原 UnifiedSearchBuffer / Actions 与 ReadSession；原 lease、buffer 版本、浏览版本和分页 stamp 随事件保留，不向旧事件补版本。操作草稿、真实打开及命令处理器未接线。
- [ContentQueryDisplayUpdates](../AreaChain/Services/ContentQueryDisplayUpdates.swift) 是同步修订通知，并携带原生焦点提示；不存资格真值。expandedText 只解析当前 Browse 已展开的 ExpansionReference，重新经过展示门禁。
- [DaybookSearchResultText / DaybookSearchFragment](../AreaChain/Theme/DaybookSearchResultText.swift) 按合法字素边界绘制已有片段高亮，用原生两行标签限制摘要高度；行表面与旧 BoardSearchHitRow 共用 daybookSearchResultSurface。只读正文用 [DaybookSearchReadOnlyText](../AreaChain/Theme/DaybookSearchReadOnlyText.swift)，按钮、空态及滚动条继续复用 Daybook。
- 公共输入增加 open 意图与可选 [UnifiedSearchInputReset](../AreaChain/Theme/UnifiedSearchInputReset.swift) 同步清理桥接；Tab 无候选时回原生焦点链，补全仍只挂载一次。接口、验证证据和缺口只见[权威设计 §9.46](unified-search-commands.md#946-阶段-4a-2公共原生搜索结果列表与输入导航)。

## 统一搜索 4A-3A：普通参数与即时操作预览

- [UnifiedSearchOperationPanel / Boundary](../AreaChain/Features/Search/UnifiedSearchOperationPanel.swift) 与 [UnifiedSearchOperationPreview](../AreaChain/Features/Search/UnifiedSearchOperationPreview.swift) 是两种隔离宿主共用的下方操作区域，搜索结果继续独立消费原 ReadSession；补全仍只由 unifiedSearchOverlayHost 挂载一次。字段展开使用区域内滚动，保持主输入锚点。
- [UnifiedSearchOperationEditing](../AreaChain/Features/Search/UnifiedSearchOperationEditing.swift) 扩展原 UnifiedSearchController，唯一操作状态仍从 CommandHandoffCoordinator 的 operations 读取。事件保留原 lease、CommandDraftStamp 和显示版本；原生拼写缓冲不是可独立提交的参数字典。
- [UnifiedSearchParameterField](../AreaChain/Features/Search/UnifiedSearchParameterField.swift) 按 CommandParameter 元数据组合 DaybookPicker、日期、时间、星期和 [UnifiedSearchParameterText](../AreaChain/Features/Search/UnifiedSearchParameterText.swift)。后者复用原 DaybookTextField 的独立输入编辑器；[UnifiedSearchParameterContext](../AreaChain/Theme/UnifiedSearchParameterContext.swift) 仅生成当前字段的补全/校验，不改通用查询解析器。
- DaybookPicker 新增可选 eventVersion，默认 nil 保持原消费者；操作字段在显示版本变化时重建菜单身份，拒绝旧菜单事件。实际消费者仅本阶段参数控件；原 Picker 与普通设置等消费者需回归。
- 实际消费者为 [UnifiedSearchOperationTestContent](../AreaChainTests/Features/UnifiedSearchOperationTestSupport.swift) 的标准/紧凑 QA 宿主和四套 UnifiedSearchOperation 测试。支持矩阵、版本边界、无真实执行、证据与 partial 缺口只维护在[权威设计 §9.47](unified-search-commands.md#947-阶段-4a-3a普通参数编辑与操作即时预览)。

时间参数同时显式传入 DaybookTimePicker / DaybookNativeTimePicker 的可选 eventVersion。原生未完成时分跨外部草稿版本后，迟到失焦 action 被拒绝；下一次真实鼠标/键盘输入才重新采用当前版本，本次成功输入回声不打断连续编辑。默认 nil 保持原时间消费者；专门回归见 UnifiedSearchOperationLifecycleTests 与原 DaybookTimePickerTests。

## 统一搜索 4A-3B1：对象参数与固定操作目标

- [UnifiedSearchObjectSelectionStamp / ObjectSelection](../AreaChain/Features/Search/UnifiedSearchObjectSelection.swift) 位于原 UnifiedSearchController 的扩展，复用 BrowseState 作为临时选择；确认核验原 lease、draft stamp、编辑位置、候选版本，通过原 selectTargets 或 edit 事件写入唯一草稿。
- [UnifiedSearchObjectField](../AreaChain/Features/Search/UnifiedSearchObjectField.swift) 由 ParameterField 的 target / object / objects 分支消费；[UnifiedSearchObjectPicker](../AreaChain/Features/Search/UnifiedSearchObjectPicker.swift) 共用 Daybook 结果行、候选滚动和原生键盘。标准/紧凑宿主共用实现，补全仍唯一挂载。
- [ContentQueryReadSession.objectCandidate](../AreaChain/Services/ContentQueryObjectCandidates.swift) 只解析当前安全发布的完整类型化身份，区分活对象与墓碑；没有实体或正文回查。目标预览同样重新经过此入口。
- CommandDraft.select 的可选 baseline 只接显式证据；改变具体对象集合时缺省清旧基线，保留 arguments。CommandHandoffCoordinator.ownershipRevision 在原子转交后通知原 ReadSession 观察链撤显示。
- 新消费者仅四套 UnifiedSearchObject 测试及原 OperationTestContent 隔离宿主；生产入口不变。候选范围、验收状态和下一阶段接口统一见[权威设计 §9.48](unified-search-commands.md#948-阶段-4a-3b1对象参数选择与操作固定目标的原生接线)。

## 第八阶段 B：daybookScroll 公共装配

[DaybookScroller.swift](../AreaChain/Theme/DaybookScroller.swift) 的私有 `daybookScrollAssembly` 是唯一装配链：`DaybookScrollIndicators` 策略变换 → `DaybookScrollerConfigurator` → `DaybookScrollEdgeFeatherModifier`。泛型恒等/隐藏变换保持原具体 SwiftUI 视图结构，不增加条件包装、AnyView 或状态。DaybookColor 只移出滚动入口，颜色与 daybookHideInputChrome 不变。

| 兼容调用 | 实际重载与默认 | 系统指示器 |
|---|---|---|
| `daybookScroll()` | 单参数，false / 7pt | 明确隐藏 |
| `daybookScroll(featherEdges: false/true)` | 单参数，指定开关 / 7pt | 明确隐藏 |
| `daybookScroll(featherHeight: h)` | 双参数，true / h | 保留调用方/系统策略 |
| `daybookScroll(featherEdges: value, featherHeight: h)` | 双参数，指定开关 / h | 保留调用方/系统策略 |

原默认参数不变；没有参数修正。保留策略是恒等变换，不设置 automatic 或 visible。WorkspaceItemsList、TasksPage、WorkspaceSidebarView、CalendarWeekBoard、GanttPage 和 SyntaxAutocompletePopup 均实际选择单参数入口，原生与编译证据见[工程记录](engineering.md#第八阶段-b公共滚动装配去重)。AppKit 文本仍直接使用 DaybookScroller；统一搜索 ObjectPicker / ResultsContent / OperationPreview 仍直接安装 Configurator。二者不迁移，不改浮层外壳、事件、目标搜索、拆卸、羽化算法或页面业务。

复用 DaybookScrollerTests、TaskListScrollTests、SettingsButtonTestSupport、CalendarWeekTestSupport、GanttInteractionTests 与 CaptureOverlayLayoutTests；新增 [公共结构契约](../AreaChainTests/Theme/DaybookScrollContractTests.swift)、[原生更新](../AreaChainTests/Theme/DaybookScrollNativeTests.swift)、[真实消费者刻画](../AreaChainTests/Features/ScrollAssemblyConsumerTests.swift)。历史错误目标用已知失败和原归属数量同时记录，不作为功能通过；指定 Cursor verifier 缺口保留。原 check_workflow.py 只守卫稳定入口存在，不证明行为通过。


### 统一搜索 4A-3C2A 命令保护载荷

- [CommandProtectedReference](../AreaChain/Domain/CommandDraftProtection.swift) 是无内容身份，不能授予访问；普通/required/unknown 的分类不是关键词检测结果。草稿/计划消费者沿原 Coordinator，受保护内容的完整性未知、保守 dirty，基线不可读不同于 absent。
- [CommandDraftContentSession](../AreaChain/Services/Privacy/CommandDraftContentSession.swift) 的 protect / acceptRevision / explicitlyRestore / withRestoredContents 只供隔离装配；当前宿主唯一归属仍由 CommandHandoffCoordinator 核验。锁前已接受修订已有恢复点，通知只撤权；无原生/生产入口。
- [CommandDraftPayload](../AreaChain/Services/Privacy/CommandDraftPayload.swift) 与 [SealedCommandDraft](../AreaChain/Services/Privacy/SealedCommandDraft.swift) 复用 VaultKeyAccess，独立 v1 命令格式，原 DiaryDraftText 不变。正文、基线、必要应用编辑状态受同一修订保护，不含原生能力或窗口。
- 实际消费者为 CommandDraft / Session / Baseline、CommandPlan / Validation / Semantics、CommandHostSession / HandoffCoordinator / ExecutionRun；两个原错误文案适配新增无内容拒绝原因。新服务仅由 CommandProtectedDraftTests / SealedCommandDraftTests 装配。
- 授权、恢复失败、原生缺口、回退与实际证据统一见[权威交接](unified-search-commands.md#951-阶段-4a-3c2a命令保护载荷与显式恢复)。普通转交兼容，保护/未知转交和长文协议执行仍拒绝；不进入下一阶段。

### 统一搜索 4A-3C2B 隔离原生接受探针

[CommandDraftNativeOwner](../AreaChain/Services/Privacy/CommandDraftNativeOwner.swift) 限定受控临时字段持有与同步清理；[CommandDraftContentSession](../AreaChain/Services/Privacy/CommandDraftContentSession.swift) 的 attachNative / acceptNative / undoNative / presentNative 复用 C2A 校验、密文和 Coordinator，只有同次成功修订可接续新 access。原 withRestoredContents 不允许任意缓存。

[CommandProtectedTextView](../AreaChain/Features/Search/CommandProtectedTextView.swift) 仅由 [原生测试](../AreaChainTests/Features/CommandNativeEditingTests.swift) / [故障与性能测试](../AreaChainTests/Features/CommandNativeFailureTests.swift) 装配；继承原 DaybookAppKitTextView，旧 DaybookTextEditor / SyntaxTextEditor 默认行为不变。active notes 单字段纯文本检查点与独立密文 undo；marked text 拒绝，mutable textStorage 为已知事后检测反例。无生产/planItem/handler 接线，支持矩阵和实际证据只见[权威 §9.52](unified-search-commands.md#952-阶段-4a-3c2b原生接受与锁定交错的隔离可行性)。


## 普通偏好共享入口（3A-1A）

- [AppPreferences](../AreaChain/Services/AppPreferences.swift) 的 `readLocalSetting` / `applyLocalSetting` 是语言、外观、标题省略和捕获来源标记的唯一权威读写路径；旧 [SettingsSections](../AreaChain/Features/Settings/SettingsSections.swift) 四个 Binding 即时委托，同值写入与展示事件保留。没有命令 handler 或第二份可编辑状态。
- [LocalPreference](../AreaChain/Services/LocalPreference.swift) 定义字段和值、来源/逐字段修订、可见原键快照及 `LocalPreferenceWriteResult`；[LocalPreferenceStorage / Effects](../AreaChain/Services/LocalPreferenceDependencies.swift) 只注入四键同步读写、外观和通知。默认仍为旧 UserDefaults 键及生产副作用。
- [PreferenceObservation](../AreaChain/Services/PreferenceObservation.swift) 由 PanelWindowController、StatusItemController、DiaryWindowController 和 CalendarSync 的既有偏好订阅实际消费。普通事件按来源和字段筛选，手记仅语言 chrome，日历没有普通订阅；菜单栏用已有计数呈现。AppChrome 和四象限继续 Observation，捕获仅创建时读标记。
- 隔离测试沿原 SettingsButtonTestSupport / GeneralSettingsSection，新增 LocalPreferenceTests、LocalPreferenceFailureTests、PreferenceObservationTests 和 SettingsLocalPreferenceConsumerTests。原 dark→system 进程外观测试及已知失败保留，不由注入测试替代。保证、验证与 3A-1B 接口以[权威交接](unified-search-commands.md#954-阶段-3a-1a普通偏好共享读写与事件拆分)为准。


## 普通偏好聚合文件后端（3A-3B1）

- [LocalPreferenceRecord / LocalPreferencePendingWrite](../AreaChain/Services/LocalPreferenceRecord.swift) 复用原 LocalPreferenceField / Value / RawValue；完整四值、稳定来源、记录/字段修订与提交身份。pending 只有身份/摘要及字段，不作第二权威。
- [LocalPreferenceFileStore](../AreaChain/Services/LocalPreferenceFileStore.swift) 的 `initializeNew(values:)`、`read()`、`commit(basedOn:changes:)`、`verifyPendingCommit()` 仅供显式临时目录消费者；[结果契约](../AreaChain/Services/LocalPreferenceFileContract.swift) 区分未提交、未知、已提交和清理未完成。[文件 IO 与锁](../AreaChain/Services/LocalPreferenceFileIO.swift) 只保护协议写入者，不是工程验收锁。
- 当前消费者仅 LocalPreferenceFileStoreTests / RecoveryTests / ConcurrencyTests，夹具生成独立临时目录。AppPreferences、旧四键、单项适配器、指令和 UI 未切换；B1 的迁移引用拒绝现由下节 3A-3B2A 的关系核验扩展。实际格式、保证与验证见[权威 §9.58](unified-search-commands.md#958-阶段-3a-3b1版本化聚合文件后端与提交恢复)。


## 普通偏好隔离迁移（3A-3B2A）

- [LocalPreferenceLegacySource / LocalPreferenceMigrationResult](../AreaChain/Services/LocalPreferenceLegacySource.swift) 显式注入受控测试 suite 身份及逐键存在性、原值、有效值和来源；复用四键/严格解析，来源不明或覆盖拒绝。未提供生产 UserDefaults 来源识别器。
- [LocalPreferenceMigrationEvidence](../AreaChain/Services/LocalPreferenceMigrationEvidence.swift) 保存 v1 只读证据，绑定来源、迁移身份、四键存在性、合法值及初始目标摘要；缺键的原值明确为不存在。
- [LocalPreferenceFileStore](../AreaChain/Services/LocalPreferenceFileStore.swift) 新增 `migrate(from:)` / `reopen(from:)`，复用原 IO、锁、perform 和 verifyLocked。initializeNew 仍拒绝任何迁移残留。
- 当前消费者仅 LocalPreferenceMigrationTests / RecoveryTests / EvidenceTests 及独立 suite 的 MigrationTestSupport；旧后端三套测试回归。没有 AppPreferences、指令或 UI 接线。旧版只见迁移前四键；权威状态、限制和实际证据统一见[§9.59](unified-search-commands.md#959-阶段-3a-3b2a旧四键隔离迁移重开与恢复判定)。


## 普通偏好整份发布（3A-3B2B）

- [AppPreferences](../AreaChain/Services/AppPreferences.swift) 增加显式 `init(defaults:fileStore:startup:effects:)`；原 init 和 shared 继续旧后端。`committedLocalPreferenceRecord` 返回最后完整发布记录，`applyLocalPreferences(basedOn:changes:)` 只调用一次原文件 commit，`verifyAndReloadLocalPreferences()` 只调用原核验/清理。四 Binding 按装配选择旧单键或新单字段聚合提交，没有旧键镜像。
- [LocalPreferencePublishedState / LocalPreferenceBackendState / LocalPreferenceGroupChange](../AreaChain/Services/LocalPreferencePublication.swift) 分别表达唯一四值发布、可写健康状态及无设置值的普通组事件。ready 载荷须与实际 store 完整重读一致；notMigrated 只读兼容，unknown/未决恢复关闭全部文件模式写入口。
- [LocalPreferencePresentationLedger](../AreaChain/Services/LocalPreferencePresentation.swift) 仅保存本实例的展示身份和调用事实；`localPreferencePresentation(for:)` / `retryLocalPreferencePresentation(for:)` 分别查询及重试，没有文件写入。外观与事件独立，迟到步骤按当前字段修订过期。
- [PreferenceObservation](../AreaChain/Services/PreferenceObservation.swift) 的 `init(preferences:consumer:center:presentation:legacy:)` 由 PanelWindowController、StatusItemController、DiaryWindowController 消费；组事件按来源和当前字段修订交集刷新。CalendarSync 保留空普通订阅，手记正文、捕获与截断责任不变。
- 文件后端只由 AppPreferencesFile 五套测试及 GroupObservation 测试的临时装配消费；旧单项 LocalSettingCommandAdapter 明确拒绝文件证据。启动、提交、展示、恢复的准确保证、同值两种政策及 3B3 接口只维护在[权威 §9.60](unified-search-commands.md#960-阶段-3a-3b2bapppreferences-聚合后端整份发布与展示事件)。没有生产后端切换、用户迁移、多项指令或新 UI。

### 普通偏好命令共同提交（3A-3B3A）

| 入口 | 职责与消费者 |
|---|---|
| [FileLocalSettingCommandAdapter](../AreaChain/Services/FileLocalSettingCommandAdapter.swift) | 显式 filePreferences 装配；prepare 单项、prepareGroup 显式整组、readiness / submit / execute、rereadConflict / resolveConflict、returnUnsubmittedToPlan、verifyCommit、retryPresentation 和 report。当前仅隔离测试消费，多项 UI 未接线。 |
| [CommandPreferenceGroupBaseline / GroupIdentity](../AreaChain/Domain/CommandPreferenceGroup.swift) | 完整标量证据及签发身份；原计划/组/有序成员身份，提交和展示的独立类型化结果。 |
| [claimPreferenceGroup](../AreaChain/Domain/CommandHandoffCoordinator.swift) | 多适配器共用 IO 前占用；原子安装成员基线、本地事实先入原运行、展示完成和精确 unknown 核验。 |
| [readLocalPreferenceRecord](../AreaChain/Services/AppPreferences.swift) | 显式完整权威读取，不发布或隐式准备。applyLocalPreferences 的 recordCommit、verifyAndReloadLocalPreferences 的 recordRecovery 在整份发布前登记可信事实；复用原后端和展示 ledger。 |

旧 LocalSettingCommandAdapter 仅接受旧后端；文件模式只通过新显式适配器。成员 changedFields 仅说明差异，整组 localReceipt 唯一。真实计数与隔离矩阵、拒绝范围、恢复和下一阶段接口统一见[权威 §9.61](unified-search-commands.md#961-阶段-3a-3b3a普通设置组准备共同执行与回执)。不接生产后端、多项 UI、真实迁移或执行后撤销。


### 普通设置组原生接线（3A-3B3B）

UnifiedSearchController 的 UnifiedSearchSettingBackend 互斥选择未装配、旧单项、文件适配。requestFileSettingPreparation 与 UnifiedSearchFileSettingSubmission / UnifiedSearchFileSettingCopy 复用原 PlanLinks、PlanList、SettingSubmission、参数控件和 ReadSession；FileLocalSettingCommandAdapter 仍唯一负责组资格、基线、提交、冲突与核验。显式临时文件消费者为 UnifiedSearchFileSettingContract/Interaction/RecoveryTests，旧单项初始化兼容；完整接口、状态和证据见[权威 §9.62](unified-search-commands.md#962-阶段-3a-3b3b普通设置共同提交的原生接线)。
