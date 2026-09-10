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
    MenuBar/      菜单栏浮层与捕获框
    Calendar/     日历月网格（工作台 tab）
    Quadrant/     四象限（工作台 tab）
    Gantt/        当月单日色块安排（工作台 tab）
    Diary/        灵感手记卡片流（多维标签、密码虚化、置顶）
    Attachments/  附件浏览（工作台 tab，侧栏名「附件」）
    Search/       跨天搜索（工作台 tab）
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

1. **CloudKit 预备**：不用 `@Attribute(.unique)`；对外稳定 UUID。设置里 iCloud 开关写入 `wantsICloudSync`，`SettingsView` 不按 `CloudKitAvailability.isConfigured` 禁用，`Persistence` 也不读该偏好，打开不改本地库。
2. **日期键 (`DayKey`)**：`yyyy-MM-dd` 字符串，避免时区与「当天零点 Date」错位。
3. **软删除 (`deletedAt`)**：优先标时间进回收站；彻底删除才物理移除。回收站 UI 列习惯、待办、手记、附件、项目与标签（种类文案「任务 / 常驻 / 日记 / 附件 / 项目 / 标签」）。父项软删时，当时活着的子任务与附件共用同一戳。附件页 `AttachmentClusters.grouped(..., liveOwnerIDs:)` 只显示活父项；父项未知或已删时回收站 `canRestore == false`。
4. **软删除与级联**：父待办勾完成时，应用层把未完成子任务标完成。父待办进回收站时，当时未删的子任务和附件打上同一 `deletedAt`；恢复时只还原时间戳相同的项。SwiftData `.cascade` 只管硬删除。
5. **快照日期**：JSON 使用带小数秒的 ISO8601，旧备份整秒日期仍能导入。

## 关键领域算法

- **`HabitStreakLogic`**：游标按日推进，得 `currentStreak` / `bestStreak`。跳过与非排定日桥接；当天未打卡不破击；历史排定日漏打清零；非排定日若仍 `isDone` 则连击 +1。停用区间（`pausedOnDayKey` 起，旧数据则整段停用）当桥接。启用时把暂停日到今天之前的空排定日补成跳过。
- **`NaturalLanguageParser`**：正则提取时间（含 `@HH:mm`、带时段的「下午3点开会」、无时段时「点」后须空白/标点/`#@!`/「和跟与在去到给把从向」；「点」后直接「问题」不当时刻）、优先级（预览「重要且紧急 / 重要 / 紧急 / 其余」）、`#tag`、多行备注。待办捕获（`parseTaskCapture`）跳过「密码 / 小巧思 / 日记」，把这些 hashtag 留在标题里并继续找下一个普通标签。手记默认仍消费第一个 `#tag`。不提取日期词、不提取项目。
- **`DayBoardLogic`**：今天 / 昨天 / 即将 / 某月未完成等聚合；昨天未完成含习惯。`Classification.precedes`：四象限 → 提醒时刻 → `createdAt`。`BoardFocusDay.key` 把 leftover/即将映射到检查日；`BoardFocusDay.checkDay` 让空格跟点选检查日，避免同一习惯既在昨天芯片又在今日清单时总勾昨天。`InspectDayPolicy` 让常驻页 / 专属清单打开检查器时把检查日钉到今天，切到「任务」「常驻」也会复位 leftover 日历日；日历 / 昨天芯片仍由 `DayBoardList` 自己 `inspectBoard`。
- **`ClipboardPayload`**：剪贴板有文字则只取文字、不挂图；仅图片才挂附件。
- **`SoftDelete`**：软删时间戳；父待办进回收站时子任务与附件共用同一戳，恢复只还原戳相同的项。
- **`ExportDates`**：导出带小数秒，导入兼容旧的整秒 ISO8601。
- **`BoardSearch`**：待办标题、习惯名、手记正文；不搜 notes / 子任务 / 标签。习惯命中的 `dayKey` 是从今天起下一个排定日（今天该打则用今天）。
- **`ReminderPlanning`**：结合时钟、习惯掩码与待办 `dayKey` 算下一枪通知时刻。
- **`NotificationScheduler`**：刷新时用 `Persistence.session.container.mainContext`，能读到刚 persist 的改动。

## 窗口路由与生命周期 (`AppWindows`)

菜单栏入口：`StatusItemController`（`NSStatusItem` + `NSPopover`）。

1. **工作台 (`openWorkspace`)**：`WorkspaceNavigation.revealTab` 后 `PanelWindowController.workspace.show()`。窗口已存在时只前置，**不**重挂 SwiftUI 树（保留草稿、过滤条、芯片展开等 `@State`）。切到不同 tab 会复位侧栏项目/标签并清掉**批量多选**；单选 `selectedTaskID` 与检查器是否打开会保留。同一 tab 再调 `revealTab` 会清掉项目/标签过滤（浮层 Return 才能回到「任务」页），并保留当前检查器选中。离开「灵感手记」tab 会清掉手记滚动高亮。浮层头部展开走 `openWorkspace`；`revealWorkspace()` 只前置当前 tab，不切回「任务」页。搜索点习惯/待办走 `openCalendar()`，点手记走 `openDiary()`，都转调 `openWorkspace(tab:)`。macOS ⌘, 打开 SwiftUI Settings 场景（同一套设置页）。
2. **激活策略**：平时 `.accessory`（无 Dock）；打开工作台升为 `.regular`；工作台关掉后回到 `.accessory`。
3. **面板窗**：只有工作台这一扇 `PanelWindowController`。关设置时 `hideStrayWindows` 会藏起 SwiftUI Settings 场景多出来的窗，避免被当成「下一扇」打开。
