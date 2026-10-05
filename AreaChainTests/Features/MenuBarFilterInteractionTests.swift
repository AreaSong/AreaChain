import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct MenuBarFilterInteractionTests {
    @Test func manyTagsScrollToTheLastProductionOption() async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let probe = MenuBarFilterProbe()
        probe.category = .tag
        let tags = MenuBarFilterTestSupport.tags(24)
        let window = support.window(MenuBarFilterSample(probe: probe, tags: tags), size: NSSize(width: 380, height: 260))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let last = try #require(tags.last)
        let node = try MenuBarFilterTestSupport.button("#" + last.name, in: window)
        let scroll = try #require(OverlaySurfaceTestSupport.descendants(window.contentView).compactMap { $0 as? NSScrollView }.first)
        #expect(scroll.documentView!.bounds.height > scroll.contentView.bounds.height)
        let initial = scroll.contentView.bounds.origin
        try await SettingsButtonTestSupport.reveal(node, in: window)
        #expect(scroll.contentView.bounds.origin != initial)
        try await MenuBarFilterTestSupport.click("#" + last.name, in: window)
        #expect(probe.filters == BoardFilters(tasks: BoardFilter(tagID: last.id)))
        #expect(probe.writes.count == 1 && probe.dismissals == 1)
    }

    @Test(arguments: ["en", "zh-Hans"], [BoardTab.tasks, .diary])
    func choicesWriteExactlyOnceAndClearOnlyCurrentTab(locale: String, tab: BoardTab) async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let probe = MenuBarFilterProbe()
        let tags = MenuBarFilterTestSupport.tags(2)
        probe.filters = BoardFilters(tasks: BoardFilter(dateScope: .today), diary: BoardFilter(tagID: UUID()))
        let other = probe.filters.selection(for: tab == .tasks ? .diary : .tasks)
        let window = support.window(MenuBarFilterSample(probe: probe, tab: tab, tags: tags), locale: locale,
                                    size: NSSize(width: 380, height: 260))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        for category in (tab == .tasks ? FilterCategory.allCases : [.tag]) {
            probe.category = category
            try await SystemPageHost.settle(window)
            let filter = probe.filters.selection(for: tab)
            let choice: BoardFilterChoice
            switch category {
            case .date: choice = BoardFilterChoices.dates(filter: filter, locale: Locale(identifier: locale))[3]
            case .priority: choice = BoardFilterChoices.priorities(filter: filter, locale: Locale(identifier: locale))[2]
            case .tag:
                choice = BoardFilterChoices.tags(filter: filter,
                    rows: tags.map { .init(id: $0.id, name: $0.name) }, counts: [:], untaggedCount: nil,
                    includeNone: false, locale: Locale(identifier: locale))[1]
            }
            let title = category == .tag ? BoardFilterChoices.markedTagTitle(choice) : choice.title
            let before = probe.writes.count
            try await MenuBarFilterTestSupport.click(title, in: window)
            #expect(probe.filters.selection(for: tab) == choice.applied)
            #expect(probe.writes.count == before + 1 && probe.dismissals == before + 1)
            try await MenuBarFilterTestSupport.click(title, in: window)
            #expect(probe.filters.selection(for: tab) == choice.cleared)
            #expect(probe.writes.count == before + 2 && probe.dismissals == before + 2)
            #expect(probe.filters.selection(for: tab == .tasks ? .diary : .tasks) == other)
        }
        probe.filters.write(BoardFilter(tagID: tags[0].id, priorityScope: .p1, dateScope: .overdue), for: tab)
        try await SystemPageHost.settle(window)
        let before = probe.writes.count
        try await MenuBarFilterTestSupport.click(L10n.string("filter.clear", locale: Locale(identifier: locale)), in: window)
        #expect(probe.filters.selection(for: tab) == BoardFilter())
        #expect(probe.filters.selection(for: tab == .tasks ? .diary : .tasks) == other)
        #expect(probe.writes.count == before + 1 && probe.dismissals == before + 1)
    }

    @Test(arguments: [false, true])
    func categoryClickUsesInternalOrExternalOwner(external: Bool) async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let probe = MenuBarFilterProbe()
        let window = support.window(MenuBarFilterSample(probe: probe, external: external), size: NSSize(width: 380, height: 260))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await MenuBarFilterTestSupport.click(FilterCategory.priority.title(locale: Locale(identifier: "en")), in: window)
        let title = PriorityFilterScope.p1.title(locale: Locale(identifier: "en"))
        _ = try MenuBarFilterTestSupport.button(title, in: window)
        #expect(probe.category == (external ? .priority : .date))
        #expect(probe.writes.isEmpty && probe.dismissals == 0)
    }

    @Test func nativeHoverCascadesCancelsAndUnmountsWithoutLateDismissal() async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let probe = MenuBarFilterProbe()
        let window = support.window(MenuBarFilterSample(probe: probe, tags: MenuBarFilterTestSupport.tags(24)),
                                    size: NSSize(width: 380, height: 260))
        defer { SystemPageHost.release(window) }
        let originalPointer = NSEvent.mouseLocation
        defer { RowBubbleTestSupport.warp(originalPointer) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        var moves = 0
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { event in
            MainActor.assumeIsolated { if event.window === window { moves += 1 } }
            return event
        }
        defer { if let monitor { NSEvent.removeMonitor(monitor) } }
        let rect = try SettingsButtonTestSupport.frame(MenuBarFilterTestSupport.button("Priority", in: window), in: window)
        let category = NSPoint(x: rect.midX, y: rect.midY)
        try await RowBubbleTestSupport.move(category, in: window)
        #expect(probe.category == .priority && moves > 0)
        let frame = try NativeSyntaxUI.frame("syntax.filter.sample", in: window)
        for x in [frame.minX + 111, frame.minX + 115, frame.minX + 120, frame.minX + 190] {
            try await RowBubbleTestSupport.move(NSPoint(x: x, y: category.y), in: window)
        }
        try await Task.sleep(for: .milliseconds(260))
        #expect(probe.dismissals == 0 && probe.writes.isEmpty)
        let outside = NSPoint(x: 370, y: 245)
        try await RowBubbleTestSupport.move(outside, in: window)
        #expect(probe.dismissals == 0)
        try await RowBubbleTestSupport.move(category, in: window)
        try await Task.sleep(for: .milliseconds(260))
        #expect(probe.dismissals == 0)
        try await RowBubbleTestSupport.move(outside, in: window)
        #expect(probe.dismissals == 0)
        try await Task.sleep(for: .milliseconds(200))
        #expect(probe.dismissals == 1)
        try await RowBubbleTestSupport.move(category, in: window)
        try await RowBubbleTestSupport.move(outside, in: window)
        probe.mounted = false
        try await SystemPageHost.settle(window)
        try await Task.sleep(for: .milliseconds(260))
        #expect(probe.dismissals == 1 && probe.writes.isEmpty)
        SurfaceEventTestSupport.note("filter native mouseMoved=\(moves), category=\(probe.category), dismissals=\(probe.dismissals)")
    }
}
