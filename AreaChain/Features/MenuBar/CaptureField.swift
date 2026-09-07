import SwiftUI

struct CaptureField: View {
    @Binding var text: String
    var focus: FocusState<Bool>.Binding
    var onTodo: () -> Void
    var onDiary: () -> Void

    var body: some View {
        TextField("回车加待办，⌘回车写日记", text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(DaybookTheme.ink)
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
            .focused(focus)
            .onSubmit(onTodo)
            .onKeyPress(.return, phases: .down) { press in
                if press.modifiers.contains(.command) {
                    onDiary()
                    return .handled
                }
                return .ignored
            }
    }
}
