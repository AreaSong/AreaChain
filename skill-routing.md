# AreaChain 技能路由与交付闭环

安装脚本的原身份恢复改动沿 areachain-workflow → areachain-verify；复用原候选验签、安装锁、暂存替换和回退，仅以显式 `--previous-app` 提供可信原包身份。入口见[组件目录](docs/component-catalog.md#安装身份恢复入口)，参数与数据边界以[签名文档](docs/signing.md#原应用缺失时重装)为准。先做隔离脚本回归与只读预检；真实安装沿当前明确授权，数据重置、签名迁移和系统解锁不随之授权。指定 Cursor verifier 不可用时保留复核缺口，不用其他代理替代。

## 设置控件预览功能

本功能沿 areachain-workflow → areasong-development / areachain-ui（ui-ux-pro-max 聚焦 SwiftUI 状态身份与焦点）→ areachain-verify。正式设置入口复用同一 DaybookControlsPreview；迁移边界和窗口契约见[组件目录](docs/component-catalog.md#设置控件预览)，使用方法见[使用说明](docs/usage.md#8-偏好与系统设置)，实际证据见[工程记录](docs/engineering.md#设置控件预览2026-10-08)。

本轮明确允许 XCTest 点击生产设置区并打开新生产预览窗；完整正常 PrivacyQA、原锁最多900秒、合成数据及六项钥匙串授权清除仍适用。旧 Gallery 平台工具、runner 与 Feature 验收留测试侧；历史桌面应用入口暂停不变。新窗口和共享展示仍指定 Cursor verifier 只读复核，不可调用时保留缺口，不用其他代理代替、不重复请求人工矩阵。无提交、推送、安装或发布。


公共控件最终工程收口沿 areachain-workflow → areachain-ui（ui-ux-pro-max聚焦身份/焦点）→ areachain-verify，当前结论只见[原O总交接](docs/engineering.md#最终工程收口2026-10-08)。用户已确认上一轮人工操作正常，记录为人工确认通过；不重启Gallery，不重复旁白、取消、焦点、K输入或L操作，不补造日志。原P续验建议属于历史条件，不自动派生下一阶段；桌面入口暂停、完整正常PrivacyQA/XCTest、原锁900秒、合成数据与六项授权清除保持。指定Cursor不可用则材料就绪/复核未执行，不认证、安装或以其他代理替代。

H 真实截止保存依赖验收沿 areachain-workflow → areachain-ui（ui-ux-pro-max 聚焦原生身份/状态）→ areachain-verify。只显式透传截止最终 save，复用原 ModelChanges.perform；[组件契约](docs/component-catalog.md#第十阶段-h真实截止详情的局部保存依赖)与[原 H 证据](docs/engineering.md#h-真实截止详情链的最小保存依赖与失败恢复验收2026-10-08)为唯一维护来源。完整正常 PrivacyQA/XCTest、原锁单次900秒、六项钥匙串变量清除、合成数据和串行事件保持；不启动 Gallery/桌面入口，不改事务或失败发布。两项嵌套 AX 继续精确复验并独立开放；指定 Cursor verifier 不可用保留材料与缺口，不认证或替代，整体 partial，不提交、安装或发布。

第十阶段P沿 areachain-workflow → areachain-ui（ui-ux-pro-max仅补原生验收核对）→ areachain-verify；就地完善测试生命周期、逐事件/真实合成回调证据及原runner，不改生产。复用原interactiveGallery／SearchMultilineFixture、完整正常PrivacyQA、原锁900秒单一等待及六项授权清除；600秒内的30秒收尾期由测试支持集中维护。桌面入口（含旧app对象的AX/截图）继续暂停，无仅附着且绝不启动保证不得恢复；原生只由XCTest启动。自动/人工、平台能力、指定Cursor材料与H/K/L判定只维护在[原O内的P收尾](docs/engineering.md#第十阶段-p人工平台验收与最终交付判定)。人工准备不等于通过，重新确认当时方便才启动有界人工窗口；能力不可用不重复认证或替代指定复核。

P提交后重开与多行输入续验保持上述路由；仅扩展原Gallery的消费者/模式选择及有限语义观测，优先完成相关短回归，再由用户确认当时方便后开始600秒内的人工批次。真实粘贴只由用户自愿提供合成材料；命名pasteboard自动导入与用户系统粘贴分开，生产匹配/保存/安全和桌面入口暂停边界不变。

后续构建与测试统一遵循[并发构建与测试](docs/quality-gates.md#并发构建与测试)：默认原锁等待最多 900 秒，取得锁后核对源码变化，超时再报告未完成；当前任务明确的非等待要求优先。下列历史阶段的“锁忙停止／非等待申请”仅保留当时范围和执行事实，不作为后续任务的默认要求。

第十阶段 I 修复二沿 areachain-workflow → areachain-ui（areasong-development 补输入契约、ui-ux-pro-max 聚焦身份）→ areachain-verify。仅剪贴板 Browser 搜索显式选择 verbatim，公开原生排版支持与默认输入兼容见[组件目录](docs/component-catalog.md#第十阶段-i-修复二剪贴板搜索保真输入)，实际证据见[工程记录](docs/engineering.md#第十阶段-i-修复二剪贴板搜索保真输入)。先过最小保真/单行/撤销门槛，再扩大生产 Browser 三模式及修复一/J回归；完整正常 PrivacyQA、原锁900秒单一等待、六项授权清除、合成数据、随机命名 pasteboard 与串行事件保持。Cursor verifier 不可用保留缺口，不认证或替代。完成停止，不修历史问题，不提交、推送、安装、发布或操作真实数据与系统剪贴板。


第十阶段 J 沿 areachain-workflow → areachain-ui（ui-ux-pro-max 聚焦原生身份）→ areachain-verify。仅 CaptureField 两条手记提交入口共用局部组合文本保护，复用自有弱编辑器关联与 DaybookTextEditing；[组件契约](docs/component-catalog.md#第十阶段-j捕获按钮组合文本提交保护)及[工程证据](docs/engineering.md#第十阶段-j捕获按钮组合文本提交保护)保存边界。沿完整正常 PrivacyQA、原构建锁900秒单一有界等待、独立标识/目录、六项授权清除、合成数据与串行焦点测试。Cursor verifier 不可用保留缺口，不认证或替代；完成停止，不实施剪贴板策略或修复历史问题，不提交、推送、安装或发布。

第十阶段 I 修复一沿 areachain-workflow → areachain-ui（areasong-development 补输入契约，ui-ux-pro-max 聚焦原生身份）→ areachain-verify。只修 DaybookTextField 原生编辑边界和四个普通搜索的显式换行用途；[组件目录](docs/component-catalog.md#第十阶段-i-修复一普通搜索换行与撤销边界)与[工程记录](docs/engineering.md#第十阶段-i-修复一普通搜索换行与撤销边界)保存政策及验证。沿完整正常 PrivacyQA、独立标识/目录、六项授权清除、原构建锁和串行输入测试；指定 Cursor verifier 不可用保留缺口，不认证或替换。剪贴板本轮只回归撤销，换行保真政策和新统一搜索业务不接入；完成停止，不提交、推送、安装、发布或操作真实数据与系统剪贴板。

第十阶段 G 沿 areachain-workflow → areasong-development / areachain-ui（ui-ux-pro-max 聚焦原生可见性）→ areachain-verify。只修周布局的视口传播、等宽/横向浏览与选中日可达性；[组件目录](docs/component-catalog.md#第十阶段-g日历窄周布局)记录原装配与尺寸，[工程记录](docs/engineering.md#第十阶段-g日历窄周布局修复)记录测量和实际验收。完整正常 PrivacyQA、独立目录/标识、原锁、六项授权清除和串行事件保持；指定 Cursor verifier 不可用保留缺口，不认证或替代。完成停止，不扩修历史问题，不提交、安装或发布。

第十阶段 F 沿 areachain-workflow → areachain-ui（ui-ux-pro-max 聚焦 SwiftUI 身份／焦点，架构与可靠性判据补状态归属）→ areachain-verify。只将 CalendarPage 范围变化的业务焦点协调移到稳定页面，分段与顶栏菜单保持各自重选行为；[组件目录](docs/component-catalog.md#第十阶段-f月周切换后的键盘焦点恢复)记录入口，[工程记录](docs/engineering.md#第十阶段-f日历月周切换后的键盘焦点恢复)保留旧失败、运行根因及严格首次按键证据。沿完整正常 PrivacyQA、独立标识／目录、原构建锁、六项授权清除和串行合成窗口；指定 Cursor verifier 不可调用保留缺口，不认证或替代。完成停止，不修窄周、时间清除、搜索换行或安全输入，不提交、安装或发布。

第十阶段 E 沿 areachain-workflow → areachain-ui（areasong-development 补架构/可靠性，ui-ux-pro-max 聚焦身份）→ areachain-verify。羽化复用同一 scope 的 Host 绑定，观察与清理责任见[组件目录](docs/component-catalog.md#第十阶段-e滚动边缘羽化定位与更新)；修复前 nil/通知证据、自动状态与渐变、D 回归和缺口见[工程记录](docs/engineering.md#第十阶段-e滚动边缘羽化定位与更新修复)。沿完整正常 PrivacyQA、原构建锁、独立目录/标识、六项授权清除、合成数据与串行测试；指定 Cursor verifier 不可调用保留缺口，不认证或替换。完成停止，不修周布局、时间清除、搜索换行或其他历史问题，不提交、安装或发布。



第十阶段 D 沿 areachain-workflow → areachain-ui（ui-ux-pro-max 聚焦身份，架构/可靠性判据补归属和释放）→ areachain-verify。公共 daybookScroll 用成对局部边界定位，Host 管理自有浮层与拆卸；[组件目录](docs/component-catalog.md#第十阶段-d公共滚动浮层目标归属)列出复用入口，[工程记录](docs/engineering.md#第十阶段-d公共滚动浮层目标归属修复)记录旧失败、新归属及事件证据。完整正常 PrivacyQA、独立目录/标识、原构建锁、六项授权清除与串行合成宿主保持；指定 Cursor verifier 不可调用保留缺口，不认证或替代。完成停止，不修羽化、横向滑块、周布局、时间清除或其他历史问题，不提交、安装或发布。

第十阶段 C 沿 areachain-workflow → areachain-ui（areasong-development 局部等价、ui-ux-pro-max 聚焦 SwiftUI 身份）→ areachain-verify。仅 Dashboard 外层 ScrollView 显式接 `daybookScroll(featherEdges: false)`，两个横向图表保持原入口；[组件目录](docs/component-catalog.md#第十阶段-cdashboard-外层垂直滚动接入partial)与[工程记录](docs/engineering.md#第十阶段-cdashboard-外层垂直滚动接入partial)保存 partial 证据。完整正常 PrivacyQA、独立目录/标识、原锁、六项授权清除、串行及合成今日资料；续验已解除测试编译阻断并证实外层1／两横层0归属，32方法／53次有效自动回归通过。大视口同尺寸补验亦通过，第二处漏接按归属和自动回归证据标为已处理；人工、窗口合成器与指定复核缺口单列，不修公共目标搜索或历史问题，不提交、安装或发布。

第十阶段 B 沿 areachain-workflow → areachain-ui（ui-ux-pro-max 聚焦 SwiftUI 修饰顺序/身份，areasong-development 补局部等价判据）→ areachain-verify。只接 QuadrantTitlePreview 的静态 rowBubble 装饰；摘要、全文复制、静态边框、命中及定位差异见[组件目录](docs/component-catalog.md#第十阶段-b四象限标题预览纯装饰接入)。直接生产预览/overlay 与页面安全悬停沿完整正常 PrivacyQA、独立标识/目录、原构建锁、六项授权清除和串行事件；static profile、窄守卫/反例与真实证据见[工程记录](docs/engineering.md#第十阶段-b四象限标题预览纯装饰接入)。公共组件不改，局部等价由主代理自查，既有指定复核缺口保留。完成停止，Dashboard 外层滚动留下一轮，不修历史问题，不提交、安装或发布。

第九阶段 C 沿 areachain-workflow → areachain-ui（ui-ux-pro-max 聚焦修饰器身份；架构治理补等价判据）→ areachain-verify。只把 MenuBarFilterFlyout 两处外壳接入 DaybookFloatingSurface.filterFlyout；内描边与旧居中描边差异、状态和宿主责任见[组件目录](docs/component-catalog.md#第九阶段-c菜单栏筛选浮层外壳)。先直接挂生产组件并经生产筛选入口取基线；静态 profile 配完整正常 PrivacyQA、独立标识/目录、原构建锁、六项钥匙串授权清除与串行原生事件。像素/几何、合成鼠标、程序化状态、缓存图与屏幕证据分开；指定 Cursor verifier 不可用保留缺口，不认证或替代。结果见[工程记录](docs/engineering.md#第九阶段-c菜单栏筛选浮层外壳)。完成停止，连击指标、标签色点及历史缺口留待后续，不提交、安装或发布。

第九阶段 B 沿 areachain-workflow → areachain-ui（ui-ux-pro-max 聚焦修饰器身份；架构治理补等价判据）→ areachain-verify。仅 DaybookSurface 静态卡片与 TasksPage 两种昨日外壳，接口及布局/业务责任见[组件目录](docs/component-catalog.md#第九阶段-b昨日事项静态卡片外壳)。先直接挂载生产页面经原昨日入口取基线；静态 profile 配完整正常 PrivacyQA、独立标识/目录、原构建锁、六项钥匙串变量清除与串行事件。实际鼠标、程序化动作、像素与规则分开记录；指定 Cursor verifier 不可用保留缺口，不认证或替代。结果见[工程记录](docs/engineering.md#第九阶段-b昨日事项静态卡片外壳)。完成停止，筛选浮层、连击指标、标签色点及历史缺口只登记，不提交、安装或发布。

第八阶段 F 沿 areachain-workflow → areachain-ui（ui-ux-pro-max 聚焦 SwiftUI 身份，areasong-development 补架构等价判据）→ areachain-verify。只把 RowTitleBubble / RowNoteBubble.noteCardContent 接入原 floating 动态预设；公共层集中颜色和背景阴影，反馈、事件、箭头与命中形状留在气泡。接口及确定剩余范围见[组件目录](docs/component-catalog.md#第八阶段-f标题与备注气泡动态外壳)。修改前直接挂载原生产气泡，冻结装饰仅作像素对照；静态 profile 配完整正常 PrivacyQA、原构建锁、独立标识/目录、六项授权清除和串行事件。消费者默认复制路径不点击；指定 Cursor verifier 不可用继续保留缺口，不认证或替代。结果见[工程记录](docs/engineering.md#第八阶段-f标题与备注气泡动态外壳)。完成停止，不修复制、滚动、定位及其他历史问题，不提交、安装或发布。


第八阶段 E 修复二沿原 E 路由；仅帮助宿主同层遮罩/card 排序及既有本地键盘监视器的 Escape 优先级。复用 FooterBar 菜单动作、MenuBarHelpSurfaceTests 和原事件 helper，正常完整 PrivacyQA 串行验证，输入法/筛选/窗口边界与原草稿动作见[组件目录](docs/component-catalog.md#第八阶段-e标签详情与语法帮助卡外壳)，实际证据见[工程补记](docs/engineering.md#e-修复二语法帮助遮罩与-escape-路由)。指定 Cursor verifier 缺口保留，不认证或替换；完成停止，不迁移气泡、不修复制/滚动。

统一搜索 3A-2 沿 areachain-workflow → areasong-development 架构/可靠性 → areachain-ui（UI/UX 聚焦原生身份和焦点）→ areachain-verify。仅原隔离 Controller 显式装配四项 LocalSettingCommandAdapter，真实基线、单项提交、冲突及结果继续复用原 Coordinator / Plan / Run；[组件入口](docs/component-catalog.md#普通设置原生提交3a-2)与[权威 §9.56](docs/unified-search-commands.md#956-阶段-3a-2四类普通设置的原生提交冲突和反馈)为唯一交接。完整正常 QA 目标、独立 UserDefaults/副作用/隐私依赖、六项钥匙串变量清除、原构建锁与串行测试；锁忙停止原生执行。指定 Cursor verifier、C2B、外观、构建与人工缺口只按本轮证据更新，不认证或冒充复核。完成后停止，不修改用户偏好、不替换生产入口、不执行其他命令、多项事务或撤销。

统一搜索 3A-1B 沿 areachain-workflow → areasong-development 架构治理/可靠性 → areachain-verify。复用 AppPreferences 四项共享入口、原草稿/计划/运行与 Coordinator；只显式装配隔离单项，默认未装配和生产搜索继续关闭。基线/资格/调用前占用、冲突返回及展示重试见[组件目录](docs/component-catalog.md#普通设置单项指令适配3a-1b)，完整契约与证据见[权威 §9.55](docs/unified-search-commands.md#955-阶段-3a-1b普通设置单项真实适配与隔离验证)。静态门禁配完整正常 QA 目标、独立标识/目录、六项钥匙串变量清除与原构建锁；测试串行，锁忙保留缺口。指定 Cursor verifier、C2B、外观和原生历史缺口不豁免，不认证或替代复核。完成后停止，不接生产 UI、多项事务、迁移、撤销或用户设置。

第八阶段 E 修复一沿原 E 路由；仅公共浮层描边禁用命中，五预设共用，内容与宿主负责交互。冻结 medium 作为旧故障刻画，公共壳以双路径精确成功、边界与直接消费者回归验收；完整外缘像素/几何与动态时间分开。契约见[组件目录](docs/component-catalog.md#第八阶段-e标签详情与语法帮助卡外壳)，实际证据见[工程补记](docs/engineering.md#e-修复一公共浮层描边不拦截内容点击)。指定 Cursor verifier 缺口保留；完成即停止，帮助遮罩/键盘路由留下一轮，不迁移标题/备注或触碰系统剪贴板。

第八阶段 E 沿 areachain-workflow → areachain-ui（ui-ux-pro-max 聚焦 modifier 顺序/身份）→ areachain-verify；areasong-development 仅补架构等价判据。只接 tagDetailBubble 与 SyntaxExpandableCard 最外壳，新 tagDetail / syntaxHelp 共用 60% / 0.8pt 背景阴影政策，原三个预设兼容。帮助原 clipShape 留在消费者外壳之后；接口及下一阶段动态气泡线索见[组件目录](docs/component-catalog.md#第八阶段-e标签详情与语法帮助卡外壳)。生产 MenuBarPopoverView 只经原合成宿主核对真实动作，不改状态或接线。静态 profile 配合完整正常 PrivacyQA、独立目录/标识、构建锁、六变量清除和串行测试；像素、缓存图、几何、合成事件与真人证据分开。指定 Cursor verifier 缺失保留缺口、不认证或替代；实际证据见[工程记录](docs/engineering.md#第八阶段-e标签详情与语法帮助卡外壳)。完成后停止，不迁移标题/备注，不修滚动、复制或其他历史问题。

第八阶段 D 沿 areachain-workflow → areachain-ui（ui-ux-pro-max 聚焦 modifier 身份与顺序）→ areachain-verify；areasong-development 仅补架构等价判据。任务 mainRow 复用 suggestions，手记主卡接 smallBackground / !showsSuggestions；纯装饰差异及剩余气泡见[组件目录](docs/component-catalog.md#第八阶段-d两类实时预览主外壳)。先沿原隔离宿主直接挂生产预览和 SyntaxAutocompletePopup 取基线；完整正常 PrivacyQA、独立目录/标识、构建锁、六项钥匙串变量清除与串行执行，静态 profile 配合独立 Swift 测试。完整外缘像素、动态时间、原生合成事件和真人证据分开，指定 Cursor verifier 不可用仍保留缺口，不认证或替换。实际证据见[工程记录](docs/engineering.md#第八阶段-d两类实时预览主外壳)。完成后停止，不搬 Theme 历史组合、不增加消费者，不迁移标签详情、标题/备注气泡或帮助卡。

第八阶段 C 沿 areachain-workflow → areachain-ui（ui-ux-pro-max 聚焦 modifier 身份）→ areachain-verify。仅扩展 DaybookSurface 并接 SyntaxAutocompletePopup / CaptureAttributesPopup；表现、实时预览边界和实际共享搜索入口见[组件目录](docs/component-catalog.md#第八阶段-c候选与只读属性浮层外壳)。测试先冻结原绘制，沿完整正常 PrivacyQA、独立标识/目录、构建锁、六项钥匙串变量清除和串行 XCTest；静态 profile 与原检查器/反例配合。并发编译失败不得排除文件；实际证据见[工程记录](docs/engineering.md#第八阶段-c候选与只读属性浮层外壳)。指定 Cursor verifier 不可用保留缺口，不认证或替换。完成后停止，不迁移实时预览/帮助卡，不修滚动目标归属、事件或其他历史问题。

统一搜索 4A-3B2 沿 areachain-workflow → areasong-development → areachain-ui → areachain-verify；UI/UX 聚焦 SwiftUI 原生列表、键盘和焦点。复用 Controller / OperationEditing / ObjectSelection，将编辑位置扩展到原 CommandPlan 项；唯一参数所有权、入列、移出、重排、合并与输出引用全部经协调者和领域事件。标准/紧凑隔离宿主共用原 OperationPanel 的有界滚动区域，不增加补全浮层或执行接线。组件与版本见[组件目录](docs/component-catalog.md#统一搜索计划列表4a-3b2)，证据与指定复核/人工/历史缺口见[权威交接](docs/unified-search-commands.md#949-阶段-4a-3b2待执行计划与就地编辑)。不进入 handler 阶段。

第七阶段 D 沿 areachain-workflow → areasong-development UI/架构判据 → areachain-ui → areachain-verify；UI/UX 聚焦原生安全输入的身份、条件挂载与焦点。生产只接 PrivacySetupSheet 四字段，复用 DaybookSecureField / 28pt 输入壳及四个稳定身份；条件、校验、生命周期与 B/C 差异见[组件目录](docs/component-catalog.md#第七阶段-d隐私设置安全输入接入)。先用原 SetupFixture / PrivacyQA 直接挂载生产 sheet 建基线，再用同一宿主回归隐藏恢复、双语主题、键盘、滚动、取消和清空。合法键盘/Apply 先建立原 storageFailure 提前失败保护；不进入配置、认证、文件面板或迁移。静态 profile 配合完整正常隔离 XCTest、独立标识/目录、清除六项钥匙串变量及串行执行。稳定身份沿原检查器和反例维护；指定 Cursor verifier 缺口不替代，B 残留和历史未验项继续保留。到 D 停止，搜索、任务/手记编辑器不迁移。

第七阶段 C 沿 areachain-workflow → areasong-development UI/架构判据 → areachain-ui → areachain-verify；UI/UX 聚焦原生焦点与视图身份。PrivacyUnlockView 仅接已有 DaybookSecureField，接口及与密码 sheet 的空值提交、busy 取消、关闭责任差异见[组件目录](docs/component-catalog.md#第七阶段-c解锁面板安全输入接入)。先直接挂载原 View 并经原 Presenter 注入合成 vault 建基线，再用相同宿主/配置/操作对照。复用原 ControlsPreview、SecureInputTestSupport 和 Presenter 归属/清理方式；静态 profile 配合完整正常 PrivacyQA、独立目录/标识、六项真实钥匙串变量清除和串行测试。稳定接入沿原检查器/反例维护；指定 Cursor verifier 不可用保留缺口，不重复认证或替换。B 的确认字段残留、真人/VoiceOver 和历史缺口保留，完成后停止，不迁移 Setup、搜索或任务/手记编辑器。

第七阶段 B 沿 areachain-workflow → areasong-development 架构/UI 判据 → areachain-ui → areachain-verify；UI/UX 聚焦原生 SecureField 的 Binding 与焦点，不套用普通输入的“不提交”或明文辅助读取。公共 DaybookSecureField 仅接 PrivacyPasswordSheet，四种配置与后续差异见[组件目录](docs/component-catalog.md#第七阶段-b公共安全输入与通用密码弹窗)。复用原 PrivacyButtonSheetHost、隔离设置夹具和 ControlsPreview；静态 profile 配合完整正常 PrivacyQA、独立标识/目录、串行测试及真实钥匙串变量清除。稳定入口沿原检查器和反例维护；指定 Cursor verifier 不可用保留缺口，不重新认证或替换。完成后停止，不迁移 Setup、Unlock、搜索、任务/手记编辑器，不执行真实安全业务。


第七阶段 A 沿 `areachain-workflow` → `areasong-development` UI/架构判据 → `areachain-ui` → `areachain-verify`；UI/UX 仅补 SwiftUI Binding 与焦点检查。普通表单公共入口 DaybookFormTextField 及三个真实字段见[组件目录](docs/component-catalog.md#第七阶段-a普通表单输入与三个输入框)。复用未改的 DaybookInputShell、SettingsButtonTestSupport、ClipboardOptionsFixture、真实 sheet 与 ControlsPreview；静态 profile 配合完整正常 PrivacyQA 目标和串行定向测试，原生事件、编辑 API、程序化 marked text 与真人证据分开。稳定公共入口和两个消费者由原检查器及反例维护，指定 Cursor verifier 不可用保留缺口，不重复认证或替换。完成后停止，不迁移 SecureField、搜索、任务/手记编辑器或其他控件；历史周布局、切周焦点、真实拖放、Tab 等未验项继续登记。

第六阶段 E 沿 `areachain-workflow` → `areasong-development` 架构/UI 判据 → `areachain-ui` → `areachain-verify`；UI/UX 聚焦 SwiftUI 原生按钮身份与辅助语义。CalendarWeekBoard 只接 DaybookDateCell.weekHeader，纯短日期值保留格式来源差异，接口与剩余范围见[组件目录](docs/component-catalog.md#第六阶段-e周视图日期列头接入)。先直接挂载原周看板与生产 CalendarPage，再用完整 PrivacyQA 目标、串行事件和合成内存库验证公共呈现、真实消费者与日期回归。静态 profile 配合独立隔离 Swift 测试/Debug 验签，稳定入口沿原检查器维护。指定 Cursor verifier 缺失保留 partial，不认证或替换；历史周越界、标题挤压、切周焦点、真实拖放及 D 的 Tab 等缺口继续登记。完成后停止，不将业务周看板移入 Theme 或进入其他阶段。

统一搜索 2K-8 沿 areachain-workflow → areasong-development 架构/可靠性规范 → areachain-verify；TagUsageContentQueryReads 复用五类元数据枚举和家庭同批装配，ContentQueryReadSession.prepareTagUsage 负责受门禁发布。旧计数口径、公开次数/排序及精确时间隔离、实际验证和生产前置只见[权威设计 §9.44](docs/unified-search-commands.md#944-阶段-2k-8全来源标签使用统计的只读存储适配与受门禁发布)。只验证隔离合成数据库；指定 Cursor verifier 缺口保留，不重复认证检查，完成后停止。

统一搜索 2K-7 沿 areachain-workflow → areasong-development 架构/可靠性规范 → areachain-verify；TrashContentQueryReads 在 ContentQueryReadSession.prepareTrash 的内部许可中完成六类墓碑及活身份行的独立枚举，复用 2H 投影/查询与原排序、片段、分组、分页。正文授权只开放确认公开的普通墓碑，受保护墓碑不解密。实际覆盖、只读证据与 partial 状态统一见[权威设计 §9.43](docs/unified-search-commands.md#943-阶段-2k-7完整墓碑只读适配与受门禁回收站搜索)。仅隔离合成数据库，不接生产、文件或恢复执行；指定 Cursor verifier 缺口保留，不重复认证检查，完成后停止。

统一搜索 2K-6 沿 areachain-workflow → areasong-development 架构/可靠性规范 → areachain-verify；ImageContentQueryReads 在 ContentQueryReadSession.prepareImages 的内部许可中复用 TaskFamilyContentQueryReader，同批接图片与 has:image。授权、实际全表读取、对象级保护、成本与 partial 状态统一见[权威设计 §9.42](docs/unified-search-commands.md#942-阶段-2k-6图片元数据只读适配同批图片查询与-hasimage)。只用隔离库及合成资料，不读图片文件或生产入口，完成后停止。

统一搜索 2K-5 沿 areachain-workflow → areasong-development 架构/可靠性引用 → areachain-verify；ClipboardContentQueryReader 仅显式存储读取，ContentQueryReadSession.prepareClipboard 复用唯一发布门禁。实际接口、全文件成本、临时合成文件验证及指定复核 partial 状态见[权威设计 §9.41](docs/unified-search-commands.md#941-阶段-2k-5剪贴板历史文件只读适配与受门禁发布)。不读生产历史或系统剪贴板，不初始化监听/历史会话；完成后停止。

统一搜索 2K-4D 沿 areachain-workflow → 架构治理 → areachain-verify；ContentQueryBodyReads、ContentQueryReadSession.prepareBodies 和 DiaryContentQueryReader 共同将正文留在内部许可与唯一冻结所有者中，复用 DiaryContent.read 同批目录校验。外部 Batch 仍仅 metadataOnly；无生产接线。实际接口、授权、生命周期、性能/内存限制和 partial 验证状态统一见[权威设计 §9.40](docs/unified-search-commands.md#940-阶段-2k-4d受搜索生命周期门禁约束的手记正文读取)。

统一搜索 2K-4C 沿 `areachain-workflow` → `areasong-development` 架构/可靠性引用 → `areachain-verify`；ContentQueryReadSession 接注入 vault 的实际通知和 Observation，privacyInvalidated 经协调者只清搜索。接口与隔离验证见[权威设计 §9.39](docs/unified-search-commands.md#939-阶段-2k-4c搜索隐私失效查询清理与结果发布门禁)。指定 Cursor verifier 缺口保持 partial，不重查登录或替代；不接敏感草稿封存、正文或生产窗口，完成后停止。

统一搜索 2K-4B 沿 `areachain-workflow` → `areasong-development` 架构/可靠性引用 → `areachain-verify`；DiaryContentQueryReader 仅显式 metadataOnly 注入读取，同批目录复用和完整限制见[权威设计 §9.38](docs/unified-search-commands.md#938-阶段-2k-4b手记元数据只读适配同批标签装配与隔离回归)。D1～D3 已确认，D3 仅登记；隔离回归后停止，不接生产或 2K-4C。指定 Cursor verifier 缺失继续 partial，不重查认证。

统一搜索 2K-3 沿 `areachain-workflow` → `areasong-development` 架构/可靠性路径 → `areachain-verify`。TagContentQueryReader 读取完整标签目录，TaskFamilyContentQueryReader 同批装配，关联名字继续复用 ContentQueryTagNames；唯一契约、注入统计与全来源统计缺口见[权威设计第 9.36 节](docs/unified-search-commands.md#936-阶段-2k-3标签目录的-swiftdata-只读适配与同批装配)。验证使用原隔离 SwiftData 夹具、TagQuery/任务家庭/旧仓储、ReadOwner/展示分页、Debug 构建与原门禁；不读取手记正文或接生产 UI。指定 Cursor verifier 缺失继续 partial，不重查认证、不替代复核，完成后停止。

统一搜索 2K-2 沿 `areachain-workflow` → `areasong-development` 架构/可靠性路径 → `areachain-verify`。任务家庭读取在同一注入上下文同步装配 todo/subtask/routine；习惯全定义与按需全记录表读取、坏关系限制、当前观察与冻结查询日分离、共享标签及 Batch 记录源问题见[权威设计第 9.35 节](docs/unified-search-commands.md#935-阶段-2k-2习惯与打卡的-swiftdata-只读适配及任务类同批装配)。只跑隔离内存库、相关领域/服务回归、Debug 构建及原门禁；Cursor verifier 缺失继续 partial，不重查认证或替代复核，不进入下一阶段。

统一搜索 2K-1 沿 `areachain-workflow` → `areasong-development` 架构/可靠性路径 → `areachain-verify`。仅在 Services 将显式注入 ModelContext 中的 todo、平面 subtask 与必要标签名称转为 Batch，测试走内存库到 ReadOwner/展示分页；入口见组件目录，唯一契约与证据见[权威设计第 9.34 节](docs/unified-search-commands.md#934-阶段-2k-1任务与子任务的-swiftdata-只读快照适配)。指定 Cursor verifier 仍不可用，不重复认证检查、不以其他复核代替；整体 partial，完成后停止，不接其他来源或生产 UI。

统一搜索 2J-3C 沿 `areachain-workflow` → `areasong-development` 纯领域/架构与可靠性路径 → `areachain-verify`。ReadOwner 只冻结注入 Batch，ContinuationPolicy 只处理提供者预算余量；完整重算复用 BatchReader/Sorter/Presenter/DisplayBuilder，发布复用 Pagination.reset 与稳定锚点。入口与消费者见组件目录，唯一契约和证据见[权威设计第 9.33 节](docs/unified-search-commands.md#933-阶段-2j-3c预算续读同快照重新求值与结果发布协调)。验收选四套新领域测试及既有提供者、聚合、排序、片段、分组和分页回归，严格局部 lint、静态/工作流门禁、原脚本回归及 Debug 构建；原检查器接口不变。指定 Cursor verifier 缺失保持 partial，不重查登录、不替代复核；不接真实仓储、UI、系统调度或持久缓存，完成后停在 2J-3C。

统一搜索 2J-3B 沿 `areachain-workflow` → `areasong-development` 纯领域/架构路径 → `areachain-verify`。PaginationState 复用 Display 的不可变来源与可见性、Browse 的 publish/apply；接口与消费者见组件目录，唯一契约及 2J-3C 交接见[权威设计第 9.32 节](docs/unified-search-commands.md#932-阶段-2j-3b展示分页组内分段与浏览状态接续)。运行四套分页测试、原 Display/Browse/保护、排序/片段/聚合与提供者回归，严格局部 lint、静态/工作流门禁及 Debug 构建；复用原检查器与脚本回归，不另建执行器。指定 Cursor verifier 缺失保持 partial，不重查认证或冒充复核。只实施已读取结果的展示分页，不接生产 UI、预算续读或实际滚动，完成后停在 2J-3B。

统一搜索 2J-3A 沿 `areachain-workflow` → `areasong-development` 纯领域路径 → `areachain-verify`。展示与浏览入口、版本和后续可见性统一见[权威设计第 9.31 节](docs/unified-search-commands.md#931-阶段-2j-3a展示分组可见命中序列与键盘选择)，复用入口见组件目录。运行 Display/Browse/DisplayProtection 与原排序、片段、聚合、墓碑/提供者回归、局部严格 lint、静态/工作流门禁和 Debug 构建。原检查器入口不变，沿原脚本回归；指定 Cursor verifier 缺失保持 partial，不重查认证，不替代复核。只输出纯打开/焦点意图，不接原生 UI、分页、续读或执行，停在 2J-3A。

统一搜索 2J-2B 沿 `areachain-workflow` → `areasong-development` 纯领域路径 → `areachain-verify`。ContentQueryPresenter.project 只消费同批安全排序响应，接口/预算/Unicode/隐私回退与验证统一见[权威设计第 9.30 节](docs/unified-search-commands.md#930-阶段-2j-2b安全摘要命中片段与高亮映射)，复用入口见组件目录。运行四套展示/片段测试及原排序、聚合、九类提供者回归、严格局部 lint、静态/工作流门禁与 Debug 构建。复用原检查器和脚本测试，不新增执行器；指定 Cursor verifier 缺失继续 partial，历史缺口保留。不接 UI、真实展开、键盘/组分页、缓存、真实读取或执行，完成后停止。

统一搜索 2J-2A 沿 `areachain-workflow` → `areasong-development` 纯领域/架构路径 → `areachain-verify`。ContentQuerySorter.sort 只消费同批绑定排序上下文的 ContentQueryBatchResponse，输出平面确定命中身份序列；实际规则与交接见[权威设计第 9.29 节](docs/unified-search-commands.md#929-阶段-2j-2a安全聚合结果的相关性与最近排序)，复用入口见组件目录。验证三套排序测试、原批次与九类提供者/查询回归、严格局部 lint、静态/工作流门禁及 Debug 构建；既有检查器规则不变，继续原脚本回归，不新增执行器。指定 Cursor verifier 缺失仍 partial，历史缺口保留；不接片段、UI、分页、缓存或真实读取，完成后停止，不进入 2J-2B。

统一搜索 2J-1 沿 `areachain-workflow` → `areasong-development` 纯领域/架构路径 → `areachain-verify`。入口 ContentQueryBatchReader.read 从唯一批次装配九个只读提供者，接口/消费者见组件目录，唯一交接见[权威设计第 9.28 节](docs/unified-search-commands.md#928-阶段-2j-1同步批次跨提供者类型化结果与完整性汇总)。验证四套 ContentQueryBatch 集成、原查询/九个提供者/关联/墓碑/记录回归，另跑严格局部 lint、静态及原脚本回归、工作流和 Debug 构建。检查器接口/规则不变，不新增执行器；指定 Cursor verifier 缺失继续 partial，不重查认证或替代复核。不接真实仓储、生产 UI、排序/片段/分页、缓存、异步失效或执行，完成后停止。

统一搜索 2I 沿 `areachain-workflow` → `areasong-development` 纯领域/架构与可靠性路径 → `areachain-verify`。入口 RoutineOccurrenceQueryProvider.read 仅消费显式记录范围和日期窗口，复用 2C-1 归并/历史分段；组件与实际消费者见组件目录，唯一交接见[权威设计第 9.27 节](docs/unified-search-commands.md#927-阶段-2i显式日期窗口内的习惯执行情况只读提供者)。验证四套 RoutineOccurrenceQuery、2C-1/2C-2、完整查询/类型分析、现有提供者与旧看板/逾期/习惯仓储合成回归，另跑静态质量/原脚本回归、工作流、严格局部 lint 与 Debug 构建。检查器接口和规则不变，无新执行器。指定 Cursor verifier 缺失继续 partial，不重查登录或替代复核；不接真实仓储、生产 UI、写入、聚合或全局分页，完成后停止。

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

第四阶段 B 继续 `areachain-workflow` → `areachain-ui` → `areachain-verify`，只接 GeneralSettingsSection 三处普通偏好。公共 DaybookPicker.formRow 的默认布局兼容剪贴板；复用 SettingsButtonTestSupport、PickerNativeTestSupport 与 SystemPageHost.preferenceWindow 做原 AppChrome 动态传播验证。接口、消费者和后续边界见[组件目录](docs/component-catalog.md#第四阶段-b普通设置下拉选择器接入)，验证证据见工程手册；公共只读复核仍指定 Cursor verifier，不可用保留缺口。到 B 停止，不迁移标签合并、自动锁定或分段切换。

第四阶段 C 沿 `areachain-workflow` → `areachain-ui` → `areachain-verify`，只接 TagManagementPage.mergeSheet。公共 DaybookPickerOption 增加 verbatim 原文入口，UUID 与显示文字分离，原本地化初始化及 inline/formRow 兼容；接口与消费者见[组件目录](docs/component-catalog.md#第四阶段-c标签合并目标选择器接入)。复用公共 Picker/WorkspaceMenuConsumerTests、原合并宿主、TagCatalogTests 和 ControlsPreview，合成提交只走确认的内存仓储链路；旧 A/B 消费者回归。指定 Cursor verifier 不可用仍留缺口，不替换。到 C 停止，自动锁定、分段切换及历史缺口不纳入本轮。

第四阶段 E 沿 `areachain-workflow` → `areachain-ui` → `areachain-verify`；通用 DaybookSegmentedControl 与兼容 DaybookSegmentedBar 共用绘制，接口和几何见[组件目录](docs/component-catalog.md#第四阶段-e通用分段与菜单栏)。复用 ControlsPreview、原生宿主和 MenuBarPopoverRenderingTests，定向检查 Binding、动效、草稿/搜索/快捷键及 380pt 布局。稳定入口由原检查器守卫；公共只读复核仍指定 Cursor verifier，不可用留缺口、不替代。完成后停止，不迁移 CalendarPage。

第四阶段 F 继续 `areachain-workflow` → `areachain-ui` → `areachain-verify`；CalendarPage 直接接公共分段，CalendarSpan 单一文案源同时适配顶栏菜单，范围与完整定向清单见[组件目录](docs/component-catalog.md#第四阶段-f日历月周分段接入)。沿原 PrivacyQA XCTest 直接挂载生产日历/顶栏，恢复 BoardSelection 和 WorkspaceNavigation；运行日历、公共分段、菜单栏与工作台相关定向回归。复用原检查器、ControlsPreview 和工程记录，无新公共 API 或执行器；原生对照的列表切周焦点及窄周布局已知失败、指定 Cursor verifier 缺口和历史未验项继续保留。到 F 停止，不改日期选择器、日期格或其他控件。

第五阶段 A 沿 `areachain-workflow` → `areachain-ui` → `areachain-verify`，仅接 TaskRow.timePicker 与 ResidentsPage 提醒弹出层。公共 DaybookTimePicker、原生适配、分钟/空值与后续差异见[组件目录](docs/component-catalog.md#第五阶段-a公共时间选择器与首批消费者)。复用原 PrivacyQA XCTest、ControlsPreview、内存模型/独立偏好及仓储失败注入；原生合成事件、程序化赋值和截图分别取证。公共契约只交 Cursor verifier，不可用保留缺口、不替代。到 A 停止，不迁移详情提醒、截止时间或日期选择器，不补历史日历/主题/H/Stepper 未验项。


第五阶段 B 继续 `areachain-workflow` → `areachain-ui` → `areachain-verify`；只接 TaskDetailRemindChips / TaskDetailDueTime 的分钟 Binding 与弹出层。实际消费者、空值不初始化及草稿/截止差异见[组件目录](docs/component-catalog.md#第五阶段-b详情提醒与截止时间接入)。复用 PrivacyQA XCTest、TimePickerConsumerTestSupport、原事务/仓储失败注入与公共关闭生命周期，并回归阶段 A 两消费者。不新增公共 API、执行器或展示应用；原指定 Cursor verifier、真人及历史未验项继续保留。到 B 停止，日期、星期与日历布局留后续阶段。

第六阶段 A 沿 `areachain-workflow` → `areasong-development` / `areachain-ui` → `areachain-verify`；DaybookDatePicker / DaybookDateCell 只接 DaySchedulePicker 及其四个宿主，接口与复用见[组件目录](docs/component-catalog.md#第六阶段-a公共日期选择器与排期弹窗)。先保留原图形日期基线，再沿 PrivacyQA XCTest 验证生产控件和消费者；ControlsPreview 与原稳定入口检查原地扩展。Cursor verifier 不可用保留缺口，不替代复核。完成后停止，主日历、习惯月历、周布局、星期选择及历史未验项均不扩修。


第六阶段 B 继续 `areachain-workflow` → `areasong-development` / `areachain-ui` → `areachain-verify`，仅接 CalendarMonthGrid。公共日格表现、星期入口、集中几何与业务边界见[组件目录](docs/component-catalog.md#第六阶段-b主日历月网格接入)。复用原 PrivacyQA XCTest、生产 CalendarPage、内存合成夹具和 ControlsPreview；新旧布局、点击、原生拖放接线、程序化回调与规则分别记证据。稳定入口沿原检查器/反例维护，指定 Cursor verifier 不可用保留缺口，不替代。完成后停止，习惯月历、星期选择、周布局和历史未验项不扩修。

统一搜索 4A-1 沿 areachain-workflow → areasong-development → areachain-ui → areachain-verify；ui-ux-pro-max 仅做 SwiftUI 聚焦检索，AppKit 输入机制与 Daybook 样式为实现依据。公共输入与两个隔离宿主的唯一交接见[权威设计 §9.45](docs/unified-search-commands.md#945-阶段-4a-1公共原生搜索输入与斜杠补全)。不接生产入口、结果列表、长正文预览或真实执行；指定 Cursor verifier 与历史缺口保留，不重查认证。


第六阶段 C 沿 `areachain-workflow` → `areasong-development` UI/架构判据 → `areachain-ui` → `areachain-verify`，UI/UX 仅聚焦 macOS 适用的身份与辅助语义。HabitCheckMonthView 接入 DaybookDateCell.habit / DaybookHabitDateState，复用完整日键身份与原 HabitMonth/导航；接口及后续星期选择线索见[组件目录](docs/component-catalog.md#第六阶段-c习惯月历接入公共日期格)。修改前直接挂载原生产组件，之后用完整 PrivacyQA 目标、隔离模型和串行测试比较原几何/像素、标题备注、真实检查器与公共日期回归。静态 profile 配合独立隔离 Swift 测试和 Debug 构建，避免 auto/swift profile 启动普通宿主。指定 Cursor verifier 不可用继续保留缺口，不重查认证或替代复核；不盲目重试 B 的真实拖放。完成后停止，不迁移星期选择、周布局或其他控件。

统一搜索 4A-2 沿 areachain-workflow → areasong-development → areachain-ui（聚焦 SwiftUI/原生检索）→ areachain-verify。公共结果消费原 Presentation / Display / Browse / Pagination，ReadSession 通过同步 ContentQueryDisplayUpdates 撤除原生展示。只用两种隔离宿主与合成数据；生产搜索、操作预览及真实打开未接线。唯一交接见[权威设计 §9.46](docs/unified-search-commands.md#946-阶段-4a-2公共原生搜索结果列表与输入导航)。指定 Cursor verifier 和人工缺口保留，不重复认证检查。

第六阶段 D 沿 `areachain-workflow` → `areasong-development` 架构判据 → `areachain-ui` → `areachain-verify`；UI/UX 只补原生身份与辅助语义。TaskDetailWeekdayPicker 薄适配转交 Theme 的 DaybookWeekdayPicker，三个消费者保留草稿/即时保存差异，接口见[组件目录](docs/component-catalog.md#第六阶段-d公共星期多选与三个消费者)。先直接挂载原控件/消费者测基线，再跑完整正常 PrivacyQA 目标、合成内存库、原事务失败注入、串行鼠标/焦点和像素对照；静态 profile 配合独立 Swift 测试与 Debug 构建，不启动普通宿主。稳定入口继续由 check_workflow.py 守卫；指定 Cursor verifier 缺失保留 partial，不认证或换机制。完成后停止，任务行原生星期子菜单、只读星期标题、周布局及历史未验项不扩修。

统一搜索 4A-3A 沿 areachain-workflow → areasong-development → areachain-ui → areachain-verify；ui-ux-pro-max 聚焦原生表单校验与焦点，不重建设计系统。参数组件按真实目录元数据驱动、只修改协调者 operations；输入补全与下方预览共用原 lease/stamp，结果职责独立。只用合成资料和标准/紧凑隔离宿主，唯一交接见[权威设计 §9.47](docs/unified-search-commands.md#947-阶段-4a-3a普通参数编辑与操作即时预览)。指定 Cursor verifier 与人工缺口继续 partial，不重查登录或替代复核；完成后停止，不接对象选择、待执行列表、生产入口或真实执行。

## 统一搜索 4A-3B1 对象接线

本阶段沿 areachain-workflow → areasong-development → areachain-ui → areachain-verify；ui-ux-pro-max 仅聚焦 SwiftUI 焦点建议，保留 AppKit 原生输入。复用 Controller / OperationEditing、参数字段、结果行、Browse、ReadSession 与原草稿 reducer。只在合成隔离宿主中确认运行内固定目标及普通对象参数；候选限制不改变全局搜索。接口见[组件目录](docs/component-catalog.md#统一搜索-4a-3b1对象参数与固定操作目标)，唯一验收和交接见[权威设计 §9.48](docs/unified-search-commands.md#948-阶段-4a-3b1对象参数选择与操作固定目标的原生接线)。指定 Cursor verifier 不可调用继续 partial，保留人工验收及 4A-3A 外观预期失败；不认证、不替代、不执行真实指令，不进入 4A-3B2。


第八阶段 B 沿 areachain-workflow → areachain-ui（ui-ux-pro-max 聚焦 SwiftUI 身份）→ areachain-verify。先用真实工程编译符号与 PrivacyQA 调用五种重载取基线，再将公共装配集中在 DaybookScroller 的 daybookScrollAssembly；默认和策略差异见[组件目录](docs/component-catalog.md#第八阶段-bdaybookscroll-公共装配)。静态 profile 配合完整正常隔离 XCTest、原构建锁、六项钥匙串变量清除与串行执行；公共结构、原生更新与真实消费者前后比较。指定 Cursor verifier 不可用保留缺口，不重查认证或替换；只登记原目标搜索、羽化和事件未验项。停止在 B，不改浮层外壳、绘制、事件或统一搜索直连。


统一搜索 4A-3C2A 沿 areachain-workflow → areasong-development 架构治理/可靠性 → areachain-verify；不做原生编辑实现。复用 VaultKeyAccess 与唯一 HandoffCoordinator，命令独立载荷、同修订检查点和显式恢复见[组件目录](docs/component-catalog.md#统一搜索-4a-3c2a-命令保护载荷)，唯一契约与验收见[权威 §9.51](docs/unified-search-commands.md#951-阶段-4a-3c2a命令保护载荷与显式恢复)。测试沿现有 build/.build.lock 和正常完整 PrivacyQA 目标，锁不可得则报告未验证；不删锁、不认证、不以其他代理替代指定 Cursor verifier。原生 IME/撤销、4A-3B2 最终原生重验与历史缺口保留，完成后停止。

统一搜索 4A-3C2B 沿 areachain-workflow → areasong-development 架构/可靠性 → areachain-ui（ui-ux-pro-max 聚焦身份/焦点，保留 AppKit）→ areachain-verify。C2A 原服务只增加受控原生暂持与同次修订接续，隔离探针复用 DaybookAppKitTextView；[组件目录](docs/component-catalog.md#统一搜索-4a-3c2b-隔离原生接受探针) 与[权威矩阵](docs/unified-search-commands.md#952-阶段-4a-3c2b原生接受与锁定交错的隔离可行性) 为接口/证据来源。正常完整 PrivacyQA 目标、原测试锁、六项授权变量清除和串行执行；指定 Cursor verifier、4A-3B2 最终原生和人工缺口保留。marked text、绕过 delegate 的 storage 写入与生产敏感入口不开放，停在 C2B。


## 普通偏好共享读写（3A-1A）

沿 areachain-workflow → 架构治理/可靠性 → areachain-ui（UI/UX 聚焦 Observation 与 Binding）→ areachain-verify。复用 AppPreferences、旧 GeneralSettingsSection 四 Binding 和原 QA 宿主；公共入口与真实订阅见[组件目录](docs/component-catalog.md#普通偏好共享入口3a-1a)。仅注入存储与副作用、拆四项普通事件，真实保证和下一阶段前置见[权威 §9.54](docs/unified-search-commands.md#954-阶段-3a-1a普通偏好共享读写与事件拆分)。静态门禁配独立 QA 标识/目录、串行定向测试及原构建锁；锁忙保留缺口，不运行全量包含排除能力的测试。指定 Cursor verifier 缺口保留，不重查认证或替代。完成后停止，不接生产搜索、handler、多项事务或用户设置。


普通偏好 3A-3B1 沿 areachain-workflow → areasong-development 架构治理/工程交付/可靠性 → areachain-verify。只实现显式临时目录的 LocalPreferenceFileStore，复用原四值严格解析，不接 AppPreferences、迁移、指令或 UI；[组件索引](docs/component-catalog.md#普通偏好聚合文件后端3a-3b1)与[权威 §9.58](docs/unified-search-commands.md#958-阶段-3a-3b1版本化聚合文件后端与提交恢复)为接口和证据来源。真实临时文件与窄故障注入，正常完整 QA 目标、独立目录/标识、六项授权清除、原测试锁非等待申请。指定 Cursor verifier 和历史缺口保留，不重查登录或替代复核；停在 B1，迁移与生产启用另定范围。


普通偏好 3A-3B2A 沿 areachain-workflow → areasong-development 架构治理/工程交付/可靠性 → areachain-verify。只在独立测试 suite 和显式临时目录采集旧四键、严格判源、建立只读迁移证据及重开核验；复用原 FileStore/IO 的锁、提交和恢复入口，不新建恢复引擎。接口见[组件目录](docs/component-catalog.md#普通偏好隔离迁移3a-3b2a)，唯一格式、状态表和证据见[权威 §9.59](docs/unified-search-commands.md#959-阶段-3a-3b2a旧四键隔离迁移重开与恢复判定)。完整正常 QA 目标、独立标识/目录、六项授权清除、原验收锁非等待申请；指定 Cursor verifier 与历史缺口保留，不认证或替代。完成停止，不读取真实设置、不切换 AppPreferences、不接指令/UI、不进入 3B2B。


普通偏好 3A-3B2B 沿 areachain-workflow → areasong-development 架构治理/工程交付/可靠性引用 → areachain-verify。AppPreferences 显式临时后端装配复用原 FileStore / MigrationResult，单份发布和普通组事件接口见[组件目录](docs/component-catalog.md#普通偏好整份发布3a-3b2b)，唯一状态、证据与下一阶段边界见[权威 §9.60](docs/unified-search-commands.md#960-阶段-3a-3b2bapppreferences-聚合后端整份发布与展示事件)。完整正常 QA 目标、隔离旧域/目录/副作用、原验收锁非等待申请；并行编译失败不排除源码或抢锁。指定 Cursor verifier 与历史原生缺口保留，不认证或替代；完成后停止，不切换 shared、不迁移用户偏好、不开放多项指令或生产 UI，不进入 3B3。

普通偏好 3A-3B3A 沿 areachain-workflow → areasong-development 架构治理/可靠性/工程交付 → areachain-verify。显式 FileLocalSettingCommandAdapter 复用 AppPreferences 完整记录、共同提交和展示 ledger，Coordinator 独占组身份与原子安装，Run 区分本地与展示结果。[组件目录](docs/component-catalog.md#普通偏好命令共同提交3a-3b3a)记录入口，[权威 §9.61](docs/unified-search-commands.md#961-阶段-3a-3b3a普通设置组准备共同执行与回执)记录契约与实际验证。仅真实临时文件、随机旧键域和注入效果，完整正常 QA 目标及原锁非等待申请；指定 Cursor verifier 与历史缺口保留，不登录或替代复核。完成停止，不接生产后端、多项 UI、真实迁移或下一阶段。

统一搜索 3A-3B3B 沿 areachain-workflow → areasong-development 架构治理 → areachain-ui（ui-ux-pro-max 聚焦 SwiftUI 身份）→ areachain-verify；显式互斥文件装配、原计划共同准备/提交与类型化恢复见[权威 §9.62](docs/unified-search-commands.md#962-阶段-3a-3b3b普通设置共同提交的原生接线)。仅隔离宿主；生产与历史复核缺口不改变。


普通捕获 3T-1A 沿 areachain-workflow → 架构治理/可靠性引用 → areachain-verify；共享入口与旧消费者见[组件目录](docs/component-catalog.md#普通捕获共享新增3t-1a)，提交事实、D1～D3 确认及验收见[权威 §9.64](docs/unified-search-commands.md#964-阶段-3t-1a普通捕获共享新增与事务局部边界)。完整正常 QA 目标、原锁非等待申请、隔离内存模型与显式 fake 系统依赖；指定 Cursor verifier 不可用保留 partial，不重查登录或替代。只提取新增，不接 handler、标题/备注或统一搜索执行，完成后停止。

普通创建 3T-1B 沿 areachain-workflow → areasong-development 架构治理/可靠性 → areachain-verify；固定身份、原运行占用和唯一交接见[权威 §9.65](docs/unified-search-commands.md#965-阶段-3t-1b最小普通-todocreate-的隔离真实适配)，入口见[组件目录](docs/component-catalog.md#最小普通创建指令3t-1b)。只用内存上下文、私有事件与 fake 消费者；完整正常 QA 目标、原构建锁非等待申请、六项钥匙串授权清除，锁忙即停止。指定 Cursor、C2B、人工和历史缺口保留，不认证、不替代；不接生产/原生 UI、其余字段或其他命令，完成后停止。


统一搜索 3T-4A 沿 areachain-workflow → areasong-development 架构治理/可靠性 → areachain-ui（ui-ux-pro-max 聚焦原生提交与焦点）→ areachain-verify。只显式装配最小 todo.create 的隔离原生提交，复用原参数、计划和运行；[组件入口](docs/component-catalog.md#最小任务创建原生提交3t-4a)与[权威 §9.66](docs/unified-search-commands.md#966-阶段-3t-4a最小-todocreate-原生提交与隔离验收)保存边界及证据。原锁、独立 QA 标识/目录、内存库、私有事件源、fake 系统消费者、六项真实钥匙串变量清除和串行测试保持。指定 Cursor、C2B、人工及历史缺口保留；不认证、不替代复核、不启用生产搜索或真实系统操作，完成后停止。


普通新增 3T-2A1 沿 areachain-workflow → areasong-development 架构治理/可靠性 → areachain-verify。只读 CommandTaskCreatePreview 复用目录、parser、标签规范化及原宿主版本，最终字段/标签效果不接写入；[组件索引](docs/component-catalog.md#普通新增只读合成3t-2a1)与[权威 §9.67](docs/unified-search-commands.md#967-阶段-3t-2a1普通新增参数合成与只读标签变更计划)为唯一契约/证据入口。完整正常 PrivacyQA、原锁非等待申请、六项授权清除、显式值目录与合成内存库；指定 Cursor、C2B、人工及历史缺口保留，不认证或替代复核。原 UI / 最小执行资格保持，完成停止，不进入事务接线或下一阶段。


普通新增 3T-2A2 沿 areachain-workflow → areasong-development 架构治理/可靠性 → areachain-verify。显式扩展装配、真实目录预览及版本接受复用原创建占用，共同事务沿 TaskMutationService / InputTagResolver / ModelChanges；[组件入口](docs/component-catalog.md#普通新增扩展事务3t-2a2)与[权威 §9.68](docs/unified-search-commands.md#968-阶段-3t-2a2普通新增的显式扩展事务与隔离适配)保存唯一契约/证据。完整正常 PrivacyQA、原锁非等待申请、六项授权清除、内存库/私有事件/fake 消费者；指定 Cursor、C2B、人工及历史缺口保留，不认证或替代。最小适配、旧 UI、notes 和生产资格不扩展，完成停止。


普通新增扩展原生 3T-4B 沿 areachain-workflow → areasong-development 架构治理/可靠性 → areachain-ui（ui-ux-pro-max 聚焦字段/焦点）→ areachain-verify。复用原 TaskCreate 预览/接受/共同提交、参数/计划与 ReadSession；[组件入口](docs/component-catalog.md#普通新增扩展原生交互3t-4b)与[权威 §9.69](docs/unified-search-commands.md#969-阶段-3t-4b普通新增扩展参数最终效果与明确提交)为唯一契约/证据。原锁非等待、完整正常 QA、六项授权清除、内存库/私有事件/fake 消费者、固定有限原生验收；Cursor/C2B/人工/历史缺口保留，不认证或替代。仅 ordinaryComposition 扩展，minimal/notes/生产边界保持，完成停止。


任务标题 3T-2B1 沿 areachain-workflow → 架构治理/可靠性引用 → areachain-verify；不做 UI 实现。共享 editTitle、只读目录/影响和原 Draft 基线见[组件索引](docs/component-catalog.md#任务标题共享入口与只读影响3t-2b1)，唯一契约、提交事实及 B2 前置见[权威 §9.70](docs/unified-search-commands.md#970-阶段-3t-2b1标题共享修改与普通命令只读影响预览)。完整正常 PrivacyQA、原锁非等待申请、六项授权清除、隔离模型与私有事件/fake 系统依赖；Cursor/C2B/人工/历史缺口保留，不认证或替代复核。旧 UI 备注能力保持，普通预览拒绝长正文；不实现 handler、不扩 UI、不进下一阶段，完成停止。


第十阶段 N 沿 areachain-workflow → areachain-ui（ui-ux-pro-max 聚焦身份/生命周期）→ areachain-verify。仅修手记标题气泡窗口悬停与清理，复用原显示资格、时序和点击语义；[组件责任](docs/component-catalog.md#第十阶段-n手记标题气泡窗口观测)与[原生证据](docs/engineering.md#第十阶段-n手记向上标题气泡悬停保留修复)为交接入口。完整正常 PrivacyQA、原锁900秒有界等待、独立目录/标识、六项授权清除、合成资料和串行指针测试保持；指定 Cursor verifier 不可用保留缺口，不认证或替代。K、L及其他历史问题独立，完成停止，不提交、推送、安装、发布或操作真实数据/系统剪贴板/权限。

任务标题 3T-2B2A 沿 areachain-workflow → areasong-development 架构治理/可靠性 → areachain-verify。只显式装配普通无备注单目标 todo.title；[组件索引](docs/component-catalog.md#普通无备注单目标标题适配3t-2b2a) 与[权威 §9.71](docs/unified-search-commands.md#971-阶段-3t-2b2a普通无备注单目标-todotitle-隔离执行适配) 保存接受/冻结核验、严格共同事务、noChange/unknown 和实际缺口。内存库、私有事件/fake 消费者、完整正常 PrivacyQA、六项授权清除及原锁非等待申请保持；首次锁忙即停止；用户明确要求续验后正常取得原锁，195 方法 / 379 次隔离执行及正常 Debug 验签通过，没有换锁或绕过。Cursor、C2B、人工及历史缺口保留，不认证或替代；不接 UI、不开放多步、不进入下一阶段，不提交、推送、安装或发布。


统一搜索 3T-4C 沿 areachain-workflow → areasong-development（架构治理/可靠性）→ areachain-ui（ui-ux-pro-max 聚焦 SwiftUI、frontend-design 沿 Daybook）→ areachain-verify。标题 UI 仅显式注入 TaskTitleCommandAdapter；沿原对象候选/参数/计划、ReadSession 与 Facts/Run，不接生产/notes/多步。新增共用效果组件、原入口回归及固定原生清单见[组件目录](docs/component-catalog.md#单目标标题原生接线3t-4c)与[权威 §9.72](docs/unified-search-commands.md#972-阶段-3t-4c单目标-todotitle-原生-ui-与隔离验收)。指定 Cursor、C2B、人工/历史缺口保留；锁忙停止，不重查登录或替代复核，完成本阶段停止。

## 统一搜索 T-M1 普通任务本地闭环

本批沿 areachain-workflow → areasong-development 架构/可靠性 → areachain-ui（UI/UX 仅补原生身份与焦点）→ areachain-verify。复用普通修改、原 Plan/Run/Coordinator 与创建/标题适配；[组件入口](docs/component-catalog.md#t-m1-普通字段与受限两步执行)与[权威 T-M1](docs/unified-search-commands.md#973-里程碑-t-m1普通任务修改与受限依赖执行)集中维护范围与证据。用户已授权 A～E 连续实施，旧阶段停止语句只保留历史范围。原锁单次等待最多900秒，锁忙时继续批内独立工作，最后集中补验；完整正常 PrivacyQA、私有事件与 fake 系统消费者保持。指定 Cursor、C2B、人工及历史缺口独立保留，不重复认证、不冒充复核。默认未装配和生产入口继续关闭，不提交、推送、安装、访问真实数据或开放 notes、敏感执行及任意多步计划。

## 统一搜索 T-M2 完成、标签与截止时间

沿 areachain-workflow → areasong-development 架构/可靠性 → areachain-ui（ui-ux-pro-max 聚焦 Binding 与原生身份）→ areachain-verify。原 FieldAdapter 的显式 milestone2 能力、完成子项证据、标签共同事务与 dueMinutes 共享赋值见[组件入口](docs/component-catalog.md#t-m2-完成标签与截止时间)，A～E 状态和实际证据集中在[权威 T-M2](docs/unified-search-commands.md#974-里程碑-t-m2完成标签与截止时间的隔离闭环)。单目标、单操作和原 create→title 边界保持；完整正常 PrivacyQA、合成内存库、私有事件/fake 消费者、六项真实授权清除、原锁单次900秒及串行原生保持。锁屏暂停焦点测试，继续独立事项；正常签名到期与指定 Cursor verifier 缺口单独保留，不续签、不改个人配置、不以 QA 代替正常签名。没有生产搜索、真实库/系统、notes/敏感执行、批量/任意多步、执行后撤销、跨重启恢复或发行授权。


## 第十阶段剩余运行问题

Stepper 警告与 H 截止补证沿 areachain-workflow → areachain-ui（UI/UX 仅核对 SwiftUI 焦点/身份）→ areachain-verify。Stepper 只改局部焦点呈现通知，复用原事件/attachment 防线和两处剪贴板消费者；H 只检查当前真实 setDue 的注入能力，缺少接点不新增生产保存 API。完整正常 PrivacyQA/XCTest、原锁900秒、六项授权清除和只读进程收尾保持；不启动 Gallery 或桌面入口。根因与通过/警告/未验项只记在[原 O/P 续记](docs/engineering.md#第十阶段剩余运行问题stepper-警告与-h-截止注入核对2026-10-08)，指定 Cursor verifier 不可用不以其他代理替代，整体 partial 与原人工分类不变。

## 统一搜索 T-M3 普通子任务

沿 areachain-workflow → areasong-development 架构/可靠性 → areachain-ui（UI/UX 聚焦身份、Binding 与原生焦点，frontend-design 沿 Daybook）→ areachain-verify。结构化仓储/共享赋值、父子实体核验、独立来源证明与类型化事实见[组件入口](docs/component-catalog.md#t-m3-普通子任务隔离闭环)，A～E 与真实证据只维护在[权威 T-M3](docs/unified-search-commands.md#975-里程碑-t-m3普通子任务的隔离闭环)。仅显式完整 PrivacyQA、合成内存库、私有事件/fake 消费者；原锁单次900秒、六项授权清除及原生串行保持。正常签名已过期时不重复失败构建，不续签、不改配置或申请资源；指定 Cursor verifier 不可调用继续保留缺口。未装配能力、生产、排序/删除/批量、notes/敏感输入和子任务输出依赖继续关闭，不提交、推送、安装或发布。

## 统一搜索 R-M1 习惯定义五字段

沿 areachain-workflow → areasong-development 架构/可靠性 → areachain-ui（UI/UX 聚焦原生校验与身份，frontend-design 沿 Daybook）→ areachain-verify。普通无备注单定义的标题/星期/提醒/优先级/标签及原仓储复用见[组件目录](docs/component-catalog.md#r-m1-习惯定义五字段)，唯一 A～E 状态和证据见[权威 R-M1](docs/unified-search-commands.md#976-里程碑-r-m1习惯定义五字段的隔离闭环)。完整正常 PrivacyQA、合成内存库、私有事件/fake 消费者、六项授权清除及原锁单次900秒保持；锁屏暂停焦点测试。正常签名到期、指定Cursor、C2B与人工/历史缺口独立保留；不认证、不替代指定复核、不启用生产/新增/启停/打卡/排序/删除/批量/notes或新的多步执行。

R-M1 旧习惯标题 Bool 嵌套兼容修复沿 areachain-workflow → areachain-verify；仅同步返回事实与旧映射，复用原事务、冻结算法及实际 Bool 消费者。修复、复现、定向服务/原生与完整QA证据只记在[权威修复记录](docs/unified-search-commands.md#旧习惯标题-bool-嵌套兼容修复2026-10-08)，O/H引用；不改命令 saved、H或Stepper。指定Cursor不可调用保留缺口，整体partial、用户未接受，不提交、推送、安装或发布。

K真实输入、L持续按压与关键可访问性沿 areachain-workflow → areachain-ui（ui-ux-pro-max仅核对焦点与辅助语义）→ areachain-verify。复用ControlsPlatformAcceptance、原P runner及安全输入/Stepper测试支持，先短回归及清理再确认当时人工窗口；每批最多600秒含30秒收尾。桌面入口继续暂停，只有完整PrivacyQA/XCTest启动；不改生产安全、重复、保存或事务。测试入口见[组件目录](docs/component-catalog.md)，当轮人工/自动/未执行与K/L判定仅维护[原O/P续记](docs/engineering.md#剩余平台验收kl与关键可访问性2026-10-08)；指定Cursor不可用不替代，整体partial、用户未接受。

## 统一搜索 R-M2 普通习惯结构化新增

沿 areachain-workflow → areasong-development 架构／可靠性 → areachain-ui（UI/UX 聚焦原生校验，frontend-design 沿 Daybook）→ areachain-verify。原创建占用、目录合成、共同事务与参数组件复用见[组件目录](docs/component-catalog.md#r-m2-普通习惯结构化新增)，A～E 及启停／打卡兼容建议只维护在[权威 R-M2](docs/unified-search-commands.md#977-里程碑-r-m2普通习惯结构化新增与状态兼容核验)。启停／打卡仅只读与合成特征验证，不实现 handler 或迁移。完整 PrivacyQA、独立标识／目录、合成内存库、私有事件／fake 消费者、六项授权清除及原锁单次900秒保持；正常签名和指定 Cursor verifier 缺口独立，不认证或替代复核，不接生产或扩大多步／敏感／notes 边界。


## 统一搜索 R-M3 习惯状态

沿 areachain-workflow → areasong-development 架构／可靠性 → areachain-ui（UI/UX 聚焦稳定日期身份与滚动，frontend-design 沿 Daybook）→ areachain-verify。复用入口见[组件目录](docs/component-catalog.md#r-m3-习惯启停与指定执行日)，D1～D3批准、精确写集／共同提交／unknown和最终证据只维护在[权威 R-M3](docs/unified-search-commands.md#978-里程碑-r-m3兼容跳过习惯启停与指定执行日状态)。完整正常PrivacyQA、独立RM3目录／标识、合成内存库、私有事件／fake消费者、六项钥匙串变量清除、原锁单次900秒和串行原生保持；锁屏暂停焦点测试并继续独立事项。正常签名和指定Cursor复核不可用时分别保留缺口，不认证或替代，不接生产、真实数据、批量、多步、notes、敏感执行或执行后撤销，不提交／推送／安装／发布。

## 统一搜索 B-M1 固定多目标

沿 areachain-workflow → areasong-development 架构／可靠性 → areachain-ui（ui-ux-pro-max 聚焦身份／焦点，frontend-design 沿 Daybook）→ areachain-verify。复用入口见[组件目录](docs/component-catalog.md#b-m1-固定多目标共同提交)，一个操作／固定集合／共同保存与 unknown 的唯一契约和证据见[权威 B-M1](docs/unified-search-commands.md#979-里程碑-b-m1固定多目标改期与混合标签共同提交)。完整正常 PrivacyQA、独立 BM1 标识／目录、合成内存库、私有事件／fake 消费者、六项钥匙串变量清除、原锁单次900秒及原生串行保持。正常签名到期、指定 Cursor verifier、C2B 和人工／最低系统／多窗口缺口独立保留；不认证、续签或替代指定复核。不接生产、真实数据／系统、批量完成／启停、自动拆批、新多项计划、notes、敏感执行或执行后撤销，不提交／推送／安装／发布。


## 统一搜索 B-M2 批量状态

沿 areachain-workflow → areasong-development 架构／可靠性 → areachain-ui（ui-ux-pro-max 聚焦身份／Binding／焦点）→ areachain-verify。原 Batch／T-M2／R-M3 共同规则与精确应用复用见[组件目录](docs/component-catalog.md#b-m2-批量状态与精确实体写集)，已批准总量、日期／级联／补录、A～E实际证据与缺口只维护在[权威 B-M2](docs/unified-search-commands.md#980-里程碑-b-m2批量状态级联与补录总量控制)。本批4000实体限制只适用于两类批量状态，不能自动改单项绕过。完整正常PrivacyQA、独立BM2身份／目录、原锁单次900秒、六项授权清除、合成数据与原生串行保持；正常签名已由本批当前Debug验证更新，指定Cursor缺口仍独立，不认证或替代复核。不接生产、真实系统、自动拆批、新多项计划、notes／敏感执行或执行后撤销，不提交／推送／安装／发布。

## 统一搜索 P-M1 普通多项计划

沿 areachain-workflow → areasong-development 架构／可靠性 → areachain-ui（ui-ux-pro-max 聚焦状态身份和错误恢复）→ areachain-verify。显式装配、原 Plan／Run／Coordinator、逐单元实际调用及运行内恢复入口见[组件目录](docs/component-catalog.md#p-m1-普通多项计划与运行内恢复)，已批准unknown整计划暂停、支持形状、A～E状态和真实证据只维护在[权威 P-M1](docs/unified-search-commands.md#981-里程碑-p-m1普通多项计划顺序提交与运行内恢复)。完整正常PrivacyQA、独立PM1身份／目录、合成数据、私有事件／fake消费者、六项授权清除、原锁900秒及原生串行保持；最终正常development Debug与验签使用当前源码，不沿旧到期记录停验。指定Cursor不可用保留缺口，不认证或替代；C2B和人工／历史问题独立。不接生产、真实系统、其他输出链、notes／敏感执行、删除、自动拆批、执行后撤销或跨重启恢复，不提交、推送、安装或发布。

## 工作台公共框架

沿 areachain-workflow → areasong-development / areachain-ui（ui-ux-pro-max 聚焦原生身份和宽度，frontend-design 沿 Daybook）→ areachain-verify。单行顶栏、真实宽度操作收纳、详情空间门禁与局部顶部羽化的入口见[组件目录](docs/component-catalog.md#3-feature-级复合组件)，状态所有权见[公共顶栏架构](docs/architecture.md#工作台公共顶栏)。复用原搜索、workspaceHeader、workspaceInspectorTargets、EditDrafts 和 ScrollScope；不接统一搜索命令，不改保存事务。验证使用完整正常隔离 QA 目标、合成数据、原锁单次900秒和六项授权清除；桌面控制暂停，原生由 XCTest 启动。指定 Cursor verifier 不可调用时记录未执行，整体保留 partial，不认证或替代；不安装、提交、推送或发布。

验收收尾先核对完整源码清单及历史 QA 进程；无法恢复的启动来源/副作用不由新测试追认。字体按实际可见原生控件和系统中文回退精确核验，组合输入收起沿原详情焦点标志与 EditDrafts 保留；定向入口见组件目录。原生前先编译、确认当时桌面条件，执行后按本批 pid/start/path 核对退出；合成 marked text、缓存图、系统窗口截图和真人操作分别记录。唯一收尾记录仍为原[工作台公共框架章节](docs/engineering.md#工作台公共框架调整2026-10-09)。

## P-M2 类型化创建输出

沿 areachain-workflow → areasong-development／areachain-ui（ui-ux-pro-max 聚焦原生身份与确认）→ areachain-verify。复用原 Plan／Run／Coordinator、成员 Reader 和 PlanLinks；仅显式 typedCreation 装配开放三类输出的受限消费、分支和多级链，默认 P-M1 与旧单项／T-M1 保持原范围。实际接口见[组件目录](docs/component-catalog.md#p-m2-类型化输出与消费绑定)，批准规则和有限验证只维护在[权威 P-M2](docs/unified-search-commands.md#982-里程碑-p-m2类型化创建输出受限分支与多级创建链)。完整正常 PrivacyQA、独立 PM2 标识／目录、原锁900秒、合成内存库、六项授权清除和串行原生保持；当前源码补正常 development Debug／严格验签。指定 Cursor verifier 不可调用时保留缺口，不能用普通代理替代；不接生产、真实数据／系统、安装或发布。
