import SwiftUI

struct DayScheduleMenu: View {
    var todayKey: String
    var currentDayKey: String?
    var onMove: (String) -> Void
    @Binding var pickingDay: Bool

    private var tomorrowKey: String {
        DayKey.shifted(todayKey, by: 1)
    }

    var body: some View {
        if currentDayKey != todayKey {
            Button("放到今天") { onMove(todayKey) }
        }
        if currentDayKey != tomorrowKey {
            Button("放到明天") { onMove(tomorrowKey) }
        }
        Button("选一天…") { pickingDay = true }
    }
}

struct DaySchedulePicker: View {
    var initialKey: String
    var onPick: (String) -> Void

    @State private var pickedDate = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("改到哪一天")
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.muted)
            DatePicker(
                "日期",
                selection: $pickedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            Button("改到这一天") {
                onPick(DayKey.from(pickedDate))
            }
        }
        .padding(12)
        .onAppear {
            pickedDate = DayKey.date(from: initialKey) ?? .now
        }
    }
}
