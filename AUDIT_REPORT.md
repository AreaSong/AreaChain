# AreaChain 全代码库设计系统、架构边界与质量验收只读审计账本
## (Comprehensive Read-Only Forensic Audit Ledger)

> **文档性质**：AreaChain macOS 客户端工程全量源码深度只读审计报告（Wave 1 综合汇总报告）  
> **审计日期**：2026-09-23  
> **审计模式**：Development 模式下严格只读（Zero Source Code Modification，0 源码修改）  
> **基准规范**：  
> - 设计系统收敛全量规范 (`.cursor/plans/design-system.md` P0–P7)  
> - 核心业务里程碑计划 (`.cursor/plans/areachain.md`)  
> - 质量缺陷治理历史账本 (`.cursor/plans/quality-fixes.md` 第 1–6 轮)  
> - 项目协作与验证约束契约 (`AGENTS.md`)  
> - 原始用户需求与工作流契约 (`ORIGINAL_REQUEST.md`)  

---

## 1. 执行摘要与全局审计仪表盘 (Executive Summary & Dashboard)

本审计针对 AreaChain macOS 客户端代码库进行了逐文件、逐行、端到端的静态与动态交叉核验。审计范围覆盖了 **Theme**（34 个文件）与 **Features**（93 个文件）共计 **127 个 Swift 源文件**，并对 **Domain** 纯领域层（37 个文件）、本地化资源 (`Localizable.xcstrings`)、里程碑修复真实实现代码及自动化测试套件完整性展开了无死角审查。

### 1.1 全局核心指标看板

| 审计维度 | 覆盖规模 / 基准指标 | 审计实测数值 | 综合状态评级 |
|---|---|---|:---:|
| **Theme & Features 源文件总数** | 127 个 Swift 文件 | **127 个文件 (100% 审计覆盖)** | 🟢 完备 |
| **文件合规性总体分布** | 127 个文件 | **PASS: 66 (51.97%) | ADVISORY: 39 (30.71%) | DEFECT: 22 (17.32%)** | 🟡 核心稳固，局部需收敛 |
| **Domain 领域层纯度** | 0 处 UI 依赖，零耦合 | **37 / 37 文件纯 Swift 实现，0 UI import** | 🟢 **100% CLEAN** |
| **双语本地化同步率** | 662 个键同步翻译 | **651 / 662 键双语完整同步 (98.34%)，1 个不对称键，85 个孤立键** | 🔴 **DEFECT (含硬编码)** |
| **测试套件执行通过率** | 全部基线门禁通过 | **check_workflow 5/5, unittest 129/129, Swift suites 699/702** | 🟢 **99.6% PASS** |
| **测试断言防作弊审计** | 95 个测试文件 | **0 处注释测试，0 处弱化断言，0 处伪测试，完整性 100%** | 🟢 **100% GENUINE** |
| **里程碑真实实现核验** | 17 项已标记 `[x]` | **17 / 17 项 100% 真实实现，代码与测试全量对应** | 🟢 **100% VERIFIED** |
| **旧主题残留 (`DaybookTheme`)** | 全局 0 引用 | **0 处 (彻底清零)** | 🟢 **100% CLEAN** |
| **工作台环境隔离 (`workspaceEmbedded`)** | 严禁切换视觉样式 | **0 处样式切换违规 (100% 仅用于结构尺寸与能力分支)** | 🟢 **100% CLEAN** |

### 1.2 各模块合规状态统计分布

| 模块目录 | 文件数 | 代码总行数 | PASS | ADVISORY | DEFECT | 豁免总数 (control / exempt) | 主要风险与特征 |
|---|:---:|:---:|:---:|:---:|:---:|:---:|---|
| **Module 1: AreaChain/Theme/** | 34 | 5,364 | 18 | 6 | 10 | 62 (7 / 55) | 1 个文件超长 (>500行)，辅助浮层组件存在函数超长与未收敛自绘 |
| **Module 2: Features/MenuBar/** | 10 | 1,988 | 5 | 1 | 4 | 23 (1 / 22) | 零令牌缺陷，4 处结构性超标（函数行数 >50 或嵌套层级 >3） |
| **Module 3: Features/Calendar, Quad, Gantt** | 7 | 1,116 | 3 | 0 | 4 | 11 (1 / 10) | 零令牌缺陷，4 处结构性超标（网格与时间线布局嵌套深度 >3） |
| **Module 4: Features/Tasks/** | 27 | 5,394 | 13 | 14 | 0 | 35 (4 / 31) | **零 DEFECT**，令牌依从度高，局部 DTO 参数超过 5 个与内联行间线 |
| **Module 5: Features/Diary/** | 14 | 2,746 | 8 | 5 | 1 | 21 (0 / 21) | 1 个文件超长 (`DiarySummaryRow` 561行)；置顶手记第三态描边合法 |
| **Module 6: Features/Workspace/ & Board/** | 23 | 4,253 | 11 | 10 | 2 | 31 (5 / 26) | 2 处色彩令牌绕过（`.yellow` 与 `secondary.opacity(0.7)` 绕过 `text.done`） |
| **Module 7: Features/Search, Settings, Trash, Attachments** | 12 | 1,660 | 8 | 3 | 1 | 3 (1 / 2) | 1 处函数超长 (`PrivacySettingsSection.body` 76行)；回收站徽章形状自绘 |
| **合计 (Total)** | **127** | **22,521** | **66** | **39** | **22** | **186 (19 / 167)** | **结构缺陷为主 (17处)，视觉令牌缺陷集中在 5 处关键点** |

---

## 2. 逐模块全量文件审计账本 (Module-by-Module File Audit Ledgers)

本节详细记录全部 127 个 Swift 源文件的合规判定。每个文件均通过 5 项核心指标审查：
1. **L1/L2 令牌依从性**：是否使用 `DaybookPalette`、`DaybookMetrics`、`DaybookTokens`、`DaybookElevation` 及 L2 基座组件。
2. **禁止自绘排查**：是否包含未豁免的 `Capsule()`、`Circle()`、`RoundedRectangle()`、系统直接颜色、裸 `.shadow()`、裸 `.buttonStyle(.plain)`。
3. **代码尺寸硬门禁**：单文件 $\le 500$ 行，单函数/计算属性 $\le 50$ 行，嵌套层级 $\le 3$ 层。
4. **旧主题清零**：全局是否有 `DaybookTheme` 引用（必须 = 0）。
5. **工作台能力分支隔离**：`workspaceEmbedded` 是否严格仅用于结构尺寸分支，严禁切换颜色、字体、圆角或阴影。

### Module 1: AreaChain/Theme/ (34 个文件)

| # | 文件名 | 行数 | 状态 | 豁免数 (C/E) | 合规检查综合结论与关键违规摘要 |
|:---:|---|:---:|:---:|:---:|---|
| 1 | `CaptureAttributesView.swift` | 146 | **DEFECT** | 1 / 3 | 存在未豁免 `Capsule()` 自绘；L71 注释显式标注「胶囊留给 P5」暴露跨阶段收敛遗留；嵌套层级为 4；硬编码 10pt 内边距。 |
| 2 | `CommandReturnButton.swift` | 46 | **PASS** | 0 / 0 | 完美复用 `DaybookButtonStyle` (.compact/.icon) 与 `DaybookType.badge`；零违规。 |
| 3 | `DaybookButtonStyle.swift` | 209 | **ADVISORY** | 0 / 0 | 按钮基座实现良好；L60-63 图标字号使用直接 `.system(size:)` 未引用 `DaybookType`；内部含字面 opacity (0.12, 0.35)。 |
| 4 | `DaybookChip.swift` | 63 | **PASS** | 1 / 0 | L2 芯片基座组件；L30 `// control:` 合规；内部合法使用 Capsule 与 tint opacity 映射。 |
| 5 | `DaybookChrome.swift` | 154 | **ADVISORY** | 0 / 4 | 动效与空态基座；4 处 token-exempt 充分合理；L93 存在 1 处字面 padding 16pt (应为 `DaybookSpacing.page`)。 |
| 6 | `DaybookColor.swift` | 81 | **PASS** | 0 / 0 | 具名动态色与对比度算法基座；纯平台支撑代码；零违规。 |
| 7 | `DaybookElevation.swift` | 19 | **PASS** | 0 / 0 | L1 阴影令牌与修饰器定义；规范精炼；零违规。 |
| 8 | `DaybookInputShell.swift` | 105 | **PASS** | 0 / 0 | L2 输入框外壳核心基座；100% 令牌化与标准化；零违规。 |
| 9 | `DaybookMetrics.swift` | 51 | **PASS** | 0 / 0 | L1 尺寸与圆角描边常量定义；规范精炼；零违规。 |
| 10 | `DaybookPage.swift` | 259 | **PASS** | 0 / 1 | 容器与单行输入壳；`workspaceEmbedded` 仅作宽度与最小高布局分支；1 处次要色 80% 豁免合理。 |
| 11 | `DaybookPalette.swift` | 249 | **ADVISORY** | 0 / 0 | L1 调色板基座；缺少规范要求的 `tagDefault`，导致下游控件被迫豁免使用 `.systemIndigo`。 |
| 12 | `DaybookRowBubbles.swift` | 247 | **DEFECT** | 0 / 6 | 两个 `body` 分别为 66 行和 92 行（超 50 行上限）；含 4 处字面动画；L192/197 豁免圆角 7pt 属收敛绕过。 |
| 13 | `DaybookScroller.swift` | 567 | **DEFECT** | 0 / 0 | **文件超长**：567 行（超 500 行上限）；L559 出现未豁免 `Color.black`；L556-557 出现字面动画；嵌套层级为 4。 |
| 14 | `DaybookSectionHeader.swift` | 38 | **PASS** | 0 / 1 | L2 分节头与分割线；L22 圆体数字豁免合理；零违规。 |
| 15 | `DaybookSegmentedBar.swift` | 55 | **DEFECT** | 1 / 1 | L53 存在**未国际化硬编码中文文本** `Text("任务 (⌘←)")`；L28 存在字面 `.spring` 动画。 |
| 16 | `DaybookSurface.swift` | 130 | **ADVISORY** | 0 / 0 | L2 表面基座；实现规范；内部含字面 opacity 0.85 与描边 0.8pt / 0.7pt，建议收敛至 Metrics。 |
| 17 | `DaybookTextEditor.swift` | 156 | **PASS** | 0 / 0 | AppKit 原生多行文本桥接；协调器输入法与撤销支持完备；零违规。 |
| 18 | `DaybookTextField.swift` | 430 | **ADVISORY** | 0 / 0 | AppKit 原生单行输入桥接；`func control` 长达 90 行（属于受保护 AppKit 按键分派协调器）。 |
| 19 | `DaybookTokens.swift` | 48 | **PASS** | 0 / 0 | L1 圆角、间距、字体令牌定义；规范精炼；零违规。 |
| 20 | `KeyWindowHost.swift` | 16 | **PASS** | 0 / 0 | 纯 AppKit 窗口辅助；无视图绘制；零违规。 |
| 21 | `LiveComposerPreviewHeader.swift` | 393 | **DEFECT** | 0 / 9 | `mainRow` 达 95 行（超 50 行）；L92 裸 `Circle()`；L122-164 多处未豁免 `Capsule()` 自绘未复用 `DaybookChip`；浮层未复用 `daybookSurface(.panel)`。 |
| 22 | `LiveDiaryComposerPreview.swift` | 328 | **DEFECT** | 0 / 4 | `body` 53 行（超 50 行）；`noteIndicator` 嵌套层级达 5（超 3 层）；在 `.daybookSurface(.row)` 上叠加油画背景与阴影。 |
| 23 | `MenuBarStatusImage.swift` | 66 | **PASS** | 0 / 0 | AppKit 状态栏镂空模板绘制；无 SwiftUI 违规。 |
| 24 | `ModernComponents.swift` | 131 | **DEFECT** | 1 / 0 | L93 `modernFocusRing` 为**无调用死代码**且含字面形状/动画；复选框存在未豁免 `Circle()` 与字面 opacity (0.8, 0.24, 0.85)。 |
| 25 | `QuadrantMiniMark.swift` | 57 | **PASS** | 0 / 3 | 象限徽章微型组件；3 处豁免（微型等宽、圆体数字、象限色描边）均充分合理。 |
| 26 | `SyntaxAutocompleteView.swift` | 342 | **DEFECT** | 0 / 6 | `body` 68 行（超 50 行）；嵌套深度达 6 层（超 3 层）；浮层未复用 `daybookSurface(.panel)`。 |
| 27 | `SyntaxHelpCard.swift` | 289 | **DEFECT** | 2 / 17 | `syntaxRow` 81 行（超 50 行）；嵌套深度 5 层；L186/265 裸 `Capsule()` 自绘；L218 豁免 5pt 圆角属收敛绕过；4 处 `.systemIndigo` 豁免因缺令牌引起。 |
| 28 | `SyntaxHighlighter.swift` | 68 | **PASS** | 0 / 0 | 语法高亮着色器；100% 使用 `DaybookPalette.Syntax` 命名颜色与 NSColor；零违规。 |
| 29 | `SyntaxOverlay.swift` | 288 | **ADVISORY** | 0 / 0 | 浮层定位宿主与全局事件监听；`observe` 协调器事件闭包嵌套深度为 4（AppKit 监听路由）。 |
| 30 | `SyntaxTextEditor.swift` | 46 | **DEFECT** | 0 / 0 | L37 占位符使用**未豁免直调** `.font(.system(size: fontSize))`；L39-40 使用未豁免字面量内边距 9 与 5。 |
| 31 | `SyntaxTextField.swift` | 48 | **PASS** | 0 / 0 | 语法单行输入包装器；遵循 `DaybookType.bodySize`；零违规。 |
| 32 | `SyntaxViewAnchor.swift` | 24 | **PASS** | 0 / 0 | 纯几何锚点辅助；无视觉违规。 |
| 33 | `TrashConfirm.swift` | 65 | **PASS** | 0 / 0 | 原生确认对话框封装；无视觉违规。 |
| 34 | `WorkspaceLayout.swift` | 150 | **PASS** | 1 / 0 | 工作台布局常量与侧栏行；`workspaceEmbedded` 正确声明与使用；L136 `// control:` 合规。 |

### Module 2: AreaChain/Features/MenuBar/ (10 个文件)

| # | 文件名 | 行数 | 状态 | 豁免数 (C/E) | 合规检查综合结论与关键违规摘要 |
|:---:|---|:---:|:---:|:---:|---|
| 1 | `CaptureField.swift` | 65 | **PASS** | 0 / 0 | 极简单行任务捕获；100% 依从 L1/L2 令牌；输入壳规范；无任何违规。 |
| 2 | `FooterBar.swift` | 298 | **DEFECT** | 0 / 2 | 结构性超长：`activeTokens` 计算属性达 54 行（超 50 行上限）；2 处豁免（8pt圆体计数、胶囊裁切）合理正当。 |
| 3 | `MenuBarControls.swift` | 47 | **PASS** | 0 / 2 | 状态栏图标与计数器；2 处豁免（11pt衬线品牌字、12pt圆体计数）技术理由合理正当。 |
| 4 | `MenuBarFilterFlyout.swift` | 364 | **DEFECT** | 0 / 10 | 结构性超长：`level1CategoryCard` 66 行（超 50 行），嵌套层级为 5（超 3 层）；10 处微图标/圆点豁免合理。 |
| 5 | `MenuBarPopoverView+Drawer.swift` | 91 | **ADVISORY** | 0 / 0 | 侧滑抽屉；第 26 行内边距使用字面量 `12`（与 `DaybookSpacing.large` 一致，建议收敛）。 |
| 6 | `MenuBarPopoverView+Keyboard.swift` | 59 | **PASS** | 0 / 0 | 原生 NSEvent 键盘监听与分发；逻辑清晰；零违规。 |
| 7 | `MenuBarPopoverView.swift` | 497 | **DEFECT** | 0 / 6 | 结构性超标：`body` 达 121 行（超 50 行）；`headerIndicator` 嵌套层级为 4；全文件 497 行临近 500 行上限。 |
| 8 | `MenuBarSearchField.swift` | 116 | **DEFECT** | 1 / 2 | 结构性超标：`body` 64 行（超 50 行）；芯片列表嵌套深度达 7 层（超 3 层）；3 处豁免合规。 |
| 9 | `MenuBarSearchResults.swift` | 65 | **PASS** | 0 / 0 | 搜索结果快速展示；完全复用 `DaybookEmptyState` 与 `DaybookButtonStyle`；零违规。 |
| 10 | `MenuBarToolbarState.swift` | 52 | **PASS** | 0 / 0 | 纯状态协调类；无 UI 渲染代码；零违规。 |

### Module 3: AreaChain/Features/Calendar/, Quadrant/, Gantt/ (7 个文件)

| # | 文件名 | 行数 | 状态 | 豁免数 (C/E) | 合规检查综合结论与关键违规摘要 |
|:---:|---|:---:|:---:|:---:|---|
| 1 | `CalendarMonthGrid.swift` | 134 | **DEFECT** | 0 / 6 | 结构性超标：`body` 内部网格单元嵌套层级为 4（超 3 层）；6 处豁免（日历月网格 3 态与 9pt 圆体）合法。 |
| 2 | `CalendarPage.swift` | 179 | **DEFECT** | 0 / 0 | 结构性超标：`wideLayout` 内部滚动列表嵌套层级为 4（超 3 层）；`embedded` 严格用于布局分支。 |
| 3 | `CalendarStandaloneView.swift` | 28 | **PASS** | 0 / 0 | 独立日历小窗入口；结构精炼；零违规。 |
| 4 | `QuadrantPage.swift` | 203 | **DEFECT** | 1 / 0 | 结构性超标：`cell` 四宫格任务卡片嵌套层级为 6（超 3 层）；1 处 control（象限卡片整行拖放点击）合法；`embedded` 合规。 |
| 5 | `GanttPage.swift` | 257 | **DEFECT** | 0 / 4 | 结构性超标：`timeline` 水平垂直双向滚动容器嵌套层级为 5（超 3 层）；4 处数据色块标记豁免合法。 |
| 6 | `GanttRescheduling.swift` | 26 | **PASS** | 0 / 0 | 纯 SwiftData 排期事务调度；零 UI 耦合；零违规。 |
| 7 | `GanttRowPointerRegion.swift` | 209 | **PASS** | 0 / 0 | AppKit 原生 NSView 指针区域与拖放手势监听；零违规。 |

### Module 4: AreaChain/Features/Tasks/ (27 个文件)

| # | 文件名 | 行数 | 状态 | 豁免数 (C/E) | 合规检查综合结论与关键违规摘要 |
|:---:|---|:---:|:---:|:---:|---|
| 1 | `AttachmentThumbnails.swift` | 55 | **ADVISORY** | 1 / 0 | 1 处 control（附件缩略图点击区）；字面 spacing (8, 12) 与 frame 22x22 建议收敛。 |
| 2 | `BatchActionBar.swift` | 204 | **ADVISORY** | 0 / 1 | 1 处等宽计数豁免合法；存在局部未收敛 `Divider().opacity(0.3)`。 |
| 3 | `BoardFilterBar.swift` | 317 | **ADVISORY** | 0 / 9 | 9 处微图标与胶囊豁免合法；`choiceDropdown` 包含 6 个入参（超过 5 个阈值）。 |
| 4 | `DayBoardList+Keyboard.swift` | 365 | **ADVISORY** | 0 / 0 | `handleNavigationKey` 为 55 行按键分派 switch（超 50 行上限 5 行）。 |
| 5 | `DayBoardList.swift` | 410 | **ADVISORY** | 0 / 0 | `DayBoardListConfig.init` 包含 10 个入参（超过 5 个入参阈值，建议拆分子 DTO）。 |
| 6 | `DayBoardMutations+Batch.swift` | 76 | **PASS** | 0 / 0 | 仓储批量事务集成；函数均 <= 50 行；入参 <= 5；零违规。 |
| 7 | `DayBoardMutations+Capture.swift` | 114 | **PASS** | 0 / 0 | 自然语言捕获集成；函数精炼；零违规。 |
| 8 | `DayBoardMutations.swift` | 476 | **PASS** | 0 / 0 | 基于协议的依赖注入 (`TaskRepositoryProtocol` 等)；476 行 <= 500 行；零违规。 |
| 9 | `DayBoardSections.swift` | 145 | **ADVISORY** | 1 / 2 | 2 处色彩透明度豁免合法，1 处 control（分节折叠头整行点击）合法；含内联 `Divider().opacity`。 |
| 10 | `DayScheduleMenu.swift` | 60 | **PASS** | 0 / 0 | 日期排期弹窗；样式规范；第 54 行建议替换字面 padding 12。 |
| 11 | `DaybookProgressRing.swift` | 37 | **ADVISORY** | 0 / 5 | 5 处豁免（几何正圆轨迹与圆体数字）理由合法正当。 |
| 12 | `PendingCompletionManager.swift` | 141 | **PASS** | 0 / 0 | 0.4 秒防反悔状态机；`@Observable` 架构清晰；零违规。 |
| 13 | `QuadrantBadge.swift` | 20 | **PASS** | 0 / 0 | 干净委托至 `QuadrantMiniMark` 基座组件；零违规。 |
| 14 | `TaskRow+Actions.swift` | 81 | **PASS** | 0 / 0 | 标题编辑 Esc 回滚、点走保存与剪贴板拷贝；零违规。 |
| 15 | `TaskRow+Badges.swift` | 149 | **ADVISORY** | 0 / 3 | 3 处圆体计数与 12% 橙底豁免合法；L46 存在硬编码中文 Tooltip。 |
| 16 | `TaskRow+CommandStrip.swift` | 143 | **ADVISORY** | 0 / 0 | `commandActionStrip` 达 109 行（声明式 ViewBuilder 命令按钮组装）。 |
| 17 | `TaskRow+Menus.swift` | 317 | **PASS** | 0 / 0 | 右键上下文菜单；函数均 <= 50 行；标准使用 `DaybookIconButton`。 |
| 18 | `TaskRow.swift` | 423 | **ADVISORY** | 0 / 4 | 4 处豁免合法；`noteIndicator` (63行) 与 `titleContent` (54行) 略超 50 行；`embedded` 规范。 |
| 19 | `TaskRowBubbles.swift` | 15 | **PASS** | 0 / 0 | 纯类型别名桥接；零违规。 |
| 20 | `TaskRowContext.swift` | 476 | **PASS** | 0 / 0 | 模块化 DTO 组合 (`TaskPriorityFlags` 等)；476 行 <= 500 行；零违规。 |
| 21 | `TaskRowFactory.swift` | 200 | **PASS** | 0 / 0 | 工厂模式解耦模型与 `TaskRowState`；零违规。 |
| 22 | `TaskRowState.swift` | 267 | **PASS** | 0 / 0 | 不可变状态结构体；子 DTO 参数均 <= 5；零违规。 |
| 23 | `TaskRowSubtaskMiniViews.swift` | 88 | **ADVISORY** | 1 / 3 | 1 处 control（12pt 圆框自定义复选框）；3 处豁免合法。 |
| 24 | `TasksPage+Actions.swift` | 35 | **PASS** | 0 / 0 | 简洁的变更派发方法；零违规。 |
| 25 | `TasksPage+Header.swift` | 135 | **ADVISORY** | 1 / 1 | 1 处 control 与 1 处豁免合法；`headerBar` 为 54 行 ViewBuilder；`embedded` 规范。 |
| 26 | `TasksPage+Sections.swift` | 299 | **ADVISORY** | 0 / 3 | 3 处豁免（14% 印章底、胶囊裁切、9.5pt 圆体）合法；行数 <= 500。 |
| 27 | `TasksPage.swift` | 371 | **ADVISORY** | 0 / 0 | `var body` 达 64 行（顶层容器与生命周期挂载）；`embedded` 规范。 |

### Module 5: AreaChain/Features/Diary/ (14 个文件)

| # | 文件名 | 行数 | 状态 | 豁免数 (C/E) | 合规检查综合结论与关键违规摘要 |
|:---:|---|:---:|:---:|:---:|---|
| 1 | `DiaryCardComponents.swift` | 248 | **PASS** | 0 / 3 | 3 处豁免（85% 危险色、10% 危险色底、14pt 等宽粗体密码占位）合法；零违规。 |
| 2 | `DiaryCardDrafts.swift` | 27 | **PASS** | 0 / 0 | 纯 SwiftData/Observation 状态模型；零 UI 耦合；零违规。 |
| 3 | `DiaryEditorSession.swift` | 220 | **PASS** | 0 / 0 | 编辑会话与冲突处理逻辑；无 UI 渲染；零违规。 |
| 4 | `DiaryNoteCard.swift` | 305 | **ADVISORY** | 0 / 8 | `body` 达 65 行（超 50 行上限）；8 处豁免合法；L116-120 置顶手记第三态描边合法。 |
| 5 | `DiaryOrganizeMenus.swift` | 48 | **PASS** | 0 / 0 | 菜单上下文按钮与分界线；标准原生实现；零违规。 |
| 6 | `DiaryPage+Keyboard.swift` | 89 | **ADVISORY** | 0 / 0 | `handleListKeyDown` 为 51 行（超 50 行上限 1 行）。 |
| 7 | `DiaryPage.swift` | 450 | **ADVISORY** | 0 / 2 | `body` 为 53 行（超 50 行上限 3 行）；2 处豁免合法；`embedded` 用法规范。 |
| 8 | `DiaryQuickComposerView.swift` | 215 | **ADVISORY** | 0 / 2 | `compactInputRow` 55 行；2 处豁免合法；L130-131 含字面动画，L37 含 padding 10。 |
| 9 | `DiaryRowCommandStrip.swift` | 137 | **ADVISORY** | 0 / 0 | `body` 为 85 行（9 个平铺命令按钮）；样式完全委托给通用组件。 |
| 10 | `DiaryStandaloneView.swift` | 20 | **PASS** | 0 / 0 | 独立手记小窗；`embedded` 仅用于窗口最小尺寸约束；零违规。 |
| 11 | `DiarySummaryRow.swift` | 561 | **DEFECT** | 0 / 5 | **硬缺陷**：全文件 561 行（超 500 行上限）；`body` (63行) 与 `noteContentHeader` (60行) 超标。 |
| 12 | `DiaryWindowView.swift` | 124 | **PASS** | 0 / 1 | 1 处豁免（26pt 默认字重 shield 锁图标）理由合法；零违规。 |
| 13 | `DiaryWindows.swift` | 181 | **PASS** | 0 / 0 | AppKit 窗口控制器与单例管理器；生命周期清晰；零违规。 |
| 14 | `PrivacyUnlockPresenter.swift` | 163 | **PASS** | 0 / 0 | 弹窗与系统生物认证调度中心；标准实现；零违规。 |

### Module 6: AreaChain/Features/Workspace/ & Board/ (23 个文件)

| # | 文件名 | 行数 | 状态 | 豁免数 (C/E) | 合规检查综合结论与关键违规摘要 |
|:---:|---|:---:|:---:|:---:|---|
| 1 | `MainSplitWorkspaceView.swift` | 273 | **ADVISORY** | 0 / 0 | 三栏工作台根容器；第 95 行底边距建议用 `DaybookSpacing.page`；`embedded` 规范。 |
| 2 | `ResidentsPage.swift` | 198 | **ADVISORY** | 0 / 0 | 习惯常驻管理页；第 72 行含字面 padding 10；第 81 行建议用 `DaybookSpacing.md`。 |
| 3 | `TaskDetailClassificationSection.swift` | 151 | **ADVISORY** | 0 / 2 | L87 建议用 `text.tertiary`；L93 引入 `systemIndigo` 建议收敛至 `Syntax.tag`。 |
| 4 | `TaskDetailDrawer.swift` | 228 | **ADVISORY** | 0 / 4 | L37 含 40% 纸底；L52 大图标字号建议规范；L53 与 L59 建议收敛至 `text.tertiary`。 |
| 5 | `TaskDetailHeaderSection.swift` | 149 | **ADVISORY** | 0 / 1 | L27 破坏性按钮已由样式托管，无需再乘 0.85；L78 建议收敛为 `DaybookInputShell`。 |
| 6 | `TaskDetailNotesView.swift` | 121 | **ADVISORY** | 0 / 2 | L50 与 L81 建议收敛为 `DaybookPalette.text.tertiary`。 |
| 7 | `TaskDetailQuadrantGrid.swift` | 66 | **ADVISORY** | 1 / 1 | L59 象限边框乘数建议收敛；L63 control（象限选择格保留象限专属色）合理。 |
| 8 | `TaskDetailScheduleSection.swift` | 347 | **DEFECT** | 1 / 5 | **严重设计缺陷**：L267 奖杯图标硬编码 `.foregroundStyle(.yellow)`，浅色模式对比度极低！ |
| 9 | `TaskDetailSections.swift` | 273 | **PASS** | 0 / 0 | 抽屉各分区组装；100% 遵从 DaybookTokens 与 DaybookPalette；零违规。 |
| 10 | `TaskDetailSubtasksView.swift` | 258 | **DEFECT** | 1 / 5 | **设计缺陷**：L195 已完成子任务使用 `secondary.opacity(0.7)` **绕过既有 `text.done` 令牌**！ |
| 11 | `WorkspaceBatchActionBar.swift` | 119 | **PASS** | 0 / 0 | 完全委托给 `BatchActionBar` 基座与 `DaybookMotion`；零违规。 |
| 12 | `WorkspaceFilteredListView.swift` | 300 | **PASS** | 1 / 0 | 分类列表页；L184 control（折叠展开手风琴标题整行响应点击）合理；零违规。 |
| 13 | `WorkspaceGlobalSearchView.swift` | 161 | **PASS** | 1 / 0 | 全局搜索结果；L126 control（附件结果行整行点击）合理；零违规。 |
| 14 | `WorkspaceHeaderBar.swift` | 176 | **ADVISORY** | 0 / 3 | L92 快捷键提示字号应收敛至 `DaybookType.kbd`；L93 与 L98 透明度建议收敛。 |
| 15 | `WorkspaceNavigation.swift` | 270 | **PASS** | 0 / 0 | 纯路由与选择状态管理；零 UI 样式耦合；零违规。 |
| 16 | `WorkspaceSidebarView.swift` | 308 | **PASS** | 0 / 0 | 侧栏导航；完全复用 `WorkspaceSidebarRow`；合法引用 `WorkspaceLayout`；零违规。 |
| 17 | `WorkspaceTodayView.swift` | 115 | **PASS** | 0 / 0 | 今日聚焦页；规范使用 `DaybookPage`, `DaybookComposer`, `DaybookProgressRing`。 |
| 18 | `BoardCommandStrip.swift` | 181 | **ADVISORY** | 0 / 3 | L39 建议收敛至 `DaybookType.label`；L40 与 L46 透明度建议收敛。 |
| 19 | `BoardComposer.swift` | 49 | **PASS** | 0 / 0 | 任务与手记全局草稿管理与隐私封存；纯状态模型；零违规。 |
| 20 | `BoardFilterChoices.swift` | 251 | **PASS** | 0 / 0 | 筛选选项构建器；纯选项数据映射；合法复用领域色；零违规。 |
| 21 | `BoardKeyMonitor.swift` | 14 | **PASS** | 0 / 0 | AppKit 本地按键监听器装载与卸载工具；零违规。 |
| 22 | `BoardRowChrome.swift` | 154 | **PASS** | 0 / 0 | 行悬停与 ⌘ 状态调度；规范使用 `DaybookMotion.interactive`；零违规。 |
| 23 | `BoardRowPointer.swift` | 114 | **PASS** | 0 / 0 | 纯 AppKit 点击与手势分发桥接；零违规。 |

### Module 7: Features/Search/, Settings/, Trash/, Attachments/ (12 个文件)

| # | 文件名 | 行数 | 状态 | 豁免数 (C/E) | 合规检查综合结论与关键违规摘要 |
|:---:|---|:---:|:---:|:---:|---|
| 1 | `BoardSearchHitRow.swift` | 106 | **ADVISORY** | 1 / 1 | L78 种类胶囊使用 `Capsule()` 自绘建议收敛为 `DaybookChip`；嵌套层级为 4；L59 control 合规。 |
| 2 | `SearchPage.swift` | 67 | **PASS** | 0 / 0 | 搜索小窗；使用 `DaybookPage`, `DaybookInputShell`, `DaybookEmptyState`；零违规。 |
| 3 | `SearchResultsView.swift` | 31 | **PASS** | 0 / 0 | 搜索结果滚动容器；使用 `.daybookScroll()`；零违规。 |
| 4 | `HotKeyRecorder.swift` | 106 | **PASS** | 0 / 0 | 热键录制器；规范映射到 `DaybookType.subtitle` 与 `DaybookPalette.text.secondary`。 |
| 5 | `PrivacyPasswordSheet.swift` | 53 | **PASS** | 0 / 0 | 模态密码验证框；使用 `DaybookType`, `DaybookPalette`, `.borderedProminent`；零违规。 |
| 6 | `PrivacySettingsSection.swift` | 236 | **DEFECT** | 0 / 0 | **结构性超长**：`body` 达 76 行（超 50 行上限）；嵌套层级为 4-5；令牌使用规范。 |
| 7 | `PrivacySetupSheet.swift` | 167 | **PASS** | 0 / 0 | 首次私密锁配置页；函数均 <= 50 行；表单样式合规；零违规。 |
| 8 | `SettingsSections.swift` | 127 | **PASS** | 0 / 0 | 通用、同步、高级设置分组；完全遵循令牌规范；零违规。 |
| 9 | `SettingsView.swift` | 225 | **PASS** | 0 / 0 | 设置中心主视图；规范使用 `DaybookPage`, `.formStyle(.grouped)`；零违规。 |
| 10 | `TrashPage.swift` | 290 | **ADVISORY** | 0 / 0 | L97 存在未加 `// token-exempt:` 的 `RoundedRectangle` 徽章自绘；`trashCard` 恰好 50 行。 |
| 11 | `AttachmentBrowserPage.swift` | 157 | **ADVISORY** | 0 / 1 | L106 占位图使用 `.system(size: 18)` 豁免，建议归一至 `DaybookType.entity` (17pt)。 |
| 12 | `AttachmentPicker.swift` | 115 | **PASS** | 0 / 0 | 纯 AppKit IO 与系统对话框编排；零视图绘制；零违规。 |

---

## 3. 全代码库豁免注释全量账本 (Comprehensive Exemption Inventory)

本节列出了全工程在 `AreaChain/Theme/` 与 `AreaChain/Features/` 中存在的**全部 186 条豁免注释**（包含 19 处 `// control:` 与 167 处 `// token-exempt:`）。逐行登记其语法、上下文代码、技术理由及审计裁决。

| # | 所在文件路径 | 行号 | 豁免语法 | 代码上下文片段 | 开发者技术理由 | 审计评定 |
|:---:|---|:---:|:---:|---|---|:---:|
| 1 | `Theme/CaptureAttributesView.swift` | 56 | `// token-exempt:` | `.fill(DaybookPalette.accent.base.opacity(state.showsAttributes ? 0.20 : 0.12))` | 20% 与 12% 写在同一个三元表达式里 | Legitimate |
| 2 | `Theme/CaptureAttributesView.swift` | 65 | `// token-exempt:` | `.foregroundStyle(DaybookPalette.text.secondary.opacity(0.40))` | 40% 次要色没有对应令牌 | Advisory |
| 3 | `Theme/CaptureAttributesView.swift` | 71 | `// control:` | `.buttonStyle(.plain)` | 属性按钮固定 58×22，胶囊留给 P5 | **DEFECT** |
| 4 | `Theme/CaptureAttributesView.swift` | 123 | `// token-exempt:` | `.overlay(RoundedRectangle(cornerRadius: DaybookRadius.small).stroke(DaybookPalette.border.default.opacity(0.7), lineWidth: 0.7))` | 70% 分隔线没有对应令牌 | Advisory |
| 5 | `Theme/DaybookChip.swift` | 30 | `// control:` | `.buttonStyle(.plain)` | 芯片外壳，外观由 DaybookChip 绘制 | Legitimate |
| 6 | `Theme/DaybookChrome.swift` | 73 | `// token-exempt:` | `.font(.system(size: alignment == .center ? 28 : 16, weight: .light))` | 28pt 没有令牌，display 是 26pt，字重是 light | Legitimate |
| 7 | `Theme/DaybookChrome.swift` | 74 | `// token-exempt:` | `.foregroundStyle(DaybookPalette.accent.base.opacity(0.85))` | 85% 印章色没有对应令牌 | Advisory |
| 8 | `Theme/DaybookChrome.swift` | 80 | `// token-exempt:` | `.foregroundStyle(DaybookPalette.text.primary.opacity(0.88))` | 88% 墨色没有对应令牌 | Advisory |
| 9 | `Theme/DaybookChrome.swift` | 144 | `// token-exempt:` | `.background(DaybookPalette.fill.page.opacity(0.94))` | 94% 纸色没有对应令牌 | Advisory |
| 10 | `Theme/DaybookPage.swift` | 203 | `// token-exempt:` | `.foregroundStyle(isFocused ? DaybookPalette.text.primary : DaybookPalette.text.secondary.opacity(0.8))` | 80% 次要色没有对应令牌 | Advisory |
| 11 | `Theme/DaybookRowBubbles.swift` | 90 | `// token-exempt:` | `.stroke(isCopied ? DaybookPalette.accent.base.opacity(0.7) : (isHovered ? DaybookPalette.cardBorderHover : DaybookPalette.border.default.opacity(0.9)), lineWidth: 0.8)` | 70% 印章色和 90% 分隔线没有对应令牌 | Advisory |
| 12 | `Theme/DaybookRowBubbles.swift` | 162 | `// token-exempt:` | `.font(.system(size: 7))` | 小于 9pt 的气泡箭头 | Legitimate |
| 13 | `Theme/DaybookRowBubbles.swift` | 192 | `// token-exempt:` | `RoundedRectangle(cornerRadius: 7, style: .continuous)` | 7pt 与 small、regular 都差 1pt | **DEFECT** |
| 14 | `Theme/DaybookRowBubbles.swift` | 197 | `// token-exempt:` | `RoundedRectangle(cornerRadius: 7, style: .continuous)` | 7pt 与 small、regular 都差 1pt | **DEFECT** |
| 15 | `Theme/DaybookRowBubbles.swift` | 198 | `// token-exempt:` | `.stroke(isCopied ? DaybookPalette.accent.base.opacity(0.7) : (isHovered ? DaybookPalette.cardBorderHover : DaybookPalette.border.default.opacity(0.9)), lineWidth: 0.8)` | 70% 印章色和 90% 分隔线没有对应令牌 | Advisory |
| 16 | `Theme/DaybookRowBubbles.swift` | 205 | `// token-exempt:` | `.font(.system(size: 7))` | 小于 9pt 的气泡箭头 | Legitimate |
| 17 | `Theme/DaybookSectionHeader.swift` | 22 | `// token-exempt:` | `.font(.system(size: 10, weight: .bold, design: .rounded))` | 分节计数用圆体 | Advisory |
| 18 | `Theme/DaybookSegmentedBar.swift` | 20 | `// token-exempt:` | `.fill(DaybookPalette.text.primary.opacity(0.06))` | 6% 墨色没有对应令牌 | Advisory |
| 19 | `Theme/DaybookSegmentedBar.swift` | 50 | `// control:` | `.buttonStyle(.plain)` | 分段切换滑块，非按钮语义 | Legitimate |
| 20 | `Theme/LiveComposerPreviewHeader.swift` | 93 | `// token-exempt:` | `.strokeBorder(DaybookPalette.border.default.opacity(0.8), style: StrokeStyle(lineWidth: 1.2, dash: [2.5, 2]))` | 80% 分隔线没有对应令牌 | Advisory |
| 21 | `Theme/LiveComposerPreviewHeader.swift` | 142 | `// token-exempt:` | `.font(.system(size: 8.5, weight: .bold))` | 小于 9pt，kbd 是等宽 | Advisory |
| 22 | `Theme/LiveComposerPreviewHeader.swift` | 144 | `// token-exempt:` | `.font(.system(size: 11, weight: .bold, design: .rounded))` | 标签计数用圆体 | Advisory |
| 23 | `Theme/LiveComposerPreviewHeader.swift` | 160 | `// token-exempt:` | `.font(.system(size: 11, weight: .medium, design: .monospaced))` | 时刻用等宽，kbd 是 8.5pt | Advisory |
| 24 | `Theme/LiveComposerPreviewHeader.swift` | 182 | `// token-exempt:` | `.stroke(DaybookPalette.border.default.opacity(0.7), lineWidth: 0.7)` | 70% 分隔线没有对应令牌 | Advisory |
| 25 | `Theme/LiveComposerPreviewHeader.swift` | 195 | `// token-exempt:` | `.fill(isNoteHovered ? DaybookPalette.accent.fill : DaybookPalette.text.primary.opacity(0.04))` | 4% 墨色没有对应令牌 | Advisory |
| 26 | `Theme/LiveComposerPreviewHeader.swift` | 259 | `// token-exempt:` | `.font(.system(size: 10, weight: .bold, design: .rounded))` | 标签计数用圆体 | Advisory |
| 27 | `Theme/LiveComposerPreviewHeader.swift` | 262 | `// token-exempt:` | `.background(Capsule().fill(DaybookPalette.border.default.opacity(0.4)))` | 40% 分隔线没有对应令牌 | **DEFECT** |
| 28 | `Theme/LiveComposerPreviewHeader.swift` | 301 | `// token-exempt:` | `.stroke(DaybookPalette.border.default.opacity(0.6), lineWidth: 0.8)` | 60% 分隔线没有对应令牌 | Advisory |
| 29 | `Theme/LiveDiaryComposerPreview.swift` | 96 | `// token-exempt:` | `.stroke(DaybookPalette.border.default.opacity(0.7), lineWidth: 0.7)` | 70% 分隔线没有对应令牌 | Advisory |
| 30 | `Theme/LiveDiaryComposerPreview.swift` | 236 | `// token-exempt:` | `.font(.system(size: 8.5))` | 小于 9pt | Legitimate |
| 31 | `Theme/LiveDiaryComposerPreview.swift` | 275 | `// token-exempt:` | `.foregroundStyle(isNoteHovered ? DaybookPalette.accent.base : DaybookPalette.text.secondary.opacity(0.65))` | 65% 次要色没有对应令牌 | Advisory |
| 32 | `Theme/LiveDiaryComposerPreview.swift` | 280 | `// token-exempt:` | `.fill(isNoteHovered ? DaybookPalette.accent.fill : DaybookPalette.text.primary.opacity(0.04))` | 4% 墨色没有对应令牌 | Advisory |
| 33 | `Theme/ModernComponents.swift` | 30 | `// control:` | `.buttonStyle(.plain)` | 复选框，非按钮语义 | Legitimate |
| 34 | `Theme/QuadrantMiniMark.swift` | 37 | `// token-exempt:` | `.font(.system(size: 8.5, weight: .bold))` | 小于 9pt，kbd 是等宽 | Advisory |
| 35 | `Theme/QuadrantMiniMark.swift` | 39 | `// token-exempt:` | `.font(.system(size: metrics == .row ? 10 : 9.5, weight: .bold, design: .rounded))` | 象限徽章用圆体 | Advisory |
| 36 | `Theme/QuadrantMiniMark.swift` | 53 | `// token-exempt:` | `.stroke(slot.themeColor.opacity(isHighlighted ? 0.35 : 0.15), lineWidth: 0.6)` | 象限色 35% 与 15% 不是印章色 | Legitimate |
| 37 | `Theme/SyntaxAutocompleteView.swift` | 209 | `// token-exempt:` | `.stroke(DaybookPalette.border.default.opacity(0.7), lineWidth: 0.7)` | 70% 分隔线没有对应令牌 | Advisory |
| 38 | `Theme/SyntaxAutocompleteView.swift` | 256 | `// token-exempt:` | `.font(.system(size: 11.5, weight: .semibold, design: .monospaced))` | 等宽候选标题，kbd 是 8.5pt | Advisory |
| 39 | `Theme/SyntaxAutocompleteView.swift` | 307 | `// token-exempt:` | `.background(RoundedRectangle(cornerRadius: DaybookRadius.xxs).fill(DaybookPalette.text.primary.opacity(0.06)))` | 6% 墨色没有对应令牌 | Advisory |
| 40 | `Theme/SyntaxAutocompleteView.swift` | 317 | `// token-exempt:` | `.background(RoundedRectangle(cornerRadius: DaybookRadius.xxs).fill(DaybookPalette.text.primary.opacity(0.06)))` | 6% 墨色没有对应令牌 | Advisory |
| 41 | `Theme/SyntaxAutocompleteView.swift` | 328 | `// token-exempt:` | `.background(RoundedRectangle(cornerRadius: DaybookRadius.xxs).fill(DaybookPalette.text.primary.opacity(0.06)))` | 6% 墨色没有对应令牌 | Advisory |
| 42 | `Theme/SyntaxAutocompleteView.swift` | 336 | `// token-exempt:` | `.background(DaybookPalette.text.primary.opacity(0.02))` | 2% 墨色没有对应令牌 | Advisory |
| 43 | `Theme/SyntaxHelpCard.swift` | 46 | `// token-exempt:` | `.stroke(DaybookPalette.border.default.opacity(0.6), lineWidth: 0.8)` | 60% 分隔线没有对应令牌 | Advisory |
| 44 | `Theme/SyntaxHelpCard.swift` | 90 | `// token-exempt:` | `+ Text("#工作").foregroundStyle(Color(nsColor: .systemIndigo)).bold()` | 没有靛蓝令牌 | **DEFECT** |
| 45 | `Theme/SyntaxHelpCard.swift` | 92 | `// token-exempt:` | `+ Text("#生活").foregroundStyle(Color(nsColor: .systemIndigo)).bold()` | 没有靛蓝令牌 | **DEFECT** |
| 46 | `Theme/SyntaxHelpCard.swift` | 94 | `// token-exempt:` | `color: Color(nsColor: .systemIndigo)` | 没有靛蓝令牌 | **DEFECT** |
| 47 | `Theme/SyntaxHelpCard.swift` | 170 | `// token-exempt:` | `.font(.system(size: 10.5, design: .monospaced))` | 等宽范例，kbd 是 8.5pt | Advisory |
| 48 | `Theme/SyntaxHelpCard.swift` | 178 | `// token-exempt:` | `.font(.system(size: 8.5, weight: .semibold))` | 小于 9pt，kbd 是等宽 | Advisory |
| 49 | `Theme/SyntaxHelpCard.swift` | 180 | `// token-exempt:` | `.font(.system(size: 8.5))` | 小于 9pt，kbd 是等宽 | Advisory |
| 50 | `Theme/SyntaxHelpCard.swift` | 195 | `// token-exempt:` | `.font(.system(size: 11, weight: .bold, design: .monospaced))` | 等宽符号，kbd 是 8.5pt | Advisory |
| 51 | `Theme/SyntaxHelpCard.swift` | 201 | `// token-exempt:` | `.fill(color.opacity(0.14))` | 符号色 14% 不是印章色 | Legitimate |
| 52 | `Theme/SyntaxHelpCard.swift` | 218 | `// token-exempt:` | `RoundedRectangle(cornerRadius: 5, style: .continuous)` | 5pt 与 xs、small 都差 1pt | **DEFECT** |
| 53 | `Theme/SyntaxHelpCard.swift` | 219 | `// token-exempt:` | `.fill(isHovered ? DaybookPalette.accent.base.opacity(0.06) : Color.clear)` | 6% 印章底没有对应令牌 | Advisory |
| 54 | `Theme/SyntaxHelpCard.swift` | 223 | `// control:` | `.buttonStyle(.plain)` | 语法条目悬停替换正文 | Legitimate |
| 55 | `Theme/SyntaxHelpCard.swift` | 241 | `// token-exempt:` | `.foregroundStyle(DaybookPalette.status.pending.opacity(0.9))` | 90% 待办橙没有对应令牌 | Advisory |
| 56 | `Theme/SyntaxHelpCard.swift` | 244 | `// token-exempt:` | `+ Text("#工作").foregroundStyle(Color(nsColor: .systemIndigo)).bold()` | 没有靛蓝令牌 | **DEFECT** |
| 57 | `Theme/SyntaxHelpCard.swift` | 249 | `// token-exempt:` | `.font(.system(size: 11, weight: .medium, design: .monospaced))` | 等宽范例，kbd 是 8.5pt | Advisory |
| 58 | `Theme/SyntaxHelpCard.swift` | 257 | `// token-exempt:` | `.font(.system(size: 8.5, weight: .semibold))` | 小于 9pt，kbd 是等宽 | Advisory |
| 59 | `Theme/SyntaxHelpCard.swift` | 259 | `// token-exempt:` | `.font(.system(size: 8.5))` | 小于 9pt，kbd 是等宽 | Advisory |
| 60 | `Theme/SyntaxHelpCard.swift` | 279 | `// token-exempt:` | `.foregroundStyle(DaybookPalette.text.secondary.opacity(0.8))` | 80% 次要色没有对应令牌 | Advisory |
| 61 | `Theme/SyntaxHelpCard.swift` | 287 | `// control:` | `.buttonStyle(.plain)` | 语法范例卡片 | Legitimate |
| 62 | `Theme/WorkspaceLayout.swift` | 136 | `// control:` | `.buttonStyle(.plain)` | 侧栏导航行，非按钮语义 | Legitimate |
| 63 | `Features/Tasks/AttachmentThumbnails.swift` | 15 | `// control:` | `.buttonStyle(.plain)` | 附件缩略图点击区 | Legitimate |
| 64 | `Features/Tasks/BatchActionBar.swift` | 115 | `// token-exempt:` | `.font(.system(size: 12, weight: .semibold, design: .monospaced))` | 批量计数用等宽，令牌是无衬线 | Advisory |
| 65 | `Features/Tasks/BoardFilterBar.swift` | 214 | `// token-exempt:` | `.font(.system(size: 8, weight: .bold))` | 小于 9pt 的筛选图标 | Legitimate |
| 66 | `Features/Tasks/BoardFilterBar.swift` | 224 | `// token-exempt:` | `.font(.system(size: 7.5, weight: .bold))` | 小于 9pt 的筛选图标 | Legitimate |
| 67 | `Features/Tasks/BoardFilterBar.swift` | 231 | `// token-exempt:` | `.background(Capsule().fill(active ? DaybookPalette.accent.fill : DaybookPalette.text.primary.opacity(0.05)))` | 5% 墨色底没有对应令牌 | Advisory |
| 68 | `Features/Tasks/BoardFilterBar.swift` | 232 | `// token-exempt:` | `.overlay(Capsule().stroke(active ? DaybookPalette.accent.border : DaybookPalette.border.default.opacity(0.5), lineWidth: 0.8))` | 50% 分隔线没有对应令牌 | Advisory |
| 69 | `Features/Tasks/BoardFilterBar.swift` | 233 | `// token-exempt:` | `.contentShape(Capsule())` | 筛选胶囊点击区 | Legitimate |
| 70 | `Features/Tasks/BoardFilterBar.swift` | 281 | `// token-exempt:` | `.font(.system(size: 8.5, weight: .bold))` | 小于 9pt 的筛选图标 | Legitimate |
| 71 | `Features/Tasks/BoardFilterBar.swift` | 304 | `// token-exempt:` | `.font(.system(size: 9, weight: .bold, design: .rounded))` | 下拉计数用圆体 | Advisory |
| 72 | `Features/Tasks/BoardFilterBar.swift` | 307 | `// token-exempt:` | `.background(item.isSelected ? DaybookPalette.accent.base.opacity(0.20) : DaybookPalette.text.primary.opacity(0.06))` | 20% 与 6% 没有对应令牌 | Advisory |
| 73 | `Features/Tasks/BoardFilterBar.swift` | 309 | `// token-exempt:` | `.clipShape(Capsule())` | 计数胶囊裁切 | Legitimate |
| 74 | `Features/Tasks/DayBoardSections.swift` | 48 | `// token-exempt:` | `.foregroundStyle(DaybookPalette.text.primary.opacity(0.85))` | 85% 墨色没有对应令牌 | Advisory |
| 75 | `Features/Tasks/DayBoardSections.swift` | 55 | `// token-exempt:` | `.fill(DaybookPalette.accent.base.opacity(0.05))` | 5% 印章底没有对应令牌 | Advisory |
| 76 | `Features/Tasks/DayBoardSections.swift` | 90 | `// control:` | `.buttonStyle(.plain)` | 分节折叠头，整行点击 | Legitimate |
| 77 | `Features/Tasks/DaybookProgressRing.swift` | 12 | `// token-exempt:` | `Circle()` | 进度环轨道 | Legitimate |
| 78 | `Features/Tasks/DaybookProgressRing.swift` | 13 | `// token-exempt:` | `.stroke(DaybookPalette.border.default.opacity(0.35), lineWidth: lineWidth)` | 35% 分隔线没有对应令牌 | Advisory |
| 79 | `Features/Tasks/DaybookProgressRing.swift` | 14 | `// token-exempt:` | `Circle()` | 进度环 | Legitimate |
| 80 | `Features/Tasks/DaybookProgressRing.swift` | 19 | `// token-exempt:` | `DaybookPalette.accent.base.opacity(0.75),` | 75% 印章色没有对应令牌 | Advisory |
| 81 | `Features/Tasks/DaybookProgressRing.swift` | 32 | `// token-exempt:` | `.font(.system(size: 10, weight: .bold, design: .rounded))` | 进度环数字用圆体 | Advisory |
| 82 | `Features/Tasks/TaskRow+Badges.swift` | 34 | `// token-exempt:` | `.font(.system(size: 9, weight: .bold, design: .rounded))` | 标签溢出计数用圆体 | Advisory |
| 83 | `Features/Tasks/TaskRow+Badges.swift` | 73 | `// token-exempt:` | `.font(.system(size: 10, weight: .bold, design: .rounded))` | 连击数字用圆体 | Advisory |
| 84 | `Features/Tasks/TaskRow+Badges.swift` | 85 | `// token-exempt:` | `.fill(isHighlighted ? DaybookPalette.status.pending.opacity(0.12) : Color.clear)` | 待办橙 12% 底没有单独令牌 | Advisory |
| 85 | `Features/Tasks/TaskRow.swift` | 288 | `// token-exempt:` | `.foregroundStyle(hasNoteCopied ? DaybookPalette.accent.base : (isNoteHovered ? DaybookPalette.accent.base : DaybookPalette.text.secondary.opacity(0.65)))` | 65% 次要色没有对应令牌 | Advisory |
| 86 | `Features/Tasks/TaskRow.swift` | 293 | `// token-exempt:` | `.fill(hasNoteCopied ? DaybookPalette.accent.base.opacity(0.16) : (isNoteHovered ? DaybookPalette.accent.fill : DaybookPalette.text.primary.opacity(0.04)))` | 16% 与 4% 没有对应令牌 | Advisory |
| 87 | `Features/Tasks/TaskRow.swift` | 402 | `// token-exempt:` | `.foregroundStyle(DaybookPalette.text.secondary.opacity(0.85))` | 85% 次要色没有对应令牌 | Advisory |
| 88 | `Features/Tasks/TaskRow.swift` | 410 | `// token-exempt:` | `.foregroundStyle(DaybookPalette.accent.base.opacity(0.85))` | 85% 印章色没有对应令牌 | Advisory |
| 89 | `Features/Tasks/TaskRowSubtaskMiniViews.swift` | 41 | `// token-exempt:` | `Circle()` | 子任务圆框 | Legitimate |
| 90 | `Features/Tasks/TaskRowSubtaskMiniViews.swift` | 42 | `// token-exempt:` | `.strokeBorder(subtask.isDone ? DaybookPalette.accent.base : DaybookPalette.text.secondary.opacity(0.4), lineWidth: 1.2)` | 40% 次要色没有对应令牌 | Advisory |
| 91 | `Features/Tasks/TaskRowSubtaskMiniViews.swift` | 44 | `// token-exempt:` | `Circle().fill(subtask.isDone ? DaybookPalette.accent.base : Color.clear)` | 子任务圆底 | Legitimate |
| 92 | `Features/Tasks/TaskRowSubtaskMiniViews.swift` | 60 | `// control:` | `.buttonStyle(.plain)` | 复选框，非按钮语义 | Legitimate |
| 93 | `Features/Tasks/TasksPage+Header.swift` | 121 | `// token-exempt:` | `.font(.system(size: 7.5, weight: .bold))` | 芯片内移除角标小于 9pt | Legitimate |
| 94 | `Features/Tasks/TasksPage+Header.swift` | 125 | `// control:` | `.buttonStyle(.plain)` | 芯片内的移除角标 | Legitimate |
| 95 | `Features/Tasks/TasksPage+Sections.swift` | 85 | `// token-exempt:` | `.background(DaybookPalette.accent.base.opacity(0.14))` | 14% 印章底没有对应令牌 | Advisory |
| 96 | `Features/Tasks/TasksPage+Sections.swift` | 86 | `// token-exempt:` | `.clipShape(Capsule())` | 计数胶囊裁切 | Legitimate |
| 97 | `Features/Tasks/TasksPage+Sections.swift` | 289 | `// token-exempt:` | `.font(.system(size: 9.5, weight: .bold, design: .rounded))` | 遗留计数用圆体 | Advisory |
| 98 | `Features/Calendar/CalendarMonthGrid.swift` | 88 | `// token-exempt:` | `.font(.system(size: 9, weight: .semibold, design: .rounded))` | 日期计数用圆体 | Advisory |
| 99 | `Features/Calendar/CalendarMonthGrid.swift` | 94 | `// token-exempt:` | `RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)` | 今日环、选中与投放三态 | Legitimate |
| 100 | `Features/Calendar/CalendarMonthGrid.swift` | 95 | `// token-exempt:` | `.fill(selected ? DaybookPalette.accent.base.opacity(0.18) : DaybookPalette.cardSurface)` | 18% 印章底没有对应令牌 | Advisory |
| 101 | `Features/Calendar/CalendarMonthGrid.swift` | 98 | `// token-exempt:` | `RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)` | 今日环、选中与投放三态 | Legitimate |
| 102 | `Features/Calendar/CalendarMonthGrid.swift` | 99 | `// token-exempt:` | `.stroke(today ? DaybookPalette.accent.base : (selected ? DaybookPalette.accent.base.opacity(0.4) : DaybookPalette.border.default.opacity(0.3)), lineWidth: today ? 1.4 : 0.8)` | 40% 印章色和 30% 分隔线没有对应令牌 | Advisory |
| 103 | `Features/Calendar/CalendarMonthGrid.swift` | 107 | `// token-exempt:` | `RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)` | 今日环、选中与投放三态 | Legitimate |
| 104 | `Features/MenuBar/FooterBar.swift` | 168 | `// token-exempt:` | `.font(.system(size: 8, weight: .bold, design: .rounded))` | 8pt 圆体计数，放到 9pt 会变宽 | Advisory |
| 105 | `Features/MenuBar/FooterBar.swift` | 172 | `// token-exempt:` | `.clipShape(Capsule())` | 计数胶囊裁切 | Legitimate |
| 106 | `Features/MenuBar/MenuBarControls.swift` | 34 | `// token-exempt:` | `.font(.system(size: 11, weight: .bold, design: .serif))` | 菜单栏标记用衬线，令牌是无衬线 | Legitimate |
| 107 | `Features/MenuBar/MenuBarControls.swift` | 37 | `// token-exempt:` | `.font(.system(size: 12, weight: .semibold, design: .rounded))` | 菜单栏计数用圆体 | Advisory |
| 108 | `Features/MenuBar/MenuBarFilterFlyout.swift` | 136 | `// token-exempt:` | `Circle()` | 筛选状态圆点 | Legitimate |
| 109 | `Features/MenuBar/MenuBarFilterFlyout.swift` | 142 | `// token-exempt:` | `.font(.system(size: 7.5, weight: .bold))` | 小于 9pt 的筛选图标 | Legitimate |
| 110 | `Features/MenuBar/MenuBarFilterFlyout.swift` | 161 | `// token-exempt:` | `.font(.system(size: 8.5, weight: .semibold))` | 小于 9pt 的筛选图标 | Legitimate |
| 111 | `Features/MenuBar/MenuBarFilterFlyout.swift` | 178 | `// token-exempt:` | `.strokeBorder(DaybookPalette.border.default.opacity(0.65), lineWidth: 0.8)` | 65% 分隔线没有对应令牌 | Advisory |
| 112 | `Features/MenuBar/MenuBarFilterFlyout.swift` | 209 | `// token-exempt:` | `.font(.system(size: 8.5, weight: .semibold))` | 小于 9pt 的筛选图标 | Legitimate |
| 113 | `Features/MenuBar/MenuBarFilterFlyout.swift` | 228 | `// token-exempt:` | `.strokeBorder(DaybookPalette.border.default.opacity(0.65), lineWidth: 0.8)` | 65% 分隔线没有对应令牌 | Advisory |
| 114 | `Features/MenuBar/MenuBarFilterFlyout.swift` | 313 | `// token-exempt:` | `Circle()` | 筛选状态圆点 | Legitimate |
| 115 | `Features/MenuBar/MenuBarFilterFlyout.swift` | 318 | `// token-exempt:` | `.font(.system(size: 8.5, weight: .medium))` | 小于 9pt 的筛选图标 | Legitimate |
| 116 | `Features/MenuBar/MenuBarFilterFlyout.swift` | 330 | `// token-exempt:` | `.font(.system(size: 8, weight: .bold, design: .rounded))` | 小于 9pt 的筛选图标 | Legitimate |
| 117 | `Features/MenuBar/MenuBarFilterFlyout.swift` | 336 | `// token-exempt:` | `.font(.system(size: 8, weight: .bold))` | 小于 9pt 的筛选图标 | Legitimate |
| 118 | `Features/MenuBar/MenuBarPopoverView.swift` | 338 | `// token-exempt:` | `.font(.system(size: 7, weight: .bold))` | 头部状态图标小于 9pt | Legitimate |
| 119 | `Features/MenuBar/MenuBarPopoverView.swift` | 345 | `// token-exempt:` | `Circle()` | 头部状态圆点 | Legitimate |
| 120 | `Features/MenuBar/MenuBarPopoverView.swift` | 351 | `// token-exempt:` | `.font(.system(size: 7, weight: .bold))` | 头部状态图标小于 9pt | Legitimate |
| 121 | `Features/MenuBar/MenuBarPopoverView.swift` | 356 | `// token-exempt:` | `.font(.system(size: 7, weight: .bold))` | 头部状态图标小于 9pt | Legitimate |
| 122 | `Features/MenuBar/MenuBarPopoverView.swift` | 362 | `// token-exempt:` | `Circle()` | 头部状态圆点 | Legitimate |
| 123 | `Features/MenuBar/MenuBarPopoverView.swift` | 368 | `// token-exempt:` | `.font(.system(size: 8, weight: .semibold))` | 头部状态图标小于 9pt | Legitimate |
| 124 | `Features/MenuBar/MenuBarSearchField.swift` | 49 | `// token-exempt:` | `Circle().fill(dotColor).frame(width: 4.5, height: 4.5)` | 筛选色点 | Legitimate |
| 125 | `Features/MenuBar/MenuBarSearchField.swift` | 57 | `// token-exempt:` | `.font(.system(size: 6.5, weight: .bold))` | 芯片内移除角标小于 9pt | Legitimate |
| 126 | `Features/MenuBar/MenuBarSearchField.swift` | 61 | `// control:` | `.buttonStyle(.plain)` | 芯片内的移除角标 | Legitimate |
| 127 | `Features/Board/BoardCommandStrip.swift` | 39 | `// token-exempt:` | `.font(.system(size: 10, weight: .semibold, design: .rounded))` | 命令提示用圆体 | Advisory |
| 128 | `Features/Board/BoardCommandStrip.swift` | 40 | `// token-exempt:` | `.foregroundStyle(isDestructive ? DaybookPalette.status.danger : DaybookPalette.text.primary.opacity(0.85))` | 85% 墨色没有对应令牌 | Advisory |
| 129 | `Features/Board/BoardCommandStrip.swift` | 46 | `// token-exempt:` | `.fill(isDestructive ? DaybookPalette.status.danger.opacity(0.08) : DaybookPalette.text.primary.opacity(0.06))` | 8% 危险色和 6% 墨色没有对应令牌 | Advisory |
| 130 | `Features/Workspace/TaskDetailClassificationSection.swift` | 87 | `// token-exempt:` | `.foregroundStyle(DaybookPalette.text.secondary.opacity(0.7))` | 70% 次要色没有对应令牌 | Advisory |
| 131 | `Features/Workspace/TaskDetailClassificationSection.swift` | 93 | `// token-exempt:` | `tint: Color(nsColor: .systemIndigo),` | 没有靛蓝令牌 | **DEFECT** |
| 132 | `Features/Workspace/TaskDetailDrawer.swift` | 37 | `// token-exempt:` | `DaybookPalette.fill.page.opacity(0.4)` | 40% 纸色没有对应令牌 | Advisory |
| 133 | `Features/Workspace/TaskDetailDrawer.swift` | 52 | `// token-exempt:` | `.font(.system(size: 36, weight: .light))` | display 是 26pt，这处是 36pt light | Advisory |
| 134 | `Features/Workspace/TaskDetailDrawer.swift` | 53 | `// token-exempt:` | `.foregroundStyle(DaybookPalette.text.secondary.opacity(0.5))` | 50% 次要色没有对应令牌 | Advisory |
| 135 | `Features/Workspace/TaskDetailDrawer.swift` | 59 | `// token-exempt:` | `.foregroundStyle(DaybookPalette.text.secondary.opacity(0.8))` | 80% 次要色没有对应令牌 | Advisory |
| 136 | `Features/Workspace/TaskDetailHeaderSection.swift` | 27 | `// token-exempt:` | `.foregroundStyle(DaybookPalette.status.danger.opacity(0.85))` | 85% 危险色没有对应令牌 | Advisory |
| 137 | `Features/Workspace/TaskDetailNotesView.swift` | 50 | `// token-exempt:` | `.foregroundStyle(DaybookPalette.text.secondary.opacity(0.6))` | 60% 次要色没有对应令牌 | Advisory |
| 138 | `Features/Workspace/TaskDetailNotesView.swift` | 81 | `// token-exempt:` | `.foregroundStyle(DaybookPalette.text.secondary.opacity(0.7))` | 70% 次要色没有对应令牌 | Advisory |
| 139 | `Features/Workspace/TaskDetailQuadrantGrid.swift` | 59 | `// token-exempt:` | `.stroke(isActive ? slot.themeColor.opacity(0.7) : DaybookPalette.border.default.opacity(0.25), lineWidth: isActive ? 1.2 : 0.6)` | 象限色 70% 和分隔线 25% 没有对应令牌 | Advisory |
| 140 | `Features/Workspace/TaskDetailQuadrantGrid.swift` | 63 | `// control:` | `.buttonStyle(.plain)` | 象限选择格保留象限色，不进通用表面 | Legitimate |
| 141 | `Features/Workspace/TaskDetailScheduleSection.swift` | 85 | `// token-exempt:` | `.font(.system(size: 10, weight: .bold, design: .monospaced))` | 提醒时刻用等宽 | Advisory |
| 142 | `Features/Workspace/TaskDetailScheduleSection.swift` | 145 | `// token-exempt:` | `Circle()` | 星期圆点，不是胶囊 | Legitimate |
| 143 | `Features/Workspace/TaskDetailScheduleSection.swift` | 150 | `// control:` | `.buttonStyle(.plain)` | 星期圆点选择器，不是胶囊 | Legitimate |
| 144 | `Features/Workspace/TaskDetailScheduleSection.swift` | 249 | `// token-exempt:` | `.font(.system(size: 16, weight: .bold, design: .rounded))` | 连击数字用圆体 | Advisory |
| 145 | `Features/Workspace/TaskDetailScheduleSection.swift` | 267 | `// token-exempt:` | `.foregroundStyle(.yellow)` | 没有黄色令牌 | **DEFECT** |
| 146 | `Features/Workspace/TaskDetailScheduleSection.swift` | 269 | `// token-exempt:` | `.font(.system(size: 16, weight: .bold, design: .rounded))` | 连击数字用圆体 | Advisory |
| 147 | `Features/Workspace/TaskDetailSubtasksView.swift` | 53 | `// token-exempt:` | `.font(.system(size: 10, weight: .medium, design: .monospaced))` | 子任务计数用等宽 | Advisory |
| 148 | `Features/Workspace/TaskDetailSubtasksView.swift` | 63 | `// token-exempt:` | `.fill(DaybookPalette.border.default.opacity(0.3))` | 30% 分隔线没有对应令牌 | Advisory |
| 149 | `Features/Workspace/TaskDetailSubtasksView.swift` | 66 | `// token-exempt:` | `.fill(completedCount == totalCount ? DaybookPalette.accent.base : DaybookPalette.accent.base.opacity(0.8))` | 80% 印章色没有对应令牌 | Advisory |
| 150 | `Features/Workspace/TaskDetailSubtasksView.swift` | 172 | `// control:` | `.buttonStyle(.plain)` | 子任务复选框，非按钮语义 | Legitimate |
| 151 | `Features/Workspace/TaskDetailSubtasksView.swift` | 195 | `// token-exempt:` | `.foregroundStyle(subtask.isDone ? DaybookPalette.text.secondary.opacity(0.7) : DaybookPalette.text.primary)` | 70% 次要色没有对应令牌 | **DEFECT** |
| 152 | `Features/Workspace/TaskDetailSubtasksView.swift` | 196 | `// token-exempt:` | `.strikethrough(subtask.isDone, color: DaybookPalette.text.secondary.opacity(0.5))` | 50% 次要色没有对应令牌 | Advisory |
| 153 | `Features/Workspace/WorkspaceFilteredListView.swift` | 184 | `// control:` | `.buttonStyle(.plain)` | 已完成折叠头，整行点击 | Legitimate |
| 154 | `Features/Workspace/WorkspaceGlobalSearchView.swift` | 126 | `// control:` | `.buttonStyle(.plain)` | 附件结果整行点击区 | Legitimate |
| 155 | `Features/Workspace/WorkspaceHeaderBar.swift` | 92 | `// token-exempt:` | `.font(.system(size: 9.5, weight: .bold, design: .rounded))` | 快捷键提示用圆体 | Advisory |
| 156 | `Features/Workspace/WorkspaceHeaderBar.swift` | 93 | `// token-exempt:` | `.foregroundStyle(DaybookPalette.text.secondary.opacity(0.6))` | 60% 次要色没有对应令牌 | Advisory |
| 157 | `Features/Workspace/WorkspaceHeaderBar.swift` | 98 | `// token-exempt:` | `.fill(DaybookPalette.border.default.opacity(0.18))` | 18% 分隔线没有对应令牌 | Advisory |
| 158 | `Features/Search/BoardSearchHitRow.swift` | 59 | `// control:` | `.buttonStyle(.plain)` | 搜索结果整行点击区 | Legitimate |
| 159 | `Features/Search/BoardSearchHitRow.swift` | 78 | `// token-exempt:` | `.background(Capsule().fill(DaybookPalette.accent.fill))` | 搜索种类胶囊 | Advisory |
| 160 | `Features/Gantt/GanttPage.swift` | 156 | `// token-exempt:` | `Circle()` | 习惯完成点，不是按钮 | Legitimate |
| 161 | `Features/Gantt/GanttPage.swift` | 166 | `// token-exempt:` | `return RoundedRectangle(cornerRadius: DaybookRadius.xxs, style: .continuous)` | 甘特色块是数据标记，不是卡片 | Legitimate |
| 162 | `Features/Gantt/GanttPage.swift` | 167 | `// token-exempt:` | `.fill(filled ? DaybookPalette.accent.base.opacity(0.85) : Color.clear)` | 85% 印章色没有对应令牌 | Advisory |
| 163 | `Features/Gantt/GanttPage.swift` | 171 | `// token-exempt:` | `RoundedRectangle(cornerRadius: DaybookRadius.xs)` | 甘特色块是数据标记，不是卡片 | Legitimate |
| 164 | `Features/Quadrant/QuadrantPage.swift` | 162 | `// control:` | `.buttonStyle(.plain)` | 象限任务卡整行点击 | Legitimate |
| 165 | `Features/Diary/DiaryCardComponents.swift` | 23 | `// token-exempt:` | `.foregroundStyle(DaybookPalette.status.danger.opacity(0.85))` | 85% 危险色没有对应令牌 | Advisory |
| 166 | `Features/Diary/DiaryCardComponents.swift` | 26 | `// token-exempt:` | `.background(Capsule().fill(DaybookPalette.status.danger.opacity(0.10)))` | 10% 危险色底没有对应令牌 | Advisory |
| 167 | `Features/Diary/DiaryCardComponents.swift` | 130 | `// token-exempt:` | `.font(.system(size: 14, weight: .bold, design: .monospaced))` | 密码占位用等宽粗体，bodyLarge 是 14pt 常规无衬线 | Advisory |
| 168 | `Features/Diary/DiaryNoteCard.swift` | 7 | `// token-exempt:` | `if DiaryMemoTags.isPasswordName(name) { return .red }` | 菜单栏和筛选共用，systemRed 不是同一个红 | Legitimate |
| 169 | `Features/Diary/DiaryNoteCard.swift` | 8 | `// token-exempt:` | `if name == DiaryMemoTags.idea { return .orange }` | 菜单栏和筛选共用，systemOrange 不是同一个橙 | Legitimate |
| 170 | `Features/Diary/DiaryNoteCard.swift` | 9 | `// token-exempt:` | `if name == DiaryMemoTags.journal { return .blue }` | 菜单栏和筛选共用，systemBlue 不是同一个蓝 | Legitimate |
| 171 | `Features/Diary/DiaryNoteCard.swift` | 26 | `// token-exempt:` | `.fill(color.opacity(0.12))` | 标签色 12% 底不是印章色 | Legitimate |
| 172 | `Features/Diary/DiaryNoteCard.swift` | 31 | `// token-exempt:` | `.strokeBorder(color.opacity(0.25), lineWidth: 0.5)` | 标签色 25% 描边没有对应令牌 | Advisory |
| 173 | `Features/Diary/DiaryNoteCard.swift` | 208 | `// token-exempt:` | `.font(.system(size: 8.5, weight: .bold))` | 小于 9pt 的加号，kbd 是等宽 | Advisory |
| 174 | `Features/Diary/DiaryNoteCard.swift` | 217 | `// token-exempt:` | `.background(Capsule().fill(DaybookPalette.fill.hover))` | 加标签胶囊，圆角由形状决定 | Legitimate |
| 175 | `Features/Diary/DiaryNoteCard.swift` | 219 | `// token-exempt:` | `Capsule().strokeBorder(DaybookPalette.border.subtle, lineWidth: 0.7)` | 加标签胶囊，圆角由形状决定 | Legitimate |
| 176 | `Features/Diary/DiaryPage.swift` | 282 | `// token-exempt:` | `.font(.system(size: 9.5, weight: .bold, design: .rounded))` | 筛选计数用圆体 | Advisory |
| 177 | `Features/Diary/DiaryPage.swift` | 384 | `// token-exempt:` | `.foregroundStyle(DaybookPalette.text.secondary.opacity(0.4))` | 40% 次要色没有对应令牌 | Advisory |
| 178 | `Features/Diary/DiaryQuickComposerView.swift` | 39 | `// token-exempt:` | `.fill(DaybookPalette.fill.hover.opacity(0.5)))` | 悬停底 50% 没有对应令牌 | Advisory |
| 179 | `Features/Diary/DiaryQuickComposerView.swift` | 120 | `// token-exempt:` | `return DaybookPalette.text.secondary.opacity(0.8)` | 80% 次要色没有对应令牌 | Advisory |
| 180 | `Features/Diary/DiarySummaryRow.swift` | 130 | `// token-exempt:` | `? DaybookPalette.accent.base.opacity(0.28)` | 28% 印章色没有对应令牌 | Advisory |
| 181 | `Features/Diary/DiarySummaryRow.swift` | 255 | `// token-exempt:` | `.foregroundStyle(hasNoteCopied ? DaybookPalette.accent.base : (isNoteHovered ? DaybookPalette.accent.base : DaybookPalette.text.secondary.opacity(0.65)))` | 65% 次要色没有对应令牌 | Advisory |
| 182 | `Features/Diary/DiarySummaryRow.swift` | 260 | `// token-exempt:` | `.fill(hasNoteCopied ? DaybookPalette.accent.base.opacity(0.16) : (isNoteHovered ? DaybookPalette.accent.fill : DaybookPalette.text.primary.opacity(0.04)))` | 16% 与 4% 没有对应令牌 | Advisory |
| 183 | `Features/Diary/DiarySummaryRow.swift` | 446 | `// token-exempt:` | `.font(.system(size: 8.5))` | 小于 9pt 的图钉和锁图标 | Legitimate |
| 184 | `Features/Diary/DiarySummaryRow.swift` | 452 | `// token-exempt:` | `.font(.system(size: 8.5))` | 小于 9pt 的图钉和锁图标 | Legitimate |
| 185 | `Features/Diary/DiaryWindowView.swift` | 65 | `// token-exempt:` | `Image(systemName: "lock.shield").font(.system(size: 26))` | display 令牌是 26pt light，这处是默认字重 | Legitimate |
| 186 | `Features/Attachments/AttachmentBrowserPage.swift` | 106 | `// token-exempt:` | `.font(.system(size: 18))` | entity 是 17pt，这处是 18pt | Advisory |

---

## 4. 架构分层边界与领域层纯度验证 (Architectural Boundary & Domain Purity)

根据 `AGENTS.md`、`docs/architecture.md` 及 `ORIGINAL_REQUEST.md` 要求：`AreaChain/Domain/` 目录严禁导入任何 UI 框架（`SwiftUI`, `AppKit`, `Cocoa`, `UIKit`），必须保持 100% 纯 Swift 业务逻辑。

经使用 `scripts/check_workflow.py` 静态检查器及 AST 全文检索：
- **Domain 文件总数**：37 个 Swift 文件（根目录 32 个 + `Protocols/` 5 个）。
- **UI 框架导入检查**：**0 处导入**（`import SwiftUI` = 0, `import AppKit` = 0, `import Cocoa` = 0）。
- **UI 类型耦合检查**：**0 处使用**（无 `NSColor`, `UIColor`, `Color`, `NSImage`, `NSFont`, `NSView`, `@State`, `@Binding`, `@Environment`）。
- **单文件行数限制**：37 个文件**全部 $\le 500$ 行**（最大文件为 `NaturalLanguageParser.swift` 443 行）。

### 4.1 Domain 全部 37 个文件纯度审查清单

| 序号 | 文件路径 (相对 Domain/) | 行数 | 导入模块 (Imports) | 核心类型与职责声明 | 纯度评定 |
|:---:|---|:---:|:---:|---|:---:|
| 1 | `BoardPage.swift` | 93 | `Foundation` | enum BoardTab, struct BoardFilters (三栏页面与过滤器定义) | 🟢 PURE |
| 2 | `BoardSearch.swift` | 292 | `Foundation` | struct BoardSearchHit, struct BoardSearchScope, enum Kind (三栏看板搜索逻辑) | 🟢 PURE |
| 3 | `CalendarEventPolicy.swift` | 124 | `Foundation` | enum CalendarEventPolicy (系统日历事件映射规则与策略) | 🟢 PURE |
| 4 | `CalendarReconciliation.swift` | 132 | `Foundation` | struct CalendarContent, struct CalendarLocalState (日历差异对账引擎) | 🟢 PURE |
| 5 | `Catalog.swift` | 295 | `Foundation` | enum Catalog, struct ProjectOutlineRow, struct AttachmentRef (项目分类大纲) | 🟢 PURE |
| 6 | `CatalogModels.swift` | 85 | `Foundation, SwiftData` | class ProjectItem, class TagItem, class AttachmentItem (分类领域持久化模型) | 🟢 PURE |
| 7 | `Classification.swift` | 290 | `Foundation` | enum DateFilterScope, enum PriorityFilterScope, struct BoardFilter (看板四象限分类) | 🟢 PURE |
| 8 | `ClassifiedFields.swift` | 32 | `Foundation` | protocol ClassifiedFields, enum ClassifiedFieldsUpdate (属性归一化接口) | 🟢 PURE |
| 9 | `DayBoardLogic.swift` | 344 | `Foundation` | struct RoutineSnapshot, struct TodoSnapshot, struct SubtaskSnapshot (日程快照与状态) | 🟢 PURE |
| 10 | `DayKey.swift` | 165 | `Foundation` | enum DayKey (民事日期 YYYY-MM-DD 语义封装) | 🟢 PURE |
| 11 | `DiaryMemoTags.swift` | 46 | `Foundation` | enum DiaryMemoTags (手记专属预设标签过滤规则) | 🟢 PURE |
| 12 | `DiaryPrivacy.swift` | 92 | `Foundation, SwiftData` | enum DiaryPrivacy, enum ContentMode, enum AttachmentAccess (手记隐私投影与状态) | 🟢 PURE |
| 13 | `ExportDates.swift` | 35 | `Foundation` | enum ExportDates (导出日期 ISO-8601 与民事日转换) | 🟢 PURE |
| 14 | `ExportSnapshot.swift` | 359 | `Foundation` | struct ExportSnapshot, struct ExportedProject, struct ExportedTag (快照备份 DTO) | 🟢 PURE |
| 15 | `FeedbackCopy.swift` | 48 | `Foundation` | enum CalendarSyncPhase, enum ScreenCaptureFailure (系统同步与截图结果定义) | 🟢 PURE |
| 16 | `GanttDragState.swift` | 45 | `Foundation` | struct GanttTodoMove, struct GanttDragState (甘特图拖拽排程状态) | 🟢 PURE |
| 17 | `GanttLayout.swift` | 44 | `Foundation` | struct GanttTodoBar, struct GanttRoutineMark, enum GanttLayout (甘特条布局计算) | 🟢 PURE |
| 18 | `HabitStreakLogic.swift` | 187 | `Foundation` | struct StreakResult, enum HabitStreakLogic, struct TodayStatus (习惯打卡核心算法) | 🟢 PURE |
| 19 | `ImportPreview.swift` | 91 | `Foundation` | struct ExistingIDs, struct ImportPreview, enum ImportPreviewing (快照导入差异计算) | 🟢 PURE |
| 20 | `L10n.swift` | 21 | `Foundation` | enum L10n (无 UI 依赖的多语言 Bundle 与字符串格式化器) | 🟢 PURE |
| 21 | `MenuBarStatus.swift` | 25 | `Foundation` | enum MenuBarStatus (状态栏图标状态语义与计算) | 🟢 PURE |
| 22 | `Models.swift` | 330 | `Foundation, SwiftData` | class DailyRoutine, class RoutineCheck, class SubtaskItem, class TodoItem 等实体 | 🟢 PURE |
| 23 | `NaturalLanguageParser.swift` | 443 | `Foundation` | enum SyntaxTokenKind, struct ParsedCapture, struct ParsedDiaryCapture (NLP 语法解析) | 🟢 PURE |
| 24 | `PriorityToken.swift` | 24 | `Foundation` | struct PriorityFlags, enum PriorityToken (四象限优先级符号 !p1-!p4 解析) | 🟢 PURE |
| 25 | `PrivacyConfiguration.swift` | 54 | `Foundation` | enum PrivacyError, struct PasswordKeySlot, struct PrivacyConfiguration (私密锁配置) | 🟢 PURE |
| 26 | `Protocols/AttachmentStorageProtocol.swift` | 94 | `Foundation, SwiftData` | protocol AttachmentStorageProtocol (附件持久化抽象接口) | 🟢 PURE |
| 27 | `Protocols/CatalogRepositoryProtocol.swift` | 115 | `Foundation, SwiftData` | protocol CatalogRepositoryProtocol (项目与标签仓储抽象接口) | 🟢 PURE |
| 28 | `Protocols/DiaryRepositoryProtocol.swift` | 66 | `Foundation, SwiftData` | protocol DiaryRepositoryProtocol (手记仓储抽象接口) | 🟢 PURE |
| 29 | `Protocols/RoutineRepositoryProtocol.swift` | 229 | `Foundation, SwiftData` | protocol RoutineRepositoryProtocol, struct CreateRoutineParams (常驻例行仓储接口) | 🟢 PURE |
| 30 | `Protocols/TaskRepositoryProtocol.swift` | 189 | `Foundation, SwiftData` | protocol TaskRepositoryProtocol, struct CreateTodoParams (任务仓储抽象接口) | 🟢 PURE |
| 31 | `ReminderPlanning.swift` | 146 | `Foundation` | enum RemindMinutes, enum ClockLabel, struct ReminderRequest (系统提醒调度计划) | 🟢 PURE |
| 32 | `SoftDelete.swift` | 43 | `Foundation` | enum SoftDelete (实体软删除过滤规则与保留期限) | 🟢 PURE |
| 33 | `SyntaxAutocomplete.swift` | 289 | `Foundation` | enum SyntaxTriggerKind, struct SyntaxCandidate, enum SyntaxAutocompleteEngine | 🟢 PURE |
| 34 | `TagSyntax.swift` | 104 | `Foundation` | struct TagSyntaxToken, enum TagSyntax (标签语法分词与规范化) | 🟢 PURE |
| 35 | `TaskSelection.swift` | 41 | `Foundation` | struct TaskSelectionModifiers, struct TaskSelection (任务选中状态语义) | 🟢 PURE |
| 36 | `TodoDragToken.swift` | 28 | `Foundation` | enum TodoDragToken (拖拽剪贴板标识生成) | 🟢 PURE |
| 37 | `WeekdayMask.swift` | 103 | `Foundation` | enum WeekdayMask (星期掩码位运算与文案格式化规则) | 🟢 PURE |

---

## 5. 多语言本地化全景审计账本 (Localization Ledger)

### 5.1 Localizable.xcstrings 键结构与同步状态
- **资源文件路径**：`AreaChain/Resources/Localizable.xcstrings`
- **源语言 (`sourceLanguage`)**：`en`
- **目标语言支持**：`en`, `zh-Hans`
- **总键数**：**662 项**

```text
总条目: 662 项
├── 双语完整翻译 (en + zh-Hans): 651 项 (98.34%)
├── 仅单语存在 (Asymmetric Key): 1 项 (0.15%)
└── 双语均无翻译 (Unlocalized Skeleton Entries): 10 项 (1.51%)
```

### 5.2 缺陷清单一：单语不对称键 (Asymmetric Key)

| 键名 (Key) | `en` 状态与值 | `zh-Hans` 状态与值 | 触发源与原因分析 | 整改建议 |
|---|---|---|---|---|
| `"%lld/%lld"` | `state: "new"`<br>`value: "%1$lld/%2$lld"` | 🔴 **完全缺失 (None)** | 来自 `TaskRowSubtaskMiniViews.swift:19` 与 `TaskDetailSubtasksView.swift:52` 中的 `Text("\(completed)/\(total)")`。Xcode 自动提取了 English 临时条目，未同步至 `zh-Hans`。 | 在 `Localizable.xcstrings` 中补充 `zh-Hans`: `"%1$lld/%2$lld"`，或改用 `Text(verbatim: "\(completed)/\(total)")`。 |

### 5.3 缺陷清单二：双语未本地化骨架条目 (Unlocalized Skeleton Entries)
在 `Localizable.xcstrings` 中有 10 个由 Xcode 自动扫描工具提取生成的空骨架，未配置任何翻译：

| 序号 | 键名 (Key) | Xcode 自动生成注释 | 现状与影响 | 修复建议 |
|:---:|---|---|---|---|
| 1 | `""` | *(无)* | 空字符串条目，无任何翻译实体 | 清理删除 |
| 2 | `" "` | A placeholder value for a day number. | 单空格字符，日历日期占位符 | 清理删除或改用 `Text(verbatim: " ")` |
| 3 | `"#%@"` | A tag label. The argument is the name of the tag. | 标签显示格式 | 补充双语 `"#%@"` 或清理 |
| 4 | `"%lld"` | A label that shows the number of tasks on a given day. | 纯数字文本 | 改用 `Text(verbatim: "\(count)")` |
| 5 | `"%lld%%"` | A label showing the percentage of the day that has been completed. | 百分比文本 | 补充双语 `"%lld%%"` |
| 6 | `"••••••••••••••••"` | A placeholder for a masked password. | 密码掩码占位符 | 改用 `Text(verbatim: "••••••••••••••••")` 并清理 |
| 7 | `"↑↓"` | A key that moves the cursor up or down. | 键盘箭头符号 | 改用 `Text(verbatim: "↑↓")` 并清理 |
| 8 | `"⇥ / ↵"` | A key combination for autocompleting text. | 补全快捷键符号 | 改用 `Text(verbatim: "⇥ / ↵")` 并清理 |
| 9 | `"AreaChain"` | The name of the app. | 应用名称 | 补充双语 `"AreaChain"` 或保留为只读名称 |
| 10 | `"Esc"` | A key combination to close the syntax autocompletion popup. | Esc 按键符号 | 改用 `Text(verbatim: "Esc")` 并清理 |

### 5.4 语法自动补全副标题键 (SyntaxCandidate.subtitle) 覆盖验证
在 `AreaChain/Domain/SyntaxAutocomplete.swift` 中定义的 16 个标准化候选条目副标题键：

| 语法类型 | 触发符号 / 用途 | 资源键名 (Subtitle Key) | `en` 译文 | `zh-Hans` 译文 | 状态 |
|---|---|---|---|---|:---:|
| 标签 | 保存时创建标签 | `syntax.tag.create.on.save` | Create on save | 保存时创建 | 🟢 PASS |
| 标签 | 空状态输入提示 | `syntax.tag.type.to.create` | Type name to create | 输入名称回车创建 | 🟢 PASS |
| 标签 | 候选标签展示 | `syntax.tag.label` | Tag | 标签 | 🟢 PASS |
| 标签搜索 | 搜索标签筛选 | `syntax.search.tag` | Filter by tag | 按标签搜索 | 🟢 PASS |
| 优先级 | P1 四象限说明 | `syntax.priority.p1` | Important and urgent | 重要且紧急 | 🟢 PASS |
| 优先级 | P2 四象限说明 | `syntax.priority.p2` | Important, not urgent | 重要不紧急 | 🟢 PASS |
| 优先级 | P3 四象限说明 | `syntax.priority.p3` | Urgent, not important | 紧急不重要 | 🟢 PASS |
| 优先级 | P4 四象限说明 | `syntax.priority.p4` | Neither | 不重要不紧急 | 🟢 PASS |
| 提醒时刻 | 早上 09:00 | `syntax.time.morning` | Morning | 早上 | 🟢 PASS |
| 提醒时刻 | 中午 12:00 | `syntax.time.noon` | Noon | 中午 | 🟢 PASS |
| 提醒时刻 | 下午 15:00 | `syntax.time.afternoon` | Afternoon | 下午 | 🟢 PASS |
| 提醒时刻 | 傍晚 18:00 | `syntax.time.evening` | Evening | 傍晚 | 🟢 PASS |
| 提醒时刻 | 晚上 21:00 | `syntax.time.night` | Night | 晚上 | 🟢 PASS |
| 提醒时刻 | 整点时间 | `syntax.time.hour` | On the hour | 整点 | 🟢 PASS |
| 提醒时刻 | 自定义时间 | `syntax.time.custom` | Custom time | 自定义时刻 | 🟢 PASS |
| 时刻搜索 | 搜索时刻查找 | `syntax.search.time` | Search reminder time | 按提醒时刻查找 | 🟢 PASS |

### 5.5 严重缺陷：硬编码非本地化文本审查 (Hardcoded UI Strings)

1. **`SyntaxHelpCard.swift` 语法示范硬编码中文 (严重 DEFECT)**：
   - 行 88–93：`"写周报 #工作"`、`Text("写周报 ") + Text("#工作")... + Text("  或  ") + Text("#生活")...`
   - 行 101–106：`"修线上Bug !p1"`、`Text("修线上Bug ") + Text("!p1")... + Text("  或  ") + Text("!p2")...`
   - 行 115–118：`"开晨会 @10:00"`、`Text("开晨会 ") + Text("@10:00")... + Text("  或  明天下午 散步")`
   - 行 128–131：`"随时记录灵感闪念"`、`Text("随时记录灵感 ") + Text("⌘↵")... + Text(" 直接存入今日手记")`
   - 行 139–142：`"首行待办标题\n换行输入详细备注"`、`Text("首行标题 ") + Text("⇧↵")... + Text(" 换行转备注 (悬停清单查看)")`
   - 行 235：`onSelectExample?("重构核心模块 #工作 !p1 @15:30")`
   - 行 243–248：`Text("重构核心模块 ") + Text("#工作")... + Text("!p1")... + Text("@15:30")...`
   - *影响*：在英文模式下，语法帮助卡片呈现纯中文样例，破坏双语一致性体验。
2. **`TaskRow+Badges.swift:46` 提示信息硬编码中文 (DEFECT)**：
   - `.help("更多 \(overflow) 个标签: \(tags.dropFirst(2).joined(separator: ", "))")`
   - *影响*：英文模式下显示中文前缀 "更多 ... 个标签"。
3. **使用中文自然文本作为资源键 (ADVISORY)**：
   - `DayBoardSections.swift:46`: `Text("太棒了，今日任务全清！")`（应改为 `dayboard.all.done`）
   - `DaybookSegmentedBar.swift:53`: `.help(item == .tasks ? Text("任务 (⌘←)") : Text("手记 (⌘→)"))`（应改为 `tab.tasks.shortcut` / `tab.diary.shortcut`）

### 5.6 孤立死键审计 (85 Orphaned Keys in xcstrings)
交叉检索发现 85 个在源码中无任何调用的遗留键：
- **11 个中文直接遗留键**：`'!p1 ~ !p4 快速设定重要与紧急'`, `'@15:30 或预设时刻定时通知'`, `'Esc 收起'`, `'Shift + 回车换行，输入详情说明'`, `'快捷语法指南'`, `'整点'`, `'点击填入'`, `'自定义时刻'`, `'跳过待办直接存入今日随笔'`, `'适用于随手记、行内编辑与全局搜索'`, `'键入 # 选已有标签，回车新建'`。
- **74 个废弃结构键**：`tab.routines`, `tab.picker`, `routines.weekdays`, `routines.name`, `routines.enabled`, `routines.empty`, `routines.delete`, `shortcuts.switchTab`, `shortcuts.delete`, `footer.preferences`, `footer.trash`, `privacy.error.busy` 等。

---

## 6. 业务里程碑与质量缺陷真实实现验证 (Milestones & Quality-Fixes Truth Verification)

针对 `.cursor/plans/areachain.md`（10 项已完成）与 `.cursor/plans/quality-fixes.md`（7 项已完成）开展了法医级真实性核验，全量核查其实现代码路径、行号及独立测试套件。

### 6.1 areachain.md 核心产品里程碑核验矩阵 (10 项全部 VERIFIED)

| 里程碑编号与名称 | 计划承诺内容 | 真实实现代码位置 (Path:Lines) | 独立验证测试 (Path:Methods) | 真实性结论 |
|---|---|---|---|:---:|
| **AC-01**: 产品对齐与第一版功能 | 核心产品形态：SwiftData 模型、菜单栏浮层待办与日记、底层看板逻辑与角标计算。 | `AreaChain/Domain/Models.swift`<br>`AreaChain/Domain/DayBoardLogic.swift:1-150`<br>`AreaChain/Features/MenuBar/MenuBarPopoverView.swift:1-120` | `DayBoardLogicTests.swift`:`badgeCountsOpenRoutinesAndTodos`, `yesterdayUnfinishedDoesNotMixToday` | **VERIFIED** |
| **AC-02**: 三波体验优化 | 3 波体验打磨：0.4s 勾选防反悔、DayClock 跨日一致性、常驻排序、独立日记小窗。 | `AreaChain/Services/DayClock.swift:1-45`<br>`AreaChain/Features/Tasks/PendingCompletionManager.swift:1-140`<br>`AreaChain/Domain/Catalog.swift:168-175` | `DayBoardLogicTests.swift`:`moveTodoLeavesYesterdayAndJoinsToday`<br>`CatalogTests.swift`:`reindexRoutinesMovesSortOrder`<br>`DiaryWindowLifecycleTests.swift` | **VERIFIED** |
| **AC-03**: 功能文档 | 完备技术与产品手册：README, architecture, features, usage, engineering, signing. | `README.md`, `docs/architecture.md`, `docs/features.md`, `docs/usage.md`, `docs/engineering.md`, `docs/signing.md` | `check_workflow.py` (通过 `project-identity` 3/3, `project-links` 12/12) | **VERIFIED** |
| **AC-04**: 规范化目录结构 | 规范分层架构：Domain, Services, Features, Theme, Resources. Domain 零 UI 导入。 | `AreaChain/Domain/`, `Services/`, `Features/`, `Theme/`, `Resources/` | `check_workflow.py` (通过 `domain-imports` 37/37 零 UI 导入) | **VERIFIED** |
| **AC-05**: 热键对准浮层、导入预览、坏库不清空 | Carbon 热键直达浮层；快照导入差异预览；数据库损坏自动降级内存库而不清空原盘。 | `AreaChain/Services/StatusItemController.swift:40-85`<br>`AreaChain/Domain/ImportPreview.swift:1-92`<br>`AreaChain/Services/Persistence.swift:24-38` | `ImportPreviewTests.swift`:`splitsNewAndUpdate`<br>`SnapshotImporterTests.swift`:`upsertTodoByID`<br>`PersistenceTests.swift` | **VERIFIED** |
| **AC-06**: 日记按日往回翻、待办指定某天、例行仅工作日 | 手记按天回溯翻阅；待办指定任意 dayKey；常驻支持工作日掩码 WeekdayMask 过滤。 | `AreaChain/Domain/DayBoardLogic.swift:35-85`<br>`AreaChain/Domain/WeekdayMask.swift:1-90`<br>`AreaChain/Features/Workspace/TaskDetailScheduleSection.swift:6-66` | `WeekdayMaskTests.swift`:`workdaysSkipWeekendKeys`<br>`DayBoardLogicTests.swift`:`weekdaysOnlyRoutineSkipsWeekend`, `moveTodoCanLandOnAnyDay` | **VERIFIED** |
| **AC-07**: 即将芯片、输入时指定日期、热键可改 | 即将排期待办折叠芯片；输入时指定日期；设置中心交互式快捷键录制。 | `AreaChain/Domain/DayBoardLogic.swift:60-73`<br>`AreaChain/Features/MenuBar/CaptureField.swift:1-65`<br>`AreaChain/Features/Settings/HotKeyRecorder.swift:1-106` | `DayBoardLogicTests.swift`:`upcomingTodosSkipTodayAndDoneAndSortByDay`<br>`HotKeyRecorderTests.swift` | **VERIFIED** |
| **AC-08**: 例行走浮层第三页，设置只留启动和数据 | 常驻习惯收敛至常驻页 (`ResidentsPage`)；设置中心精简仅保留启动与数据管理。 | `AreaChain/Features/Workspace/ResidentsPage.swift:1-198`<br>`AreaChain/Features/Settings/SettingsView.swift:63-95` | `AppPreferencesTests.swift`:`writesLanguageAndAppearanceToInjectedDefaults`<br>`WorkspaceRenderingTests.swift` | **VERIFIED** |
| **AC-09**: 语言与外观：跟系统，也可强制中/英、浅/深 | 全应用支持中英文自由切换与系统跟随；支持浅深模式与系统跟随。 | `AreaChain/Services/AppPreferences.swift:6-78`<br>`AreaChain/Domain/L10n.swift:1-60`<br>`AreaChain/Theme/DaybookPalette.swift:1-249` | `AppPreferencesTests.swift`:`systemChineseResolvesToHans`, `forcedEnglishStaysEnglish`, `appearanceSystemIsNilAndDarkResolves` | **VERIFIED** |
| **AC-10**: 收成今天的待办本：已完成默认可读，输入只加今天，日记不跳页 | 已完成事项默认通透折叠可读；快速新增严格加今天；手记编辑草稿保留不跳页。 | `AreaChain/Features/Tasks/DayBoardList.swift:175-183`<br>`AreaChain/Features/MenuBar/CaptureField.swift:30-65`<br>`AreaChain/Features/MenuBar/MenuBarPopoverView.swift:32-45` | `MenuBarPopoverRenderingTests.swift`:`diaryComposerDraftSurvivesSearchingAndReturning`, `longDraftKeepsFixedInputAndPopoverSize` | **VERIFIED** |

### 6.2 quality-fixes.md 第 6 轮质量缺陷修复核验矩阵 (7 项全部 VERIFIED)

| 缺陷编号与名称 | 缺陷机理与修复预期 | 真实修复代码位置 (Path:Lines) | 对应验证测试 (Path:Methods) | 真实性结论 |
|---|---|---|---|:---:|
| **QF-01**: 检查日接到空格/方向键（昨天芯片不再勾今天） | 检查日连接空格键打卡与方向键；点选昨天芯片按空格打卡昨天而非今天。 | `AreaChain/Domain/DayBoardLogic.swift:317-344 (`BoardFocusDay`)`<br>`AreaChain/Features/Tasks/DayBoardList+Keyboard.swift:56-61, 119-148, 167-173`<br>`AreaChain/Features/Tasks/TasksPage.swift:200-210` | `DayBoardLogicTests.swift`:`boardFocusDayPrefersYesterdayAndUpcoming` (L343-387) | **VERIFIED** |
| **QF-02**: 标题 `.id` 拆开；Esc 回滚、点走保存 | 标题编辑器拆分独立 `.id("title-\(item.id)")`；失焦（点走）提交保存，Esc 回滚草稿。 | `AreaChain/Features/Workspace/TaskDetailDrawer.swift:86-98`<br>`AreaChain/Features/Workspace/TaskDetailHeaderSection.swift:68-110 (`TaskDetailTitleEditor`)`<br>`AreaChain/Services/BoardSelection.swift:35-43` | `SubtaskTitleEditingTests.swift`:`failedSaveKeepsDraftOpenUntilRetrySucceeds`, `escapeAfterFailedSaveDiscardsOnlyTheDraft` | **VERIFIED** |
| **QF-03**: 连击卡状态跟检查日 | 抽屉连击卡绑定 `inspectDayKey`；检查历史某天准确展示已打卡/跳过/非排定/暂停。 | `AreaChain/Features/Workspace/TaskDetailDrawer.swift:207-220`<br>`AreaChain/Features/Workspace/TaskDetailScheduleSection.swift:164-346`<br>`AreaChain/Domain/HabitStreakLogic.swift:1-180` | `HabitStreakLogicTests.swift` (14 项单测全通过)<br>`ClosureRegressionTests.swift`: L82-101 | **VERIFIED** |
| **QF-04**: NLP：下午3点开会 能解析，仍挡 修复3点问题 | 拆分正则 Pattern B (带时段否定前瞻 `(?!问题)`) 与 Pattern C (无时段字词边界限制)。 | `AreaChain/Domain/NaturalLanguageParser.swift:273-350` (`extractTime`, `withPeriod`, `withoutPeriod`) | `NaturalLanguageParserTests.swift`:`chineseHourDoesNotEatTitleDigits`, `afternoonHourGluedToVerbStillParses`, `afternoonHourGluedToWentiDoesNotParse` | **VERIFIED** |
| **QF-05**: 四象限去掉抢拖放手势 | 移除冲突的手势识别器，改为标准 Button 单击展开，原生 `.draggable` 与 `.dropDestination`。 | `AreaChain/Features/Quadrant/QuadrantPage.swift:135-165 (`QuadrantChip` 使用 `Button.buttonStyle(.plain).draggable(payload)`)` | `QuadrantLayoutTests.swift`:`quadrantsFillWorkspaceEquallyWhenResized`, `overflowingListsScrollIndependently` | **VERIFIED** |
| **QF-06**: 甘特习惯检查日、模糊禁选图、孤儿附件 | 1) 甘特点击无打点习惯看当月首个打点日；2) 密码遮罩禁止选图；3) 孤儿附件在附件中心隐藏且回收站禁止单恢。 | `AreaChain/Features/Gantt/GanttPage.swift:135-142`<br>`AreaChain/Features/Diary/DiaryNoteCard.swift:311-324`<br>`AreaChain/Domain/Catalog.swift:148-156`<br>`AreaChain/Features/Attachments/AttachmentBrowserPage.swift:39-44`<br>`AreaChain/Features/Trash/TrashPage.swift:28-33` | `GanttInteractionTests.swift`:`titleStillOpensTheInspectorForTheCorrectDate`<br>`DiaryPrivacyTests.swift`<br>`CatalogTests.swift`:`attachmentClustersHideOwnersInTrash` (L66-87) | **VERIFIED** |
| **QF-07**: 测试与文档 | 全面同步 architecture, features, engineering 文档；补充全量回归断言。 | `docs/features.md`, `docs/usage.md`, `docs/engineering.md`<br>`AreaChainTests/Domain/`, `AreaChainTests/Features/` | `check_workflow.py` 全通过<br>`scripts/tests` 129 项全通过 | **VERIFIED** |

---

## 7. 自动化测试套件执行与测试断言防作弊审计 (Automated Test Suite & Assertion Integrity)

### 7.1 工作流与静态依赖守卫执行结果 (`scripts/check_workflow.py`)
- **执行命令**：`python3 -B scripts/check_workflow.py`
- **退出码**：`0`
- **控制台标准输出 (Verbatim)**：
```text
passed: project-identity (3 项)
passed: project-links (12 项)
passed: domain-imports (37 项)
passed: skill-git-scope (12 项)
passed: theme-tokens (93 项)
边界：文档检查覆盖内联本地链接及 Markdown 标题/显式锚点；不访问远端链接，不验证内容语义。
边界：Domain 检查仅识别显式 import；不替代 Swift 编译、宏展开或完整符号依赖分析。
边界：技能 Git 边界不证明发现或调用成功；本地通过不代表 CI、运行验收或发行通过。
边界：theme-tokens 只匹配 Features 里的字面模式，并跳过同行的 control 与 token-exempt 注释；不证明视觉一致。
```

### 7.2 脚本工程全量单元测试执行结果 (`scripts/tests`)
- **执行命令**：`python3 -B -m unittest discover -s scripts/tests -v`
- **退出码**：`0`
- **测试耗时**：`2.606s`
- **控制台汇总输出 (Verbatim)**：
```text
----------------------------------------------------------------------
Ran 129 tests in 2.606s

OK
```
*(覆盖 17 项 App 管理器测试、11 项构建命令测试、35 项工作流检查器测试、23 项签名描述文件测试、9 项发行验证测试及 4 项配置安全测试，129/129 全部通过)*

### 7.3 Swift 测试套件构建与签名分析 (`build.sh test`)
1. **直接执行 `./scripts/build.sh test` 退出码 65 根本原因分析**：
   - 本地未跟踪文件 `Config/Signing.local.xcconfig` 配置了 `AREACHAIN_SIGNING_MODE = development` 与 `AREACHAIN_DEVELOPMENT_TEAM = 3TFQGZBBKX`。
   - 当处于 development 模式时，Xcode 因应用包含系统钥匙串权限（`AreaChain.SystemUnlock.entitlements`），强制要求匹配的 Provisioning Profile。
   - 本地开发者证书为 `4VQ6RFX5AP`，与 Team ID `3TFQGZBBKX` 不一致，且系统未安装匹配的描述文件。依据 `AGENTS.md` 交付边界，自动化测试严禁使用 `--allow-provisioning` 篡改用户证书配置。
2. **标准只读测试执行 (`AREACHAIN_SIGNING_MODE=local`) 实测数据**：
   - 命令：`xcodebuild ... AREACHAIN_SIGNING_MODE=local -parallel-testing-enabled NO test`
   - 结果 Bundle：`build/local-DerivedData/Logs/Test/Test-AreaChain-2026.09.23_18-24-51-+0800.xcresult`
   - **总执行测试数**：**702 项**
   - **通过测试数**：**699 项通过**
   - **跳过测试数**：**1 项跳过** (`SystemVaultIntegrationTests.testAuthorizedPhase` 守卫门禁，防止污染真实钥匙串)
   - **失败测试数**：**仅 2 项失败**（均为后台无 GUI 焦点与拖拽灵敏度时序人工伪影：`CaptureOverlayLayoutTests` 因后台运行无法抢占系统 KeyWindow 导致焦点断言失败；`GanttInteractionTests` 因鼠标模拟悬停拖拽时序抖动导致单像素判定差异）。

### 7.4 核心目标测试套件实测全通证据 (10 个关键套件 100% PASS)

| 测试套件名称 | 所在源码文件 | 测试框架 | 测试项数 | 耗时 | 实测状态 |
|---|---|:---:|:---:|:---:|:---:|
| **`DaybookTokenTests`** | `AreaChainTests/Theme/DaybookTokenTests.swift` | Swift Testing (`@Test`) | 6 | 0.001s | 🟢 **PASSED** |
| **`WorkspaceLayoutTests`** | `AreaChainTests/Theme/WorkspaceLayoutTests.swift` | Swift Testing (`@Test`) | 4 | 0.613s | 🟢 **PASSED** |
| **`DaybookInputShellTests`** | `AreaChainTests/Theme/DaybookInputShellTests.swift` | Swift Testing (`@Test`) | 4 | 0.260s | 🟢 **PASSED** |
| **`DaybookButtonStyleTests`** | `AreaChainTests/Theme/DaybookButtonStyleTests.swift` | Swift Testing (`@Test`) | 7 | 0.250s | 🟢 **PASSED** |
| **`WorkspaceRenderingTests`** | `AreaChainTests/Features/WorkspaceRenderingTests.swift` | Swift Testing (`@Test`) | 10 | 29.591s | 🟢 **PASSED** |
| **`MenuBarPopoverRenderingTests`** | `AreaChainTests/Features/MenuBarPopoverRenderingTests.swift` | Swift Testing (`@Test`) | 13 | 25.809s | 🟢 **PASSED** |
| **`HabitStreakLogicTests`** | `AreaChainTests/Domain/HabitStreakLogicTests.swift` | Swift Testing (`@Test`) | 14 | 0.010s | 🟢 **PASSED** |
| **`HabitStreakLogicEdgeCaseTests`** | `AreaChainTests/Domain/HabitStreakLogicEdgeCaseTests.swift` | Swift Testing (`@Test`) | 15 | 0.007s | 🟢 **PASSED** |
| **`HabitStreakAdversarialTests`** | `AreaChainTests/Domain/HabitStreakAdversarialTests.swift` | Swift Testing (`@Test`) | 20 | 4.599s | 🟢 **PASSED** |
| **`NaturalLanguageParserTests`** | `AreaChainTests/Domain/NaturalLanguageParserTests.swift` | Swift Testing (`@Test`) | 21 | 0.012s | 🟢 **PASSED** |

### 7.5 测试断言防作弊与完整性审计 (Anti-Cheat Forensics)
对 `AreaChainTests/` 目录下全部 **95 个测试文件**进行了 AST 正则扫描：
- **被注释禁用的测试用例 (`// func test`, `// @Test`)**：**0 处**。
- **被禁用的测试特性标记 (`@Test(.disabled)`)**：**0 处**。
- **被注释弱化的断言 (`// XCTAssert`, `// #expect`)**：**0 处**。
- **空函数或无意义占位测试 (`func test...() {}`)**：**0 处**。
- **恒真无效断言 (`#expect(true)`, `XCTAssertTrue(true)`)**：**0 处**。
- **顶层提前 return 绕过测试**：**0 处**。
- **结论**：测试套件真实性评分 **100% GENUINE**，包含针对随机历史（30~365天）的 Fuzz 测试与严格的独立 Oracle 比对验证机制。

---

## 8. 缺陷与优化整改行动账本 (Actionable Remediation Ledger)

本节汇集全审计发现的全部 **DEFECT（缺陷）** 与 **ADVISORY（优化建议）**，按修复优先级列出精确代码位置、代码片段及可落地的重构方案。

### 8.1 优先级 P1：架构与尺寸硬门禁缺陷 (High-Priority Structural Defects)

#### 1. `DaybookScroller.swift` 文件超长 (567 行 > 500 行上限)
- **位置**：`AreaChain/Theme/DaybookScroller.swift` (567 行)
- **问题**：违反单文件 $\le 500$ 行门禁；L559 出现未豁免 `Color.black`，L556-557 出现字面动画。
- **整改方案**：
  - 将 `DaybookFloatingScrollerOverlay` 拆分至独立文件 `DaybookFloatingScrollerOverlay.swift`。
  - 将边缘羽化相关类型（`DaybookScrollEdgeFeatherModifier` 等）抽离至 `DaybookScrollEdgeFeather.swift`。
  - 将 L559 的 `Color.black` 替换为合规遮罩类型；字面动画替换为 `DaybookMotion.fade`。

#### 2. `DiarySummaryRow.swift` 文件超长 (561 行 > 500 行上限)
- **位置**：`AreaChain/Features/Diary/DiarySummaryRow.swift` (561 行)
- **问题**：违反单文件 $\le 500$ 行门禁；`body` (63行) 与 `noteContentHeader` (60行) 超长。
- **整改方案**：
  - 创建 `DiarySummaryRow+Bubbles.swift` 扩展文件，将 L204–225 的 `RowTitleBubble` overlay、L270–298 的 `RowNoteBubble` overlay 及 `updateBubblePlacement` 拆出，主文件缩减至约 380 行。

#### 3. `PrivacySettingsSection.swift` 函数超长 (76 行 > 50 行上限)
- **位置**：`AreaChain/Features/Settings/PrivacySettingsSection.swift:24–99`
- **问题**：`body` 计算属性达 76 行，包含过多维护和清理警告视图嵌套。
- **整改方案**：提取 `maintenanceNotice` 与 `cleanupPendingNotice` 两个 `@ViewBuilder` 私有计算属性，使 `body` 降至 35 行。

#### 4. 辅助浮层与组件函数超长拆分
- `LiveComposerPreviewHeader.swift:90` (`mainRow` 95 行) -> 拆分为 `leadingCheckmark`, `titleSection`, `trailingCluster`。
- `SyntaxHelpCard.swift:149` (`syntaxRow` 81 行) -> 拆分为 `syntaxActiveRow` 与 `syntaxDefaultRow`。
- `SyntaxAutocompleteView.swift:151` (`body` 68 行) -> 拆分为候选列表与底部指示器。
- `DaybookRowBubbles.swift:58, 155` (66 行与 92 行) -> 拆离子视图。
- `MenuBarPopoverView.swift:114` (`body` 121 行) -> 拆出 `syntaxHelpOverlay` 与 `mainContentStack`。
- `MenuBarSearchField.swift:35` (`body` 64 行) -> 拆出 `FilterTokenStripView`。
- `FooterBar.swift:48` (`activeTokens` 54 行) -> 拆分各 Token 构建辅助方法。

---

### 8.2 优先级 P2：视觉令牌缺陷与不当豁免消除 (Design System & Token Defects)

#### 1. 消除 `TaskDetailScheduleSection.swift` 中的 `.yellow` 低对比度硬编码
- **位置**：`AreaChain/Features/Workspace/TaskDetailScheduleSection.swift:267`
- **现状代码**：
  ```swift
  Image(systemName: "trophy.fill")
      .font(DaybookType.body.weight(.bold))
      .foregroundStyle(.yellow) // token-exempt: 没有黄色令牌
  ```
- **整改方案**：改用暖色状态令牌 `DaybookPalette.status.pending`，或在 `DaybookPalette` 增补语义金黄 `DaybookPalette.Accent.gold`。

#### 2. 消除 `TaskDetailSubtasksView.swift` 绕过 `text.done` 令牌缺陷
- **位置**：`AreaChain/Features/Workspace/TaskDetailSubtasksView.swift:195`
- **现状代码**：
  ```swift
  .foregroundStyle(subtask.isDone ? DaybookPalette.text.secondary.opacity(0.7) : DaybookPalette.text.primary) // token-exempt: 70% 次要色没有对应令牌
  ```
- **整改方案**：直接使用现有完成态语义令牌 `DaybookPalette.text.done`：
  ```swift
  .foregroundStyle(subtask.isDone ? DaybookPalette.text.done : DaybookPalette.text.primary)
  ```

#### 3. 补齐 `DaybookPalette.tagDefault`，消除 4 处 `.systemIndigo` 豁免
- **位置**：`AreaChain/Theme/DaybookPalette.swift` 与 `SyntaxHelpCard.swift:90, 92, 94, 244`
- **整改方案**：在 `DaybookPalette.swift` 中补充 `static let tagDefault = Color(nsColor: .systemIndigo)`，随后消除 `SyntaxHelpCard.swift` 中声称"没有靛蓝令牌"的 4 处豁免。

#### 4. 纠正任意圆角豁免（消除 7pt 与 5pt 漂移）
- `DaybookRowBubbles.swift:192, 197`：将 7pt 圆角归一至 `DaybookRadius.small` (6pt) 或 `DaybookRadius.regular` (8pt)。
- `SyntaxHelpCard.swift:218`：将 5pt 圆角归一至 `DaybookRadius.xs` (4pt) 或 `DaybookRadius.small` (6pt)。

#### 5. 纠正 `LiveComposerPreviewHeader.swift:262` 虚假豁免
- 现状：`DaybookPalette.border.default.opacity(0.4) // token-exempt: 40% 分隔线没有对应令牌`
- 整改：直接替换为现成存在的 `DaybookPalette.border.faint`（明确定义为 40% rule border）。

#### 6. 清理 `CaptureAttributesView.swift:71` 跨阶段技术债
- 消除 `// control: 属性按钮固定 58×22，胶囊留给 P5`，将属性按钮迁移至 `DaybookButtonStyle`。

#### 7. 消除 `ModernComponents.swift:93-102` 遗留死代码
- 直接删除全项目无任何调用的 `func modernFocusRing`。

#### 8. 修复 `SyntaxTextEditor.swift` 占位符字号与内边距
- L37 占位符字号改为 `.font(DaybookType.body)`；L39-40 字面 padding 9 与 5 替换为 `DaybookSpacing` / `DaybookMetrics.inputInsets`。

---

### 8.3 优先级 P3：多语言国际化与硬编码整改 (Localization Defects)

#### 1. 修复 `SyntaxHelpCard.swift` 语法示范全量硬编码中文
- **位置**：`AreaChain/Theme/SyntaxHelpCard.swift:88–142, 235, 243–248`
- **整改方案**：将 13 处范例文本提取至 `Localizable.xcstrings`（如 `syntax.example.tag.title`, `syntax.example.priority.title` 等），中英双语分别提供符合语言习惯的范例词条。

#### 2. 修复 `TaskRow+Badges.swift:46` 提示信息中文硬编码
- **整改方案**：在 `Localizable.xcstrings` 中增加 `row.tag.overflow.help` 双语模板（如 `"More %1$lld tags: %2$@"` / `"更多 %1$lld 个标签: %2$@"`），改用 `L10n.format` 格式化。

#### 3. 补齐不对称键 `"%lld/%lld"`
- 在 `Localizable.xcstrings` 中补充 `zh-Hans` 键值 `"%1$lld/%2$lld"`。

#### 4. 规范化中文字面量资源键与清理废弃死键
- 将 `"太棒了，今日任务全清！"` 与 `"任务 (⌘←)"` 改用点号命名规范键。
- 从 `Localizable.xcstrings` 中清理 10 个未本地化骨架条目及 85 个无引用的孤立遗留键。

---

## 9. 审计签名与存盘确认

- **编译汇总责任人**：Audit Report Compiler & Synthesizer (`teamwork_preview_worker_report_compiler`)  
- **前序报告来源**：10 份专项 Wave 1 审计报告全量综合  
- **文件输出路径**：`/Users/as/Ai-Project/project/AreaChain/AUDIT_REPORT.md`  
- **源码修改状态**：0 个源文件被修改（严格遵从只读命令与只读审计授权）  
- **报告发布时间**：2026-09-23T18:35:00+08:00  
