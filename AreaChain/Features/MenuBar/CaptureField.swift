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
        HStack(spacing: 8) {
            DaybookTextField(
                text: $text,
                placeholder: L10n.string("capture.placeholder.today", locale: locale),
                focus: focus,
                onSubmit: onTodo,
                onCommandReturn: onDiary
            )
            ComposerAddButton(enabled: canSubmit, action: onTodo)
            ComposerAddButton(title: "capture.diary", enabled: canSubmit, emphasized: false, action: onDiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DaybookTheme.paper.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(DaybookTheme.rule, lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .daybookHideInputChrome()
    }
}