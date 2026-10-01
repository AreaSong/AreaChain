import Foundation
import Testing
@testable import AreaChain

enum TodoQueryFixture {
    static let work = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    static let study = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    static let archive = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
    static let names = [work: "工作", study: "学习", archive: "归档"]
    static let created = Date(timeIntervalSince1970: 1_790_784_000)
    static let requestID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!

    static func todo(_ number: Int, title: String = "项目汇报", day: String = QuerySessionFixture.today) -> TodoSnapshot {
        .init(id: UUID(uuidString: String(format: "30000000-0000-0000-0000-%012d", number))!,
              title: title, isDone: false, dayKey: day, createdAt: created)
    }

    static func session(_ source: String = "", page: ContentQueryPage = .overview) -> ContentQuerySession {
        var state = ContentQuerySession(page: QuerySessionFixture.page(page))
        QuerySessionFixture.apply(.setInput(source), &state)
        return state
    }

    static func read(
        _ state: ContentQuerySession, _ todos: [TodoSnapshot],
        names: [UUID: String]? = names, subtasks: TodoQuerySubtaskData = .includedInSnapshots
    ) -> TodoQueryResponse {
        TodoQueryProvider.read(.init(requestID: requestID, session: state, todos: todos,
                                     tagNames: names, subtaskData: subtasks))
    }

    static func read(_ source: String, _ todos: [TodoSnapshot]) -> TodoQueryResponse {
        read(session(source), todos)
    }

    static func subtask(_ number: Int, parent: TodoSnapshot, tags: [UUID] = []) -> SubtaskSnapshot {
        .init(id: UUID(uuidString: String(format: "40000000-0000-0000-0000-%012d", number))!,
              todoId: parent.id, title: "合成子任务", isDone: false, createdAt: created, tagIDs: TagIDList.encode(tags))
    }

    static func add(_ value: ContentQueryConditionValue, to session: ContentQuerySession) -> ContentQuerySession {
        ContentQueryReducer.reduce(session, .addCondition(value)).state
    }
}
