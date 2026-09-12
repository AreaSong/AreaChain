import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct SubtaskTitleEditingTests {
    @Test func failedSaveKeepsDraftOpenUntilRetrySucceeds() async throws {
        let harness = try SubtaskEditorHarness()
        defer { harness.close() }
        try await harness.beginEditing("尚未保存的新标题")
        try await harness.press(.return)

        #expect(harness.attemptedTitles == ["尚未保存的新标题"])
        #expect(harness.subtask.title == "原标题")
        #expect(harness.editorText == "尚未保存的新标题")

        harness.rejectWrites = false
        try await harness.press(.return)
        #expect(harness.attemptedTitles == ["尚未保存的新标题", "尚未保存的新标题"])
        #expect(harness.subtask.title == "尚未保存的新标题")
        #expect(harness.editorText == nil)
        let reader = ModelContext(harness.container)
        #expect(try reader.fetch(FetchDescriptor<SubtaskItem>()).first?.title == "尚未保存的新标题")
    }

    @Test func escapeAfterFailedSaveDiscardsOnlyTheDraft() async throws {
        let harness = try SubtaskEditorHarness()
        defer { harness.close() }
        try await harness.beginEditing("主动取消的草稿")
        try await harness.press(.return)
        #expect(harness.editorText == "主动取消的草稿")

        try await harness.press(.escape)
        #expect(harness.editorText == nil)
        #expect(harness.subtask.title == "原标题")
        #expect(harness.attemptedTitles == ["主动取消的草稿"])
    }

    @Test func modelRefreshDoesNotReplaceAnActiveDraft() async throws {
        let harness = try SubtaskEditorHarness()
        defer { harness.close() }
        try await harness.beginEditing("正在编辑的草稿")
        harness.subtask.title = "刷新后的持久化标题"
        try harness.container.mainContext.save()
        try await harness.settle()
        #expect(harness.editorText == "正在编辑的草稿")

        try await harness.press(.escape)
        #expect(harness.editorText == nil)
        #expect(harness.subtask.title == "刷新后的持久化标题")
        #expect(harness.attemptedTitles.isEmpty)
    }
}

@MainActor
private final class SubtaskEditorHarness {
    // SwiftUI 的销毁回调可晚于测试结束，内存容器须覆盖模型视图的完整生命周期。
    private static var retainedContainers: [ModelContainer] = []
    let container: ModelContainer
    let subtask: SubtaskItem
    let window: NSWindow
    var rejectWrites = true
    private(set) var attemptedTitles: [String] = []

    init() throws {
        container = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let todo = TodoItem(title: "父任务", dayKey: "2026-09-12")
        subtask = SubtaskItem(title: "原标题", todo: todo)
        container.mainContext.insert(todo)
        container.mainContext.insert(subtask)
        try container.mainContext.save()
        Self.retainedContainers.append(container)
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 70),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        let content = SubtaskRowView(
            subtask: subtask, onToggle: {},
            onUpdateTitle: { [weak self] title in self?.save(title) ?? false }, onDelete: {}
        )
        .padding(12)
        .frame(width: 320, height: 70)
        .modelContainer(container)
        .transaction { $0.disablesAnimations = true }
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: content)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    var editorText: String? { field(in: window.contentView)?.stringValue }

    func close() {
        window.contentView = nil
        window.orderOut(nil)
    }

    func beginEditing(_ title: String) async throws {
        try await settle()
        for count in 1...2 {
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                let event = try #require(NSEvent.mouseEvent(
                    with: type, location: NSPoint(x: 120, y: 35), modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                    context: nil, eventNumber: 0, clickCount: count, pressure: 1
                ))
                window.sendEvent(event)
            }
        }
        try await settle()
        let textField = try #require(self.field(in: window.contentView))
        window.makeFirstResponder(textField)
        let editor = try #require(textField.currentEditor() as? NSTextView)
        editor.selectAll(nil)
        editor.insertText(title, replacementRange: editor.selectedRange())
        try await settle()
        #expect(editorText == title)
    }

    enum Key { case `return`, escape }

    func press(_ key: Key) async throws {
        let character = key == .return ? "\r" : "\u{1b}"
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, characters: character, charactersIgnoringModifiers: character,
            isARepeat: false, keyCode: key == .return ? 36 : 53
        ))
        window.sendEvent(event)
        try await settle()
    }

    func settle() async throws {
        window.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(180))
        window.contentView?.layoutSubtreeIfNeeded()
    }

    private func field(in view: NSView?) -> NSTextField? {
        guard let view else { return nil }
        if let field = view as? NSTextField, field.isEditable { return field }
        return view.subviews.lazy.compactMap { self.field(in: $0) }.first
    }

    private func save(_ title: String) -> Bool {
        attemptedTitles.append(title)
        return ModelChanges.perform(in: container.mainContext, save: { context in
            if self.rejectWrites { throw CocoaError(.fileWriteNoPermission) }
            try context.save()
        }) {
            subtask.title = title
        }
    }
}
