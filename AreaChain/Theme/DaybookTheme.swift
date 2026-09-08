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
    static let inkLight = (0.18, 0.16, 0.12)
    static let inkDark = (0.91, 0.89, 0.84)
    static let mutedLight = (0.45, 0.42, 0.38)
    static let mutedDark = (0.72, 0.68, 0.62)
    static let ruleLight = (0.82, 0.78, 0.70)
    static let ruleDark = (0.38, 0.34, 0.28)
    static let stampLight = (0.62, 0.34, 0.06)
    static let stampDark = (0.90, 0.68, 0.32)
    static let paperLight = (0.96, 0.94, 0.88)
    static let paperDark = (0.10, 0.09, 0.08)
    static let doneLight = (0.40, 0.38, 0.34)
    static let doneDark = (0.68, 0.65, 0.60)
    static let destructiveLight = (0.72, 0.18, 0.14)
    static let destructiveDark = (0.95, 0.52, 0.46)
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
    static let hoverFill = ink.opacity(0.07)
    static let pressFill = ink.opacity(0.12)
    static let surface = paper.opacity(0.72)
    static let focusRing = stamp
    static let popoverSize = CGSize(width: 380, height: 500)
    static let workspaceSize = CGSize(width: 960, height: 640)
    static let workspaceMinSize = CGSize(width: 780, height: 500)
    static let hit: CGFloat = 28
    static let space: CGFloat = 8
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

struct RuledPaper: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 28
            var y: CGFloat = 36
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 16, y: y))
                path.addLine(to: CGPoint(x: size.width - 16, y: y))
                context.stroke(path, with: .color(DaybookTheme.rule.opacity(0.45)), lineWidth: 0.6)
                y += step
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct InkCheckbox: View {
    var isDone: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(isDone ? DaybookTheme.done : DaybookTheme.ink.opacity(0.85), lineWidth: 1.4)
                    .frame(width: 15, height: 15)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DaybookTheme.stamp)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: DaybookTheme.hit, height: DaybookTheme.hit)
            .contentShape(Rectangle())
        }
        .buttonStyle(DaybookQuietButtonStyle())
        .accessibilityLabel(isDone ? Text("checkbox.done") : Text("checkbox.open"))
        .accessibilityAddTraits(isDone ? [.isSelected] : [])
    }
}

struct SectionStamp: View {
    var title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .tracking(2.4)
            .foregroundStyle(DaybookTheme.muted)
            .padding(.top, 8)
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
        scrollIndicators(.hidden)
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
            cell.usesSingleLineMode = true
        }
        field.setContentHuggingPriority(.defaultHigh, for: .vertical)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text {
            field.stringValue = text
        }
        if field.placeholderString != placeholder {
            field.placeholderString = placeholder
        }
        field.font = .systemFont(ofSize: fontSize)
        field.textColor = NSColor(DaybookTheme.ink)
        if focus.wrappedValue, field.window != nil, field.currentEditor() == nil {
            DispatchQueue.main.async {
                guard focus.wrappedValue else { return }
                field.window?.makeFirstResponder(field)
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
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                submitted()
                return true
            }
            return false
        }
    }
}
