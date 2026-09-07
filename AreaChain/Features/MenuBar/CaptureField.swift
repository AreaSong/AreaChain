import SwiftUI

struct CaptureField: View {
    @Binding var text: String
    @Binding var dayKey: String
    var todayKey: String
    var focus: FocusState<Bool>.Binding
    var onTodo: () -> Void
    var onDiary: () -> Void

    @Environment(\.locale) private var locale
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
            DaySchedulePicker(initialKey: dayKey, confirmTitle: "capture.use.day") { key in
                dayKey = key
                pickingDay = false
            }
        }
    }

    private var dayButton: some View {
        Menu {
            Button("capture.today") { dayKey = todayKey }
            Button("capture.tomorrow") { dayKey = tomorrowKey }
            Button("capture.pick") { pickingDay = true }
        } label: {
            Text(dayLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DaybookTheme.stamp)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("a11y.capture \(dayLabel)")
    }

    private var dayLabel: String {
        if dayKey == todayKey {
            return L10n.string("capture.today", locale: locale)
        }
        if dayKey == tomorrowKey {
            return L10n.string("capture.tomorrow", locale: locale)
        }
        return DayKey.shortStamp(dayKey, locale: locale)
    }

    private var placeholder: String {
        if dayKey == todayKey {
            return L10n.string("capture.placeholder.today", locale: locale)
        }
        if dayKey == tomorrowKey {
            return L10n.string("capture.placeholder.tomorrow", locale: locale)
        }
        let stamp = DayKey.shortStamp(dayKey, locale: locale)
        return L10n.string("capture.placeholder.other \(stamp)", locale: locale)
    }
}
