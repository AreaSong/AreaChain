import AppKit
import SwiftData

/// 只记住最近一次完成或取消完成。文本框聚焦时不接管 ⌘Z。
@MainActor
final class CompletionUndo {
    static let shared = CompletionUndo()

    enum Record {
        case todo(UUID, wasDone: Bool, reopen: [UUID])
        case routine(UUID, dayKey: String, wasClosed: Bool)
        case subtask(UUID, wasDone: Bool)
    }

    private var last: Record?
    private var applying = false
    private var monitor: Any?

    func record(_ record: Record) {
        guard !applying else { return }
        last = record
    }

    func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
    }

    @discardableResult
    func undo() -> Bool {
        guard let last else { return false }
        self.last = nil
        applying = true
        defer { applying = false }
        guard let notice = apply(last) else { return false }
        CompletionUndoToast.shared.show(notice.text(locale: AppPreferences.shared.resolvedLocale))
        return true
    }

    private func apply(_ record: Record) -> CompletionUndoNotice? {
        let context = Persistence.session.container.mainContext
        switch record {
        case .todo(let id, let wasDone, let reopen):
            return applyTodo(id: id, wasDone: wasDone, reopen: reopen, context: context)
        case .routine(let id, let dayKey, let wasClosed):
            return applyRoutine(id: id, dayKey: dayKey, wasClosed: wasClosed, context: context)
        case .subtask(let id, let wasDone):
            return applySubtask(id: id, wasDone: wasDone, context: context)
        }
    }

    private func applyTodo(id: UUID, wasDone: Bool, reopen: [UUID], context: ModelContext) -> CompletionUndoNotice? {
        guard let todo = try? SwiftDataTaskRepository(context: context).fetchTodo(id: id) else { return nil }
        guard DayBoardMutations.toggleTodo(todo) else { return nil }
        let reopened = reopenSubtasks(todo, ids: reopen)
        if wasDone { return .recompletedTodo(title: todo.title) }
        return .reopenedTodo(title: todo.title, subtasks: reopened)
    }

    private func reopenSubtasks(_ todo: TodoItem, ids: [UUID]) -> Int {
        var reopened = 0
        for subtask in todo.subtasks where ids.contains(subtask.id) && subtask.deletedAt == nil && subtask.isDone {
            if DayBoardMutations.toggleSubtask(subtask) { reopened += 1 }
        }
        return reopened
    }

    private func applyRoutine(
        id: UUID, dayKey: String, wasClosed: Bool, context: ModelContext
    ) -> CompletionUndoNotice? {
        guard let routine = try? SwiftDataRoutineRepository(context: context).fetchRoutine(id: id) else { return nil }
        let checks = (try? SwiftDataRoutineRepository(context: context).fetchChecks(for: id)) ?? []
        guard DayBoardMutations.toggleRoutine(routine, on: dayKey, checks: checks, context: context) else { return nil }
        if wasClosed { return .restoredRoutine(title: routine.title) }
        return .reopenedRoutine(title: routine.title)
    }

    private func applySubtask(id: UUID, wasDone: Bool, context: ModelContext) -> CompletionUndoNotice? {
        guard let subtask = try? context.fetch(
            FetchDescriptor<SubtaskItem>(predicate: #Predicate { $0.id == id })
        ).first else { return nil }
        guard DayBoardMutations.toggleSubtask(subtask) else { return nil }
        if wasDone { return .recompletedSubtask(title: subtask.title) }
        return .reopenedSubtask(title: subtask.title)
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command), !flags.contains(.shift),
              event.charactersIgnoringModifiers?.lowercased() == "z" else { return event }
        if NSApp.keyWindow?.firstResponder is NSTextView { return event }
        return undo() ? nil : event
    }
}
