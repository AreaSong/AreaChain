import SwiftUI

struct TaskDetailDueTime: View {
    var dueMinutes: Int?
    var onSelectMinutes: (Int?) -> Void
    @Environment(\.locale) private var locale
    @State private var pickingTime = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("drawer.due.title")
                    .font(DaybookType.label)
                    .foregroundStyle(DaybookPalette.text.secondary)
                Spacer()
                if let dueMinutes {
                    Text(RemindMinutes.label(dueMinutes, locale: locale))
                        .font(.system(size: 10, weight: .bold, design: .monospaced)) // token-exempt: 截止时刻用等宽
                        .foregroundStyle(DaybookPalette.accent.base)
                    DaybookIconButton(systemName: "xmark.circle.fill", label: "row.time.clear", size: .inline) {
                        onSelectMinutes(nil)
                    }
                }
            }
            Button(dueMinutes == nil ? "row.time.set" : "drawer.remind.custom") {
                pickingTime = true
            }
            .buttonStyle(DaybookButtonStyle(.subtle, size: .compact))
            .popover(isPresented: $pickingTime) {
                DatePicker(
                    "drawer.due.title",
                    selection: timeBinding,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.stepperField)
                .padding(12)
            }
        }
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { RemindMinutes.date(minutes: dueMinutes ?? RemindMinutes.from(date: .now)) ?? .now },
            set: { onSelectMinutes(RemindMinutes.from(date: $0)) }
        )
    }
}
