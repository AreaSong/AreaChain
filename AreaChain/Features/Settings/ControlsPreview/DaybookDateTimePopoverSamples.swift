import SwiftUI

/// 弹窗也只借用本样例的值，关闭或重置不会向其他窗口提交。
struct DaybookDateTimePopoverSamples: View {
    @Environment(\.isEnabled) private var isEnabled
    @State private var showDate = false
    @State private var showTime = false
    @State private var day = "2026-09-18"
    @State private var minutes: Int? = 720

    var body: some View {
        HStack {
            Button("controls.preview.datePopover") { showDate = true }
                .accessibilityIdentifier("preview.date.open")
                .popover(isPresented: $showDate) {
                    DaybookDatePicker(selection: $day, todayKey: "2026-09-18")
                        .padding(DaybookSpacing.lg)
                }
            Button("controls.preview.timePopover") { showTime = true }
                .accessibilityIdentifier("preview.time.open")
                .popover(isPresented: $showTime) {
                    DaybookTimePicker("row.time", minutes: $minutes)
                        .padding(DaybookSpacing.lg)
                        .frame(width: 220)
                }
        }
        .buttonStyle(DaybookButtonStyle(.quiet))
        .onChange(of: isEnabled) { _, enabled in
            if !enabled { showDate = false; showTime = false }
        }
    }
}
