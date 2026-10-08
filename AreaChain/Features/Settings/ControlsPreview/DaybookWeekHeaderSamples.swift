import SwiftUI

struct DaybookWeekHeaderSamples: View {
    @Environment(\.locale) private var locale
    var body: some View {
        HStack {
            ForEach(0..<4) { state in
                let day = "2026-09-\(27 + state)"
                DaybookDateCell(dayKey: day, isToday: state & 1 != 0, isSelected: state & 2 != 0,
                    presentation: .weekHeader(shortStamp: DayKey.shortStamp(day, locale: locale))) {}
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("preview.weekHeader")
    }
}
