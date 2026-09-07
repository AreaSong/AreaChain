import SwiftUI

struct CaptureField: View {
    @Binding var text: String
    @Binding var dayKey: String
    var todayKey: String
    var focus: FocusState<Bool>.Binding
    var onTodo: () -> Void
    var onDiary: () -> Void

    @State private var pickingDay = false

    private var tomorrowKey: String {
        DayKey.shifted(todayKey, by: 1)
    }

    var body: some View {
        HStack(spacing: 8) {
            dayButton
            TextField(placeholder, text: $text)
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
        .popover(isPresented: $pickingDay) {
            DaySchedulePicker(initialKey: dayKey, confirmTitle: "用这一天") { key in
                dayKey = key
                pickingDay = false
            }
        }
    }

    private var dayButton: some View {
        Menu {
            Button("今天") { dayKey = todayKey }
            Button("明天") { dayKey = tomorrowKey }
            Button("选一天…") { pickingDay = true }
        } label: {
            Text(dayLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DaybookTheme.stamp)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("待办写到 \(dayLabel)")
    }

    private var dayLabel: String {
        if dayKey == todayKey { return "今天" }
        if dayKey == tomorrowKey { return "明天" }
        return DayKey.shortStamp(dayKey)
    }

    private var placeholder: String {
        if dayKey == todayKey {
            return "回车加待办，⌘回车写日记"
        }
        if dayKey == tomorrowKey {
            return "回车加到明天，⌘回车仍写今天日记"
        }
        return "回车加到\(DayKey.shortStamp(dayKey))，⌘回车仍写今天日记"
    }
}
