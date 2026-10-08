import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct CaptureShortcutBoundaryTests {
    @Test func captureQueuedUndoRedoPreservesOriginalInput() async throws {
        try await SearchMultilineUndoTests().queuedUndoRedo(kind: .capture)
    }

    @Test func nativeEquivalentAndButtonEachSubmitOnce() async throws {
        let fixture = try SearchMultilineFixture(.capture)
        defer { fixture.cleanup() }
        fixture.draft.text = "Native route"
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        let event = try key(in: fixture.window)
        editor.setMarkedText("拼音", selectedRange: NSRange(location: 1, length: 0),
                             replacementRange: NSRange(location: 0, length: 0))
        // 补充原生字段优先收到事件的分支；按钮优先分支仍由 Mode 用例真实入队覆盖。
        #expect(field.performKeyEquivalent(with: event))
        #expect(fixture.draft.diaryCommits == 0 && editor.hasMarkedText())
        editor.insertText("中文", replacementRange: editor.markedRange())
        try await SystemPageHost.settle(fixture.window)
        #expect(field.performKeyEquivalent(with: event))
        #expect(fixture.draft.diaryCommits == 1 && fixture.draft.commits == 0)
        try await SearchMultilineBoundaryTests.key(command: true, in: fixture.window)
        #expect(fixture.draft.diaryCommits == 2 && fixture.draft.commits == 0)
    }

    @Test func isolatedRebindingAndDisarmingPreserveNativeContract() async throws {
        let fixture = try SearchMultilineFixture(.capture)
        defer { fixture.cleanup() }
        fixture.draft.text = "Rebound capture"
        let field = try #require(try await fixture.prepare() as? DaybookAppKitTextField)
        let editor = try #require(field.currentEditor() as? NSTextView)
        let defaults = fixture.base.native.defaults
        let center = HotKeyCenter(defaults: defaults, registration: HotKeyRegistration(
            register: { _, _ in true }, unregister: { _ in }))
        let store = ShortcutStore(defaults: defaults, center: center)
        store.start()
        let chord = ShortcutChord(keyCode: ShortcutKey.returnKey, modifiers: ShortcutModifier.command | ShortcutModifier.shift)
        store.assign(chord, to: .commitDiary)
        #expect(store.binding(for: .commitDiary).chord.displayName(locale: Locale(identifier: "en")) == "⌘⇧Return")
        #expect(store.binding(for: .commitDiary).chord.displayName(locale: Locale(identifier: "zh-Hans")) == "⌘⇧回车")
        #expect(store.keyboardShortcut(for: .commitDiary)?.modifiers == [.command, .shift])
        field.commandChord = store.armedChord(for: .commitDiary)
        #expect(!field.performKeyEquivalent(with: try key(in: fixture.window)))
        let rebound = try key(in: fixture.window, shift: true)
        editor.setMarkedText("拼音", selectedRange: NSRange(location: 1, length: 0),
                             replacementRange: NSRange(location: 0, length: 0))
        #expect(field.performKeyEquivalent(with: rebound))
        #expect(editor.hasMarkedText() && fixture.draft.diaryCommits == 0)
        editor.insertText("中文", replacementRange: editor.markedRange())
        try await SystemPageHost.settle(fixture.window)
        field.commandChord = store.armedChord(for: .commitDiary)
        #expect(field.performKeyEquivalent(with: rebound))
        #expect(fixture.draft.diaryCommits == 1)
        store.assign(chord, to: .search)
        #expect(!store.binding(for: .commitDiary).isArmed)
        #expect(store.keyboardShortcut(for: .commitDiary) == nil)
        field.commandChord = store.armedChord(for: .commitDiary)
        #expect(!field.performKeyEquivalent(with: rebound))
        #expect(fixture.draft.diaryCommits == 1)
    }

    private func key(in window: NSWindow, shift: Bool = false) throws -> NSEvent {
        try #require(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: shift ? [.command, .shift] : .command, timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, characters: "\r", charactersIgnoringModifiers: "\r",
            isARepeat: false, keyCode: 36))
    }
}
