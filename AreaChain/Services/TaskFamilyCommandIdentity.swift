import Foundation
import SwiftData

/// 完成级联与子任务命令共用实体核验；平铺读取包含墓碑，父数组不能独自证明唯一身份。
enum TaskFamilyCommandIdentity {
    static func children(of todo: TodoItem, in context: ModelContext) throws -> [SubtaskItem] {
        let rows = try context.fetch(FetchDescriptor<SubtaskItem>())
        let related = rows.filter { $0.todo === todo }
        let children = todo.subtasks
        let identities = children.map(\.persistentModelID)
        guard todo.modelContext === context, Set(identities).count == identities.count,
              Set(identities) == Set(related.map(\.persistentModelID)) else { throw SubtaskCommandIssue.invalidFamily }
        let byID = Dictionary(grouping: rows, by: \.id)
        guard children.allSatisfy({ $0.modelContext === context && $0.todo === todo && byID[$0.id]?.count == 1 }) else {
            throw SubtaskCommandIssue.invalidFamily
        }
        return children
    }

    static func subtask(_ id: UUID, in context: ModelContext) throws -> SubtaskItem {
        let rows = try context.fetch(FetchDescriptor<SubtaskItem>(predicate: #Predicate { $0.id == id }))
        guard rows.count == 1, rows[0].deletedAt == nil, rows[0].modelContext === context else {
            throw SubtaskCommandIssue.invalidFamily
        }
        return rows[0]
    }
}
