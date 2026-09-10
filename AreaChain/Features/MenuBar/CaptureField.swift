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
        let focused = focus.wrappedValue
        let plusColor = focused ? DaybookTheme.stamp : DaybookTheme.muted
        let lineColor = focused ? DaybookTheme.stamp : DaybookTheme.rule
        let lineHeight: CGFloat = focused ? 1.4 : 0.8
        let diaryInk = canSubmit ? DaybookTheme.ink : DaybookTheme.muted
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "plus")
                    .font(DaybookType.subtitle.weight(.semibold))
                    .foregroundStyle(plusColor)
                    .frame(width: 12)

                DaybookTextField(
                    text: $text,
                    placeholder: L10n.string("capture.placeholder.today", locale: locale),
                    focus: focus,
                    onSubmit: onTodo,
                    onCommandReturn: onDiary
                )
                .accessibilityLabel("capture.placeholder.today")

                ComposerAddButton(enabled: canSubmit, action: onTodo)

                Button(action: onDiary) {
                    HStack(spacing: 3) {
                        Text("capture.diary")
                            .font(DaybookType.caption.weight(.medium))
                        Text("⌘↩")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(DaybookTheme.muted)
                    }
                    .foregroundStyle(diaryInk)
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1 : 0.45)
                .help("capture.diary")
            }
            .padding(.bottom, 7)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(lineColor)
                    .frame(height: lineHeight)
            }

            CaptureTokenBar(text: text)
        }
        .animation(DaybookMotion.interactive, value: text)
        .animation(DaybookMotion.interactive, value: focused)
        .daybookHideInputChrome()
    }
}
