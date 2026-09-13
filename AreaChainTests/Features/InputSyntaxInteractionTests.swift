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
        try #require(editor.tryToPerform(Selector(("undo:")), with: nil))
        try await host.settle()
        // 合成输入共用原生事件事务；撤销可回到空草稿，不能留下错位的半截字符。
        #expect(editor.string.isEmpty)
        try #require(editor.tryToPerform(Selector(("redo:")), with: nil))
        try await host.settle()
        #expect(editor.string == "#工作 ")
    }

    @Test(arguments: [false, true])
    func mouseCompletionInTheMiddleOfATagKeepsTheCaretAndUndo(multiline: Bool) async throws {
        let host = try InputSyntaxHost()
        defer { host.close() }
        host.container.mainContext.insert(TagItem(name: "工作", sortOrder: 0))
        try host.container.mainContext.save()
        if multiline { host.show(DiaryInputFixture(), size: NSSize(width: 600, height: 500)) }
        else { host.show(SearchPage(), size: NSSize(width: 600, height: 500)) }
        try await host.settle()
        let editor = try host.focusEditor(multiline: multiline)
        editor.insertText("#工作事项", replacementRange: NSRange(location: 0, length: 0))
        editor.setSelectedRange(NSRange(location: 2, length: 0))
        try await host.settle()
        let anchor: NSView = multiline ? try #require(editor.enclosingScrollView) : try #require(host.field)
        let bounds = anchor.convert(anchor.bounds, to: nil)
        try host.click(NSPoint(x: bounds.minX + 80, y: bounds.minY - (multiline ? 46 : 52)))
        try await host.settle()
        try #require(editor.string == "#工作 ")
        try #require(editor.selectedRange().location == 4)
        try #require(editor.tryToPerform(Selector(("undo:")), with: nil))
        try await host.settle()
        #expect(editor.string.isEmpty)
        try #require(editor.tryToPerform(Selector(("redo:")), with: nil))
        try await host.settle()
        #expect(editor.string == "#工作 ")
        editor.insertText("继续", replacementRange: editor.selectedRange())
        #expect(editor.string == "#工作 继续")
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

    @Test func notesEscapePassesThroughTheListMonitorBeforeSaving() async throws {
        let host = try InputSyntaxHost()
        defer { host.close() }
        let todo = TodoItem(title: "列表与备注", dayKey: "2026-09-13")
        host.container.mainContext.insert(todo)
        try host.container.mainContext.save()
        host.show(NotesWithListFixture(todo: todo), size: NSSize(width: 700, height: 420))
        try await host.settle()
        let editor = try host.focusEditor(multiline: true)
        editor.insertText("#半", replacementRange: NSRange(location: 0, length: 0))
        try await host.settle()
        let coordinator = try #require(editor.delegate as? DaybookTextEditor.Coordinator)
        #expect(coordinator.parent.autocomplete.isActive)
        try host.pressEscape()
        try await host.settle()
        #expect(!coordinator.parent.autocomplete.isActive)
        #expect(host.window.firstResponder === editor)
        #expect(host.tags.isEmpty && todo.notes.isEmpty)
        try host.pressEscape()
        try await host.settle()
        #expect(host.window.firstResponder !== editor)
        #expect(todo.notes == "#半" && host.tags.map(\.name) == ["半"])
    }

    @Test(arguments: [false, true])
    func unchangedResidentTitleDoesNotApplySyntaxOnEscapeOrBlur(escape: Bool) async throws {
        let host = try InputSyntaxHost()
        defer { host.close() }
        let original = "读书 #待读 !p2"
        let routine = DailyRoutine(title: original, sortOrder: 0)
        host.container.mainContext.insert(routine)
        try host.container.mainContext.save()
        host.show(ResidentsPage(), size: NSSize(width: 650, height: 450))
        try await host.settle()
        let field = try #require(host.fields.first { $0.stringValue == original })
        host.window.makeFirstResponder(field)
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.setSelectedRange(NSRange(location: 0, length: 0))
        try await host.settle()
        if escape { try host.pressEscape() }
        else { host.window.makeFirstResponder(nil) }
        try await host.settle()
        #expect(routine.title == original)
        #expect(host.tags.isEmpty && routine.tagIDs.isEmpty)
        #expect(!routine.isImportant && routine.remindMinutes == nil)
    }

    @Test(arguments: [false, true])
    func editedResidentTitleStillSavesOnReturnOrBlur(blur: Bool) async throws {
        let host = try InputSyntaxHost()
        defer { host.close() }
        let routine = DailyRoutine(title: "原习惯", sortOrder: 0)
        host.container.mainContext.insert(routine)
        try host.container.mainContext.save()
        host.show(ResidentsPage(), size: NSSize(width: 650, height: 450))
        try await host.settle()
        let field = try #require(host.fields.first { $0.stringValue == "原习惯" })
        host.window.makeFirstResponder(field)
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.selectAll(nil)
        editor.insertText("#今日 新习惯", replacementRange: editor.selectedRange())
        try await host.settle()
        if blur { host.window.makeFirstResponder(nil) }
        else { try host.pressReturn() }
        try await host.settle()
        #expect(routine.title == "新习惯")
        #expect(host.tags.map(\.name) == ["今日"])
        #expect(!routine.tagIDs.isEmpty)
    }

    @Test func listShortcutsDoNotInterruptChineseComposition() throws {
        let list = DayBoardList(dayKey: "2026-09-13", routines: [], checks: [], todos: [])
        let editor = NSTextView()
        editor.setMarkedText("今", selectedRange: NSRange(location: 1, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
        for keyCode: UInt16 in [53, 125] {
            let event = try #require(NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
                context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: keyCode
            ))
            #expect(list.handleTextViewEditingKey(event: event, firstResponder: editor) === event)
        }
    }

    @Test func nativeCompletionRegistersASeparateUndoableReplacement() throws {
        let editor = UndoableSyntaxTestView()
        editor.allowsUndo = true
        editor.isRichText = false
        let undo = editor.history
        undo.groupsByEvent = false
        undo.beginUndoGrouping()
        editor.insertText("#工", replacementRange: NSRange(location: 0, length: 0))
        undo.endUndoGrouping()
        let completion = SyntaxAutocompleteState(context: .tags)
        completion.editor = editor
        completion.update(text: editor.string, cursorLocation: 2, availableTags: ["工作"])
        let candidate = try #require(completion.candidates.first { $0.id == "tag_工作" })
        undo.beginUndoGrouping()
        #expect(completion.commit(candidate))
        undo.endUndoGrouping()
        #expect(editor.string == "#工作 " && editor.selectedRange().location == 4)
        undo.undo()
        #expect(editor.string == "#工")
        undo.redo()
        #expect(editor.string == "#工作 ")
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
private final class UndoableSyntaxTestView: NSTextView {
    let history = UndoManager()
    override var undoManager: UndoManager? { history }
}

private struct NotesWithListFixture: View {
    let todo: TodoItem
    @State private var selectedID: UUID?
    var body: some View {
        HStack {
            VStack {
                DayBoardList(
                    dayKey: todo.dayKey, routines: [], checks: [], todos: [todo],
                    config: DayBoardListConfig(interaction: DayBoardInteraction(focusedTaskID: $selectedID))
                )
            }
            TodoBasicsSectionView(todo: todo)
        }
    }
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
    var fields: [NSTextField] { descendants(window.contentView).compactMap { $0 as? NSTextField }.filter(\.isEditable) }
    var field: NSTextField? { fields.first }

    func focusEditor(multiline: Bool) throws -> NSTextView {
        if multiline {
            let editor = try #require(editor)
            window.makeFirstResponder(editor)
            return editor
        }
        let field = try #require(field)
        window.makeFirstResponder(field)
        return try #require(field.currentEditor() as? NSTextView)
    }

    func close() { window.contentView = nil; window.orderOut(nil) }

    func settle() async throws {
        window.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(180))
        window.contentView?.layoutSubtreeIfNeeded()
    }

    func pressReturn() throws {
        let event = try keyEvent(modifiers: [])
        NSApp.sendEvent(event)
    }

    func click(_ point: NSPoint) throws {
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
            ))
            NSApp.sendEvent(event)
        }
    }

    func commandReturn() throws {
        #expect(window.performKeyEquivalent(with: try keyEvent(modifiers: .command)))
    }

    func pressEscape() throws {
        NSApp.sendEvent(try keyEvent(modifiers: [], character: "\u{1b}", keyCode: 53))
    }

    private func keyEvent(modifiers: NSEvent.ModifierFlags, character: String = "\r", keyCode: UInt16 = 36) throws -> NSEvent {
        try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, characters: character, charactersIgnoringModifiers: character,
            isARepeat: false, keyCode: keyCode
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
