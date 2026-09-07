# 架构与目录

工程用 Xcode 文件系统同步组：往对应文件夹加 `.swift` 即可，不必改 `pbxproj`（签名文件路径除外）。

## 仓库根目录

```
AreaChain.xcodeproj
AreaChain/                 应用 target
AreaChainTests/            测试 target，目录镜像应用层
scripts/                   本机 Debug 编译与安装
docs/                      人读文档
README.md
.gitignore
.cursor/plans/             进行中的任务跟踪，完成后可删
```

不要把 `build/`、`DerivedData/`、`xcuserdata` 提交进去。

菜单栏入口是 `StatusItemController`（`NSStatusItem` + `NSPopover`），热键走同一套 `toggle`，不再另开「今日」窗口。浮层底栏点「设置 / 日历窗」走 `AppWindows` 激活后再打开；日记窗、回收站、附件、四象限、安排、搜索放在「更多」里，不用 `SettingsLink`。日历窗和四象限窗共用会话级 `BoardSelection.inspectingDayKey`；独立日记窗用 `diaryDayKey`。

## 应用内分层

```
AreaChain/
  App/            入口、签名、Scene 组装
  Resources/      Assets.xcassets、Localizable.xcstrings
  Domain/         纯领域：日期键、模型、过滤规则
  Services/       本机存储、时钟、导入导出、热键、通知、附件、截屏、日历同步、首启
  Features/       界面，按功能分包
    MenuBar/
    Tasks/
    Diary/
    Calendar/
    Attachments/
    Quadrant/
    Gantt/
    Search/
    Settings/
    Trash/
  Theme/          颜色与共用控件
```

规则：

- **Domain** 不 import SwiftUI / AppKit（`Models` 可用 SwiftData）。
- **Services** 可以碰磁盘、系统 API；业务对错仍以 Domain 函数为准。
- **Features** 只组合 Domain + Services，不把过滤规则再写一遍。
- 新功能先落 `Features/<Name>/`，过滤逻辑能单测的放 `Domain/`。
- 测试放 `AreaChainTests/Domain` 或 `AreaChainTests/Services`，与被测文件同层。

## 数据

SwiftData 七张表：

| 类型 | 作用 |
|---|---|
| `DailyRoutine` | 常驻（标题、排序、启用、开始日、星期掩码、创建时间、可选时刻、项目/标签/四象限、捕获 App、进回收站时间） |
| `RoutineCheck` | 某常驻在某一天的完成 / 跳过 |
| `TodoItem` | 某一天的临时任务（含创建时间、可选时刻、同一组分类字段、可选 `calendarEventID`、进回收站时间） |
| `DiaryEntry` | 某一天的一句日记（含进回收站时间） |
| `ProjectItem` | 项目短名单（名字、排序、可选 `parentID`、软删） |
| `TagItem` | 标签短名单（名字、排序、软删） |
| `AttachmentItem` | 附件元数据（归属 routine/todo/diary、文件名、时间）。**二进制不进库**，文件在 `Application Support/areachain-attachments/<id>` |

没有 `@Attribute(.unique)`（CloudKit 不支持）；对外 ID 仍是 UUID。日期用 `DayKey` 字符串 `yyyy-MM-dd`，不用「当天 0 点」的 `Date` 去比较。标签多值存成逗号分隔 UUID 字符串，避免 CloudKit 难消化的多对多。

列表「今天 / 昨天 / 即将 / 未完成 / 某月每天未完成」只通过 `DayBoardLogic` 计算。跨天搜索走 `BoardSearch`。项目/标签/App 过滤和四象限排序也在 Domain（`Classification`）。到点通知的下一枪时刻只通过 `ReminderPlanning` 计算。对应单测在 `AreaChainTests/Domain/`。

本机通知由 `NotificationScheduler` 在启动和 `BoardEvents.changed` 时重排；测试进程不注册热键和通知。日历双向同步由 `CalendarSync` 在开关打开后才要权限、才监听 `EKEventStoreChanged`；测试进程不碰 EventKit。截当前屏走 `ScreenCapture` 一次静图，写入 `AttachmentStore`。旧 JSON 缺 `createdAt` / `remindMinutes` / `deletedAt` / `weekdayMask` / 分类字段 / 项目标签附件数组 / `parentID` / `calendarEventID` 时按缺省读（旧的 `weekdaysOnly: true` 当作周一到周五）。删除先写 `deletedAt` 进回收站，彻底删除才从库里拿掉并删附件文件。JSON 导出附件只出元数据。

`Persistence` 默认仍是本地 `areachain` 库。设置里的 iCloud 开关在未配置容器时只作说明，不改 `ModelConfiguration`。真同步以后需要付费 Team、iCloud capability、`icloud-container-identifiers`，并把配置换成 `cloudKitDatabase: .automatic`。

第二条热键（默认 ⌘⇧V）读一次剪贴板，不监听。测试进程不注册。

## 签名路径

`CODE_SIGN_ENTITLEMENTS` 指向 `AreaChain/App/AreaChain.entitlements`。若再挪 entitlements，必须改 `project.pbxproj`。
