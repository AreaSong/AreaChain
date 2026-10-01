import Foundation
import Testing
@testable import AreaChain

struct SubtaskQueryAttributeTests {
    @Test func ownParentAndSiblingTagsStaySeparateForTextStableAndNoTags() {
        var parent = SubtaskQueryFixture.parent(1)
        parent.tagIDs = TodoQueryFixture.work.uuidString
        parent.subtasks += [TodoQueryFixture.subtask(2, parent: parent, tags: [TodoQueryFixture.work]),
                            TodoQueryFixture.subtask(3, parent: parent, tags: [TodoQueryFixture.study])]
        for matching in [ContentQueryTagMatching.own, .taskOrSubtask] {
            let query = TodoQueryFixture.add(.page(.tagID(TodoQueryFixture.work, matching: matching)), to: TodoQueryFixture.session())
            let result = SubtaskQueryFixture.read(query, [parent], names: nil)
            #expect(result.matches.map(\.id.id) == [parent.subtasks[1].id])
            #expect(result.matches[0].evidence[0].relatedObject == .init(type: .tag, id: TodoQueryFixture.work))
        }
        #expect(SubtaskQueryFixture.read("#工作", [parent]).matches.map(\.id.id) == [parent.subtasks[1].id])
        #expect(SubtaskQueryFixture.read("-#工作", [parent]).matches.map(\.id.id) == [parent.subtasks[0].id, parent.subtasks[2].id])
        let query = TodoQueryFixture.add(.page(.noTags), to: TodoQueryFixture.session())
        #expect(SubtaskQueryFixture.read(query, [parent], names: nil).matches.map(\.id.id) == [parent.subtasks[0].id])
        parent.subtasks[0].tagIDs = BoardFilter.noneID.uuidString
        #expect(SubtaskQueryFixture.read(query, [parent], names: nil).matches.isEmpty)
        let zero = TodoQueryFixture.add(.page(.tagID(BoardFilter.noneID)), to: TodoQueryFixture.session())
        #expect(SubtaskQueryFixture.read(zero, [parent], names: nil).matches.map(\.id.id) == [parent.subtasks[0].id])
    }

    @Test func tagNormalizationORAndIntersectionReuse2ARules() {
        var parent = SubtaskQueryFixture.parent(1)
        parent.subtasks[0].tagIDs = TagIDList.encode([TodoQueryFixture.work, TodoQueryFixture.study])
        let names = [TodoQueryFixture.work: " ＡＢＣ ", TodoQueryFixture.study: "cafe\u{301}"]
        let query = TodoQueryFixture.session("(#abc | #其他) #café -#归档")
        #expect(SubtaskQueryFixture.read(query, [parent], names: names).matches.count == 1)
        #expect(SubtaskQueryFixture.read(TodoQueryFixture.session("#cafe"), [parent], names: names).matches.isEmpty)
    }

    @Test func ownStatusAndParentPageStatusAreIndependent() throws {
        var doneParent = SubtaskQueryFixture.parent(1)
        doneParent.isDone = true
        var openParent = SubtaskQueryFixture.parent(2)
        openParent.subtasks[0].isDone = true
        #expect(SubtaskQueryFixture.read("status:open", [doneParent, openParent]).matches.map(\.id.id) == [doneParent.subtasks[0].id])
        #expect(SubtaskQueryFixture.read("status:done", [doneParent, openParent]).matches.map(\.id.id) == [openParent.subtasks[0].id])
        let page = ContentQueryPage.items(.init(kind: .oneOff, todoStatus: .done, routineStatus: .disabled,
                                               todayKey: QuerySessionFixture.today))
        let query = TodoQueryFixture.session("status:open", page: page)
        let result = SubtaskQueryFixture.read(query, [doneParent, openParent])
        let match = try #require(result.matches.first)
        #expect(result.matches.map(\.id.id) == [doneParent.subtasks[0].id])
        #expect(match.evidence.contains { $0.field == .completion && $0.relatedObject == nil })
        #expect(match.evidence.contains { $0.field == .parentCompletion && $0.relatedObject == match.parent })
        #expect(match.evidence.contains { $0.field == .parentItemKind && $0.relatedObject == match.parent })
        #expect(match.evidence.contains { $0.kind == .typeNeutral && $0.relatedObject == match.parent })
        let recurring = TodoQueryFixture.add(.page(.itemKind(.recurring)), to: TodoQueryFixture.session())
        #expect(SubtaskQueryFixture.read(recurring, [doneParent, openParent]).matches.isEmpty)
    }

    @Test func absentOwnFieldsBlockButTypedParentPageConstraintsCanMatch() throws {
        var parent = SubtaskQueryFixture.parent(1)
        parent.isImportant = true
        parent.isUrgent = true
        parent.remindMinutes = 930
        parent.sourceBundleID = "app.source"
        for source in ["!p1", "@15:30", "has:image", "(!p1 | !p2)", "(@15:30 | @16:00)"] {
            let result = SubtaskQueryFixture.read(source, [parent])
            #expect(result.queryIsValid && result.state == .inapplicableConditions && result.matches.isEmpty)
            #expect(result.typeAnalysis.assessment(for: .subtask)?.reasons.contains {
                $0.issue == .fieldNotApplicable && !$0.conditionIDs.isEmpty
            } == true)
        }
        var query = TodoQueryFixture.add(.page(.reminderPresence(.set)), to: TodoQueryFixture.session())
        query = TodoQueryFixture.add(.page(.sourceApplication("app.source")), to: query)
        let match = try #require(SubtaskQueryFixture.read(query, [parent]).matches.first)
        #expect(match.evidence.map(\.field) == [.parentReminder, .parentSourceApplication])
        #expect(match.evidence.allSatisfy { $0.relatedObject == match.parent })
        let wrongCase = TodoQueryFixture.add(.page(.sourceApplication("APP.SOURCE")), to: TodoQueryFixture.session())
        #expect(SubtaskQueryFixture.read(wrongCase, [parent]).matches.isEmpty)
        let unset = TodoQueryFixture.add(.page(.reminderPresence(.unset)), to: TodoQueryFixture.session())
        #expect(SubtaskQueryFixture.read(unset, [parent]).matches.isEmpty)
        parent.remindMinutes = nil
        #expect(SubtaskQueryFixture.read(unset, [parent]).matches.count == 1)
        let pagePriority = TodoQueryFixture.session("", page: .today(.init(priorityScope: .p1)))
        #expect(SubtaskQueryFixture.read(pagePriority, [parent]).matches.map(\.id.id) == [parent.subtasks[0].id])
    }

    @Test func missingSubtasksAndTagNamesNeverWidenIncludingExclusionAndOR() {
        let parent = SubtaskQueryFixture.parent(1)
        let missing = SubtaskQueryFixture.read(TodoQueryFixture.session(), [parent], subtasks: .unavailable)
        #expect(missing.state == .blocked && missing.diagnostics.first?.issue == .missingSubtasks)
        let empty = TodoQueryFixture.todo(2)
        #expect(SubtaskQueryFixture.read(TodoQueryFixture.session(), [empty], subtasks: .unavailable).state == .blocked)
        #expect(SubtaskQueryFixture.read(TodoQueryFixture.session(), [empty]).isCompleteForCoveredTypes)
        for text in ["#工作", "-#工作", "(#工作 | -#归档)"] {
            let query = TodoQueryFixture.session(text)
            let absent = SubtaskQueryFixture.read(query, [parent], names: nil)
            #expect(absent.state == .blocked && absent.matches.isEmpty && !absent.isCompleteForCoveredTypes)
            #expect(absent.diagnostics.allSatisfy { $0.issue == .missingTagNames })
        }
        var orphan = parent
        orphan.subtasks[0].tagIDs = TodoQueryFixture.work.uuidString
        let incomplete = SubtaskQueryFixture.read(TodoQueryFixture.session("-#归档"), [orphan, SubtaskQueryFixture.parent(2)], names: [:])
        #expect(incomplete.state == .evaluated && !incomplete.isCompleteForCoveredTypes && incomplete.matches.count == 1)
        #expect(incomplete.diagnostics.first?.issue == .missingAssociatedTagName(TodoQueryFixture.work))
        #expect(incomplete.diagnostics.first?.object == .init(type: .subtask, id: orphan.subtasks[0].id))
        // 父项未知标签不污染子任务自己的辅助数据完整性。
        orphan.tagIDs = TodoQueryFixture.study.uuidString
        #expect(SubtaskQueryFixture.read(TodoQueryFixture.session("#工作"), [orphan], names: [TodoQueryFixture.work: "工作"]).matches.count == 1)
    }
}
