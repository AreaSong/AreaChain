import SwiftUI

@Observable
@MainActor
final class CaptureSession {
    static let shared = CaptureSession()
    var draft = ""
}

struct CaptureField: View {
    @Binding var text: String
    var focus: FocusState<Bool>.Binding
    var onTodo: () -> Void
    var onDiary: () -> Void

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField("capture.placeholder.today", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(DaybookTheme.ink)
                .focused(focus)
                .onSubmit(onTodo)
                .onKeyPress(.return, phases: .down) { press in
                    if press.modifiers.contains(.command) {
                        onDiary()
                        return .handled
                    }
                    return .ignored
                }
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
    }
}