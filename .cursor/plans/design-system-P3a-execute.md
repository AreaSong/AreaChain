# 任务：AreaChain 设计系统收敛 · 阶段 P3a（按钮基座 + MenuBar / Tasks / Board / Search 迁移）· 执行提示词

## 你是谁、怎么工作

你是这个 macOS 原生项目（SwiftUI + AppKit + SwiftData）的执行工程师。设计已完成，**你只负责照做**。规则：

1. 严格按步骤顺序执行；每个"检查点"必须跑通再进下一步；修不好就停下来问我。
2. 代码块**原样粘贴**；替换用精确字符串定位，行号只是提示。
3. 只改本文列出的文件。
4. 不 `git commit` / `git push` / 安装 / 发布；不删测试、不注释测试。
5. 先读 `AGENTS.md`，再读 `.cursor/plans/design-system.md` 第 0、1、2、5 节，再读本文。不读其他文档，不全仓库扫描。
6. 没写清楚的取舍 → 用提问工具问我，复述我的回答，我说"对"才继续。
7. 做完不宣布"通过"，只按"汇报格式"交证据；验收由另一个对话按 `design-system-P3a-verify.md` 做。
8. 本阶段**只迁 MenuBar / Tasks / Board / Search 四个模块**的按钮，以及为了删除旧 API 必须做的跨模块一行改名。Diary / Workspace / Theme 内部的 `.buttonStyle(.plain)` 留给 P3b，**不要顺手改**。

## 背景

现在按钮外观有：`DaybookQuietButtonStyle`（15 处，悬停画蓝环）、`RowIconButton` / `DaybookNavButton` / `ComposerAddButton` / `WorkspaceSidebarHeaderAction` / `BoardCommandStripButton` / `FooterActionItemModifier` 六个专用 struct，以及 96 处 `.buttonStyle(.plain)` 后各自手画底色、点击区 9 种尺寸。本阶段建一个 `DaybookButtonStyle` + `DaybookIconButton` + Menu 标签修饰符，迁完四个模块，删掉全部旧 API。

**视觉基准（用户决定）**：悬停 = **淡灰圆角底**（`fill.hover`），没有蓝色悬停环；按下 = `fill.press` + 缩放 0.97；禁用 = 45% 透明。点击区三档：regular 28 / compact 22 / inline 18。

## 两类 `.buttonStyle(.plain)` 的处理规则

- **A. 按钮语义**（点了触发一个动作、外观是"按钮"）→ 换成 `DaybookButtonStyle(variant, size:)` 或 `DaybookIconButton`，并删掉 label 里自己画的 `.padding` / `.frame` / `.background` / `.overlay` / `.foregroundStyle` / `.contentShape`。
- **B. 非按钮控件**（复选框、Tab 滑块、整行点击区、缩略图、胶囊芯片、标签移除小角标）→ 保留 `.buttonStyle(.plain)`，在同一行末尾加注释 `// control: <原因>`，后续阶段（P4 表面 / P5 芯片）再处理。

下面每一处都已标好 A 或 B，你不需要自己判断。

## 开始前必读

1. `AreaChain/Theme/DaybookChrome.swift` 第 56–115 行（`DaybookQuietButtonStyle`）、170–214 行（`DaybookNavButton`、`DaybookPeriodBar`）。
2. `AreaChain/Theme/DaybookTheme.swift` 第 134–166 行（`RowIconButton`、`ComposerAddButton`）。
3. `AreaChain/Features/Board/BoardCommandStrip.swift` 全文（210 行）。
4. `AreaChain/Features/MenuBar/FooterBar.swift` 第 160–367 行。
5. `AreaChain/Features/Tasks/TaskRow+Menus.swift` 第 1–96 行。
6. `AreaChainTests/Theme/DaybookInputShellTests.swift` 全文（借用它的原生宿主测试写法）。

基线（必须绿）：

```bash
./scripts/build.sh test --only-testing AreaChainTests/MenuBarPopoverRenderingTests --only-testing AreaChainTests/BoardFilterBarTests --only-testing AreaChainTests/TaskRowInteractionTests --only-testing AreaChainTests/DiarySummaryRowTests
```

---

## 步骤 1：新建 `AreaChain/Theme/DaybookButtonStyle.swift`

```swift
import SwiftUI

/// 按钮外观变体。基准 = 菜单栏浮层现状（用户决定）：悬停淡灰圆角底，没有蓝色悬停环。
enum DaybookButtonVariant: Equatable {
    /// 普通文字 / 图文按钮：主文字色。
    case quiet
    /// 次要文字 / 图文按钮：次要文字色，悬停变主文字色（例：未激活的"筛选"）。
    case subtle
    /// 强调动作（添加、今天、清除筛选）：强调色文字。
    case prominent
    /// 危险动作：危险色文字。
    case destructive
    /// 已选中 / 已激活的文字按钮：强调色文字 + 强调色 12% 底。
    case active
    /// 带描边的胶囊状按钮：指定色文字 + 12% 底 + 35% 描边（例：已激活的"筛选"）。
    case pill(tint: Color)
    /// 纯图标按钮：次要文字色，悬停主文字色 + 淡灰底；点击区为 size 决定的正方形。
    case icon
    /// 已激活的纯图标按钮：强调色 + 强调色 12% 底。
    case iconActive
    /// 危险的纯图标按钮：危险色，悬停危险色 12% 底。
    case iconDestructive

    var isIcon: Bool {
        switch self {
        case .icon, .iconActive, .iconDestructive: true
        default: false
        }
    }
}

/// 按钮尺寸：决定图标按钮的正方形点击区、文字按钮的内边距、圆角与图标字号。
enum DaybookButtonSize: Equatable {
    case regular
    case compact
    case inline

    var hit: CGFloat {
        switch self {
        case .regular: DaybookMetrics.Hit.regular
        case .compact: DaybookMetrics.Hit.compact
        case .inline: DaybookMetrics.Hit.inline
        }
    }

    var padding: EdgeInsets {
        switch self {
        case .regular: EdgeInsets(top: 3, leading: 6, bottom: 3, trailing: 6)
        case .compact: EdgeInsets(top: 2, leading: 5, bottom: 2, trailing: 5)
        case .inline: EdgeInsets(top: 1, leading: 3, bottom: 1, trailing: 3)
        }
    }

    var radius: CGFloat {
        self == .regular ? DaybookMetrics.Radius.control : DaybookMetrics.Radius.inline
    }

    var iconFont: Font {
        switch self {
        case .regular: .system(size: 12, weight: .semibold)
        case .compact: .system(size: 11, weight: .semibold)
        case .inline: .system(size: 9.5, weight: .bold)
        }
    }
}

/// 全应用唯一的按钮样式。Features 里不再允许 `.buttonStyle(.plain)` 之后自己画底色。
struct DaybookButtonStyle: ButtonStyle {
    var variant: DaybookButtonVariant
    var size: DaybookButtonSize
    /// 键盘焦点环。只有底栏这类能 Tab 到的按钮需要传入 FocusState 的值。
    var isFocused: Bool

    init(_ variant: DaybookButtonVariant = .quiet, size: DaybookButtonSize = .regular, isFocused: Bool = false) {
        self.variant = variant
        self.size = size
        self.isFocused = isFocused
    }

    func makeBody(configuration: Configuration) -> some View {
        DaybookButtonBody(configuration: configuration, variant: variant, size: size, isFocused: isFocused)
    }
}

private struct DaybookButtonBody: View {
    let configuration: ButtonStyle.Configuration
    var variant: DaybookButtonVariant
    var size: DaybookButtonSize
    var isFocused: Bool
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size.radius, style: .continuous)
        configuration.label
            .foregroundStyle(ink)
            .modifier(DaybookButtonFrame(isIcon: variant.isIcon, size: size))
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(border, lineWidth: borderWidth))
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .onHover { hovering = $0 }
            .animation(DaybookMotion.interactive(reduceMotion), value: hovering)
            .animation(DaybookMotion.snappy(reduceMotion), value: configuration.isPressed)
            .opacity(isEnabled ? 1 : 0.45)
    }

    private var ink: Color {
        if !isEnabled { return DaybookPalette.text.disabled }
        switch variant {
        case .quiet: return DaybookPalette.text.primary
        case .subtle, .icon: return hovering ? DaybookPalette.text.primary : DaybookPalette.text.secondary
        case .prominent, .active, .iconActive: return DaybookPalette.accent.base
        case .destructive, .iconDestructive: return DaybookPalette.status.danger
        case .pill(let tint): return tint
        }
    }

    private var fill: Color {
        if configuration.isPressed { return DaybookPalette.fill.press }
        switch variant {
        case .active, .iconActive: return DaybookPalette.accent.fill
        case .pill(let tint): return tint.opacity(0.12)
        case .iconDestructive: return hovering && isEnabled ? DaybookPalette.status.danger.opacity(0.12) : .clear
        default: return hovering && isEnabled ? DaybookPalette.fill.hover : .clear
        }
    }

    private var border: Color {
        if isFocused { return DaybookPalette.border.focus }
        if case .pill(let tint) = variant { return tint.opacity(0.35) }
        return .clear
    }

    private var borderWidth: CGFloat {
        if isFocused { return 1.5 }
        if case .pill = variant { return DaybookMetrics.Stroke.regular }
        return 0
    }
}

/// 图标按钮是固定正方形点击区；文字按钮只加内边距。
private struct DaybookButtonFrame: ViewModifier {
    var isIcon: Bool
    var size: DaybookButtonSize

    func body(content: Content) -> some View {
        if isIcon {
            content.frame(width: size.hit, height: size.hit)
        } else {
            content.padding(size.padding)
        }
    }
}

/// 纯图标按钮的薄包装：统一点击区、图标字号、无障碍名与 help。
struct DaybookIconButton: View {
    var systemName: String
    var label: LocalizedStringKey
    var size: DaybookButtonSize = .regular
    var role: ButtonRole? = nil
    var isActive = false
    var enabled = true
    var action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .font(size.iconFont)
        }
        .buttonStyle(DaybookButtonStyle(variant, size: size))
        .disabled(!enabled)
        .accessibilityLabel(label)
        .help(label)
    }

    private var variant: DaybookButtonVariant {
        if role == .destructive { return .iconDestructive }
        return isActive ? .iconActive : .icon
    }
}

/// `Menu` 不接受 ButtonStyle；它的 label 用这个修饰符获得与图标按钮一致的外观。
private struct DaybookMenuLabelChrome: ViewModifier {
    var size: DaybookButtonSize
    var isActive: Bool
    var isFocused: Bool
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: size.radius, style: .continuous)
        content
            .foregroundStyle(isActive ? DaybookPalette.accent.base : (hovering ? DaybookPalette.text.primary : DaybookPalette.text.secondary))
            .frame(width: size.hit, height: size.hit)
            .background(shape.fill(isActive ? DaybookPalette.accent.fill : (hovering ? DaybookPalette.fill.hover : .clear)))
            .overlay(shape.strokeBorder(DaybookPalette.border.focus, lineWidth: isFocused ? 1.5 : 0))
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .animation(DaybookMotion.interactive(reduceMotion), value: hovering)
    }
}

extension View {
    func daybookMenuLabel(size: DaybookButtonSize = .compact, isActive: Bool = false, isFocused: Bool = false) -> some View {
        modifier(DaybookMenuLabelChrome(size: size, isActive: isActive, isFocused: isFocused))
    }
}
```

检查点：`./scripts/build.sh` 通过。

---

## 步骤 2：旧样式一行改名（跨模块，机械替换），然后删除旧 struct

### 2.1 `DaybookQuietButtonStyle` → `DaybookButtonStyle`

```bash
sed -i '' \
  -e 's/DaybookQuietButtonStyle(prominent: true)/DaybookButtonStyle(.prominent)/g' \
  -e 's/DaybookQuietButtonStyle(destructive: true)/DaybookButtonStyle(.destructive)/g' \
  -e 's/DaybookQuietButtonStyle()/DaybookButtonStyle(.quiet)/g' \
  AreaChain/Features/Attachments/AttachmentBrowserPage.swift \
  AreaChain/Features/Calendar/CalendarMonthGrid.swift \
  AreaChain/Features/Calendar/CalendarPage.swift \
  AreaChain/Features/Trash/TrashPage.swift \
  AreaChain/Features/Search/BoardSearchHitRow.swift \
  AreaChain/Features/MenuBar/MenuBarSearchResults.swift \
  AreaChain/Features/Workspace/TaskDetailHeaderSection.swift \
  AreaChain/Features/Tasks/BoardFilterBar.swift \
  AreaChain/Theme/DaybookChrome.swift
```

### 2.2 `RowIconButton` / `DaybookNavButton` → `DaybookIconButton`（参数名完全兼容）

```bash
sed -i '' 's/RowIconButton(/DaybookIconButton(/g' AreaChain/Features/Tasks/TaskRow+Menus.swift AreaChain/Features/Workspace/ResidentsPage.swift
sed -i '' 's/DaybookNavButton(/DaybookIconButton(/g' AreaChain/Theme/DaybookChrome.swift
```

### 2.3 `ComposerAddButton` → 直接用样式

`AreaChain/Theme/DaybookPage.swift` 里把

```swift
                ComposerAddButton(enabled: canSubmit, action: onSubmit)
```

替换为

```swift
                Button("row.add", action: onSubmit)
                    .font(DaybookType.subtitle.weight(.semibold))
                    .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
                    .disabled(!canSubmit)
```

### 2.4 `WorkspaceSidebarHeaderAction` → `DaybookIconButton`

`AreaChain/Features/Workspace/WorkspaceSidebarView.swift` 两处：
- `WorkspaceSidebarHeaderAction(labelKey: "sidebar.add.project", action: onAddProject)` → `DaybookIconButton(systemName: "plus", label: "sidebar.add.project", size: .compact, action: onAddProject)`
- `WorkspaceSidebarHeaderAction(labelKey: "sidebar.add.tag", action: onAddTag)` → `DaybookIconButton(systemName: "plus", label: "sidebar.add.tag", size: .compact, action: onAddTag)`

### 2.5 删除旧 struct

- `AreaChain/Theme/DaybookChrome.swift`：删除 `struct DaybookQuietButtonStyle: ButtonStyle { ... }` 与紧随的 `private struct DaybookQuietButton: View { ... }`（约 61–115 行）；删除 `struct DaybookNavButton: View { ... }`（约 170–188 行）。
- `AreaChain/Theme/DaybookTheme.swift`：删除 `struct RowIconButton: View { ... }` 与 `struct ComposerAddButton: View { ... }`（约 134–166 行）。
- `AreaChain/Theme/WorkspaceLayout.swift`：删除 `/// 侧边栏分组标题操作微按钮` 注释与 `struct WorkspaceSidebarHeaderAction: View { ... }` 整段。

检查点：

```bash
rg -n 'DaybookQuietButtonStyle|RowIconButton|DaybookNavButton|ComposerAddButton|WorkspaceSidebarHeaderAction' AreaChain AreaChainTests
./scripts/build.sh
```

第一条预期零输出；第二条通过。

---

## 步骤 3：MenuBar 模块

### 3.1 `AreaChain/Features/MenuBar/FooterBar.swift`

a. `inactiveFilterButton`（A，`.subtle`）：整个属性替换为

```swift
    private var inactiveFilterButton: some View {
        Button {
            triggerAction()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease")
                    .accessibilityHidden(true)
                Text(L10n.string("filter.label", locale: locale))
                    .lineLimit(1)
            }
            .font(DaybookType.caption)
        }
        .buttonStyle(DaybookButtonStyle(.subtle, size: .compact, isFocused: triggerFocused))
        .keyboardShortcut("f", modifiers: [.command, .shift])
        .focused($triggerFocused)
        .accessibilityLabel("filter.label")
        .accessibilityIdentifier("menubar.filter.open")
        .help(L10n.string("filter.open.help", locale: locale))
    }
```

b. `activeFilterButton`（A，`.pill`）：把 label 里 `HStack(spacing: 3.5) { ... }` 之后的 `.padding(.horizontal, 6)`、`.frame(height: 26)`、`.foregroundStyle(DaybookTheme.stamp)`、`.background( ... )` 4 行、`.overlay( ... )` 4 行、`.contentShape(Rectangle())` **全部删除**（HStack 内部的三个子视图和计数小胶囊原样保留）；`.buttonStyle(.plain)` → `.buttonStyle(DaybookButtonStyle(.pill(tint: DaybookPalette.accent.base), size: .compact, isFocused: triggerFocused))`。

c. `dismissDrawerButton`（A）：整个属性替换为

```swift
    private var dismissDrawerButton: some View {
        DaybookIconButton(systemName: "xmark", label: "common.close", size: .regular) {
            isFilterDrawerPresented.wrappedValue = false
        }
    }
```

d. `workspaceButton`（A）：把 label 里的 `.modifier(FooterActionItemModifier(isFocused: workspaceFocused))` 一行删除；`.buttonStyle(.plain)` → `.buttonStyle(DaybookButtonStyle(.icon, size: .regular, isFocused: workspaceFocused))`。其余 `.focused` / `.keyboardShortcut` / `.help` / `.accessibilityLabel` / `.accessibilityIdentifier` 保留。

e. `moreMenu`（A，Menu 标签）：label 里 `.modifier(FooterActionItemModifier(isFocused: moreFocused))` → `.daybookMenuLabel(size: .regular, isFocused: moreFocused)`。

f. 删除文件末尾 `// MARK: - 底栏动作按钮微交互修饰符` 与 `private struct FooterActionItemModifier: ViewModifier { ... }` 整段。

### 3.2 `AreaChain/Features/MenuBar/MenuBarFilterFlyout.swift`

a. 一级分类按钮（约 121–154 行，A）：label 里 `HStack(spacing: 5) { ... }` 之后删除 `.padding(.horizontal, 6)`、`.padding(.vertical, 4.5)`、`.background( ... )` 4 行、`.foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.ink)`、`.contentShape(Rectangle())`；`.buttonStyle(.plain)` → `.buttonStyle(DaybookButtonStyle(isSelected ? .active : .quiet, size: .compact))`。后面的 `.onHover { ... }` 保留。

b. 两处"清除筛选"按钮（约 167–180 与 220–233 行，A）：各自 label 里 `HStack(spacing: 4) { ... }` 之后删除 `.padding(.horizontal, 6)`、`.padding(.vertical, 3.5)`、`.foregroundStyle(DaybookTheme.stamp.opacity(0.9))`、`.contentShape(Rectangle())`；`.buttonStyle(.plain)` → `.buttonStyle(DaybookButtonStyle(.prominent, size: .inline))`。

c. `flyoutItem` 选项行（约 319–371 行，A）：label 里 `HStack(spacing: 4) { ... }` 之后删除 `.padding(.horizontal, 6)`、`.padding(.vertical, 3.5)`、`.background( ... )` 4 行、`.overlay( ... )` 4 行、`.foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.ink)`、`.contentShape(Rectangle())`；`.buttonStyle(.plain)` → `.buttonStyle(DaybookButtonStyle(isSelected ? .active : .quiet, size: .compact))`。HStack 内部（圆点、图标、标题、计数、勾）原样保留。

### 3.3 `AreaChain/Features/MenuBar/MenuBarSearchField.swift`

a. 放大镜按钮（A）：把 `leading` 槽里

```swift
            Button { toolbar.focusSearch() } label: {
                Image(systemName: "magnifyingglass")
                    .font(DaybookType.caption)
                    .foregroundStyle(toolbar.searchIsFocused ? DaybookTheme.ink : DaybookTheme.muted)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("f", modifiers: .command)
            .accessibilityLabel("footer.search.label")
```

替换为

```swift
            DaybookIconButton(systemName: "magnifyingglass", label: "footer.search.label", size: .inline) {
                toolbar.focusSearch()
            }
            .keyboardShortcut("f", modifiers: .command)
```

b. token 的 xmark 小按钮（B）：`.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 筛选 token 移除角标，P5 迁 DaybookChip(.token)`

c. 清空按钮（A）：把 `trailing` 槽里

```swift
                Button { toolbar.clearSearch(); toolbar.focusSearch() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookTheme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("footer.search.clear")
                .help("footer.search.clear")
```

替换为

```swift
                DaybookIconButton(systemName: "xmark.circle.fill", label: "footer.search.clear", size: .inline) {
                    toolbar.clearSearch()
                    toolbar.focusSearch()
                }
```

### 3.4 `AreaChain/Features/MenuBar/MenuBarSearchResults.swift`

`Button("footer.search.clear", action: onClearSearch)` 之后的 `.buttonStyle(.plain)` → `.buttonStyle(DaybookButtonStyle(.quiet, size: .compact))`。（第 40 行的 quiet 已由步骤 2.1 改好。）

### 3.5 `AreaChain/Features/MenuBar/MenuBarControls.swift`（B）

`DaybookQuietTabBar` 里的 `.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 分段切换滑块，非按钮语义，P5 迁 DaybookSegmentedBar`

检查点：

```bash
rg -n '\.buttonStyle\(\.plain\)' AreaChain/Features/MenuBar | rg -v '// control:'
./scripts/build.sh
```

第一条预期零输出。

---

## 步骤 4：Tasks 模块

### 4.1 `AreaChain/Features/Tasks/AttachmentThumbnails.swift`（B）
`.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 附件缩略图点击区`

### 4.2 `AreaChain/Features/Tasks/BatchActionBar.swift`（A）
- 移入废纸篓按钮：删除 label 里 `.foregroundStyle(DaybookTheme.destructive)` 一行；`.buttonStyle(.plain)` → `.buttonStyle(DaybookButtonStyle(.destructive, size: .compact))`
- 清除选择按钮：把

```swift
            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(DaybookTheme.muted)
            }
            .buttonStyle(.plain)
```

替换为

```swift
            DaybookIconButton(systemName: "xmark.circle.fill", label: "batch.clear", size: .compact, action: onClear)
```

### 4.3 `AreaChain/Features/Tasks/BoardFilterBar.swift`
- 第 33 行的 quiet 已由步骤 2.1 改好。
- `standardCapsule` 里下拉主按钮（约 196–210 行，A）：`.buttonStyle(.plain)` → `.buttonStyle(DaybookButtonStyle(.quiet, size: .inline))`；label 里 `.contentShape(Rectangle())` 删除，其余保留（`active` 的着色留给 label 自己）。
- 重置 xmark 按钮（约 213–221 行，A）：删除 label 里 `.foregroundStyle(DaybookTheme.stamp)`、`.padding(.horizontal, 3)`、`.padding(.vertical, 2)`、`.contentShape(Rectangle())`；`.buttonStyle(.plain)` → `.buttonStyle(DaybookButtonStyle(.iconActive, size: .inline))`。`.help` / `.accessibilityLabel` 保留。
- 展开 chevron 按钮（约 225–233 行，A）：删除 label 里 `.foregroundStyle(active ? ... : ...)`、`.contentShape(Rectangle())`；`.buttonStyle(.plain)` → `.buttonStyle(DaybookButtonStyle(.icon, size: .inline))`。
- `FilterDropdownItemRow`（约 280–334 行，A）：
  - 删除 `@State private var isHovered = false` 与 `@Environment(\.accessibilityReduceMotion) private var reduceMotion` 两行。
  - label 里 `HStack(spacing: 5) { ... }` 之后删除 `.padding(.horizontal, 6)`、`.padding(.vertical, 4)`、`.background( ... )` 4 行、`.contentShape(Rectangle())`。
  - `.buttonStyle(.plain)` → `.buttonStyle(DaybookButtonStyle(.quiet, size: .compact))`；删除其后的 `.onHover { isHovered = $0 }` 与 `.animation(DaybookMotion.interactive(reduceMotion), value: isHovered)` 两行。
  - 让整行可点满宽：在 `.buttonStyle(...)` 之后加一行 `.frame(maxWidth: .infinity, alignment: .leading)`。

### 4.4 `AreaChain/Features/Tasks/DayBoardSections.swift`（B）
`.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 分节折叠头，整行点击`

### 4.5 `AreaChain/Features/Tasks/TaskRow+Badges.swift`（B）
`.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 时间胶囊，P5 迁 DaybookChip(.status)`

### 4.6 `AreaChain/Features/Tasks/TaskRow+Menus.swift`（A）
- 第 10–11 行已由步骤 2.2 改为 `DaybookIconButton`。
- `copyButton` 整个属性替换为

```swift
    private var copyButton: some View {
        Button {
            copyTask()
        } label: {
            Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 11, weight: .semibold))
        }
        .buttonStyle(DaybookButtonStyle(hasCopied ? .iconActive : .icon, size: .compact))
        .help(Text(hasCopied ? "diary.copied" : "diary.quick.copy"))
        .accessibilityLabel(Text(hasCopied ? "diary.copied" : "diary.quick.copy"))
        .fixedSize()
    }
```

- `moreMenu` 的 label 与尾部修饰符：把

```swift
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DaybookTheme.muted)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                        .fill(DaybookTheme.ink.opacity(0.06))
                )
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
```

替换为

```swift
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .semibold))
                .daybookMenuLabel(size: .compact)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
```

（后面的 `.frame(width: 24, height: 24)`、`.fixedSize()` 等保留。）

### 4.7 `AreaChain/Features/Tasks/TaskRowSubtaskMiniViews.swift`（B，两处）
- 子任务计数芯片：`.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 子任务计数芯片，P5 迁 DaybookChip(.count)`
- 迷你复选框：`.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 复选框，非按钮语义`

### 4.8 `AreaChain/Features/Tasks/TasksPage+Header.swift`（B）
`.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 筛选 token 移除角标，P5 迁 DaybookChip(.token)`

### 4.9 `AreaChain/Features/Tasks/TasksPage+Sections.swift`（B，两处）
- "全部移到今天"胶囊：`.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 胶囊操作，P5 迁 DaybookChip(.action)`
- `chip(_:)` 里：`.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 遗留芯片，P5 迁 DaybookChip(.filter)`

检查点：

```bash
rg -n '\.buttonStyle\(\.plain\)' AreaChain/Features/Tasks | rg -v '// control:'
./scripts/build.sh
```

第一条预期零输出。

---

## 步骤 5：Board 模块（命令条）

`AreaChain/Features/Board/BoardCommandStrip.swift`：

a. `BoardCommandStripButton` 的 `var body` 整体替换为

```swift
    var body: some View {
        Button(action: action) {
            BoardCommandStripIcon(icon: icon)
        }
        .buttonStyle(DaybookButtonStyle(isDestructive ? .iconDestructive : (isActive ? .iconActive : .icon), size: .compact))
        .fixedSize()
        .accessibilityLabel(LocalizedStringKey(labelKey))
        .help(LocalizedStringKey(labelKey))
        .onHover { updateTip($0) }
        .background(BoardCommandHoverArea { updateTip($0) })
    }
```

b. `BoardCommandStripMenu` 的 `var body` 里，把

```swift
        } label: {
            BoardCommandStripIcon(
                icon: icon,
                isButtonHovered: hoveredTip == localizedText,
                isActive: isActive
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 22, height: 22)
        .fixedSize()
```

替换为

```swift
        } label: {
            BoardCommandStripIcon(icon: icon)
                .daybookMenuLabel(size: .compact, isActive: isActive)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
```

c. `BoardCommandStripIcon` 整个 struct 替换为

```swift
struct BoardCommandStripIcon: View {
    var icon: String

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 11.5, weight: .medium))
    }
}
```

`BoardCommandStripTip`、`BoardCommandHoverArea`、`HoverTrackingNSView` 不动。

检查点：

```bash
rg -n 'isButtonHovered' AreaChain
./scripts/build.sh
```

第一条预期零输出。

---

## 步骤 6：Search 模块

### 6.1 `AreaChain/Features/Search/SearchPage.swift`（A，两处）
- `leading` 槽里

```swift
                Button { searchFocus = true } label: {
                    Image(systemName: "magnifyingglass").foregroundStyle(DaybookTheme.muted)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("f", modifiers: .command)
                .accessibilityLabel("search.placeholder")
```

→

```swift
                DaybookIconButton(systemName: "magnifyingglass", label: "search.placeholder", size: .inline) {
                    searchFocus = true
                }
                .keyboardShortcut("f", modifiers: .command)
```

- `trailing` 槽里

```swift
                    Button {
                        query = ""
                        searchFocus = true
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(DaybookTheme.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("footer.search.clear")
```

→

```swift
                    DaybookIconButton(systemName: "xmark.circle.fill", label: "footer.search.clear", size: .inline) {
                        query = ""
                        searchFocus = true
                    }
```

### 6.2 `AreaChain/Features/Search/BoardSearchHitRow.swift`
- `.list` 分支的 quiet 已由步骤 2.1 改好。
- `.workspace` 分支（B）：`.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 搜索结果整行点击区，P4 迁 daybookSurface(.row)`

检查点：

```bash
rg -n '\.buttonStyle\(\.plain\)' AreaChain/Features/Search AreaChain/Features/Board | rg -v '// control:'
./scripts/build.sh
```

第一条预期零输出。

---

## 步骤 7：新建测试 `AreaChainTests/Theme/DaybookButtonStyleTests.swift`

```swift
import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct DaybookButtonStyleTests {
    @Test func sizesFollowMetrics() {
        #expect(DaybookButtonSize.regular.hit == DaybookMetrics.Hit.regular)
        #expect(DaybookButtonSize.compact.hit == DaybookMetrics.Hit.compact)
        #expect(DaybookButtonSize.inline.hit == DaybookMetrics.Hit.inline)
        #expect(DaybookButtonSize.regular.radius == DaybookMetrics.Radius.control)
        #expect(DaybookButtonSize.compact.radius == DaybookMetrics.Radius.inline)
        #expect(DaybookButtonVariant.icon.isIcon)
        #expect(DaybookButtonVariant.iconActive.isIcon)
        #expect(!DaybookButtonVariant.quiet.isIcon)
        #expect(!DaybookButtonVariant.pill(tint: .red).isIcon)
    }

    @Test func iconButtonsUseSquareHitAreas() async throws {
        let content = HStack(spacing: 12) {
            DaybookIconButton(systemName: "xmark", label: "common.close", size: .regular, action: {})
                .background(ButtonMarker(name: "regular"))
            DaybookIconButton(systemName: "xmark", label: "common.close", size: .compact, action: {})
                .background(ButtonMarker(name: "compact"))
            DaybookIconButton(systemName: "xmark", label: "common.close", size: .inline, action: {})
                .background(ButtonMarker(name: "inline"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        let host = NSHostingView(rootView: content)
        let window = makeWindow(host, size: NSSize(width: 240, height: 80))
        defer { window.contentView = nil; window.orderOut(nil) }
        try await settle(host)
        for (name, hit) in [("regular", DaybookMetrics.Hit.regular), ("compact", DaybookMetrics.Hit.compact), ("inline", DaybookMetrics.Hit.inline)] {
            let view = try #require(marker(name, in: host))
            #expect(abs(view.bounds.width - hit) < 1, "\(name) 宽应为 \(hit)")
            #expect(abs(view.bounds.height - hit) < 1, "\(name) 高应为 \(hit)")
        }
    }

    @Test func textButtonDoesNotForceASquareFrame() async throws {
        let content = Button("清除筛选", action: {})
            .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
            .background(ButtonMarker(name: "text"))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        let host = NSHostingView(rootView: content)
        let window = makeWindow(host, size: NSSize(width: 240, height: 80))
        defer { window.contentView = nil; window.orderOut(nil) }
        try await settle(host)
        let view = try #require(marker("text", in: host))
        #expect(view.bounds.width > DaybookMetrics.Hit.compact)
        #expect(view.bounds.height < DaybookMetrics.Hit.regular)
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

    private func marker(_ name: String, in view: NSView) -> NSView? {
        if view.identifier?.rawValue == name { return view }
        return view.subviews.lazy.compactMap { marker(name, in: $0) }.first
    }
}

private struct ButtonMarker: NSViewRepresentable {
    let name: String
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.identifier = NSUserInterfaceItemIdentifier(name)
        return view
    }
    func updateNSView(_ view: NSView, context: Context) {}
}
```

检查点：

```bash
./scripts/build.sh test --only-testing AreaChainTests/DaybookButtonStyleTests
```

---

## 最终验证（全部必须通过）

```bash
# 1. 旧 API 彻底消失（预期零输出）
rg -n 'DaybookQuietButtonStyle|RowIconButton|DaybookNavButton|ComposerAddButton|WorkspaceSidebarHeaderAction|FooterActionItemModifier|isButtonHovered' AreaChain AreaChainTests

# 2. 四个模块里没有裸 .plain（预期零输出）
rg -n '\.buttonStyle\(\.plain\)' AreaChain/Features/MenuBar AreaChain/Features/Tasks AreaChain/Features/Board AreaChain/Features/Search | rg -v '// control:'

# 3. 四个模块里 control 注释的数量（预期恰好 11）
rg -c '\.buttonStyle\(\.plain\) // control:' AreaChain/Features/MenuBar AreaChain/Features/Tasks AreaChain/Features/Board AreaChain/Features/Search | awk -F: '{s+=$2} END {print s}'

# 4. 新样式被使用（预期 ≥ 25）
rg -c 'DaybookButtonStyle\(|DaybookIconButton\(|daybookMenuLabel\(' AreaChain --glob '*.swift' | awk -F: '{s+=$2} END {print s}'

# 5. 没有人给样式塞颜色（预期零输出；pill 的 tint 只允许是 DaybookPalette 的值）
rg -n 'pill\(tint:' AreaChain/Features | rg -v 'DaybookPalette\.'

# 6. 测试（原生界面测试串行，期间不操作其他窗口）
./scripts/build.sh test \
  --only-testing AreaChainTests/DaybookButtonStyleTests \
  --only-testing AreaChainTests/DaybookInputShellTests \
  --only-testing AreaChainTests/MenuBarPopoverRenderingTests \
  --only-testing AreaChainTests/MenuBarToolbarStateTests \
  --only-testing AreaChainTests/BoardFilterBarTests \
  --only-testing AreaChainTests/TaskRowInteractionTests \
  --only-testing AreaChainTests/TaskRowBubbleTests \
  --only-testing AreaChainTests/DiarySummaryRowTests \
  --only-testing AreaChainTests/CaptureOverlayLayoutTests \
  --only-testing AreaChainTests/WorkspaceRenderingTests \
  --only-testing AreaChainTests/WorkspaceLayoutTests

# 7. 工作流检查
python3 -B scripts/check_workflow.py

# 8. 改动范围
git status --short
```

第 6 条里如果有测试失败且信息是"某个尺寸与预期不符"，**不要改测试**，把失败信息原样贴出来停下问我。

## 汇报格式

```
## P3a 完成汇报
### 新建 / 删除的文件与 struct
### 修改文件（路径 — 一句话）
### A 类迁移清单（file:line — 用了哪个 variant/size）
### B 类保留清单（file:line — control 注释内容）
### 验证输出（最终验证 1–8 条原样输出）
### 未做 / 发现的问题
```

最后把 `.cursor/plans/design-system.md` 第 8 节 `- [ ] P3a 按钮（MenuBar + Tasks + Board + Search）` 改成 `- [x]`，决策记录追加 `- <日期> P3a 完成：<一句话>`。

## 绝对不要做

- 不要动 Diary / Workspace / Theme 内部的 `.buttonStyle(.plain)`（步骤 2 列出的跨模块一行改名除外）。
- 不要给 `DaybookButtonStyle` 增加颜色参数；不要新增 variant。
- 不要动 `CommandReturnButton`、`CaptureAttributesButton`（P3b）。
- 不要动 `MenuBarSearchField` / `TasksPage+Header` 里 token 胶囊的形状（P5）。
- 不要改任何 `accessibilityIdentifier` / `accessibilityLabel` / `SyntaxViewAnchor` 字符串。
- 不要 commit。
