# 任务：AreaChain 设计系统收敛 · 阶段 P2（统一输入壳）· 执行提示词

## 你是谁、怎么工作

你是这个 macOS 原生项目（SwiftUI + AppKit + SwiftData）的执行工程师。设计已完成，**你只负责照做**。规则：

1. 严格按步骤顺序执行；每个"检查点"必须跑通再进下一步；修不好就停下来问我。
2. 代码块**原样粘贴**；替换用精确字符串定位，行号只是提示。
3. 只改本文列出的文件。
4. 不 `git commit` / `git push` / 安装 / 发布；不删测试、不注释测试。
5. 先读 `AGENTS.md`，再读 `.cursor/plans/design-system.md` 第 0、1、2、5 节，再读本文。不读其他文档，不全仓库扫描。
6. 没写清楚的取舍 → 用提问工具问我，复述我的回答，我说"对"才继续。
7. 做完不宣布"通过"，只按"汇报格式"交证据；验收由另一个对话按 `design-system-P2-verify.md` 做。
8. **绝对不动**这些文件：`DaybookTextField.swift`、`DaybookTextEditor.swift`、`SyntaxTextField.swift`、`SyntaxTextEditor.swift`、`SyntaxOverlay.swift`、`SyntaxAutocompleteView.swift`。它们是输入行为层，有测试保护；本阶段只换"外壳"。

## 背景

现在"输入框外壳"有 4 套实现 + 5 处自绘：`BoardCaptureRow`（菜单栏捕获框、手记快捷框、工作台 composer 内部）、`daybookInputChrome` 修饰符（工作台 composer 外框、`DaybookField`、手记编辑器、手记搜索）、`MenuBarSearchField` / `WorkspaceHeaderSearchCapsule` / `TaskDetailNotesView` / `TaskDetailSubtasksView` / `DiaryWindowView` 各自手画。本阶段建一个 `DaybookInputShell`，把全部 13 处迁过去，然后删掉旧的 4 套。

**视觉基准（用户决定）= 菜单栏浮层现状**：
- 单行输入（composer）：高 34、圆角 8、内边距上下 7 左右 10；未聚焦底 `ink 3%` + 边 `rule 40%` 0.6pt；聚焦底 `surface` + 边 `ink 35%` 0.9pt。**没有蓝色聚焦环。**
- 搜索框（search）：以菜单栏底栏搜索框为准——高 28、圆角 6、内边距上下 4 左右 7、颜色同上。（P0 时误抄成圆角 10 / 内边距 8/10，本阶段纠正。）
- 多行编辑（editor）：不锁高，内边距 4，圆角 6，颜色同上。
- 尺寸差异只允许通过 `configure` 闭包重载；颜色不可重载。

## 开始前必读

1. `AreaChain/Theme/BoardCaptureRow.swift`（41 行）、`AreaChain/Theme/DaybookChrome.swift` 第 212–232 行（`DaybookField`）与 第 296–350 行（`DaybookInputKind` / `DaybookInputChrome`）。
2. `AreaChain/Theme/DaybookPage.swift` 第 155–234 行（`DaybookComposer`）。
3. `AreaChain/Features/MenuBar/CaptureField.swift` 全文（70 行）。
4. `AreaChain/Features/Diary/DiaryQuickComposerView.swift` 第 1–125 行、160–170 行。
5. `AreaChain/Features/MenuBar/MenuBarSearchField.swift` 全文（141 行）。
6. `AreaChain/Features/Workspace/WorkspaceHeaderBar.swift` 第 62–132 行。
7. `AreaChainTests/Theme/WorkspaceLayoutTests.swift` 全文（只为借用它的原生宿主测试写法）。

基线（必须绿）：

```bash
./scripts/build.sh test --only-testing AreaChainTests/DaybookTokenTests --only-testing AreaChainTests/DaybookTextFieldTests --only-testing AreaChainTests/CaptureOverlayLayoutTests --only-testing AreaChainTests/DiaryComposerInteractionTests
```

---

## 步骤 1：修正令牌（palette 加一个边框色；metrics 纠正搜索框值；同步 P0 测试）

### 1.1 `AreaChain/Theme/DaybookPalette.swift`

`struct Border` 里，在 `let selection: Color` 之后加一行：

```swift
        let faint: Color
```

`static let border = Border(` 的参数列表里，在 `selection: DaybookTheme.cardSelectionStroke` 之后加一个参数（注意给上一行补逗号）：

```swift
        selection: DaybookTheme.cardSelectionStroke,
        faint: alpha("palette.border.faint", DaybookSwatch.ruleLight, DaybookSwatch.ruleDark, 0.4)
```

### 1.2 `AreaChain/Theme/DaybookMetrics.swift`

- `static let inputSearch: CGFloat = 10` → `static let inputSearch: CGFloat = 6`
- `case .search: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)` → `case .search: EdgeInsets(top: 4, leading: 7, bottom: 4, trailing: 7)`

### 1.3 `AreaChainTests/Theme/DaybookTokenTests.swift`

- `#expect(DaybookMetrics.Radius.inputSearch == 10)` → `#expect(DaybookMetrics.Radius.inputSearch == 6)`
- `#expect(search.top == 8)` → `#expect(search.top == 4)`
- `#expect(search.leading == 10)` → `#expect(search.leading == 7)`

检查点：

```bash
./scripts/build.sh test --only-testing AreaChainTests/DaybookTokenTests
```

---

## 步骤 2：新建 `AreaChain/Theme/DaybookInputShell.swift`

```swift
import SwiftUI

/// 输入外壳的三种用途；尺寸随 kind 变，颜色不变。
enum DaybookInputKind: Equatable {
    case composer
    case search
    case editor
}

/// 输入外壳的尺寸配置。只有尺寸可以在调用点重载；颜色、描边宽度不在这里，不可重载。
struct DaybookInputShellConfiguration {
    var height: CGFloat?
    var minHeight: CGFloat?
    var insets: EdgeInsets
    var spacing: CGFloat
    var radius: CGFloat

    static func standard(for kind: DaybookInputKind) -> DaybookInputShellConfiguration {
        switch kind {
        case .composer:
            DaybookInputShellConfiguration(
                height: DaybookMetrics.inputHeight, minHeight: nil,
                insets: DaybookMetrics.inputInsets(.composer), spacing: 8,
                radius: DaybookMetrics.Radius.inputComposer
            )
        case .search:
            DaybookInputShellConfiguration(
                height: DaybookMetrics.controlHeight, minHeight: nil,
                insets: DaybookMetrics.inputInsets(.search), spacing: 4,
                radius: DaybookMetrics.Radius.inputSearch
            )
        case .editor:
            DaybookInputShellConfiguration(
                height: nil, minHeight: nil,
                insets: DaybookMetrics.inputInsets(.editor), spacing: 0,
                radius: DaybookMetrics.Radius.inputEditor
            )
        }
    }
}

/// 全应用唯一的输入外壳（菜单栏、工作台、抽屉、手记小窗共用）。
/// 视觉基准 = 菜单栏浮层任务捕获框（用户决定）：未聚焦 ink 3% 底 + rule 40% 细边；聚焦 surface 底 + ink 35% 边；没有蓝色聚焦环。
/// composer / search 为固定高度单行；editor 多行不锁高。
/// 正文控件（DaybookTextField / SyntaxTextField / SyntaxTextEditor）放在 field 槽里，本壳不改变它们的任何按键行为。
struct DaybookInputShell<Leading: View, Field: View, Trailing: View>: View {
    var kind: DaybookInputKind
    var focused: Bool
    var configure: ((inout DaybookInputShellConfiguration) -> Void)? = nil
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var field: () -> Field
    @ViewBuilder var trailing: () -> Trailing

    private var configuration: DaybookInputShellConfiguration {
        var config = DaybookInputShellConfiguration.standard(for: kind)
        configure?(&config)
        return config
    }

    var body: some View {
        let config = configuration
        HStack(alignment: kind == .editor ? .top : .center, spacing: config.spacing) {
            leading()
            field()
            trailing()
        }
        .frame(maxWidth: .infinity)
        .padding(config.insets)
        .frame(height: config.height)
        .frame(minHeight: config.minHeight)
        .background(
            RoundedRectangle(cornerRadius: config.radius, style: .continuous)
                .fill(focused ? DaybookPalette.fill.surface : DaybookPalette.fill.subtle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: config.radius, style: .continuous)
                .stroke(
                    focused ? DaybookPalette.border.focus : DaybookPalette.border.faint,
                    lineWidth: focused ? DaybookMetrics.Stroke.focus : DaybookMetrics.Stroke.regular
                )
        )
        .daybookHideInputChrome()
    }
}

extension DaybookInputShell where Leading == EmptyView, Trailing == EmptyView {
    init(
        kind: DaybookInputKind, focused: Bool,
        configure: ((inout DaybookInputShellConfiguration) -> Void)? = nil,
        @ViewBuilder field: @escaping () -> Field
    ) {
        self.init(kind: kind, focused: focused, configure: configure, leading: { EmptyView() }, field: field, trailing: { EmptyView() })
    }
}

extension DaybookInputShell where Trailing == EmptyView {
    init(
        kind: DaybookInputKind, focused: Bool,
        configure: ((inout DaybookInputShellConfiguration) -> Void)? = nil,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder field: @escaping () -> Field
    ) {
        self.init(kind: kind, focused: focused, configure: configure, leading: leading, field: field, trailing: { EmptyView() })
    }
}
```

然后在 `AreaChain/Theme/DaybookChrome.swift` 里**删除**原来的 `enum DaybookInputKind { ... }`（约 299–303 行，共 5 行），因为它已经搬到新文件。`DaybookInputChrome` 暂时保留（步骤 4 删）。

检查点：`./scripts/build.sh` 通过。

---

## 步骤 3：迁移 13 处消费者

### 3.1 `AreaChain/Features/MenuBar/CaptureField.swift`

把 `var body` 与 `private var inputRow` 两个属性整体替换为：

```swift
    var body: some View {
        inputRow
        .syntaxSuggestions(autocomplete)
        .animation(DaybookMotion.interactive, value: focus.wrappedValue)
    }

    private var inputRow: some View {
        let focused = focus.wrappedValue
        let plusColor = focused ? DaybookTheme.ink : DaybookTheme.muted.opacity(0.8)

        return DaybookInputShell(kind: .composer, focused: focused) {
            Image(systemName: "plus")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(plusColor)
                .frame(width: 14)
        } field: {
            DaybookTextField(
                text: $text,
                placeholder: L10n.string("capture.placeholder.today", locale: locale),
                focus: focus,
                autocomplete: autocomplete,
                availableTags: availableTags,
                highlightsSyntax: true,
                onSubmit: onTodo,
                onCommandReturn: { if allowsDiaryShortcut { onDiary() } },
                allowsShiftNewline: false
            )
            .accessibilityLabel("capture.placeholder.today")
        } trailing: {
            diaryShortcutButton
        }
    }
```

（`diaryShortcutButton` 属性保留不动。）

### 3.2 `AreaChain/Theme/DaybookPage.swift`（`DaybookComposer`）

把 `var body` 整体替换为：

```swift
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            DaybookInputShell(kind: .composer, focused: isFocused) {
                Image(systemName: "plus")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(isFocused ? DaybookTheme.ink : DaybookTheme.muted.opacity(0.8))
                    .frame(width: 14)
            } field: {
                field
            } trailing: {
                CaptureAttributesButton(text: text, knownTags: completionTags, state: autocomplete)
                ComposerAddButton(enabled: canSubmit, action: onSubmit)
            }
            .syntaxSuggestions(autocomplete)
            accessory
        }
    }
```

### 3.3 `AreaChain/Features/Diary/DiaryQuickComposerView.swift`（三处）

a. `var body` 里删除 `.daybookHideInputChrome()` 这一行（壳已内置）。

b. `compactInputRow` 开头，把

```swift
        let focused = focused.wrappedValue
        let strokeColor = focused ? DaybookTheme.stamp.opacity(0.48) : DaybookTheme.rule.opacity(0.45)

        return BoardCaptureRow(
            focused: focused,
            fill: focused ? DaybookTheme.surface : DaybookTheme.ink.opacity(0.025),
            stroke: strokeColor,
            locksHeight: true,
            showsFocusShadow: true
        ) {
```

替换为

```swift
        let focused = focused.wrappedValue

        return DaybookInputShell(kind: .composer, focused: focused) {
```

后面的 `statusIcon`、`} field: {`、`} trailing: {`、`.background(KeyWindowHost...)`、`.background(SyntaxViewAnchor("syntax.diary.composer"))`、三个 `.onChange/.onAppear` 全部**原样保留**。

c. `editorInputView` 整体替换为：

```swift
    private var editorInputView: some View {
        DaybookInputShell(kind: .editor, focused: focused.wrappedValue) {
            SyntaxTextEditor(
                text: $text, focused: focused,
                placeholder: L10n.string("diary.composer.placeholder", locale: locale),
                onSubmit: onSubmit
            )
            .frame(minHeight: 64, maxHeight: 100)
        }
    }
```

（原来的 `@ViewBuilder` 标注和 `let editor =` 都去掉。）

### 3.4 `AreaChain/Features/Diary/DiaryPage.swift`（两处）

a. `searchChrome` 整体替换为：

```swift
    private var searchChrome: some View {
        DaybookInputShell(kind: .search, focused: searchFocused) {
            Button { searchFocused = true } label: {
                Image(systemName: "magnifyingglass").font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(showsPageHeader ? KeyboardShortcut("f", modifiers: .command) : nil)
            .accessibilityLabel("diary.search.placeholder")
        } field: {
            SyntaxTextField(
                text: $searchQuery, placeholder: L10n.string("diary.search.placeholder", locale: locale),
                focused: $searchFocused, context: .tagSearch, fontSize: DaybookType.subtitleSize,
                onEscape: {
                    if !searchQuery.isEmpty { searchQuery = "" }
                    else { NSApp.keyWindow?.makeFirstResponder(nil) }
                }
            )
        } trailing: {
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(DaybookTheme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("footer.search.clear")
            }
        }
    }
```

b. `quickComposer` 里锁定草稿那一段的 `.font(DaybookType.caption).padding(10).daybookInputChrome(focused: false, kind: .composer)` 替换为（这不是输入框，是提示框，P4 会迁到表面基座）：

```swift
            .font(DaybookType.caption)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: DaybookMetrics.Radius.inputComposer, style: .continuous).fill(DaybookPalette.fill.subtle)) // token-exempt: 锁定草稿提示框，P4 迁 daybookSurface(.banner)
            .overlay(RoundedRectangle(cornerRadius: DaybookMetrics.Radius.inputComposer, style: .continuous).stroke(DaybookPalette.border.faint, lineWidth: DaybookMetrics.Stroke.regular)) // token-exempt: 同上
```

### 3.5 `AreaChain/Features/Diary/DiaryCardComponents.swift`

`editingContent` 里，把

```swift
            SyntaxTextEditor(
                text: $session.text, focused: $editFocused,
                placeholder: L10n.string("diary.composer.placeholder", locale: locale), onSubmit: saveTextEdit
            )
                .frame(minHeight: 64, maxHeight: 160)
                .onAppear { editFocused = true }
                .zIndex(20)
                .daybookInputChrome(focused: editFocused, kind: .editor)
```

替换为

```swift
            DaybookInputShell(kind: .editor, focused: editFocused) {
                SyntaxTextEditor(
                    text: $session.text, focused: $editFocused,
                    placeholder: L10n.string("diary.composer.placeholder", locale: locale), onSubmit: saveTextEdit
                )
                .frame(minHeight: 64, maxHeight: 160)
                .onAppear { editFocused = true }
            }
            .zIndex(20)
```

### 3.6 `AreaChain/Features/Search/SearchPage.swift`

把 `DaybookField(focused: searchFocus) { HStack(spacing: 8) { ... } }` 整段（到 `.zIndex(50)` 之前）替换为：

```swift
            DaybookInputShell(kind: .search, focused: searchFocus) {
                Button { searchFocus = true } label: {
                    Image(systemName: "magnifyingglass").foregroundStyle(DaybookTheme.muted)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("f", modifiers: .command)
                .accessibilityLabel("search.placeholder")
            } field: {
                SyntaxTextField(
                    text: $query,
                    placeholder: L10n.string("search.placeholder", locale: locale),
                    focused: $searchFocus,
                    context: .search,
                    onEscape: {
                        if !query.isEmpty { query = "" }
                        else { NSApp.keyWindow?.makeFirstResponder(nil) }
                    }
                )
            } trailing: {
                if !query.isEmpty {
                    Button {
                        query = ""
                        searchFocus = true
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(DaybookTheme.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("footer.search.clear")
                }
            }
```

（后面的 `.zIndex(50)` 保留。）

### 3.7 `AreaChain/Features/MenuBar/MenuBarSearchField.swift`

把 `var body` 整体替换为（筛选 token 的滚动区原文照抄，只是从 HStack 移进 `leading` 槽）：

```swift
    var body: some View {
        DaybookInputShell(kind: .search, focused: toolbar.searchIsFocused) {
            Button { toolbar.focusSearch() } label: {
                Image(systemName: "magnifyingglass")
                    .font(DaybookType.caption)
                    .foregroundStyle(toolbar.searchIsFocused ? DaybookTheme.ink : DaybookTheme.muted)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("f", modifiers: .command)
            .accessibilityLabel("footer.search.label")

            if !tokens.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 3) {
                        ForEach(tokens) { token in
                            HStack(spacing: 2) {
                                if let dotColor = token.dotColor {
                                    Circle().fill(dotColor).frame(width: 4.5, height: 4.5)
                                } else if let icon = token.icon {
                                    Image(systemName: icon).font(.system(size: 7.5, weight: .bold))
                                }
                                Text(token.title)
                                    .font(.system(size: 9.5, weight: .medium))
                                    .lineLimit(1)
                                Button(action: token.onRemove) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 6.5, weight: .bold))
                                        .frame(width: 9, height: 9)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.leading, 4)
                            .padding(.trailing, 2.5)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(DaybookTheme.stamp.opacity(0.12)))
                            .overlay(Capsule().strokeBorder(DaybookTheme.stamp.opacity(0.35), lineWidth: 0.6))
                            .foregroundStyle(DaybookTheme.stamp)
                        }
                    }
                    .padding(.vertical, 1)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        } field: {
            DaybookTextField(
                text: $toolbar.searchText,
                placeholder: searchPlaceholder,
                fontSize: 11,
                focus: $toolbar.searchIsFocused,
                autocomplete: toolbar.autocomplete,
                availableTags: availableTags,
                onSubmit: {},
                onCommandReturn: {},
                allowsShiftNewline: false,
                onEscape: escapeSearch
            )
            .accessibilityLabel("footer.search.label")
            .accessibilityIdentifier("menubar.search.input")
        } trailing: {
            if !toolbar.searchText.isEmpty {
                Button { toolbar.clearSearch(); toolbar.focusSearch() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookTheme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("footer.search.clear")
                .help("footer.search.clear")
            }
        }
        .frame(minWidth: 110, maxWidth: .infinity)
        .syntaxSuggestions(toolbar.autocomplete, prefersAbove: true, enabled: toolbar.searchIsFocused && !toolbar.isFiltering)
        .background(KeyWindowHost { hostWindow = $0 })
        .onDisappear(perform: resignSearch)
        .help("footer.search.help")
    }
```

### 3.8 `AreaChain/Features/Workspace/WorkspaceHeaderBar.swift`（`WorkspaceHeaderSearchCapsule`）

把它的 `var body` 整体替换为：

```swift
    var body: some View {
        DaybookInputShell(kind: .search, focused: navigation.isSearchFocused) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(navigation.isSearchFocused ? DaybookTheme.ink : DaybookTheme.muted)
        } field: {
            DaybookTextField(
                text: $navigation.searchQuery,
                placeholder: L10n.string("search.placeholder", locale: locale),
                fontSize: 12,
                focus: $navigation.isSearchFocused,
                onSubmit: {},
                allowsShiftNewline: false,
                onEscape: {
                    navigation.clearSearch()
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
            )
            .accessibilityIdentifier("workspace.header.search")
        } trailing: {
            if !navigation.searchQuery.isEmpty {
                Button {
                    navigation.clearSearch()
                    navigation.isSearchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(DaybookTheme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("footer.search.clear")
            } else {
                Text("⌘F")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(DaybookTheme.muted.opacity(0.6))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DaybookTheme.rule.opacity(0.18))
                    )
            }
        }
        .frame(width: 260)
        // ⌘F 全局快捷键聚焦
        .background {
            Button("") {
                navigation.isSearchFocused = true
            }
            .keyboardShortcut("f", modifiers: .command)
            .opacity(0)
            .accessibilityHidden(true)
        }
    }
```

### 3.9 `AreaChain/Features/Workspace/TaskDetailSubtasksView.swift`

`addSubtaskInput` 整体替换为：

```swift
    private var addSubtaskInput: some View {
        DaybookInputShell(kind: .composer, focused: isInputFocused) {
            Image(systemName: "plus.circle")
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.stamp)
        } field: {
            SyntaxTextField(
                text: $newSubtaskTitle, placeholder: L10n.string("drawer.subtasks.placeholder", locale: locale),
                focused: $isInputFocused, context: .taskTags, fontSize: 11, onSubmit: submitNewSubtask
            )
        } trailing: {
            if !newSubtaskTitle.isEmpty {
                Button {
                    submitNewSubtask()
                } label: {
                    Text("drawer.subtasks.add")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DaybookTheme.stamp)
                }
                .buttonStyle(.plain)
            }
        }
    }
```

### 3.10 `AreaChain/Features/Workspace/TaskDetailNotesView.swift`

`notesEditorBox` 整体替换为（原 ZStack + RoundedRectangle + `.padding(4)` 都去掉）：

```swift
    private var notesEditorBox: some View {
        DaybookInputShell(kind: .editor, focused: isFocused) {
            SyntaxTextEditor(
                text: $draft, focused: $isFocused, placeholder: L10n.string("drawer.notes.placeholder", locale: locale),
                fontSize: 11, context: .capture, onSubmit: flushSave
            )
            .frame(minHeight: 56, maxHeight: 150)
            .onChange(of: draft) { _, newValue in
                if newValue != notes { EditDrafts.shared.notes[draftKey] = newValue }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused {
                    _ = BoardSelection.shared.consumeEscapeCancelsEdits()
                    flushSave()
                }
            }
        }
    }
```

### 3.11 `AreaChain/Features/Diary/DiaryWindowView.swift`

`content` 的最后一个 `else` 分支，把

```swift
            SyntaxTextEditor(text: $session.text, focused: $editorFocused,
                             placeholder: L10n.string("diary.quick.placeholder", locale: locale), onSubmit: save)
                .padding(8)
                .background(DaybookTheme.surface, in: RoundedRectangle(cornerRadius: DaybookRadius.small))
                .overlay(RoundedRectangle(cornerRadius: DaybookRadius.small)
                    .strokeBorder(editorFocused ? DaybookTheme.focusRing : DaybookTheme.rule, lineWidth: 1))
```

替换为

```swift
            DaybookInputShell(kind: .editor, focused: editorFocused) {
                SyntaxTextEditor(text: $session.text, focused: $editorFocused,
                                 placeholder: L10n.string("diary.quick.placeholder", locale: locale), onSubmit: save)
            }
```

检查点：

```bash
rg -n 'BoardCaptureRow\(|daybookInputChrome\(|DaybookField\(' AreaChain
./scripts/build.sh
```

第一条预期零输出（只剩定义处没有调用处）；第二条通过。

---

## 步骤 4：删除旧壳

```bash
git rm -q AreaChain/Theme/BoardCaptureRow.swift
```

在 `AreaChain/Theme/DaybookChrome.swift` 删除：
- `struct DaybookField<Content: View>: View { ... }` 整段（约 216–229 行）。
- 文件末尾 `// MARK: - 输入外框…` 注释、`private struct DaybookInputChrome: ViewModifier { ... }` 整段、以及 `extension View { func daybookInputChrome(...) }` 整段。

检查点：

```bash
rg -n 'BoardCaptureRow|DaybookInputChrome|daybookInputChrome|DaybookField\b' AreaChain AreaChainTests
./scripts/build.sh
```

第一条预期零输出；第二条通过。

---

## 步骤 5：新建测试 `AreaChainTests/Theme/DaybookInputShellTests.swift`

```swift
import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct DaybookInputShellTests {
    @Test func standardConfigurationFollowsMetrics() {
        let composer = DaybookInputShellConfiguration.standard(for: .composer)
        #expect(composer.height == DaybookMetrics.inputHeight)
        #expect(composer.radius == DaybookMetrics.Radius.inputComposer)
        #expect(composer.insets.top == 7)
        let search = DaybookInputShellConfiguration.standard(for: .search)
        #expect(search.height == DaybookMetrics.controlHeight)
        #expect(search.radius == 6)
        #expect(search.insets.top == 4)
        let editor = DaybookInputShellConfiguration.standard(for: .editor)
        #expect(editor.height == nil)
        #expect(editor.radius == DaybookMetrics.Radius.inputEditor)
    }

    @Test func composerAndSearchUseFixedHeightsAndEditorGrows() async throws {
        let content = VStack(alignment: .leading, spacing: 12) {
            DaybookInputShell(kind: .composer, focused: false) { Text("输入").frame(height: 20) }
                .background(InputShellMarker(name: "composer"))
            DaybookInputShell(kind: .search, focused: true) { Text("搜索").frame(height: 18) }
                .background(InputShellMarker(name: "search"))
            DaybookInputShell(kind: .editor, focused: false) { Text("编辑").frame(minHeight: 64) }
                .background(InputShellMarker(name: "editor"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        let host = NSHostingView(rootView: content)
        let window = makeWindow(host, size: NSSize(width: 360, height: 240))
        defer { window.contentView = nil; window.orderOut(nil) }
        try await settle(host)
        let composer = try #require(marker("composer", in: host))
        #expect(abs(composer.bounds.height - DaybookMetrics.inputHeight) < 1)
        let search = try #require(marker("search", in: host))
        #expect(abs(search.bounds.height - DaybookMetrics.controlHeight) < 1)
        let editor = try #require(marker("editor", in: host))
        let editorInsets = DaybookMetrics.inputInsets(.editor)
        #expect(editor.bounds.height >= 64 + editorInsets.top + editorInsets.bottom - 1)
    }

    @Test func configureOverridesMinHeight() async throws {
        let content = DaybookInputShell(kind: .editor, focused: false, configure: { $0.minHeight = 90 }) {
            Text("编辑")
        }
        .background(InputShellMarker(name: "editor"))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        let host = NSHostingView(rootView: content)
        let window = makeWindow(host, size: NSSize(width: 360, height: 200))
        defer { window.contentView = nil; window.orderOut(nil) }
        try await settle(host)
        let editor = try #require(marker("editor", in: host))
        #expect(editor.bounds.height >= 89)
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

private struct InputShellMarker: NSViewRepresentable {
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
./scripts/build.sh test --only-testing AreaChainTests/DaybookInputShellTests --only-testing AreaChainTests/DaybookTokenTests
```

---

## 步骤 6：文档同步

6.1 `AGENTS.md`：把 `- 输入优先复用现有 \`DaybookTextField\`、\`DaybookTextEditor\`、\`SyntaxTextField\`、\`SyntaxTextEditor\` 等组件。` 改为 `- 输入外壳统一用 \`DaybookInputShell\`（composer / search / editor 三种 kind，尺寸可用 configure 重载，颜色不可），正文控件复用现有 \`DaybookTextField\`、\`DaybookTextEditor\`、\`SyntaxTextField\`、\`SyntaxTextEditor\`。`（同一行后半句"新增、搜索、标题编辑和手记保存有各自语义…"保留。）

6.2 `docs/architecture.md`：
- 把 `` `DaybookInputChrome` 区分新增、搜索和多行编辑，将由 `DaybookInputShell` 取代。 `` 替换为 `` `DaybookInputShell` 是全应用唯一的输入外壳：composer / search 固定单行高（34 / 28），editor 多行不锁高；聚焦为菜单栏捕获框的灰描边，没有蓝色聚焦环。 ``
- 把 `` 浮层手记输入框使用 `DaybookTextField` 严格锁定为单行 34pt（与任务捕获框像素级对齐） `` 替换为 `` 浮层手记输入框与任务捕获框共用 `DaybookInputShell(kind: .composer)`，固定单行 34pt ``

6.3 `docs/usage.md`：把 `菜单栏快速输入框采用动态智能属性按钮，无属性时呈现轻柔半透明小图标，解析到标签、优先级或时间属性时展开高亮计数胶囊，点击可预览详情；外层维持严格的固定 58×22 几何边界以杜绝输入光标抖动。工作台新增输入栏维持固定宽度「属性 N」与详情抽屉联通。` 替换为 `菜单栏快速输入框右侧是「⌘↩」手记按钮，输入时在框下方显示实时解析预览；工作台新增输入栏右侧是固定 58×22 的「属性 N」按钮（有属性时高亮计数胶囊，点击预览详情）与「添加」按钮。两处输入框共用同一外壳：高 34、圆角 8、聚焦时灰描边。`

6.4 `docs/features.md`：把 `输入框右侧动态智能属性按钮，无属性时呈现半透明轻量图标，解析到属性时展开高亮胶囊，并保持严格的 58×22 几何边界杜绝打字抖动。` 替换为 `输入框右侧是「⌘↩」手记按钮，输入时在框下方显示实时解析预览。`

检查：

```bash
rg -n 'DaybookInputChrome|BoardCaptureRow|DaybookField\b|动态智能属性按钮' AGENTS.md README.md docs .agents/skills --glob '*.md'
python3 -B scripts/check_workflow.py
```

第一条预期零输出。

---

## 最终验证（全部必须通过）

```bash
# 1. 旧壳彻底消失（预期零输出）
rg -n 'BoardCaptureRow|DaybookInputChrome|daybookInputChrome|DaybookField\b|locksHeight|showsFocusShadow|paintsChrome' AreaChain AreaChainTests

# 2. 新壳被 13 处消费（预期 ≥ 13）
rg -c 'DaybookInputShell\(' AreaChain --glob '*.swift' | awk -F: '{s+=$2} END {print s}'

# 3. 没有人绕过壳自己画输入框（预期零输出）：field 槽以外不应再出现 focusRing 描边
rg -n 'focusRing' AreaChain/Features

# 4. 文档
rg -n 'DaybookInputChrome|BoardCaptureRow|动态智能属性按钮' AGENTS.md README.md docs .agents/skills --glob '*.md'

# 5. 测试（原生界面测试串行，期间不操作其他窗口）
./scripts/build.sh test \
  --only-testing AreaChainTests/DaybookInputShellTests \
  --only-testing AreaChainTests/DaybookTokenTests \
  --only-testing AreaChainTests/WorkspaceLayoutTests \
  --only-testing AreaChainTests/DaybookTextFieldTests \
  --only-testing AreaChainTests/DaybookTextFieldSearchTests \
  --only-testing AreaChainTests/CaptureOverlayLayoutTests \
  --only-testing AreaChainTests/InputSyntaxInteractionTests \
  --only-testing AreaChainTests/DiaryComposerInteractionTests \
  --only-testing AreaChainTests/WorkspaceRenderingTests \
  --only-testing AreaChainTests/MenuBarPopoverRenderingTests \
  --only-testing AreaChainTests/MenuBarToolbarStateTests \
  --only-testing AreaChainTests/DiaryWindowLifecycleTests \
  --only-testing AreaChainTests/PrivacyRenderingTests

# 6. 工作流检查
python3 -B scripts/check_workflow.py

# 7. 改动范围
git status --short
```

第 5 条里如果某个测试失败且信息是"某个尺寸与预期不符"（例如原来断言 38 或 28 的地方），**不要改测试**，把失败信息原样贴出来停下问我。

## 汇报格式

```
## P2 完成汇报
### 新建 / 删除的文件
### 修改文件（路径 — 一句话）
### 13 处消费者迁移清单（file:line — kind）
### 令牌修正（inputSearch 10→6、search 内边距 8/10→4/7、新增 border.faint）
### 验证输出（最终验证 1–7 条原样输出）
### 未做 / 发现的问题
```

最后把 `.cursor/plans/design-system.md` 第 8 节 `- [ ] P2 输入壳` 改成 `- [x]`，决策记录追加 `- <日期> P2 完成：<一句话>`。

## 绝对不要做

- 不要改 `DaybookTextField.swift` / `DaybookTextEditor.swift` / `SyntaxTextField.swift` / `SyntaxTextEditor.swift` / `SyntaxOverlay.swift` / `SyntaxAutocompleteView.swift`。
- 不要改任何 `SyntaxViewAnchor("...")`、`accessibilityIdentifier("...")`、`accessibilityLabel("...")` 字符串。
- 不要给壳加颜色参数；不要在调用点用 `configure` 改颜色。
- 不要动 `CommandReturnButton`、`CaptureAttributesButton`、`ComposerAddButton`（P3）。
- 不要动 `MenuBarSearchField` 里筛选 token 的 `Capsule`（P5）和 `WorkspaceHeaderSearchCapsule` 里的 `⌘F` 小标签（P5）。
- 不要 commit。
