import Foundation
@testable import AreaChain

enum SubtaskQueryFixture {
    static func parent(_ number: Int, title: String = "子任务 汇报", day: String = QuerySessionFixture.today) -> TodoSnapshot {
        var parent = TodoQueryFixture.todo(number, title: "父标题", day: day)
        var child = TodoQueryFixture.subtask(number, parent: parent)
        child.title = title
        parent.subtasks = [child]
        return parent
    }

    static func read(
        _ state: ContentQuerySession, _ todos: [TodoSnapshot],
        names: [UUID: String]? = TodoQueryFixture.names, subtasks: TodoQuerySubtaskData = .includedInSnapshots
    ) -> SubtaskQueryResponse {
        SubtaskQueryProvider.read(.init(requestID: TodoQueryFixture.requestID, session: state, todos: todos,
                                        tagNames: names, subtaskData: subtasks))
    }

    static func read(_ source: String, _ todos: [TodoSnapshot]) -> SubtaskQueryResponse {
        read(TodoQueryFixture.session(source), todos)
    }
}
