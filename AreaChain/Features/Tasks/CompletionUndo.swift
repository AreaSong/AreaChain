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
        let context = Persistence.session.container.mainContext
        switch last {
        case .todo(let id, _, let reopen):
            guard let todo = try? SwiftDataTaskRepository(context: context).fetchTodo(id: id) else { return false }
            guard DayBoardMutations.toggleTodo(todo) else { return false }
            for subtask in todo.subtasks where reopen.contains(subtask.id) && subtask.deletedAt == nil && subtask.isDone {
                _ = DayBoardMutations.toggleSubtask(subtask)
            }
        case .routine(let id, let dayKey, _):
            guard let routine = try? SwiftDataRoutineRepository(context: context).fetchRoutine(id: id) else { return false }
            let checks = (try? SwiftDataRoutineRepository(context: context).fetchChecks(for: id)) ?? []
            return DayBoardMutations.toggleRoutine(routine, on: dayKey, checks: checks, context: context)
        case .subtask(let id, _):
            guard let subtask = try? context.fetch(
                FetchDescriptor<SubtaskItem>(predicate: #Predicate { $0.id == id })
            ).first else { return false }
            return DayBoardMutations.toggleSubtask(subtask)
        }
        return true
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command), !flags.contains(.shift),
              event.charactersIgnoringModifiers?.lowercased() == "z" else { return event }
        if NSApp.keyWindow?.firstResponder is NSTextView { return event }
        return undo() ? nil : event
    }
}
