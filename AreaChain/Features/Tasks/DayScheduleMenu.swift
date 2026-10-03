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
        if currentDayKey != afterTomorrowKey {
            Button("day.move.afterTomorrow") { onMove(afterTomorrowKey) }
        }
        Button("day.pick") { pickingDay = true }
    }

    private var afterTomorrowKey: String {
        DayKey.shifted(todayKey, by: 2)
    }
}

struct DaySchedulePicker: View {
    var initialKey: String
    var confirmTitle: LocalizedStringKey = "day.confirm"
    var onPick: (String) -> Void

    @Environment(\.calendar) private var calendar
    @State private var pickedKey = DayKey.today()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("day.pick.title")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
            DaybookDatePicker(selection: $pickedKey)
            Button(confirmTitle) {
                onPick(pickedKey)
            }
            .buttonStyle(DaybookButtonStyle(.prominent))
        }
        .padding(12)
        .onAppear {
            pickedKey = DayKey.from(DayKey.date(from: initialKey, calendar: calendar) ?? .now, calendar: calendar)
        }
    }
}
