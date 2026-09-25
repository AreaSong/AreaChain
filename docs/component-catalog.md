# 共享组件与复用目录

这是 AreaChain 的复用导航，不是新的设计系统，也不是把所有 `struct` 都承诺成公共 API。新任务必须先查本目录，再查看声明和真实调用方；如果目录与代码不一致，以代码、测试和 `AGENTS.md` 的当前契约为准，并在同一任务中修正目录。

## 1. 复用原则

1. 先复用已有令牌、基座、领域规则、仓储和事务入口，再考虑局部扩展。
2. 相似外观不代表相同业务契约。任务、手记、搜索、剪贴板捕获和独立窗口的提交与快捷键语义不能只靠一个布尔参数抹平。
3. 只有一个真实消费者时，默认保留在所属 Feature；多个消费者共享同一语义并需要同步演进时，才提取到公共层。
4. 新公共组件必须有明确归属、至少一个真实调用链、相关测试和本目录条目。
5. `Theme` 负责令牌和通用展示基座；业务复合视图原则上放在所属 `Features`，不要把新的业务视图塞进 `Theme`。当前 `LiveComposerPreviewHeader` 和 `LiveDiaryComposerPreview` 是历史例外；新增消费者不得继续扩大这两个例外，迁移它们需要单独的架构重构授权和回归证据。
6. 目录条目只说明复用边界，不替代类型检查、调用方检查或原生运行验收。

## 2. 令牌与视觉基座

| 类别 | 入口 | 文件 | 适用范围与必须保持的行为 |
|---|---|---|---|
| 语义色 | `DaybookPalette`、`DaybookColor` | [DaybookPalette.swift](../AreaChain/Theme/DaybookPalette.swift)、[DaybookColor.swift](../AreaChain/Theme/DaybookColor.swift) | 使用语义色，不在 Feature 写裸系统色；状态、文本、表面和热力图颜色从这里取。 |
| 尺寸/字号/间距 | `DaybookMetrics`、`DaybookTokens` | [DaybookMetrics.swift](../AreaChain/Theme/DaybookMetrics.swift)、[DaybookTokens.swift](../AreaChain/Theme/DaybookTokens.swift) | 复用高度、间距、圆角、字号和描边；不要用局部常量悄悄改变全局基线。 |
| 阴影/动效 | `DaybookElevation`、`DaybookMotion` | [DaybookElevation.swift](../AreaChain/Theme/DaybookElevation.swift)、[DaybookChrome.swift](../AreaChain/Theme/DaybookChrome.swift) | 遵守浅深色和减弱动态效果；动效调整须检查取消和快速重复操作。 |
| 输入外壳 | `DaybookInputShell`、`DaybookInputKind` | [DaybookInputShell.swift](../AreaChain/Theme/DaybookInputShell.swift) | `composer`、`search`、`editor` 是外壳类型，不改写内部控件的 Return、Escape、撤销或组合文本行为。颜色和聚焦边界由基座管理。 |
| 普通文本输入 | `DaybookTextField`、`DaybookTextEditor` | [DaybookTextField.swift](../AreaChain/Theme/DaybookTextField.swift)、[DaybookTextEditor.swift](../AreaChain/Theme/DaybookTextEditor.swift) | 原生 AppKit 输入桥接；需要核对焦点、输入法、撤销和最小尺寸。 |
| 语法输入 | `SyntaxTextField`、`SyntaxTextEditor` | [SyntaxTextField.swift](../AreaChain/Theme/SyntaxTextField.swift)、[SyntaxTextEditor.swift](../AreaChain/Theme/SyntaxTextEditor.swift) | 任务/手记语法高亮和候选输入；必须提供正确的 `SyntaxInputContext`，搜索不能借此创建标签。 |
| 候选与浮层 | `SyntaxAutocompletePopup`、`SyntaxOverlay` | [SyntaxAutocompleteView.swift](../AreaChain/Theme/SyntaxAutocompleteView.swift)、[SyntaxOverlay.swift](../AreaChain/Theme/SyntaxOverlay.swift) | 就近消费输入锚点，保留 Esc 先关闭候选、焦点和定位；不要在多个宿主重复呈现同一浮层。 |
| 按钮 | `DaybookButtonStyle`、`DaybookIconButton`、`CommandReturnButton` | [DaybookButtonStyle.swift](../AreaChain/Theme/DaybookButtonStyle.swift)、[CommandReturnButton.swift](../AreaChain/Theme/CommandReturnButton.swift) | 复用尺寸、禁用、悬停、可访问性和 Command 反馈；图标按钮需有语义标签。 |
| 表面与分组 | `daybookSurface`、`DaybookChip`、`DaybookSectionHeader`、`DaybookDivider`、`DaybookSegmentedBar` | [DaybookSurface.swift](../AreaChain/Theme/DaybookSurface.swift)、[DaybookChip.swift](../AreaChain/Theme/DaybookChip.swift)、[DaybookSectionHeader.swift](../AreaChain/Theme/DaybookSectionHeader.swift)、[DaybookSegmentedBar.swift](../AreaChain/Theme/DaybookSegmentedBar.swift) | 共享表面、芯片、分节头、分隔线和分段切换；不要在 Feature 自绘同义基座。 |
| 页面和工作台布局 | `DaybookPage`、`DaybookPageHeader`、`WorkspaceLayout`、`WorkspaceSidebarRow` | [DaybookPage.swift](../AreaChain/Theme/DaybookPage.swift)、[WorkspaceLayout.swift](../AreaChain/Theme/WorkspaceLayout.swift) | 页面页头、侧栏和内容宽度遵循已有宿主；`workspaceEmbedded` 只表达能力/布局差异，不切换颜色、字体或主题。 |
| 空态与周期栏 | `DaybookEmptyState`、`DaybookPeriodBar` | [DaybookChrome.swift](../AreaChain/Theme/DaybookChrome.swift) | 区分无数据、筛选无结果和失败；可见文案走本地化。 |
| 任务完成反馈 | `ModernCheckbox`、`ModernTaskTitle` | [ModernComponents.swift](../AreaChain/Theme/ModernComponents.swift) | 只在任务完成语义和现有待沉底/减弱动态效果契约一致时复用；不要把它当作任意布尔开关。 |

`CaptureAttributesView`、`SyntaxHelpCard`、`MenuBarStatusImage` 和 `KeyWindowHost` 也是已有专用基座，但它们分别绑定属性捕获、语法帮助、菜单栏状态图标和原生窗口宿主；复用前必须检查其宿主契约：

- [CaptureAttributesView.swift](../AreaChain/Theme/CaptureAttributesView.swift)
- [SyntaxHelpCard.swift](../AreaChain/Theme/SyntaxHelpCard.swift)
- [MenuBarStatusImage.swift](../AreaChain/Theme/MenuBarStatusImage.swift)
- [KeyWindowHost.swift](../AreaChain/Theme/KeyWindowHost.swift)

## 3. Feature 级复合组件

这些不是全局通用控件，而是带业务语义的可复用组合。新入口优先复用它们的状态和回调契约，不复制内部筛选或保存逻辑。

| 领域 | 入口 | 文件 | 复用边界 |
|---|---|---|---|
| 任务清单 | `TaskRow`、`TaskRowState`、`DayBoardList` | [TaskRow.swift](../AreaChain/Features/Tasks/TaskRow.swift)、[TaskRowState.swift](../AreaChain/Features/Tasks/TaskRowState.swift)、[DayBoardList.swift](../AreaChain/Features/Tasks/DayBoardList.swift) | 任务/子任务展示、选择、键盘和完成反馈；不要在新页面另写父子级联或重复事项完成规则。 |
| 任务筛选 | `BoardFilterBar`、`BoardFilterChoices` | [BoardFilterBar.swift](../AreaChain/Features/Tasks/BoardFilterBar.swift)、[BoardFilterChoices.swift](../AreaChain/Features/Board/BoardFilterChoices.swift) | 使用 `BoardFilter` 的现有字段和交集语义；手记入口不能伪造任务属性。 |
| 工作台清单 | `WorkspaceItemsList`、`WorkspaceHeaderBar`、`WorkspaceSidebarRow` | [WorkspaceItemsList.swift](../AreaChain/Features/Workspace/WorkspaceItemsList.swift)、[WorkspaceHeaderBar.swift](../AreaChain/Features/Workspace/WorkspaceHeaderBar.swift)、[WorkspaceLayout.swift](../AreaChain/Theme/WorkspaceLayout.swift) | 复用工作台布局、搜索入口、页头和侧栏状态；不在页面内创建第二套导航状态。 |
| 检查器 | `TaskDetailDrawer`、子任务/备注视图 | [TaskDetailDrawer.swift](../AreaChain/Features/Workspace/TaskDetailDrawer.swift)、[TaskDetailSubtasksView.swift](../AreaChain/Features/Workspace/TaskDetailSubtasksView.swift)、[TaskDetailNotesView.swift](../AreaChain/Features/Workspace/TaskDetailNotesView.swift) | 保留草稿、取消、失败、外部修改和隐私行为；不要复制保存会话。 |
| 菜单栏 | `MenuBarPopoverView`、`CaptureField`、`MenuBarSearchField`、`MenuBarFilterFlyout` | [MenuBarPopoverView.swift](../AreaChain/Features/MenuBar/MenuBarPopoverView.swift)、[CaptureField.swift](../AreaChain/Features/MenuBar/CaptureField.swift)、[MenuBarSearchField.swift](../AreaChain/Features/MenuBar/MenuBarSearchField.swift)、[MenuBarFilterFlyout.swift](../AreaChain/Features/MenuBar/MenuBarFilterFlyout.swift) | 任务/手记草稿、焦点、快捷键和窗口关闭策略由现有状态对象管理；不要把浮层当成普通页面复制。 |
| 搜索结果 | `BoardSearchHitRow`、`SearchResultsView` | [BoardSearchHitRow.swift](../AreaChain/Features/Search/BoardSearchHitRow.swift)、[SearchResultsView.swift](../AreaChain/Features/Search/SearchResultsView.swift) | 复用结果路由、隐私投影、父任务信息和重复事项日期；搜索本身只读。 |
| 日历 | `CalendarPage`、`CalendarMonthGrid` | [CalendarPage.swift](../AreaChain/Features/Calendar/CalendarPage.swift)、[CalendarMonthGrid.swift](../AreaChain/Features/Calendar/CalendarMonthGrid.swift) | 使用 `DayKey` 和已有日计数；只允许临时待办拖动，不能复制同步规则。 |
| Dashboard | `DashboardView` 及其统计/热力图分节 | [DashboardView.swift](../AreaChain/Features/Dashboard/DashboardView.swift) | 使用既有投影和日期统计；Dashboard 不是第二个可编辑事项清单。 |

## 4. 领域、服务与变更入口

| 语义 | 权威入口 | 文件 | 规则 |
|---|---|---|---|
| 日期 | `DayKey` | [DayKey.swift](../AreaChain/Domain/DayKey.swift) | 使用民事日期语义；不要用 UTC 时间戳替代日键。 |
| 解析 | `NaturalLanguageParser`、`TagSyntax` | [NaturalLanguageParser.swift](../AreaChain/Domain/NaturalLanguageParser.swift)、[TagSyntax.swift](../AreaChain/Domain/TagSyntax.swift) | 任务、习惯、手记和剪贴板的输入契约分别核对；搜索不创建标签。 |
| 筛选/搜索 | `BoardFilter`、`BoardFilters`、`BoardSearch` | [Classification.swift](../AreaChain/Domain/Classification.swift)、[BoardPage.swift](../AreaChain/Domain/BoardPage.swift)、[BoardSearch.swift](../AreaChain/Domain/BoardSearch.swift) | 关键词与结构化筛选取交集；不要在页面重复 `matches` 规则。 |
| 待处理投影 | `AgendaProjection` | [AgendaProjection.swift](../AreaChain/Domain/AgendaProjection.swift) | 逾期、即将、当前/下一排定日和批量能力使用同一投影。 |
| 任务变更 | `DayBoardMutations` | [DayBoardMutations.swift](../AreaChain/Features/Tasks/DayBoardMutations.swift)、[DayBoardMutations+Batch.swift](../AreaChain/Features/Tasks/DayBoardMutations+Batch.swift) | 完成、打卡、标签、改期、回收站和批量动作沿现有事务入口。 |
| 事务和通知 | `ModelChanges` | [ModelChanges.swift](../AreaChain/Services/ModelChanges.swift) | 保存成功后才发布变更；失败保留草稿和用户上下文。 |
| 窗口路由 | `AppWindows`、`DiaryWindows` | [AppWindows.swift](../AreaChain/Services/AppWindows.swift)、[DiaryWindows.swift](../AreaChain/Features/Diary/DiaryWindows.swift) | 工作台、菜单栏和手记小窗沿既有激活/复用策略，不新增平行窗口装配。 |

## 5. 新组件决策清单

新功能需要一个看起来相似的控件时，按以下顺序回答：

1. 是否只是颜色、尺寸、文字或状态变化？优先使用现有令牌或现有基座的参数。
2. 是否已有同一业务语义的 Feature 组件？复用它的状态和回调，不复制内部规则。
3. 是否只有一个消费者？留在所属 Feature，并用具体名称表达职责。
4. 是否有多个真实消费者且契约完全相同？再提取到合适的共享层。
5. 新组件是否会引入新的持久化状态、快捷键、焦点或保存语义？若会，先做架构/契约评估，不能仅以“控件复用”名义加入。
6. 新增后必须补：调用方列表、边界测试、双语/主题验证（若可见）和本目录条目。

禁止事项：

- 不为一个页面复制 `DaybookInputShell`、`BoardFilter`、`ModelChanges` 或 `DayKey` 的替代实现。
- 不在 Feature 中写裸颜色、字号、圆角、阴影或第二套按钮样式。
- 不把 `Theme` 中的业务复合预览、持久化或隐私决策继续扩散到新宿主。
- 不因组件名称相似就跨越任务、手记、搜索和菜单栏的提交契约。

## 6. 目录维护

修改共享组件、公共规则或路由时，必须同步检查：

- 本目录中的文件链接和契约描述；
- 所有真实消费者及其定向测试；
- `docs/architecture.md` 的分层边界（若责任发生变化）；
- `python3 -B scripts/check_workflow.py` 和受影响测试。

本目录是冷启动导航的单一入口之一，不记录一次性任务的临时方案，也不替代产品文档和测试结果。
