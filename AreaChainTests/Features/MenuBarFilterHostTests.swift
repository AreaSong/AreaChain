import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

extension MenuBarPopoverRenderingTests {
    @Test(arguments: ["send", "queue"])
    func filterMouseStaysAboveHelpAndEscapeClosesOneLayer(delivery: String) async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let toolbar = MenuBarToolbarState()
        let filters = BoardFilterSession()
        var writes = 0
        filters.onChange = { _ in writes += 1 }
        let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
        let composer = BoardComposerSession(vault: vault)
        composer.tasks.text = "Synthetic draft"
        let window = MenuBarFilterTestSupport.host(support, composer: composer, filters: filters, toolbar: toolbar)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        let help = MenuBarHelpSurfaceTests()
        try await help.openHelp(in: window)
        try await MenuBarFilterTestSupport.toggleFilterKey(in: window)
        try #require(toolbar.isFiltering && help.anyHelpVisible(window))
        let title = DateFilterScope.overdue.title(locale: Locale(identifier: "en"))
        let rect = try SettingsButtonTestSupport.frame(MenuBarFilterTestSupport.button(title, in: window, minX: 125), in: window)
        try await SurfaceEventTestSupport.click(NSPoint(x: rect.midX, y: rect.midY), in: window, delivery: delivery)
        #expect(filters.filters.tasks == BoardFilter(dateScope: .overdue) && writes == 1)
        #expect(!toolbar.isFiltering && help.anyHelpVisible(window))
        try await MenuBarFilterTestSupport.toggleFilterKey(in: window)
        #expect(toolbar.isFiltering)
        try await help.helpKey(53, in: window)
        #expect(!toolbar.isFiltering && help.anyHelpVisible(window))
        try await help.helpKey(53, in: window)
        #expect(!help.anyHelpVisible(window) && writes == 1)
        #expect(composer.tasks.text == "Synthetic draft" && !support.container.mainContext.hasChanges)
    }

    @Test(arguments: ["en", "zh-Hans"])
    func filterEntryWritesPreciseSelectionAndPreservesIndependentSessions(locale: String) async throws {
        let support = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { support.cleanup() }
        let tags = try MenuBarFilterTestSupport.seed(support)
        let context = support.container.mainContext
        let tagIDs = Set(try context.fetch(FetchDescriptor<TagItem>()).map(\.id))
        let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
        let composer = BoardComposerSession(vault: vault)
        composer.tasks.text = "Synthetic task draft"
        composer.diary.text = "Synthetic diary draft"
        let toolbar = MenuBarToolbarState()
        let filters = BoardFilterSession(filters: BoardFilters(diary: BoardFilter(tagID: tags[1].id)))
        var changes: [BoardFilters] = []
        filters.onChange = { changes.append($0) }
        let window = MenuBarFilterTestSupport.host(support, composer: composer, filters: filters, toolbar: toolbar, locale: locale)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let mutations = MenuBarHelpMutationProbe(context: context) { _ = composer.tasks; _ = composer.diary }
        let title = DateFilterScope.overdue.title(locale: Locale(identifier: locale))
        for index in 0..<2 {
            try await SurfaceEventTestSupport.click(filterTriggerPoint(in: window), in: window)
            #expect(toolbar.isFiltering)
            try await MenuBarFilterTestSupport.click(title, in: window, minX: 125)
            #expect(filters.filters.tasks == BoardFilter(dateScope: index == 0 ? .overdue : .all))
            #expect(filters.filters.diary == BoardFilter(tagID: tags[1].id))
            #expect(changes.count == index + 1 && !toolbar.isFiltering)
        }
        try await SurfaceEventTestSupport.click(filterTriggerPoint(in: window), in: window)
        try await MenuBarFilterTestSupport.click(FilterCategory.priority.title(locale: Locale(identifier: locale)), in: window, categoryOnly: true)
        #expect(changes.count == 2 && toolbar.isFiltering)
        try await MenuBarFilterTestSupport.click(PriorityFilterScope.p1.title(locale: Locale(identifier: locale)), in: window, minX: 125)
        #expect(filters.filters.tasks == BoardFilter(priorityScope: .p1) && changes.count == 3)
        #expect(mutations.writes == 0, "任务筛选不写草稿")
        try await MenuBarFilterTestSupport.selectTab(.diary, locale: locale, in: window)
        let diaryWrites = mutations.writes
        try await SurfaceEventTestSupport.click(filterTriggerPoint(in: window), in: window)
        try await MenuBarFilterTestSupport.click("#" + tags[0].name, in: window)
        #expect(filters.filters.diary == BoardFilter(tagID: tags[0].id) && changes.count == 4)
        #expect(filters.filters.tasks == BoardFilter(priorityScope: .p1) && !toolbar.isFiltering)
        try await SurfaceEventTestSupport.click(filterTriggerPoint(in: window), in: window)
        let clear = L10n.string("filter.clear", locale: Locale(identifier: locale))
        let clearNode = try MenuBarFilterTestSupport.button(clear, in: window)
        // 清除位于原滚动容器末尾；程序化揭示只证明滚动后的命中，不冒充滚轮事件。
        try await SettingsButtonTestSupport.reveal(clearNode, in: window)
        try await MenuBarFilterTestSupport.click(clear, in: window)
        #expect(filters.filters.diary == BoardFilter() && changes.count == 5 && !toolbar.isFiltering)
        #expect(mutations.writes == diaryWrites, "手记筛选不写草稿")
        try await MenuBarFilterTestSupport.selectTab(.tasks, locale: locale, in: window)
        let taskWrites = mutations.writes
        try await SurfaceEventTestSupport.click(filterTriggerPoint(in: window), in: window)
        try await MenuBarFilterTestSupport.click(clear, in: window)
        #expect(filters.filters == BoardFilters() && changes.count == 6 && !toolbar.isFiltering)
        #expect(mutations.writes == taskWrites, "任务清除不写草稿")
        toolbar.searchText = "Synthetic"
        toolbar.focusSearch()
        try await SystemPageHost.settle(window)
        try await SurfaceEventTestSupport.click(filterTriggerPoint(in: window), in: window)
        try await SettingsButtonTestSupport.key(53, in: window)
        #expect(!toolbar.isFiltering && toolbar.searchText == "Synthetic" && changes.count == 6)
        #expect(composer.tasks.text == "Synthetic task draft" && composer.diary.text == "Synthetic diary draft")
        SurfaceEventTestSupport.note("filter host draftWrites=\(mutations.writes) saves=\(mutations.saves) dirty=\(context.hasChanges)")
        #expect(mutations.saves == 0 && !context.hasChanges)
        #expect(try context.fetchCount(FetchDescriptor<TodoItem>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<DiaryEntry>()) == 1)
        #expect(Set(try context.fetch(FetchDescriptor<TagItem>()).map(\.id)) == tagIDs)
    }
}
