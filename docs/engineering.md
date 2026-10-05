# 工程与维护

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

**两项旧日历问题保留**：从列表进入周视图后，原 spanPicker 分支中的 onChange 未能恢复 grid，firstResponder 已为 NSWindow 但方向键未换日；Escape 返回网格后原路径继续可用。420pt 周布局的七列及右导航超出窗口，长标签会进一步放大；月布局和分段本身仍可操作。两项在原生和公共版本同场景复现，分别归属原 CalendarPage 状态回调生命周期及 CalendarWeekBoard/周布局最小宽度，不在 F 重写。测试以 withKnownIssue 保留失败断言，每次仍执行；不能把结果包 Passed 或已知问题数算作这些要求验收通过。

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

**清除失败的已知缺口**：`TimePickerB-final-detail.xcresult` 与补充尺寸矩阵的 `TimePickerB-final-matrix.xcresult` 均为 9 项/24 次，22 次通过、2 次失败。进一步 `TimePickerB-clear-diagnostic.xcresult` 确认失败发生在操作后：待办提醒/截止模型已恢复原值，但对应清除按钮消失，原宿主仍显示空值；并非同名按钮取错。`TimePickerB-original-clear.xcresult` 用迁移前两份生产源码、同一完整测试目标/夹具/失败注入，3 次中同样两处失败，重复事项通过；对照结束已恢复本轮代码。该现象与 H 阶段记录的外层事务回滚后详情未自然刷新一致。仅在这个已证实的原版/迁移版场景使用 withKnownIssue 保留断言，不手动重建、不修改生产保存/刷新机制；不能将已知问题计为自动回显通过。时间弹出层有效赋值失败的回显测试仍为普通断言且通过，两者证据不可混用。

**静态收口**：Features 仅四处 DaybookTimePicker，hourMinute/textFieldAndStepper 仅在公共原生承载。仅日期的 DaySchedulePicker 及 TaskRow、TaskDetailDateChips、DiaryNoteCard、DiarySummaryRow 调用保留；星期和日历布局未改。布局矩阵覆盖真实详情分组的 280/400pt、中英文/浅深色及新建表单；320pt 首轮截图也保留。原快捷项在窄详情中省略、设时刻换行，原代码未变，不据此扩修布局。公共长辅助名和 12/24 小时显示沿原展示/原生基线回归。原生位图缓存中的透明系统材质不代表屏幕最终合成效果。

**最终验证**：`build/TimePickerB-final-verified.xcresult` 的 summary/tests 树确认 13 套全部实际命中：DetailTimePickerTests、DetailTimePickerLifecycleTests、RecurringEditorTimeTests、RecurringItemEditorTests、TimePickerNativeBaselineTests、DaybookTimePickerTests、DaybookTimePickerLifecycleTests、TimePickerConsumerTests、ReminderPlanningTests、ModelChangesTests、RecurringToggleConsumerTests、DaybookTokenTests、WorkspaceLayoutTests。共 66 项、107 次运行：105 次通过、2 次已知问题、0 非预期失败/跳过。不能用 summary 顶层 Passed 抹去设备层的两次 expectedFailures。覆盖 nil 打开关闭零回调、午夜、快捷项重选/原清除、独立截止及通知/日历投影、实际赋值失败回显、草稿失败重试/取消、时间字段 Return 不提前创建、合法单数字失焦、Escape 不补交、禁用/外部更新/重开/迟到 action，并回归阶段 A 两消费者。

截图位于 QA 容器临时目录 `AreaChainButtonConsumersQA/settings-detail-time-*`、`settings-recurring-time-form-*` 及原 `settings-time-gallery-*`，交互结束后核对缓存图；en 的 AM/PM、中文 24 小时、浅深色与长辅助名沿原展示验证。程序化 dateValue/action 与 AXPress 证明适配/业务链；完整分钟输入和 Return/Escape/失焦为合成原生键鼠，仍不等于真人证据。

最终严格局部 SwiftLint、`python3 -B scripts/check_workflow.py`、`python3 -B scripts/quality_gate.py --profile static`（含 186 项脚本测试）及 `git diff --check` 通过。`./scripts/build.sh` Debug 构建/静态验签通过，沿既有 development 配置，不安装或启动产物；已有弃用 API/Swift 6 隔离编译警告不扩修。因仅授权隔离 XCTest 宿主，未运行另起普通宿主的 auto/swift 全量 profile，Swift 证据由上述完整目标的隔离定向回归提供。整体验收仍为 partial：两处旧清除失败回显、指定复核、真人与历史未验项保留。已在 B 停止，无提交、推送、安装、发布、真实数据、系统偏好、签名配置或权限变更。

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
