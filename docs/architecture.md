# 架构与目录

工程采用 Xcode 文件系统同步组：往对应文件夹添加 `.swift` 即可纳入编译，无需频繁改 `project.pbxproj`。

## 仓库根目录

```text
AreaChain.xcodeproj
AreaChain/                 应用 target 主源码
AreaChainTests/            测试 target，目录镜像应用层结构
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
    Workspace/    三栏工作台、检查器抽屉、子任务、备注、2×2 四象限
    Tasks/        今日清单、待办行、键盘导航、过滤条、变更动作、批量栏
    MenuBar/      菜单栏浮层与捕获框
    Calendar/     日历月网格（工作台 tab）
    Quadrant/     四象限（工作台 tab）
    Gantt/        当月单日色块安排（工作台 tab）
    Diary/        灵感手记卡片流（多维标签、密码虚化、置顶）
    Attachments/  附件中心（工作台 tab）
    Search/       跨天搜索（工作台 tab）
    Settings/     设置（习惯、项目树、标签、偏好）
    Trash/        回收站（工作台 tab）
  Theme/          色板、印章质感、动效、确认组件
```

独立 `*StandaloneView` 与 `PanelWindowController` 的日历/手记等控制器仍在源码中，公开入口一律 `openWorkspace(tab:)`，不再单独 `show()`。

### 分层设计原则

- **Domain**：禁止 `import SwiftUI` / `import AppKit`（模型可用 SwiftData `@Model`）。纯函数：NLP、连击、四象限排序、日期键。
- **Services**：封装 `UNUserNotificationCenter`、`EventKit`、Carbon HotKey、`SMAppService`、磁盘与持久化。决策走 Domain。
- **Features**：组合 Domain 与 Services，不重复领域过滤规则。
- **Theme**：色彩、圆角、阴影、无障碍动效。

## 数据模型设计 (SwiftData 8 张表)

| 模型类名 | 所属领域 | 职责与字段 |
|---|---|---|
| `DailyRoutine` | 常驻习惯 | `id`, `title`, `sortOrder`, `isEnabled`, `createdDayKey`, `weekdayMask`（及兼容字段 `weekdaysOnly`）, `createdAt`, `remindMinutes`, `deletedAt`, `projectID`, `tagIDs`, `isImportant`, `isUrgent`, `sourceBundleID`, `notes`；对 `RoutineCheck` cascade。 |
| `RoutineCheck` | 习惯打卡 | `id`, `dayKey`, `isDone`, `isSkipped`，反向关联 `DailyRoutine`。跳过时 `isDone = true && isSkipped = true`。 |
| `TodoItem` | 临时待办 | `id`, `title`, `isDone`, `dayKey`, `createdAt`, `remindMinutes`, `deletedAt`, `projectID`, `tagIDs`, `isImportant`, `isUrgent`, `sourceBundleID`, `calendarEventID`, `notes`；对 `SubtaskItem` cascade（硬删除）。 |
| `SubtaskItem` | 待办子任务 | `id`, `title`, `isDone`, `sortOrder`, `createdAt`, `deletedAt`，一层，归属 `TodoItem`。 |
| `DiaryEntry` | 灵感手记 | `id`, `text`, `dayKey`, `createdAt`, `deletedAt`, `tagIDs`, `isPinned`。JSON 导出含标签与置顶；旧备份缺字段时按空标签、未置顶导入。 |
| `ProjectItem` | 项目分类树 | `id`, `name`, `sortOrder`, `parentID`, `deletedAt`。 |
| `TagItem` | 标签 | `id`, `name`, `sortOrder`, `deletedAt`。 |
| `AttachmentItem` | 附件元数据 | `id`, `ownerKind`（todo/routine/diary）, `ownerID`, `filename`, `createdAt`, `deletedAt`。图像文件在 `Application Support/areachain-attachments/<id>`，不进数据库，导出也不含二进制。 |

### 数据约束与设计考量

1. **CloudKit 预备**：不用 `@Attribute(.unique)`；对外稳定 UUID。设置里 iCloud 开关是占位（`CloudKitAvailability.isConfigured == false`），打开不改本地库。
2. **日期键 (`DayKey`)**：`yyyy-MM-dd` 字符串，避免时区与「当天零点 Date」错位。
3. **软删除 (`deletedAt`)**：优先标时间进回收站；彻底删除才物理移除。回收站 UI 列习惯、待办、手记、附件、项目与标签。
4. **软删除与级联**：父待办勾完成时，应用层把未完成子任务标完成。父待办进回收站时，当时未删的子任务打上同一 `deletedAt`；恢复时只还原时间戳相同的子任务。SwiftData `.cascade` 只管硬删除。

## 关键领域算法

- **`HabitStreakLogic`**：游标按日推进，得 `currentStreak` / `bestStreak`。跳过与非排定日桥接；当天未打卡不破击；历史排定日漏打清零；非排定日若仍 `isDone` 则连击 +1。
- **`NaturalLanguageParser`**：正则提取时间（含 `@HH:mm`）、优先级、**第一个** `#tag`、多行备注。不提取日期词、不提取项目。
- **`DayBoardLogic`**：今天 / 昨天 / 即将 / 某月未完成等聚合；昨天未完成含习惯。`Classification.precedes`：四象限 → 提醒时刻 → `createdAt`。
- **`SoftDelete`**：软删时间戳；父待办进回收站时子任务共用同一戳，恢复只还原戳相同的子任务。
- **`BoardSearch`**：待办标题、习惯名、手记正文；不搜 notes / 子任务 / 标签。
- **`ReminderPlanning`**：结合时钟、习惯掩码与待办 `dayKey` 算下一枪通知时刻。

## 窗口路由与生命周期 (`AppWindows`)

菜单栏入口：`StatusItemController`（`NSStatusItem` + `NSPopover`）。

1. **工作台 (`openWorkspace`)**：`WorkspaceNavigation.shared` 切 tab（今日、搜索、四象限、甘特、日历、手记、附件、回收站、设置）。`openDiary` / `openCalendar` / `openSettings` 等全部转调 `openWorkspace(tab:)`。
2. **激活策略**：平时 `.accessory`（无 Dock）；打开工作台升为 `.regular`；工作台关掉后回到 `.accessory`。
3. **遗留独立窗**：`PanelWindowController.settings/diary/calendar/...` 仍实例化在 `panelWindows` 列表里，用于关窗时判断是否退回 accessory；公开路径不再 `show()` 它们。
