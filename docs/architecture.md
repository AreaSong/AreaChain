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
    Workspace/    三栏工作台、常驻页、检查器抽屉、子任务、备注、2×2 四象限
    Tasks/        今日清单、待办行、键盘导航、过滤条、变更动作、批量栏
    MenuBar/      菜单栏浮层、捕获框、可切换底栏与语法搜索
    Calendar/     日历月网格（工作台 tab）
    Quadrant/     四象限（工作台 tab）
    Gantt/        当月单日色块安排（工作台 tab）
    Diary/        灵感手记卡片流（多维标签、密码虚化、置顶）
    Attachments/  附件浏览（工作台 tab，侧栏名「附件」）
    Search/       跨天搜索与工作台/浮层共用的结果列表
    Settings/     设置（外观、启动、捕获、通知、日历、iCloud、数据）
    Trash/        回收站（工作台 tab）
  Theme/          色板、DaybookType 字号、DaybookPage 页壳、动效、确认组件
```

独立 `*StandaloneView` 是工作台 tab 的包装，不是独立窗口。公开入口一律 `openWorkspace(tab:)`，只有 `PanelWindowController.workspace` 会 `show()`。

### 分层设计原则

- **Domain**：禁止 `import SwiftUI` / `import AppKit`（模型可用 SwiftData `@Model`）。纯函数：NLP、连击、四象限排序、日期键。
- **Services**：封装 `UNUserNotificationCenter`、`EventKit`、Carbon HotKey、`SMAppService`、磁盘与持久化。决策走 Domain。
- **Features**：组合 Domain 与 Services，不重复领域过滤规则。
- **Theme**：色彩、圆角、阴影、无障碍动效、页壳 `DaybookPage` 与字号令牌 `DaybookType`。

## 数据模型设计 (SwiftData 8 张表)

| 模型类名 | 所属领域 | 职责与字段 |
|---|---|---|
| `DailyRoutine` | 常驻习惯 | `id`, `title`, `sortOrder`, `isEnabled`, `createdDayKey`, `weekdayMask`（及兼容字段 `weekdaysOnly`）, `createdAt`, `remindMinutes`, `deletedAt`, `projectID`, `tagIDs`, `isImportant`, `isUrgent`, `sourceBundleID`, `notes`, `pausedOnDayKey`（停用当天；旧数据可空）；对 `RoutineCheck` cascade。 |
| `RoutineCheck` | 习惯打卡 | `id`, `dayKey`, `isDone`, `isSkipped`，反向关联 `DailyRoutine`。跳过时 `isDone = true && isSkipped = true`。 |
| `TodoItem` | 临时待办 | `id`, `title`, `isDone`, `dayKey`, `createdAt`, `remindMinutes`, `deletedAt`, `projectID`, `tagIDs`, `isImportant`, `isUrgent`, `sourceBundleID`, `calendarEventID`, `notes`；对 `SubtaskItem` cascade（硬删除）。 |
| `SubtaskItem` | 待办子任务 | `id`, `title`, `isDone`, `sortOrder`, `createdAt`, `deletedAt`，一层，归属 `TodoItem`。 |
| `DiaryEntry` | 灵感手记 | `id`, `text`, `dayKey`, `createdAt`, `deletedAt`, `tagIDs`, `isPinned`。JSON 导出含标签与置顶；旧备份缺字段时按空标签、未置顶导入。 |
| `ProjectItem` | 项目分类树 | `id`, `name`, `sortOrder`, `parentID`, `deletedAt`。 |
| `TagItem` | 标签 | `id`, `name`, `sortOrder`, `deletedAt`。 |
| `AttachmentItem` | 附件元数据 | `id`, `ownerKind`（todo/routine/diary）, `ownerID`, `filename`, `createdAt`, `deletedAt`。图像文件在 `Application Support/areachain-attachments/<id>`，不进数据库，导出也不含二进制。 |

### 数据约束与设计考量

1. **CloudKit 边界**：不用 `@Attribute(.unique)`；对外稳定 UUID。iCloud 开关只写入 `wantsICloudSync`，此版本尚未接入 CloudKit，打开不改变本地库。
2. **日期键 (`DayKey`)**：`yyyy-MM-dd` 字符串，避免时区与「当天零点 Date」错位。
3. **软删除 (`deletedAt`)**：优先标时间进回收站；彻底删除才物理移除。回收站 UI 列习惯、待办、手记、附件、项目与标签。父项软删时，当时活着的子任务与同类型拥有者附件共用同一戳。附件中心通过 `AttachmentAccess` 校验拥有者类型、存活状态和手记隐私；父项未知或已删时附件不能单独恢复。
4. **软删除与级联**：父待办勾完成时，应用层把未完成子任务标完成。父待办进回收站时，当时未删的子任务和附件打上同一 `deletedAt`；恢复时只还原时间戳相同的项。SwiftData `.cascade` 只管硬删除。
5. **快照日期**：JSON 使用带小数秒的 ISO8601，旧备份整秒日期仍能导入。

## 关键领域算法

- **`HabitStreakLogic`**：游标按日推进，得 `currentStreak` / `bestStreak`。跳过与非排定日桥接；当天未打卡不破击；历史排定日漏打清零；非排定日若仍 `isDone` 则连击 +1。停用区间（`pausedOnDayKey` 起，旧数据则整段停用）当桥接。启用时把暂停日到今天之前的空排定日补成跳过。
- **`NaturalLanguageParser`**：正则提取时间（含 `@HH:mm`、带时段的「下午3点开会」、无时段时「点」后须空白/标点/`#@!`/「和跟与在去到给把从向」；「点」后直接「问题」不当时刻）、优先级（预览「重要且紧急 / 重要 / 紧急 / 其余」）、`#tag`、多行备注。待办捕获（`parseTaskCapture`）跳过「密码 / 小巧思 / 日记」，把这些 hashtag 留在标题里并继续找下一个普通标签。手记默认仍消费第一个 `#tag`。不提取日期词、不提取项目。
- **`DayBoardLogic`**：今天 / 昨天 / 即将 / 某月未完成等聚合；昨天未完成含习惯。`Classification.precedes`：四象限 → 提醒时刻 → `createdAt`。`BoardFocusDay.key` 把 leftover/即将映射到检查日；`BoardFocusDay.checkDay` 让空格跟点选检查日，避免同一习惯既在昨天芯片又在今日清单时总勾昨天。`InspectDayPolicy` 让常驻页 / 专属清单打开检查器时把检查日钉到今天，切到「任务」「常驻」也会复位 leftover 日历日；日历 / 昨天芯片仍由 `DayBoardList` 自己 `inspectBoard`。
- **`ClipboardPayload`**：剪贴板有文字则只取文字、不挂图；仅图片才挂附件。
- **`SoftDelete`**：软删时间戳；父待办进回收站时子任务与附件共用同一戳，恢复只还原戳相同的项。
- **`ExportDates`**：导出带小数秒，导入兼容旧的整秒 ISO8601。
- **`BoardSearch`**：搜索待办/习惯标题和备注、手记正文，支持 `#标签` 与待办优先级条件，不搜子任务。私密手记仅返回隐藏标题，不把原文复制进展示对象；习惯命中的 `dayKey` 是从今天起下一个排定日。
- **底栏搜索**：`MenuBarToolbarState` 保留关键词与筛选展示状态；`FooterBar` 互斥显示工具或标签，不使用覆盖工具栏的面板。`MenuBarSearchResults` 先应用当前筛选，再使用同一 `BoardSearch` 和隐私投影；`SearchResultsView` 共用分组与跳转。关键词只存在本次浮层内，不写入偏好或磁盘。
- **语法输入**：`SyntaxInputContext` 区分捕获与搜索；搜索补全仅提供标签与优先级，不提示新建标签或未实现的时间条件。`Theme/DaybookTextField.swift` 封装原生编辑器，保护输入法组合文本和双输入框的快捷键归属。底栏搜索通过输入框锚点在浮层根部向上展示候选，避免底栏命中区域挡住候选点击。
- **`ReminderPlanning`**：结合时钟、习惯掩码与待办 `dayKey` 算下一枪通知时刻。
- **`NotificationScheduler`**：刷新时用 `Persistence.session.container.mainContext`，能读到刚 persist 的改动。

## 保存、恢复与同步边界

- `ModelChanges` 在保存成功后才通知 UI/系统服务，组合操作延后仓储提交；失败时 `ModelRollback` 回滚并在同一 context 重新 fetch 八类模型，刷新已持有的对象缓存。
- `SnapshotImportState` 在预览及写入前校验重复标识、嵌套子任务、附件归属及最终打卡业务键；不自动清洗现存数据。导入失败只撤销导入，调用前已有编辑先保存。
- `DiaryPrivacy` 统一卡片、搜索及删除提示的安全投影；`AttachmentAccess` 按类型和 UUID 检查拥有者。遮罩不改变存储正文，也不是加密；显式复制及 JSON 导出仍包含原文。
- 附件级联按 `ownerKind + ownerID` 执行。永久删除后，`AttachmentCleanup` 仅在文件清理成功后移除附件元数据；失败的附件记录留在回收站，下一次操作可以重试。
- `CalendarSyncCoordinator` 串行合并本地/远端事件；`CalendarSyncEngine` 对比上次本地与远端基线，不盲目先拉后推。基线保存在本机 `areachain-calendar-sync.json`，不改八张表 schema，也不导出到快照。读失败或内存降级时禁写；未知事件保留，冲突需核对一致后重试。跨系统部分提交失败不宣称已同步，旧基线用于幂等恢复。
- `EventKitCalendarClient` 按年分片查询，补查绑定 ID，并在写入前验证事件版本和所属日历。夏令时归一化保存原始本地时刻和实际远端时刻，避免把正常顺延误判为冲突。
- 测试宿主在 `Persistence.makeSession` 的磁盘访问之前切换内存库；端到端系统权限/真实日历验证与单元测试证据分开报告。

## 窗口路由与生命周期 (`AppWindows`)

菜单栏入口：`StatusItemController`（`NSStatusItem` + `NSPopover`）。

`MenuBarStatus` 复用今日看板规则区分未安排、未完成与已处理完。`MenuBarStatusImage` 把书本与状态绘制在固定 45×18pt 的模板图像中，系统负责着色；状态项固定 53pt 宽，按钮标题始终为空，避免系统按数字长度重新居中图标。13pt 等宽数字使用固定 26pt 状态区，`99+` 只限制显示，不改变实际计数；读失败不覆盖上次有效状态。

1. **工作台 (`openWorkspace`)**：`WorkspaceNavigation.revealTab` 后 `PanelWindowController.workspace.show()`。窗口已存在时只前置，**不**重挂 SwiftUI 树（保留草稿、过滤条、芯片展开等 `@State`）。切到不同 tab 会复位侧栏项目/标签并清掉**批量多选**；单选 `selectedTaskID` 与检查器是否打开会保留。同一 tab 再调 `revealTab` 会清掉项目/标签过滤（浮层 Return 才能回到「任务」页），并保留当前检查器选中；带明确检查目标时，在普通导航归位后恢复传入的检查日。离开「灵感手记」tab 会清掉手记滚动高亮。浮层底栏窗口按钮走 `openWorkspace`；`revealWorkspace()` 只前置当前 tab，不切回「任务」页。搜索点习惯/待办走带 `inspecting` 和 `dayKey` 的 `openWorkspace`，点手记走 `openDiary()`，都转调 `openWorkspace(tab:)`。macOS ⌘, 打开 SwiftUI Settings 场景（同一套设置页）。
2. **激活策略**：平时 `.accessory`（无 Dock）；打开工作台升为 `.regular`；工作台关掉后回到 `.accessory`。
3. **面板窗**：只有工作台这一扇 `PanelWindowController`。关设置时 `hideStrayWindows` 会藏起 SwiftUI Settings 场景多出来的窗，避免被当成「下一扇」打开。
