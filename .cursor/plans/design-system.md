# AreaChain 设计系统收敛（新对话交接提示词）

## 使用方法（给用户，每个阶段重复一遍）

每个阶段配两份提示词文件，放在本目录：`design-system-P<n>-execute.md`（执行）和 `design-system-P<n>-verify.md`（独立验收）。

1. 新开对话 A，输入：`@.cursor/plans/design-system-P0-execute.md 按这个文件逐步执行，做完按它的汇报格式汇报。`
2. A 汇报后**不要相信它说的"通过"**。新开对话 B，输入：`@.cursor/plans/design-system-P0-verify.md 按这个文件逐项验收，只读，给结论和整改清单。`
3. B 结论"通过" → 回到架构师对话，说"P0 验收通过，出 P1"，我再生成 `P1-execute` / `P1-verify`（后续阶段的行号依赖上一阶段结果，不能提前生成）。
4. B 结论"不通过" → 新开对话 C，输入：`@.cursor/plans/design-system-P0-execute.md 这是原任务；下面是验收发现的问题，只修这些问题，修完重跑该文件的"最终验证"：<粘贴 B 的整改清单>`。修完再跑一次 B。
5. 执行者和验收者必须是**两个不同的新对话**，不要让同一个对话既做又验。

> 本文件是给新对话的完整任务书。新对话上下文有限（256k）：现状数字、文件路径、行号、命名、基准来源、阶段顺序、验证命令全部在此钉死。**不要重扫仓库、不要重新命名、不要重新设计、不要自行选基准。**

## 0. 给新对话的执行规则

1. 你在 AreaChain 仓库（原生 macOS：SwiftUI + AppKit + SwiftData）。先读 `AGENTS.md`，再读本文件，然后**只读当前阶段的"必读文件"**。
2. 每次对话只做**一个阶段**（第 7 节）；阶段太大可跨两次对话，但旧 API 必须在阶段结束时删除，**不保留转发层、不保留旧名字**。开始时把阶段标为进行中；结束时更新第 8 节。
3. 令牌名、组件名、文件名、variant 名、基准来源是**已决定项**。需要新增令牌或 variant 时只能在上限内增加，并登记到第 8 节。
4. **提问义务**：遇到第 5 节基准决策表和兜底规则都判不了的视觉/尺寸取舍，必须停下来用提问工具问用户，复述其答案确认，直到用户说"对"，再把答案写进第 8 节决策记录。不得自己挑。
5. 不安装、不启动、不发布、不碰签名、不改 `AreaChain/Domain` 的业务规则、不读取真实用户数据。
6. 硬约束：单文件 ≤ 500 行、单函数 ≤ 50 行；新增可见文案同时补 `en` / `zh-Hans`（`AreaChain/Resources/Localizable.xcstrings`）；不把旧测试结果当新改动的证据。
7. 迁移只换"外观实现"，**不改行为**：Return / ⌘Return / Shift+Return / Esc 分级 / 空文本 ↓ / 输入法组合文本 / 撤销 / 焦点 / 选中 / 草稿 / 快捷键注册条件 / 所有 `SyntaxViewAnchor("...")` 与 `accessibilityIdentifier` 字符串。

## 1. 目标与非目标

目标
- 建两层基座：**L1 语义令牌**（颜色、尺寸、字号、圆角、间距、阴影、动效）和 **L2 组件基座**（输入壳、按钮、表面、芯片、分节头、分隔线、分段栏、确认框、修饰键监听）。
- `AreaChain/Features` 只能组合 L2 组件和引用 L1 令牌。**哪怕只用一次的视觉元素也必须先成为基座的 variant**，页面内不得直接画 `RoundedRectangle` / `Capsule` / `Circle` 作视觉、不得写 `.shadow` / `.font(.system(size:` / 系统色 / `.opacity(字面)` / 字面圆角 / `.buttonStyle(.plain)`。
- **菜单栏与工作台使用同一套令牌和同一种视觉**（用户决定）。工作台只保留"有侧栏、有页头、内容更宽"的布局差异，放在 `WorkspaceLayout`。

非目标
- 不改 `DaybookTextField` / `DaybookTextEditor` 的 Coordinator（有测试保护）；不改 `SyntaxOverlay` / `SyntaxAutocompleteView` 的定位与事件监听逻辑。
- 不改产品约定：任务捕获 Return 建待办、⌘Return 记手记；手记浮层输入严格单行；搜索不创建标签；剪贴板捕获与普通输入解析差异。
- 不引入第三方 UI 库；不建 `class` 继承；不新建第二套主题目录。

## 2. "基类 + 重载"在 Swift/SwiftUI 的对应做法（必须遵守）

SwiftUI View 是 struct，**没有类继承**。对应关系：
- 令牌 = `enum` 命名空间下的 `static let`（单份，因为两宿主已统一）；`Color.daybook(name:...)` 必须具名（匿名动态色在 SwiftUI Button 拷贝时 SIGSEGV），并用 `static let` 缓存。
- 组件 = 单一 `struct` View 或 `ViewModifier` + `variant` 枚举 + `@ViewBuilder` slot + `configure: (inout Configuration) -> Void` 闭包。
- **重载规则（用户确认）**：调用点只能通过 `configure` 闭包改"尺寸类"（高度、宽度、内边距、行数），颜色 / 字体 / 阴影 / 圆角必须引用令牌名；同一重载出现在两个及以上调用点，就升级为基座的一个具名 variant。例：任务行默认 `metrics.rowHeight` 36，手记行 `configure { $0.minHeight = 46 }`。
- 按钮 = 实现 `ButtonStyle` 协议。
- 业务包装（`CaptureField`、`DaybookComposer`、`TaskRow` 等）= 薄适配器，只传配置、绑定、回调。

## 3. 现状盘点（2026-09-22 已统计，勿重扫）

### 3.1 现有令牌层（`AreaChain/Theme`）
- `DaybookTheme.swift`：`DaybookSwatch` 原始值；`DaybookTheme` 8 基色（ink / muted / rule / stamp / paper / done / destructive / checkmark）+ 表面色（surface / cardSurface / cardSurfaceHover / hoverFill / pressFill / cardBorder / cardBorderHover / cardSelectionFill / cardSelectionStroke / focusRing）+ `DaybookTheme.Syntax`（标签绿、时间蓝、p1–p4）+ `DaybookRadius`（xs 4 / small 6 / medium 10 / card 12 / large 16 / full）+ `DaybookSpacing`（2/4/8/12/16/24，page 16）+ `DaybookType`（title 16 / subtitle 12 / body 13 / caption 11 / badge 10 / label 10 / entity 17 / section 11）+ `DaybookShadow` + `SectionStamp` / `RowIconButton` / `ComposerAddButton`。
- `DaybookWorkspaceStyle.swift`：`DaybookViewStyle`（enum，`.standard` / `.workspace`，6 派生属性 + `inputBorderWidth`）、`WorkspaceSwatch` / `WorkspaceStyle`（工作台色与尺寸）、`DaybookPageHeader`、`DaybookInputKind`、`DaybookInputChrome`（109–159 行）、`WorkspaceFilterLabel`、`WorkspaceSidebarHeaderAction`、`WorkspaceSidebarRow`。注入点：`Features/Workspace/MainSplitWorkspaceView.swift:41`；测试注入 6 处：`WorkspaceStyleTests.swift:74,100`、`QuadrantLayoutTests.swift:113`、`GanttInteractionTests.swift:216`、`WorkspaceRenderingTests.swift:266`、`CaptureOverlayLayoutTests.swift:144,309`。
- `DaybookChrome.swift`：`DaybookMotion`（snappy / interactive / smooth / strike / checkmark / strikethrough / collapse）、`DaybookHaptics`、`DaybookQuietButtonStyle`、`DaybookEmptyState`、`DaybookNavButton`、`DaybookPeriodBar`、`DaybookField`、`daybookCardStyle`。
- `ModernComponents.swift`：`ModernCheckbox`（控件，保留）、`PillBadge`、`modernCard` / `ModernCardModifier`、`modernRow` / `ModernRowModifier`、`DaybookGroupedCard`、`ModernTaskTitle`（保留）。

### 3.2 字面值失控数字（`AreaChain/` 下）
- 字面字号 245 处（Features 184）；取值：8 (11) / 8.5 (20) / 9 (33) / 9.5 (19) / 10 (37) / 10.5 (10) / 11 (56) / 11.5 (12) / 12 (11) / 13 (9) / 14 (3) / 16 (3) / 6–7.5 (12，图标) / 18、26、36 各 1。
- 字面圆角 77 处：2 (2) / 2.5 (7) / 3 (3) / 3.5 (12) / 4 (9) / 4.5 (5) / 5 (7) / 6 (15) / 7 (2) / 8 (13) / 10 (2)。
- `DaybookTheme.x.opacity(字面)` 153 处；系统色直用 70 处（`Color.orange`：`MenuBarPopoverView.swift:347`、`TaskRow+Badges.swift:71,85`、`SyntaxHelpCard.swift:119,255`；`Color.green`：`DiaryCardComponents.swift:182,186,207`；`Color.red`：`DiaryCardComponents.swift:23,26`、`BoardCommandStrip.swift:40,46,155,163`；`Color.white`：`DiaryQuickComposerView.swift:262`、`TaskDetailScheduleSection.swift:148`；`Color.black.opacity` 阴影与点击感知层）。
- `.shadow(color:` 16 处、12 种组合；字面动画 21 处（Features：`DiaryQuickComposerView.swift:154,155`、`DiaryNoteCard.swift:143`、`BoardCommandStrip.swift:27`、`FooterBar.swift:362`、`MenuBarControls.swift:36`）。
- `isWorkspace ?` 三元 52 处：Theme 31；Features 21（`Diary/DiaryStandaloneView.swift:17`；`Tasks/TaskRow+Badges.swift:16,71,73,74,95,97,98`；`Workspace/TaskDetailDrawer.swift:220,222,223,233`；`Tasks/TaskRow.swift:154,374`；`Calendar/CalendarPage.swift:45`；`Tasks/DaybookProgressRing.swift:14,33`；`Diary/DiaryCardComponents.swift:13`；`Diary/DiaryNoteCard.swift:116,117,120`）。
- `.buttonStyle(.plain)` 96 处：Workspace 24 / Diary 21 / Tasks 19 / Theme 14 / MenuBar 13 / Search 3 / Quadrant 1 / Board 1。

### 3.3 输入壳（4 套 + 5 处自绘）
- `Theme/BoardCaptureRow.swift`：消费者 `MenuBar/CaptureField.swift`、`Diary/DiaryQuickComposerView.swift`（compact，`locksHeight: true` 34pt）、`Theme/DaybookPage.swift` 的 `DaybookComposer`（`paintsChrome: false`）。
- `daybookInputChrome(focused:kind:)`（`DaybookWorkspaceStyle.swift:109–159`）：消费者 `DaybookComposer`（DaybookPage.swift:210）、`DaybookField`（DaybookChrome.swift:223）、`Diary/DiaryCardComponents.swift:96`、`Diary/DiaryPage.swift:244,330`、`Diary/DiaryQuickComposerView.swift:41,179`。
- `DiaryQuickComposerView.workspaceComposer` else 分支（43–51）自绘。
- 自绘：`MenuBar/MenuBarSearchField.swift:110`、`Workspace/WorkspaceHeaderBar.swift:112–116`（`WorkspaceHeaderSearchCapsule`）、`Workspace/TaskDetailNotesView.swift:58`、`Workspace/TaskDetailSubtasksView.swift:122`、`Diary/DiaryWindowView.swift:78`。
- **不动**：`DaybookTextField.swift`、`DaybookTextEditor.swift`、`SyntaxTextField.swift`、`SyntaxTextEditor.swift`、`SyntaxOverlay.swift`、`SyntaxAutocompleteView.swift`、`SyntaxViewAnchor.swift`。

### 3.4 按钮
- 专用 struct 11：`DaybookQuietButtonStyle`、`DaybookNavButton`、`CommandReturnButton`、`CaptureAttributesButton`、`RowIconButton`、`ComposerAddButton`、`BoardCommandStripButton`（Board/BoardCommandStrip.swift:53）、`DiaryTagToggleButtons` / `DiaryDayMoveButtons`（Diary/DiaryOrganizeMenus.swift）、`BoardFilterDropdownButton`（Tasks/BoardFilterBar.swift:176）、`WorkspaceSidebarHeaderAction`。
- 纯图标 `.plain` 按钮 45 处、点击区 9 种（无 / 9 / 12 / 18 / 20 / 22 / 24 / 26 / 28）：`Diary/DiaryCardComponents.swift:201,210,224,238,254,267`、`Workspace/TaskDetailSections.swift:232,242,286`、`Workspace/TaskDetailSubtasksView.swift:183,249,257`、`Tasks/BoardFilterBar.swift:230,242,275,286`、`MenuBar/MenuBarSearchField.swift:42,65,101`、`MenuBar/FooterBar.swift:269,282`、`Diary/DiaryPage.swift:221,240`、`Search/SearchPage.swift:24,44`、`Workspace/WorkspaceHeaderBar.swift:95,151`、`Board/BoardCommandStrip.swift:73`、`Tasks/TaskRow+Menus.swift:42`、`Diary/DiarySummaryRow.swift:338`、`Diary/DiaryQuickComposerView.swift:101`、`Workspace/ResidentsPage.swift:112`、`Workspace/TaskDetailScheduleSection.swift:90`、`Workspace/WorkspaceFilteredListView.swift:68`、`Workspace/TaskDetailClassificationSection.swift:86`、`Tasks/TasksPage+Header.swift:126`、`Tasks/BatchActionBar.swift:195`、`Diary/DiaryWindowView.swift:97`；Theme：`CommandReturnButton.swift:36`、`LiveComposerPreviewHeader.swift:177`、`SyntaxHelpCard.swift:87`、`DaybookWorkspaceStyle.swift:232`、`LiveDiaryComposerPreview.swift:206`、`CaptureAttributesView.swift:99`。
- 自绘 `Menu` label 7 处：`TaskRow+Menus.swift:51`、`DiarySummaryRow.swift:345`、`DiaryNoteCard.swift:217`、`LiveDiaryComposerPreview.swift:212`、`BoardCommandStrip.swift:108`、`FooterBar.swift:291`、`TaskDetailClassificationSection.swift:20`。

### 3.5 表面（卡 / 行 / 分组 / 浮层）
- 共享修饰符消费者：`modernCard` 5、`modernRow` 2（`TaskRow`、`DiarySummaryRow`）、`daybookCardStyle` 1（`TrashPage`）、`DaybookGroupedCard` 2（`DayBoardSections`、`WorkspaceFilteredListView`）、`BoardRowChrome` 3（**指针/选中行为组件，保留**）。
- 自绘 fill+stroke 24 处：`Calendar/CalendarMonthGrid.swift:94`、`Diary/DiaryNoteCard.swift:25,116`、`Diary/DiaryQuickComposerView.swift:46`、`Diary/DiaryWindowView.swift:78`、`Gantt/GanttPage.swift:166`、`MenuBar/FooterBar.swift:223,353`、`MenuBar/MenuBarFilterFlyout.swift:185,240,361`、`MenuBar/MenuBarSearchField.swift:110`、`Search/BoardSearchHitRow.swift:90`、`Tasks/BatchActionBar.swift:201`、`Tasks/DayBoardSections.swift:54`、`Tasks/TaskRow+Badges.swift:22`、`Tasks/TaskRowSubtaskMiniViews.swift:29`、`Tasks/TasksPage+Sections.swift:31,58`、`Workspace/TaskDetailDrawer.swift:232`、`Workspace/TaskDetailNotesView.swift:58`、`Workspace/TaskDetailQuadrantGrid.swift:55`、`Workspace/TaskDetailSubtasksView.swift:122`、`Workspace/WorkspaceGlobalSearchView.swift:124`。
- 浮层面板 11 处：`MenuBarFilterFlyout.swift:187,242`、`BatchActionBar.swift:207`、`SyntaxHelpCard.swift:44`、`SyntaxAutocompleteView.swift:203`、`CaptureAttributesView.swift:126`、`LiveComposerPreviewHeader.swift:186,306`、`LiveDiaryComposerPreview.swift:92`、`DaybookRowBubbles.swift:86,194`。
- 行高：`TaskRow.swift:154` 标准 36；`DiarySummaryRow.swift:124` 46。

### 3.6 芯片 / 计数 / 状态点 / 颜色映射
- `Capsule()` 48 处（Features 31 / Theme 17），共享的只有 `PillBadge`（2 消费者）、`workspaceFilterChrome`（1）、`CaptureAttributesButton`。自绘：`TasksPage+Header.swift:131`、`TasksPage+Sections.swift:86,105,332,340`、`BoardFilterBar.swift:247,369`、`DiaryPage.swift:312`、`DiaryNoteCard.swift:205,237`、`DiaryQuickComposerView.swift:228`、`DiaryCardComponents.swift:26,147,186`、`MenuBarSearchField.swift:70`、`FooterBar.swift:216`、`BoardSearchHitRow.swift:78`、`TaskDetailSubtasksView.swift:230`；Theme：`LiveComposerPreviewHeader.swift:121,134,147,163,270`、`SyntaxHelpCard.swift:200,279`。
- 状态小圆点 6 处：`MenuBarSearchField.swift:52`、`MenuBarPopoverView.swift:347,363`、`MenuBarFilterFlyout.swift:136,331`、`GanttPage.swift:156`。计数文本 14 处、5 种字体写法。
- `DiaryTagChrome.color(for:)` 定义在 `Features/Diary/DiaryNoteCard.swift:6`（密码红 / 小巧思橙 / 日记蓝 / 默认 stamp），被 MenuBar / Tasks / Board 共 5 文件消费；`TaskDetailClassificationSection` 标签写死 `.systemIndigo`。
- 优先级色旁路：`Theme/QuadrantMiniMark.swift:3–19`、`Board/BoardFilterChoices.swift:229`。

### 3.7 分节头 / 分隔线 / 空态 / 分段栏 / 确认框 / 事件监听
- 自绘分节标题 18 处：`TaskDetailDrawer.swift:220,222,223`（uppercase + tracking）、`TaskDetailScheduleSection.swift:16,76,131,216`、`TaskDetailHeaderSection.swift:121`、`TaskDetailQuadrantGrid.swift:15`、`TaskDetailClassificationSection.swift:17,74`、`TaskDetailNotesView.swift:35`、`TaskDetailSubtasksView.swift:48`、`TaskDetailSections.swift:222`、`CalendarMonthGrid.swift:70`、`QuadrantPage.swift:64`、`CalendarPage.swift:61`、`TasksPage+Sections.swift:71`。
- 改色 `Divider` 7 处：`GanttPage.swift:56`、`WorkspaceHeaderBar.swift:26`、`MenuBarFilterFlyout.swift:163,216`、`MenuBarPopoverView.swift:137`、`CalendarPage.swift:104`、`BoardFilterBar.swift:301`。
- 空态：`DaybookEmptyState` 11 消费者（良好）；自绘 `TaskDetailDrawer.swift:54`、`DiaryPage.swift:407`。
- 分段栏：`DaybookQuietTabBar` 在 `Features/MenuBar/MenuBarControls.swift:12`；`TaskDetailWeekdayPicker`（`TaskDetailScheduleSection.swift:135`）自绘。
- 确认框：`TrashConfirm.swift` 10 消费者；裸 `.confirmationDialog` 5（`SettingsView.swift:47`、`DiaryWindowView.swift:34`、`DiaryPage.swift:177`、`TrashPage.swift:54`、`DiaryNoteCard.swift:162`）、`.alert` 2（`SettingsView.swift:35`、`DiaryNoteCard.swift:138`）。
- `.flagsChanged` 监听重复：`Board/BoardRowChrome.swift:86`、`Theme/CommandReturnButton.swift:53`；`.keyDown` 与 `SyntaxOverlay` 监听专用，不动。

## 4. 目标结构

```mermaid
flowchart TB
  subgraph l1 [L1 语义令牌 单份]
    Palette[DaybookPalette]
    Metrics[DaybookMetrics]
    Elevation[DaybookElevation]
    Tokens[DaybookType / DaybookRadius / DaybookSpacing / DaybookMotion]
    Layout[WorkspaceLayout 仅三栏容器可用]
  end
  subgraph l2 [L2 组件基座]
    InputShell[DaybookInputShell]
    Buttons[DaybookButtonStyle + DaybookIconButton]
    Surface[daybookSurface]
    Chip[DaybookChip / DaybookCount / DaybookStatusDot]
    Header[DaybookSectionHeader / DaybookDivider]
    Misc[DaybookSegmentedBar / confirmDestructive / ModifierKeyObserver]
  end
  subgraph l3 [L3 业务适配 Features]
    Pages[CaptureField / DaybookComposer / TaskRow / DiaryNoteCard ...]
  end
  Palette --> InputShell
  Palette --> Buttons
  Palette --> Surface
  Palette --> Chip
  Palette --> Header
  Metrics --> InputShell
  Metrics --> Buttons
  Metrics --> Surface
  Metrics --> Chip
  Elevation --> Surface
  InputShell --> Pages
  Buttons --> Pages
  Surface --> Pages
  Chip --> Pages
  Header --> Pages
  Misc --> Pages
  Layout --> Pages
```

## 5. 基准决策（用户已确认，2026-09-22）

### 5.1 总原则
- **视觉与尺寸基准 = 菜单栏浮层任务页现状**（`MenuBarPopoverView` + `CaptureField` + `TasksPage` + `TaskRow` 在 `.standard` 下的样子）。工作台改成同一套；只保留布局差异。
- **兜底规则**：未在下表单独列出的视觉/尺寸差异，一律取菜单栏任务页现值；菜单栏没有的元素（检查器抽屉、日历格、甘特色块、设置页）取其当前实现但换成令牌。规则也判不了的，按第 0 节第 4 条问用户。
- **冲突判定顺序**：本节决策表 > 兜底规则 > 已有测试断言的值 > 问用户。

### 5.2 决策表（结构来源 / 尺寸 / 视觉）
- 输入壳：结构取 `DaybookInputChrome` 的 `kind` 枚举 + `BoardCaptureRow` 的三段 slot。高度**全局 34**（含工作台）。视觉取 `CaptureField`：未聚焦底 `ink 3%` + 边 `rule 40%` 0.6pt；聚焦底 `surface` + 边 `ink 35%` 0.9pt；**不用蓝色聚焦环**；composer 圆角 8、search 圆角 10、editor 圆角 6；composer 内边距 h10 v7。
- 按钮：结构取 `DaybookQuietButtonStyle` 的 hover / press / reduceMotion / disabled 机制。悬停视觉 = **淡灰圆角底**（`FooterActionItemModifier` 做法，`fill.hover`），不用蓝环。点击区 regular 28 / compact 22 / inline 18。
- 表面：结构取 `ModernRowModifier` / `ModernCardModifier` 的状态驱动。列表容器 = **纸底 + 分隔线，无白卡**（工作台去掉 `DaybookGroupedCard`）。行默认高 36，hover `fill.hover`，选中 `fill.selection` + `border.selection`。卡片（日历格、象限格、抽屉分组）圆角 10、边 `border.subtle`、无阴影。
- 浮层面板：结构取 `SyntaxAutocompletePopup`（纸底、圆角 8、边 `rule 70%` 0.7pt）。阴影统一 **黑 14% / 模糊 8 / 下偏 2**。
- 芯片：结构取 `PillBadge`。填充 `tint 12%`、描边 `tint 35%` 0.8pt、高 18。
- 分节头：结构取 `SectionStamp`（icon + title + count）。**一律不大写**、`DaybookType.section` 11 semibold + 0.5 字距；抽屉字段标题为 `.field` 层级，只有尺寸差异。
- 分隔线：`rule` 三档 `subtle 25% / regular 40% / strong 65%`。
- 分段栏：结构取 `DaybookQuietTabBar`，滑块阴影 = `elevation.raised`（黑 8% / 1.5 / 0.5）。
- 布局：工作台页头 50、内容最大宽 880、侧栏行 28 与内边距、页边距 16 **保留**在 `WorkspaceLayout`，只允许 `MainSplitWorkspaceView.swift`、`WorkspaceSidebarView.swift`、`WorkspaceHeaderBar.swift`、`DaybookPage.swift`、`WorkspaceLayout.swift` 引用。

## 6. 基座规格（命名已定；每文件 ≤ 300 行）

### 6.1 L1 令牌（全部单份 `enum` + `static let`）
- `Theme/DaybookPalette.swift`：`text`（primary=ink, secondary=muted, tertiary=muted 75%, disabled=muted 45%, done, onAccent=白）；`fill`（page=paper, surface, subtle=ink 3%, hover, press, selection=stamp 8%, scrim=黑 0.1%）；`border`（default=rule, subtle=黑 6%, strong=ink 35%, **focus=ink 35%**, selection=stamp 35%）；`status`（pending=systemOrange, success=systemGreen, danger=destructive）；`accent`=stamp、`accentFill` 12%、`accentBorder` 35%；`diaryPreset(.password/.idea/.journal/.default)`（搬 `DiaryTagChrome`）、`tagDefault`（替换 `.systemIndigo`）；`syntax`（原 `DaybookTheme.Syntax` 原值搬入）。颜色字段上限 34。原 `DaybookSwatch` 搬入本文件。
- `Theme/DaybookMetrics.swift`：`inputHeight` 34、`controlHeight` 28、`rowHeight` 36、`chipHeight` 18；`hit.regular` 28 / `.compact` 22 / `.inline` 18；`radius.inputComposer` 8 / `.inputSearch` 10 / `.inputEditor` 6 / `.control` 6 / `.panel` 8 / `.card` 10 / `.inline` 4；`inputInsets(kind:)`（composer h10 v7 / search h10 v8 / editor 4）；`stroke.hairline` 0.5 / `.regular` 0.6 / `.focus` 0.9 / `.emphasis` 1.0。
- `Theme/DaybookElevation.swift`：`.none` / `.raised`（黑 8% / 1.5 / 0.5）/ `.floating`（黑 14% / 8 / 2）；修饰符 `.daybookElevation(_:)`。
- `Theme/WorkspaceLayout.swift`：`headerHeight` 50、`maxContentWidth` 880、`sidebarRowHeight` 28、`sidebarRowVerticalPadding` 4.5、`sidebarRowHorizontalPadding` 8、`sidebarTopInset` 28；同文件收留 `DaybookPageHeader`、`WorkspaceSidebarRow`、`WorkspaceSidebarHeaderAction`。
- `Theme/DaybookTokens.swift`：从 `DaybookTheme.swift` 搬出 `DaybookRadius`（补 `xxs` 2.5、`regular` 8）、`DaybookSpacing`、`DaybookType`（补 `kbd` 8.5 semibold monospaced、`micro` 9 medium、`bodyLarge` 14、`display` 26 light；总数上限 12）。字号映射：8–8.5→kbd；9–9.5→micro；10–10.5→badge/label；11–11.5→caption；12–12.5→subtitle；13–13.5→body；14→bodyLarge；16→title；≥18→display；6–7.5 图标改 `DaybookType.micro`。圆角映射：2–3→xxs；3.5–4.5→xs；5–6→small；7–8→regular；10→medium。允许 ≤ 0.5pt 漂移。
- `DaybookMotion` 补 `fade`（easeInOut 0.15）。

### 6.2 L2 组件基座（`AreaChain/Theme`）
- `DaybookInputShell.swift`：`DaybookInputShell<Leading, Field, Trailing>(kind: DaybookInputKind, focused: Bool, configure: ((inout Configuration) -> Void)? = nil, leading:, field:, trailing:)`；`Configuration` 含 `height`（默认 `metrics.inputHeight`，editor 为 nil 用 minHeight）、`insets`；内置 `.daybookHideInputChrome()`。`DaybookInputKind` 搬到本文件。
- `DaybookButtonStyle.swift`：`DaybookButtonStyle(variant: .quiet | .prominent | .icon | .destructive | .pill(tint) | .menuLabel, size: .regular | .compact | .inline)`；`DaybookIconButton(systemName:label:size:role:action:)`。`CommandReturnButton`、`CaptureAttributesButton` 保留为专用组件（有 anchor 与测试），内部改用本样式。非按钮语义控件保留 `.plain` 并加 `// control: 非按钮语义，保留 .plain`。
- `DaybookSurface.swift`：`daybookSurface(_ variant: .row | .card | .panel | .banner | .cell, isHovered:, isSelected:, isFocused:, configure:)`；`.panel` 自带 `elevation.floating`。`BoardRowChrome` 内部视觉改走 `.row`。
- `DaybookChip.swift`：`DaybookChip(variant: .tag | .count | .filter | .status | .token | .action, isSelected:, tint:, onRemove:, action:) { label }`；同文件 `DaybookStatusDot(color:)`、`DaybookCount(_:emphasis:)`（字体 `DaybookType.badge.monospacedDigit()`）。优先级色一律 `DaybookPalette.syntax.priorityColor / priorityFill`。
- `DaybookSectionHeader.swift`：`DaybookSectionHeader(_ title, level: .page | .section | .field | .column, icon:, count:, trailing:)`；同文件 `DaybookDivider(emphasis: .subtle | .regular | .strong)`。
- `DaybookSegmentedBar.swift`：`DaybookSegmentedBar<Item: Hashable>(items:, selection:, label:)`（原 `DaybookQuietTabBar` 泛型化）。
- `TrashConfirm.swift` 增 `confirmDestructive(isPresented:title:message:confirmTitle:action:)`。
- `ModifierKeyObserver.swift`：单一 `.flagsChanged` 监听，`@Observable var isCommandPressed`。
- 保留不改结构：`DaybookEmptyState`、`ModernCheckbox`、`ModernTaskTitle`、`DaybookPeriodBar`、`DaybookScroller`、`DaybookMotion`、`DaybookHaptics`。

## 7. 阶段（每阶段结束旧 API 必须删净）

### P0 令牌落地
必读：`Theme/DaybookTheme.swift`、`Theme/DaybookWorkspaceStyle.swift`、`Theme/DaybookChrome.swift`（1–60）、`Theme/ModernComponents.swift`（165–221）、`Features/Diary/DiaryNoteCard.swift`（1–15）、`Features/MenuBar/CaptureField.swift`、`Features/MenuBar/FooterBar.swift`（340–370）、`AreaChainTests/Theme/DaybookContrastTests.swift`、`AreaChainTests/Theme/WorkspaceStyleTests.swift`。
做：按 6.1 新建 `DaybookTokens.swift`（搬出 `DaybookRadius / DaybookSpacing / DaybookType` 并补令牌）、`DaybookPalette.swift`（搬入 `DaybookSwatch` 与 `DaybookTheme.Syntax`→`DaybookPalette.Syntax`，更新 6 个文件引用）、`DaybookMetrics.swift`、`DaybookElevation.swift`（5 处 `DaybookShadow` 引用改 `DaybookElevation.raised.color` 后删除 `DaybookShadow`）、`WorkspaceLayout.swift`（6 个布局常量 + 搬入 `DaybookPageHeader` / `WorkspaceSidebarHeaderAction` / `WorkspaceSidebarRow`；`WorkspaceStyle` 中这 6 个常量删除，其 5 处消费者改 `WorkspaceLayout.*`）；`DaybookMotion` 补 `fade`。**`WorkspaceStyle` / `WorkspaceSwatch` / `DaybookViewStyle` 其余部分暂留到 P1 一起删**；`DaybookTheme` 基色暂留（P6 删）。
测试：新建 `AreaChainTests/Theme/DaybookTokenTests.swift`（metrics 数值、elevation 三档互异、radius/type 新令牌、`inputInsets`、`diaryPreset` 映射）；`SyntaxHighlighterTests.swift:52` 改 `DaybookPalette.Syntax.tagNS`；`WorkspaceStyleTests.swift:84` 改 `WorkspaceLayout.headerHeight`；其余测试不动。
完成标准：`./scripts/build.sh test --only-testing AreaChainTests/DaybookTokenTests --only-testing AreaChainTests/DaybookContrastTests --only-testing AreaChainTests/WorkspaceStyleTests --only-testing AreaChainTests/SyntaxHighlighterTests` 通过；`rg 'DaybookShadow|DaybookTheme\.Syntax' AreaChain AreaChainTests` 为空；`rg 'enum (DaybookRadius|DaybookSpacing|DaybookType|DaybookSwatch)' AreaChain/Theme/DaybookTheme.swift` 为空；`python3 -B scripts/check_workflow.py` 通过；`git diff --stat` 中 Features 只允许 `Tasks/TaskRow+Badges.swift`、`Workspace/WorkspaceHeaderBar.swift`、`Workspace/WorkspaceSidebarView.swift`。

### P1 删除双宿主分支
必读：P0 产物；3.2 节 52 处 `isWorkspace ?` 所在文件；`Features/Workspace/MainSplitWorkspaceView.swift`；6 处测试注入文件；`AGENTS.md`（"语言与界面一致性"段）。
做：每处 `style.isWorkspace ? W : S` 取 **S（标准分支）** 并替换为令牌；`WorkspaceStyle.*` 其余 56 处引用（颜色→`DaybookPalette`、字体→`DaybookType`、尺寸→`DaybookMetrics`）全部替换后删除 `WorkspaceStyle`、`WorkspaceSwatch`、`DaybookViewStyle`、环境键、`MainSplitWorkspaceView.swift:41` 注入、6 处测试注入；`DaybookWorkspaceStyle.swift` 删除（`DaybookInputChrome` 与 `DaybookInputKind` 暂搬到 `DaybookChrome.swift`，P2 删；`WorkspaceFilterLabel` 暂搬到 `ModernComponents.swift`，P5 删）。`WorkspaceStyleTests.swift` 改名 `WorkspaceLayoutTests.swift`：删 `workspaceStyleIsOptIn`、`workspaceTextAndControlsMeetContrastTargets`、`inputChromeKeepsStandardAndWorkspaceStrokesSeparate`；保留原生字段字重、页头原点两条（去掉 `.environment(\.daybookViewStyle, .workspace)`）；`workspaceInputAndFilterUseTheirSharedControlMetrics` 改为断言 composer 高 `DaybookMetrics.inputHeight`、search 与 filter 高 `DaybookMetrics.controlHeight`。`DaybookPage` 的 `minWidth/minHeight` 分支：工作台内由三栏容器决定，改为参数 `embedded: Bool` 由 `MainSplitWorkspaceView` 传入。
文档：`AGENTS.md` 把"工作台样式由 DaybookWorkspaceStyle.swift 的环境区分，不能把工作台尺寸和材质强制套到菜单栏或手记小窗"改为"菜单栏、工作台、手记小窗共用同一套令牌与基座；工作台只在 `WorkspaceLayout` 保留布局尺寸"；`docs/architecture.md` "工作台公共外观"段同步。
完成标准：`rg 'daybookViewStyle|isWorkspace|DaybookViewStyle' AreaChain AreaChainTests` 为空；`./scripts/build.sh test --only-testing AreaChainTests/WorkspaceRenderingTests --only-testing AreaChainTests/MenuBarPopoverRenderingTests --only-testing AreaChainTests/CaptureOverlayLayoutTests --only-testing AreaChainTests/QuadrantLayoutTests --only-testing AreaChainTests/GanttInteractionTests --only-testing AreaChainTests/DaybookTokenTests` 通过。

### P2 输入壳
必读：P0/P1 产物；3.3 节全部文件；`docs/usage.md`（26、57 行）；`docs/architecture.md`（"语法输入"段）。
做：新建 `DaybookInputShell.swift`；3.3 节 4 套 + 5 处自绘全部迁入；手记 compact 不再需要 `locksHeight`（全局 34）；前导图标 plus / checkmark / exclamationmark / lock.shield 切换保留；`allowsDiaryShortcut` 保留。删除 `BoardCaptureRow.swift`、`DaybookInputChrome`、`daybookInputChrome`、`DaybookField`、`WorkspaceHeaderSearchCapsule` 自绘。
文档：`docs/usage.md:57` 修正"菜单栏快速输入框采用动态智能属性按钮"（实际为实时预览 `LiveComposerPreviewHeader`，属性按钮只在工作台）；`AGENTS.md` 输入组件列表补 `DaybookInputShell`。
完成标准：`./scripts/build.sh test --only-testing AreaChainTests/DaybookTextFieldTests --only-testing AreaChainTests/DaybookTextFieldSearchTests --only-testing AreaChainTests/CaptureOverlayLayoutTests --only-testing AreaChainTests/InputSyntaxInteractionTests --only-testing AreaChainTests/DiaryComposerInteractionTests --only-testing AreaChainTests/WorkspaceRenderingTests --only-testing AreaChainTests/MenuBarPopoverRenderingTests` 通过；`rg 'BoardCaptureRow|daybookInputChrome|DaybookField\b|WorkspaceHeaderSearchCapsule' AreaChain` 为空；浅/深、中/英各截一次菜单栏任务页与工作台今日页输入框（隔离 QA 构建，见 `docs/architecture.md#隔离验收与真实启用门禁`）。

### P3 按钮（可分两次：a = MenuBar + Tasks + Board + Search；b = Diary + Workspace + Theme）
必读：`Theme/DaybookChrome.swift`（`DaybookQuietButtonStyle`）、`Theme/DaybookTheme.swift`（`RowIconButton` / `ComposerAddButton`）、`Features/MenuBar/FooterBar.swift`（340–370 `FooterActionItemModifier`）、3.4 节全部文件。
做：新建 `DaybookButtonStyle.swift`；96 处 `.plain`、45 处图标按钮、7 处 Menu label、11 个 struct 全部迁入或改用；删除 `DaybookQuietButtonStyle`、`RowIconButton`、`DaybookNavButton`、`ComposerAddButton`、`WorkspaceSidebarHeaderAction`、`BoardCommandStripButton`、`FooterActionItemModifier`（其 hover 逻辑进 `.icon` variant）。
完成标准：模块测试 + `WorkspaceRenderingTests` + `MenuBarPopoverRenderingTests` + `TaskRowInteractionTests` + `DiarySummaryRowTests` 通过；`rg '\.buttonStyle\(\.plain\)' AreaChain` 只剩带 `// control:` 的行；`rg 'DaybookQuietButtonStyle|RowIconButton|DaybookNavButton|ComposerAddButton|FooterActionItemModifier' AreaChain AreaChainTests` 为空。

### P4 表面与浮层
必读：`Theme/ModernComponents.swift`、`Theme/DaybookChrome.swift`（`DaybookCardModifier`）、`Features/Board/BoardRowChrome.swift`、`Features/Tasks/DayBoardSections.swift`、`Features/Workspace/WorkspaceFilteredListView.swift`、3.5 节全部文件。
做：新建 `DaybookSurface.swift`；24 处自绘 + 11 处浮层 + 四个旧修饰符消费者全部迁入；工作台列表去白卡（`DayBoardSections`、`WorkspaceFilteredListView` 改纸底 + `DaybookDivider`）；`DiarySummaryRow` 用 `configure { $0.minHeight = 46 }`。删除 `modernCard` / `modernRow` / `daybookCardStyle` / `DaybookGroupedCard` / `ModernCardModifier` / `ModernRowModifier` / `DaybookCardModifier`。
完成标准：`WorkspaceRenderingTests` + `MenuBarPopoverRenderingTests` + `TaskRowInteractionTests` + `DiarySummaryRowTests` + `SyntaxOverlayPlacementTests` + `BoardFilterBarTests` 通过；`rg 'modernCard|modernRow|daybookCardStyle|DaybookGroupedCard|\.shadow\(color:' AreaChain/Features` 为空。

### P5 芯片、分节头、分隔线、分段栏、确认框、监听器（可分两次：a = 芯片/计数/圆点；b = 其余）
必读：`Theme/ModernComponents.swift`（`PillBadge`）、`Theme/DaybookTheme.swift`（`SectionStamp`）、`Features/MenuBar/MenuBarControls.swift`、`Theme/TrashConfirm.swift`、`Theme/CommandReturnButton.swift`、`Features/Board/BoardRowChrome.swift`（80–100）、3.6 / 3.7 节全部文件。
做：新建 `DaybookChip.swift`、`DaybookSectionHeader.swift`、`DaybookSegmentedBar.swift`、`ModifierKeyObserver.swift`；`TrashConfirm.swift` 增 `confirmDestructive`；48 处 Capsule、6 圆点、14 计数、18 分节头、7 分隔线、2 分段控件、7 裸确认框、2 重复监听全部迁入。删除 `PillBadge`、`SectionStamp`、`WorkspaceFilterLabel` / `workspaceFilterChrome`、`DaybookQuietTabBar`、`DiaryTagPill`、`DiaryTagChrome`（Features）、`QuadrantSlot.themeColor/themeFill` 与 `BoardFilterChoices.priorityDot` 旁路。
完成标准：相关模块测试 + `WorkspaceRenderingTests` + `MenuBarPopoverRenderingTests` 通过；`rg 'Capsule\(\)|PillBadge|SectionStamp|DiaryTagChrome|DaybookQuietTabBar' AreaChain/Features` 只剩带 `// control:` 的行。

### P6 颜色、字号、圆角、动效清扫（按模块：MenuBar → Tasks → Diary → Workspace → 其余页面 → Theme）
做：`DaybookTheme.x` / `DaybookTheme.x.opacity(字面)` → `DaybookPalette.*`；系统色 → `palette.status.* / text.onAccent / fill.scrim`；`.font(.system(size:` → `DaybookType.*`；字面圆角 → `DaybookRadius.*` 或 `metrics.radius.*`；字面动画 → `DaybookMotion.*`。双语补齐：`Domain/SyntaxAutocomplete.swift` 候选副标题（「标签」「重要且紧急…」「早上…」）改为返回本地化 key，由 `SyntaxAutocompletePopup` 用 `LocalizedStringKey` 显示；`SyntaxAutocompletePopup.footerGuide`「切换 / 补全 / 关闭」改 key；`Localizable.xcstrings` 同时补 en / zh-Hans。Theme 模块完成后删除 `DaybookTheme` enum（`DaybookTheme.swift` 文件删除）。
完成标准（每模块）：模块目录下 `rg '\.font\(\.system\(size:|cornerRadius:\s*[0-9]|DaybookTheme\.|Color\.(orange|red|green|white|black|blue|gray)\b|\.(spring|easeInOut|easeOut|easeIn|linear)\((response|duration)' <模块目录>` 为空；`WorkspaceRenderingTests` + `MenuBarPopoverRenderingTests` + `SyntaxAutocompleteTests` 通过。Theme 完成后 `rg 'DaybookTheme' AreaChain AreaChainTests` 为空。

### P7 禁令、文档、全量回归
做：
- `scripts/check_workflow.py` 新增 `check_theme_tokens(root)`：扫描 `AreaChain/Features/**/*.swift`，用现有 `swift_code()` 屏蔽注释与字符串后匹配：`RoundedRectangle\(`、`Capsule\(`、`Circle\(\)`、`\.shadow\(`、`\.font\(\.system\(`、`cornerRadius:\s*[0-9]`、`Color\.(orange|red|green|white|black|blue|gray|primary|secondary)\b`、`\.opacity\([0-9.]+\)`、`\.buttonStyle\(\.plain\)`、`DaybookTheme\.`、`isWorkspace`、`WorkspaceLayout\.`（白名单外文件）。同行含 `// control:` 或 `// token-exempt: 原因` 则跳过。结果名 `theme-tokens`，加入 `run_checks`；`LIMITATIONS` 补"只匹配字面模式，不证明视觉一致"。`scripts/tests` 加单测（正例、负例、注释内不误报、exempt 与白名单生效）。
- 文档：`docs/architecture.md` Theme 段改为"令牌 / 基座 / 业务"三层并列出基座清单与基准决策；`docs/engineering.md` 加 `theme-tokens`；`AGENTS.md` "复用 DaybookTheme.swift 中的主题、字号、间距等定义"改为指向 `DaybookPalette / DaybookMetrics / DaybookTokens` 与基座。
完成标准：`python3 -B scripts/check_workflow.py` 零违规；`python3 -B -m unittest discover -s scripts/tests -v` 通过；`./scripts/build.sh test` 全量通过。

## 8. 状态与记录

- [ ] P0 令牌落地
- [ ] P1 删除双宿主分支
- [ ] P2 输入壳
- [ ] P3a 按钮（MenuBar + Tasks + Board + Search）
- [ ] P3b 按钮（Diary + Workspace + Theme）
- [ ] P4 表面与浮层
- [ ] P5a 芯片 / 计数 / 圆点
- [ ] P5b 分节头 / 分隔线 / 分段栏 / 确认框 / 监听器
- [ ] P6 MenuBar
- [ ] P6 Tasks
- [ ] P6 Diary
- [ ] P6 Workspace
- [ ] P6 Search / Calendar / Quadrant / Gantt / Trash / Attachments / Settings
- [ ] P6 Theme（含双语补齐、删 DaybookTheme）
- [ ] P7 禁令、文档、全量回归

决策记录
- 2026-09-22 用户确认：粒度 = 哪怕只用一次的视觉元素也必须经基座；重载 = configure 闭包只改尺寸、同一重载 ≥ 2 处升级 variant；旧组件一步到位删除，不留转发；双语补齐纳入。
- 2026-09-22 用户确认基准：视觉与尺寸全部以菜单栏浮层任务页为准，单份令牌；输入框聚焦 = ink 35% 灰描边、无蓝环、全局 34 高；按钮悬停 = 淡灰圆角底；列表 = 纸底 + 分隔线、工作台去白卡；浮层阴影 = 黑 14% / 8 / 2；分节头一律不大写；工作台仅保留 `WorkspaceLayout` 布局尺寸；结构基准按 5.2 表。
- 已知文档与实现差异：`docs/usage.md:57` 描述的菜单栏属性按钮实际只在工作台；`AGENTS.md` 中"不能把工作台尺寸和材质强制套到菜单栏"一句将在 P1 按用户决定改写。

每阶段追加：日期、改动文件、运行的命令与结果、未覆盖项、新增令牌/variant 登记、向用户提问及其确认答案。全部完成后删除本文件；`.cursor/plans/areachain.md` 与 `quality-fixes.md` 已完成，可一并删除。
