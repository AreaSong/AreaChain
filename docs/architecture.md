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

菜单栏入口是 `StatusItemController`（`NSStatusItem` + `NSPopover`），热键走同一套 `toggle`，不再另开「今日」窗口。浮层不在 SwiftUI Scene 里，底栏「设置 / 日记窗」走 `AppWindows` 激活后再打开，不用 `SettingsLink`。

## 应用内分层

```
AreaChain/
  App/            入口、签名、Scene 组装
  Resources/      Assets.xcassets、Localizable.xcstrings
  Domain/         纯领域：日期键、模型、过滤规则
  Services/       本机存储、时钟、导入导出、热键、首启
  Features/       界面，按功能分包
    MenuBar/
    Tasks/
    Diary/
    Settings/
  Theme/          颜色与共用控件
```

规则：

- **Domain** 不 import SwiftUI / AppKit（`Models` 可用 SwiftData）。
- **Services** 可以碰磁盘、系统 API；业务对错仍以 Domain 函数为准。
- **Features** 只组合 Domain + Services，不把过滤规则再写一遍。
- 新功能先落 `Features/<Name>/`，过滤逻辑能单测的放 `Domain/`。
- 测试放 `AreaChainTests/Domain` 或 `AreaChainTests/Services`，与被测文件同层。

## 数据

SwiftData 四张表：

| 类型 | 作用 |
|---|---|
| `DailyRoutine` | 例行模板（标题、排序、启用、开始日、是否仅工作日） |
| `RoutineCheck` | 某模板在某一天的完成 / 跳过 |
| `TodoItem` | 某一天的临时待办 |
| `DiaryEntry` | 某一天的一句日记 |

对外 ID 都是 UUID，方便以后同步。日期用 `DayKey` 字符串 `yyyy-MM-dd`，不用「当天 0 点」的 `Date` 去比较。

列表「今天 / 昨天 / 即将 / 未完成」只通过 `DayBoardLogic` 计算，单测在 `AreaChainTests/Domain/DayBoardLogicTests.swift`。

## 签名路径

`CODE_SIGN_ENTITLEMENTS` 指向 `AreaChain/App/AreaChain.entitlements`。若再挪 entitlements，必须改 `project.pbxproj`。
