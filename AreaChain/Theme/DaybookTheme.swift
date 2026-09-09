import AppKit
import SwiftUI

extension Color {
    static func daybook(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }))
    }
}

enum DaybookSwatch {
    static let inkLight = (0.12, 0.12, 0.14)
    static let inkDark = (0.96, 0.96, 0.98)
    static let mutedLight = (0.40, 0.41, 0.45)
    static let mutedDark = (0.70, 0.71, 0.75)
    static let ruleLight = (0.86, 0.88, 0.92)
    static let ruleDark = (0.24, 0.25, 0.28)
    static let stampLight = (0.08, 0.35, 0.76)
    static let stampDark = (0.38, 0.68, 1.0)
    static let paperLight = (0.98, 0.98, 0.99)
    static let paperDark = (0.12, 0.12, 0.13)
    static let doneLight = (0.40, 0.42, 0.45)
    static let doneDark = (0.68, 0.70, 0.74)
    static let destructiveLight = (0.78, 0.16, 0.14)
    static let destructiveDark = (0.98, 0.52, 0.48)
    static let checkmarkLight = (1.0, 1.0, 1.0)
    static let checkmarkDark = (0.08, 0.08, 0.10)
}

enum ContrastMath {
    static func relativeLuminance(r: Double, g: Double, b: Double) -> Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    static func ratio(
        _ a: (Double, Double, Double),
        _ b: (Double, Double, Double)
    ) -> Double {
        let first = relativeLuminance(r: a.0, g: a.1, b: a.2)
        let second = relativeLuminance(r: b.0, g: b.1, b: b.2)
        let high = max(first, second)
        let low = min(first, second)
        return (high + 0.05) / (low + 0.05)
    }
}

enum DaybookTheme {
    static let ink = Color.daybook(swatch: DaybookSwatch.inkLight, dark: DaybookSwatch.inkDark)
    static let muted = Color.daybook(swatch: DaybookSwatch.mutedLight, dark: DaybookSwatch.mutedDark)
    static let rule = Color.daybook(swatch: DaybookSwatch.ruleLight, dark: DaybookSwatch.ruleDark)
    static let stamp = Color.daybook(swatch: DaybookSwatch.stampLight, dark: DaybookSwatch.stampDark)
    static let paper = Color.daybook(swatch: DaybookSwatch.paperLight, dark: DaybookSwatch.paperDark)
    static let done = Color.daybook(swatch: DaybookSwatch.doneLight, dark: DaybookSwatch.doneDark)
    static let destructive = Color.daybook(
        swatch: DaybookSwatch.destructiveLight,
        dark: DaybookSwatch.destructiveDark
    )
    static let hoverFill = Color.daybook(
        light: NSColor.black.withAlphaComponent(0.04),
        dark: NSColor.white.withAlphaComponent(0.08)
    )
    static let pressFill = Color.daybook(
        light: NSColor.black.withAlphaComponent(0.08),
        dark: NSColor.white.withAlphaComponent(0.14)
    )
    static let surface = Color.daybook(
        light: NSColor.white.withAlphaComponent(0.65),
        dark: NSColor(white: 0.18, alpha: 0.55)
    )
    static let cardSurface = Color.daybook(
        light: NSColor.white.withAlphaComponent(0.55),
        dark: NSColor(white: 0.18, alpha: 0.55)
    )
    static let cardSurfaceHover = Color.daybook(
        light: NSColor.white.withAlphaComponent(0.85),
        dark: NSColor(white: 0.24, alpha: 0.75)
    )
    static let cardSelectionFill = Color.daybook(
        light: NSColor.daybook(DaybookSwatch.stampLight).withAlphaComponent(0.08),
        dark: NSColor.daybook(DaybookSwatch.stampDark).withAlphaComponent(0.14)
    )
    static let cardSelectionStroke = Color.daybook(
        light: NSColor.daybook(DaybookSwatch.stampLight).withAlphaComponent(0.35),
        dark: NSColor.daybook(DaybookSwatch.stampDark).withAlphaComponent(0.40)
    )
    static let cardBorder = Color.daybook(
        light: NSColor.black.withAlphaComponent(0.06),
        dark: NSColor.white.withAlphaComponent(0.08)
    )
    static let cardBorderHover = Color.daybook(
        light: NSColor.black.withAlphaComponent(0.12),
        dark: NSColor.white.withAlphaComponent(0.16)
    )
    static let focusRing = stamp
    static let popoverWidth: CGFloat = 380
    static let popoverMinHeight: CGFloat = 280
    static let popoverMaxHeight: CGFloat = 490
    static let popoverHeight: CGFloat = 490
    static let popoverSize = CGSize(width: popoverWidth, height: popoverHeight)
    static let workspaceSize = CGSize(width: 960, height: 640)
    static let workspaceMinSize = CGSize(width: 780, height: 500)
    static let hit: CGFloat = 28
    static let space: CGFloat = 8
}

// MARK: - Modern Design Tokens

enum DaybookRadius {
    static let xs: CGFloat = 4
    static let small: CGFloat = 6
    static let medium: CGFloat = 10
    static let card: CGFloat = 12
    static let large: CGFloat = 16
    static let full: CGFloat = 999
}

enum DaybookSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

enum DaybookShadow {
    static let cardSubtle = Color.black.opacity(0.04)
    static let cardHover = Color.black.opacity(0.08)
    static let popover = Color.black.opacity(0.15)
}

extension Color {
    static func daybook(
        swatch: (Double, Double, Double),
        dark: (Double, Double, Double)
    ) -> Color {
        .daybook(light: NSColor.daybook(swatch), dark: NSColor.daybook(dark))
    }
}

extension NSColor {
    static func daybook(_ rgb: (Double, Double, Double)) -> NSColor {
        NSColor(calibratedRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
    }
}

/// 现代 Pro 纯净表面，安全替换旧有的繁琐横线笔记本纹理
struct RuledPaper: View {
    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct InkCheckbox: View {
    var isDone: Bool
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(
                        isDone
                            ? DaybookTheme.stamp
                            : (hovering ? DaybookTheme.stamp.opacity(0.65) : DaybookTheme.ink.opacity(0.28)),
                        lineWidth: 1.5
                    )
                    .background(
                        Circle()
                            .fill(isDone ? DaybookTheme.stamp : Color.clear)
                    )
                    .frame(width: 16, height: 16)

                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(
                            Color.daybook(
                                swatch: DaybookSwatch.checkmarkLight,
                                dark: DaybookSwatch.checkmarkDark
                            )
                        )
                        .accessibilityHidden(true)
                }
            }
            .frame(width: DaybookTheme.hit, height: DaybookTheme.hit)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(isDone ? Text("checkbox.done") : Text("checkbox.open"))
        .accessibilityAddTraits(isDone ? [.isSelected] : [])
    }
}

struct SectionStamp: View {
    var title: LocalizedStringKey
    var icon: String? = nil
    var count: Int? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DaybookTheme.stamp)
            }
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(DaybookTheme.muted)
            if let count {
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(DaybookTheme.muted)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
    }
}

struct RowIconButton: View {
    var systemName: String
    var label: LocalizedStringKey
    var role: ButtonRole? = nil
    var action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: DaybookTheme.hit, height: DaybookTheme.hit)
                .contentShape(Rectangle())
        }
        .buttonStyle(DaybookQuietButtonStyle(destructive: role == .destructive))
        .accessibilityLabel(label)
        .help(label)
    }
}

struct ComposerAddButton: View {
    var title: LocalizedStringKey = "row.add"
    var enabled: Bool
    var emphasized: Bool = true
    var action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.system(size: 12, weight: .semibold))
            .buttonStyle(DaybookQuietButtonStyle(prominent: emphasized && enabled))
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.45)
    }
}

extension View {
    func daybookScroll() -> some View {
        scrollIndicators(.automatic)
    }

    @ViewBuilder
    func daybookHideInputChrome() -> some View {
        if #available(macOS 15.4, *) {
            self
                .writingToolsBehavior(.disabled)
                .writingToolsAffordanceVisibility(.hidden)
        } else if #available(macOS 15.0, *) {
            self.writingToolsBehavior(.disabled)
        } else {
            self
        }
    }
}

/// AppKit 单行输入，避开 SwiftUI TextField 在 NSPopover 里错位的系统附件按钮。
struct DaybookTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var fontSize: CGFloat = 13
    var focus: FocusState<Bool>.Binding
    var onSubmit: () -> Void
    var onCommandReturn: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: "")
        field.placeholderString = placeholder
        field.font = .systemFont(ofSize: fontSize)
        field.textColor = NSColor(DaybookTheme.ink)
        field.drawsBackground = false
        field.backgroundColor = .clear
        field.isBordered = false
        field.isBezeled = false
        field.focusRingType = .none
        field.lineBreakMode = .byTruncatingTail
        if let cell = field.cell as? NSTextFieldCell {
            cell.wraps = false
            cell.isScrollable = true
            cell.usesSingleLineMode = false
        }
        field.setContentHuggingPriority(.defaultHigh, for: .vertical)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text {
            if field.currentEditor() == nil || text.isEmpty {
                field.stringValue = text
                field.currentEditor()?.string = text
            }
        }
        if field.placeholderString != placeholder {
            field.placeholderString = placeholder
        }
        field.font = .systemFont(ofSize: fontSize)
        field.textColor = NSColor(DaybookTheme.ink)
        if focus.wrappedValue {
            if field.window != nil, field.currentEditor() == nil {
                DispatchQueue.main.async {
                    guard focus.wrappedValue, field.currentEditor() == nil else { return }
                    field.window?.makeFirstResponder(field)
                }
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: DaybookTextField

        init(_ parent: DaybookTextField) {
            self.parent = parent
        }

        @objc func submitted(_ sender: Any? = nil) {
            if NSApp.currentEvent?.modifierFlags.contains(.command) == true, let extra = parent.onCommandReturn {
                extra()
            } else {
                parent.onSubmit()
            }
        }

        func controlTextDidChange(_ obj: Notification) {
            parent.text = (obj.object as? NSTextField)?.stringValue ?? ""
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            parent.focus.wrappedValue = true
            guard let editor = (obj.object as? NSTextField)?.currentEditor() as? NSTextView else { return }
            editor.isAutomaticQuoteSubstitutionEnabled = false
            editor.isAutomaticDashSubstitutionEnabled = false
            editor.isAutomaticTextReplacementEnabled = false
            editor.isAutomaticSpellingCorrectionEnabled = false
            if #available(macOS 15.1, *) {
                editor.writingToolsBehavior = .none
            }
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            parent.focus.wrappedValue = false
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertLineBreak(_:)) ||
               (commandSelector == #selector(NSResponder.insertNewline(_:)) && NSApp.currentEvent?.modifierFlags.contains(.shift) == true) {
                textView.insertNewlineIgnoringFieldEditor(nil)
                return true
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if textView.hasMarkedText() {
                    return false
                }
                submitted()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                textView.window?.makeFirstResponder(nil)
                parent.focus.wrappedValue = false
                return true
            }
            return false
        }
    }
}
