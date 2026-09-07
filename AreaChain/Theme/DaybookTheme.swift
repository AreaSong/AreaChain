import AppKit
import SwiftUI

extension Color {
    static func daybook(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }))
    }
}

enum DaybookTheme {
    static let ink = Color.daybook(
        light: NSColor(calibratedRed: 0.18, green: 0.16, blue: 0.12, alpha: 1),
        dark: NSColor(calibratedRed: 0.91, green: 0.89, blue: 0.84, alpha: 1)
    )
    static let muted = Color.daybook(
        light: NSColor(calibratedRed: 0.45, green: 0.42, blue: 0.38, alpha: 1),
        dark: NSColor(calibratedRed: 0.55, green: 0.52, blue: 0.47, alpha: 1)
    )
    static let rule = Color.daybook(
        light: NSColor(calibratedRed: 0.82, green: 0.78, blue: 0.70, alpha: 1),
        dark: NSColor(calibratedRed: 0.27, green: 0.24, blue: 0.20, alpha: 1)
    )
    static let stamp = Color(red: 0.88, green: 0.63, blue: 0.29)
    static let paper = Color.daybook(
        light: NSColor(calibratedRed: 0.96, green: 0.94, blue: 0.88, alpha: 1),
        dark: NSColor(calibratedRed: 0.10, green: 0.09, blue: 0.08, alpha: 1)
    )
    static let done = Color.daybook(
        light: NSColor(calibratedRed: 0.55, green: 0.52, blue: 0.48, alpha: 1),
        dark: NSColor(calibratedRed: 0.45, green: 0.43, blue: 0.39, alpha: 1)
    )

    static let popoverSize = CGSize(width: 320, height: 420)
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
                    .frame(width: 14, height: 14)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(DaybookTheme.stamp)
                }
            }
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isDone ? "checkbox.done" : "checkbox.open")
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
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? Color.red.opacity(0.75) : DaybookTheme.muted)
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
            .font(.system(size: 11, weight: .semibold))
            .buttonStyle(.plain)
            .foregroundStyle(enabled && emphasized ? DaybookTheme.stamp : DaybookTheme.muted)
            .disabled(!enabled)
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
