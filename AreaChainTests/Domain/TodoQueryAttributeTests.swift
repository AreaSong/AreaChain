import Foundation
import Testing
@testable import AreaChain

struct TodoQueryAttributeTests {
    @Test func tagNamesUseRealOwnAssociationsAndNormalizedNames() {
        var work = TodoQueryFixture.todo(1)
        work.tagIDs = TagIDList.encode([TodoQueryFixture.work, TodoQueryFixture.study])
        var archived = TodoQueryFixture.todo(2)
        archived.tagIDs = TagIDList.encode([TodoQueryFixture.study, TodoQueryFixture.archive])
        var unrelated = TodoQueryFixture.todo(3, title: "#工作")
        unrelated.subtasks = [TodoQueryFixture.subtask(1, parent: unrelated, tags: [TodoQueryFixture.work])]
        let todos = [work, archived, unrelated]
        #expect(TodoQueryFixture.read("(#工作 | #学习) -#归档", todos).matches.map(\.id.id) == [work.id])
        #expect(TodoQueryFixture.read("#工作 #学习", todos).matches.map(\.id.id) == [work.id])
        #expect(TodoQueryFixture.read("-#工作", todos).matches.map(\.id.id) == [archived.id, unrelated.id])
        let state = TodoQueryFixture.session("#abc #café")
        let names = [TodoQueryFixture.work: " ＡＢＣ ", TodoQueryFixture.study: "cafe\u{301}"]
        #expect(TodoQueryFixture.read(state, todos, names: names).matches.map(\.id.id) == [work.id])
        #expect(TodoQueryFixture.read(TodoQueryFixture.session("#cafe"), [work], names: names).matches.isEmpty)
    }

    @Test func stableTagsKeepOwnAndTaskOrSubtaskDistinctAndNeverIncludeDeletedChildren() throws {
        var parent = TodoQueryFixture.todo(1)
        let child = TodoQueryFixture.subtask(1, parent: parent, tags: [TodoQueryFixture.work])
        parent.subtasks = [child]
        let own = TodoQueryFixture.add(.page(.tagID(TodoQueryFixture.work)), to: TodoQueryFixture.session())
        let nested = TodoQueryFixture.add(.page(.tagID(TodoQueryFixture.work, matching: .taskOrSubtask)),
                                         to: TodoQueryFixture.session())
        #expect(TodoQueryFixture.read(own, [parent], names: nil).matches.isEmpty)
        let result = TodoQueryFixture.read(nested, [parent], names: nil)
        let match = try #require(result.matches.first)
        #expect(match.id == CommandObjectReference(type: .todo, id: parent.id))
        #expect(match.evidence == [.init(conditionID: nested.conditions[0].id, field: .subtaskTags,
                                        relatedObject: .init(type: .subtask, id: child.id))])
        parent.subtasks[0].deletedAt = TodoQueryFixture.created
        #expect(TodoQueryFixture.read(nested, [parent]).matches.isEmpty)
    }

    @Test func noTagsUsesOwnEmptyAssociationIncludingStableZeroUUID() {
        var parent = TodoQueryFixture.todo(1)
        parent.subtasks = [TodoQueryFixture.subtask(1, parent: parent, tags: [TodoQueryFixture.work])]
        var tagged = TodoQueryFixture.todo(2)
        tagged.tagIDs = BoardFilter.noneID.uuidString
        let noTags = TodoQueryFixture.add(.page(.noTags), to: TodoQueryFixture.session())
        #expect(TodoQueryFixture.read(noTags, [parent, tagged], names: nil, subtasks: .unavailable).matches.map(\.id.id) == [parent.id])
        let actualID = TodoQueryFixture.add(.page(.tagID(BoardFilter.noneID)), to: TodoQueryFixture.session())
        #expect(TodoQueryFixture.read(actualID, [parent, tagged], names: nil).matches.map(\.id.id) == [tagged.id])
    }

    @Test func missingAuxiliaryDataNeverBehavesAsAnEmptyCollection() {
        let empty = TodoQueryFixture.todo(1)
        let query = TodoQueryFixture.session("-#工作")
        let missing = TodoQueryFixture.read(query, [empty], names: nil)
        #expect(missing.queryIsValid && missing.state == .blocked && missing.matches.isEmpty)
        #expect(missing.diagnostics.first?.issue == .missingTagNames)
        #expect(TodoQueryFixture.read(query, [empty], names: [:]).matches.count == 1)
        var orphan = empty
        orphan.tagIDs = TodoQueryFixture.work.uuidString
        let unknown = TodoQueryFixture.read(query, [orphan], names: [:])
        #expect(unknown.matches.isEmpty && !unknown.isCompleteForCoveredTypes)
        #expect(unknown.diagnostics.first?.issue == .missingAssociatedTagName(TodoQueryFixture.work))
        let nested = TodoQueryFixture.add(.page(.tagID(TodoQueryFixture.work, matching: .taskOrSubtask)), to: query)
        #expect(TodoQueryFixture.read(nested, [empty], subtasks: .unavailable).state == .blocked)
        #expect(TodoQueryFixture.read(nested, [empty], subtasks: .includedInSnapshots).state == .evaluated)
    }

    @Test func childIdentityAndOwnershipMustBeUnambiguous() {
        var parent = TodoQueryFixture.todo(1)
        var other = TodoQueryFixture.todo(2)
        let child = TodoQueryFixture.subtask(1, parent: parent, tags: [TodoQueryFixture.work])
        parent.subtasks = [child]
        other.subtasks = [child]
        let query = TodoQueryFixture.add(.page(.tagID(TodoQueryFixture.work, matching: .taskOrSubtask)),
                                        to: TodoQueryFixture.session())
        let duplicated = TodoQueryFixture.read(query, [parent, other])
        #expect(duplicated.matches.isEmpty)
        #expect(duplicated.diagnostics.filter { $0.issue == .duplicateSubtaskID }.count == 2)
        #expect(duplicated.diagnostics.contains { $0.issue == .invalidSubtaskOwner && $0.object?.id == other.id })
        let wrongOwner = TodoQueryFixture.read(query, [other])
        #expect(wrongOwner.diagnostics.first?.issue == .invalidSubtaskOwner && wrongOwner.matches.isEmpty)
    }

    @Test func completionPriorityReminderAndSourceUseExactOwnValues() {
        var target = TodoQueryFixture.todo(1)
        target.isImportant = true
        target.remindMinutes = 930
        target.sourceBundleID = "app.source"
        var done = target
        done.id = TodoQueryFixture.todo(2).id
        done.isDone = true
        var other = TodoQueryFixture.todo(3)
        other.isUrgent = true
        let todos = [target, done, other]
        var query = TodoQueryFixture.session("(!p2 | !p1) @15:30 status:open")
        query = TodoQueryFixture.add(.page(.sourceApplication("app.source")), to: query)
        #expect(TodoQueryFixture.read(query, todos).matches.map(\.id.id) == [target.id])
        #expect(TodoQueryFixture.read("status:done", todos).matches.map(\.id.id) == [done.id])
        #expect(TodoQueryFixture.read("@15:31", todos).matches.isEmpty)
        let wrongCase = TodoQueryFixture.add(.page(.sourceApplication("APP.SOURCE")), to: TodoQueryFixture.session())
        #expect(TodoQueryFixture.read(wrongCase, todos).matches.isEmpty)
        let unset = TodoQueryFixture.add(.page(.reminderPresence(.unset)), to: TodoQueryFixture.session())
        #expect(TodoQueryFixture.read(unset, todos).matches.map(\.id.id) == [other.id])
        let set = TodoQueryFixture.add(.page(.reminderPresence(.set)), to: TodoQueryFixture.session())
        #expect(TodoQueryFixture.read(set, todos).matches.map(\.id.id) == [target.id, done.id])
        // 子任务的完成状态不能代替父项。
        target.subtasks = [TodoQueryFixture.subtask(1, parent: target)]
        target.subtasks[0].isDone = true
        #expect(TodoQueryFixture.read("status:open", [target]).matches.count == 1)
    }

    @Test func itemKindAndSeparateStatusPredicatesFollowItemsListing() {
        let open = TodoQueryFixture.todo(1)
        var done = TodoQueryFixture.todo(2)
        done.isDone = true
        let todos = [open, done]
        let page = ContentQueryPage.items(.init(kind: .oneOff, todoStatus: .done, routineStatus: .disabled,
                                                todayKey: QuerySessionFixture.today))
        let response = TodoQueryFixture.read(TodoQueryFixture.session("", page: page), todos)
        #expect(response.matches.map(\.id.id) == [done.id])
        #expect(response.matches.first?.evidence.contains { $0.kind == .typeNeutral } == true)
        let recurring = TodoQueryFixture.add(.page(.itemKind(.recurring)), to: TodoQueryFixture.session())
        #expect(TodoQueryFixture.read(recurring, todos).matches.isEmpty)
        let todoStatus = TodoQueryFixture.add(.page(.todoStatus(.open)), to: TodoQueryFixture.session())
        #expect(TodoQueryFixture.read(todoStatus, todos).matches.map(\.id.id) == [open.id])
    }
}
