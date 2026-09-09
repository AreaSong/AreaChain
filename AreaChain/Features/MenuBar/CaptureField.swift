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
            CaptureTokenBar(text: text)
        }
        .animation(DaybookMotion.interactive, value: text)
        .daybookHideInputChrome()
    }
}