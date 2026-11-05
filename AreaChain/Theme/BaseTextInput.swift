import AppKit
import SwiftUI

/// 输入框行模式：覆盖单行固定高、多行自适应高度与密码安全输入。
enum BaseInputLineMode: Equatable {
    case singleLine
    case multiLine(minHeight: CGFloat? = nil, maxHeight: CGFloat? = nil)
    case secure
}

/// 输入框语法高亮插件：按业务上下文选择高亮策略。
enum BaseInputSyntaxPlugin: Equatable {
    case none
    case taskSyntax
    case tagOnly
    case commandSearch
}

/// 垂直方向键枚举，用于历史回溯或候选列表上下导航。
enum BaseInputVerticalDirection: Equatable {
    case up
    case down
}

/// 前置槽位辅助图标：检测到私密标签时动态切换为盾牌图标。
struct BaseInputPrivacyPrefix: View {
    var defaultSystemImage: String
    var isPrivate: Bool

    var body: some View {
        Image(systemName: isPrivate ? "lock.shield" : defaultSystemImage)
            .font(DaybookType.subtitle)
            .foregroundStyle(isPrivate ? DaybookPalette.accent.base : DaybookPalette.text.secondary)
            .accessibilityIdentifier(isPrivate ? "base.input.prefix.private" : "base.input.prefix.default")
    }
}

/// 根据输入场景的语法插件策略，对富文本或 NSTextStorage 着色。
@MainActor
enum BaseInputSyntaxHighlighter {
    private static let commandRegex = try? NSRegularExpression(pattern: #"(?:^|\s)(/[^\s]+)"#)
    private static let searchFilterRegex = try? NSRegularExpression(
        pattern: #"(?:^|\s)((?:tag|type|status|date|in|is):[^\s]+)"#,
        options: [.caseInsensitive]
    )

    static func attributedString(
        for text: String, plugin: BaseInputSyntaxPlugin, font: NSFont,
        defaultColor: NSColor = NSColor(DaybookPalette.text.primary)
    ) -> NSAttributedString {
        guard plugin != .none, !text.isEmpty else {
            return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: defaultColor])
        }
        if plugin == .taskSyntax {
            return SyntaxHighlighter.attributedString(for: text, font: font, defaultColor: defaultColor)
        }
        let attributed = NSMutableAttributedString(
            string: text, attributes: [.font: font, .foregroundColor: defaultColor]
        )
        applyCustomTokens(to: attributed, text: text, plugin: plugin, font: font)
        return attributed
    }

    static func applyHighlighting(
        to storage: NSTextStorage, plugin: BaseInputSyntaxPlugin, font: NSFont,
        defaultColor: NSColor = NSColor(DaybookPalette.text.primary)
    ) {
        let text = storage.string
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        guard fullRange.length > 0 else { return }
        if plugin == .taskSyntax {
            SyntaxHighlighter.applyHighlighting(to: storage, font: font, defaultColor: defaultColor)
            return
        }
        storage.beginEditing()
        storage.setAttributes([.font: font, .foregroundColor: defaultColor], range: fullRange)
        if plugin != .none {
            applyCustomTokens(to: storage, text: text, plugin: plugin, font: font)
        }
        storage.endEditing()
    }

    private static func applyCustomTokens(
        to target: NSMutableAttributedString, text: String, plugin: BaseInputSyntaxPlugin, font: NSFont
    ) {
        let nsString = text as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        let mediumFont = NSFont.systemFont(ofSize: font.pointSize, weight: .medium)
        for token in NaturalLanguageParser.extractHighlightTokens(in: text) {
            guard token.range.location != NSNotFound, NSMaxRange(token.range) <= fullRange.length else { continue }
            if plugin == .tagOnly, case .tag = token.kind {} else if plugin == .tagOnly { continue }
            target.addAttributes([
                .foregroundColor: SyntaxHighlighter.color(for: token.kind),
                .font: mediumFont
            ], range: token.range)
        }
        guard plugin == .commandSearch else { return }
        if let matches = commandRegex?.matches(in: text, range: fullRange) {
            for match in matches where match.numberOfRanges > 1 && match.range(at: 1).location != NSNotFound {
                target.addAttributes([.foregroundColor: NSColor(DaybookPalette.accent.base), .font: mediumFont], range: match.range(at: 1))
            }
        }
        if let matches = searchFilterRegex?.matches(in: text, range: fullRange) {
            for match in matches where match.numberOfRanges > 1 && match.range(at: 1).location != NSNotFound {
                target.addAttributes([.foregroundColor: DaybookPalette.Syntax.timeNS, .font: mediumFont], range: match.range(at: 1))
            }
        }
    }
}

/// 全软件所有输入场景的唯一输入框基类，统一结合 DaybookInputShell 外观与 AppKit 文本桥接。
struct BaseTextInput<Prefix: View, Suffix: View>: View {
    @Binding var text: String
    var placeholder: String
    var focus: Binding<Bool>
    var kind: DaybookInputKind
    var lineMode: BaseInputLineMode
    var syntaxPlugin: BaseInputSyntaxPlugin
    var fontSize: CGFloat
    var fontWeight: NSFont.Weight
    var newlinePolicy: DaybookNewlinePolicy
    var commandChord: ShortcutChord?
    var autocomplete: SyntaxAutocompleteState?
    var availableTags: [String]
    var configureShell: ((inout DaybookInputShellConfiguration) -> Void)?
    var onSubmit: () -> Void
    var onCommandReturn: (() -> Void)?
    var onTab: (() -> Void)?
    var onEscape: (() -> Void)?
    var onVerticalArrow: ((BaseInputVerticalDirection) -> Void)?
    @ViewBuilder var prefix: () -> Prefix
    @ViewBuilder var suffix: () -> Suffix

    @FocusState private var secureFocused: Bool
    @State private var multiLineMarked = false
    @Environment(\.isEnabled) private var isEnabled

    init(
        text: Binding<String>, placeholder: String, focus: Binding<Bool>,
        kind: DaybookInputKind = .composer, lineMode: BaseInputLineMode = .singleLine,
        syntaxPlugin: BaseInputSyntaxPlugin = .none, fontSize: CGFloat = DaybookType.bodySize,
        fontWeight: NSFont.Weight = .regular, newlinePolicy: DaybookNewlinePolicy = .capture,
        commandChord: ShortcutChord? = nil, autocomplete: SyntaxAutocompleteState? = nil,
        availableTags: [String] = [], configureShell: ((inout DaybookInputShellConfiguration) -> Void)? = nil,
        onSubmit: @escaping () -> Void = {}, onCommandReturn: (() -> Void)? = nil,
        onTab: (() -> Void)? = nil, onEscape: (() -> Void)? = nil,
        onVerticalArrow: ((BaseInputVerticalDirection) -> Void)? = nil,
        @ViewBuilder prefix: @escaping () -> Prefix = { EmptyView() },
        @ViewBuilder suffix: @escaping () -> Suffix = { EmptyView() }
    ) {
        _text = text; self.placeholder = placeholder; self.focus = focus
        self.kind = kind; self.lineMode = lineMode; self.syntaxPlugin = syntaxPlugin
        self.fontSize = fontSize; self.fontWeight = fontWeight; self.newlinePolicy = newlinePolicy
        self.commandChord = commandChord; self.autocomplete = autocomplete; self.availableTags = availableTags
        self.configureShell = configureShell; self.onSubmit = onSubmit; self.onCommandReturn = onCommandReturn
        self.onTab = onTab; self.onEscape = onEscape; self.onVerticalArrow = onVerticalArrow
        self.prefix = prefix; self.suffix = suffix
    }

    var body: some View {
        DaybookInputShell(
            kind: resolvedShellKind, focused: isShellFocused,
            configure: mergedShellConfiguration,
            leading: prefix, field: { fieldContent }, trailing: suffix
        )
        .frame(maxHeight: resolvedMaxHeight)
    }

    private var resolvedShellKind: DaybookInputKind {
        if case .multiLine = lineMode { return .editor }
        return kind
    }

    private var isShellFocused: Bool {
        if lineMode == .secure { return (focus.wrappedValue || secureFocused) && isEnabled }
        return focus.wrappedValue && isEnabled
    }

    private var resolvedMaxHeight: CGFloat? {
        if case .multiLine(_, let maxHeight) = lineMode { return maxHeight }
        return nil
    }

    private func mergedShellConfiguration(_ config: inout DaybookInputShellConfiguration) {
        if case .multiLine(let minHeight, _) = lineMode, let minHeight {
            config.minHeight = minHeight
            config.height = nil
        }
        configureShell?(&config)
    }

    @ViewBuilder
    private var fieldContent: some View {
        switch lineMode {
        case .singleLine:
            BaseSingleLineTextField(
                text: $text, placeholder: placeholder, focus: focus,
                syntaxPlugin: syntaxPlugin, fontSize: fontSize, fontWeight: fontWeight,
                newlinePolicy: newlinePolicy, commandChord: commandChord,
                autocomplete: autocomplete, availableTags: availableTags,
                onSubmit: onSubmit, onCommandReturn: onCommandReturn,
                onTab: onTab, onEscape: onEscape, onVerticalArrow: onVerticalArrow
            )
            .frame(minHeight: fontSize + 6)
            .accessibilityLabel(placeholder)
        case .multiLine(let minHeight, let maxHeight):
            BaseMultiLineTextEditor(
                text: $text, focus: focus, placeholder: placeholder,
                syntaxPlugin: syntaxPlugin, fontSize: fontSize,
                commandChord: commandChord, autocomplete: autocomplete,
                availableTags: availableTags, onSubmit: onSubmit,
                onCommandReturn: onCommandReturn, onTab: onTab,
                onEscape: onEscape, onVerticalArrow: onVerticalArrow,
                onMarkedTextChange: { multiLineMarked = $0 }
            )
            .frame(minHeight: minHeight ?? 56, maxHeight: maxHeight)
            .overlay(alignment: .topLeading) {
                if text.isEmpty && !multiLineMarked {
                    Text(verbatim: placeholder)
                        .font(fontSize <= DaybookType.captionSize ? DaybookType.caption : DaybookType.body)
                        .foregroundStyle(DaybookPalette.text.secondary)
                        .padding(.horizontal, 9) // token-exempt: 对齐 AppKit NSTextView 文本容器内边距
                        .padding(.vertical, 4) // token-exempt: 对齐 AppKit NSTextView 垂直容器内边距
                        .allowsHitTesting(false)
                }
            }
            .accessibilityLabel(placeholder)
        case .secure:
            SecureField(text: $text, prompt: Text(verbatim: placeholder)) { Text(verbatim: placeholder) }
                .textFieldStyle(.plain)
                .font(DaybookType.body)
                .foregroundStyle(isEnabled ? DaybookPalette.text.primary : DaybookPalette.text.tertiary)
                .focused($secureFocused)
                .onSubmit(onSubmit)
                .onChange(of: focus.wrappedValue) { _, newValue in
                    if secureFocused != newValue { secureFocused = newValue }
                }
                .onChange(of: secureFocused) { _, newValue in
                    if focus.wrappedValue != newValue { focus.wrappedValue = newValue }
                }
                .accessibilityLabel(placeholder)
        }
    }

    /// 单行粘贴多行文本时自动将换行合并为空格，避免破坏单行布局与撤销栈。
    static func sanitizeSingleLinePaste(_ raw: String) -> String {
        DaybookNewlinePolicy.searchWhitespace.submittedText(raw, allowsShiftNewline: false)
    }
}

// MARK: - 派生便捷构造器

extension BaseTextInput where Prefix == EmptyView, Suffix == EmptyView {
    /// 任务与速记捕获框派生构造（34pt 高度，默认启用任务语法高亮）。
    static func composer<P: View, S: View>(
        text: Binding<String>, placeholder: String, focus: Binding<Bool>,
        syntaxPlugin: BaseInputSyntaxPlugin = .taskSyntax,
        autocomplete: SyntaxAutocompleteState? = nil, availableTags: [String] = [],
        commandChord: ShortcutChord? = nil, onSubmit: @escaping () -> Void = {},
        onCommandReturn: (() -> Void)? = nil, onTab: (() -> Void)? = nil,
        onEscape: (() -> Void)? = nil, onVerticalArrow: ((BaseInputVerticalDirection) -> Void)? = nil,
        @ViewBuilder prefix: @escaping () -> P = { EmptyView() },
        @ViewBuilder suffix: @escaping () -> S = { EmptyView() }
    ) -> BaseTextInput<P, S> {
        BaseTextInput<P, S>(
            text: text, placeholder: placeholder, focus: focus,
            kind: .composer, lineMode: .singleLine, syntaxPlugin: syntaxPlugin,
            newlinePolicy: .capture, commandChord: commandChord,
            autocomplete: autocomplete, availableTags: availableTags,
            onSubmit: onSubmit, onCommandReturn: onCommandReturn,
            onTab: onTab, onEscape: onEscape, onVerticalArrow: onVerticalArrow,
            prefix: prefix, suffix: suffix
        )
    }

    /// 统一搜索与筛选框派生构造（28pt 紧凑高度，默认启用命令与筛选语法高亮）。
    static func search<P: View, S: View>(
        text: Binding<String>, placeholder: String, focus: Binding<Bool>,
        syntaxPlugin: BaseInputSyntaxPlugin = .commandSearch,
        onSubmit: @escaping () -> Void = {}, onCommandReturn: (() -> Void)? = nil,
        onTab: (() -> Void)? = nil, onEscape: (() -> Void)? = nil,
        onVerticalArrow: ((BaseInputVerticalDirection) -> Void)? = nil,
        @ViewBuilder prefix: @escaping () -> P = { EmptyView() },
        @ViewBuilder suffix: @escaping () -> S = { EmptyView() }
    ) -> BaseTextInput<P, S> {
        BaseTextInput<P, S>(
            text: text, placeholder: placeholder, focus: focus,
            kind: .search, lineMode: .singleLine, syntaxPlugin: syntaxPlugin,
            newlinePolicy: .searchWhitespace,
            onSubmit: onSubmit, onCommandReturn: onCommandReturn,
            onTab: onTab, onEscape: onEscape, onVerticalArrow: onVerticalArrow,
            prefix: prefix, suffix: suffix
        )
    }

    /// 多行手记与备注编辑器派生构造（支持 Shift+Return 或直接换行及自定义最小/最大高度）。
    static func editor<P: View, S: View>(
        text: Binding<String>, placeholder: String, focus: Binding<Bool>,
        minHeight: CGFloat? = 72, maxHeight: CGFloat? = nil,
        syntaxPlugin: BaseInputSyntaxPlugin = .tagOnly,
        autocomplete: SyntaxAutocompleteState? = nil, availableTags: [String] = [],
        commandChord: ShortcutChord? = nil, onSubmit: @escaping () -> Void = {},
        onCommandReturn: (() -> Void)? = nil, onTab: (() -> Void)? = nil,
        onEscape: (() -> Void)? = nil, onVerticalArrow: ((BaseInputVerticalDirection) -> Void)? = nil,
        @ViewBuilder prefix: @escaping () -> P = { EmptyView() },
        @ViewBuilder suffix: @escaping () -> S = { EmptyView() }
    ) -> BaseTextInput<P, S> {
        BaseTextInput<P, S>(
            text: text, placeholder: placeholder, focus: focus,
            kind: .editor, lineMode: .multiLine(minHeight: minHeight, maxHeight: maxHeight),
            syntaxPlugin: syntaxPlugin, commandChord: commandChord,
            autocomplete: autocomplete, availableTags: availableTags,
            onSubmit: onSubmit, onCommandReturn: onCommandReturn,
            onTab: onTab, onEscape: onEscape, onVerticalArrow: onVerticalArrow,
            prefix: prefix, suffix: suffix
        )
    }

    /// 密码安全输入派生构造（遮蔽明文、禁用语法分析）。
    static func secure<P: View, S: View>(
        text: Binding<String>, placeholder: String, focus: Binding<Bool>,
        onSubmit: @escaping () -> Void = {}, onEscape: (() -> Void)? = nil,
        @ViewBuilder prefix: @escaping () -> P = { EmptyView() },
        @ViewBuilder suffix: @escaping () -> S = { EmptyView() }
    ) -> BaseTextInput<P, S> {
        BaseTextInput<P, S>(
            text: text, placeholder: placeholder, focus: focus,
            kind: .search, lineMode: .secure, syntaxPlugin: .none,
            onSubmit: onSubmit, onEscape: onEscape,
            prefix: prefix, suffix: suffix
        )
    }
}
