# 架构与目录

工程采用现代 Xcode 文件系统同步组规范：往对应文件夹添加 `.swift` 源代码文件即可自动纳入编译，无需手动频繁修改 `project.pbxproj`。

## 仓库根目录

```text
AreaChain.xcodeproj
AreaChain/                 应用 target 主源码
AreaChainTests/            测试 target，目录严格镜像应用层结构
scripts/                   本机 Debug 编译、安装与测试脚本
docs/                      产品、架构、功能与用法设计文档
README.md                  项目快速入门说明
.gitignore                 Git 忽略项配置
```

> **注意**：禁止将 `build/`、`DerivedData/`、`xcuserdata` 提交到仓库。

## 应用架构分层

```text
AreaChain/
  App/            入口生命周期、签名、主应用 App 定义
  Resources/      Assets.xcassets、Localizable.xcstrings 多语言资源
  Domain/         纯领域层：日期计算、数据模型、过滤逻辑、解析规则、连击算法
  Services/       系统服务层：SwiftData 存储、时钟、通知中心、快照导入导出、热键中心、附件系统、日历同步
  Features/       界面展示层（按业务模块封装）：
    Workspace/    三栏大屏工作台（主分栏视图、任务检查器抽屉、子任务管理、长备注编辑、四象限九宫格）
    Tasks/        核心待办清单（待办行、子任务微视图、进度卡片、浮动批量操作条、过滤条、变更动作集）
    MenuBar/      菜单栏浮层入口与捕获框
    Calendar/     日历月网格与独立日历窗
    Quadrant/     四象限矩阵独立窗
    Gantt/        当月轻量甘特安排独立窗
    Diary/        一句话日记独立窗与时间轴
    Attachments/  附件管理中心独立窗
    Search/       跨天全局搜索独立窗
    Settings/     设置中心独立窗（习惯管理、项目树、标签、系统偏好）
    Trash/        回收站管理独立窗
  Theme/          设计系统：色彩色板、印章复古质感、动效规范、模态确认组件
```

### 分层设计原则

- **Domain（纯领域层）**：禁止 `import SwiftUI` 或 `import AppKit`（模型层允许使用 `SwiftData` 的 `@Model` 宏）。该层承载纯函数业务逻辑（如自然语言解析、习惯连击推算、四象限排序规则、日历日期换算），保证 100% 可独立进行高覆盖率单元测试。
- **Services（系统服务层）**：封装对 macOS 系统 API 的调用（如 `UNUserNotificationCenter`, `EventKit`, `Carbon HotKey`, `SMAppService`）以及磁盘文件 I/O、数据库持久化。业务逻辑决策必须遵循 Domain 函数规范。
- **Features（界面展示层）**：组合 Domain 与 Services，只负责状态绑定与交互呈现，严禁重复编写领域过滤规则。
- **Theme（设计系统）**：统管全应用的色彩、圆角、阴影、微质感与无障碍动效。

## 数据模型设计 (SwiftData 8 张表)

AreaChain 使用 SwiftData 统一管理 8 张核心持久化表结构：

| 模型类名 | 所属领域 | 职责与字段定义 |
|---|---|---|
| `DailyRoutine` | 常驻习惯 | 习惯定义：`id`, `title`, `sortOrder`, `isEnabled`, `createdDayKey`, `weekdayMask`（按位掩码存储执行星期）, `createdAt`, `remindMinutes`（提醒分钟偏移）, `deletedAt`（软删除时间戳）, `projectID`, `tagIDs`, `isImportant`, `isUrgent`, `sourceBundleID`, `notes`（多行长备注），对 `RoutineCheck` 建立级联删除关系。 |
| `RoutineCheck` | 习惯打卡记录 | 单日打卡日志：`id`, `dayKey`（日期键）, `isDone`（已打卡）, `isSkipped`（已跳过），反向关联 `DailyRoutine`。 |
| `TodoItem` | 临时待办 | 待办事务：`id`, `title`, `isDone`, `dayKey`（排定日期）, `createdAt`, `remindMinutes`, `deletedAt`, `projectID`, `tagIDs`, `isImportant`, `isUrgent`, `sourceBundleID`, `calendarEventID`（同步到系统日历的事件标识）, `notes`（多行长备注），对 `SubtaskItem` 建立级联删除关系。 |
| `SubtaskItem` | 待办子任务 | 任务拆解项：`id`, `title`, `isDone`, `sortOrder`, `createdAt`, `deletedAt`，反向级联归属于 `TodoItem`。 |
| `DiaryEntry` | 随手日记 | 日记条目：`id`, `text`, `dayKey`, `createdAt`, `deletedAt`。 |
| `ProjectItem` | 项目分类树 | 结构化项目：`id`, `name`, `sortOrder`, `parentID`（支持树形嵌套）, `deletedAt`。 |
| `TagItem` | 标签分类 | 扁平标签：`id`, `name`, `sortOrder`, `deletedAt`。 |
| `AttachmentItem` | 附件元数据 | 图片附件索引：`id`, `ownerKind`（归属 todo/routine/diary）, `ownerID`, `filename`, `createdAt`, `deletedAt`。**二进制图像不存入数据库**，存储于 `Application Support/areachain-attachments/<id>`。 |

### 数据约束与设计考量

1. **CloudKit 兼容性预备**：不使用 `@Attribute(.unique)` 约束（CloudKit 不支持）；全部对外暴露稳定 UUID。
2. **确定性日期键 (`DayKey`)**：日期统一使用 `yyyy-MM-dd` 格式字符串作为键值，杜绝因时区与「当天零点 Date」精度偏差导致的跨日错位问题。
3. **软删除体系 (`deletedAt`)**：所有对象删除时优先标记 `deletedAt = .now` 进入回收站，仅在用户在回收站点击彻底删除时才会从数据库与磁盘中物理移除。
4. **级联联动保证**：父待办完成时自动完成下属子任务；父待办移入回收站时下属子任务同步软删除。

## 关键领域算法与逻辑模块

- **`HabitStreakLogic`（习惯连续天数与连击推导）**：
  采用日期游标递进算法，精准推导 `currentStreak` 与 `bestStreak`。通过 `WeekdayMask` 判断每日本应排定的状态，对未安排打卡的工作日/休息日及主动「今天跳过」实行透明桥接，保证习惯养成动量不被假期间断误伤。
- **`NaturalLanguageParser`（自然语言快速解析器）**：
  基于纯函数正则表达式组合，高效提取中文自然时间（如「下午3点半」「15:30」）、四象限与优先级标签（`!p1`~`!p4`, `!重要且紧急` 等）、主题标签（`#tag`）以及自动将多行输入的第一行与后续长文本备注（`notes`）干净分离。
- **`DayBoardLogic`（看板数据流引擎）**：
  汇总计算「今天 / 昨天 / 即将 / 某月每日未完成」等聚合状态，与 `BoardSearch` 配合驱动轻量高效的响应式界面刷新。
- **`ReminderPlanning`（通知时间推算）**：
  结合系统时钟、习惯生效掩码与待办指定日期，动态计算下一次需要发送通知的精确绝对时刻。

## 窗口路由与生命周期 (`AppWindows`)

菜单栏主入口采用 `StatusItemController`（`NSStatusItem` + `NSPopover`）。
三栏大屏工作台及各类独立弹窗统一由 `PanelWindowController` 统一接管生命周期：
1. **工作台模式 (`openWorkspace`)**：通过 `WorkspaceNavigation.shared` 统一调度路由，可在三栏工作台内直接切换今天清单、日历、四象限、甘特、日记、附件、搜索、回收站及设置。
2. **应用激活策略 (`ActivationPolicy`)**：平时应用以 `.accessory` 模式隐蔽运行于菜单栏（无 Dock 图标）；当唤起大屏工作台或独立配置窗口时，自动无缝升级为 `.regular` 前台模式；当所有独立窗口关闭后，自动平滑退回 `.accessory` 模式。
