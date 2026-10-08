import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 直接装配生产菜单栏和原保存入口，仅使用 XCTest 内存库及非私密合成正文。
@Suite(.serialized) @MainActor
struct MenuBarCaptureSubmissionTests {
    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func markedCaptureThenSingleDiary(locale: String, scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let composer = BoardComposerSession(vault: PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys()))
        let toolbar = MenuBarToolbarState()
        let window = support.window(MenuBarPopoverView(toolbar: toolbar, composer: composer,
            filterSession: BoardFilterSession()), locale: locale, scheme: scheme,
            size: NSSize(width: locale == "en" ? 356 : 380, height: 490))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let field = try #require(MenuBarHelpSurfaceTests().captureField(window))
        let editor = try await FormInputTestSupport.editor(field, in: window)
        let context = support.container.mainContext
        let initialTodos = try context.fetchCount(FetchDescriptor<TodoItem>())
        let initialDiaries = try context.fetchCount(FetchDescriptor<DiaryEntry>())
        editor.setMarkedText("合成", selectedRange: NSRange(location: 1, length: 0),
                             replacementRange: NSRange(location: 0, length: 0))
        composer.tasks.text = "Synthetic external draft"
        try await SystemPageHost.settle(window)
        let selection = editor.selectedRange()
        let marked = editor.markedRange()
        try await SearchMultilineBoundaryTests.key(command: true, in: window)
        #expect(try context.fetchCount(FetchDescriptor<TodoItem>()) == initialTodos)
        #expect(try context.fetchCount(FetchDescriptor<DiaryEntry>()) == initialDiaries)
        #expect(composer.tasks.text == "Synthetic external draft")
        #expect(editor.hasMarkedText() && editor.markedRange() == marked && editor.selectedRange() == selection)
        #expect(editor.string == "合成" && field.currentEditor() === editor)
        editor.insertText("Synthetic completed capture", replacementRange: marked)
        try await SystemPageHost.settle(window)
        #expect(!editor.hasMarkedText() && composer.tasks.text == "Synthetic completed capture")
        try await SearchMultilineBoundaryTests.key(command: true, in: window)
        #expect(try context.fetchCount(FetchDescriptor<TodoItem>()) == initialTodos)
        let entries = try context.fetch(FetchDescriptor<DiaryEntry>())
        #expect(entries.count == initialDiaries + 1)
        #expect(entries.filter { $0.text == "Synthetic completed capture" }.count == 1)
        #expect(composer.tasks.text.isEmpty)
    }

    @Test(arguments: [false, true])
    func searchOrFilterKeepsCaptureShortcutDisabled(search: Bool) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let composer = BoardComposerSession(vault: PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys()))
        composer.tasks.text = "Synthetic pending capture"
        let toolbar = MenuBarToolbarState()
        let window = support.window(MenuBarPopoverView(toolbar: toolbar, composer: composer,
            filterSession: BoardFilterSession()), size: NSSize(width: 380, height: 490))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        if search { toolbar.searchText = "Synthetic search"; toolbar.focusSearch() }
        else { toolbar.showFilters() }
        try await SystemPageHost.settle(window)
        #expect(toolbar.isSearching || toolbar.isFiltering)
        let context = support.container.mainContext
        let todos = try context.fetchCount(FetchDescriptor<TodoItem>())
        let diaries = try context.fetchCount(FetchDescriptor<DiaryEntry>())
        try await SearchMultilineBoundaryTests.key(command: true, in: window)
        #expect(try context.fetchCount(FetchDescriptor<TodoItem>()) == todos)
        #expect(try context.fetchCount(FetchDescriptor<DiaryEntry>()) == diaries)
        #expect(composer.tasks.text == "Synthetic pending capture")
    }
}
