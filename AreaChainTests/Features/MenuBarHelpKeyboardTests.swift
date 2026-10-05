import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

extension MenuBarHelpSurfaceTests {
    @Test(arguments: [false, true], ["en", "zh-Hans"])
    func helpEscapePreservesEditorAndPresentation(search: Bool, locale: String) async throws {
        for scheme in [ColorScheme.light, .dark] {
            for width: CGFloat in [356, 380] {
                try await exerciseHelpEscape(search: search, locale: locale, scheme: scheme, width: width)
            }
        }
    }

    private func exerciseHelpEscape(search: Bool, locale: String, scheme: ColorScheme, width: CGFloat) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let composer = BoardComposerSession()
        composer.tasks.text = "Synthetic original #tag"
        composer.diary.text = "Synthetic diary"
        let toolbar = MenuBarToolbarState()
        if search { toolbar.searchText = "query"; toolbar.focusSearch() }
        let window = helpWindow(support, composer: composer, toolbar: toolbar, configuration: (locale, scheme, width))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await openHelp(in: window, locale: locale)
        #expect(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == (scheme == .dark ? .darkAqua : .aqua))
        let root = try #require(window.contentView)
        let field = try #require(search
            ? MenuBarPopoverRenderingTests().searchField(in: root) as? DaybookAppKitTextField
            : captureField(window))
        let editor = try #require(field.currentEditor() as? NSTextView)
        let state = try #require((field.delegate as? DaybookTextField.Coordinator)?.parent.autocomplete)
        let preview = state.showsPreview
        let active = state.isActive
        let text = editor.string
        let selection = editor.selectedRange()
        describeInput(window)
        try await helpKey(53, in: window)
        #expect(!anyHelpVisible(window))
        #expect(window.firstResponder === editor && field.currentEditor() === editor)
        #expect(editor.string == text && editor.selectedRange() == selection)
        #expect(state.showsPreview == preview && state.isActive == active)
        #expect(composer.tasks.text == "Synthetic original #tag" && composer.diary.text == "Synthetic diary")
        #expect(toolbar.searchText == (search ? "query" : ""))
        #expect(window.isVisible && window.isKeyWindow)
        describeInput(window)
        try await helpKey(53, in: window)
        if preview { #expect(!state.showsPreview) }
        else if search { #expect(toolbar.searchText.isEmpty) }
        #expect(!anyHelpVisible(window) && !support.container.mainContext.hasChanges)
    }

    @Test(arguments: [false, true])
    func helpEscapeDefersMarkedText(search: Bool) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let composer = BoardComposerSession()
        let toolbar = MenuBarToolbarState()
        if search { toolbar.searchText = "query"; toolbar.focusSearch() }
        let window = helpWindow(support, composer: composer, toolbar: toolbar)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await openHelp(in: window)
        let editor = try #require(window.firstResponder as? NSTextView)
        editor.setMarkedText("拼音", selectedRange: NSRange(location: 2, length: 0), replacementRange: editor.selectedRange())
        try #require(editor.hasMarkedText())
        let text = editor.string
        try await helpKey(53, in: window)
        #expect(anyHelpVisible(window))
        #expect(window.firstResponder === editor)
        #expect(editor.string == text)
        editor.unmarkText()
        try await helpKey(53, in: window)
        #expect(!anyHelpVisible(window))
        #expect(window.firstResponder === editor && !support.container.mainContext.hasChanges)
    }

    @Test func helpEscapeHonorsFilterAndNativeResponder() async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let composer = BoardComposerSession()
        composer.tasks.text = "Synthetic draft"
        let toolbar = MenuBarToolbarState()
        let window = helpWindow(support, composer: composer, toolbar: toolbar)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await openHelp(in: window)
        // charactersIgnoringModifiers 仍保留 Shift；原生 ⌘⇧F 的此字段为 F，不能沿用小写 f。
        let filterKey = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: [.command, .shift], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, characters: "f",
            charactersIgnoringModifiers: "F", isARepeat: false, keyCode: 3))
        NSApp.postEvent(filterKey, atStart: false)
        try await settledHelp(window)
        try #require(toolbar.isFiltering)
        try await helpKey(53, in: window)
        #expect(!toolbar.isFiltering && anyHelpVisible(window))
        try await helpKey(53, in: window)
        #expect(!anyHelpVisible(window))
        try await openHelp(in: window)
        // 单独的原生响应者场景；不用于替代上面实际输入焦点断言。
        try #require(window.makeFirstResponder(window))
        try await helpKey(53, in: window)
        #expect(!anyHelpVisible(window) && window.firstResponder === window)
        #expect(composer.tasks.text == "Synthetic draft" && !support.container.mainContext.hasChanges)
    }

    @Test func helpEscapeIsWindowScopedAndSurvivesReopening() async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let first = helpWindow(support, composer: BoardComposerSession(), toolbar: MenuBarToolbarState())
        defer { SystemPageHost.release(first) }
        try await NativeSyntaxUI.prepareFocus(in: first)
        try await openHelp(in: first)
        let second = helpWindow(support, composer: BoardComposerSession(), toolbar: MenuBarToolbarState())
        defer { SystemPageHost.release(second) }
        try await NativeSyntaxUI.prepareFocus(in: second)
        try await openHelp(in: second)
        try await helpKey(53, in: second)
        #expect(anyHelpVisible(first) && !anyHelpVisible(second))
        for _ in 0..<2 {
            try await openHelp(in: second)
            try await helpKey(53, in: second)
            #expect(!anyHelpVisible(second) && anyHelpVisible(first))
        }
        try await openHelp(in: second)
        second.orderOut(nil)
        first.makeKeyAndOrderFront(nil)
        try await helpKey(53, in: second)
        #expect(anyHelpVisible(second), "隐藏宿主不消费迟到按键")
        second.makeKeyAndOrderFront(nil)
        try await SystemPageHost.settle(second)
        try await helpKey(53, in: second)
        #expect(!anyHelpVisible(second) && anyHelpVisible(first))
        SystemPageHost.release(second)
        first.makeKeyAndOrderFront(nil)
        try await SystemPageHost.settle(first)
        try await helpKey(53, in: first)
        #expect(!anyHelpVisible(first) && !support.container.mainContext.hasChanges)
    }

    @Test func helpMonitorStopsAfterUnmountAndDoesNotConsumeModifiedEscape() async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let window = helpWindow(support, composer: BoardComposerSession(), toolbar: MenuBarToolbarState())
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await openHelp(in: window)
        let responder = HelpKeyResponder()
        window.contentView?.addSubview(responder)
        try #require(window.makeFirstResponder(responder))
        for flags: NSEvent.ModifierFlags in [.command, .shift, .option, .control] {
            try await helpKey(53, modifiers: flags, in: window)
            #expect(anyHelpVisible(window))
        }
        #expect(responder.keys == 4)
        try await helpKey(53, in: window)
        #expect(!anyHelpVisible(window) && responder.keys == 4)
        try await openHelp(in: window)
        window.contentViewController = nil
        window.contentView = responder
        try await SystemPageHost.settle(window)
        try #require(window.makeFirstResponder(responder))
        try await helpKey(53, in: window)
        #expect(responder.keys == 5, "卸载后的 Escape 应交给当前原生响应者")
        #expect(!support.container.mainContext.hasChanges)
    }

    @Test func helpEscapePreservesNativeCandidatesAndSyntheticModels() async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let tag = TagItem(name: "Synthetic", sortOrder: 0)
        support.container.mainContext.insert(tag)
        try support.container.mainContext.save()
        let tagID = tag.id
        let composer = BoardComposerSession()
        let toolbar = MenuBarToolbarState()
        let window = helpWindow(support, composer: composer, toolbar: toolbar)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await openHelp(in: window)
        let editor = try #require(window.firstResponder as? NSTextView)
        editor.insertText("#", replacementRange: editor.selectedRange())
        try await SystemPageHost.settle(window)
        let state = try #require((captureField(window)?.delegate as? DaybookTextField.Coordinator)?.parent.autocomplete)
        try #require(state.isActive && !state.candidates.isEmpty)
        let count = state.candidates.count
        let mutations = MenuBarHelpMutationProbe(context: support.container.mainContext) { _ = composer.tasks }
        try await helpKey(53, in: window)
        #expect(!helpVisible(window) && state.isActive && state.candidates.count == count)
        #expect(window.firstResponder === editor && composer.tasks.text == "#")
        try await helpKey(53, in: window)
        #expect(!state.isActive && composer.tasks.text == "#")
        #expect(tag.id == tagID && tag.name == "Synthetic")
        #expect(try support.container.mainContext.fetchCount(FetchDescriptor<TagItem>()) == 1)
        #expect(try support.container.mainContext.fetchCount(FetchDescriptor<TodoItem>()) == 0)
        #expect(try support.container.mainContext.fetchCount(FetchDescriptor<DiaryEntry>()) == 0)
        #expect(mutations.writes == 0 && mutations.saves == 0 && !support.container.mainContext.hasChanges)
    }

    @Test func absentHostDoesNotConsumeEscapeOrSearch() throws {
        let toolbar = MenuBarToolbarState()
        let host = MenuBarPopoverView(toolbar: toolbar, composer: BoardComposerSession(), filterSession: BoardFilterSession())
        for (code, chars, flags): (UInt16, String, NSEvent.ModifierFlags) in [(53, "\u{1B}", []), (3, "f", .command)] {
            let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0, context: nil,
                characters: chars, charactersIgnoringModifiers: chars, isARepeat: false, keyCode: code))
            #expect(host.handleTabKeyDown(event) === event && !toolbar.searchIsFocused)
        }
    }

    func anyHelpVisible(_ window: NSWindow) -> Bool {
        let strings = SurfaceConsumerUI.strings(window)
        return ["en", "zh-Hans"].contains { locale in
            ["syntax.guide.title", "syntax.search.title"].contains {
                strings.contains(L10n.string(String.LocalizationValue($0), locale: Locale(identifier: locale)))
            }
        }
    }

    func helpKey(_ code: UInt16, chars: String = "\u{1B}", modifiers: NSEvent.ModifierFlags = [],
                 in window: NSWindow) async throws {
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            characters: chars, charactersIgnoringModifiers: chars, isARepeat: false, keyCode: code))
        NSApp.postEvent(event, atStart: false)
        try await settledHelp(window)
    }
}

@MainActor
private final class HelpKeyResponder: NSView {
    var keys = 0
    override var acceptsFirstResponder: Bool { true }
    override func keyDown(with event: NSEvent) { keys += 1 }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.keyCode == 53,
              !event.modifierFlags.isDisjoint(with: [.command, .shift, .option, .control]) else { return false }
        keys += 1
        return true
    }
}
