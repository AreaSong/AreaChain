import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DetailTimePickerLifecycleTests {
    typealias Native = SettingsButtonTestSupport
    typealias Detail = DetailTimeSupport

    @Test(arguments: [false, true])
    func nilLifecycleExactCallbacksDisableClearAndLateAction(due: Bool) async throws {
        let fixture = try TimePickerConsumerFixture(minutes: nil)
        defer { fixture.cleanup() }
        let probe = TimePickerProbe()
        probe.minutes = nil
        let window = fixture.native.window(DetailTimeProbe(probe: probe, due: due),
            locale: "zh-Hans", size: NSSize(width: 320, height: 180))
        defer { SystemPageHost.release(window) }
        var stage = "initial open"
        defer { Detail.lifecycleState(stage, host: window) }
        let picker = try await Detail.open(due: due, locale: "zh-Hans", in: window)
        #expect(probe.writes.isEmpty)
        Detail.lifecycleState("initial popup", host: window, picker: picker)
        stage = "initial close"
        try await fixture.close(picker)
        #expect(probe.writes.isEmpty && probe.minutes == nil)
        stage = "reopen"
        let reopened = try await Detail.open(due: due, locale: "zh-Hans", in: window)
        try fixture.assign(0, to: reopened)
        try await SystemPageHost.settle(window)
        #expect(probe.minutes == 0 && probe.writes == [0])
        probe.minutes = 720
        try await SystemPageHost.settle(window)
        #expect(Detail.displayed(reopened) == 720)
        stage = "partial before disable"
        try await Detail.partial(reopened)
        stage = "disable and rejected action"
        probe.disabled = true
        try await SystemPageHost.settle(window)
        #expect(!reopened.isEnabled && probe.writes == [0])
        try fixture.assign(900, to: reopened)
        #expect(probe.writes == [0] && probe.minutes == 720)
        stage = "reenable and partial"
        probe.disabled = false
        try await SystemPageHost.settle(window)
        try await Detail.partial(reopened)
        stage = "close pending input"
        try await fixture.close(reopened)
        #expect(probe.writes == [0])
        stage = "clear and late action"
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await Native.click(Detail.button("row.time.clear", due: due, locale: "zh-Hans", in: window), in: window)
        #expect(probe.minutes == nil && probe.writes == [0, nil])
        try fixture.assign(900, to: reopened)
        #expect(probe.minutes == nil && probe.writes == [0, nil])
        stage = "last open/close"
        let last = try await Detail.open(due: due, locale: "zh-Hans", in: window)
        #expect(last.accessibilityHelp() == "未设置" && probe.writes == [0, nil])
        try await fixture.close(last)
        #expect(probe.writes == [0, nil])
    }
}

private struct DetailTimeProbe: View {
    @Bindable var probe: TimePickerProbe
    let due: Bool
    var body: some View {
        Group {
            if due {
                TaskDetailDueTime(dueMinutes: probe.minutes) { probe.binding.wrappedValue = $0 }
            } else {
                TaskDetailRemindChips(remindMinutes: probe.minutes) { probe.binding.wrappedValue = $0 }
            }
        }.disabled(probe.disabled).padding(12)
    }
}
