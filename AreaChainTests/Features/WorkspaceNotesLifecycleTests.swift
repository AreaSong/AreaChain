import AppKit
import Observation
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct WorkspaceNotesLifecycleTests {
    @Test func successfulBlurAndUnmountPublishOnce() async throws {
        let host = try NotesLifecycleHost()
        defer { host.close() }
        let editor = try await host.prepare()
        editor.insertText("Synthetic changed", replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        host.window.makeFirstResponder(nil)
        try await host.settle()
        host.state.visible = false
        try await host.settle()
        #expect(host.state.calls == 1 && host.state.publications == 1)
        #expect(host.state.item.notes == "Synthetic changed" && EditDrafts.shared.notes[host.state.key] == nil)
    }

    @Test func failedBlurCanRetryAndNewEditingCanSave() async throws {
        let host = try NotesLifecycleHost()
        defer { host.close() }
        host.state.fails = true
        let editor = try await host.prepare()
        editor.insertText("Synthetic retained", replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        host.window.makeFirstResponder(nil)
        try await host.settle()
        #expect(host.state.calls == 1 && host.state.publications == 0 && host.state.failures == 1)
        #expect(host.state.item.notes == "Original" && EditDrafts.shared.notes[host.state.key] == "Synthetic retained")
        host.state.fails = false
        try #require(host.window.makeFirstResponder(editor))
        try host.commandReturn()
        try await host.settle()
        #expect(host.state.calls == 2 && host.state.publications == 1)
        editor.insertText(" again", replacementRange: editor.selectedRange())
        try await host.settle()
        host.window.makeFirstResponder(nil)
        try await host.settle()
        #expect(host.state.calls == 3 && host.state.publications == 2)
    }

    @Test func failedDraftSurvivesUnmountAndDifferentRecordWithSameText() async throws {
        let host = try NotesLifecycleHost()
        defer { host.close() }
        host.state.fails = true
        var editor = try await host.prepare()
        editor.insertText("Same synthetic draft", replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        let firstKey = host.state.key
        host.window.makeFirstResponder(nil)
        try await host.settle()
        host.state.visible = false
        try await host.settle()
        #expect(host.state.calls == 1 && EditDrafts.shared.notes[firstKey] == "Same synthetic draft")
        host.state.item = host.state.other
        host.state.visible = true
        editor = try await host.prepare()
        #expect(editor.string == "Original")
        editor.insertText("Same synthetic draft", replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        host.state.fails = false
        host.window.makeFirstResponder(nil)
        try await host.settle()
        #expect(host.state.calls == 2 && host.state.publications == 1)
        #expect(EditDrafts.shared.notes[firstKey] == "Same synthetic draft")
        #expect(EditDrafts.shared.notes[host.state.key] == nil)
    }

    @Test func collapseDuringMarkedNotesRetainsDraftWithoutSaving() async throws {
        let host = try NotesLifecycleHost()
        defer { host.close() }
        let editor = try await host.prepare()
        editor.setMarkedText("组合草稿", selectedRange: NSRange(location: 4, length: 0),
                             replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        try #require(editor.hasMarkedText())
        let draft = editor.string
        host.focus.releaseFocus()
        host.state.visible = false
        try await host.settle()
        #expect(host.state.calls == 0 && host.state.publications == 0)
        #expect(EditDrafts.shared.notes[host.state.key] == draft)
        #expect(host.window.firstResponder !== editor)
        host.state.visible = true
        try await host.settle()
        #expect(try host.editor().string == draft)
    }

    @Test func externalUpdateDoesNotOverwriteUnsavedDraft() async throws {
        let host = try NotesLifecycleHost()
        defer { host.close() }
        let editor = try await host.prepare()
        host.state.fails = true
        editor.insertText("Local synthetic draft", replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        host.state.item.notes = "External synthetic update"
        try host.fixture.container.mainContext.save()
        try await host.settle()
        #expect(editor.string == "Local synthetic draft")
        host.window.makeFirstResponder(nil)
        try await host.settle()
        #expect(host.state.item.notes == "External synthetic update")
        #expect(EditDrafts.shared.notes[host.state.key] == "Local synthetic draft")
    }
}

@Observable @MainActor
private final class NotesLifecycleState {
    var item: TodoItem
    let first: TodoItem
    let other: TodoItem
    var visible = true
    var fails = false
    var calls = 0
    var publications = 0
    var failures = 0
    var key: String { "todo-\(item.id)" }

    init(first: TodoItem, other: TodoItem) {
        item = first
        self.first = first
        self.other = other
    }

    func save(_ value: String) -> Bool {
        guard let context = item.modelContext else { return false }
        calls += 1
        return ModelChanges.perform(in: context, boundary: .init(save: { [self] context in
            if fails { throw CocoaError(.fileWriteUnknown) }
            try context.save()
        }, publish: { [self] in publications += 1 }, reportFailure: { [self] _ in failures += 1 })) {
            // 实际生产备注入口继承外层注入的事务；不用假的成功值替代保存/回滚。
            _ = DayBoardMutations.updateNotes(for: item, notes: value)
        }
    }
}

@MainActor
private final class NotesLifecycleHost {
    let fixture: SettingsButtonTestSupport
    let state: NotesLifecycleState
    let focus = WorkspaceInspectorFocus()
    let window: NSWindow

    init() throws {
        fixture = try SettingsButtonTestSupport(isolatedPreferences: true)
        let first = TodoItem(title: "Synthetic first", dayKey: "2026-10-09")
        let other = TodoItem(title: "Synthetic second", dayKey: "2026-10-09")
        first.notes = "Original"
        other.notes = "Original"
        fixture.container.mainContext.insert(first)
        fixture.container.mainContext.insert(other)
        try fixture.container.mainContext.save()
        state = NotesLifecycleState(first: first, other: other)
        window = fixture.window(NotesLifecycleView(state: state, focus: focus), size: .init(width: 400, height: 300))
        print("WORKSPACE_QA pid=\(ProcessInfo.processInfo.processIdentifier) bundle=\(Bundle.main.bundleIdentifier ?? "nil") xctest=\(ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil) memory=true")
    }

    func editor() throws -> NSTextView {
        let editors = ScrollNativeEvidence.views(window).compactMap { $0 as? NSTextView }
            .filter { $0.isEditable && !$0.isFieldEditor && !$0.isHiddenOrHasHiddenAncestor && !$0.visibleRect.isEmpty }
        try #require(editors.count == 1)
        return try #require(editors.first)
    }

    func prepare() async throws -> NSTextView {
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await settle()
        let result = try editor()
        try #require(window.makeFirstResponder(result))
        try await settle()
        return result
    }

    func commandReturn() throws {
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        #expect(window.performKeyEquivalent(with: event))
    }

    func settle() async throws { try await SystemPageHost.settle(window) }

    func close() {
        window.makeFirstResponder(nil)
        window.contentView = nil
        window.orderOut(nil)
        for item in [state.first, state.other] { EditDrafts.shared.notes.removeValue(forKey: "todo-\(item.id)") }
        fixture.cleanup()
    }
}

private struct NotesLifecycleView: View {
    @Bindable var state: NotesLifecycleState
    let focus: WorkspaceInspectorFocus
    var body: some View {
        if state.visible {
            TaskDetailNotesView(draftKey: state.key, notes: state.item.notes, onUpdate: state.save)
                .id("notes-\(state.item.id)")
                .background(WorkspaceInspectorFocusMarker(owner: focus))
                .environment(\.workspaceInspectorFocus, focus)
                .padding()
                .syntaxOverlayHost()
        } else { Text("Collapsed") }
    }
}
