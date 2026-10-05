import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct MenuBarFilterConsumerTests {
    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func productionCardsPreserveGeometryAndCategories(locale: String, scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        for tab in [BoardTab.tasks, .diary] {
            for count in [0, 1, 24] {
                let probe = MenuBarFilterProbe()
                let window = support.window(MenuBarFilterSample(probe: probe, tab: tab, tags: MenuBarFilterTestSupport.tags(count)),
                    locale: locale, scheme: scheme, size: NSSize(width: 380, height: 260))
                defer { SystemPageHost.release(window) }
                try await SystemPageHost.settle(window)
                for category in FilterCategory.allCases {
                    probe.category = category
                    try await SystemPageHost.settle(window)
                    let frame = try NativeSyntaxUI.frame("syntax.filter.sample", in: window)
                    #expect(frame.width == (tab == .tasks ? 295 : 181))
                    #expect(frame.height == 171)
                    let scroll = try #require(OverlaySurfaceTestSupport.descendants(window.contentView).compactMap { $0 as? NSScrollView }.first)
                    #expect(scroll.bounds.width == 175 && scroll.bounds.height == 165)
                    #expect(!scroll.hasHorizontalScroller && !scroll.hasVerticalScroller)
                    let strings = SurfaceConsumerUI.strings(window)
                    if tab == .tasks {
                        for item in FilterCategory.allCases {
                            #expect(strings.contains(item.title(locale: Locale(identifier: locale))))
                        }
                    } else {
                        #expect(!strings.contains(FilterCategory.date.title(locale: Locale(identifier: locale))))
                    }
                    #expect(probe.writes.isEmpty && probe.dismissals == 0)
                    try MenuBarFilterTestSupport.record(window, name: "direct-\(tab)-\(count)-\(category)-\(locale)-\(scheme)")
                }
            }
        }
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func productionEntryScrimAndFooterPreserveDrafts(locale: String, scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        _ = try MenuBarFilterTestSupport.seed(support)
        let context = support.container.mainContext
        let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
        let composer = BoardComposerSession(vault: vault)
        composer.tasks.text = "Synthetic task draft"
        composer.diary.text = "Synthetic diary draft"
        let toolbar = MenuBarToolbarState()
        let filters = BoardFilterSession()
        var writes = 0
        filters.onChange = { _ in writes += 1 }
        let window = MenuBarFilterTestSupport.host(support, composer: composer, filters: filters, toolbar: toolbar,
                                                  locale: locale, scheme: scheme)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let helper = MenuBarPopoverRenderingTests()
        let mutations = MenuBarHelpMutationProbe(context: context) { _ = composer.tasks; _ = composer.diary }
        for tab in [BoardTab.tasks, .diary] {
            if tab == .diary { try await MenuBarFilterTestSupport.selectTab(tab, locale: locale, in: window) }
            let trigger = try helper.filterTriggerPoint(in: window)
            try await SurfaceEventTestSupport.click(trigger, in: window)
            #expect(toolbar.isFiltering)
            try await MenuBarHelpSurfaceTests().settledHelp(window)
            let scroll = try #require(OverlaySurfaceTestSupport.descendants(window.contentView).compactMap { $0 as? NSScrollView }
                .first { $0.bounds.width == 175 && $0.bounds.height == 165 })
            let card = scroll.convert(scroll.bounds, to: nil)
            #expect(card.minX == (tab == .tasks ? 129 : 15) && card.minY == 47)
            try MenuBarFilterTestSupport.record(window, name: "host-\(tab)-\(locale)-\(scheme)")
            let scrim = try #require(OverlaySurfaceTestSupport.descendants(window.contentView).first {
                String(describing: type(of: $0)).contains("FilterDrawerScrimView")
            })
            #expect(scrim.hitTest(scrim.superview!.convert(NSPoint(x: 330, y: 43), from: nil)) == nil)
            #expect(scrim.hitTest(scrim.superview!.convert(NSPoint(x: 330, y: 44), from: nil)) === scrim)
            try await SurfaceEventTestSupport.click(trigger, in: window)
            #expect(!toolbar.isFiltering)
            try await SurfaceEventTestSupport.click(trigger, in: window)
            #expect(toolbar.isFiltering)
            try await SurfaceEventTestSupport.click(NSPoint(x: 330, y: 270), in: window)
            #expect(!toolbar.isFiltering)
        }
        #expect(composer.tasks.text == "Synthetic task draft" && composer.diary.text == "Synthetic diary draft")
        #expect(toolbar.searchText.isEmpty && writes == 0 && mutations.writes == 0 && mutations.saves == 0)
        #expect(try context.fetchCount(FetchDescriptor<TodoItem>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<DiaryEntry>()) == 1)
        #expect(!context.hasChanges)
    }
}
