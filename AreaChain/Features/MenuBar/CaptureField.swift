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
                        tokenBadge(icon: "clock.fill", text: "\(time) 提醒", color: DaybookTheme.stamp)
                    }
                    if let tag = parsed.tagName {
                        tokenBadge(icon: "tag.fill", text: "#\(tag)", color: Color.daybook(light: NSColor.systemIndigo, dark: NSColor.systemIndigo))
                    }
                    if let priority = parsed.priorityLabel {
                        tokenBadge(
                            icon: "exclamationmark.circle.fill",
                            text: priority,
                            color: parsed.isImportant && parsed.isUrgent ? DaybookTheme.destructive : DaybookTheme.stamp
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

    private func tokenBadge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
            Text(text)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
    }
}