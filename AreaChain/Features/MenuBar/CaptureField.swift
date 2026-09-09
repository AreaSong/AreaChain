import SwiftUI

@Observable
@MainActor
final class CaptureSession {
    static let shared = CaptureSession()
    var draft = ""
}

struct CaptureField: View {
    @Environment(\.locale) private var locale
    @Binding var text: String
    var focus: FocusState<Bool>.Binding
    var onTodo: () -> Void
    var onDiary: () -> Void

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            DaybookField(focused: focus.wrappedValue) {
                HStack(spacing: 8) {
                    DaybookTextField(
                        text: $text,
                        placeholder: L10n.string("capture.placeholder.today", locale: locale),
                        focus: focus,
                        onSubmit: onTodo,
                        onCommandReturn: onDiary
                    )
                    .accessibilityLabel("capture.placeholder.today")
                    ComposerAddButton(enabled: canSubmit, action: onTodo)
                    ComposerAddButton(title: "capture.diary", enabled: canSubmit, emphasized: false, action: onDiary)
                }
            }
            parsedTokensBar
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: text)
        .daybookHideInputChrome()
    }

    private var parsedTokensBar: some View {
        let parsed = NaturalLanguageParser.parse(text)
        return Group {
            if parsed.hasTokens && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 6) {
                    if let time = parsed.timeLabel {
                        PillBadge(title: L10n.format("workspace.remind.suffix", locale: locale, time), icon: "clock.fill", color: DaybookTheme.stamp, isSelected: true)
                    }
                    if let tag = parsed.tagName {
                        PillBadge(title: "#\(tag)", icon: "tag.fill", color: Color.daybook(light: NSColor.systemIndigo, dark: NSColor.systemIndigo), isSelected: true)
                    }
                    if let priority = parsed.priorityLabel {
                        PillBadge(
                            title: priority,
                            icon: "exclamationmark.circle.fill",
                            color: parsed.isImportant && parsed.isUrgent ? DaybookTheme.destructive : DaybookTheme.stamp,
                            isSelected: true
                        )
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 4)
                .padding(.top, 1)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}