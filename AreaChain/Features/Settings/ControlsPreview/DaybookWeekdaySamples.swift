import SwiftUI

/// 原 ControlsPreview 的星期样例，四个实例各自限定宿主；不增加展示应用或共享状态。
struct DaybookWeekdaySamples: View {
    @State private var draft = 0
    @State private var saved = WeekdayMask.only(weekday: 2)
    @State private var independent = WeekdayMask.workdays

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TaskDetailWeekdayPicker(resolvedMask: draft, onUpdateMask: { draft = $0 }, allowsEmpty: true)
                .accessibilityElement(children: .contain).accessibilityIdentifier("preview.weekday.draft")
            TaskDetailWeekdayPicker(resolvedMask: saved, onUpdateMask: { saved = $0 }, showsTitle: false)
                .accessibilityElement(children: .contain).accessibilityIdentifier("preview.weekday.saved")
            TaskDetailWeekdayPicker(resolvedMask: WeekdayMask.workdays, onUpdateMask: { _ in })
                .disabled(true)
                .accessibilityElement(children: .contain).accessibilityIdentifier("preview.weekday.disabled")
            DaybookWeekdayPicker(selection: independent, onUpdateSelection: { independent = $0 },
                                 accessibilityTitle: Text("residents.days"))
                .accessibilityElement(children: .contain).accessibilityIdentifier("preview.weekday.independent")
        }
    }
}
