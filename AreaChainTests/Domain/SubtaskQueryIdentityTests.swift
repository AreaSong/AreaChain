import Foundation
import Testing
@testable import AreaChain

struct SubtaskQueryIdentityTests {
    @Test func deletedParentsAndChildrenNeverReturnButValidSiblingSurvives() {
        var deletedParent = SubtaskQueryFixture.parent(1)
        deletedParent.deletedAt = TodoQueryFixture.created
        var parent = SubtaskQueryFixture.parent(2)
        parent.subtasks[0].deletedAt = TodoQueryFixture.created
        parent.subtasks.append(TodoQueryFixture.subtask(3, parent: parent))
        let result = SubtaskQueryFixture.read("", [deletedParent, parent])
        #expect(result.matches.map(\.id.id) == [parent.subtasks[1].id])
        #expect(result.isCompleteForCoveredTypes && result.diagnostics.isEmpty)
    }

    @Test func duplicateParentIDsQuarantineAllTheirChildrenIncludingDeletedCollision() {
        let first = SubtaskQueryFixture.parent(1)
        var duplicate = first
        duplicate.subtasks = [TodoQueryFixture.subtask(2, parent: duplicate)]
        duplicate.deletedAt = TodoQueryFixture.created
        let valid = SubtaskQueryFixture.parent(3)
        let result = SubtaskQueryFixture.read("", [first, valid, duplicate])
        #expect(result.matches.map(\.id.id) == [valid.subtasks[0].id])
        #expect(result.diagnostics == [.init(issue: .duplicateTodoID, object: .init(type: .todo, id: first.id),
            inputPositions: [.init(parentIndex: 0), .init(parentIndex: 2)])])
        #expect(!result.isCompleteForCoveredTypes)
    }

    @Test func duplicateChildrenWithinAndAcrossParentsNeverUseFirstWins() throws {
        var first = SubtaskQueryFixture.parent(1)
        first.subtasks.append(first.subtasks[0])
        first.subtasks.append(TodoQueryFixture.subtask(3, parent: first))
        var other = SubtaskQueryFixture.parent(2)
        var collision = first.subtasks[0]
        collision.todoId = other.id
        collision.deletedAt = TodoQueryFixture.created
        other.subtasks.append(collision)
        let result = SubtaskQueryFixture.read("", [first, other])
        #expect(result.matches.map(\.id.id) == [first.subtasks[2].id, other.subtasks[0].id])
        let diagnostic = try #require(result.diagnostics.first)
        #expect(diagnostic.issue == .duplicateSubtaskID && diagnostic.object == .init(type: .subtask, id: collision.id))
        #expect(diagnostic.inputPositions == [.init(parentIndex: 0, subtaskIndex: 0),
            .init(parentIndex: 0, subtaskIndex: 1), .init(parentIndex: 1, subtaskIndex: 1)])
        #expect(result.diagnostics.count == 1 && !result.isCompleteForCoveredTypes)
    }

    @Test func wrongOwnershipDoesNotReparentOrPoisonUnrelatedSibling() {
        var parent = SubtaskQueryFixture.parent(1)
        let other = SubtaskQueryFixture.parent(2)
        parent.subtasks[0].todoId = other.id
        parent.subtasks.append(TodoQueryFixture.subtask(3, parent: parent))
        let result = SubtaskQueryFixture.read("", [parent, other])
        #expect(result.matches.map(\.id.id) == [parent.subtasks[1].id, other.subtasks[0].id])
        #expect(result.diagnostics == [.init(issue: .invalidSubtaskOwner, object: .init(type: .subtask, id: parent.subtasks[0].id),
                                            inputPositions: [.init(parentIndex: 0, subtaskIndex: 0)])])
    }

    @Test func malformedDaysAndParentOrChildTimestampsAreQuarantined() {
        for day in ["2026-02-30", "2026-2-03", "", "bad", "2026-13-01"] {
            let bad = SubtaskQueryFixture.parent(1, day: day)
            let result = SubtaskQueryFixture.read("", [bad, SubtaskQueryFixture.parent(2)])
            #expect(result.matches.count == 1 && !result.isCompleteForCoveredTypes)
            #expect(result.diagnostics.first?.issue == .invalidScheduledDay)
            #expect(result.diagnostics.first?.object == .init(type: .todo, id: bad.id))
        }
        for value in [Double.nan, .infinity, -.infinity, Double.greatestFiniteMagnitude] {
            var parent = SubtaskQueryFixture.parent(1)
            parent.createdAt = Date(timeIntervalSince1970: value)
            let badParent = SubtaskQueryFixture.read("", [parent])
            #expect(badParent.matches.isEmpty && badParent.diagnostics.first?.issue == .invalidCreatedAt)
            #expect(badParent.diagnostics.first?.object?.type == .todo)
            parent.createdAt = TodoQueryFixture.created
            parent.subtasks[0].createdAt = Date(timeIntervalSince1970: value)
            parent.subtasks.append(TodoQueryFixture.subtask(2, parent: parent))
            let badChild = SubtaskQueryFixture.read("", [parent])
            #expect(badChild.matches.map(\.id.id) == [parent.subtasks[1].id])
            #expect(badChild.diagnostics.first?.issue == .invalidCreatedAt && badChild.diagnostics.first?.object?.type == .subtask)
        }
    }

    @Test func resultIdentityOrderAndInputsStayIndependentOfSortingAndParentUUID() throws {
        var parent = SubtaskQueryFixture.parent(1)
        parent.subtasks[0].id = parent.id
        parent.subtasks[0].sortOrder = 9
        parent.subtasks.append(TodoQueryFixture.subtask(2, parent: parent))
        parent.subtasks[1].sortOrder = -1
        let other = SubtaskQueryFixture.parent(3, day: "2025-01-01")
        let todos = [other, parent]
        let session = TodoQueryFixture.session("/subtasks")
        let savedTodos = todos
        let savedSession = session
        let result = SubtaskQueryFixture.read(session, todos)
        #expect(result.matches.map(\.id.id) == [other.subtasks[0].id, parent.id, parent.subtasks[1].id])
        let match = try #require(result.matches.first { $0.id.id == parent.id })
        #expect(match.id == .init(type: .subtask, id: parent.id) && match.parent == .init(type: .todo, id: parent.id))
        #expect(match.id != match.parent && match.id.dayKey == nil)
        #expect(todos == savedTodos && session == savedSession && SubtaskQueryFixture.read(session, todos) == result)
        #expect(TodoQueryFixture.read("", [parent]).matches[0].id != match.id)
    }
}
