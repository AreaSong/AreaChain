import AppKit
import Observation
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 修复批 M-7F：正式版宿主（`sharesProductionStorage`）下检查器失焦即保存，与删开关前的旧界面一致；
/// 隔离宿主仍沿 N-M1 只留草稿（见 UnifiedSearchNavigationBoundaryTests）。只用内存库与合成文字。
@Suite(.serialized) @MainActor
struct InspectorBlurSaveTests {
    @Test func titleBlurSavesInProductionHost() async throws {
        let host = try InspectorBlurHost(.title)
        defer { host.close() }
        let editor = try await host.focusField()
        editor.insertText("Synthetic title saved", replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        host.window.makeFirstResponder(nil)
        try await host.settle()
        #expect(host.state.titleCalls == ["Synthetic title saved"] && host.state.publications == 1)
        #expect(host.state.todo.title == "Synthetic title saved")
        #expect(host.drafts.titles[EditDrafts.key(todo: host.state.todo.id)] == nil)
    }

    @Test func subtaskBlurSavesInProductionHost() async throws {
        let host = try InspectorBlurHost(.subtask)
        defer { host.close() }
        let editor = try await host.focusField()
        editor.insertText("Synthetic child saved", replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        host.window.makeFirstResponder(nil)
        try await host.settle()
        #expect(host.state.subtaskCalls == ["Synthetic child saved"] && host.state.publications == 1)
        #expect(host.state.child.title == "Synthetic child saved")
        #expect(host.drafts.titles[EditDrafts.key(subtask: host.state.child.id)] == nil)
    }

    @Test func notesBlurSavesInProductionHost() async throws {
        let host = try InspectorBlurHost(.notes)
        defer { host.close() }
        let editor = try await host.focusNotes()
        editor.insertText("Synthetic note saved", replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        host.window.makeFirstResponder(nil)
        try await host.settle()
        #expect(host.state.noteCalls == 1 && host.state.publications == 1)
        #expect(host.state.todo.notes == "Synthetic note saved")
        #expect(host.drafts.notes[EditDrafts.key(todo: host.state.todo.id)] == nil)
    }

    /// 保存失败：不发布、不改模型、草稿仍在；重新挂载后编辑内容能找回。
    @Test(arguments: [InspectorBlurHost.Editor.title, .subtask, .notes])
    func failedBlurSaveKeepsDraftWithoutReportingSuccess(_ kind: InspectorBlurHost.Editor) async throws {
        let host = try InspectorBlurHost(kind)
        defer { host.close() }
        host.state.fails = true
        let text = "Synthetic failed \(kind)"
        if kind == .notes {
            let editor = try await host.focusNotes()
            editor.insertText(text, replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        } else {
            let editor = try await host.focusField()
            editor.insertText(text, replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        }
        try await host.settle()
        host.window.makeFirstResponder(nil)
        try await host.settle()
        #expect(host.state.publications == 0 && host.state.failures == 1)
        #expect(host.state.todo.title == "Synthetic parent" && host.state.todo.notes == "Original")
        #expect(host.state.child.title == "Synthetic child")
        host.state.visible = false
        try await host.settle()
        #expect(host.retainedDraft == text)
        host.state.visible = true
        try await host.settle()
        #expect(host.retainedDraft == text)
        #expect(try host.visibleText() == text)
    }

    /// 编辑检查器标题时（焦点仍在检查器里）从搜索输入跳到另一页：先按失焦规则保存，再切页。
    @Test func editingTitleThenNavigatingSavesBeforeLeaving() async throws {
        let fixture = try UnifiedSearchNavigationFixture(productionHost: true)
        defer { fixture.stop() }
        try await fixture.start()
        try await fixture.open(.init(type: .todo, id: fixture.todo.id))
        #expect(fixture.router.outcome == .displayed)
        try await fixture.click("detail.title.display")
        let editor = try Self.inspectorEditor(fixture)
        editor.insertText("needle parent saved", replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        try await fixture.settle()
        #expect(try Self.persisted(fixture).title == "needle parent")
        try await fixture.enter("/go/settings")
        try #require(fixture.window?.firstResponder === editor, "跳转前焦点必须仍在检查器标题，才能证明是导航触发的保存")
        fixture.controller.intent(.open, source: fixture.controller.buffer)
        await fixture.controller.navigationTask?.value
        try await fixture.settle()
        #expect(fixture.router.outcome == .displayed)
        #expect(try Self.persisted(fixture).title == "needle parent saved")
        #expect(fixture.drafts.titles[EditDrafts.key(todo: fixture.todo.id)] == nil)
    }

    /// 编辑检查器标题时用指令关闭检查器：先按失焦规则保存，再关闭，不丢修改。
    @Test func editingTitleThenClosingInspectorSavesFirst() async throws {
        let fixture = try UnifiedSearchNavigationFixture(productionHost: true)
        defer { fixture.stop() }
        try await fixture.start()
        try await fixture.open(.init(type: .todo, id: fixture.todo.id))
        try await fixture.click("detail.title.display")
        let editor = try Self.inspectorEditor(fixture)
        editor.insertText("needle parent closed", replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        try await fixture.settle()
        #expect(try Self.persisted(fixture).title == "needle parent")
        try await fixture.command("inspector.close")
        #expect(!fixture.navigation.isInspectorPresented)
        #expect(fixture.controller.navigationMessage == "unified.navigation.inspectorClosed")
        #expect(try Self.persisted(fixture).title == "needle parent closed")
        #expect(fixture.drafts.titles[EditDrafts.key(todo: fixture.todo.id)] == nil)
    }

    /// 编辑备注后返回搜索再打开另一个结果：返回前已保存，另一个结果照常打开。
    @Test func editingNotesThenOpeningAnotherResultSavesFirst() async throws {
        let fixture = try UnifiedSearchNavigationFixture(productionHost: true)
        defer { fixture.stop() }
        try await fixture.start()
        try await fixture.open(.init(type: .todo, id: fixture.todo.id))
        let window = try #require(fixture.window)
        let notes = try #require(Self.inspectorViews(fixture).compactMap { $0 as? NSTextView }
            .first { !$0.isFieldEditor && $0.isEditable })
        try #require(window.makeFirstResponder(notes))
        notes.insertText("needle note saved", replacementRange: NSRange(location: 0, length: notes.string.utf16.count))
        try await fixture.settle()
        try #require(window.firstResponder === notes)
        try await fixture.back()
        #expect(try Self.persisted(fixture).notes == "needle note saved")
        #expect(fixture.drafts.notes[EditDrafts.key(todo: fixture.todo.id)] == nil)
        try await fixture.open(.init(type: .subtask, id: fixture.child.id))
        #expect(fixture.router.outcome == .displayed)
        #expect(try Self.persisted(fixture).notes == "needle note saved")
    }

    /// 工作台视图内层 `.modelContainer` 让详情写入 container.mainContext，夹具的 `context` 是另一份上下文；
    /// 用新上下文读回持久化结果，证明确实写进了存储而不只是改了内存对象。
    private static func persisted(_ fixture: UnifiedSearchNavigationFixture) throws -> TodoItem {
        let id = fixture.todo.id
        let reader = ModelContext(fixture.data.container)
        return try #require(try reader.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id })).first)
    }

    /// 只取检查器标记范围内的视图：列表行与日历输入框不在检查器里，不能被误当成详情编辑器。
    private static func inspectorViews(_ fixture: UnifiedSearchNavigationFixture) throws -> [NSView] {
        let window = try #require(fixture.window)
        let marker = try #require(fixture.router.inspectorFocus.marker)
        let bounds = marker.convert(marker.bounds, to: nil)
        return SettingsButtonTestSupport.elements(window.contentView).compactMap { $0 as? NSView }.filter { view in
            guard view.window === window, !view.isHiddenOrHasHiddenAncestor else { return false }
            let frame = view.convert(view.bounds, to: nil)
            return bounds.contains(NSPoint(x: frame.midX, y: frame.midY))
        }
    }

    private static func inspectorEditor(_ fixture: UnifiedSearchNavigationFixture) throws -> NSTextView {
        let editor = try #require(fixture.window?.firstResponder as? NSTextView, "点击标题后应进入编辑并取得焦点")
        let field = try #require(editor.delegate as? NSTextField)
        try #require(try inspectorViews(fixture).contains { $0 === field }, "焦点字段必须在检查器内")
        return editor
    }
}

@Observable @MainActor
final class InspectorBlurState {
    let todo: TodoItem
    let child: SubtaskItem
    var visible = true
    var fails = false
    var titleCalls: [String] = []
    var subtaskCalls: [String] = []
    var noteCalls = 0
    var publications = 0
    var failures = 0

    init(todo: TodoItem, child: SubtaskItem) {
        self.todo = todo
        self.child = child
    }

    func saveTitle(_ value: String) -> Bool {
        titleCalls.append(value)
        return perform { _ = DayBoardMutations.editTodo(self.todo, title: value) }
    }

    func saveSubtask(_ value: String) -> Bool {
        subtaskCalls.append(value)
        return perform { self.child.title = value }
    }

    func saveNotes(_ value: String) -> Bool {
        noteCalls += 1
        return perform { _ = DayBoardMutations.updateNotes(for: self.todo, notes: value) }
    }

    private func perform(_ change: () -> Void) -> Bool {
        guard let context = todo.modelContext else { return false }
        return ModelChanges.perform(in: context, boundary: .init(save: { [self] context in
            if fails { throw CocoaError(.fileWriteUnknown) }
            try context.save()
        }, publish: { [self] in publications += 1 }, reportFailure: { [self] _ in failures += 1 }), change)
    }
}

@MainActor
final class InspectorBlurHost {
    enum Editor: String, CustomStringConvertible { case title, subtask, notes; var description: String { rawValue } }

    let kind: Editor
    let fixture: SettingsButtonTestSupport
    let state: InspectorBlurState
    let drafts = EditDrafts()
    let host: WorkspaceHostContext
    let window: NSWindow

    init(_ kind: Editor) throws {
        self.kind = kind
        fixture = try SettingsButtonTestSupport(isolatedPreferences: true)
        let todo = TodoItem(title: "Synthetic parent", dayKey: "2026-10-28")
        todo.notes = "Original"
        let child = SubtaskItem(title: "Synthetic child", todo: todo)
        fixture.container.mainContext.insert(todo)
        fixture.container.mainContext.insert(child)
        try fixture.container.mainContext.save()
        state = InspectorBlurState(todo: todo, child: child)
        host = Self.productionHost(drafts: drafts, defaults: fixture.defaults)
        // 标题与子任务沿原 EditDrafts 恢复入口进入编辑态；值与原标题相同，不代表任何未保存内容。
        switch kind {
        case .title: drafts.titles[EditDrafts.key(todo: todo.id)] = todo.title
        case .subtask: drafts.titles[EditDrafts.key(subtask: child.id)] = child.title
        case .notes: break
        }
        window = fixture.window(InspectorBlurView(kind: kind, state: state, host: host),
                                size: .init(width: 420, height: 320))
    }

    /// 正式版宿主：附件读写走生产取值，但本夹具没有任何附件引用，不会触达共享目录。
    static func productionHost(drafts: EditDrafts, defaults: UserDefaults) -> WorkspaceHostContext {
        let clipboard = ClipboardHistorySession(store: .init(root: FileManager.default.temporaryDirectory
            .appending(path: "AreaChain-M7F-clipboard-" + UUID().uuidString)), defaults: defaults, pasteboard: nil,
            gate: .init(isTrusted: { false }, prompt: {}, sendCommandV: {}))
        let shortcuts = ShortcutStore(defaults: defaults, center: HotKeyCenter(defaults: defaults,
            registration: .init(register: { _, _ in false }, unregister: { _ in })))
        var host = WorkspaceHostContext(navigation: WorkspaceNavigation(boardSelection: BoardSelection()), drafts: drafts,
            filters: BoardFilterSession(),
            vault: PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys()),
            clipboard: clipboard, shortcuts: shortcuts)
        host.sharesProductionStorage = true
        return host
    }

    var retainedDraft: String? {
        switch kind {
        case .title: drafts.titles[EditDrafts.key(todo: state.todo.id)]
        case .subtask: drafts.titles[EditDrafts.key(subtask: state.child.id)]
        case .notes: drafts.notes[EditDrafts.key(todo: state.todo.id)]
        }
    }

    func focusField() async throws -> NSTextView {
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await settle()
        let fields = SettingsButtonTestSupport.elements(window.contentView).compactMap { $0 as? NSTextField }
            .filter { $0.isEditable && !$0.isHiddenOrHasHiddenAncestor }
        let field = try #require(fields.count == 1 ? fields.first : nil)
        try #require(window.makeFirstResponder(field))
        try await settle()
        return try #require(field.currentEditor() as? NSTextView)
    }

    func focusNotes() async throws -> NSTextView {
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await settle()
        let editor = try notesEditor()
        try #require(window.makeFirstResponder(editor))
        try await settle()
        return editor
    }

    func visibleText() throws -> String {
        if kind == .notes { return try notesEditor().string }
        let field = try #require(SettingsButtonTestSupport.elements(window.contentView).compactMap { $0 as? NSTextField }
            .first { $0.isEditable && !$0.isHiddenOrHasHiddenAncestor })
        return field.stringValue
    }

    private func notesEditor() throws -> NSTextView {
        let editors = SettingsButtonTestSupport.elements(window.contentView).compactMap { $0 as? NSTextView }
            .filter { $0.isEditable && !$0.isFieldEditor && !$0.isHiddenOrHasHiddenAncestor }
        return try #require(editors.count == 1 ? editors.first : nil)
    }

    func settle() async throws { try await SystemPageHost.settle(window) }

    func close() {
        window.makeFirstResponder(nil)
        window.contentView = nil
        window.orderOut(nil)
        fixture.cleanup()
    }
}

private struct InspectorBlurView: View {
    let kind: InspectorBlurHost.Editor
    @Bindable var state: InspectorBlurState
    let host: WorkspaceHostContext

    var body: some View {
        Group {
            if state.visible {
                switch kind {
                case .title:
                    TaskDetailTitleEditor(draftKey: EditDrafts.key(todo: state.todo.id), title: state.todo.title,
                                          onUpdate: state.saveTitle)
                case .subtask:
                    SubtaskRowView(subtask: state.child, onToggle: {}, onUpdateTitle: state.saveSubtask, onDelete: {})
                case .notes:
                    TaskDetailNotesView(draftKey: EditDrafts.key(todo: state.todo.id), notes: state.todo.notes,
                                        onUpdate: state.saveNotes)
                }
            } else { Text("Collapsed") }
        }
        .environment(\.workspaceHostContext, host)
        .padding()
        .syntaxOverlayHost()
    }
}
