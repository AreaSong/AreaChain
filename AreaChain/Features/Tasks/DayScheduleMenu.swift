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
            Button("day.move.today") { onMove(todayKey) }
        }
        if currentDayKey != tomorrowKey {
            Button("day.move.tomorrow") { onMove(tomorrowKey) }
        }
        Button("day.pick") { pickingDay = true }
    }
}

struct DaySchedulePicker: View {
    var initialKey: String
    var confirmTitle: LocalizedStringKey = "day.confirm"
    var onPick: (String) -> Void

    @State private var pickedDate = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("day.pick.title")
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.muted)
            DatePicker(
                "day.date",
                selection: $pickedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            Button(confirmTitle) {
                onPick(DayKey.from(pickedDate))
            }
        }
        .padding(12)
        .onAppear {
            pickedDate = DayKey.date(from: initialKey) ?? .now
        }
    }
}
