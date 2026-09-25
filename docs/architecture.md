# 架构与目录

工程采用 Xcode 文件系统同步组：往对应文件夹添加 `.swift` 即可纳入编译，无需频繁改 `project.pbxproj`。

## 仓库根目录

```text
AreaChain.xcodeproj
AreaChain/                 应用 target 主源码
AreaChainTests/            测试 target；以 Domain / Services 为主，另有 Theme 与 E2E
scripts/                   本机 Debug 编译、安装与测试脚本
docs/                      产品、架构、功能与用法文档
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
    Tasks/        今日清单、待办行、键盘导航、过滤条、变更动作、批量栏、待沉底协调器 (PendingCompletionManager)
    MenuBar/      菜单栏浮层、捕获框、可切换底栏与语法搜索
    Calendar/     日历月网格（工作台 tab）
    Quadrant/     四象限（工作台 tab）
    Gantt/        当月单日色块安排（工作台 tab）
    Diary/        手记摘要、工作台卡片、编辑会话与可置顶小窗
    Attachments/  附件浏览（工作台 tab，侧栏名「附件」）
    Search/       跨天搜索与工作台/浮层共用的结果列表
    Settings/     设置、隐私与解锁、数据与备份（三者页面分离）
    Trash/        回收站（工作台 tab）
  Theme/          令牌（DaybookPalette / DaybookMetrics / DaybookTokens / DaybookColor）、基座（输入壳、按钮、表面、芯片、分节头）与页壳
```

各 `*StandaloneView` 仍是工作台 tab 的包装。`AppWindows.openWorkspace(tab:)` 负责工作台；新增的单条手记小窗由 Features/Diary 中的 `DiaryWindows` 注册和持有，不声明额外 SwiftUI Window Scene，不复制数据模型。

### 分层设计原则

- **Domain**：禁止 `import SwiftUI` / `import AppKit`（模型可用 SwiftData `@Model`）。纯函数：NLP、连击、四象限排序、日期键。
- **Services**：封装 `UNUserNotificationCenter`、`EventKit`、Carbon HotKey、`SMAppService`、磁盘与持久化。决策走 Domain。
- **Features**：组合 Domain 与 Services，不重复领域过滤规则。
- **Theme**：令牌层是 `DaybookPalette`、`DaybookMetrics`、`DaybookTokens`、`DaybookElevation`、`DaybookColor`；基座层是 `DaybookInputShell`、`DaybookButtonStyle`、`daybookSurface`、`DaybookChip`、`DaybookSectionHeader`、`DaybookDivider`、`DaybookSegmentedBar`。基准是菜单栏浮层任务页：输入高 34、聚焦为墨色 35% 描边、列表是纸底加分隔线、浮层阴影是黑 14% / 模糊 8 / 偏移 2。工作台只在 `WorkspaceLayout` 保留页头、侧栏和内容宽度。

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
4. **测试与无障碍自适应**：在 XCTest 运行环境下或系统开启 `accessibilityReduceMotion` 时，协调器自动直调底层提交，跳过任何时间等待，既保证了单元测试的确定性与执行速度，又完全遵守 HIG 无障碍规范。

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

1. **CloudKit 边界**：不用 `@Attribute(.unique)`；对外稳定 UUID。iCloud 开关只写入 `wantsICloudSync`，此版本尚未接入 CloudKit，打开不改变本地库。
2. **日期键 (`DayKey`)**：`yyyy-MM-dd` 字符串，避免时区与「当天零点 Date」错位。
3. **软删除 (`deletedAt`)**：优先标时间进回收站；彻底删除才物理移除。回收站 UI 列习惯、待办、手记、附件与标签。永久清除标签会先解除事项、重复事项、子任务和手记上的关联。手记预置标签不能删除。父项软删时，当时活着的子任务与同类型拥有者附件共用同一戳。附件中心通过 `AttachmentAccess` 校验拥有者类型、存活状态和手记隐私；父项未知或已删时附件不能单独恢复。
4. **软删除与级联**：父待办勾完成时，应用层把未完成子任务标完成。父待办进回收站时，当时未删的子任务和附件打上同一 `deletedAt`；恢复时只还原时间戳相同的项。SwiftData `.cascade` 只管硬删除。
5. **快照日期**：JSON 使用带小数秒的 ISO8601，旧备份整秒日期仍能导入。

## 关键领域算法

- **`HabitStreakLogic`**：游标按日推进，得 `currentStreak` / `bestStreak`。跳过与非排定日桥接；当天未打卡不破击；历史排定日漏打清零；非排定日若仍 `isDone` 则连击 +1。停用区间（`pausedOnDayKey` 起，旧数据则整段停用）当桥接。启用时把暂停日到今天之前的空排定日补成跳过。
- **`NaturalLanguageParser`**：正则提取时间（含 `@HH:mm`、带时段的「下午3点开会」、无时段时「点」后须空白/标点/`#@!`/「和跟与在去到给把从向」；「点」后直接「问题」不当时刻）、优先级（预览「重要且紧急 / 重要 / 紧急 / 其余」）、`#tag`、多行备注。待办捕获（`parseTaskCapture`）跳过「密码 / 小巧思 / 日记」，把这些 hashtag 留在标题里并收集其余全部普通标签；备注各行中的标签也会关联，原文保留。不提取日期词。没有项目字段。
- **`DayBoardLogic`**：今天 / 昨天 / 即将 / 某月未完成等聚合；昨天未完成含习惯。`Classification.precedes`：四象限 → 提醒时刻 → `createdAt`。`BoardFocusDay.key` 把 leftover/即将映射到检查日；`BoardFocusDay.checkDay` 让空格跟点选检查日，避免同一习惯既在昨天芯片又在今日清单时总勾昨天。`InspectDayPolicy` 让标签专属清单打开检查器时把检查日钉到今天，切到「今日」也会复位 leftover 日历日；日历 / 昨天芯片仍由 `DayBoardList` 自己 `inspectBoard`。侧栏不再提供常驻页入口。今日列表把一次性事项和当天重复事项按同一 `Classification.precedes` 混排；菜单栏角标和「今天还剩」共用 `DayBoardLogic.todayProgress`（含当天重复事项）。工作台进度环只用 `todayOneOffProgress`，不把重复事项算进一次性事项进度。待处理和全部事项的日期、排序与子任务命中在 `AgendaProjection` / `ItemsListing`，不在视图里各写一套。重复事项不写虚假 `dayKey`。`DashboardProjection` 的今日、近 7 日和热力图共用同一套日统计：只把排定日上的实际完成计入完成数和热力图强度。跳过、非排定日和停用后的标记不计完成；同一天既完成又跳过时跳过优先，与 `HabitStreakLogic` 一致。菜单栏角标仍用 `DayBoardLogic.todayProgress`，跳过在今日页视为已闭合。视图不自己写公式，也不调用 `context.save()`。活动不进入 SwiftData schema，不读取手记正文，不触发解锁。工作台「隐私与解锁」和「数据与备份」已是独立页面，不再占用设置页。阶段七已把搜索筛选交集、菜单栏与今日/手记筛选共享接到现有规则；浅深色、最小窗口和原生走查尚未做，阶段八未开始。
- **`ClipboardPayload`**：剪贴板有文字则只取文字、不挂图；仅图片才挂附件。
- **`SoftDelete`**：软删时间戳；父待办进回收站时子任务与附件共用同一戳，恢复只还原戳相同的项。
- **`ExportDates`**：导出带小数秒，导入兼容旧的整秒 ISO8601。
- **`BoardSearch`**：搜索待办/习惯标题和备注、子任务标题及手记正文；多个 `#标签` 匹配真实关联，待办和习惯支持优先级及 `@时间` 条件。传入的 `BoardFilter` 与关键词取交集，日期范围和提醒是否设置会参与匹配；手记只吃标签，日期、提醒、优先级或来源一出现就整组退出。子任务按自身标签匹配，并带父任务跳转标识。私密手记仅返回隐藏标题，不把原文复制进展示对象；习惯命中的 `dayKey` 是从今天起下一个排定日。附件文件名不属于这套结果，只在工作台顶部搜索里额外匹配可浏览附件。查询不写入偏好。菜单栏与工作台今日、手记页共用同一次运行里的 `BoardFilterSession`，待处理和全部事项仍用各自页面筛选。工作台顶部搜索和专门搜索页使用这份会话里的任务筛选。菜单栏和专门搜索页打开任务时进入日历；工作台顶部搜索就地打开检查器，两边都使用命中的 `dayKey`。
- **底栏搜索**：`MenuBarToolbarState` 保留关键词与筛选展示状态；`FooterBar` 互斥显示工具或标签，不使用覆盖工具栏的面板。浮层「任务 / 手记」共用底栏入口和 `BoardFilters`。任务与手记各持有一份 `BoardFilter`，手记只使用标签这一维；`DiaryPage` 通过 `Binding` 直接读写这份筛选，不再另持一个标签 ID。只有工作台保留页内搜索与分类栏。`MenuBarSearchResults` 先应用当前筛选，再使用同一 `BoardSearch` 和隐私投影；`SearchResultsView` 共用分组与跳转。关键词只存在本次浮层内，不写入偏好或磁盘。 手记搜索结果直接进入同一条记录的小窗，任务路由保持不变。
- **语法输入**：`SyntaxInputContext` 区分任务输入、仅标签输入及对应搜索能力。`SyntaxTextField` / `SyntaxTextEditor` 保留原生组合文本、光标及撤销。`SyntaxOverlay` 在菜单栏、工作台和检查器根部消费输入锚点，统一候选和只读属性详情，自动上下避让，不参与正文排版；就近消费避免嵌套宿主重复呈现。`CaptureAttributesButton` 在新增输入栏内预留固定宽度，由原文解析「属性 N」，不新增第二套可编辑状态。浮层保留来源语言和配色，Esc 先关闭浮层，不提前触发失焦保存。
- **快捷操作按钮与捕获对齐**：`CommandReturnButton` 共用任务和手记的符号、悬停/Command 高亮及禁用反馈。手记输入与按钮同行，不另设底部保存行；⌘Return 由焦点原生编辑器处理，不再注册一份会抢占搜索或输入法的全局按钮快捷键。保存状态放入固定宽度的前导图标，输入私密标签时图标切换为盾牌反馈，避免挤动输入区。浮层手记输入框与任务捕获框共用 `DaybookInputShell(kind: .composer)`，固定单行 34pt，底层设置 `cell.usesSingleLineMode = !allowsShiftNewline` 保证多行文本粘贴保持单行模式且不撑高布局；长文本横向平滑滚动；右侧独立小窗入口全时段可用（空草稿直接打开空白小窗）。
- **手记行交互与键盘路由**：`DiarySummaryRow` 结合 `DiaryRowPointerRegion` 原生事件监听，单击整行立即选中高亮，双击呼出独立编辑小窗；辅助动作按钮在悬停或选中时淡入显示。`DiaryPage+Keyboard` 监听本窗口按键，打通手记列表的 `↑/↓` 选中切换、`Return/⌘O` 独立窗口打开、`⌘C` 复制（含隐私保护标记）、`Delete/⌘⌫` 移入废纸篓及 `Esc` 清除选中。
- **`ReminderPlanning`**：结合时钟、习惯掩码与待办 `dayKey` 算下一枪通知时刻。
- **`NotificationScheduler`**：刷新时用 `Persistence.session.container.mainContext`，能读到刚 persist 的改动。

- **`TagSyntax` / `InputTagResolver`**：共享多标签、引号名称、代码/转义边界及名称归一化。解析和补全没有存储副作用；`ModelChanges.transaction` 将标签创建/恢复与内容保存组成单个本地事务。子任务新增默认空 `tagIDs`，旧库轻量升级和旧 JSON 缺字段都保持兼容；永久删除标签会解除子任务关联。

## 保存、恢复与同步边界

- `ModelChanges` 在保存成功后才通知 UI/系统服务，组合操作延后仓储提交；失败时 `ModelRollback` 回滚并在同一 context 重新 fetch 八类模型，刷新已持有的对象缓存。
- `DiaryEditorSession` 在内存持有正文草稿及编辑基线；显式保存仍走 `SwiftDataDiaryRepository` 与 `ModelChanges.transaction`。外部正文改变时，干净会话跟随更新，脏会话阻止覆盖。卡片通过列表持有的 `DiaryCardDrafts` 复用同一编辑会话，搜索过滤移除卡片不会销毁唯一草稿；锁定前加密封存，解锁后仍需显式显示。失败保留草稿，已删除记录不可被旧窗口保存重建。
- `SnapshotImportState` 在预览及写入前校验重复标识、嵌套子任务、附件归属及最终打卡业务键；不自动清洗现存数据。导入失败只撤销导入，调用前已有编辑先保存。
- `DiaryPrivacy` 统一卡片、搜索及删除提示的安全投影；`AttachmentAccess` 按类型和 UUID 检查拥有者。`DiaryContent` 统一正文加解密，失败不回退明文；锁定时搜索投影没有私密正文。普通 JSON 排除受保护及旧密码遮罩手记和其附件。小窗、卡片和快速输入失焦后遮罩，锁定时不挂载私密编辑器；文件面板回调通过 `PrivacyAccess.withDiary` 重新鉴权并核对记录存活。
- 附件级联按 `ownerKind + ownerID` 执行。永久删除后，`AttachmentCleanup` 仅在文件清理成功后移除附件元数据；失败的附件记录留在回收站，下一次操作可以重试。
- `CalendarSyncCoordinator` 串行合并本地/远端事件；`CalendarSyncEngine` 对比上次本地与远端基线，不盲目先拉后推。基线保存在本机 `areachain-calendar-sync.json`，不改七张表 schema，也不导出到快照。读失败或内存降级时禁写；未知事件保留，冲突需核对一致后重试。跨系统部分提交失败不宣称已同步，旧基线用于幂等恢复。
- `EventKitCalendarClient` 按年分片查询，补查绑定 ID，并在写入前验证事件版本和所属日历。夏令时归一化保存原始本地时刻和实际远端时刻，避免把正常顺延误判为冲突。
- 测试宿主在 `Persistence.makeSession` 的磁盘访问之前切换内存库；端到端系统权限/真实日历验证与单元测试证据分开报告。

## 私密锁、加密与恢复

- `PrivacyVault` 管理单个私密锁、共享会话与认证代次。系统认证和主密码是两条可选解锁路径，不是双重验证。随机 256 位数据密钥只在解锁会话中使用；`VaultKeyAccess` 提供受锁保护的访问，锁定时先通知编辑会话封存草稿，再清除可用密钥。迟到认证必须同时满足代次和当前配置一致，不能重新写回旧配置。
- `VaultCrypto` 使用 CryptoKit AES-GCM，并将记录／附件身份绑定到认证附加数据。主密码路径使用 PBKDF2-HMAC-SHA256（独立 32 字节随机盐，当前 600,000 次）包装同一数据密钥；配置不保存明文密码或数据密钥。
- `SystemVaultKeyStore` 使用本机 Data Protection Keychain 与 `userPresence` 访问控制，系统界面接受 Touch ID 或系统密码，应用不采集系统密码。`PrivacySystemKeyCleanup` 在创建系统条目前持久化待清理 UUID；只有配置提交后才清日志。清理依据成功读取、校验的落盘配置，不删除当前有效条目；删除失败或清日志失败保留可重试状态，不能显示为完全撤销。
- `FileVaultConfigurationStore` 原子保存 `areachain-privacy.json`，以及只含待清理 UUID 的 `.pending-system-keys` 日志，权限为 0600。旧配置 JSON 仍兼容；日志读取失败阻止凭据变更，不把错误当成空列表。已有可用配置仍能正常验证，隐私与解锁页显示待清理状态。
- `DiaryProtection` 将标签规则与记录级保护分开：移除标签不会解除已保存的保护。显式解除保护必须重新验证，且不再命中私密标签。转换需要已验证、未过期的备份；`PrivacyAttachmentBatch` 先写独立文件，再随模型事务切换指针，提交失败删除暂存文件而保留原文件。
- `PrivateBackupFile` 使用独立口令对清单与附件分帧加密，回读核对内容和完整性。`PrivateBackupService` 恢复前完整验证，采用目标私密锁重新加密；备份外仍保留的本地图片若属于将受保护的手记，也纳入同一次暂存与提交。普通 JSON 不能替代加密备份，不能覆盖既有私密记录或解除保护。
- `PrivacyStoreMaintenance` 在加密转换前记录待清理标记，在冷启动打开 SwiftData 容器前执行 SQLite 历史明文重建。重建成功才删除标记；未完成状态显示在「隐私与解锁」页，不在设置页。不能承诺清除系统快照、外部备份、原始图片或第三方剪贴板历史。
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

该命令显式隔离应用标识、使用不绑定账号的临时签名，并移除可能继承的真实钥匙串授权；不会修改个人签名配置。自动化探测只查询随机不存在的钥匙串条目，禁止提示和写入；它不是实际创建、读取、撤销的证明。真实启用前应另行确认隔离系统密钥测试，验证 Touch ID／系统密码、取消、重启与重编译／升级后的签名兼容，再确认真实数据迁移。不得为了通过验收去掉钥匙串访问控制或默默改签名／权限。上述命令不安装应用；`scripts/build.sh` 无参数只构建并验签 Debug，安装已分离至需明确确认的 `scripts/install.sh`。

`SystemVaultIntegrationTests` 是默认跳过的真实钥匙串入口，须同时提供 QA Bundle ID、显式授权标志、随机 UUID 和测试阶段。它使用独立服务名，按创建、读取、主动取消、重编译后读取、清理分阶段运行；取消阶段必须收到用户取消，不能把程序超时计为通过。只持久化测试标识、密钥摘要和初始构建版本，不保存明文测试密钥。普通测试不得开启该入口；临时验收配置运行后关闭授权标志。

工程通过 `Config/Signing.xcconfig` 区分 `local` 和 `development` 模式；默认仍为不绑定账号的 ad-hoc 签名，无受限钥匙串访问组。开发签名由未入库的 `Signing.local.xcconfig` 显式开启，应用标识、Team ID 与访问组必须保持一致。最初的 ad-hoc 真机创建曾返回 `errSecMissingEntitlement (-34018)`；受保护钥匙串需要有效签名及合法授权，不能仅根据不存在条目的只读查询判定可写。

构建工具只生成和静态核验产物，不再自动安装、关闭或启动现用应用。Release 核验拒绝调试权限、临时测试权限及测试插件；通过核验仍不等于通过真机运行或 Developer ID 公证发行。正式安装、签名身份切换及真实数据迁移必须单独确认，先在 QA 中验收。配置方法与门禁见[本机构建与系统解锁签名](signing.md)。

原生界面测试共享进程焦点，Scheme 默认串行。`NativeSyntaxUI.prepareFocus` 仅在场景开始时等待实际可见、激活和 key window 状态，操作后的焦点断言仍原样执行；测试日志中的前台应用只表明失焦时的状态，不单独证明触发原因。

## 窗口路由与生命周期 (`AppWindows`)

菜单栏入口：`StatusItemController`（`NSStatusItem` + `NSPopover`）。

`MenuBarStatus` 复用今日看板规则区分未安排、未完成与已处理完，并保留准确数量。`MenuBarStatusImage` 使用固定 18×18pt 模板图像，在书本内部镂空小点或勾号表达状态，由系统统一着色。状态项固定 24pt 宽，按钮标题始终为空，不再绘制任何数量文字；所有正数共用同一个小点图标，完整计数只用于悬停提示与无障碍标签。读失败不覆盖上次有效状态。

1. **工作台 (`openWorkspace`)**：`WorkspaceNavigation.revealTab` 后 `PanelWindowController.workspace.show()`。窗口已存在时只前置，**不**重挂 SwiftUI 树（保留草稿、过滤条、芯片展开等 `@State`）。不传 tab 时打开 Dashboard；显式传入的今日、手记、日历等 tab 不会被 Dashboard 覆盖。切到不同 tab 会复位侧栏标签并清掉**批量多选**；单选 `selectedTaskID` 与检查器是否打开会保留。同一 tab 再调 `revealTab` 会清掉标签过滤（浮层 Return 才能回到「今日」页），并保留当前检查器选中；带明确检查目标时，在普通导航归位后恢复传入的检查日。离开「灵感手记」tab 会清掉手记滚动高亮。浮层底栏窗口按钮走 `openWorkspace`；`revealWorkspace()` 只前置当前 tab，不切回「今日」页。搜索点习惯/待办走带 `inspecting` 和 `dayKey` 的 `openWorkspace`，手记结果走 `DiaryWindows.open(entry:context:)`；显式「在工作台打开」仍走 `openDiary()`。macOS ⌘, 打开 SwiftUI Settings 场景（同一套设置页）。
2. **激活策略**：平时 `.accessory`（无 Dock）；工作台或手记小窗打开后升为 `.regular`。`AppWindows.diaryWindowsProvider` 把全部手记窗口纳入存活窗口集合，防止关设置/工作台时被当成杂散窗口隐藏；还有可见或最小化窗口时不撤去 Dock。
3. **手记小窗**：`DiaryWindows` 按记录标识复用 `DiaryWindowController`，草稿首次保存后也复用原窗。窗口置顶只设置 `.floating` 层级，不改变记录的 `isPinned`，也不重新激活应用；不自动恢复窗口或未保存正文。关闭窗口使用原生保存确认，应用退出还检查独立窗口和 `BoardComposerSession` 中的手记草稿。
