import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct InputSyntaxInteractionTests {
    @Test func mouseCompletionUpdatesTheMultilineEditorWithoutWriting() async throws {
        let host = try InputSyntaxHost()
        defer { host.close() }
        host.container.mainContext.insert(TagItem(name: "工作", sortOrder: 0))
        try host.container.mainContext.save()
        host.show(DiaryInputFixture(), size: NSSize(width: 600, height: 500))
        try await host.settle()
        let editor = try #require(host.editor)
        host.window.makeFirstResponder(editor)
        editor.insertText("#工", replacementRange: NSRange(location: 0, length: 0))
        try await host.settle()
        let scroll = try #require(editor.enclosingScrollView)
        let bounds = scroll.convert(scroll.bounds, to: nil)
        try host.snapshot("diary-mouse-completion")
        try host.click(NSPoint(x: bounds.minX + 80, y: bounds.minY - 46))
        try await host.settle()
        #expect(editor.string == "#工作 ")
        #expect(host.window.firstResponder === editor)
        #expect(!host.tags.contains { $0.name == "工" })
        #expect(try host.container.mainContext.fetchCount(FetchDescriptor<DiaryEntry>()) == 0)
    }

    @Test func diaryInputOnlyCreatesItsTagWhenSubmittedAndRendersBothThemes() async throws {
        let host = try InputSyntaxHost()
        defer { host.close() }
        host.show(DiaryInputFixture(), size: NSSize(width: 600, height: 500))
        try await host.settle()
        let editor = try #require(host.editor)
        host.window.makeFirstResponder(editor)
        editor.insertText("#今日", replacementRange: NSRange(location: 0, length: 0))
        try await host.settle()
        #expect(!host.tags.contains { $0.name == "今日" })
        try host.snapshot("diary-completion-light")
        editor.insertText(" 今天很开心", replacementRange: editor.selectedRange())
        try await host.settle()
        try host.commandReturn()
        try await host.settle()
        let entry = try #require(host.container.mainContext.fetch(FetchDescriptor<DiaryEntry>()).first)
        let tag = try #require(host.tags.first { $0.name == "今日" })
        #expect(entry.text == "#今日 今天很开心" && TagIDList.contains(entry.tagIDs, tag.id))
        #expect(host.editor?.string.isEmpty == true)
        try host.snapshot("diary-saved-light")
        host.window.appearance = NSAppearance(named: .darkAqua)
        host.show(DiaryInputFixture().preferredColorScheme(.dark), size: NSSize(width: 600, height: 500))
        try await host.settle()
        try host.snapshot("diary-saved-dark")
    }

    @Test func searchCompletesUnknownTagsWithoutCreatingThemAndEscapeClears() async throws {
        let host = try InputSyntaxHost()
        defer { host.close() }
        host.show(SearchPage(), size: NSSize(width: 500, height: 480))
        try await host.settle()
        let field = try #require(host.field)
        host.window.makeFirstResponder(field)
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.insertText("#不存在", replacementRange: NSRange(location: 0, length: 0))
        try await host.settle()
        try host.pressReturn()
        try await host.settle()
        #expect(field.stringValue == "#不存在 ")
        try host.commandReturn()
        #expect(host.tags.isEmpty)
        #expect(try host.container.mainContext.fetchCount(FetchDescriptor<TodoItem>()) == 0)
        try host.snapshot("search-tag-empty")
        editor.doCommand(by: #selector(NSResponder.cancelOperation(_:)))
        try await host.settle()
        #expect(field.stringValue.isEmpty)
    }

    @Test func notesRetainTheDraftUntilCommitInsteadOfCreatingPartialTags() async throws {
        let host = try InputSyntaxHost()
        defer { host.close() }
        let todo = TodoItem(title: "带备注的任务", dayKey: "2026-09-13")
        host.container.mainContext.insert(todo)
        try host.container.mainContext.save()
        host.show(TodoBasicsSectionView(todo: todo), size: NSSize(width: 340, height: 360))
        try await host.settle()
        let editor = try #require(host.editor)
        host.window.makeFirstResponder(editor)
        editor.insertText("#今", replacementRange: NSRange(location: 0, length: 0))
        try await Task.sleep(for: .milliseconds(650))
        #expect(host.tags.isEmpty && todo.notes.isEmpty)
        editor.insertText("日 今天很开心", replacementRange: editor.selectedRange())
        try await host.settle()
        try host.commandReturn()
        try await host.settle()
        #expect(todo.notes == "#今日 今天很开心")
        #expect(host.tags.map(\.name) == ["今日"])
        #expect(TagIDList.contains(todo.tagIDs, try #require(host.tags.first).id))
        try host.snapshot("notes-tags-saved")
    }

    @Test func subtaskInputCreatesItsOwnTagAndDisplaysIt() async throws {
        let host = try InputSyntaxHost()
        defer { host.close() }
        let todo = TodoItem(title: "父任务", dayKey: "2026-09-13")
        host.container.mainContext.insert(todo)
        try host.container.mainContext.save()
        host.show(TaskDetailSubtasksView(todo: todo), size: NSSize(width: 340, height: 250))
        try await host.settle()
        let field = try #require(host.field)
        host.window.makeFirstResponder(field)
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.insertText("#今日 子任务内容", replacementRange: NSRange(location: 0, length: 0))
        try await host.settle()
        #expect(host.tags.isEmpty)
        try host.pressReturn()
        try await host.settle()
        let child = try #require(todo.subtasks.first)
        #expect(child.title == "子任务内容" && !child.tagIDs.isEmpty)
        #expect(todo.tagIDs.isEmpty && field.stringValue.isEmpty)
        try host.snapshot("subtask-tags-saved")
        let tag = try #require(host.tags.first)
        host.show(WorkspaceFilteredListView(tag: tag), size: NSSize(width: 550, height: 500))
        try await host.settle()
        try host.snapshot("tag-page-subtasks")
    }

    @Test func multilineEditorDoesNotConsumeReturnDuringChineseComposition() {
        var text = "#今"
        var focused = true
        let completion = SyntaxAutocompleteState(context: .tags)
        completion.update(text: text, cursorLocation: 2, availableTags: ["今日"])
        let wrapper = DaybookTextEditor(
            text: Binding(get: { text }, set: { text = $0 }),
            focused: Binding(get: { focused }, set: { focused = $0 }),
            placeholder: "测试", autocomplete: completion, availableTags: ["今日"]
        )
        let editor = NSTextView()
        editor.setMarkedText("#今", selectedRange: NSRange(location: 2, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(!wrapper.makeCoordinator().textView(editor, doCommandBy: #selector(NSResponder.insertNewline(_:))))
        #expect(text == "#今")
        DaybookTextEditor.synchronizeText("不得覆盖组合文本", in: editor)
        #expect(editor.string == "#今")
    }
}

private struct DiaryInputFixture: View {
    @Query private var entries: [DiaryEntry]
    var body: some View { DiaryPage(todayKey: "2026-09-13", entries: entries) }
}

@MainActor
private final class InputSyntaxHost {
    private static var retainedContainers: [ModelContainer] = []
    let container: ModelContainer
    let window: NSWindow

    init() throws {
        container = try ModelContainer(for: Schema(AreaChainSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        Self.retainedContainers.append(container)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 500), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
    }

    func show<V: View>(_ view: V, size: NSSize) {
        let content = view.padding(12).modelContainer(container)
            .environment(AppPreferences.shared).environment(\.locale, Locale(identifier: "zh-Hans"))
            .background(DaybookTheme.paper)
            .transaction { $0.disablesAnimations = true }
        window.contentView = NSHostingView(rootView: content)
        window.setContentSize(size)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    var tags: [TagItem] { (try? container.mainContext.fetch(FetchDescriptor<TagItem>())) ?? [] }
    var editor: NSTextView? { descendants(window.contentView).compactMap { $0 as? NSTextView }.first { !$0.isFieldEditor && $0.isEditable } }
    var field: NSTextField? { descendants(window.contentView).compactMap { $0 as? NSTextField }.first { $0.isEditable } }

    func close() { window.contentView = nil; window.orderOut(nil) }

    func settle() async throws {
        window.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(180))
        window.contentView?.layoutSubtreeIfNeeded()
    }

    func pressReturn() throws {
        let event = try keyEvent(modifiers: [])
        window.sendEvent(event)
    }

    func click(_ point: NSPoint) throws {
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
            ))
            window.sendEvent(event)
        }
    }

    func commandReturn() throws {
        #expect(window.performKeyEquivalent(with: try keyEvent(modifiers: .command)))
    }

    private func keyEvent(modifiers: NSEvent.ModifierFlags) throws -> NSEvent {
        try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, characters: "\r", charactersIgnoringModifiers: "\r",
            isARepeat: false, keyCode: 36
        ))
    }

    private func descendants(_ view: NSView?) -> [NSView] {
        guard let view else { return [] }
        return [view] + view.subviews.flatMap { descendants($0) }
    }

    func snapshot(_ name: String) throws {
        let view = try #require(window.contentView)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AreaChain-Input-QA")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try png.write(to: directory.appendingPathComponent(name + ".png"), options: .atomic)
    }
}
