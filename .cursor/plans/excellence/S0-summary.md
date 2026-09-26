# S0 结构摸底汇总

2026-09-26。这是整项目路线 W3 的结果，不是 106 个独立模型会话的逐字读稿。扫描对象是 `S0-units.tsv` 所覆盖的正式代码、测试和文档；结论只保留有文件证据、并且会改变后续重构的项。

## 问题清单

| 项 | 证据 | 处理 |
|---|---|---|
| `DashboardProjection.swift` 曾为 507 行 | 拆分前行数 | W5 已把快照值挪到 `DashboardModels.swift`，计算文件 417 行 |
| Theme 里的实时预览是业务视图 | `docs/component-catalog.md` 已标为历史例外 | 不迁移、不新增消费者 |
| `SearchPage` 无生产入口 | `docs/features.md` 与测试宿主 | 保留给测试，不删、不接到侧栏 |
| 启动、大库、恢复没有性能预算 | `docs/performance-baselines.json` 三条 `not-established` | 不在重构里编预算 |
| 0.4 秒待沉底在测试中被直调 | `PendingCompletionManager` | 不把单测写成生产时序已验收 |
| 真实钥匙串用例默认跳过 | W2 结果里 `SystemVaultIntegrationTests.testAuthorizedPhase` | 保持跳过，不在本路线启用 |

没有发现 Domain 导入 SwiftUI/AppKit，也没有发现需要在本路线合并的第二套日期、筛选或保存入口。

## 决定 → 位置

| 决定 | 位置 |
|---|---|
| 民事日期 | `AreaChain/Domain/DayKey.swift` |
| 解析与标签 | `NaturalLanguageParser.swift`、`TagSyntax.swift` |
| 筛选与搜索 | `Classification.swift`、`BoardSearch.swift` |
| 待处理 | `AgendaProjection.swift` |
| 总览 | `DashboardModels.swift`、`DashboardProjection.swift` |
| 保存 | `AreaChain/Services/ModelChanges.swift` |
| 外观令牌与输入壳 | `AreaChain/Theme/` 中的 `DaybookPalette`、`DaybookMetrics`、`DaybookInputShell` |
| 工作台布局能力 | `WorkspaceLayout.swift` 的 `workspaceEmbedded` |
| 可见文案 | `AreaChain/Resources/Localizable.xcstrings` |

## 复用积木

新功能先查 `docs/component-catalog.md`。稳定入口仍是输入壳、按钮、表面、`TaskRow` / `DayBoardList`、`BoardFilter`、`BoardSearch`、`DayKey`、`AgendaProjection`、`DayBoardMutations`、`ModelChanges`。总览只复用 `DashboardProjection`，不在页面重写热力图或活动公式。
