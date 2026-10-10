import Foundation
import SwiftData

enum WorkspaceOpenFailure: String, Error {
    case unassembled, unavailable, cancelled, composing, stale, invalidTarget, unsupported
}

struct WorkspaceObjectLocation: Equatable {
    let object: CommandObjectReference
    let parent: CommandObjectReference?
    let dayKey: String
    var inspectorID: UUID { parent?.id ?? object.id }
}

/// 打开前重新读取真实身份/关系/业务日；没有仓储修改、保存或系统入口。
@MainActor final class WorkspaceObjectNavigation {
    let context: ModelContext
    let calendar: Calendar
    let allows: (CommandObjectReference) throws -> Bool

    init(context: ModelContext, calendar: Calendar, allows: @escaping (CommandObjectReference) throws -> Bool) {
        self.context = context
        self.calendar = calendar
        self.allows = allows
    }

    func resolve(_ open: ContentQueryBrowseOpen) throws -> WorkspaceObjectLocation {
        guard !open.viewingTrash else { throw WorkspaceOpenFailure.unsupported }
        let object = open.object
        guard try allows(object) else { throw WorkspaceOpenFailure.invalidTarget }
        switch object.type {
        case .todo:
            guard open.parent == nil, object.dayKey == nil else { throw WorkspaceOpenFailure.invalidTarget }
            let todo = try todo(object.id)
            return try location(object, parent: nil, day: todo.dayKey)
        case .subtask:
            guard object.dayKey == nil else { throw WorkspaceOpenFailure.invalidTarget }
            let child = try TaskFamilyCommandIdentity.subtask(object.id, in: context)
            guard let parent = child.todo, try todo(parent.id) === parent,
                  open.parent == .init(type: .todo, id: parent.id),
                  try allows(.init(type: .todo, id: parent.id)),
                  try TaskFamilyCommandIdentity.children(of: parent, in: context).contains(where: { $0 === child }) else {
                throw WorkspaceOpenFailure.invalidTarget
            }
            return try location(object, parent: open.parent, day: parent.dayKey)
        case .routineOccurrence:
            let id = object.id
            let rows = try context.fetch(FetchDescriptor<DailyRoutine>(predicate: #Predicate { $0.id == id }))
            guard rows.count == 1, rows[0].deletedAt == nil, rows[0].modelContext === context,
                  open.parent == .init(type: .routine, id: id), let day = object.dayKey else {
                throw WorkspaceOpenFailure.invalidTarget
            }
            return try location(object, parent: open.parent, day: day)
        default: throw WorkspaceOpenFailure.unsupported
        }
    }

    private func todo(_ id: UUID) throws -> TodoItem {
        let rows = try context.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id }))
        guard rows.count == 1, rows[0].deletedAt == nil, rows[0].modelContext === context else {
            throw WorkspaceOpenFailure.invalidTarget
        }
        return rows[0]
    }

    private func location(_ object: CommandObjectReference, parent: CommandObjectReference?, day: String) throws -> WorkspaceObjectLocation {
        guard let date = DayKey.date(from: day, calendar: calendar), DayKey.from(date, calendar: calendar) == day else {
            throw WorkspaceOpenFailure.invalidTarget
        }
        return .init(object: object, parent: parent, dayKey: day)
    }
}
