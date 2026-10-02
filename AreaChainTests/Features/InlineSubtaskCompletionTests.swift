import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct InlineSubtaskCompletionTests {
    private typealias Native = SettingsButtonTestSupport

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func realRowPreservesIdentityDraftAndImmediateCommit(locale: String, scheme: ColorScheme) async throws {
        let fixture = try InlineCompletionFixture()
        defer { fixture.cleanup() }
        let window = fixture.native.window(InlineCompletionRow(fixture: fixture), locale: locale,
                                           scheme: scheme, size: NSSize(width: 320, height: 220))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try await fixture.expand(in: window)
        let inspected = WorkspaceNavigation.shared.selectedTaskID
        let editor = try #require(Native.elements(window.contentView).compactMap { $0 as? NSTextField }
            .first { $0.isEditable })
        window.makeFirstResponder(editor)
        let text = try #require(editor.currentEditor() as? NSTextView)
        text.insertText("尚未提交的相邻输入", replacementRange: text.selectedRange())
        try await SystemPageHost.settle(window)
        let second = fixture.subtasks[1]
        let nodes = try fixture.subtasks.map { try Native.button("task.subtask.complete.\($0.id)", in: window) }
        try Native.assertBounds(nodes, in: window)
        try await Native.click(Native.button("task.subtask.complete.\(second.id)", in: window), in: window)
        #expect(second.isDone && !fixture.subtasks[0].isDone && !fixture.todo.isDone)
        #expect(fixture.probe.actions.count == 1)
        if case .toggleSubtask(let id) = fixture.probe.actions.first { #expect(id == second.id) }
        else { Issue.record("应仅派发正确 UUID 的 toggleSubtask") }
        #expect(PendingCompletionManager.shared.pendingDoneIDs.isEmpty)
        #expect(fixture.probe.selections == 0 && fixture.probe.parentToggles == 0)
        #expect(WorkspaceNavigation.shared.selectedTaskID == inspected)
        #expect(fixture.probe.draft == "尚未提交的相邻输入" && fixture.probe.submits == 0)
        #expect(Native.elements(window.contentView).compactMap { $0 as? NSTextField }.filter { $0.isEditable }.count == 1)
        let saved = try ModelContext(fixture.native.container).fetch(FetchDescriptor<SubtaskItem>())
        #expect(saved.first { $0.id == second.id }?.isDone == true)
        #expect(fixture.todo.dayKey == "2026-10-01")
        try Native.snapshot(window, name: "inline-completion-\(locale)-\(scheme)")
    }

    @Test func failedTransactionRestoresModelAndRefreshedExternalStateWithoutRetry() async throws {
        let fixture = try InlineCompletionFixture()
        defer { fixture.cleanup() }
        let window = fixture.native.window(InlineCompletionRow(fixture: fixture))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try await fixture.expand(in: window)
        let sub = fixture.subtasks[0]
        let button = try Native.button("task.subtask.complete.\(sub.id)", in: window)
        // 沿既有事务注入 save 失败，按钮仍经过真实 TaskRowFactory → DayBoardMutations → 仓储。
        #expect(throws: CocoaError.self) {
            try ModelChanges.transaction(in: fixture.native.container.mainContext,
                                         save: { _ in throw CocoaError(.fileWriteNoPermission) }) {
                _ = button.perform(NSSelectorFromString("accessibilityPerformPress"))
            }
        }
        try await Task.sleep(for: .milliseconds(600))
        #expect(fixture.probe.actions.count == 1)
        #expect(!sub.isDone && !fixture.todo.isDone)
        // SwiftData 回滚后重新投影外部快照；此用例不声称回滚会自动刷新所有宿主。
        fixture.probe.refresh += 1
        try await SystemPageHost.settle(window)
        let refreshed = try Native.button("task.subtask.complete.\(sub.id)", in: window)
        #expect(Native.value(refreshed, "accessibilityLabel") as? String ==
                L10n.string("checkbox.open", locale: Locale(identifier: "en")))
        #expect(PendingCompletionManager.shared.pendingDoneIDs.isEmpty)
    }

    @Test func missingCallbackDoesNotCreateAnActionOrCompletion() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let sub = SubtaskSnapshot(id: UUID(), todoId: UUID(), title: "无回调", isDone: false)
        let window = fixture.window(TaskRowSubtaskInlineList(subtasks: [sub], onToggle: nil))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try await Native.click(Native.button("task.subtask.complete.\(sub.id)", in: window), in: window)
        try await Task.sleep(for: .milliseconds(500))
        #expect(Native.value(try Native.button("task.subtask.complete.\(sub.id)", in: window), "accessibilityLabel") as? String ==
                L10n.string("checkbox.open", locale: Locale(identifier: "en")))
        #expect(try fixture.container.mainContext.fetchCount(FetchDescriptor<SubtaskItem>()) == 0)
    }

    @Test(arguments: [false, true])
    func inspectorHeaderKeepsCallbacksAndLayout(done: Bool) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        var toggles = 0
        var other = 0
        let header = TaskDetailHeaderBar(isDone: done, onToggle: { toggles += 1 },
                                        onTrash: { other += 1 }, onClose: { other += 1 })
        let window = fixture.window(header.padding(12), size: NSSize(width: 300, height: 80))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try Native.assertBounds(Native.buttons(in: window), in: window)
        try await Native.click(Native.button(done ? "checkbox.done" : "checkbox.open", in: window), in: window)
        #expect(toggles == 1 && other == 0)
    }
}

@Observable @MainActor
private final class InlineCompletionProbe {
    var actions: [TaskRowAction] = []
    var selections = 0
    var parentToggles = 0
    var draft = ""
    var submits = 0
    var refresh = 0
}

@MainActor
private final class InlineCompletionFixture {
    let native: SettingsButtonTestSupport
    let todo: TodoItem
    let subtasks: [SubtaskItem]
    let probe = InlineCompletionProbe()
    private let previousDelay = PendingCompletionManager.shared.skipDelayOverride

    init() throws {
        native = try SettingsButtonTestSupport()
        let parent = TodoItem(title: "合成父任务", dayKey: "2026-10-01")
        todo = parent
        subtasks = ["第一个子任务", String(repeating: "第二个长标题 / Long subtask title ", count: 6)]
            .enumerated().map { SubtaskItem(title: $0.element, sortOrder: $0.offset, todo: parent) }
        native.container.mainContext.insert(todo)
        subtasks.forEach { native.container.mainContext.insert($0) }
        try native.container.mainContext.save()
        PendingCompletionManager.shared.skipDelayOverride = false
    }

    func cleanup() {
        PendingCompletionManager.shared.clearAll()
        PendingCompletionManager.shared.skipDelayOverride = previousDelay
        native.cleanup()
    }

    func expand(in window: NSWindow) async throws {
        let node = try #require(SettingsButtonTestSupport.elements(window.contentView).first {
            let label = SettingsButtonTestSupport.value($0, "accessibilityLabel") as? String ?? ""
            let title = SettingsButtonTestSupport.value($0, "accessibilityTitle") as? String ?? ""
            return label.contains("0/2") || title.contains("0/2")
        })
        try await SettingsButtonTestSupport.click(node, in: window)
    }
}

private struct InlineCompletionRow: View {
    let fixture: InlineCompletionFixture
    @State private var focused = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            row
            SyntaxTextField(text: Binding(get: { fixture.probe.draft }, set: { fixture.probe.draft = $0 }),
                            placeholder: "Synthetic draft", focused: $focused,
                            onSubmit: { fixture.probe.submits += 1 })
        }.padding(12).background(DaybookPalette.fill.page)
    }

    private var row: TaskRow {
        _ = fixture.probe.refresh
        let original = TaskRowFactory.todo(TodoRowContext(
            todo: fixture.todo, todayKey: "2026-10-01",
            catalogs: TaskCatalogContext(tags: [], attachments: [], context: fixture.native.container.mainContext),
            display: TodoRowDisplayOptions(isDone: fixture.todo.isDone, dragPayload: TodoDragToken.encode(fixture.todo.id)),
            actions: TodoRowActions(onSelect: { _ in fixture.probe.selections += 1 }, onDelete: {},
                                    onToggle: { fixture.probe.parentToggles += 1 })
        ))
        return TaskRow(state: original.state, onSaveTitle: original.onSaveTitle) { action in
            fixture.probe.actions.append(action)
            original.dispatch(action)
        }
    }
}
