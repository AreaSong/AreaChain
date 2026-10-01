import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct BatchMenuConsumerTests {
    private typealias Native = SettingsButtonTestSupport
    private typealias Menus = MenuButtonTestSupport

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func nativeEntrancesCancelAndDispatchOriginalParameters(locale: String, scheme: ColorScheme) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let tag = TagItem(name: "合成的长标签 Synthetic long tag for menu selection", sortOrder: 0)
        fixture.container.mainContext.insert(tag)
        let trace = BatchMenuTrace()
        let window = fixture.window(bar(trace, tags: [tag]), locale: locale, scheme: scheme,
                                    size: NSSize(width: 580, height: 160))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let keys = ["batch.move.date", "batch.status", "batch.tag"]
        let nodes = try keys.map { try Menus.menu($0, locale: locale, in: window) }
        try Native.assertBounds(nodes + Native.buttons(in: window), in: window)
        for node in nodes {
            try Menus.assertTextWidth(node, in: window)
            for fraction in [CGFloat(0.04), 0.18, 0.65, 0.96] {
                _ = try await Menus.openAndEscape(node, xFraction: fraction, in: window)
                #expect(trace.events.isEmpty)
            }
            for fraction in [CGFloat(0.05), 0.95] {
                _ = try await Menus.openAndEscape(node, yFraction: fraction, in: window)
                #expect(trace.events.isEmpty)
            }
        }
        try Native.snapshot(window, name: "batch-menus-\(locale)-\(scheme)")
        let dates = try await Menus.openAndEscape(nodes[0], in: window)
        try Menus.dispatch(Menus.localized("capture.today", locale), in: dates)
        try Menus.dispatch(Menus.localized("capture.tomorrow", locale), in: dates)
        let status = try await Menus.openAndEscape(nodes[1], in: window)
        try Menus.dispatch(Menus.localized("batch.done", locale), in: status)
        try Menus.dispatch(Menus.localized("batch.undone", locale), in: status)
        let tags = try await Menus.openAndEscape(nodes[2], in: window)
        try Menus.dispatch("#\(tag.name)", in: tags)
        try Menus.dispatch("#\(tag.name)", occurrence: 1, in: tags)
        #expect(trace.events == ["today", "tomorrow", "done:true", "done:false",
                                 "tag:\(tag.id):true", "tag:\(tag.id):false"])
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func allMenusEnableButtonsAndNoteFitNarrowHost(locale: String, scheme: ColorScheme) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let trace = BatchMenuTrace()
        let tag = TagItem(name: "Synthetic", sortOrder: 0)
        let content = bar(trace, tags: [tag], enable: true, note: "items.batch.mixed")
        let window = fixture.window(content, locale: locale, scheme: scheme, size: NSSize(width: 480, height: 200))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let nodes = Menus.menus(in: window)
        #expect(nodes.count == 3)
        try Native.assertBounds(nodes + Native.buttons(in: window), in: window)
        for node in nodes { try Menus.assertTextWidth(node, in: window) }
        for key in ["items.status.enabled", "items.status.disabled", "alert.trash.move"] {
            let button = try Native.button(key, locale: locale, in: window)
            let rect = try Native.frame(button, in: window)
            let titleWidth = (Menus.localized(key, locale) as NSString)
                .size(withAttributes: [.font: NSFont.systemFont(ofSize: 11)]).width
            #expect(rect.width >= titleWidth)
            #expect(rect.height < 30, "普通按钮文字不能被压成逐字换行")
        }
        #expect(Menus.labels(in: window).contains(Menus.localized("items.batch.mixed", locale)))
        try Native.snapshot(window, name: "batch-narrow-note-\(locale)-\(scheme)")
        #expect(trace.events.isEmpty)
    }

    @Test func hiddenEmptyAndDisabledStatesKeepHostRules() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let trace = BatchMenuTrace()
        let hidden = bar(trace, tags: [], schedule: false, status: false, enable: true)
        let window = fixture.window(hidden, size: NSSize(width: 580, height: 160))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        #expect(Menus.menus(in: window).isEmpty)
        _ = try Native.button("items.status.enabled", in: window)
        _ = try Native.button("items.status.disabled", in: window)
        let disabled = fixture.window(bar(trace, tags: []).disabled(true), size: NSSize(width: 580, height: 160))
        defer { SystemPageHost.release(disabled) }
        try await NativeSyntaxUI.prepareFocus(in: disabled)
        try await SystemPageHost.settle(disabled)
        let nodes = Menus.menus(in: disabled)
        #expect(nodes.count == 2)
        var opened = false
        let observer = NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification, object: nil, queue: nil
        ) { _ in MainActor.assumeIsolated { opened = true } }
        defer { NotificationCenter.default.removeObserver(observer) }
        for node in nodes {
            #expect((node.value(forKey: "accessibilityEnabled") as? NSNumber)?.boolValue == false)
            try await Native.click(node, in: disabled)
        }
        #expect(!opened)
        #expect(trace.events.isEmpty)
    }

    private func bar(_ trace: BatchMenuTrace, tags: [TagItem], schedule: Bool = true,
                     status: Bool = true, enable: Bool = false, note: LocalizedStringKey? = nil) -> BatchActionBar {
        BatchActionBar(selectedCount: 12,
            schedule: BatchScheduleActions(onMoveToday: { trace.events.append("today") },
                onMoveTomorrow: { trace.events.append("tomorrow") },
                onToggleDone: { trace.events.append("done:\($0)") }),
            classify: BatchClassifyActions(onApplyTag: { trace.events.append("tag:\($0):\($1)") }, tags: tags),
            lifecycle: BatchLifecycleActions(onTrash: { trace.events.append("trash") }, onClear: { trace.events.append("clear") }),
            showsSchedule: schedule, showsStatus: status, showsEnable: enable,
            onSetEnabled: { trace.events.append("enabled:\($0)") }, noteKey: note)
    }
}

@MainActor private final class BatchMenuTrace {
    var events: [String] = []
}
