# 任务：AreaChain 设计系统收敛 · 阶段 P1（删除双宿主分支）· 执行提示词

## 你是谁、怎么工作

你是这个 macOS 原生项目（SwiftUI + AppKit + SwiftData）的执行工程师。设计已完成，**你只负责照做**。规则：

1. 严格按步骤顺序执行；每个"检查点"必须跑通再进下一步；修不好就停下来问我。
2. 每一处替换都给了"改前 → 改后"。用**精确字符串查找**定位，行号只是提示（编辑后行号会变，不要信行号）。
3. 只改本文列出的文件。别的文件"看起来也该改"，记到汇报里，不动手。
4. 不 `git commit` / `git push` / 安装 / 发布；不删测试、不注释测试。
5. 先读 `AGENTS.md`，再读 `.cursor/plans/design-system.md` 第 0、1、2、5 节，再读本文。不读其他文档，不全仓库扫描。
6. 没写清楚的取舍 → 用提问工具问我，复述我的回答，我说"对"才继续。
7. 做完不宣布"通过"，只按"汇报格式"交证据；验收由另一个对话按 `design-system-P1-verify.md` 做。

## 背景

P0 已建好令牌层（`DaybookPalette` / `DaybookMetrics` / `DaybookElevation` / `DaybookTokens` / `WorkspaceLayout`）。现在代码里还有一套"双宿主"机制：`DaybookViewStyle`（`.standard` / `.workspace`）通过环境注入，52 处 `style.isWorkspace ? A : B` 三元和 56 处 `WorkspaceStyle.*` 引用让工作台长得和菜单栏不一样。**用户已决定：两宿主外观完全统一，以菜单栏为基准。** 本阶段删掉这套机制。

## 分支处理规则（本阶段的核心，先读懂）

代码里的 `isWorkspace` 分支分两类，处理方式不同：

**A. 视觉分支**——两边只是颜色 / 字体 / 圆角 / 阴影 / 内边距不同。
→ **取 `false` 那一侧（标准侧 / 菜单栏侧）**，删掉工作台侧。`isWorkspace ? W : S` 改成 `S`；`if isWorkspace { A } else { B }` 改成 `B`；`if isWorkspace { A }` 没有 else 的直接删掉 A。

**B. 能力分支**——两边显示的东西不同，原因是工作台有侧栏和页头、没有底栏；或独立窗口需要最小尺寸；或工作台行更宽能放两行。
→ 改用新的布尔环境值 `embedded`（`@Environment(\.workspaceEmbedded)`），逻辑不变。**`embedded` 只能出现在"显示什么 / 布局多大"的判断里，禁止出现在颜色、字体、圆角、阴影的判断里。**

下面每一处我都已经标好了 A 还是 B，你不需要自己判断。

**`WorkspaceStyle.*` 单独出现（没有三元）时的映射表**：

| 旧 | 新 |
|---|---|
| `WorkspaceStyle.paper` | `DaybookPalette.fill.page` |
| `WorkspaceStyle.surface` | `DaybookPalette.fill.surface` |
| `WorkspaceStyle.input` | `DaybookPalette.fill.subtle` |
| `WorkspaceStyle.border` | `DaybookPalette.border.default` |
| `WorkspaceStyle.hover` | `DaybookPalette.fill.hover` |
| `WorkspaceStyle.selection` | `DaybookPalette.fill.selection` |
| `WorkspaceStyle.cardRadius` | `DaybookRadius.regular` |
| `WorkspaceStyle.countFont` | `DaybookType.caption.monospacedDigit()` |
| `WorkspaceStyle.controlHeight` | `DaybookMetrics.controlHeight` |

`style.pageBackground` 单独出现 → `DaybookPalette.fill.page`。`style.cardSurface / cardBorder / hoverFill / selectionFill / doneText` 单独出现 → 分别 `DaybookTheme.cardSurface / cardBorder / hoverFill / cardSelectionFill / done`。

## 开始前必读

1. `AreaChain/Theme/DaybookWorkspaceStyle.swift` 全文（175 行）——这是要删的文件。
2. `AreaChain/Theme/WorkspaceLayout.swift` 全文（165 行）。
3. `AreaChain/Theme/ModernComponents.swift` 全文（371 行）。
4. `AreaChain/Features/Tasks/TaskRow.swift` 第 1–20、150–225、360–410 行。
5. `AreaChainTests/Theme/WorkspaceStyleTests.swift` 全文（150 行）——要重写。

基线（必须绿）：

```bash
./scripts/build.sh test --only-testing AreaChainTests/DaybookTokenTests --only-testing AreaChainTests/WorkspaceStyleTests --only-testing AreaChainTests/WorkspaceRenderingTests
```

---

## 步骤 1：新增 `workspaceEmbedded` 环境键

打开 `AreaChain/Theme/WorkspaceLayout.swift`。在 `enum WorkspaceLayout { ... }` 的结束花括号之后、`// MARK: - 以下三个组件…` 注释之前，插入：

```swift

/// 只表示"当前视图嵌在三栏工作台里"。仅用于能力 / 布局分支：是否显示页内筛选条、独立窗口最小尺寸、页头最小高度、行数、气泡宿主宽度。
/// 禁止用它切换颜色、字体、圆角、阴影——那些一律走令牌，两宿主相同。
private struct WorkspaceEmbeddedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var workspaceEmbedded: Bool {
        get { self[WorkspaceEmbeddedKey.self] }
        set { self[WorkspaceEmbeddedKey.self] = newValue }
    }
}
```

检查点：`./scripts/build.sh` 通过。

---

## 步骤 2：Theme 层去分支

### 2.1 `AreaChain/Theme/WorkspaceLayout.swift`

`DaybookPageHeader` 里：

- `@Environment(\.daybookViewStyle) private var style` → `@Environment(\.workspaceEmbedded) private var embedded`
- 把整个 `var body` 替换为（A + B 混合：对齐/间距取标准侧，页头最小高度是布局能力）：

```swift
    var body: some View {
        HStack(alignment: .bottom, spacing: DaybookSpacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                title.accessibilityAddTraits(.isHeader)
                subtitle
            }
            .frame(minHeight: embedded ? WorkspaceLayout.headerHeight : nil, alignment: .topLeading)
            Spacer(minLength: 0)
            trailing
        }
        .accessibilityIdentifier("workspace.page.header")
    }
```

`WorkspaceSidebarHeaderAction` 里：`.fill(isHovered ? WorkspaceStyle.hover : Color.clear)` → `.fill(isHovered ? DaybookPalette.fill.hover : Color.clear)`

`WorkspaceSidebarRow` 里：
- `.font(WorkspaceStyle.countFont)` → `.font(DaybookType.caption.monospacedDigit())`
- `return WorkspaceStyle.selection` → `return DaybookPalette.fill.selection`
- `return WorkspaceStyle.hover` → `return DaybookPalette.fill.hover`

### 2.2 `AreaChain/Theme/DaybookTheme.swift`（`SectionStamp`，A）

- 删除 `@Environment(\.daybookViewStyle) private var style`
- `.font(style.isWorkspace ? WorkspaceStyle.sectionFont : DaybookType.section)` → `.font(DaybookType.section)`
- `.tracking(style.isWorkspace ? 0 : 0.5)` → `.tracking(0.5)`
- `.font(style.isWorkspace ? WorkspaceStyle.countFont : .system(size: 10, weight: .bold, design: .rounded))` → `.font(.system(size: 10, weight: .bold, design: .rounded))`

### 2.3 `AreaChain/Theme/DaybookChrome.swift`（A）

`DaybookQuietButton`（约 69–111 行）：
- 删除 `@Environment(\.daybookViewStyle) private var style`
- `.scaleEffect(configuration.isPressed && !style.isWorkspace ? 0.97 : 1.0)` → `.scaleEffect(configuration.isPressed ? 0.97 : 1.0)`
- `if hovering && isEnabled { return style.hoverFill }` → `if hovering && isEnabled { return DaybookTheme.hoverFill }`

`DaybookCardModifier`（约 256–297 行）：
- 删除 `@Environment(\.daybookViewStyle) private var style`
- `return style.isWorkspace ? WorkspaceStyle.surface : DaybookTheme.cardSurfaceHover` → `return DaybookTheme.cardSurfaceHover`
- `return style.cardSurface` → `return DaybookTheme.cardSurface`
- `return style.isWorkspace ? WorkspaceStyle.border.opacity(0.85) : DaybookTheme.cardBorderHover` → `return DaybookTheme.cardBorderHover`
- `return style.cardBorder` → `return DaybookTheme.cardBorder`

### 2.4 `AreaChain/Theme/DaybookPage.swift`（A + B）

- `@Environment(\.daybookViewStyle) private var style` → `@Environment(\.workspaceEmbedded) private var embedded`
- `maxWidth: (style.isWorkspace && !fullWidth) ? WorkspaceLayout.maxContentWidth : .infinity,` → `maxWidth: (embedded && !fullWidth) ? WorkspaceLayout.maxContentWidth : .infinity,`（B）
- `minWidth: style.isWorkspace ? 0 : minWidth,` → `minWidth: embedded ? 0 : minWidth,`（B）
- `minHeight: style.isWorkspace ? 0 : minHeight,` → `minHeight: embedded ? 0 : minHeight,`（B）
- `.background(style.pageBackground)` → `.background(DaybookPalette.fill.page)`（A）
- `case .entity: style.isWorkspace ? DaybookType.title : DaybookType.entity` → `case .entity: DaybookType.entity`（A）

### 2.5 `AreaChain/Theme/ModernComponents.swift`（全部 A）

`ModernCheckbox`：删除 `@Environment(\.daybookViewStyle) private var style`；`return style.isWorkspace ? WorkspaceStyle.control : DaybookTheme.ink.opacity(0.24)` → `return DaybookTheme.ink.opacity(0.24)`

`PillBadge`：删除 `@Environment(\.daybookViewStyle) private var style`；两处 `.font(style.isWorkspace ? DaybookType.caption : DaybookType.badge)` → `.font(DaybookType.badge)`

`ModernCardModifier`：删除 `@Environment(\.daybookViewStyle) private var style`；把 `shadowColor` / `backgroundFill` / `borderStroke` 三个计算属性整体替换为：

```swift
    private var shadowColor: Color {
        if isSelected {
            return DaybookTheme.stamp.opacity(0.18)
        }
        return DaybookElevation.raised.color
    }

    private var backgroundFill: Color {
        if isSelected {
            return DaybookTheme.cardSelectionFill
        }
        if isHovered {
            return DaybookTheme.cardSurfaceHover
        }
        return DaybookTheme.cardSurface
    }

    private var borderStroke: Color {
        if isSelected {
            return DaybookTheme.stamp.opacity(0.85)
        }
        if isHovered {
            return DaybookTheme.cardBorderHover
        }
        return DaybookTheme.cardBorder
    }
```

`DaybookGroupedCard`（用户决定：工作台不再有白卡容器）：删除 `@Environment(\.daybookViewStyle) private var style`；把 `var body` 整体替换为：

```swift
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            content
        }
    }
```

`ModernRowModifier`：删除 `@Environment(\.daybookViewStyle) private var style`；把 `func body` / `backgroundFill` / `borderStroke` 整体替换为：

```swift
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderStroke, lineWidth: isSelected ? 1.0 : 0)
            )
            .animation(DaybookMotion.interactive(reduceMotion), value: isHovered)
            .animation(DaybookMotion.interactive(reduceMotion), value: isSelected)
    }

    private var backgroundFill: Color {
        if isSelected {
            return DaybookTheme.cardSelectionFill
        }
        if isHovered {
            return DaybookTheme.hoverFill
        }
        return Color.clear
    }

    private var borderStroke: Color {
        if isSelected {
            return DaybookTheme.cardSelectionStroke
        }
        if isHovered {
            return DaybookTheme.rule.opacity(0.35)
        }
        return Color.clear
    }
```

`ModernTaskTitle`：删除 `@Environment(\.daybookViewStyle) private var style`；三处 `style.doneText` → `DaybookTheme.done`

### 2.6 气泡定位参数改名（`isWorkspace:` → `wideHost:`，B）

```bash
sed -i '' 's/isWorkspace: Bool = false/wideHost: Bool = false/; s/let safeMaxX: CGFloat = isWorkspace ? 700 : 356/let safeMaxX: CGFloat = wideHost ? 700 : 356/' AreaChain/Theme/DaybookRowBubbles.swift
sed -i '' 's/isWorkspace: false/wideHost: false/g' AreaChain/Theme/LiveComposerPreviewHeader.swift AreaChain/Theme/LiveDiaryComposerPreview.swift AreaChain/Features/Diary/DiarySummaryRow.swift AreaChainTests/Features/DiarySummaryRowTests.swift
```

检查：`rg -n 'isWorkspace' AreaChain/Theme/DaybookRowBubbles.swift AreaChain/Theme/LiveComposerPreviewHeader.swift AreaChain/Theme/LiveDiaryComposerPreview.swift AreaChain/Features/Diary/DiarySummaryRow.swift AreaChainTests/Features/DiarySummaryRowTests.swift` 预期零输出。

检查点：`./scripts/build.sh` 通过（此时 `DaybookViewStyle` 仍存在，所以能编译）。

---

## 步骤 3：把 `DaybookInputKind` 与 `DaybookInputChrome` 搬到 `DaybookChrome.swift` 并去分支

在 `AreaChain/Theme/DaybookChrome.swift` **文件末尾**追加（这是 `DaybookWorkspaceStyle.swift` 67–124 行 + 164–167 行去掉分支后的版本；P2 会用 `DaybookInputShell` 取代它）：

```swift

// MARK: - 输入外框（从 DaybookWorkspaceStyle.swift 搬入并去掉宿主分支；P2 由 DaybookInputShell 取代）

enum DaybookInputKind: Equatable {
    case composer
    case search
    case editor
}

private struct DaybookInputChrome: ViewModifier {
    var focused: Bool
    var kind: DaybookInputKind

    func body(content: Content) -> some View {
        content
            .padding(insets)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(focused ? DaybookTheme.focusRing : border, lineWidth: borderWidth)
            )
    }

    private var insets: EdgeInsets {
        switch kind {
        case .composer: EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        case .search: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        case .editor: EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
        }
    }

    private var borderWidth: CGFloat {
        kind == .search ? (focused ? 1.6 : 1) : (focused ? 1.4 : 0.8)
    }

    private var radius: CGFloat {
        kind == .search ? DaybookRadius.medium : DaybookRadius.small
    }

    private var fill: Color {
        if kind == .composer && !focused { return DaybookTheme.hoverFill.opacity(0.75) }
        return DaybookTheme.surface
    }

    private var border: Color {
        kind == .search ? DaybookTheme.rule : DaybookTheme.cardBorder
    }
}

extension View {
    func daybookInputChrome(focused: Bool, kind: DaybookInputKind) -> some View {
        modifier(DaybookInputChrome(focused: focused, kind: kind))
    }
}
```

然后在 `AreaChain/Theme/DaybookWorkspaceStyle.swift` 里**删除**：`enum DaybookInputKind { ... }`、`private struct DaybookInputChrome { ... }`、以及 `extension View { ... }` 里的 `daybookInputChrome` 函数（保留同一 extension 里的 `workspaceFilterChrome`，步骤 6 一起删）。

检查点：`./scripts/build.sh` 通过。

---

## 步骤 4：Features 去分支（按文件）

### 4.1 `Features/Calendar/CalendarPage.swift`
- `@Environment(\.daybookViewStyle) private var style` → `@Environment(\.workspaceEmbedded) private var embedded`
- `compactLayout(compactDates: style.isWorkspace && geometry.size.height < 560)` → `compactLayout(compactDates: embedded && geometry.size.height < 560)`（B）
- `.frame(minWidth: style.isWorkspace ? 0 : 420, maxWidth: .infinity, minHeight: style.isWorkspace ? 0 : 560, maxHeight: .infinity, alignment: .topLeading)` → `.frame(minWidth: embedded ? 0 : 420, maxWidth: .infinity, minHeight: embedded ? 0 : 560, maxHeight: .infinity, alignment: .topLeading)`（B）
- `.background(style.pageBackground)` → `.background(DaybookPalette.fill.page)`（A）
- `if !style.isWorkspace {` → `if !embedded {`（B，月份导航条在工作台由页头承担）

### 4.2 `Features/Diary/DiaryNoteCard.swift`（A；同文件 `DiaryTagChrome` 不动）
- 删除 `@Environment(\.daybookViewStyle) var viewStyle`
- 两处 `cornerRadius: viewStyle.isWorkspace ? WorkspaceStyle.cardRadius : DaybookRadius.medium` → `cornerRadius: DaybookRadius.medium`
- `.fill(isHovered ? (viewStyle.isWorkspace ? WorkspaceStyle.hover : DaybookTheme.cardSurfaceHover) : viewStyle.cardSurface)` → `.fill(isHovered ? DaybookTheme.cardSurfaceHover : DaybookTheme.cardSurface)`
- `(isHovered ? DaybookTheme.cardBorderHover : viewStyle.cardBorder)` → `(isHovered ? DaybookTheme.cardBorderHover : DaybookTheme.cardBorder)`

### 4.3 `Features/Diary/DiaryCardComponents.swift`（A；它是 `DiaryNoteCard` 的 extension，用的是上面那个 `viewStyle`）
- `.font(viewStyle.isWorkspace ? WorkspaceStyle.countFont : DaybookType.caption.monospaced())` → `.font(DaybookType.caption.monospaced())`

### 4.4 `Features/Diary/DiaryPage.swift`
- `@Environment(\.daybookViewStyle) private var style` → `@Environment(\.workspaceEmbedded) private var embedded`
- `if !style.isWorkspace { tagFilterBar }` → `if !embedded { tagFilterBar }`（B）
- `if showsPageHeader && style.isWorkspace { tagFilterBar }` → `if showsPageHeader && embedded { tagFilterBar }`（B）
- `.font(WorkspaceStyle.countFont)` → `.font(DaybookType.caption.monospacedDigit())`（A）
- `filterPill`（约 285–295 行）里的 `Button(action: action) { if style.isWorkspace { WorkspaceFilterLabel(...) {...} } else { standardFilterLabel(...) } }` → 整个 `if/else` 替换为一行 `standardFilterLabel(title: title, count: count, isSelected: isSelected, color: color)`（A）

### 4.5 `Features/Diary/DiaryQuickComposerView.swift`（全部 A）
- 删除 `@Environment(\.daybookViewStyle) private var style`
- `workspaceComposer`：整个 `if style.isWorkspace { ... } else { ... }` 替换为 else 分支内容：

```swift
    @ViewBuilder
    private var workspaceComposer: some View {
        composerContent
            .padding(10)
            .background(RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                .fill(DaybookTheme.hoverFill.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                .strokeBorder(DaybookTheme.cardBorder, lineWidth: 0.8))
            .fixedSize(horizontal: false, vertical: true)
    }
```

- `editorInputView` 末尾：`if style.isWorkspace { editor } else { editor.daybookInputChrome(focused: focused.wrappedValue, kind: .editor) }` → `editor.daybookInputChrome(focused: focused.wrappedValue, kind: .editor)`
- `submitButton`：`if style.isWorkspace { ComposerAddButton(...).keyboardShortcut(.return, modifiers: .command) } else { standardSubmitButton }` → `standardSubmitButton`

### 4.6 `Features/Diary/DiaryStandaloneView.swift`
- `@Environment(\.daybookViewStyle) private var style` → `@Environment(\.workspaceEmbedded) private var embedded`
- `.frame(minWidth: style.isWorkspace ? 0 : 360, maxWidth: .infinity, minHeight: style.isWorkspace ? 0 : 420, maxHeight: .infinity, alignment: .topLeading)` → `.frame(minWidth: embedded ? 0 : 360, maxWidth: .infinity, minHeight: embedded ? 0 : 420, maxHeight: .infinity, alignment: .topLeading)`（B）
- `.background(style.pageBackground)` → `.background(DaybookPalette.fill.page)`（A）

### 4.7 `Features/Quadrant/QuadrantPage.swift`
- `@Environment(\.daybookViewStyle) private var style` → `@Environment(\.workspaceEmbedded) private var embedded`
- `if style.isWorkspace {`（GeometryReader 那一处）→ `if embedded {`（B，工作台里格子撑满高度）

### 4.8 `Features/Search/BoardSearchHitRow.swift`（A，按映射表）
- 两处 `RoundedRectangle(cornerRadius: WorkspaceStyle.cardRadius)` → `RoundedRectangle(cornerRadius: DaybookRadius.regular)`
- `.fill(isSelected ? WorkspaceStyle.selection : WorkspaceStyle.surface)` → `.fill(isSelected ? DaybookPalette.fill.selection : DaybookPalette.fill.surface)`
- `: WorkspaceStyle.border, lineWidth: 0.8)` → `: DaybookPalette.border.default, lineWidth: 0.8)`

### 4.9 `Features/Tasks/BoardFilterBar.swift`（A）
- 删除 `@Environment(\.daybookViewStyle) private var style`（约第 5 行）
- 删除调用处那一行 `style: style`（约第 133 行，在 `BoardFilterDropdownButton(` 的参数列表里；删掉后注意上一行末尾的逗号是否需要去掉）
- 删除 `var style: DaybookViewStyle`（约第 184 行）
- `Group { if style.isWorkspace { workspaceCapsule } else { standardCapsule } }` → `standardCapsule`（保留后面的 `.popover(...)` 链）
- 删除整个 `private var workspaceCapsule: some View { ... }`（约 254–293 行，从 `private var workspaceCapsule` 到 `private var dropdownPopoverContent` 之前的最后一个 `}`）

### 4.10 `Features/Tasks/DaybookProgressRing.swift`（A）
- 删除 `@Environment(\.daybookViewStyle) private var style`
- `.stroke(style.isWorkspace ? WorkspaceStyle.border : DaybookTheme.rule.opacity(0.35), lineWidth: lineWidth)` → `.stroke(DaybookTheme.rule.opacity(0.35), lineWidth: lineWidth)`
- `.font(style.isWorkspace ? WorkspaceStyle.progressFont : .system(size: 10, weight: .bold, design: .rounded))` → `.font(.system(size: 10, weight: .bold, design: .rounded))`

### 4.11 `Features/Tasks/TaskRow.swift`
- `@Environment(\.daybookViewStyle) var style` → `@Environment(\.workspaceEmbedded) var embedded`
- `.frame(minHeight: style.isWorkspace ? WorkspaceStyle.rowHeight : 36)` → `.frame(minHeight: DaybookMetrics.rowHeight)`（A）
- `hasVisibleNote` 里 `if style.isWorkspace {` → `if embedded {`（B，工作台行内显示备注摘要）
- `shouldShowTitleBubble` 里 `!style.isWorkspace && !editing` → `!embedded && !editing`（B）
- `shouldShowNoteBubble` 里 `!style.isWorkspace && !editing` → `!embedded && !editing`（B）
- `if !style.isWorkspace, fullNoteText != nil {` → `if !embedded, fullNoteText != nil {`（B）
- `isWorkspace: style.isWorkspace` → `wideHost: embedded`（B）
- `.lineLimit(style.isWorkspace ? 2 : 1)` → `.lineLimit(embedded ? 2 : 1)`（B）
- `titleContent` 里 `if style.isWorkspace {`（备注摘要那一处）→ `if embedded {`（B）

### 4.12 `Features/Tasks/TaskRow+Badges.swift`（全部 A；`style` 来自 TaskRow.swift，已改名，这里只需消掉引用）
- `.font(style.isWorkspace ? WorkspaceStyle.countFont : .system(size: 9.5, weight: .semibold))` → `.font(.system(size: 9.5, weight: .semibold))`
- `.foregroundStyle(isHighlighted ? Color.orange : DaybookTheme.muted.opacity(style.isWorkspace ? 1 : 0.75))` → `.foregroundStyle(isHighlighted ? Color.orange : DaybookTheme.muted.opacity(0.75))`
- `.font(style.isWorkspace ? WorkspaceStyle.countFont : .system(size: 10, weight: .bold, design: .rounded))` → `.font(.system(size: 10, weight: .bold, design: .rounded))`
- 三处 `DaybookTheme.muted.opacity(style.isWorkspace ? 1 : 0.75)` → `DaybookTheme.muted.opacity(0.75)`（分别在 `isHighlighted ? DaybookTheme.ink :` 两处和 `isHighlighted ? DaybookTheme.stamp :` 一处之后）
- `.font(style.isWorkspace ? WorkspaceStyle.countFont : .system(size: 10, weight: .medium, design: .rounded))` → `.font(.system(size: 10, weight: .medium, design: .rounded))`
- `.opacity(style.isWorkspace || isHovered || state.isSelected ? 1.0 : 0.65)` → `.opacity(isHovered || state.isSelected ? 1.0 : 0.65)`

### 4.13 `Features/Tasks/TasksPage.swift` / `TasksPage+Header.swift`
- `TasksPage.swift`：`@Environment(\.daybookViewStyle) var style` → `@Environment(\.workspaceEmbedded) var embedded`
- `TasksPage+Header.swift`：`let hasFilters = style.isWorkspace` → `let hasFilters = embedded`（B）；`if style.isWorkspace {`（`BoardFilterBar(` 上一行）→ `if embedded {`（B）

### 4.14 `Features/Tasks/TasksPage+Sections.swift`（A）
- 删除 `@Environment(\.daybookViewStyle) private var style`
- `chip(_:)` 里 `Button(action: config.action) { if style.isWorkspace { WorkspaceFilterLabel(...) {...} } else { standardChipLabel(config) } }` → 整个 `if/else` 替换为一行 `standardChipLabel(config)`

### 4.15 `Features/Workspace/TaskDetailDrawer.swift`
- 第一个 `@Environment(\.daybookViewStyle) private var style`（`TaskDetailDrawer` 里，约第 9 行）→ 删除
- `.background { if style.isWorkspace { WorkspaceStyle.surface } else { ZStack { ... } } }` → 保留 else 内容（A）：

```swift
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                DaybookTheme.paper.opacity(0.4)
            }
        }
```

（如果原 else 块里 `ZStack` 后面还有别的修饰符，一并保留。）

- 第二个 `@Environment(\.daybookViewStyle) private var style`（`DrawerSectionGroup` 里，约第 207 行）→ 删除
- `.font(style.isWorkspace ? WorkspaceStyle.sectionFont : .system(size: 10.5, weight: .semibold))` → `.font(.system(size: 10.5, weight: .semibold))`（A）
- `.textCase(style.isWorkspace ? nil : .uppercase)` → **整行删除**（用户决定：分节标题一律不大写）
- `.tracking(style.isWorkspace ? 0 : 0.5)` → `.tracking(0.5)`（A）
- `.fill(style.isWorkspace ? WorkspaceStyle.paper : DaybookTheme.cardSurface.opacity(0.65))` → `.fill(DaybookTheme.cardSurface.opacity(0.65))`（A）
- `.strokeBorder(style.cardBorder, lineWidth: 0.8)` → `.strokeBorder(DaybookTheme.cardBorder, lineWidth: 0.8)`（A）

### 4.16 `Features/Workspace/WorkspaceGlobalSearchView.swift`（A，映射表）
- `.background(WorkspaceStyle.paper)` → `.background(DaybookPalette.fill.page)`
- 两处 `RoundedRectangle(cornerRadius: WorkspaceStyle.cardRadius)` → `RoundedRectangle(cornerRadius: DaybookRadius.regular)`
- `.fill(WorkspaceStyle.surface)` → `.fill(DaybookPalette.fill.surface)`
- `.strokeBorder(WorkspaceStyle.border, lineWidth: 0.8)` → `.strokeBorder(DaybookPalette.border.default, lineWidth: 0.8)`

### 4.17 `Features/Workspace/WorkspaceHeaderBar.swift`（A）
- `WorkspaceStyle.input.opacity(0.85)` → `DaybookPalette.fill.subtle`

### 4.18 `Features/Workspace/MainSplitWorkspaceView.swift`
- `.environment(\.daybookViewStyle, .workspace)` → `.environment(\.workspaceEmbedded, true)`

检查点：

```bash
rg -n 'daybookViewStyle|isWorkspace|WorkspaceStyle\.|WorkspaceFilterLabel|workspaceCapsule|style\.(pageBackground|cardSurface|cardBorder|hoverFill|selectionFill|doneText)' AreaChain
```

预期**只剩** `AreaChain/Theme/DaybookWorkspaceStyle.swift` 内部的行。有其他文件出现 → 回去补改。然后 `./scripts/build.sh` 通过。

---

## 步骤 5：删除 `AreaChain/Theme/DaybookWorkspaceStyle.swift`

此时该文件只剩 `DaybookViewStyle`、环境键、`WorkspaceSwatch`、`WorkspaceStyle`、`WorkspaceFilterLabel`、`WorkspaceFilterChrome`、`workspaceFilterChrome`——全部没有消费者了。**整个文件删除**：

```bash
git rm -q AreaChain/Theme/DaybookWorkspaceStyle.swift
```

（工程用文件系统同步组，删文件不需要改 `project.pbxproj`。）

检查点：`./scripts/build.sh` 通过。编译报错说明还有引用漏了，用报错定位补改。

---

## 步骤 6：测试改造

### 6.1 删除 `AreaChainTests/Theme/WorkspaceStyleTests.swift`，新建 `AreaChainTests/Theme/WorkspaceLayoutTests.swift`

```bash
git rm -q AreaChainTests/Theme/WorkspaceStyleTests.swift
```

新建 `AreaChainTests/Theme/WorkspaceLayoutTests.swift`，内容：

```swift
import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct WorkspaceLayoutTests {
    @Test func nativeFieldKeepsTheDeclaredSizeAndWeightWhenEditing() async throws {
        let host = NSHostingView(rootView: field())
        let window = makeWindow(host, size: NSSize(width: 360, height: 70))
        defer { window.makeFirstResponder(nil); window.contentView = nil; window.orderOut(nil) }
        try await settle(host)
        let normal = try #require(nativeField(in: host))
        #expect(normal.font == NSFont.systemFont(ofSize: 13, weight: .regular))

        host.rootView = field(size: DaybookType.titleSize, weight: .semibold)
        try await settle(host)
        let title = try #require(nativeField(in: host))
        #expect(title.font == NSFont.systemFont(ofSize: 16, weight: .semibold))
        window.makeFirstResponder(title)
        let editor = try #require(title.currentEditor() as? NSTextView)
        #expect(editor.font == title.font)
        #expect(editor.delegate === title)
    }

    @Test func pageHeaderKeepsTitleAndContentOriginsWithOptionalSubtitle() async throws {
        var titleOrigins: [CGFloat] = []
        for showsSubtitle in [false, true] {
            let header = DaybookPageHeader {
                Text("今日待办").font(DaybookType.title).background(WorkspaceMetricMarker(name: "title"))
            } subtitle: {
                if showsSubtitle { Text("9月14日 周一").font(DaybookType.subtitle) }
            } trailing: {
                Color.clear.frame(width: 36, height: 36)
            }
            .background(WorkspaceMetricMarker(name: "header"))
            .environment(\.workspaceEmbedded, true)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            let host = NSHostingView(rootView: header)
            let window = makeWindow(host, size: NSSize(width: 520, height: 80))
            defer { window.contentView = nil; window.orderOut(nil) }
            try await settle(host)
            let title = try #require(marker("title", in: host))
            let frame = title.convert(title.bounds, to: host)
            titleOrigins.append(frame.minY)
            let headerMarker = try #require(marker("header", in: host))
            #expect(abs(headerMarker.bounds.height - WorkspaceLayout.headerHeight) < 1)
        }
        #expect(abs(titleOrigins[0] - titleOrigins[1]) < 1)
    }

    @Test func pageHeaderHasNoMinimumHeightOutsideTheWorkspace() async throws {
        let header = DaybookPageHeader {
            Text("今日待办").font(DaybookType.title)
        } subtitle: {
            EmptyView()
        } trailing: {
            EmptyView()
        }
        .background(WorkspaceMetricMarker(name: "header"))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        let host = NSHostingView(rootView: header)
        let window = makeWindow(host, size: NSSize(width: 520, height: 80))
        defer { window.contentView = nil; window.orderOut(nil) }
        try await settle(host)
        let headerMarker = try #require(marker("header", in: host))
        #expect(headerMarker.bounds.height < WorkspaceLayout.headerHeight)
    }

    private func field(size: CGFloat = DaybookType.bodySize, weight: NSFont.Weight = .regular) -> DaybookTextField {
        DaybookTextField(text: .constant("原生输入字号核验"), placeholder: "输入", fontSize: size,
                         fontWeight: weight, focus: .constant(false), onSubmit: {})
    }

    private func makeWindow(_ view: NSView, size: NSSize) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.setContentSize(size)
        window.makeKeyAndOrderFront(nil)
        return window
    }

    private func settle(_ view: NSView) async throws {
        view.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        view.layoutSubtreeIfNeeded()
    }

    private func nativeField(in view: NSView) -> DaybookAppKitTextField? {
        (view as? DaybookAppKitTextField) ?? view.subviews.lazy.compactMap { nativeField(in: $0) }.first
    }

    private func marker(_ name: String, in view: NSView) -> NSView? {
        if view.identifier?.rawValue == name { return view }
        return view.subviews.lazy.compactMap { marker(name, in: $0) }.first
    }
}

private struct WorkspaceMetricMarker: NSViewRepresentable {
    let name: String
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.identifier = NSUserInterfaceItemIdentifier(name)
        return view
    }
    func updateNSView(_ view: NSView, context: Context) {}
}
```

### 6.2 五处测试注入

```bash
sed -i '' 's/\.environment(\\\.daybookViewStyle, \.workspace)/.environment(\\.workspaceEmbedded, true)/g' \
  AreaChainTests/Features/WorkspaceRenderingTests.swift \
  AreaChainTests/Features/QuadrantLayoutTests.swift \
  AreaChainTests/Features/GanttInteractionTests.swift \
  AreaChainTests/Features/CaptureOverlayLayoutTests.swift
sed -i '' 's/\.environment(\\\.daybookViewStyle, workspace ? \.workspace : \.standard)/.environment(\\.workspaceEmbedded, workspace)/' \
  AreaChainTests/Features/CaptureOverlayLayoutTests.swift
```

检查：`rg -n 'daybookViewStyle|DaybookViewStyle|WorkspaceStyle\b|WorkspaceSwatch|WorkspaceFilterLabel' AreaChainTests` 预期零输出。如果 sed 没生效（macOS sed 对反斜杠敏感），就手工把这 5 行改成 `.environment(\.workspaceEmbedded, true)`（`CaptureOverlayLayoutTests` 第 309 行改成 `.environment(\.workspaceEmbedded, workspace)`）。

检查点：

```bash
./scripts/build.sh test --only-testing AreaChainTests/WorkspaceLayoutTests --only-testing AreaChainTests/DaybookTokenTests
```

---

## 步骤 7：文档同步（否则 `check_workflow.py` 的链接检查会因文件不存在而失败）

7.1 `AGENTS.md`：找到以 `- 复用 [DaybookTheme.swift]` 开头的整行，替换为：

```
- 复用 [DaybookPalette.swift](AreaChain/Theme/DaybookPalette.swift)、[DaybookMetrics.swift](AreaChain/Theme/DaybookMetrics.swift)、[DaybookTokens.swift](AreaChain/Theme/DaybookTokens.swift) 中的语义色、尺寸、字号、圆角、间距令牌与已有共享组件。菜单栏、工作台与手记小窗共用同一套令牌与外观；工作台只在 [WorkspaceLayout.swift](AreaChain/Theme/WorkspaceLayout.swift) 保留页头、侧栏与内容宽度等布局尺寸，并用 `workspaceEmbedded` 环境值表达"有无侧栏/页头"这类能力差异，不得用它切换颜色、字体或尺寸。
```

7.2 `AGENTS.md`：把 `` `WorkspaceStyleTests`、`WorkspaceRenderingTests` `` 改为 `` `DaybookTokenTests`、`WorkspaceLayoutTests`、`WorkspaceRenderingTests` ``。

7.3 `.agents/skills/areachain-ui/SKILL.md`：找到以 `| 样式与宿主差异 |` 开头的表格行，替换为：

```
| 样式与宿主差异 | [DaybookPalette.swift](../../../AreaChain/Theme/DaybookPalette.swift)、[DaybookMetrics.swift](../../../AreaChain/Theme/DaybookMetrics.swift)、[WorkspaceLayout.swift](../../../AreaChain/Theme/WorkspaceLayout.swift) | 复用语义色、尺寸与字号令牌；两宿主外观一致，只有 `workspaceEmbedded` 决定的布局/能力差异 |
```

7.4 `.agents/skills/areachain-verify/references/checks.md`：`` `WorkspaceStyleTests`、`DaybookContrastTests` `` → `` `DaybookTokenTests`、`WorkspaceLayoutTests`、`DaybookContrastTests` ``。

7.5 `docs/architecture.md`：
- 找到以 `` `MainSplitWorkspaceView` 在根部注入 `DaybookViewStyle.workspace` `` 开头的整段，替换为：

```
`MainSplitWorkspaceView` 在根部注入 `workspaceEmbedded = true`，只用于页内筛选条、独立窗口最小尺寸、页头最小高度、行数与气泡宿主宽度这类能力/布局分支；颜色、字体与尺寸令牌两宿主一致，来自 `DaybookPalette` / `DaybookMetrics` / `DaybookTokens`，工作台布局常量在 `WorkspaceLayout`。`DaybookPageHeader` 保持标题起点一致并在嵌入时使用页头最小高度；`DaybookInputChrome` 区分新增、搜索和多行编辑，将由 `DaybookInputShell` 取代。
```

- 把 `` `WorkspaceStyleTests` 核对字号、字重、控件几何与对比度，包含完成态文字的悬停／选中背景及标准搜索框描边边界； `` 替换为 `` `DaybookTokenTests` 核对令牌数值与对比度，`WorkspaceLayoutTests` 核对原生字段字重与页头几何； ``。
- 把 `` `CaptureOverlayLayoutTests` 为工作台分支显式注入新外观 `` 替换为 `` `CaptureOverlayLayoutTests` 为工作台分支显式注入 `workspaceEmbedded` ``。

检查：

```bash
rg -n 'DaybookWorkspaceStyle|DaybookViewStyle|WorkspaceStyle\b|WorkspaceSwatch|WorkspaceStyleTests' AGENTS.md README.md docs .agents/skills --glob '*.md'
python3 -B scripts/check_workflow.py
```

第一条预期零输出；第二条四项 passed。

---

## 最终验证（全部必须通过）

```bash
# 1. 旧机制彻底消失（预期零输出）
rg -n 'daybookViewStyle|DaybookViewStyle|isWorkspace|WorkspaceStyle\b|WorkspaceSwatch|WorkspaceFilterLabel|workspaceFilterChrome|workspaceCapsule' AreaChain AreaChainTests

# 2. 文件已删（预期 ls 报 No such file）
ls AreaChain/Theme/DaybookWorkspaceStyle.swift AreaChainTests/Theme/WorkspaceStyleTests.swift

# 3. embedded 没被用来切颜色/字体（预期零输出）
rg -n 'embedded.*(DaybookPalette|DaybookTheme|DaybookType|\.opacity\(|Color\.)' AreaChain

# 4. 文档无悬空引用（预期零输出）
rg -n 'DaybookWorkspaceStyle|DaybookViewStyle|WorkspaceStyle\b|WorkspaceStyleTests' AGENTS.md README.md docs .agents/skills --glob '*.md'

# 5. 测试（原生界面测试串行，期间不要操作其他窗口）
./scripts/build.sh test \
  --only-testing AreaChainTests/WorkspaceLayoutTests \
  --only-testing AreaChainTests/DaybookTokenTests \
  --only-testing AreaChainTests/DaybookContrastTests \
  --only-testing AreaChainTests/WorkspaceRenderingTests \
  --only-testing AreaChainTests/MenuBarPopoverRenderingTests \
  --only-testing AreaChainTests/CaptureOverlayLayoutTests \
  --only-testing AreaChainTests/QuadrantLayoutTests \
  --only-testing AreaChainTests/GanttInteractionTests \
  --only-testing AreaChainTests/DiarySummaryRowTests \
  --only-testing AreaChainTests/TaskRowInteractionTests \
  --only-testing AreaChainTests/BoardFilterBarTests

# 6. 工作流检查
python3 -B scripts/check_workflow.py

# 7. 改动范围
git status --short
```

如果第 5 条里某个渲染测试失败且失败信息是"某个尺寸/颜色与预期不符"，**不要改测试**，把失败信息原样贴进汇报，停下来问我。

## 汇报格式

```
## P1 完成汇报
### 删除的文件
### 新建的文件
### 修改文件（路径 — 一句话）
### 能力分支清单（列出所有使用 embedded 的 file:line，方便验收核对没有被用于颜色/字体）
### 验证输出（最终验证 1–7 条原样输出）
### 未做 / 发现的问题
```

最后把 `.cursor/plans/design-system.md` 第 8 节 `- [ ] P1 删除双宿主分支` 改成 `- [x]`，决策记录追加 `- <日期> P1 完成：<一句话>`。

## 绝对不要做

- 不要用 `embedded` 决定颜色、字体、圆角、阴影。
- 不要删 `DaybookInputChrome` / `daybookInputChrome`（P2 删）、`DaybookGroupedCard` / `modernCard` / `modernRow` / `PillBadge` / `SectionStamp`（P4/P5 删）。
- 不要把 `DaybookTheme.ink` 等基色改成 `DaybookPalette.text.*`（P6）。
- 不要改 `DaybookTextField.swift`、`DaybookTextEditor.swift`、`SyntaxOverlay.swift`。
- 不要改 `DiaryTagChrome`。
- 不要 commit。
