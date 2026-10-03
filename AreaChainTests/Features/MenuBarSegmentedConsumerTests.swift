import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

extension MenuBarPopoverRenderingTests {
    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func segmentedConsumerPreservesDraftsFiltersSearchAndCounts(locale: String, scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let context = support.container.mainContext
        let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
        let composer = BoardComposerSession(vault: vault)
        composer.tasks.text = "synthetic task #uncommitted"
        composer.diary.text = "synthetic note #uncommitted"
        let taskID = UUID(), diaryID = UUID()
        let filters = BoardFilterSession(filters: BoardFilters(
            tasks: BoardFilter(tagID: taskID), diary: BoardFilter(tagID: diaryID)))
        var filterWrites = 0
        filters.onChange = { _ in filterWrites += 1 }
        let toolbar = MenuBarToolbarState()
        context.insert(TodoItem(title: "Synthetic existing task", dayKey: DayClock.shared.todayKey))
        context.insert(DiaryEntry(text: "Synthetic existing note", dayKey: DayClock.shared.todayKey))
        // DiaryPage 首次挂载本就补齐预置标签；夹具先具备该基线，切换不得重复创建。
        for (index, name) in DiaryMemoTags.presets.enumerated() { context.insert(TagItem(name: name, sortOrder: index)) }
        try context.save()
        let initialTagIDs = Set(try context.fetch(FetchDescriptor<TagItem>()).map(\.id))
        let root = MenuBarPopoverView(toolbar: toolbar, composer: composer, filterSession: filters)
        let window = support.window(root, locale: locale, scheme: scheme, size: DaybookMetrics.Window.popoverSize)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try await switchSegment(.diary, locale: locale, in: window, mouse: true)
        #expect(composer.tasks.text == "synthetic task #uncommitted")
        try await switchSegment(.tasks, locale: locale, in: window, mouse: false)
        #expect(composer.diary.text == "synthetic note #uncommitted")
        try await SettingsButtonTestSupport.key(124, flags: [.command, .function, .numericPad], in: window)
        try assertSegment(.diary, locale: locale, in: window)
        try await SettingsButtonTestSupport.key(123, flags: [.command, .function, .numericPad], in: window)
        try assertSegment(.tasks, locale: locale, in: window)
        let active = (window.firstResponder as? NSTextView)?.delegate as? DaybookAppKitTextField
        #expect(active != nil)
        try await clickAndSettle(at: filterTriggerPoint(in: window), in: window)
        #expect(toolbar.isFiltering)
        try await switchSegment(.diary, locale: locale, in: window, mouse: false)
        #expect(!toolbar.isFiltering)
        let view = try #require(window.contentView)
        let field = try await focusSearch(toolbar, in: view)
        toolbar.searchText = "Synthetic"
        try await settle(view)
        let responder = window.firstResponder
        try await switchSegment(.tasks, locale: locale, in: window, mouse: true)
        #expect(toolbar.searchIsFocused && toolbar.searchText == "Synthetic")
        #expect(window.firstResponder === responder && field.currentEditor() != nil)
        try await SettingsButtonTestSupport.key(124, flags: .command, in: window)
        try assertSegment(.tasks, locale: locale, in: window)
        #expect(window.firstResponder === responder)
        let submit = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        _ = window.performKeyEquivalent(with: submit)
        try await settle(view)
        #expect(composer.tasks.text == "synthetic task #uncommitted")
        #expect(composer.diary.text == "synthetic note #uncommitted")
        #expect(filters.filters.tasks.tagID == taskID && filters.filters.diary.tagID == diaryID && filterWrites == 0)
        #expect(try context.fetchCount(FetchDescriptor<TodoItem>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<DiaryEntry>()) == 1)
        #expect(Set(try context.fetch(FetchDescriptor<TagItem>()).map(\.id)) == initialTagIDs)
        #expect(!context.hasChanges)
        try assertSegmentHeaderBounds(locale: locale, in: window)
        try SettingsButtonTestSupport.snapshot(window, name: "segment-menubar-search-\(locale)-\(scheme)")
        toolbar.clearSearch()
        try await settle(view)
        try assertSegmentHeaderBounds(locale: locale, in: window)
        try SettingsButtonTestSupport.snapshot(window, name: "segment-menubar-\(locale)-\(scheme)")
        window.contentView = NSView(frame: view.bounds)
        try await SystemPageHost.settle(window)
        toolbar.searchIsFocused = false
        let search = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            characters: "f", charactersIgnoringModifiers: "f", isARepeat: false, keyCode: 3))
        NSApp.sendEvent(search)
        try await SystemPageHost.settle(window)
        #expect(!toolbar.searchIsFocused, "已拆卸宿主的键盘监视器不得继续响应")
    }

    private func segmentNode(_ tab: BoardTab, locale: String, in window: NSWindow) throws -> NSObject {
        let native = SettingsButtonTestSupport.self
        let help = L10n.string(String.LocalizationValue(tab.helpKey), locale: Locale(identifier: locale))
        let matches = native.buttons(in: window).filter {
            native.value($0, "accessibilityHelp") as? String == help
        }
        // 捕获提交按钮与页签可能同名；必须靠页签专属帮助唯一定位，禁止猜测点击。
        try #require(matches.count == 1)
        return try #require(matches.first)
    }

    private func switchSegment(_ tab: BoardTab, locale: String, in window: NSWindow, mouse: Bool) async throws {
        let node = try segmentNode(tab, locale: locale, in: window)
        if mouse { try await SettingsButtonTestSupport.click(node, in: window) }
        else {
            try DaybookSegmentedControlTests().press(node)
            try await SystemPageHost.settle(window)
        }
        try assertSegment(tab, locale: locale, in: window)
    }

    private func assertSegment(_ tab: BoardTab, locale: String, in window: NSWindow) throws {
        for option in BoardTab.allCases {
            let node = try segmentNode(option, locale: locale, in: window)
            #expect((node.value(forKey: "accessibilitySelected") as? NSNumber)?.boolValue == (tab == option))
        }
    }

    private func assertSegmentHeaderBounds(locale: String, in window: NSWindow) throws {
        let native = SettingsButtonTestSupport.self
        let tabs = try BoardTab.allCases.map { try segmentNode($0, locale: locale, in: window) }
        try native.assertBounds(tabs, in: window)
        let left = try native.frame(tabs[0], in: window)
        let headerText = native.elements(window.contentView).filter {
            native.value($0, "accessibilityRole") as? String == "AXStaticText"
        }
        for node in headerText {
            let frame = try native.frame(node, in: window)
            if frame.maxY > left.minY && frame.minX < left.minX {
                #expect(frame.maxX <= left.minX, "日期/状态文字不得与分段重叠")
            }
        }
    }
}
