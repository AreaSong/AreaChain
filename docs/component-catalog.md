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
| 语法输入 | `SyntaxTextField`、`SyntaxTextEditor` | [SyntaxTextField.swift](../AreaChain/Theme/SyntaxTextField.swift)、[SyntaxTextEditor.swift](../AreaChain/Theme/SyntaxTextEditor.swift) | 任务/手记语法高亮和候选输入；必须提供正确的 `SyntaxInputContext`，搜索不能借此创建标签。触发检测和高亮正则编译一次。同一 `NSTextStorage` 在文本、字体、默认色和外观未变时不整段重建属性。外观键取自该 storage 所属文本视图或窗口的 `effectiveAppearance`，没有宿主时才回退 `NSApp`。 |
| 候选与浮层 | `SyntaxAutocompletePopup`、`SyntaxOverlay` | [SyntaxAutocompleteView.swift](../AreaChain/Theme/SyntaxAutocompleteView.swift)、[SyntaxOverlay.swift](../AreaChain/Theme/SyntaxOverlay.swift) | 就近消费输入锚点，保留 Esc 先关闭候选、焦点和定位；不要在多个宿主重复呈现同一浮层。 |
| 按钮 | `DaybookButtonStyle`、`DaybookIconButton`、`CommandReturnButton` | [DaybookButtonStyle.swift](../AreaChain/Theme/DaybookButtonStyle.swift)、[CommandReturnButton.swift](../AreaChain/Theme/CommandReturnButton.swift) | 复用尺寸、禁用、悬停、可访问性和 Command 反馈；图标按钮需有语义标签。`daybookMenuLabel` 与按钮共享内部视觉基座，保留 `fitsLabel` 和系统菜单语义；文字仍按内容加边距，图标为 28/22/18 正方形。原生焦点与显式 `isFocused` 均可显示焦点环，减弱动态效果禁用按下缩放。测试专用 `DaybookControlsPreview` 的开发展示见[工程手册](engineering.md#按钮开发展示与验收)。 |
| 启用开关 | `DaybookToggleStyle` | [DaybookToggleStyle.swift](../AreaChain/Theme/DaybookToggleStyle.swift)、[DaybookMetrics.swift](../AreaChain/Theme/DaybookMetrics.swift) 的 `Toggle` | 默认显示原标签；紧凑布局传 `hiddenLabel: LocalizedStringKey`，同时提供辅助名称，并保留消费者 `labelsHidden` / help 意图。原生 Toggle 的 button 样式承载鼠标与辅助操作；显式焦点容器独占空格按下/释放，临时按下态不镜像业务布尔值。统一轨道、滑块及反馈，无保存、导航或权限行为。几何 34×20、滑块 16、点击高度 28 集中维护；不提供颜色覆盖。仅接入新建重复事项与管理行。 |
| 表面与分组 | `daybookSurface`、`DaybookChip`、`DaybookSectionHeader`、`DaybookDivider`、`DaybookSegmentedBar` | [DaybookSurface.swift](../AreaChain/Theme/DaybookSurface.swift)、[DaybookChip.swift](../AreaChain/Theme/DaybookChip.swift)、[DaybookSectionHeader.swift](../AreaChain/Theme/DaybookSectionHeader.swift)、[DaybookSegmentedBar.swift](../AreaChain/Theme/DaybookSegmentedBar.swift) | 共享表面、芯片、分节头、分隔线和分段切换；不要在 Feature 自绘同义基座。 |
| 页面和工作台布局 | `DaybookPage`、`DaybookPageHeader`、`WorkspaceLayout`、`WorkspaceSidebarRow` | [DaybookPage.swift](../AreaChain/Theme/DaybookPage.swift)、[WorkspaceLayout.swift](../AreaChain/Theme/WorkspaceLayout.swift) | 页面页头、侧栏和内容宽度遵循已有宿主；`workspaceEmbedded` 只表达能力/布局差异，不切换颜色、字体或主题。 |
| 空态与周期栏 | `DaybookEmptyState`、`DaybookPeriodBar` | [DaybookChrome.swift](../AreaChain/Theme/DaybookChrome.swift) | 区分无数据、筛选无结果和失败；可见文案走本地化。 |
| 任务完成反馈 | `ModernCheckbox`、`ModernTaskTitle` | [ModernComponents.swift](../AreaChain/Theme/ModernComponents.swift) | 只在任务完成语义和现有待沉底/减弱动态效果契约一致时复用；不要把它当作任意布尔开关。 |

`CaptureAttributesView`、`SyntaxHelpCard`、`MenuBarStatusImage` 和 `KeyWindowHost` 也是已有专用基座，但它们分别绑定属性捕获、语法帮助、菜单栏状态图标和原生窗口宿主；复用前必须检查其宿主契约：

- [CaptureAttributesView.swift](../AreaChain/Theme/CaptureAttributesView.swift)
- [SyntaxHelpCard.swift](../AreaChain/Theme/SyntaxHelpCard.swift)
- [MenuBarStatusImage.swift](../AreaChain/Theme/MenuBarStatusImage.swift)
- [KeyWindowHost.swift](../AreaChain/Theme/KeyWindowHost.swift)

第二阶段 A 的消费者接入：手记小窗 [DiaryWindowView.swift](../AreaChain/Features/Diary/DiaryWindowView.swift) 的置顶使用 `.active / .subtle`，显示正文和保存使用 `.prominent`（均 compact）；[DiaryCardComponents.swift](../AreaChain/Features/Diary/DiaryCardComponents.swift) 的编辑保存使用 `.prominent`、取消保留 `.quiet`（compact）；[TaskDetailClassificationSection.swift](../AreaChain/Features/Workspace/TaskDetailClassificationSection.swift) 的标签创建/取消使用 `.prominent / .quiet`（regular）。均直接使用 `DaybookButtonStyle`，已有图标按钮及快捷提交入口保留。系统 `confirmationDialog` / `alert` 内按钮继续由系统承载；标签芯片、输入框及其他特殊选择控件不在本次迁移范围。回调、禁用、快捷键、授权和草稿语义不变。消费者回归见 `DiaryButtonConsumerTests`，不替代[第一阶段未验项](engineering.md#第一阶段-b-补充验收2026-10-01)。

第二阶段 B 的消费者接入：[PrivacyUnlockPresenter.swift](../AreaChain/Features/Diary/PrivacyUnlockPresenter.swift) 仅 `PrivacyUnlockView` 的系统验证、密码解锁使用 `.prominent`，取消使用 `.quiet`；[PrivacyPasswordSheet.swift](../AreaChain/Features/Settings/PrivacyPasswordSheet.swift) 的保存/取消及 [PrivacySetupSheet.swift](../AreaChain/Features/Settings/PrivacySetupSheet.swift) 的应用/取消使用 `.prominent / .quiet`，均为 regular。系统验证保留全宽，其他按钮保留原对齐与弹窗尺寸。解锁取消不随 busy 禁用，另外两个 sheet 的取消仍随 busy 禁用；认证、校验、快捷键、密码清空和关闭语义保持不变。直接消费者测试为 [PrivacyButtonConsumerTests.swift](../AreaChainTests/Features/PrivacyButtonConsumerTests.swift)，复用 `PrivacyFixture`、内存配置、`FakeSystemVaultKeys` 与 `SystemPageHost`，Setup 始终传 `probeSystem: false` 且不执行 Apply 提交；具体证据与未测范围见[工程手册](engineering.md#第二阶段-b隐私弹窗按钮接入2026-10-01)。普通设置、快捷键等按钮尚待后续独立迁移，开关、密码框、加载指示器及系统弹窗按钮不在此阶段。

第二阶段 C 的消费者接入：[SettingsSections.swift](../AreaChain/Features/Settings/SettingsSections.swift) 的系统设置入口、通知测试、日历重试/冲突查看使用 `.quiet`，通知申请使用 `.prominent`；[ProjectSupportSections.swift](../AreaChain/Features/Settings/ProjectSupportSections.swift) 的帮助、问题报告、功能建议使用 `.quiet`，仓库/许可证使用 `.subtle`；[HotKeyRecorder.swift](../AreaChain/Features/Settings/HotKeyRecorder.swift) 的录入使用 `.quiet`、原 `listening` 时切换 `.active`，单项重置 `.subtle`；[ShortcutsSettingsView.swift](../AreaChain/Features/Settings/ShortcutsSettingsView.swift) 全部重置 `.quiet`，均为 regular。直接复用 `DaybookButtonStyle`，不设置 Form 根样式，不新增公共 API 或平行状态；业务回调、条件、禁用、通知防重入、链接交接、热键冲突/持久化/注册和监听释放保持原实现。消费者测试复用 `SystemPageHost`，快捷键同时隔离偏好及 fake `HotKeyCenter`；系统按钮仅取呈现和静态回调证据，详见[工程手册](engineering.md#第二阶段-c普通设置快捷键和项目支持按钮接入2026-10-01)。隐私主页、备份、Picker、Toggle、输入框及其他页面不在此阶段。

第二阶段 D 的消费者接入：[PrivacySettingsSection.swift](../AreaChain/Features/Settings/PrivacySettingsSection.swift) 的首次设置、标签管理、锁定/解锁、系统验证方式、主密码设置/移除、清理重试及退出使用 `.quiet`；[DataBackupView.swift](../AreaChain/Features/Settings/DataBackupView.swift) 的普通导入/导出和加密备份/恢复使用 `.quiet`，既有 destructive 重置入口使用 `.destructive`，均为 regular。只增加 14 处 `DaybookButtonStyle`，保留 Form/HStack、回调、角色、禁用、状态和原确认/密码弹窗语义；不新增主次层级、API、包装或令牌。系统 alert、confirmationDialog、NSAlert、文件面板内部按钮仍由系统承载。消费者测试复用 `PrivacyButtonConsumerTests`、`SettingsButtonTestSupport` 与 `SystemPageHost`，隔离范围和未执行链路见[工程手册](engineering.md#第二阶段-d隐私主页与数据备份页按钮接入2026-10-01)。

### 第二阶段 E：按钮接入与全应用静态清单（2026-10-01）

[DiaryPage.swift](../AreaChain/Features/Diary/DiaryPage.swift) 的 `quickComposer` 解锁使用 `.prominent`、丢弃入口使用 `.quiet`；[DayScheduleMenu.swift](../AreaChain/Features/Tasks/DayScheduleMenu.swift) 的 `DaySchedulePicker` 确认使用 `.prominent`，均为 regular，直接复用 `DaybookButtonStyle`。仅新增三行样式；指定 vault、restore/焦点、丢弃确认及角色、临时日期、`initialKey`、`confirmTitle`、`DayKey`、`onPick` 和宿主关闭/保存语义保持。日期本体不变。测试为 `DiaryButtonConsumerTests` 与 `DayScheduleButtonConsumerTests`，证据及限制见[工程手册](engineering.md#第二阶段-e剩余按钮接入与全应用清单核对2026-10-01)。

核对覆盖 `AreaChain/**/*.swift` 的 `Button`、`buttonStyle`、`Menu`、`menuStyle`、公共封装、AppKit 按钮/弹框与点击入口；可疑项沿实际父容器核对。下表路径省略 `AreaChain/`，同一文件可同时包含不同组；不是运行验收或所有间接手势链的证明。

| 组 | 文件与符号/入口 | 分类依据 |
|---|---|---|
| A 公共基座 | `Theme/DaybookButtonStyle.swift`（`DaybookIconButton` / `daybookMenuLabel`）、`CommandReturnButton.swift`；`Features/Board/BoardCommandStrip.swift`（`BoardCommandStripButton/Menu`） | 统一外观的权威实现和薄封装。 |
| A Theme 消费者 | `Theme/DaybookChrome.swift` 日期导航、`DaybookPage.swift` 提交、`SyntaxAutocompleteView.swift`、`LiveComposerPreviewHeader.swift`、`LiveDiaryComposerPreview.swift` 复制/更多 | 显式公共样式/封装；预览的历史业务边界不扩大。 |
| A 任务/手记/菜单栏 | `Features/Tasks/TaskRow+Menus.swift` 复制/更多、`TaskRow+CommandStrip.swift`、`BatchActionBar.swift` 普通操作、`BoardFilterBar.swift`；`Features/Diary/DiaryQuickComposerView.swift`、`DiaryCardComponents.swift`、`DiaryWindowView.swift`、`PrivacyUnlockPresenter.swift`、`DiarySummaryRow.swift` 复制/更多及本次两处；`Features/MenuBar/FooterBar.swift`、`MenuBarSearchResults.swift`、`MenuBarSearchField.swift` 搜索/清空、`MenuBarFilterFlyout.swift` | 使用公共按钮或公共菜单标签；菜单展开项另归 B。 |
| A 设置/剪贴板 | `Features/Settings/SettingsSections.swift`、`ProjectSupportSections.swift`、`HotKeyRecorder.swift`、`ShortcutsSettingsView.swift`、`PrivacySetupSheet.swift`、`PrivacyPasswordSheet.swift`、`PrivacySettingsSection.swift`、`DataBackupView.swift`；`Features/Clipboard/ClipboardHistoryOptions.swift`、`ClipboardHistoryPanel.swift`、`ClipboardHistoryPage.swift` | 已有 A–D 阶段接入或原公共封装。 |
| A 工作台 | `Features/Workspace/ResidentsPage.swift`、`WorkspaceHeaderBar.swift`、`WorkspaceHeaderSearch.swift` 清空、`WorkspacePendingView.swift`、`WorkspaceAllItemsView.swift` 清筛选、`WorkspaceFilteredListView.swift` 批选/父任务、`RecurringItemEditor.swift`；`TaskDetailHeaderSection.swift`、`TaskDetailDrawer.swift`、`TaskDetailSubtasksView.swift` 添加/操作、`TaskDetailNotesView.swift`、`TaskDetailClassificationSection.swift`、`TaskDetailScheduleSection.swift` 提醒、`TaskDetailDueTime.swift`、`TaskDetailSections.swift` | 显式公共样式/封装。`TagManagementPage.selectionActions` 的还原/删除/合并继承 `selectionToolbar` 样式；该证据不覆盖 sheet 或 Menu label。 |
| A 其他页面 | `Features/Dashboard/DashboardSummarySection.swift`、`DashboardActivitySection.swift`、`DashboardTrendSection.swift`、`DashboardHeatmapSection.swift`；`Features/Calendar/CalendarMonthGrid.swift`、`CalendarWeekBoard.swift`；`Features/Attachments/AttachmentBrowserPage.swift`；`Features/Search/BoardSearchHitRow.swift` 的 `.list`；`Features/Trash/TrashPage.swift` 还原/删除 | 普通操作已使用公共入口；日期/内容单元的选择行为另判断。 |
| B 系统菜单内容 | `TaskRow+Menus`、`DayScheduleMenu`、`DiaryOrganizeMenus`、`DiarySummaryRow`、`LiveDiaryComposerPreview`、`WorkspaceHeaderMenuItem`、`FooterBar`、`ClipboardHistoryPage/Browser`、`AttachmentBrowserPage` 的菜单项；下表 D 类 Menu 展开项 | 实际位于 `Menu` / `contextMenu` 中；**不据此豁免页面上的 Menu label**。 |
| B 系统确认/命令 | `Theme/TrashConfirm.swift`；`TrashPage`、`TagManagementPage`、`DiaryPage`、`DiaryWindowView`、`DiaryNoteCard`、`DataBackupView` 的 alert/confirmationDialog；`App/AreaChainApp.quitAlert/AreaChainCommands`、`Services/MutationFeedback`、`DiaryWindows.closeAlert`、`AttachmentPicker`、`PrivacySettingsSection` 的 NSAlert | 系统弹框、CommandGroup 的原生语义。`Services/StatusItemController.setupStatusItemButton` 是系统状态项；`WorkspaceHeaderSearch` 隐藏快捷键桥接不属可见外观。 |
| C 完成/日期/分段 | `Theme/ModernComponents.ModernCheckbox`、`TaskRowSubtaskMiniViews.TaskRowSubtaskInlineList`、`TaskDetailSubtasksView.toggleCheckboxButton`；`TaskDetailScheduleSection.TaskDetailWeekdayPicker`、`Theme/DaybookSegmentedBar.tabButton`、`HabitCheckMonthView.dayCell`、`TaskDetailQuadrantGrid` | 分别承担完成、星期掩码、分段滑块、日格和象限选择，不能批量改普通按钮样式。 |
| C 行/芯片/内容 | `Theme/WorkspaceLayout.WorkspaceSidebarRow`、`WorkspaceSidebarView.tagRow`、`WorkspaceGlobalSearchView.attachmentRow`、`BoardSearchHitRow.workspace`、`QuadrantPage.titleButton`；`DayBoardSections`/`WorkspaceFilteredListView.completedSection`；`Theme/DaybookChip`、`TasksPage+Header.activeFilterTag`、`MenuBarSearchField.tokenChip`；`Theme/CaptureAttributesView.CaptureAttributesButton`、`SyntaxHelpCard` 条目/`complexExampleBar`、`AttachmentThumbnails` | 导航/整行选择、折叠、状态角标、属性浮层或内容预览点击区。`DiaryNoteCard.addTagMenu` 与标签芯片并列，18pt 胶囊随已有标签切换文字/加号，留标签控件阶段。 |

**D：E 阶段记录的未接入清单（已由下述 F 阶段接入）**

| 精确入口 | E 阶段当时的证据 |
|---|---|
| [TagManagementPage.swift:316](../AreaChain/Features/Workspace/TagManagementPage.swift) `mergeSheet` 的 `Button("alert.cancel")` | 自定义 sheet 的 HStack 普通按钮，无公共样式；相邻合并按钮样式只修饰自身。 |
| [BatchActionBar.swift:145](../AreaChain/Features/Tasks/BatchActionBar.swift) `dateAdjustmentMenu` | 页面 HStack 的 Label 只有字体，未调用 `daybookMenuLabel`。 |
| 同文件 `statusAdjustmentMenu`（157 行） | 同上；展开后的系统菜单项保留。 |
| 同文件 `tagAssignmentMenu`（170 行） | 同上；标签菜单触发器没有芯片本体结构。 |
| [WorkspaceAllItemsView.swift:93](../AreaChain/Features/Workspace/WorkspaceAllItemsView.swift) `scopeMenu` | `controls` 的三处筛选菜单共用此定义；label 只有文本/字体，未继承公共菜单外观。 |
| [TagManagementPage.swift:229](../AreaChain/Features/Workspace/TagManagementPage.swift) `colorMenu` | 父级 `DaybookButtonStyle` 不等于 Menu label 接入；只有系统 `.borderlessButton`。 |

E 阶段结束时共余 1 处普通 Button、5 处 Menu 定义（`scopeMenu` 有三个呈现入口）。该历史缺口已由 F 阶段接入；系统 `.borderlessButton` 本身仍不是公共外观证据。特殊控件和间接手势不据此宣称全覆盖。

### 第二阶段 F：菜单入口与标签合并取消（2026-10-01）

上表六处均直接接入公共基座：`TagManagementPage.mergeSheet` 取消使用 `.quiet / .compact`，与相邻 `.prominent / .compact` 合并按钮配合；`colorMenu`、`BatchActionBar` 三个菜单及 `WorkspaceAllItemsView.scopeMenu` 均在原生 Menu 的 label 内容上使用 `daybookMenuLabel(size: .compact, fitsLabel: true)`，保留字体、文字、图标、menuStyle、Section 和系统展开项。

六处定义对应八个逻辑入口（取消、颜色、三个批量菜单、三个筛选）。批量菜单由 `WorkspaceBatchActionBar` 经 `MainSplitWorkspaceView` 的底部 overlay 供标签清单、待处理、全部事项三个宿主消费，共九个菜单/宿主组合，仍受能力和标签非空条件约束；全部事项有独立的事项类型、待办状态、重复事项状态三个入口。颜色工具条的横/竖布局候选是同一个逻辑入口。批量栏采用既有 `ViewThatFits` 模式：宽时横排，窄时将计数/操作、菜单、启停和说明分行，避免新增菜单边距后逐字换行或隐藏文字；不增加公共 API、状态、令牌或保存路径。

F 后复查仍沿上面的 A/B/C 分类：20 个 Menu 定义中，13 个使用公共标签、6 个属于系统展开子菜单，1 个是 `DiaryNoteCard.addTagMenu` 标签胶囊控件。未发现确定遗漏的普通按钮/页面 Menu；21 处 plain 样式继续归完成、日期、星期、象限、分段、导航行、折叠、芯片和内容选择。该结论只覆盖当前静态清单，不能代表全应用运行验收。第三阶段保留 C 类特殊控件，不在 F 迁移。

消费者回归直接挂载生产组件，复用 `SystemPageHost`、`SettingsButtonTestSupport` 及内存模型；入口为 [BatchMenuConsumerTests.swift](../AreaChainTests/Features/BatchMenuConsumerTests.swift)、[WorkspaceMenuConsumerTests.swift](../AreaChainTests/Features/WorkspaceMenuConsumerTests.swift)，菜单事件辅助仅在 [MenuButtonTestSupport.swift](../AreaChainTests/Features/MenuButtonTestSupport.swift)。真实追踪/Escape 与原菜单项动作派发分开取证，结果及剩余运行缺口见[工程手册](engineering.md#第二阶段-f菜单入口与标签合并取消2026-10-01)。

F 补修在 `TagManagementPage.body` 的合并 sheet 边界显式传递宿主 `locale`，复用相邻 `TaskDetailTagSelector` 的环境注入模式；文案键与标签原文、Picker、选择/取消/提交/保存语义不变。`WorkspaceMenuConsumerTests` 保留严格语言断言，覆盖 en/zh-Hans × 浅深色五处文案、360pt 长标签布局、实际取消无提交，以及测试环境语言切换后重开。原中文失败保留在旧包，已由 `ButtonStage2F-locale-matrix.xcresult` 和七组 `ButtonStage2F-locale-regression.xcresult` 消除；完整证据与第二阶段仍部分验收的边界见[工程手册补修记录](engineering.md#f-补修标签合并弹窗语言传递2026-10-01)。

### 第三阶段 A：公共启用开关与重复事项

[RecurringItemEditor.swift](../AreaChain/Features/Workspace/RecurringItemEditor.swift) 使用默认 `DaybookToggleStyle()`，仅修改 `draft.isEnabled`，取消不创建，保存失败保留草稿。[ResidentsPage.swift](../AreaChain/Features/Workspace/ResidentsPage.swift) 使用 `DaybookToggleStyle(hiddenLabel: "residents.enabled")`，原 `enabledBinding` → `DayBoardMutations.setRoutineEnabled`、暂停/恢复及标题失焦保存规则保持。公共组件没有统一两种提交方式。

展示仍在 `DaybookControlsPreview`，开/关、禁用、隐藏标签、长中英文、主题与外部更新使用本地合成状态。上方减弱效果预览仅针对按钮；开关只读取系统减弱动态效果。测试为 `DaybookToggleStyleTests`、`RecurringToggleConsumerTests`，复用现有原生宿主与仓储/事务失败注入；证据与缺口见[工程手册](engineering.md#第三阶段-a公共启用开关与重复事项2026-10-01)。其他 Toggle（设置、剪贴板、隐私）、普通复选框与任务完成圆圈均未迁移；后续须分别核对权限、提交、拒绝更新和焦点契约。

## 3. Feature 级复合组件

这些不是全局通用控件，而是带业务语义的可复用组合。新入口优先复用它们的状态和回调契约，不复制内部筛选或保存逻辑。

| 领域 | 入口 | 文件 | 复用边界 |
|---|---|---|---|
| 任务清单 | `TaskRow`、`TaskRowState`、`DayBoardList` | [TaskRow.swift](../AreaChain/Features/Tasks/TaskRow.swift)、[TaskRowState.swift](../AreaChain/Features/Tasks/TaskRowState.swift)、[DayBoardList.swift](../AreaChain/Features/Tasks/DayBoardList.swift) | 任务/子任务展示、选择、键盘和完成反馈；不要在新页面另写父子级联或重复事项完成规则。`TasksPage` 与 `DayBoardList` 各自一次 body 只建一份 `DayBoardPageProjection` / `DayBoardListIdentity`，父子不共享。筛选、空态和计数断言走 `DayBoardPageProjection.project`，不要从 `TasksPage` 再投影一次。行上连击和附件走该次索引，不要每行再扫 checks 或附件表。今日和浮层任务清单由 `TasksPage` 滚动：短清单只把内容的最小高度铺满视口，便于点空白取消选中；条目超出视口时内容继续增高，不能把高度固定成视口。今日清单多选后，空格和 Delete 只动焦点行。 |
| 行铬与命令条 | `BoardRowChrome`、`BoardCommandStrip` | [BoardRowChrome.swift](../AreaChain/Features/Board/BoardRowChrome.swift)、[BoardCommandStrip.swift](../AreaChain/Features/Board/BoardCommandStrip.swift) | 任务行与手记摘要/卡片共用悬停、选中和快捷操作条；不要在新行控件再写一套铬层。 |
| 回收确认 | `PendingTrash`、`confirmMoveToTrash` | [TrashConfirm.swift](../AreaChain/Theme/TrashConfirm.swift) | 任务、手记、附件、工作台清单和回收站共用确认绑定；不要再做一个平行的删除确认状态。 |
| 手记清单 | `DiaryPageListModel`、`DiarySummaryRow`、`DiaryNoteCard` | [DiaryPageListModel.swift](../AreaChain/Features/Diary/DiaryPageListModel.swift)、[DiarySummaryRow.swift](../AreaChain/Features/Diary/DiarySummaryRow.swift)、[DiaryNoteCard.swift](../AreaChain/Features/Diary/DiaryNoteCard.swift) | `DiaryPage` 一次 body 只建一份 `DiaryPageListModel`：`parseQuery`、活条目、标签计数、`listedDiaries` 和 `DiaryPrivacy.isSensitive`。空查询仍列出全部未删除项，不与搜索 `hits` 空结果对齐，也不读保险箱；`!优先级`/`@时刻` 整组退出。行上不要再 snapshot 或重跑 `isSensitive`。键盘事件会另建一份，不与 body 共享。不改捕获保存、快捷键或解锁语义。 |
| 任务筛选 | `BoardFilterBar`、`BoardFilterChoices` | [BoardFilterBar.swift](../AreaChain/Features/Tasks/BoardFilterBar.swift)、[BoardFilterChoices.swift](../AreaChain/Features/Board/BoardFilterChoices.swift) | 使用 `BoardFilter` 的现有字段和交集语义；手记入口不能伪造任务属性。标签、优先级、提醒和来源经 `BoardFilterCodec` 写入偏好，日期范围不写入。 |
| 工作台清单 | `WorkspaceItemsList`、`WorkspaceHeaderBar`、`WorkspaceSidebarRow` | [WorkspaceItemsList.swift](../AreaChain/Features/Workspace/WorkspaceItemsList.swift)、[WorkspaceHeaderBar.swift](../AreaChain/Features/Workspace/WorkspaceHeaderBar.swift)、[WorkspaceLayout.swift](../AreaChain/Theme/WorkspaceLayout.swift) | 复用工作台布局、搜索入口、页头和侧栏状态；不在页面内创建第二套导航状态。`WorkspaceItemsList` 自己滚动，页头和筛选留在外面，调用方不要再套一层 `ScrollView`。一次 body 只建一份 `WorkspaceItemsListIdentity`：UUID 查表、`DayBoardCheckIndex`、`TaskCatalogContext` 和连击。行上不要再 `compactMap` checks 或 `first(where:)` 找回模型。待处理/全部事项先各建一份页面模型再交给清单；标签专属清单仍用 `WorkspaceFilteredListView` 自己的滚动。失效条件是当前入参，不是跨 body 可变缓存。 |
| 检查器 | `TaskDetailDrawer`、子任务/备注/截止/月历 | [TaskDetailDrawer.swift](../AreaChain/Features/Workspace/TaskDetailDrawer.swift)、[TaskDetailSubtasksView.swift](../AreaChain/Features/Workspace/TaskDetailSubtasksView.swift)、[TaskDetailDueTime.swift](../AreaChain/Features/Workspace/TaskDetailDueTime.swift)、[HabitCheckMonthView.swift](../AreaChain/Features/Workspace/HabitCheckMonthView.swift) | 保留草稿、取消、失败、外部修改和隐私行为；不要复制保存会话。截止时刻只在待办检查器，不进提醒或日历。习惯月历只切换检查日。子任务拖动走 `ManualOrder`，令牌前缀与清单排序分开。 |
| 菜单栏 | `MenuBarPopoverView`、`CaptureField`、`MenuBarSearchField`、`MenuBarFilterFlyout` | [MenuBarPopoverView.swift](../AreaChain/Features/MenuBar/MenuBarPopoverView.swift)、[CaptureField.swift](../AreaChain/Features/MenuBar/CaptureField.swift)、[MenuBarSearchField.swift](../AreaChain/Features/MenuBar/MenuBarSearchField.swift)、[MenuBarFilterFlyout.swift](../AreaChain/Features/MenuBar/MenuBarFilterFlyout.swift) | 任务/手记草稿、焦点、快捷键和窗口关闭策略由现有状态对象管理；不要把浮层当成普通页面复制。 |
| 搜索结果 | `BoardSearchHitGroups`、`BoardSearchHitRow`、`WorkspaceGlobalSearchView`、`SearchResultsView` | [BoardSearchHitRow.swift](../AreaChain/Features/Search/BoardSearchHitRow.swift)、[WorkspaceGlobalSearchView.swift](../AreaChain/Features/Workspace/WorkspaceGlobalSearchView.swift)、[SearchResultsView.swift](../AreaChain/Features/Search/SearchResultsView.swift) | 分组与命中行共用；打开方式由调用方决定。没有独立搜索页。工作台顶栏用 `BoardSearchHitGroups`（`presentation: .workspace`）就地打开检查器。`SearchResultsView` 只服务菜单栏，打开任务走日历。不要把菜单栏路由复制进工作台。工作台和菜单栏一次 body 先 `parseQuery`，空查询不建 snapshot；非空才 map snapshot 并 `hits(parsed)`。附件文件名复用同一份 `textKeywords`。含 `!优先级`/`@时刻` 的查询不建手记 snapshot。打开附件只 snapshot 命中的那一条拥有者，不整表 map 后再 `first(where:)`。每个字符仍会因 query 变化重算，但同一次 body 不再重复解析。 |
| 日历 | `CalendarPage`、`CalendarMonthGrid`、`CalendarWeekBoard` | [CalendarPage.swift](../AreaChain/Features/Calendar/CalendarPage.swift)、[CalendarMonthGrid.swift](../AreaChain/Features/Calendar/CalendarMonthGrid.swift)、[CalendarWeekBoard.swift](../AreaChain/Features/Calendar/CalendarWeekBoard.swift) | 使用 `DayKey` 和已有日计数；月/周切换只在日历页。只允许临时待办拖到另一天或另一周列，不能复制同步规则。行上排序放下在没有排序项时不安装，避免挡住周列改期。 |
| Dashboard | `DashboardView` 及其统计/热力图分节 | [DashboardView.swift](../AreaChain/Features/Dashboard/DashboardView.swift) | 使用既有投影和日期统计；Dashboard 不是第二个可编辑事项清单。一次 body 只建一份 `DashboardSnapshot`；热力列分组在 `DashboardHeatmapLayout` 内只切一次。 |
| 剪贴板历史 | `ClipboardHistoryBrowser`、`ClipboardHistorySession` | [ClipboardHistoryBrowser.swift](../AreaChain/Features/Clipboard/ClipboardHistoryBrowser.swift)、[ClipboardHistorySession.swift](../AreaChain/Services/ClipboardHistorySession.swift) | 工作台「内容 → 剪贴板」和剪贴板历史小窗共用这一份会话。忽略、排序、搜索、置顶字母和条数只走 `ClipboardHistoryRules`。历史不跟隐私锁走。不要把历史写成待办，也不要并进 `ClipboardCapture`。菜单栏 Option 单击只切换记录开关，普通点击仍开关浮层。 |

工作台公共顶栏由 [WorkspaceHeaderContent.swift](../AreaChain/Features/Workspace/WorkspaceHeaderContent.swift) 的 `WorkspaceHeaderAction` / `workspaceHeader` 传递页面动作和动态状态，`WorkspaceHeaderBar` 只负责呈现与固定优先级收纳，搜索输入 `WorkspaceHeaderSearchCapsule` 在 [WorkspaceHeaderSearch.swift](../AreaChain/Features/Workspace/WorkspaceHeaderSearch.swift)。今日、待处理、日历、标签清单、标签管理、剪贴板、回收站提供各自原有操作；其他页面只用公共标题/帮助。`workspaceInspectorTargets` 由今日、待处理、全部事项、日历、安排、四象限、标签清单和搜索登记当前投影对象。回归见 `WorkspaceHeaderStateTests`、`WorkspaceHeaderInteractionTests`、`WorkspaceRenderingTests`，并覆盖菜单栏和独立输入宿主。菜单文字点击区复用 `daybookMenuLabel(fitsLabel: true)`，默认仍是原有图标正方形；`DaybookPeriodBar.todayLabel` 默认回到今天，安排页显式回到本月。`DaybookProgressRing.showsPercentage` 默认保留百分比，顶栏紧凑进度只关掉环内数字，旁边保留完成数/总数。

## 4. 领域、服务与变更入口

| 语义 | 权威入口 | 文件 | 规则 |
|---|---|---|---|
| 指令目录与参数 | `CommandCatalog.standard`、`CommandDescriptor`、`CommandParameter`、`CommandCatalogValidation`、`CommandArgumentValidation` | [CommandCatalog.swift](../AreaChain/Domain/CommandCatalog.swift)、[CommandDescriptor.swift](../AreaChain/Domain/CommandDescriptor.swift)、[CommandParameter.swift](../AreaChain/Domain/CommandParameter.swift)、[CommandCatalogValidation.swift](../AreaChain/Domain/CommandCatalogValidation.swift)、[CommandArgumentValidation.swift](../AreaChain/Domain/CommandArgumentValidation.swift) | 阶段 1A 的唯一纯领域目录；当前消费者仅 Domain 契约测试，后续解析、补全、草稿须复用稳定 ID、参数和能力声明。范围不限制全局指令发现，特殊选择器必须解释限制。全部适配未接线；结构校验不是业务权限或真实对象校验。完整映射、命名与证据只在[权威设计](unified-search-commands.md#96-阶段-1a-目录决策与证据)维护。 |
| 指令路径与补全 | `CommandPathParser`、`CommandPathResult`、`CommandPathCandidate` | [CommandPathParser.swift](../AreaChain/Domain/CommandPathParser.swift)、[CommandPathResult.swift](../AreaChain/Domain/CommandPathResult.swift) | 1B-1 纯领域独立输入，复用上述目录/参数与 TagSyntax 保护区间；当前仅 CommandPathTests / CommandPathConflictTests 消费。UTF-16 局部替换只生成编辑意图；规则和 partial 验收见[权威设计](unified-search-commands.md#97-阶段-1b-1-指令路径解析与补全)。 |
| 日期 | `DayKey` | [DayKey.swift](../AreaChain/Domain/DayKey.swift) | 使用民事日期语义；不要用 UTC 时间戳替代日键。 |
| 解析 | `NaturalLanguageParser`、`TagSyntax` | [NaturalLanguageParser.swift](../AreaChain/Domain/NaturalLanguageParser.swift)、[TagSyntax.swift](../AreaChain/Domain/TagSyntax.swift) | 任务、习惯、手记和剪贴板的输入契约分别核对；搜索不创建标签。 |
| 筛选/搜索 | `BoardFilter`、`BoardFilters`、`BoardSearch` | [Classification.swift](../AreaChain/Domain/Classification.swift)、[BoardPage.swift](../AreaChain/Domain/BoardPage.swift)、[BoardSearch.swift](../AreaChain/Domain/BoardSearch.swift) | 关键词与结构化筛选取交集；日清单和昨天/即将芯片用 `matchesListedRow`，不要在页面再写一套日期判断。逾期筛选下一次 `hits` 对入围习惯只调一次 `AgendaProjection.overdueRoutines`，不为每个习惯重建闭合索引。`hits` 可吃已解析的 `BoardSearchQuery`；手记命中共用一次 `TagNameIndex`，不为每条手记再规范化标签名。手记页列表走 `listedDiaries`：空查询返回全部未删除项，与 `hits` 空查询返回 [] 不同。 |
| 待处理投影 | `AgendaProjection` | [AgendaProjection.swift](../AreaChain/Domain/AgendaProjection.swift) | 逾期、即将、当前/下一排定日和批量能力使用同一投影。 |
| 日看板投影 | `DayBoardPageProjection`、`DayBoardDayProjection`、`DayBoardCheckIndex` | [DayBoardPageProjection.swift](../AreaChain/Domain/DayBoardPageProjection.swift)、[DayBoardCheckIndex.swift](../AreaChain/Domain/DayBoardCheckIndex.swift) | 今日清单、昨天/即将芯片和当日 open/done 共用一份快照与 first-wins 闭合索引。失效条件是传入的 routines/checks/todos 或筛选变化，不是跨 body 的可变缓存。`TasksPage` 嵌套 `DayBoardList` 时各自建一份，不把结果跨视图缓存。 |
| 总览投影 | `DashboardProjection`、`DashboardSnapshot` | [DashboardProjection.swift](../AreaChain/Domain/DashboardProjection.swift)、[DashboardModels.swift](../AreaChain/Domain/DashboardModels.swift) | 今日、趋势、热力图和活动只用这一份；视图不另写公式。日统计在一次 `project` 里共用闭合日键和打卡索引。快照值与计算分文件，只为遵守单文件行数上限。`DashboardView` 把这一份快照绑在 body 局部常量上，不要用计算属性让每个分节再投影一次。 |
| 标签清单 | `Catalog` | [Catalog.swift](../AreaChain/Domain/Catalog.swift) | 标签匹配、附件聚类和标签清单口径只用这一份。`matchingListedRoutines` / `openCount` 对当天打卡做 first-wins 闭合集合；闭合语义与看板相同，不走待处理「任一条闭合」。活附件按拥有者分组走 `CatalogAttachmentIndex`，不要每行再扫整表。 |
| 任务变更 | `DayBoardMutations` | [DayBoardMutations.swift](../AreaChain/Features/Tasks/DayBoardMutations.swift)、[DayBoardMutations+Batch.swift](../AreaChain/Features/Tasks/DayBoardMutations+Batch.swift) | 完成、打卡、标签、改期、回收站和批量动作沿现有事务入口。 |
| 附件拥有者 | `AttachmentAccess`、`AttachmentOwnerIndex` | [DiaryPrivacy.swift](../AreaChain/Domain/DiaryPrivacy.swift) | 回收站/浏览按 owner key 走 context predicate；工作台搜索拥有者仍用整表清单建索引，附件只 `@Query` 活行。选图/保存走同一套 id descriptor。重复 UUID 不可用。不能用「未删除 ID 集合」替代 `isSingleLive`。 |
| 事务和通知 | `ModelChanges` | [ModelChanges.swift](../AreaChain/Services/ModelChanges.swift) | 保存成功后才发布变更；失败保留草稿和用户上下文。 |
| 窗口路由 | `AppWindows`、`DiaryWindows` | [AppWindows.swift](../AreaChain/Services/AppWindows.swift)、[DiaryWindows.swift](../AreaChain/Features/Diary/DiaryWindows.swift) | 工作台、菜单栏和手记小窗沿既有激活/复用策略，不新增平行窗口装配。设置从应用菜单、⌘, 和浮层进入工作台设置页。 |
| 项目支持 | `ProjectSupport` | [ProjectSupport.swift](../AreaChain/Domain/ProjectSupport.swift) | 版本、使用说明、问题报告、功能建议、仓库和许可证链接只用这一份。问题报告只含应用版本、构建号、macOS 版本和界面语言，不接收手记、附件或密码。 |
| 快捷键 | `ShortcutCatalog`、`ShortcutStore` | [ShortcutCatalog.swift](../AreaChain/Domain/ShortcutCatalog.swift)、[ShortcutStore.swift](../AreaChain/Services/ShortcutStore.swift) | 可重设组合、默认值和冲突只在目录里决定。全局热键默认不绑定，只在打开浮层、剪贴板加今天、全局打开工作台和剪贴板历史之间互相占用；应用内命令单独占用。浮层与剪贴板加今天仍用原来的 UserDefaults 键，缺键表示未设置。方向键、空格、回车、Delete、Esc 和备注 ⌘Return 不进目录。 |

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

统一搜索 1B-2A 的纯领域查询契约：`ContentQueryParser` / `ContentQuery`（[结构](../AreaChain/Domain/ContentQuery.swift)、[解析](../AreaChain/Domain/ContentQueryParser.swift)）、`ContentQueryDates`（[日期](../AreaChain/Domain/ContentQueryDates.swift)）、`ContentQueryScopeContract` / `ContentQueryApplicability`（[范围与字段](../AreaChain/Domain/ContentQueryScope.swift)）。由 `ContentQueryTests` / `ContentQueryContractTests` 及下述 1B-2B reducer 和测试消费；复用 CommandPath、TagSyntax、DayKey、PriorityToken 与提醒规则，没有接 BoardSearch 或真实提供者。来源与边界见[权威设计第 9.8 节](unified-search-commands.md#98-阶段-1b-2a内容查询语法范围与日期契约)。

统一搜索 1B-2B 新增 [ContentQueryPageContext / Mapping](../AreaChain/Domain/ContentQueryPageContext.swift)、[ContentQueryCondition](../AreaChain/Domain/ContentQueryCondition.swift)、[ContentQuerySession / Event / Intent](../AreaChain/Domain/ContentQuerySession.swift)、[ContentQueryReducer](../AreaChain/Domain/ContentQueryReducer.swift) 与 [PageProjection](../AreaChain/Domain/ContentQueryPageProjection.swift)。复用既有解析、范围、日期、BoardFilter 和 ItemsListing 枚举，只由三份对应 Domain 测试消费；原始文本、条件来源、访问寿命与 extended 投影不能通过旧 BoardFilter 有损往返。没有生产页面、操作草稿或执行接线；提供者要求和 partial 验收见[权威设计第 9.9 节](unified-search-commands.md#99-阶段-1b-2b页面查询上下文与纯状态转移)。

统一搜索 1C-1 的 [CommandDraft / Stamp / Check](../AreaChain/Domain/CommandDraft.swift)、[CommandDraftTargets / Baseline](../AreaChain/Domain/CommandDraftTargets.swift)、[CommandDraftSession / Reducer](../AreaChain/Domain/CommandDraftSession.swift)、[CommandHostSession](../AreaChain/Domain/CommandHostSession.swift) 复用目录、参数和查询会话；新增真实消费者为 CommandDraftTests、CommandDraftProtectionTests、CommandHostSessionTests。固定目标、原值和版本保护仅在 Domain，正文只由操作参数持有；retained 可枚举恢复但不是执行队列。没有生产 UI、保存或隐私接线，1C 分阶段边界与 partial 证据见[权威设计第 9.10 节](unified-search-commands.md#910-阶段-1c-1操作草稿固定目标与编辑保护)。

统一搜索 1C-2 的 [CommandPlan / Item / Snapshot](../AreaChain/Domain/CommandPlan.swift)、[CommandPlanValidation](../AreaChain/Domain/CommandPlanValidation.swift)、[CommandPlanSemantics](../AreaChain/Domain/CommandPlanSemantics.swift)、[CommandExecutionContract](../AreaChain/Domain/CommandExecutionContract.swift) 和 [CommandExecutionRun](../AreaChain/Domain/CommandExecutionRun.swift) 经原 [CommandHostSession](../AreaChain/Domain/CommandHostSession.swift) 组合。复用原草稿、参数、固定目标与基线；显式转移所有权，retained 不自动入队。新消费者为 CommandPlanOwnershipTests / CommandPlanDependencyTests / CommandPlanMergeTests / CommandExecutionTests / CommandAtomicPlanTests；已有草稿、宿主、目录、参数和查询回归继续执行。纯状态协议不授予执行、事务、重试或撤销能力，全部目录仍 unwired；唯一契约与 partial 证据见[权威设计第 9.11 节](unified-search-commands.md#911-阶段-1c-2待执行计划依赖与纯生命周期协议)。

统一搜索 1C-3 的 [CommandHandoffCoordinator](../AreaChain/Domain/CommandHandoffCoordinator.swift) 和 [票据/所有权/宿主事件契约](../AreaChain/Domain/CommandHandoffContract.swift) 复用上述 HostSession、DraftSession、Plan、ExecutionRun 和 ContentQuerySession / Reducer。仅增加运行内唯一登记、双方原子接管、身份/引用迁移及冻结查询来源；没有窗口、执行器或权限持久化。实际消费者是 CommandHandoffTests / CommandHandoffIdentityTests / CommandHandoffBoundaryTests / ContentQueryHandoffTests；后续生产入口必须验证同一协调者的 lease，值副本不授予提交能力。资格、资源确认、源撤权与 partial 证据见[权威设计第 9.12 节](unified-search-commands.md#912-阶段-1c-3跨入口主动转交与唯一所有权)。
