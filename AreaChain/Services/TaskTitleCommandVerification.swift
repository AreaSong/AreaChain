import Foundation
import SwiftData

extension TaskTitleCommandAdapter {
    /// 重读只是当前事实，原 unknown 不升级、不清除，也没有返回可重放草稿的入口。
    func verifyUnknown(_ operation: CommandOperationIdentity, expecting lease: CommandHostLease,
                       displaySession: ContentQueryReadSession? = nil) throws -> CommandTaskTitleVerification {
        try displaySession?.validateDisplayHost(expecting: lease)
        let environment = try assembled()
        try coordinator.validate(lease)
        let run = try coordinator.host(lease.ownership.hostID).session.execution
        guard let run, run.operation(operation.operationID) == operation,
              let unit = run.units.first(where: { $0.members.contains(operation.operationID) }), let facts = unit.taskTitle, facts.state == .unknown,
              let attempt = run.attempt(unit.id), let item = run.snapshot.items.first(where: { $0.id == operation.operationID }),
              let accepted = coordinator.taskTitles.acceptances[item.draft.id],
              accepted.preview.impact.target.id == facts.targetID,
              environment.reader.owns(accepted.preview.binding.source),
              coordinator.taskTitles.wasInvoked(accepted.id) else { throw TaskTitleCommandIssue.stale }
        func result(_ presence: CommandTaskTitleVerification.Presence,
                    _ values: [TaskTitleField: TaskTitleFieldValue] = [:]) -> CommandTaskTitleVerification {
            .init(operation: operation, attempt: attempt, originalFacts: facts, presence: presence, currentValues: values)
        }
        let reader = ModelContext(environment.context.container)
        reader.autosaveEnabled = false
        do {
            let qualification = try environment.source(facts.targetID)
            try displaySession?.validateDisplayHost(expecting: lease)
            guard qualification.protection == .ordinary, qualification.notes == .absent,
                  qualification.revision == accepted.preview.binding.source.revision else { return result(.unreadable) }
            try coordinator.validate(lease)
            let rows = try SwiftDataTaskRepository(context: reader).fetchTodos(withID: facts.targetID)
            guard !rows.isEmpty else { return result(.absent) }
            guard rows.count == 1 else { return result(.ambiguous) }
            let todo = rows[0]
            try environment.reader.verifyOrdinaryTags(todo.tagIDs)
            guard todo.deletedAt == nil else { return result(.deleted) }
            var values: [TaskTitleField: TaskTitleFieldValue] = [.title: .text(todo.title), .tagIDs: .text(todo.tagIDs)]
            if accepted.preview.impact.edit.priority != nil {
                values[.isImportant] = .flag(todo.isImportant)
                values[.isUrgent] = .flag(todo.isUrgent)
            }
            if accepted.preview.impact.edit.remindMinutes != nil { values[.remindMinutes] = .minutes(todo.remindMinutes) }
            return result(.live, values)
        } catch { return result(.unreadable) }
    }
}
