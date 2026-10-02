import Foundation
import Testing
@testable import AreaChain

struct TrashQueryAttributeTests {
    @Test func taskPropertiesAndImageOwnerPropertiesUseAllowedProjection() {
        var input = TrashFixture.family()
        input.todos?[0].isImportant = true
        input.todos?[0].isUrgent = true
        input.todos?[0].remindMinutes = 30
        input.todos?[0].sourceBundleID = "synthetic.app"
        for atom in [ContentQueryAtom.priority(.init(isImportant: true, isUrgent: true)), .reminder(30)] {
            let session = TodoQueryFixture.add(.clause([.init(atom: atom)]), to: TodoQueryFixture.session("/trash"))
            let result = TrashQueryFixture.read(session, input)
            #expect(Set(result.matches.map(\.id.type)) == [.todo, .image])
            #expect(result.restrictedTypes[.subtask] != nil)
        }
        let source = TodoQueryFixture.add(.page(.sourceApplication("synthetic.app")), to: TodoQueryFixture.session("/trash"))
        let result = TrashQueryFixture.read(source, input)
        #expect(result.matches.map(\.id.type) == [.todo])
        #expect(Set(result.undeterminedObjects.map(\.type)) == [.subtask, .image])
        #expect(result.diagnostics.allSatisfy { $0.issue == .unsupportedCondition })
    }

    @Test func childCompletionIsOwnWhilePageCompletionIsParent() {
        var input = TrashFixture.family()
        input.subtasks?[0].isDone = true
        let own = TrashQueryFixture.read("/trash status:done", input)
        #expect(own.matches.map(\.id.type) == [.subtask])
        let page = TodoQueryFixture.add(.page(.todoStatus(.done)), to: TodoQueryFixture.session("/trash"))
        #expect(TrashQueryFixture.read(page, input).matches.isEmpty)
    }

    @Test func privateDiaryTagsDecideWithoutBodyAndMalformedTagsStayUnknown() {
        var input = TrashFixture.input()
        var diary = TrashFixture.diary()
        diary.isPrivate = true
        diary.tagIDs = TagIDList.encode([TodoQueryFixture.work])
        input.diaries = [diary]
        input.privacy = .init(tagNames: TodoQueryFixture.names, privateTagIDs: [])
        #expect(TrashQueryFixture.read("/trash #工作", input).definiteMatchCount == 1)
        #expect(TrashQueryFixture.read("/trash -#学习", input).definiteMatchCount == 1)
        diary.tagIDs = "malformed-uuid"
        input.diaries = [diary]
        let session = TodoQueryFixture.add(.page(.noTags), to: TodoQueryFixture.session("/trash"))
        let result = TrashQueryFixture.read(session, input)
        #expect(result.matches.isEmpty && result.undeterminedObjects == [TrashFixture.ref(.diary)])
        #expect(result.diagnostics.contains { $0.issue == .invalidField })
    }

    @Test func sameRequestRebuildsParentAndProtectionInsteadOfReusingOldFacts() {
        var input = TrashFixture.family()
        #expect(TrashQueryFixture.read("/trash date:2026-10-02", input).definiteMatchCount == 3)
        input.todos?[0].dayKey = "2026-10-03"
        input.images?[0].protection = .protected
        let result = TrashQueryFixture.read("/trash date:2026-10-02", input)
        #expect(result.matches.isEmpty && result.undeterminedObjects.isEmpty)
        #expect(!TrashQueryFixture.strings(result).contains(TrashFixture.imageID.uuidString))
    }

    @Test func invalidRelationCoverageNeverCreatesCascadeOrParentEvidence() {
        var input = TrashFixture.family()
        input.coverage.members[.init(parent: TrashFixture.ref(.todo), memberType: .subtask)] = .invalid
        let result = TrashQueryFixture.read("/trash", input)
        #expect(result.visibleGroupCount == 2)
        #expect(result.matches.first { $0.id.type == .subtask }?.object.parentAttributes == nil)
    }
}
