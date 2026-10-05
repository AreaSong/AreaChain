# 架构与目录

### 第九阶段 C 筛选浮层呈现边界

DaybookFloatingSurface.filterFlyout 只扩展纯呈现：regular/continuous、页面底色、65%／0.8pt 内描边与背景阴影。它复用 floating 装配及装饰描边非命中政策，其他预设继续原居中描边与阴影；isPresented 不分支重建正文，静态卡片和交互表面接口不变。

MenuBarFilterFlyout 两处 background/overlay 收口，布局、原生 ScrollView、类别 Binding、延迟关闭 Task、精确 BoardFilters 写回和 onDismiss 仍属于原 Feature。宿主独占遮罩/位置/zIndex、底栏穿透、帮助与 Escape 优先级；无模型、存储或真实 NSPopover 生命周期变更。范围及验证入口见[组件目录](component-catalog.md#第九阶段-c菜单栏筛选浮层外壳)。

### 第九阶段 B 静态卡片呈现边界

DaybookSurface 的 `daybookStaticCardSurface()` 只提供固定静态绘制，不复用带内部 hovering 的交互 modifier，不引入状态或布局。原 `.card` 自动悬停与选择、floating 描边非命中政策保持。TasksPage 的两种昨日组合只替换背景/内描边，显隐、布局选择、投影、行检查日与逐项移动仍属于原 Feature；公共层不接模型、查询、导航或保存回调。接口和验证边界见[组件目录](component-catalog.md#第九阶段-b昨日事项静态卡片外壳)。

### 第八阶段 F 动态气泡呈现边界

DaybookFloatingSurface.rowBubble 只消费外部悬停与复制反馈值，在原 floating 装配中集中 small/continuous、页面底色、0.8pt 居中动态描边及背景阴影。状态切换不分支重建内容；isPresented 只开关装饰，五个静态预设与旧接口保留。装饰描边继续不参与命中，帮助层级/Escape 修复不变。

RowTitleBubble 与 RowNoteBubble 独占原事件、反馈和 Task 生命周期；公共层没有回调、计时器、悬停处理或状态镜像。备注仅 noteCardContent 被装饰，箭头仍在卡片外，圆角标题与矩形备注点击区各自保持。三消费者的显隐、敏感判断和偏移不下沉，Void 复制回调不能证明系统写入成功。接口、合理差异及验证入口见[组件目录](component-catalog.md#第八阶段-f标题与备注气泡动态外壳)，实际证据见[工程记录](engineering.md#第八阶段-f标题与备注气泡动态外壳)。


普通设置 3A-2 在原 UnifiedSearchController 显式注入 LocalSettingCommandAdapter；仅四项能力开放到隔离 UI。Features 只衔接原事件及投影实际 report，prepare 将真实标量基线写入原 draft，enqueue / seal / attempt 继续唯一移交。ReadSession 负责显示资格；最后写入也核对同一显示会话，写入后撤显示不撤销原 Run 事实。成功/noChange 仅通过原 releaseExecution 显式释放，未知/已提交失败不退回草稿；结果和证据只维护在[权威 §9.56](unified-search-commands.md#956-阶段-3a-2四类普通设置的原生提交冲突和反馈)。生产搜索、其他命令、多项与安全撤销仍关闭。

### 普通设置单项运行（3A-1B）

Services 的 LocalSettingCommandAdapter 仅显式组合现有 AppPreferences 和 CommandHandoffCoordinator。CommandPreferenceBaseline 是无平台标量证据，挂在原 CommandDraftBaseline；适配器的私有签发登记防止合成值成为执行依据，不建立偏好镜像。当前 operation/attempt 在协调者先占用，再由共享偏好入口重新读回原值、核验最后 lease 并同步写入；可信完成可跨同一 ownership 的展示修订，不能跨运行或转交代次。

Run 保留 noChange、写调用/读回以及独立 preferencePresentation 结果。未知不重试；只允许确实未提交的单项经受限转移返回原计划并推进版本。多项不封存、不逐键部分执行；生产搜索、敏感输入、多项事务及撤销继续关闭。完整接口、冲突确认和证据以[权威 §9.55](unified-search-commands.md#955-阶段-3a-1b普通设置单项真实适配与隔离验证)为准。

### 第八阶段 E 标签详情与语法帮助外壳

DaybookFloatingSurface 的 tagDetail / syntaxHelp 只表达 regular/medium continuous 圆角及共同的 60% / 0.8pt 居中描边，沿既有背景阴影装配；颜色、描边与阴影由公共层维护。原 suggestions/readOnly/smallBackground 的 70% / 0.7pt、阴影和 isPresented 身份保持。公共层不接布局、裁切、事件或状态，帮助原 clipShape 继续在消费者装饰之后裁切；公共完整阴影与实际帮助裁切是两类证据。

仅替换 LiveComposerPreviewHeader.tagDetailBubble 与 SyntaxExpandableCard 的重复背景/边框，不搬历史 Theme 业务。标签出现条件、解析、滚动与草稿不动；MenuBarPopoverView 保留唯一帮助状态、上下文、示例替换/搜索追加及关闭焦点责任，只作为隔离测试入口。接口、标题/备注动态边框的后续线索及证据见[组件目录](component-catalog.md#第八阶段-e标签详情与语法帮助卡外壳)和[工程记录](engineering.md#第八阶段-e标签详情与语法帮助卡外壳)。

### 第八阶段 D 实时预览主外壳

任务 mainRow 直接复用 suggestions；手记 body 的 smallBackground 与 suggestions 共用背景阴影装配，但保留 small/continuous。手记仍先绘 row 悬停表面，再按 !showsSuggestions 开关浮层装饰；开关只作用于背景/边框/阴影，内容身份与复制反馈不归公共层。readOnly 的整体阴影及旧表面接口不改。

两处仅删除重复绘制，不搬移 Theme 历史业务组合、不增加生产消费者；内容、解析、敏感投影、悬停、回调和定位仍在原组件。SyntaxAutocompletePopup 的任务双层与手记伴随候选无自身浮层装饰保持。剩余气泡及验证边界见[组件目录](component-catalog.md#第八阶段-d两类实时预览主外壳)和[工程记录](engineering.md#第八阶段-d两类实时预览主外壳)。

### 第八阶段 C 候选与只读属性表面

DaybookSurface 的 floating 重载只组合页面底色、居中描边、圆角和既有 elevation。suggestions 的阴影只作用于背景，readOnly 作用于整个面板；没有表面状态、布局、命中扩区或事件策略。旧 panel 保持独立的内描边及原 modifier 行为。候选独立预览关闭装饰而不分支重建内容，实时预览仍拥有原外壳。

SyntaxOverlay / UnifiedSearchOverlay 保留唯一定位与来源选择；内容、滚动、属性解析/关闭、原生候选替换和搜索许可不下沉公共层。接口、两个已迁移消费者及未迁移边界见[组件目录](component-catalog.md#第八阶段-c候选与只读属性浮层外壳)，验证缺口见[工程记录](engineering.md#第八阶段-c候选与只读属性浮层外壳)。

### 统一搜索计划编辑（4A-3B2）

UnifiedSearchController 只从 CommandHandoffCoordinator 读取唯一 CommandHostSession.plan；UnifiedSearchBuffer 的 plan/item stamp 与原 draft/lease/display 版本绑定编辑位置。OperationEditing 和 ObjectSelection 共用 editingDraft，经 PlanEditing 转为原计划事件，不复制计划草稿到 active。参数拼写仅供原生输入恢复，没有独立提交能力。计划列表与草稿同在原 OperationBoundary，失焦/锁定卸载明细而保留运行内内容；隐藏不是敏感封存。

合并只经 CommandPlanSemantics，输出候选只经目录声明与 CommandPlanValidation；移除仍退回 retained。领域 link 支持逐项修复既有过期引用，整图门禁未放宽。无 handler、封存或协议执行接线；接口、证据、人工与指定复核缺口见[权威交接 §9.49](unified-search-commands.md#949-阶段-4a-3b2待执行计划与就地编辑)。

### 隐私设置安全输入呈现（第七阶段 D）

PrivacySetupSheet 的四个密码仍唯一归原 @State，DaybookSecureField 只接 Binding。methods 的创建/配置条件、useMaster、原 candidates 计数和两组独立 Character 长度/匹配规则均未移动；四个稳定字段身份区分两个同名确认输入。没有新增 onSubmit、清空策略、密码镜像或焦点路由。

Setup 捕获提交输入后保持界面字段，直到原成功、catch、取消或 onDisappear 清空；busy 禁用滚动区及取消/应用/交互关闭，不复用 B/C 的 busy 交互政策。隔离验证只利用原 StoreHealth 内存回退 guard 的提前失败，不能证明配置创建、备份取消、迁移失败或完整认证链。组件清单与证据见[组件目录](component-catalog.md#第七阶段-d隐私设置安全输入接入)。

### 解锁面板安全输入呈现（第七阶段 C）

PrivacyUnlockView 只把密码呈现交给既有 DaybookSecureField；状态仍是原 password/busy/error。密码按钮非空条件与 authenticate 仅防 busy 的守卫分别保留，聚焦空值 Return 不增加校验。开始认证的捕获/清空/Task 顺序与 onDisappear 清空不改；取消在 busy 时可用且只回调，原 Presenter 继续负责锁定、关闭和 continuation。与 PrivacyPasswordSheet 的校验及 busy 禁止取消差异必须保留，不能下沉为公共安全输入策略。

隔离测试显式注入合成 vault，区分直接 View 回调与原 Presenter 请求完成/取消/迟到结果。实际 Presenter 的 locale 沿原 shared 偏好只读读取。接口、Setup 后续四字段差异及证据见[组件目录](component-catalog.md#第七阶段-c解锁面板安全输入接入)；未触及认证、权限、密码处理或加密边界。

### 公共安全输入呈现（第七阶段 B）

Theme 的 DaybookSecureField 只承载原生 SecureField、既有输入壳及瞬时焦点。密码仍在消费者 Binding；没有密码镜像、额外草稿、规范化、日志或撤销历史。公共层不安装 onSubmit，PrivacyPasswordSheet 的两个字段继续显式调用原 submit；input 捕获、宿主字段清空、Task/action、busy、失败与 onComplete 均保留原顺序。界面字段清空不等于 Swift String 或内存安全擦除。

父页面继续拥有关闭与真实业务动作；本阶段四种配置的隔离 sheet 只证明注入回调及界面兼容，不证明真实认证/备份/恢复链路。后续安全消费者差异、公共接口与验收索引见[组件目录](component-catalog.md#第七阶段-b公共安全输入与通用密码弹窗)。


### 普通表单输入公共组合（第七阶段 A）

Theme 的 DaybookFormTextField 只组合 SwiftUI 原生 TextField、DaybookInputShell 的紧凑配置、公共字体/颜色与瞬时焦点。字符串草稿仍由 Feature 的 Binding 持有；本地化键与已解析文案使用不同初始化入口，输入内容不翻译、解析或规范化。公共层不持有业务错误、保存、关闭或隐式提交。任务语法、统一搜索状态、手记编辑与 SecureField 保留各自责任，不共享普通表单的提交算法。

TaskDetailTagSelector 和 ClipboardHistoryOptions 三个字段使用同一公共实现；前者创建回调失败保留弹窗、编辑清错，后者接受后即时保存、取消不回滚且正则编辑不清错。新建重复事项的标签通过原 resolveTaskTag 立即保存，并非随事项草稿延迟保存。接口、预期外观变化和验证入口见[组件目录](component-catalog.md#第七阶段-a普通表单输入与三个输入框)。

### 周日期列头公共呈现（第六阶段 E）

CalendarWeekBoard 只将日期按钮转交 DaybookDateCell.weekHeader(shortStamp:)；公共层拥有两行布局、原 quiet 承载和完整日期辅助语义，选中值由外部提供且重选仍回调。shortStamp 是已格式化的纯字符串，以保留原默认日历来源；日号和完整辅助日期沿环境 calendar，不改民事日规则。picker/monthGrid/habit 的默认与附加参数保持兼容。

列顺序、整列选中表面、列表/滚动/焦点、检查目标及所属日、周导航、拖放接收与保存继续归原 Feature。原 dropDestination 仍覆盖整列，不下移到按钮；公共层不接模型、查询、导航或第二份业务状态。接口、剩余范围与运行缺口见[组件目录](component-catalog.md#第六阶段-e周视图日期列头接入)和[工程记录](engineering.md#第六阶段-e周视图日期列头接入)。

统一搜索 2K-8 在受控 Session 内按需读取全来源标签使用元数据，复用原全枚举依赖、同批实体及 TagUsage 的唯一计数规则。真实统计与 injected 来源分开；公开 TagQueryUsageSummary 仅含次数，最近排序不外传精确时间。既有来源/隐私/宿主门禁约束全部发布；性能、生产监听、指定复核和完整接口见[权威设计 §9.44](unified-search-commands.md#944-阶段-2k-8全来源标签使用统计的只读存储适配与受门禁发布)。

统一搜索 2K-5 在 Services 显式注入 ClipboardHistoryStore，单次全文件读取后按原 ClipboardHistoryFile 解码；缺失、解码成功与读取/格式失败分开表达。ClipboardContentQueryReader 原样装入 Batch，ReadSession.prepareClipboard 复用当前查询、隐私失效、冻结和发布门禁，宿主不持有底层 owner。磁盘值快照不代表未保存运行内历史或 SwiftData 跨存储事务；成本、失败、临时文件证据及 partial 交接见[权威设计 §9.41](unified-search-commands.md#941-阶段-2k-5剪贴板历史文件只读适配与受门禁发布)。

统一搜索 2K-4D 沿 areachain-workflow → 架构治理 → areachain-verify；ContentQueryBodyReads、ContentQueryReadSession.prepareBodies 和 DiaryContentQueryReader 共同将正文留在内部许可与唯一冻结所有者中，复用 DiaryContent.read 同批目录校验。外部 Batch 仍仅 metadataOnly；无生产接线。实际接口、授权、生命周期、性能/内存限制和 partial 验证状态统一见[权威设计 §9.40](unified-search-commands.md#940-阶段-2k-4d受搜索生命周期门禁约束的手记正文读取)。

统一搜索 2K-4C 的 Services ContentQueryReadSession 独占注入 ReadOwner，并以固定宿主 ownership、当前 lease、本地失效代次、vault 实际状态和 source/task 约束读取及发布。willLock 同步撤权与只清搜索；Observation 重订阅期间门禁关闭；失焦保留查询但撤显示。只通过协调者系统失效入口改 query，不改草稿/计划/执行或 PrivacyVault 规则。完整事件、线程、外部副本、生产接线责任与 partial 证据见[权威设计 §9.39](unified-search-commands.md#939-阶段-2k-4c搜索隐私失效查询清理与结果发布门禁)。

统一搜索 2K-4B 在 Services 显式启用 DiaryContentQueryReader 的 metadataOnly 读取能力；仓储无实例全枚举避免全局 vault 初始化，快照无正文且不可读，同批 metadata 最后唯一装配。保护标签目录与名字投影独立诊断，不提升图片/回收站隐私覆盖，不生成统计；只用注入上下文与合成库，无生产失效或宿主接线。实际 API、D1～D3 状态、验证及 2K-4C 前置见[权威设计 §9.38](unified-search-commands.md#938-阶段-2k-4b手记元数据只读适配同批标签装配与隔离回归)。

统一搜索 2K-3 在同一 Services 装配链增加 TagContentQueryReader：标签内容由原目录仓储全量只读枚举，关联名字由 ContentQueryTagNames 对同批实体分别投影；完整目录不提升 privateTagIDs 或 diaryPrivacy 覆盖。TaskFamilyContentQueryReader 原上下文入口同步装配所有已接来源，统计只接受明确注入并记录来源，不读取手记补齐统计。纯值冻结、失败及指定复核 partial 的唯一交接见[权威设计第 9.36 节](unified-search-commands.md#936-阶段-2k-3标签目录的-swiftdata-只读适配与同批装配)。

统一搜索 2K-2 的 TaskFamilyContentQueryReader 在 Services 共用 2K-1 任务快照读取、独立习惯读取和关联标签装配，一份 Batch 流入既有 ReadOwner。观察时刻是读取调用的明确依赖，Calendar 必须与证据解释环境一致；冻结查询 today 不充当时钟。BatchRoutineFacts.checkSourceProblem 跨过空定义集保留无法归属的记录缺口，普通局部缺口仍由按习惯/日期覆盖表达。没有模型/仓储写入或生产接线，范围、全记录读取成本及 partial 复核见[权威设计第 9.35 节](unified-search-commands.md#935-阶段-2k-2习惯与打卡的-swiftdata-只读适配及任务类同批装配)。

统一搜索 2K-1 的 Services `TaskContentQueryReader` 同步读取调用方注入的上下文，输出纯值 Batch；Domain 与生产 UI 未修改。实体只在 MainActor 使用，来源代次仍由原 ReadOwner.begin 管理。任务/子任务之外保持未提供，完整性不等同磁盘事务原子性。接口、未保存变化、失败和指定复核 partial 见[权威设计第 9.34 节](unified-search-commands.md#934-阶段-2k-1任务与子任务的-swiftdata-只读快照适配)。

统一搜索 2J-3C 的 ContentQueryReadOwner 在 Domain 单独保留一份冻结 Batch 值与读取来源代次，任务只含身份和预算；同步求值产生不可外部拼装的候选票据，核验来源与当前任务后才完整发布。发布结果仅沿原 Pagination/Browse 保留一条安全展示来源链；来源代次、任务身份、提供者预算、展示 sourceID 和 revision 独立。无进展、失败和普通取消保留最后完整结果；保护失效入口丢弃本所有者引用并拒绝旧票据，但未接真实锁定/宿主缓存清理。接口与同步取消限制只见[权威设计第 9.33 节](unified-search-commands.md#933-阶段-2j-3c预算续读同快照重新求值与结果发布协调)，指定复核及历史缺口保持 partial。

统一搜索 2J-3B 在纯 Domain 中组合既有 Display/Browse。DisplaySnapshot 以不可变引用持有安全来源，sourceID 绑定结果集与排序，version 绑定单次可见性修订；分页只持有三类前缀进度及身份，浏览选择/展开仍唯一属于 BrowseState。每次加载复用来源并经原 publish 发布；新来源 reset 重建首段并返回稳定身份锚点，未引入查询、排序、片段或读取调度。接口、计数/保护与指定复核 partial 唯一见[权威设计第 9.32 节](unified-search-commands.md#932-阶段-2j-3b展示分页组内分段与浏览状态接续)，无生产 UI 或真实焦点/滚动验收。

统一搜索 2J-3A 新增纯 Domain 展示分组与浏览状态层，位于 Presenter 之后；顶层保存同批安全来源，单位及选择仅引用类型化身份。DisplayBuilder 不重新匹配/排序，BrowseState 不触及 CommandDraftTargets 或系统焦点。稳定组、显式可见成员、版本拒绝和打开/焦点意图的唯一契约及验收见[权威设计第 9.31 节](unified-search-commands.md#931-阶段-2j-3a展示分组可见命中序列与键盘选择)；尚无生产接线，指定复核及历史缺口保留。

统一搜索 2J-2B 的 ContentQueryPresenter.project 在 Domain 消费 ContentQuerySortedResponse，按完整 ordered.id 输出纯文本、结构化元数据/所属关系和字素高亮映射。顶层保留一次原来源，行内只含展示值与公开字段展开引用；SortFields 与排序共享提取，SortContext 绑定同批条件形状以核验证据。当前消费者仅领域测试，无 UI/IO/缓存/执行；安全边界、预算、原生两行未验及指定复核 partial 见[权威设计第 9.30 节](unified-search-commands.md#930-阶段-2j-2b安全摘要命中片段与高亮映射)。

统一搜索 2J-2A 在 Domain 增加 ContentQuerySorter.sort，消费原批次响应及同次构造的最小不可变 ContentQuerySortContext。上下文只保留条件 ID、原文字条件、显式模式标记与日期环境，不保存 Session、宿主状态或原始对象；排序 API 不接受替换查询。安全投影只用于校验证据、分档与真实时间，输出身份序列与解释，source 原样保留保护/完整性/诊断和墓碑 groups。生产消费者、片段、UI、分页与缓存均未接入；规则和指定复核 partial 见[权威设计第 9.29 节](unified-search-commands.md#929-阶段-2j-2a安全聚合结果的相关性与最近排序)。

统一搜索 2J-1 的 ContentQueryBatchReader 在 Domain 同步装配九个原提供者。批次是唯一 Session、主快照、日期环境与辅助事实的值输入边界；共享任务嵌套视图只装配一次，墓碑保留平面子项，原匹配/安全投影继续由各提供者负责。类型化结果与来源反馈不持有原批次、实体或操作能力；完整性按类型、来源、未知、保护、历史/记录和枚举分层。真实仓储事务、异步代次、隐私失效、UI、排序/片段/分页及执行均未接入；接口、当前测试消费者与指定复核 partial 见[权威设计第 9.28 节](unified-search-commands.md#928-阶段-2j-1同步批次跨提供者类型化结果与完整性汇总)。

统一搜索 2I 的 RoutineOccurrenceQueryProvider 在 Domain 同步消费完整 Session、定义/记录快照、按习惯限定的记录覆盖、带来源的排程证据及显式窗口。记录归并与历史判断仍属于 2C-1；仅开放 History.segments 的既有分段，新增层负责有界枚举、独立每日结果和覆盖反馈。派生 open 不创建 CheckSnapshot 或数据库行；所属标题只用于上下文，读取引用不授予操作权限。当前仅合成领域测试消费，真实仓储、生产 UI、聚合与写入未接线；接口、预算、状态分类和指定复核缺口见[权威设计第 9.27 节](unified-search-commands.md#927-阶段-2i显式日期窗口内的习惯执行情况只读提供者)。

统一搜索 2H-1 的 TrashTombstoneReader 只消费注入快照与范围完整性，按类型化身份隔离重复后调用 SoftDelete 的原同戳规则，输出安全对象及引用式分组。墓碑读取与 ImageAssociationReader / AttachmentBrowseFacts 的 live-only 边界分离；恢复条件没有执行资格或闭包。TodoItem.snapshot 过滤已删子任务，真实适配不得据此声明墓碑完整。当前消费者仅四套合成墓碑测试；接口、保护计数限制与指定复核缺口统一见[权威设计第 9.25 节](unified-search-commands.md#925-阶段-2h-1回收站墓碑删除关联与恢复条件的只读契约)。

统一搜索 2G 的 ClipboardQueryProvider 同步消费注入 ClipboardHistoryRecord；统一 Session 与显式模式原文加只读筛选 Session 互斥。ClipboardTextMatching 复用旧三模式语义并将正则编译移到单次请求；ClipboardHistorySession 的偏好、监听、保存和历史读取不变。结果仅含必要纯文本/元数据、字段依据与负载类别，类型覆盖、历史读取覆盖、未知对象及排序完整性分别表达。显式 clipboard 范围之外不求值；来源沿既有类型化条件，图片自身引用不经过任务附件关联。当前仅合成领域测试消费；契约及指定复核缺口见[权威设计第 9.24 节](unified-search-commands.md#924-阶段-2g显式剪贴板历史的只读搜索提供者)。

工程采用 Xcode 文件系统同步组：往对应文件夹添加 `.swift` 即可纳入编译，无需频繁改 `project.pbxproj`。

统一搜索与指令体系的目标状态、业务入口映射和实施边界见[权威设计](unified-search-commands.md)。阶段 1A 已加入纯领域 `CommandCatalog` 与参数声明，当前只由契约测试消费；产品会话、执行队列与默认范围仍未实现。目录与既有 `BoardSearch`、仓储、窗口之间没有执行接线。 1B-1 新增 `CommandPathParser` 与局部补全结果，直接复用目录/参数，当前也仅由 Domain 测试消费；只输出编辑意图，旧搜索/补全行为不变。独立输入与 UTF-16 边界见权威设计第 9.7 节，内容查询和页面状态留在 1B-2。

## 仓库根目录

```text
AreaChain.xcodeproj
AreaChain/                 应用 target 主源码
AreaChainTests/            测试 target：Domain、Services、Features、Theme 与 E2E
scripts/                   本机 Debug 编译、安装与测试脚本
docs/                      产品、架构、功能与用法文档
skill-routing.md           项目级技能选择与交付闭环
.agents/skills/            可共享的 AreaChain 项目技能
README.md                  项目快速入门
.gitignore
```

> **注意**：禁止将 `build/`、`DerivedData/`、`xcuserdata` 提交到仓库。

## 应用架构分层

```text
AreaChain/
  App/            入口生命周期、主应用 App 定义
  Resources/      Assets.xcassets、Localizable.xcstrings
  Domain/         纯领域层：日期、模型、过滤、解析、连击
  Services/       系统服务：SwiftData、时钟、通知、快照、热键、附件、日历同步
  Features/       界面（按模块）：
    Workspace/    三栏工作台、今日事项、重复事项面板、检查器抽屉、子任务、备注、2×2 四象限
    Dashboard/    总览摘要、趋势、热力图与活动（工作台默认 tab）
    Board/        行铬、命令条、筛选选项与共用清单组合
    Tasks/        今日清单、待办行、键盘导航、过滤条、变更动作、批量栏、待沉底协调器 (PendingCompletionManager)
    MenuBar/      菜单栏浮层、捕获框、可切换底栏与语法搜索
    Calendar/     日历月网格（工作台 tab）
    Quadrant/     四象限（工作台 tab）
    Gantt/        当月单日色块安排（工作台 tab）
    Diary/        手记摘要、工作台卡片、编辑会话与可置顶小窗
    Attachments/  附件浏览（工作台 tab，侧栏名「附件」）
    Search/       跨天搜索命中分组与行；工作台顶栏与菜单栏共用分组，打开路由不同
    Settings/     设置、快捷键、隐私与解锁、数据与备份（页面分离）
    Trash/        回收站（工作台 tab）
  Theme/          令牌（DaybookPalette / DaybookMetrics / DaybookTokens / DaybookColor）、基座（输入壳、按钮、表面、芯片、分节头）与页壳；完整复用边界见 [共享组件与复用目录](component-catalog.md)
```

各 `*StandaloneView` 仍是工作台 tab 的包装。`AppWindows.openWorkspace(tab:)` 负责工作台；新增的单条手记小窗由 Features/Diary 中的 `DiaryWindows` 注册和持有，不声明额外 SwiftUI Window Scene，不复制数据模型。

### 已采用的结构模式

这些是现有代码里为了解决具体问题才留下的做法，不是待推广的框架。

| 模式 | 位置 | 解决的问题 | 不改成更简单写法的原因 |
|---|---|---|---|
| 事务后通知 | `ModelChanges` | 只有保存成功才发布变更 | 页面直接 `save` 会在失败时清掉草稿或虚报成功 |
| 能力环境值 | `workspaceEmbedded` | 工作台有侧栏和页头，外观仍与菜单栏相同 | 用它切换颜色会把两个宿主拆成两套主题 |
| 输入外壳 | `DaybookInputShell` | 外观共用，提交语义按入口区分 | 每个页面自绘边框会让快捷键和高度一起漂 |
| 待沉底 | `PendingCompletionManager` | 勾选后 0.4 秒可反悔；普通测试直调，时序用例关闭跳过 | 立刻写库会让列表在防反悔期间重排 |
| 隐私投影 | `DiaryPrivacy` | 锁定、搜索和总览不带出正文 | 各页面自己判断会漏一种入口 |

单文件超过 500 行时拆文件，不拆行为。总览快照值在 `DashboardModels.swift`，计算留在 `DashboardProjection.swift`。

### 分层设计原则

- **Domain**：禁止 `import SwiftUI` / `import AppKit`（模型可用 SwiftData `@Model`）。纯函数：NLP、连击、四象限排序、日期键。
- **Services**：封装 `UNUserNotificationCenter`、`EventKit`、Carbon HotKey、`SMAppService`、磁盘与持久化。决策走 Domain。
- **Features**：组合 Domain 与 Services，不重复领域过滤规则。
- **Theme**：令牌层是 `DaybookPalette`、`DaybookMetrics`、`DaybookTokens`、`DaybookElevation`、`DaybookColor`；基座层是 `DaybookInputShell`、`DaybookButtonStyle`、`daybookSurface`、`DaybookChip`、`DaybookSectionHeader`、`DaybookDivider`、`DaybookSegmentedBar`。基准是菜单栏浮层任务页：输入高 34、聚焦为墨色 35% 描边、列表是纸底加分隔线、浮层阴影是黑 14% / 模糊 8 / 偏移 2。搜索框高 28、圆角 6。按钮悬停是淡灰圆角底，点击区 regular 28 / compact 22 / inline 18。工作台只在 `WorkspaceLayout` 保留页头、侧栏和内容宽度。新增 UI 先查 [共享组件与复用目录](component-catalog.md)，Feature 复合视图不反向塞入 Theme。`LiveComposerPreviewHeader` 与 `LiveDiaryComposerPreview` 保持为 Theme 中的历史例外，不新增生产消费者、不搬文件；第八阶段 D 只接主外壳，不扩大业务职责。生产搜索只走工作台顶栏和菜单栏底栏，不再保留无入口的独立搜索页。

### 工作台公共顶栏

`MainSplitWorkspaceView` 在主内容区消费 `WorkspaceHeaderContentKey`，由 `WorkspaceHeaderBar` 统一呈现标题、帮助、居中搜索和操作。页面经 `workspaceHeader` 提供动作描述与原回调，不另建导航、筛选或保存状态。宽布局两侧等宽；窄布局搜索独占第二行，右侧按声明顺序收纳到更多菜单。`DaybookPage` 的普通页标题在工作台中由公共顶栏承担，实体/分组标题及非工作台宿主页头保留。重复事项 sheet 显式使用非工作台页头能力。

各任务页经 `workspaceInspectorTargets` 登记当前投影的目标 ID；搜索登记任务、子任务的父任务和可打开附件拥有者。`WorkspaceNavigation` 按当前内容和有效目标决定详情能力，切页或查询改变使旧目标失效。检查器只在当前目标有效时展示；标题草稿复用 `EditDrafts.titles`，备注继续使用 `EditDrafts.notes`，都不写偏好或新建保存事务。

### 开发时的边界与状态核对

目录层次不是编译隔离保证。修改边界时沿入口、调用方及实际状态确认责任，不把理想依赖图当成全部现有代码的证明。`python3 -B scripts/check_workflow.py` 只守住 Domain 禁止显式导入 SwiftUI/AppKit，以及 Features 里未豁免的字面颜色、字号、圆角、阴影和旧主题名；不证明视觉一致，也不检查完整符号依赖或运行语义。

- 无 UI 的解析/过滤/日期规则沿 Domain 复用；持久化与系统 IO 沿 Services 及已有仓储入口，界面沿 Features，公共展示沿 Theme。窗口装配等现有平台协调按实际调用链理解，不借治理任务重排全仓库。
- `ModelChanges` 拥有事务提交和保存后通知；编辑会话拥有草稿与冲突基线，展示筛选不成为第二份持久化真相。变更需说明权威状态、写入者、生命周期、线程/actor 与失效责任。
- 先在所属功能内复用；多个真实消费者共享同一语义时再提取到已有公共层。剪贴板捕获、普通任务输入和搜索的解析/写入差异必须保留，不能为了“统一”合并业务契约。
- 公共接口变化列出真实消费者、旧默认值和错误/副作用；重构先固定不变量，再比较输出、保存/通知次数与失败恢复。文件变短或构建成功不单独证明等价。
- 只为公共边界、数据/安全、重要依赖或难以撤销的取舍在原有文档记录理由、后果与重访条件；普通局部提取不另建决策报告。验证选择与维护责任见 [工程手册](engineering.md)。

### 交互微动效与待沉底状态协调 (`PendingCompletionManager`)

为了实现 macOS 原生品质的物理反馈与防反悔机制，应用采用 UI 待沉底队列与持久化解耦的架构：
1. **视觉完成态与数据隔离**：用户在 UI 点击复选框或按 `Space` 时，`PendingCompletionManager` 立即在 UI 层标记该项为临时完成态，驱动贝塞尔路径生长（`CheckmarkShape` Trim 动画）、删除线平滑横向拉伸（`ModernTaskTitle`）与触控板触感（`NSHapticFeedbackManager`），但暂不向 SwiftData 发起写入。
2. **0.4 秒防反悔窗口**：任务在原列表中原位停留 400ms，期间再次触发会取消后台计时器并立即还原，完全不引发数据库重排与列表闪动。
3. **平滑折叠沉底**：计时到期后，以 `DaybookMotion.collapse` 弹簧曲线折叠列表行并提交真实持久化，任务顺畅流入「已完成」折叠区域。
4. **测试与无障碍自适应**：默认在 XCTest 运行环境或系统开启 `accessibilityReduceMotion` 时直调底层提交，跳过 400ms 等待。`PendingCompletionTimingTests` 把 `skipDelayOverride = false` 后覆盖该时序；不要把默认跳过写成“XCTest 永远测不到驻留”。

### 工作台公共外观

`MainSplitWorkspaceView` 在根部注入 `workspaceEmbedded = true`，只用于页内筛选条、独立窗口最小尺寸、页头最小高度、行数与气泡宿主宽度这类能力/布局分支；颜色、字体与尺寸令牌两宿主一致，来自 `DaybookPalette` / `DaybookMetrics` / `DaybookTokens`，工作台布局常量在 `WorkspaceLayout`。`DaybookPageHeader` 保持标题起点一致并在嵌入时使用页头最小高度；`DaybookInputShell` 是全应用唯一的输入外壳：composer / search 固定单行高（34 / 28），editor 多行不锁高；聚焦为菜单栏捕获框的灰描边，没有蓝色聚焦环。

正文继续使用 13pt 系统字体，页标题使用 16pt 半粗；字号由 `DaybookType` 共用，原生 `DaybookTextField` 同时接受字重，避免详情标题进入编辑后变细。工作台内的可用尺寸由三栏容器决定，页面的独立宿主最小尺寸不再撑大工作台；日历宽窄布局、时间轴滚动及设置原生分组保持独立。设置子分组显式接收当前环境中的偏好对象，使正常窗口和隔离渲染测试使用同一注入路径。

`DaybookTokenTests` 核对令牌数值与对比度，`WorkspaceLayoutTests` 核对原生字段字重与页头几何；`WorkspaceRenderingTests` 用内存模型渲染全部工作台路由、浅深色和最小窗口，包含六周月历、窄窗展开检查器以及手记换行与单次保存。系统材质未必能进入整窗位图缓存，侧栏与检查器另用独立原生宿主截图核验，不能把缓存占位当作应用画面。附件页面在此矩阵中使用空态，避免读取真实图片目录。

界面回归使用独立的 `PRODUCT_BUNDLE_IDENTIFIER=com.areachain.workspace-ui-qa` 和构建目录，以 `INFOPLIST_KEY_LSUIElement=NO` 将测试宿主作为前台应用运行，并逐套串行执行；生产构建保留菜单栏启动方式，不安装或覆盖现用应用。`CaptureOverlayLayoutTests` 为工作台分支显式注入 `workspaceEmbedded`，通过原生事件队列投递点击与按键，并限时等待浮层实际呈现；测试窗口失去焦点会按产品规则关闭浮层，因此焦点敏感测试期间应保持测试窗口激活，截图查看与交互测试分开进行。

## 数据模型设计 (SwiftData 7 张表)

| 模型类名 | 所属领域 | 职责与字段 |
|---|---|---|
| `DailyRoutine` | 重复事项（底层仍是该实体） | `id`, `title`, `sortOrder`, `isEnabled`, `createdDayKey`, `weekdayMask`（及兼容字段 `weekdaysOnly`）, `createdAt`, `remindMinutes`, `deletedAt`, `tagIDs`, `isImportant`, `isUrgent`, `sourceBundleID`, `notes`, `pausedOnDayKey`（停用当天；旧数据可空）；对 `RoutineCheck` cascade。 |
| `RoutineCheck` | 习惯打卡 | `id`, `dayKey`, `isDone`, `isSkipped`，反向关联 `DailyRoutine`。跳过时 `isDone = true && isSkipped = true`。 |
| `TodoItem` | 临时待办 | `id`, `title`, `isDone`, `dayKey`, `createdAt`, `remindMinutes`, `deletedAt`, `tagIDs`, `isImportant`, `isUrgent`, `sourceBundleID`, `calendarEventID`, `notes`；对 `SubtaskItem` cascade（硬删除）。 |
| `SubtaskItem` | 待办子任务 | `id`, `title`, `isDone`, `sortOrder`, `createdAt`, `deletedAt`, `tagIDs`（默认空），一层，归属 `TodoItem`。 |
| `DiaryEntry` | 灵感手记 | `id`, `text`, `dayKey`, `createdAt`, `deletedAt`, `tagIDs`, `isPinned`；新增 `isPrivate`, `encryptedText`, `privacyVaultID`。受保护正文的 `text` 为空，普通 JSON 排除私密记录；旧库新增字段默认未保护，不自动迁移真实内容。 |
| `TagItem` | 平面标签 | `id`, `name`, `sortOrder`, `deletedAt`, `isPrivateDiary`（默认 false）, `colorToken`。没有父标签。隐私规则按稳定 UUID 关联。`colorToken` 是稳定语义色标识，不是平台颜色对象。 |
| `AttachmentItem` | 附件元数据 | `id`, `ownerKind`（todo/routine/diary）, `ownerID`, `filename`, `createdAt`, `deletedAt`, `storageID`, `privacyVaultID`, `retiredStorageID`。图像在 `Application Support/areachain-attachments/<storageID 或 id>`；私密图为密文，普通 JSON 不含二进制，加密备份包含。退休指针保留待清理原文件，清理完成前禁止再次转换覆盖它。 |

### 数据约束与设计考量

1. **CloudKit 边界**：不用 `@Attribute(.unique)`；对外稳定 UUID。设置页只说明本版本不做 iCloud 同步，不再保存无效偏好；打开说明不改变本地库。
2. **日期键 (`DayKey`)**：`yyyy-MM-dd` 字符串，避免时区与「当天零点 Date」错位。
3. **软删除 (`deletedAt`)**：优先标时间进回收站；彻底删除才物理移除。回收站 UI 列习惯、待办、手记、附件与标签。永久清除标签会先解除事项、重复事项、子任务和手记上的关联。手记分类可以软删除和彻底删除，打开手记不会把已删除的分类再建回来；改名、改色和合并仍然拒绝。父项软删时，当时活着的子任务与同类型拥有者附件共用同一戳。附件中心通过 `AttachmentAccess` 校验拥有者类型、存活状态和手记隐私。回收站和附件浏览只 `@Query` 墓碑或活附件，再按 owner key 做 id predicate。工作台搜索的待办/习惯/手记仍整表 `@Query`，否则 `isSingleLive` 看不到重复 UUID；附件只拉未删除行。清空回收站经 `emptyListed` 按 owner matching 收集活附件与墓碑，再删父项，再按附件 id predicate 清文件。重复 UUID 仍判不可用。父项未知或已删时附件不能单独恢复。
4. **软删除与级联**：父待办勾完成时，应用层把未完成子任务标完成。取消父待办完成不撤回这些子任务。父待办进回收站时，当时未删的子任务和附件打上同一 `deletedAt`；恢复时只还原时间戳相同的项。SwiftData `.cascade` 只管硬删除。
5. **快照日期**：JSON 使用带小数秒的 ISO8601，旧备份整秒日期仍能导入。

## 关键领域算法

- **`HabitStreakLogic`**：规范民事日按该习惯的 checks 建只读索引并跳过空档，非规范日期键仍游标按日推进；两种路径输出与旧逐日游标等价。得 `currentStreak` / `bestStreak`。跳过与非排定日桥接；当天未打卡不破击；历史排定日漏打清零；非排定日若仍 `isDone` 则连击 +1。停用区间（`pausedOnDayKey` 起，旧数据则整段停用）当桥接。启用时把暂停日到今天之前的空排定日补成跳过。索引路径内存仍是 O(U) map，另排序 O(U) 个键，不为 D 个空日分配字符串；产品 RSS 未建立。`DashboardProjection.streakPeaks` 先按 `routineId` 分组再调用同一入口。
- **`DashboardProjection`**：今日、近 7 日和 365 日热力图共用一次日统计。`project` 只生成一份闭合日键和打卡合并索引；每个未删除习惯只解析一次创建日，在热力窗口与停用起点之间按民事日递增星期，不对每个日期再扫一遍习惯。只把排定日上的实际完成计入完成数和热力图强度；跳过、非排定日和停用后的标记不计完成；同一天既完成又跳过时跳过优先，与 `HabitStreakLogic` 一致。逾期/即将复用 `AgendaProjection.pending`。视图不自己写公式，也不调用 `context.save()`。活动不进入 SwiftData schema，不读取手记正文，不触发解锁。索引另有 O(D) 日桶和 O(U) 打卡 map；产品 RSS 未建立。
- **`NaturalLanguageParser`**：正则提取时间（含 `@HH:mm`、带时段的「下午3点开会」、无时段时「点」后须空白/标点/`#@!`/「和跟与在去到给把从向」；「点」后直接「问题」不当时刻）、优先级（预览「重要且紧急 / 重要 / 紧急 / 其余」）、`#tag`、多行备注。待办捕获（`parseTaskCapture`）跳过「密码 / 小巧思 / 日记」，把这些 hashtag 留在标题里并收集其余全部普通标签；备注各行中的标签也会关联，原文保留。不提取日期词。没有项目字段。高亮与搜索时刻/优先级正则编译一次，不在每个字符上新建 `NSRegularExpression`。
- **`DayBoardLogic`**：今天 / 昨天 / 即将 / 某月未完成等聚合；昨天未完成含习惯。`DayBoardCheckIndex` 是看板 first-wins 闭合索引；`DayBoardPageProjection` / `DayBoardDayProjection` 在一次调用里切分今日可见行、昨天/即将芯片和当日 open/done。`TasksPage` 与 `DayBoardList` 各自在一次 body 里建这份投影，今日页嵌套日看板时仍会再切分当日行。筛选与空态断言走 `DayBoardPageProjection.project`，不再从 `TasksPage` 另算一份快照。行上连击和附件走该次索引，不要每行再扫 checks 或附件表。`Classification.precedes`：四象限 → 提醒时刻 → `createdAt`。`BoardFocusDay.key` 把 leftover/即将映射到检查日；`BoardFocusDay.checkDay` 让空格跟点选检查日，避免同一习惯既在昨天芯片又在今日清单时总勾昨天。`InspectDayPolicy` 让标签专属清单打开检查器时把检查日钉到今天，切到「今日」也会复位 leftover 日历日；日历 / 昨天芯片仍由 `DayBoardList` 自己 `inspectBoard`。侧栏不再提供常驻页入口。今日列表把一次性事项和当天重复事项按同一 `Classification.precedes` 混排；工作台进度环、侧栏今日角标和菜单栏「今天还剩」共用 `DayBoardLogic.todayProgress`（含当天重复事项，跳过视为已闭合）。待处理和全部事项的日期、排序与子任务命中在 `AgendaProjection` / `ItemsListing`，不在视图里各写一套。重复事项不写虚假 `dayKey`。总览日统计见 `DashboardProjection`。工作台「隐私与解锁」和「数据与备份」已是独立页面，不再占用设置页。搜索筛选交集、菜单栏与今日/手记筛选共享已接到现有规则；浅深色和最小窗口已有 WorkspaceRenderingTests 覆盖；2026-09-26 的隔离 QA 全量测试已通过，证据见工程手册。
- **`ClipboardPayload`**：剪贴板有文字则只取文字、不挂图；仅图片才挂附件。这条规则只用于「剪贴板加今天」，不用于剪贴板历史。
- **`ClipboardHistoryRules`**：历史的忽略、模糊搜索、置顶字母和条数上限。存储在 `Application Support/areachain-clipboard`，不进入 SwiftData，因此不出现在 JSON 导出或加密备份里。剪贴板历史不跟隐私锁走，锁定手记时仍可查看。文件只存路径，粘贴时写回文件 URL。
- **`SoftDelete`**：软删时间戳；父待办进回收站时子任务与附件共用同一戳，恢复只还原戳相同的项。
- **`ExportDates`**：导出带小数秒，导入兼容旧的整秒 ISO8601。
- **`BoardSearch`**：搜索待办/习惯标题和备注、子任务标题及手记正文；多个 `#标签` 匹配真实关联，待办和习惯支持优先级及 `@时间` 条件。传入的 `BoardFilter` 与关键词取交集，日期范围和提醒是否设置会参与匹配；手记只吃标签，「无标签」表示标签列表为空；日期、提醒、优先级或来源一出现就整组退出。子任务按自身标签匹配，并带父任务跳转标识。私密手记仅返回隐藏标题，不把原文复制进展示对象；习惯命中的 `dayKey` 在逾期筛选下是 `AgendaProjection` 的真实逾期检查日，其余范围仍是从今天起的下一个排定日。逾期筛选时 `hits` 先筛分类/提醒，再对入围习惯只调用一次 `AgendaProjection.overdueRoutines`，不为每个习惯重建闭合索引；结构化 `#标签` 在一次调用内共用规范化名字表，手记命中也走这份表。`hits` 可直接吃已解析的 `BoardSearchQuery`；工作台和菜单栏一次 body 先 parse，空查询不建 snapshot，附件文件名复用同一份 `textKeywords`。手记页列表另走 `listedDiaries`：空查询仍返回全部未删除项，与 `hits` 空查询返回 [] 不同；同一次调用共用 `TagNameIndex`。今日清单按看板日套用日期筛选：当天重复事项不算逾期，昨天未完成的重复事项在逾期筛选下仍保留，即将筛选不显示当天重复事项。附件文件名不属于这套结果，只在工作台顶部搜索里按文字关键词额外匹配可浏览附件，不要求文件名包含标签、优先级或时刻。查询不写入偏好。菜单栏与工作台今日、手记页共用同一次运行里的 `BoardFilterSession`，待处理和全部事项仍用各自页面筛选，和今日未提交捕获草稿一起记在 `WorkspaceNavigation` 上。顶部搜索替换内容区时保留它们；真正离开待处理或全部事项后，待处理按逾期/即将规则重开，全部事项筛选回到默认。工作台顶部搜索使用这份会话里的任务筛选，并就地打开检查器。菜单栏搜索打开任务时进入日历。两边都使用命中的 `dayKey`。
- **底栏搜索**：`MenuBarToolbarState` 保留关键词与筛选展示状态；`FooterBar` 互斥显示工具或标签，不使用覆盖工具栏的面板。浮层「任务 / 手记」共用底栏入口和 `BoardFilters`。任务与手记各持有一份 `BoardFilter`，手记只使用标签这一维；`DiaryPage` 通过 `Binding` 直接读写这份筛选，不再另持一个标签 ID。只有工作台保留页内搜索与分类栏。`MenuBarSearchResults` 先应用当前筛选，再使用同一 `BoardSearch` 和隐私投影；菜单栏经 `SearchResultsView` 打开日历检查器。工作台顶栏用 `BoardSearchHitGroups` 就地打开检查器，不复用菜单栏这条路由。关键词只存在本次浮层内，不写入偏好或磁盘。手记搜索结果直接进入同一条记录的小窗。任务、子任务和重复事项进入工作台日历并打开检查器，日期用命中的 `dayKey`。工作台顶部搜索不走这条路由，留在结果页就地打开检查器。
- **语法输入**：`SyntaxInputContext` 区分任务输入、仅标签输入及对应搜索能力。`SyntaxTextField` / `SyntaxTextEditor` 保留原生组合文本、光标及撤销。触发检测正则编译一次。`SyntaxHighlighter` 对同一 `NSTextStorage` 在文本、字体、默认色和外观未变时不整段 `setAttributes`，文本一变仍从当前正文重新抽 token。外观键取自该 storage 所属文本视图或窗口的 `effectiveAppearance`，没有宿主时才回退 `NSApp`。`SyntaxOverlay` 在菜单栏、工作台和检查器根部消费输入锚点，统一候选和只读属性详情，自动上下避让，不参与正文排版；就近消费避免嵌套宿主重复呈现。`CaptureAttributesButton` 在新增输入栏内预留固定宽度，由原文解析「属性 N」，不新增第二套可编辑状态。浮层保留来源语言和配色，Esc 先关闭浮层，不提前触发失焦保存。
- **快捷操作按钮与捕获对齐**：`CommandReturnButton` 共用任务和手记的符号、悬停/Command 高亮及禁用反馈。手记输入与按钮同行，不另设底部保存行；⌘Return 由焦点原生编辑器处理，不再注册一份会抢占搜索或输入法的全局按钮快捷键。保存状态放入固定宽度的前导图标，输入私密标签时图标切换为盾牌反馈，避免挤动输入区。浮层手记输入框与任务捕获框共用 `DaybookInputShell(kind: .composer)`，固定单行 34pt，底层设置 `cell.usesSingleLineMode = !allowsShiftNewline` 保证多行文本粘贴保持单行模式且不撑高布局；长文本横向平滑滚动；右侧独立小窗入口全时段可用（空草稿直接打开空白小窗）。
- **手记行交互与键盘路由**：`DiaryPage` 一次 body 只建一份 `DiaryPageListModel`（`parseQuery`、活条目、标签计数、`listedDiaries`、`DiaryPrivacy.isSensitive`），行和页头/筛选计数复用这一份；空查询不读保险箱，键盘事件会另建一份，不与 body 共享。`DiarySummaryRow` 结合 `DiaryRowPointerRegion` 原生事件监听，单击整行立即选中高亮，双击呼出独立编辑小窗；辅助动作按钮在悬停或选中时淡入显示。`DiaryPage+Keyboard` 监听本窗口按键，打通手记列表的 `↑/↓` 选中切换、`Return/⌘O` 独立窗口打开、`⌘C` 复制（含隐私保护标记）、`Delete/⌘⌫` 移入废纸篓及 `Esc` 清除选中。
- **`ReminderPlanning`**：结合时钟、习惯掩码与待办 `dayKey` 算下一枪通知时刻；`records` 把 catalog 收成可比较的待发送快照。
- **`NotificationScheduler`**：刷新时用刚 persist 的主 context。只拉有提醒的活习惯/待办以及 `dayKey >= today` 的打卡；目录与当前 pending 一致时不取消重排。设置里的测试横幅使用固定标识 `areachain.notification-test`，不进入提醒目录；发出成功后才按原规则刷新提醒排程，未授权或发送失败时不取消已有提醒。`BoardEvents` 在 XCTest 里仍跳过真实排程；定向测试注入 fake，不写系统通知中心。

- **`TagSyntax` / `InputTagResolver`**：共享多标签、引号名称、代码/转义边界及名称归一化。解析和补全没有存储副作用；`ModelChanges.transaction` 将标签创建/恢复与内容保存组成单个本地事务。子任务新增默认空 `tagIDs`，旧库轻量升级和旧 JSON 缺字段都保持兼容；永久删除标签会解除子任务关联。
- **`Catalog`**：标签匹配、附件聚类和标签清单口径的权威入口。`matchingListedRoutines` 列出该标签下全部未删除的重复事项，按当天是否闭合分段，含非今日排定和停用；`openCount` 与未完成段共用这份列表，另加未完成待办和未完成子任务。一次调用里对目标日打卡做 first-wins 闭合集合，待办和子任务只扫一遍；闭合语义与看板 `isRoutineDone` 相同，不是待处理「任一条闭合」。`matchingOpenRoutines` 只保留当天排定且尚未闭合的项，给今日看板口径用，标签清单不要拿它当唯一列表。行上是否允许打卡仍由 `DayBoardLogic.isRoutineDue` 决定。工作台今日在 `TasksPage.showsFilterBar` 下始终挂 `BoardFilterBar` 并提供真实标签选项；菜单栏有 `externalFilter` 时仍用底栏筛选，不画第二条。昨天/即将芯片与今日可见行共用 `Classification.matchesListedRow`，菜单栏带入的日期范围也会作用到芯片。

## 保存、恢复与同步边界

- `ModelChanges` 在保存成功后才通知 UI/系统服务，组合操作延后仓储提交；失败时 `ModelRollback` 回滚并在同一 context 重新 fetch `AreaChainSchema.models` 中的 7 张表，刷新已持有的对象缓存。
- `DiaryEditorSession` 在内存持有正文草稿及编辑基线；显式保存仍走 `SwiftDataDiaryRepository` 与 `ModelChanges.transaction`。外部正文改变时，干净会话跟随更新，脏会话阻止覆盖。卡片通过列表持有的 `DiaryCardDrafts` 复用同一编辑会话，搜索过滤移除卡片不会销毁唯一草稿；锁定前加密封存，解锁后仍需显式显示。失败保留草稿，已删除记录不可被旧窗口保存重建。
- `SnapshotImportState` 在预览及写入前校验重复标识、嵌套子任务、附件归属及最终打卡业务键；不自动清洗现存数据。导入失败只撤销导入，调用前已有编辑先保存。
- `DiaryPrivacy` 统一卡片、搜索、总览及删除提示的安全投影；`AttachmentAccess` 按类型和 UUID 检查拥有者。`DiaryContent` 统一正文加解密，失败不回退明文；锁定时搜索投影没有私密正文。普通 JSON 排除受保护及旧密码遮罩手记和其附件。小窗、卡片和快速输入失焦后遮罩，锁定时不挂载私密编辑器；文件面板回调通过 `PrivacyAccess.withDiary` 重新鉴权并核对记录存活。
- 附件级联按 `ownerKind + ownerID` 执行。永久删除后，`AttachmentCleanup` 按 id predicate 拉待清理行，仅在文件清理成功后移除附件元数据；失败的附件记录留在回收站，下一次操作可以重试。清空回收站先 `emptyListed` 收集活孤儿与墓碑，再删父项再清文件。
- `CalendarSyncCoordinator` 串行合并本地/远端事件；`CalendarSyncEngine` 对比上次本地与远端基线，不盲目先拉后推。基线保存在本机 `areachain-calendar-sync.json`，不改七张表 schema，也不导出到快照。读失败或内存降级时禁写；未知事件保留。冲突把本机和日历的标题、日期、提醒留在结果里供设置页对照，`remote` 为空表示没有可对照事件；不代用户覆盖任一侧，核对一致后重试。跨系统部分提交失败不宣称已同步，旧基线用于幂等恢复。
- `EventKitCalendarClient` 按年分片查询，补查绑定 ID，并在写入前验证事件版本和所属日历。夏令时归一化保存原始本地时刻和实际远端时刻，避免把正常顺延误判为冲突。
- 测试宿主在 `Persistence.makeSession` 的磁盘访问之前切换内存库；端到端系统权限/真实日历验证与单元测试证据分开报告。

## 私密锁、加密与恢复

- `PrivacyVault` 管理单个私密锁、共享会话与认证代次。系统认证和主密码是两条可选解锁路径，不是双重验证。随机 256 位数据密钥只在解锁会话中使用；`VaultKeyAccess` 提供受锁保护的访问，锁定时先通知编辑会话封存草稿，再清除可用密钥。迟到认证必须同时满足代次和当前配置一致，不能重新写回旧配置。
- `VaultCrypto` 使用 CryptoKit AES-GCM，并将记录／附件身份绑定到认证附加数据。主密码路径使用 PBKDF2-HMAC-SHA256（独立 32 字节随机盐，当前 600,000 次）包装同一数据密钥；配置不保存明文密码或数据密钥。
- `SystemVaultKeyStore` 使用本机 Data Protection Keychain 与 `userPresence` 访问控制，系统界面接受 Touch ID 或系统密码，应用不采集系统密码。`PrivacySystemKeyCleanup` 在创建系统条目前持久化待清理 UUID；只有配置提交后才清日志。清理依据成功读取、校验的落盘配置，不删除当前有效条目；删除失败或清日志失败保留可重试状态，不能显示为完全撤销。
- `FileVaultConfigurationStore` 原子保存 `areachain-privacy.json`，以及只含待清理 UUID 的 `.pending-system-keys` 日志，权限为 0600。旧配置 JSON 仍兼容；日志读取失败阻止凭据变更，不把错误当成空列表。已有可用配置仍能正常验证，隐私与解锁页显示待清理状态。
- `DiaryProtection` 将标签规则与记录级保护分开：移除标签不会解除已保存的保护。显式解除保护必须重新验证，且不再命中私密标签。转换需要已验证、未过期的备份；`PrivacyAttachmentBatch` 先写独立文件，再随模型事务切换指针，提交失败删除暂存文件而保留原文件。
- `PrivateBackupFile` 使用独立口令对清单与附件分帧加密，回读核对内容和完整性。读写循环观察任务取消；口令 PBKDF2 每 2048 轮检查取消，取消会丢掉未提交暂存，不替换目标文件。`PrivateBackupService` 恢复时口令只派生一次，再用同一密钥读附件；采用目标私密锁重新加密。备份外仍保留的本地图片若属于将受保护的手记，也纳入同一次暂存与提交。普通 JSON 不能替代加密备份，不能覆盖既有私密记录或解除保护。
- `PrivacyStoreMaintenance` 在加密转换前记录待清理标记，只在冷启动打开 SwiftData 容器前执行 SQLite 历史明文重建，不对仍打开的库做在线 VACUUM。打开失败或 VACUUM 被进度回调中断（任务取消或测试注入）时保留标记，下次冷启动重试；重建成功才删除标记。未完成状态显示在「隐私与解锁」页，可退出以便下次启动完成。自动化用 `sqlite3_progress_handler` 在正在执行的 VACUUM 上返回 `SQLITE_INTERRUPT`，覆盖语句中途中断后的标记保留与重试；取消报 `cancelled` 而不是存储损坏。独立 `sqlite3` 进程的 SIGKILL 覆盖辅助 VACUUM 被杀后合成库仍可读、随后 `finish` 成功；不是杀死日用 AreaChain。不能承诺清除系统快照、外部备份、原始图片或第三方剪贴板历史。
- `PrivateClipboard` 在内存构造正文和全部敏感标记后一次发布，30 秒后仅清理仍属于本次复制的剪贴板内容。闲置锁定默认 5 分钟，可选 1／15 分钟；定时器加入公共运行循环模式，菜单和面板期间仍可检查闲置。锁屏、休眠、退出清除共享解锁状态，应用与窗口失焦仅遮罩。

### 隔离验收与真实启用门禁

隐私自动化测试使用独立测试 Bundle ID、内存或临时目录数据库、合成内容与 `FakeSystemVaultKeys`。`PrivacyMigrationTests` 冻结升级前实体并检验升级、冷启动清理和重开读取；`PrivacyRenderingTests` 检查浅深色布局及锁定后的原生编辑器层级。`PrivacyInteractionTests` 覆盖搜索过滤草稿、选图回调与已删除对象。测试图片可由注入根目录的 `AttachmentStore` 隔离，默认生产目录不变。

```bash
env -u AREACHAIN_SYSTEM_KEYCHAIN_QA -u AREACHAIN_SYSTEM_KEYCHAIN_RUN_ID \
  -u AREACHAIN_SYSTEM_KEYCHAIN_PHASE -u TEST_RUNNER_AREACHAIN_SYSTEM_KEYCHAIN_QA \
  -u TEST_RUNNER_AREACHAIN_SYSTEM_KEYCHAIN_RUN_ID -u TEST_RUNNER_AREACHAIN_SYSTEM_KEYCHAIN_PHASE \
  xcodebuild -quiet -project AreaChain.xcodeproj -scheme AreaChain \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/PrivacyQA \
  AREACHAIN_SIGNING_MODE=local DEVELOPMENT_TEAM= CODE_SIGN_IDENTITY=- \
  CODE_SIGN_ENTITLEMENTS=AreaChain/App/AreaChain.entitlements \
  PRODUCT_BUNDLE_IDENTIFIER=com.areachain.privacy-qa INFOPLIST_KEY_LSUIElement=NO \
  -parallel-testing-enabled NO test
```

该命令显式隔离应用标识、使用不绑定账号的临时签名，并移除可能继承的真实钥匙串授权；不会修改个人签名配置。自动化探测只查询随机不存在的钥匙串条目，禁止提示和写入；它不是实际创建、读取、撤销的证明。覆盖 `CODE_SIGN_ENTITLEMENTS=AreaChain/App/AreaChain.entitlements` 会丢掉钥匙串访问组并得到 `errSecMissingEntitlement (-34018)`，因此这条命令只适合非钥匙串 PrivacyQA。隔离真实钥匙串须走开发签名注入的 `AreaChain.SystemUnlock.entitlements`，见工程手册 PHASE-6 补证。真实启用前应另行确认隔离系统密钥测试，验证 Touch ID／系统密码、取消、重启与重编译／升级后的签名兼容，再确认真实数据迁移。不得为了通过验收去掉钥匙串访问控制或默默改签名／权限。上述命令不安装应用；`scripts/build.sh` 无参数只构建并验签 Debug，安装已分离至需明确确认的 `scripts/install.sh`。

`SystemVaultIntegrationTests` 是默认跳过的真实钥匙串入口，须同时提供 QA Bundle ID、显式授权标志、随机 UUID 和测试阶段。它使用独立服务名，按创建、读取、主动取消、重编译后读取、清理分阶段运行；取消阶段必须收到用户取消，不能把程序超时计为通过。只持久化测试标识、密钥摘要和初始构建版本，不保存明文测试密钥。普通测试不得开启该入口；临时验收配置运行后关闭授权标志。

工程通过 `Config/Signing.xcconfig` 区分 `local` 和 `development` 模式；默认仍为不绑定账号的 ad-hoc 签名，无受限钥匙串访问组。开发签名由未入库的 `Signing.local.xcconfig` 显式开启，应用标识、Team ID 与访问组必须保持一致。最初的 ad-hoc 真机创建曾返回 `errSecMissingEntitlement (-34018)`；受保护钥匙串需要有效签名及合法授权，不能仅根据不存在条目的只读查询判定可写。

构建工具只生成和静态核验产物，不再自动安装、关闭或启动现用应用。Release 核验拒绝调试权限、临时测试权限及测试插件；通过核验仍不等于通过真机运行或 Developer ID 公证发行。正式安装、签名身份切换及真实数据迁移必须单独确认，先在 QA 中验收。配置方法与门禁见[本机构建与系统解锁签名](signing.md)。

原生界面测试共享进程焦点，Scheme 默认串行。`NativeSyntaxUI.prepareFocus` 仅在场景开始时等待实际可见、激活和 key window 状态，等待期间会重复请求激活，最终仍要求 key window，不跳过断言。操作后的焦点断言仍原样执行；测试日志中的前台应用只表明失焦时的状态，不单独证明触发原因。

## 窗口路由与生命周期 (`AppWindows`)

菜单栏入口：`StatusItemController`（`NSStatusItem` + `NSPopover`）。

`MenuBarStatus` 复用今日看板规则区分未安排、未完成与已处理完，并保留准确数量。`MenuBarStatusImage` 使用固定 18×18pt 模板图像，在书本内部镂空小点或勾号表达状态，由系统统一着色。状态项固定 24pt 宽，按钮标题始终为空，不再绘制任何数量文字；所有正数共用同一个小点图标，完整计数只用于悬停提示与无障碍标签。读失败不覆盖上次有效状态。

1. **工作台 (`openWorkspace`)**：`WorkspaceNavigation.revealTab` 后 `PanelWindowController.workspace.show()`。窗口已存在时只前置，**不**重挂 SwiftUI 树（保留草稿、过滤条、芯片展开等 `@State`）。不传 tab 时打开 Dashboard；显式传入的今日、手记、日历等 tab 不会被 Dashboard 覆盖。切到不同 tab 会复位侧栏标签并清掉**批量多选**；当前内容改变会清空旧任务检查目标并收起检查器，目标页面按实际清单重新登记可检查对象。同一 tab 再调 `revealTab` 会清掉标签过滤（浮层 Return 才能回到「今日」页），同一内容可保留当前检查器选中；带明确检查目标时，在普通导航归位后恢复传入的检查日。离开「灵感手记」tab 会清掉手记滚动高亮。浮层底栏窗口按钮走 `openWorkspace`；`revealWorkspace()` 只前置当前 tab，不切回「今日」页。搜索点习惯/待办走带 `inspecting` 和 `dayKey` 的 `openWorkspace`，手记结果走 `DiaryWindows.open(entry:context:)`；显式「在工作台打开」仍走 `openDiary()`。应用菜单「设置」、⌘, 和浮层「设置」都调用 `openSettings()`，进入工作台设置页。
2. **激活策略**：平时 `.accessory`（无 Dock）；工作台、手记小窗或剪贴板小窗打开后升为 `.regular`。`AppWindows.diaryWindowsProvider` 把全部手记窗口纳入存活窗口集合，`clipboardWindowProvider` 纳入剪贴板小窗，防止关工作台时被当成杂散窗口隐藏；还有可见或最小化窗口时不撤去 Dock。剪贴板小窗失焦不关闭，置顶只改窗口层级。
3. **手记小窗**：`DiaryWindows` 按记录标识复用 `DiaryWindowController`，草稿首次保存后也复用原窗。窗口置顶只设置 `.floating` 层级，不改变记录的 `isPinned`，也不重新激活应用；不自动恢复窗口或未保存正文。关闭窗口使用原生保存确认，应用退出还检查独立窗口和 `BoardComposerSession` 中的手记草稿。

### 内容查询领域契约（1B-2A）

`ContentQueryParser` 在 Domain 分离内容查询与现有 `CommandPathResult`；词法、原子条件、矛盾检查、日期、范围与字段适用性分别实现。原始文本和 UTF-16 范围不被规范化覆盖。查询输出不访问 SwiftData、附件拥有者、打卡或剪贴板，也没有执行入口。消费者为原 ContentQuery 领域测试及下述 1B-2B reducer 与测试；旧 BoardSearch 保持原生产语义。`/tasks` 目录 inclusion 的未决状态改为 ordinaryContent，具体组成与停用选择由 `ContentQueryScopeContract` 声明。

日期输出民事日闭区间；习惯定义按区间内存在应执行日且每个定义只返回一次的提供者契约映射，不在本阶段实现命中或去重。`ContentQueryApplicability` 返回真实字段、所属记录/排程投影要求、不适用或需要具体执行日；不得忽略不适用条件扩大结果。语法和日期语义、后续页面绑定要求及 partial 验收见[权威设计第 9.8 节](unified-search-commands.md#98-阶段-1b-2a内容查询语法范围与日期契约)。

### 页面查询状态契约（1B-2B）

`ContentQuerySession` 是宿主独立持有的 Domain 值；`ContentQueryReducer` 接收显式访问/编辑/刷新/回声事件，输出新状态及页面同步/返回意图。页面由调用方传入 `ContentQueryPageContext`，没有反向依赖 WorkspaceNavigation、共享偏好或系统 IO。来源与稳定条件 ID 不从文字推断；自动条件没有伪造 NSRange。页面快照仅供默认映射，完整查询是有效条件的权威来源，`ContentQueryPageProjection` 只读派生可表达字段与扩展条件身份，不能用旧 BoardFilter 覆盖完整 AST。

原 ContentQueryValidation 的可满足性算法增加无位置语义入口，保留原文本诊断 API。新状态当前仅由 Domain 测试消费；操作草稿不在其字段和副作用类型中，滚动由宿主持有，生产页面和提供者未接线。生命周期、映射现状差异、日期/标签适配及实际证据统一见[权威设计第 9.9 节](unified-search-commands.md#99-阶段-1b-2b页面查询上下文与纯状态转移)。

### 操作草稿领域契约（1C-1）

`CommandDraftSession` 由宿主持有当前与保留草稿，`CommandDraftReducer` 只做显式事件的纯转移。`CommandDraft` 用身份/版本守住类型化参数与编辑基线，`CommandDraftTargets` 固定具体对象集合；目标参数只派生生成，正文不进入查询真值。`CommandHostSession` 并列组合查询和操作，查询转移委托原 `ContentQueryReducer`，返回/同步与展示信号不清草稿。当前消费者只有领域测试，没有生产服务或 UI 接线。

保留集合不承担队列和执行；外部值不会自动更新基线，重载/放弃须匹配版本。没有持久化或私密保护实现，后续编辑器接线仍需原隐私机制。完整契约、1C-2/1C-3 边界和 partial 验证只维护在[权威设计第 9.10 节](unified-search-commands.md#910-阶段-1c-1操作草稿固定目标与编辑保护)。

### 待执行计划与纯生命周期（1C-2）

`CommandHostSession` 增加 `CommandPlan` 与可选 `CommandExecutionRun`。显式入计划通过原 DraftSession 的窄入口移交草稿；计划项持有唯一参数，返回编辑就地进行，移除退回 retained。封存按计划修订版将内容移入不可编辑快照，新计划与旧运行没有可分别提交的正文副本。查询 reducer 和展示信号没有修改这些所有者的权限。运行内身份防重用，不建立持久化任务系统。

`CommandPlanValidation` 复用参数/目标检查，新增依赖图与类型化创建输出引用；`CommandPlanSemantics` 只处理已核实赋值白名单。`CommandExecutionRun` 接收纯结果协议，区分 local 提交确定性、external 效果、依赖阻塞和原子组；没有 handler、IO、真实事务、重试或撤销实现。目录全部 unwired；协议 ready 不等于可执行。新接口只由宿主组合和 Domain 测试消费。详细身份/所有权、合并限制、适配边界、1C-3 接续及 partial 证据只维护在[权威设计第 9.11 节](unified-search-commands.md#911-阶段-1c-2待执行计划依赖与纯生命周期协议)。

### 主动转交与运行内所有权（1C-3）

`CommandHandoffCoordinator` 是注入的 MainActor 引用对象，唯一登记参与转交的指令宿主、当前 lease（协调者/宿主/所有权代次/修订）及票据状态；不作为全局单例或窗口管理器。`CommandHostEvent` 委托原 HostSession，原会话值仅作快照/纯计算。未来两个入口必须共用此协调者，不能从旧值副本取得执行所有权；所有延迟事件保留产生时的 lease。

准备与确认不移动内容；提交重新检查双方、在局部候选中更新草稿/计划与引用，单次发布同时完成目标接管和源撤权。任何未释放 execution、未决草稿确认、非空目标操作或旧修订都拒绝。查询冻结来源页语义与日期上下文，目标持有自己的导航返回位置；重新绑定须显式请求。原生句柄需适配确认接续，认证/隐私保护不继承；运行不迁移、没有业务执行或磁盘写入。资格、状态机、身份映射、后续适配门禁与 partial 证据只维护在[权威设计第 9.12 节](unified-search-commands.md#912-阶段-1c-3跨入口主动转交与唯一所有权)。

### 公共启用开关（第三阶段 A）

`DaybookToggleStyle` 位于 Theme，只承载外观，原生 `Toggle` 保留鼠标、状态与辅助操作；显式焦点容器消费空格，按住/重复不写入，释放仅写入一次，禁用或失焦清除临时按下状态。唯一业务状态是消费者的 Binding。几何集中在 `DaybookMetrics.Toggle`，颜色、字号、描边与动效复用 Daybook 令牌。隐藏可见标签须传本地化 `hiddenLabel`，不移除语义名称。新建表单仍是草稿提交，管理行仍经原绑定与仓储即时启停；不在公共层持有保存/导航能力，也不缓存乐观布尔值。入口与回归见[组件目录](component-catalog.md)。

第三阶段 B 在上述样式增加 `.checkbox` 表现：图形置于标签前，几何集中在 `DaybookMetrics.Checkbox`，两种表现共用原生操作与焦点基础。复选框与原生 `.checkbox` 的相邻输入焦点单独对照，不能由滑动开关证据推定等价。隐私标签页只消费样式，业务选择仍属于原表单；初始化、取消与提交权威入口保持 `PrivacySetupSheet`，公共层不接触 vault、模型或保存。

第三阶段 F 的 `DaybookStepper` 在 Theme 维护 Int / Double 步进、可用状态与展示，不保存镜像业务值；操作始终回读消费者 Binding。`DaybookStepping` 只计算候选数值，不引入 Domain 依赖；范围与存储仍由 ClipboardHistoryRules / ClipboardHistorySession 决定。按钮外观和平台重复能力复用现有入口，数值格式与运算分离。窗口接入状态由现有 NSStepper 桥接的 AppKit 生命周期提供；拆离窗口同步阻断公共 adjust，SwiftUI 按钮禁用随后刷新，桥接销毁时清空回调，不依赖 onDisappear 先于重复事件执行。剪贴板历史保存失败时原 setLimit 仍保存新偏好、保留旧历史，这与公共 Binding 拒绝写入是两个不同契约，不新增业务回滚。接口、消费者与隔离测试见[组件目录](component-catalog.md#第三阶段-f公共数值加减与剪贴板)。

### todo 快照查询提供者（统一搜索 2A）

`TodoQueryProvider.read` 位于 Domain，同步消费调用方注入的 TodoSnapshot 和 ContentQuerySession 有效条件，返回只读类型化结果、字段命中依据、覆盖和诊断。请求没有仓储、文件、偏好、系统时间或写入能力；结果身份沿 CommandObjectReference，requestID 只关联本次请求，不授予操作或过期校验能力。未知辅助数据、重复身份与坏日期显式处理；新接口只由领域测试消费。

页面日期分别调用 Classification / AgendaProjection / ItemsListing；真实共同标签关联抽为 ItemsListing.hasTag，原列表继续使用。Classification.matchesDate 增加默认兼容的 Calendar 注入，ItemsListing 传递自身日历。文本沿 BoardSearch 的本地化匹配，不改旧搜索入口；完整契约、测试和指定复核缺口见[权威设计第 9.14 节](unified-search-commands.md#914-阶段-2atodo-只读快照提供者与类型化结果)。

### 子任务快照查询提供者（统一搜索 2B）

`SubtaskQueryProvider.read` 同步消费原 TodoSnapshot 内嵌的 SubtaskSnapshot 与 Session 有效条件，返回独立子身份、父引用及最小值投影。父子身份歧义与数据缺失显式诊断；自身文字/标签/完成/创建时间不能被父字段替代。父安排日和已确认页面约束分别附 parent 字段依据，不先调用 TodoQueryProvider 筛整份父查询。两提供者共用窄值匹配/校验与父级页面规则，公共结果证据类型保留原文件；没有全类型引擎或新的状态所有者。当前仅领域测试消费，真实仓储/UI/聚合/执行未接入；字段对照、条件限制、2A 回归和 partial 复核状态统一维护在[权威设计第 9.15 节](unified-search-commands.md#915-阶段-2b活子任务独立结果的只读快照提供者)。

### 习惯单日读取与历史证据（统一搜索 2C-1）

`ContentQueryOccurrenceDay` 从既有条件读取唯一 on，`ContentQueryDateWindow` 只计算 date 窗口；没有新的可变查询状态或持久化字段。`RoutineCheckReading` 使用 CheckSnapshot 和限定习惯/区间的完整性声明，返回单个业务身份的读取状态、输入下标与重复/冲突诊断。`RoutineScheduleHistory` 只解释调用方注明来源及适用区间的证据，当前定义仅证明明确观察日；`RoutineOccurrenceEvaluation` 组合排程与记录状态，不能把完整无记录单独当 open。它们不接旧 DayBoard/Agenda 索引，不修改七张表、排程写入或历史数据。完整协议和 2C-2 真实来源映射缺口只见[权威设计第 9.17 节](unified-search-commands.md#917-阶段-2c-1习惯执行日历史证据与只读状态契约)。

统一搜索 2C-2 的 `RoutineQueryProvider` 仍为 Domain 注入快照纯函数，唯一实际消费者是四套 RoutineQuery Domain 测试。Session 是全部有效条件的权威来源；历史、记录完整性和来源声明由请求提供，结果只含一次定义投影、见证日/显式执行日及对象诊断，不持有 SwiftData 实体或操作能力。旧页面适配与新状态读取分离，真实历史转换与持久化仍未接线；详见[权威设计第 9.18 节](unified-search-commands.md#918-阶段-2c-2习惯定义只读快照提供者)。

统一搜索 2D 的 `DiaryQueryProvider` 只消费注入 DiarySnapshot、完整查询与标签/敏感判定事实，沿 DiaryPrivacy 和既有文字/标签/日期规则求值。正文不可读采用三态，身份和安全诊断不受布尔短路遮蔽；DiaryQueryPresentation 的隐藏分支没有正文或正文证据字段。contentTypes 仅扩展 diary 合法组成，原生产页与其他提供者不接手记隐私模型。当前消费者只有合成 Domain 测试，没有 DiaryContent/vault、仓储、UI 或执行调用；来源完整性、锁定缓存失效和异步代次均留在后续真实适配，具体契约及 partial 验收见[权威设计第 9.19 节](unified-search-commands.md#919-阶段-2d手记只读快照提供者)。

### 图片关联只读基础（2E-1）

`ImageAssociationReader` 只消费注入图片纯值元数据、三个拥有者快照、保护资料和有范围的完整性声明。拥有者身份、图片身份、关联枚举及手记保护资料分别检查；墓碑参与唯一性，未知不变成没有图片。`AttachmentBrowseFacts` 承载原 `AttachmentAccess.canBrowse` 的纯条件，旧实体入口委托并保留行为；新读取器复用 `DiaryQueryPrivacy`，公开结果不存整份拥有者或敏感图片明细。当前只有合成领域测试消费，没有仓储、文件、查询匹配、生产 UI 或权限接线。类型化所属属性、受保护状态及 2E-2 接入限制以[权威设计第 9.20 节](unified-search-commands.md#920-阶段-2e-1类型化图片拥有者关联完整性与只读可浏览投影)为准。

第三阶段 G 的 ModernCheckbox 仅承载外部完成态、共享图形与一次点击反馈；TaskRow 管理 PendingCompletionManager，行内子任务沿原 UUID 动作链直接提交，四象限保留显式展示值。集中几何、紧凑表现与验收入口见[组件目录](component-catalog.md#第三阶段-g公共任务完成控件与行内子任务)，Theme 不持有模型、保存或反悔计时；ModernTaskTitle 保持原实现。详情子任务后续 H 仅以明确表现接入公共完成控件，原行编辑/保存及模型边界不变，见[组件目录](component-catalog.md#第三阶段-h详情子任务完成控件接入)。

统一搜索 2E-2A 的 `ImageQueryProvider` 在一次同步读取中消费上述关联接口，只匹配公开 ImageBrowseProjection 和共用 ImageOwnerProjection。静态类型分析保留三类拥有者分支，实例匹配明确所属字段；RoutineScheduleHistory 增加公开身份/创建日标量入口，旧快照入口兼容。图片结果覆盖、对象未知与关联保护状态独立，生产数据库、文件访问、UI 与指令执行仍未接线。唯一接口、支持矩阵、验证及 2E-2B 边界见[权威设计第 9.21 节](unified-search-commands.md#921-阶段-2e-2a公开图片元数据的只读搜索提供者)。


统一搜索 2E-2B 在三个记录提供者的读取边界构建 ContentQueryImageRead，原始图片资料只通过 ContentQueryImageInput 注入；拥有者和 Diary metadata 始终来自当前主请求，预计算响应不作为输入。has:image 共用 ImageAssociationReader 的四态与类型化 ownerKey，再适配各自三态/诊断；Todo 增加对象未知及确定性标记。该纯值上下文每次 read 重建，没有持久缓存、授权票据或真实数据访问；无图片条件不读取附件资料。核心接口、保护边界与 partial 证据见[权威设计第 9.22 节](unified-search-commands.md#922-阶段-2e-2b三类记录的图片存在性查询)。

统一搜索 2F 的 TagQueryProvider 只消费 TagQuerySnapshot、完整 Session、显式页面视图选项与可选 TagUsageRecord/覆盖声明，不持有 SwiftData 或关联内容。TagUsage.filteredValues 是原目录与新提供者的纯值共用规则；统计读取、计数口径、生产页和写入责任不变。类型覆盖、使用完整性与排序完成分开表达，默认保持输入顺序，不形成全局评分或查询副本。接口、测试及指定复核缺口只见[权威设计第 9.23 节](unified-search-commands.md#923-阶段-2f活标签只读快照搜索提供者)。

### 公共下拉选择器（第四阶段 A）

DaybookPicker 位于 Theme，仅接收类型化 Binding 与值/本地化标签分离的选项；NSPopUpButton 及原生 NSMenu 维护平台追踪、焦点和辅助操作，公共层没有业务状态镜像。菜单项携带稳定类型化值，协调器只保留当前 Binding；每次提交后立即回读，禁用/拆卸/旧菜单动作受守卫，销毁清空引用。缺失值与空选项采用显式占位，不默认写回第一项。三个剪贴板 setter、会话偏好/历史、未提交输入与关闭行为均保持；接口、呈现和消费者见[组件目录](component-catalog.md#第四阶段-a公共下拉选择器与剪贴板)。

第四阶段 C 为上述公共选项增加显式 verbatim 原文分支，只有 localized 分支调用 L10n；唯一新增消费者 TagManagementPage.mergeSheet 保持本地 mergeTarget UUID 所有权，提交继续由原合并链路执行。公共层不认识 TagItem 或仓储，没有新增保存/校验责任。接口、兼容与内存合成验证见[组件目录](component-catalog.md#第四阶段-c标签合并目标选择器接入)。

### 第四阶段 E 分段控件边界

Theme 的 DaybookSegmentedControl 仅消费类型化 Binding 与稳定选项，不持有业务会话；DaybookSegmentedBar 是兼容 BoardTab 的适配入口，委托同一核心。Namespace 仅隔离视觉动画，不镜像 selection。菜单栏的 tab、草稿、筛选、搜索焦点、键盘监视器和计数仍归原有宿主；FooterBar 的切换关闭筛选行为不变。空值与缺失选项、动效及后续日历适配契约见[组件目录](component-catalog.md#第四阶段-e通用分段与菜单栏)。

### 第五阶段 A 时间输入边界

Theme 的 DaybookTimePicker / DaybookNativeTimePicker 只消费可空分钟 Binding，NSDatePicker 管理短暂字段输入；渲染戳不成为第二份业务值。DaybookTimePresentation 将环境日历复制为固定 UTC 展示日来承载时分，仍调用 RemindMinutes 转换，不改变日期、时区或通知领域规则。有效原生 action 即时传递并回读；挂载、格式/外部更新、禁用和拆卸没有业务写入或焦点请求。两个首批消费者继续管理原默认设置、清除、弹出层和事务，接口/消费者差异及下一阶段边界见[组件目录](component-catalog.md#第五阶段-a公共时间选择器与首批消费者)。

### 公共日期选择与排期暂存（第六阶段 A）

Theme 的 DaybookDatePicker 只读取民事日 Binding 和环境 calendar/locale，瞬时浏览月份与业务选中值分离。DayKey / WeekdayMask 是唯一日期算法来源，不使用时间控件的固定 UTC 展示日；DaybookDateCell 只绘制日期与辅助语义，Theme 不引用 CalendarMonthGrid。DaySchedulePicker 独占本次暂存日键，打开按 initialKey 的原 DayKey 解析及当前日期回退初始化；确认才调用 onPick，取消/关闭不提交。四个宿主沿原保存/关闭链路并显式传递环境；失败不会被公共层转成新关闭/回滚策略。接口与消费者见[组件目录](component-catalog.md#第六阶段-a公共日期选择器与排期弹窗)，验证及未验边界见[工程手册](engineering.md#第六阶段-a公共日期选择器与排期弹窗)。


### 主月网格公共呈现（第六阶段 B）

DaybookDateCell 以 picker / monthGrid 两种语义呈现共享日期基础，DaybookWeekdayHeader 共用环境星期名称与排序。月格附加文字是已计算显示值，投放高亮是外部状态；Theme 不持有任务、统计、解码、拖放事件、仓储或保存。CalendarMonthGrid 保留原 dates/counts/onSelect/onDropTodo 和临时 dropKey，CalendarPage/CalendarGridKeys 继续管理业务选择、导航及键盘。日期选择器原月份/焦点载体仍独立于日格，重选去重只存在其自己的 Binding 路径。几何与身份见[组件目录](component-catalog.md#第六阶段-b主日历月网格接入)，测试证据与指定复核缺口见[工程手册](engineering.md#第六阶段-b主日历月网格接入)。

### 统一搜索原生输入边界（4A-1）

UnifiedSearchInput 只消费宿主发布的 UnifiedSearchBuffer，并把原 lease、版本和编辑/提交意图回交宿主；CommandHandoffCoordinator 仍是 lease 资格的最终验证者。专用 field editor 仅拥有光标、选区、组合文本和本控件撤销，派生候选不能成为业务参数真值。隐私清理使用宿主递增的 privacyRevision 与已清空的显示缓冲，不替代 ContentQueryReadSession 的业务失效，也不涉及敏感操作草稿。当前只有两种合成 QA 宿主，生产搜索仍保留旧实现；接口、证据和缺口统一见[权威设计 §9.45](unified-search-commands.md#945-阶段-4a-1公共原生搜索输入与斜杠补全)。


### 习惯月历公共呈现（第六阶段 C）

HabitCheckMonthView 将打卡状态映射为 DaybookHabitDateState，日号、字体、圆角、状态色与选中反馈统一由 DaybookDateCell.habit 绘制。HabitMonth.mark 的创建日、星期掩码、删除、第一条历史记录及未来日语义均不改变；Feature 保留原全量 Query 与导航调用，不新增规则、缓存或保存。网格与状态计算显式使用局部 Calendar.current 默认值，并传给公共日格环境；今天仍来自 DayClock。公共层不依赖模型、SwiftData、时钟或导航单例。辅助名称使用公共完整日期，业务状态只在 value 中出现，outside 保留原文案；空白不生成相邻月日期。

TaskDetailDrawer 仍从 BoardSelection 读取检查日；点击和重选沿原 inspectTask 同步检查目标与检查器显示状态，外部跨月更新重新派生网格。标题和备注保持原焦点与失焦保存，不把“导航不打卡”扩大成禁止合法编辑保存。公共按钮其他呈现的焦点、键盘和拖放承载未改变；接口与实际基线见[组件目录](component-catalog.md#第六阶段-c习惯月历接入公共日期格)，验收及 partial 缺口见[工程手册](engineering.md#第六阶段-c习惯月历接入公共日期格)。

### 公共星期多选（第六阶段 D）

Theme 的 DaybookWeekdayPicker 只持外部掩码值和更新回调；排序、名称、空草稿与至少一天均复用 WeekdayMask，不产生模型、仓储、保存或长期镜像状态。TaskDetailWeekdayPicker 保留兼容参数与业务标题，三个既有消费者不改调用：新建仅更新草稿；管理行、习惯详情继续原 DayBoardMutations.setWeekdayMask / ModelChanges 保存与失败回滚。拒绝最后一天取消仍回调原值，禁用和生命周期不写回。

几何来自 DaybookMetrics.WeekdayPicker，圆点原形状/按钮承载保持；完整名称、选中状态和独立组名称由公共层表达，显示标题由适配决定。任务行 standingMenus 的系统星期子菜单和只读 DaybookWeekdayHeader 保留各自形态，不属于重复圆点实现。接口及验证入口见[组件目录](component-catalog.md#第六阶段-d公共星期多选与三个消费者)。本轮不修改旧掩码存储、启停、打卡、检查日、提醒、标签或通知投影。

### 统一搜索原生结果边界（4A-2）

Features 的 UnifiedSearchController 组合原输入和 ReadSession；UnifiedSearchResults 的原生边界只呈现重新通过门禁的 publication，失效通知同步移除 hosting 子树、公开展开 storage 和本输入的原生缓冲。ContentQueryDisplayUpdates 只广播修订，不拥有资格；ContentQueryExpansionIndex 只保留同批安全身份的位置，不存正文。Domain 的排序、分组、分页与选择保持原实现。标准/紧凑的隔离宿主消费同一结果组件，生产入口、真实打开及操作预览未接线，证据与保留缺口统一见[权威设计 §9.46](unified-search-commands.md#946-阶段-4a-2公共原生搜索结果列表与输入导航)。

### 统一搜索普通操作预览（4A-3A）

UnifiedSearchController 的操作扩展直接读写原协调者 operations，不保存第二份可提交参数。UnifiedSearchBuffer 带可选 CommandDraftStamp，普通字段拼写缓冲只保存原文与产生版本；原生事件必须核验原 lease、草稿和缓冲版本。DaybookPicker 的可选 eventVersion 隔离旧菜单身份，原消费者默认兼容。面板复用 ReadSession.validateDisplayHost 的既有宿主展示门禁，失焦/锁定同步清原生编辑器并卸载树；普通草稿留在协调者，这不是敏感草稿封存。实际链路、支持类型、测试与指定复核缺口见[权威设计 §9.47](unified-search-commands.md#947-阶段-4a-3a普通参数编辑与操作即时预览)。

### 统一搜索对象选择边界（4A-3B1）

对象选择只在原 Controller 暂存 Browse 交互；目标身份继续是 CommandObjectReference。操作目标唯一写入 draft.targets，普通 object / objects 参数写入 draft.arguments。候选与目标预览均由 ReadSession 当前发布核验，固定集合不随分页或查询扩张。选择接受带原 lease、草稿 stamp、位置和候选版本，原子草稿事件成功后重新读取展示；没有沿旧许可补发新事件。目标变更缺少新证据时清旧 baseline，arguments 保留。转交后 ownershipRevision 接入既有只读失效观察，撤去旧宿主候选与预览。普通合成草稿仍保留；这不是敏感草稿封存、加密或零化。接口与证据见[权威设计 §9.48](unified-search-commands.md#948-阶段-4a-3b1对象参数选择与操作固定目标的原生接线)。

### 第八阶段 B 公共滚动装配

Theme 的 `daybookScrollAssembly` 只组合指示器策略、Configurator 与原羽化 modifier，不建立滚动容器或状态所有者。两个兼容重载的默认值与实际选择不变，泛型策略变换维持原具体链和 modifier 顺序；保留系统策略时直接返回传入视图。浮层、AppKit knob、观察器、定位与拆卸机制原样保留。AppKit 文本与统一搜索直连仍是不同承载入口；接口矩阵、消费者与历史定位缺口见[组件目录](component-catalog.md#第八阶段-bdaybookscroll-公共装配)。


### 命令草稿隔离保护边界（4A-3C2A）

命令正文采用独立 CommandDraftPayload / SealedCommandDraft v1，复用既有 VaultKeyAccess。CommandDraftContentSession 只拥有内存密文资源和可撤销的同步明文借用；宿主所有权仍唯一归 CommandHandoffCoordinator，成功封存后的一次性 CommandDraftCheckpoint 才可提交引用。Domain 不执行加密/认证，普通快照没有自动解封能力；原 DiaryDraftText 与磁盘格式不变。服务只由合成测试装配，敏感原生编辑、IME/撤销、执行及完整敏感转交未接线。契约、实际消费者、回退和验证缺口见[权威 §9.51](unified-search-commands.md#951-阶段-4a-3c2a命令保护载荷与显式恢复)，不将单测/构建解释为生产安全入口验收。

### 命令原生暂持边界（4A-3C2B）

ContentSession 的同步借用仍禁止调用者任意缓存。唯一原生暂持由 CommandDraftNativeOwner 登记，专用 CommandProtectedTextView 只收当前字段/选区，基线及其他参数留原服务。原生成功接受前必须先有同版本密文；连续编辑只在同次已核验提交后签发新 access，旧 access 过期。独立 UndoManager 只留密文，撤销旧正文也重新保护；撤权同步清本控件。系统 IME 与外部 mutable textStorage 不能由该探针提供完整保全，生产入口关闭；具体状态关系、反例、active/planItem 与验证限制见[权威 §9.52](unified-search-commands.md#952-阶段-4a-3c2b原生接受与锁定交错的隔离可行性)。


### 普通偏好权威入口（3A-1A）

AppPreferences 保留唯一四值及原 UserDefaults 键；兼容可写属性和后续适配共用 readLocalSetting / applyLocalSetting。逐字段修订只计本入口调用，raw 是注入存储当前搜索域可见原值，不能检测外部全部 ABA 或承诺物理落盘。普通事件带实例/存储句柄身份，不含正文或其他设置；PreferenceObservation 按身份/字段路由展示，CalendarSync 仅旧事件，手记普通事件不刷新正文。完整结果、旧页同值兼容、失败边界和验证状态只维护在[权威 §9.54](unified-search-commands.md#954-阶段-3a-1a普通偏好共享读写与事件拆分)。


### 普通偏好文件权威（3A-3B1）

Services 的 LocalPreferenceFileStore 只在显式临时 root 内保存独立完整记录，不依赖 SwiftData。current 为唯一权威，pending 只绑定基/目标身份与摘要；协作锁覆盖锁内读取、比较、整体替换和完整核实。后端不发布内存、事件或展示副作用，AppPreferences 与旧单项链不变。读取/未知关闭写入口，显式核验不重放、不恢复 CommandPlan。接口、原子性及耐久限制、恢复与未接线边界统一见[权威 §9.58](unified-search-commands.md#958-阶段-3a-3b1版本化聚合文件后端与提交恢复)。


### 普通偏好隔离迁移（3A-3B2A）

Services 的 LocalPreferenceLegacySource 只接受受控测试域的显式逐键读取证据；来源判定与旧应用宽松装载分离。LocalPreferenceMigrationEvidence 不是第二份可编辑状态；FileStore 沿原锁/一次提交/恢复路径建立带 migrationID 的完整 current，重开先核验新来源，不重新读取旧键或重放命令。唯一格式、恢复判定、保证限制及 3B2B 输入见[§9.59](unified-search-commands.md#959-阶段-3a-3b2a旧四键隔离迁移重开与恢复判定)。AppPreferences 生产后端及 SwiftData schema 保持不变。


### 普通偏好整份发布（3A-3B2B）

AppPreferences 显式文件模式将四项及持久修订保存在唯一 LocalPreferencePublishedState.committed(record) 中；候选只在文件后端局部构造。提交事实先登记，再一次赋值发布，之后独立调用外观与普通组事件。后端健康状态与展示事实不是另一份可编辑偏好。共享实例与原 defaults 初始化仍使用旧后端，文件模式不建立旧四键存储依赖；其他偏好仍走注入 defaults。

启动 ready 必须与注入 store 的身份、格式和当前权威状态重新核对；不可靠状态保留最后完整显示或只读默认，写入关闭。显式 verifyAndReload 复用原核验/清理，不提交或迁移；同源已知修订倒退也拒绝连续发布。普通消费者只刷新当前 chrome，旧单项指令接口拒绝新后端证据；外部修改发现范围、提交/展示/恢复的区别及 3B3 前置见[权威 §9.60](unified-search-commands.md#960-阶段-3a-3b2bapppreferences-聚合后端整份发布与展示事件)。

### 普通偏好组执行边界（3A-3B3A）

FileLocalSettingCommandAdapter 显式选择文件后端，与旧单项适配互斥。原 Plan 保有唯一参数；签发登记只保存不可编辑的完整证据。Coordinator 一次安装所有成员基线，按 groupID、有序 member stamps、run/attempt 占用；AppPreferences 在完整发布前经 recordCommit / recordRecovery 将可信提交事实记入原运行，再复用原展示 ledger。Run 只为已核实的四类普通偏好支持独立展示阶段，通用 atomicGroup 外部效果限制不变。冲突/确定未提交才能整组返回；unknown 只接受原目标精确身份核验，永不重放。接口与实际范围见[权威 §9.61](unified-search-commands.md#961-阶段-3a-3b3a普通设置组准备共同执行与回执)，多项 UI 与生产装配仍关闭。


### 普通设置组原生装配（3A-3B3B）

UnifiedSearchController 的单一 UnifiedSearchSettingBackend 枚举负责显式选择旧单项或文件适配。原 Plan 保有唯一参数，PlanLinks 发送原 atomicGroup 事件，FileLocalSettingCommandAdapter 准备整组证据并绑定准备后的 plan stamp；UI 只消费 readiness 和类型化本地/核验/展示回执。失焦 invalidated 推进显示缓冲版本，不更换 lease。隔离原生接线扩展了上节的测试消费者，生产默认仍旧后端；实现、验收与历史缺口只维护在[权威 §9.62](unified-search-commands.md#962-阶段-3a-3b3b普通设置共同提交的原生接线)。
