import Foundation
import Testing
@testable import AreaChain

struct TrashTombstoneCoverageTests {
    private typealias Fixture = TrashFixture

    @Test func missingNotProvidedPartialAndInvalidParentsAreDifferentFacts() {
        let cases: [(TrashReadCompleteness, TrashTombstoneIssue)] = [
            (.completeIncludingDeleted, .parentMissing), (.notProvided, .parentNotProvided),
            (.partial, .parentPartial), (.invalid, .parentInvalid)
        ]
        for (coverage, issue) in cases {
            var input = Fixture.family()
            input.todos = []
            input.coverage.types[.todo] = coverage
            let child = TrashTombstoneReader.read(input).objects.first { $0.id.type == .subtask }
            #expect(child?.relation == .unresolved(parent: Fixture.ref(.todo), issue: issue))
        }
        var absent = Fixture.family()
        absent.todos = nil
        let result = TrashTombstoneReader.read(absent)
        #expect(result.objects.allSatisfy {
            $0.relation == .unresolved(parent: Fixture.ref(.todo), issue: .parentNotProvided)
        })
        #expect(result.typeCoverage[.todo] == .notProvided)
    }

    @Test func perObjectCoverageOverridesWholeType() {
        var input = Fixture.family()
        input.coverage.objects[Fixture.ref(.todo)] = .partial
        let result = TrashTombstoneReader.read(input)
        #expect(!result.objects.contains { $0.id.type == .todo })
        #expect(result.visibleMemberCount == 0)
        #expect(result.objects.allSatisfy { $0.relation == .unresolved(parent: Fixture.ref(.todo), issue: .parentPartial) })
        input.coverage.types[.todo] = .partial
        input.coverage.objects[Fixture.ref(.todo)] = .completeIncludingDeleted
        #expect(TrashTombstoneReader.read(input).visibleMemberCount == 2)
    }

    @Test func duplicateLiveAndDeletedIdentitiesAreQuarantinedAcrossEveryKind() {
        var input = Fixture.family()
        input.todos?.append(Fixture.todo(deleted: nil))
        input.subtasks?.append(Fixture.child(deleted: nil))
        input.routines = [Fixture.routine(), Fixture.routine(deleted: nil)]
        input.diaries = [Fixture.diary(), Fixture.diary(deleted: nil)]
        input.tags = [.init(id: Fixture.parentID, name: "墓碑", deletedAt: Fixture.date), .init(id: Fixture.parentID, name: "活项")]
        input.images?.append(Fixture.image(deleted: nil))
        let result = TrashTombstoneReader.read(input)
        #expect(result.objects.isEmpty)
        #expect(result.diagnostics.filter { $0.issue == .duplicateIdentity }.count == 6)
    }

    @Test func ambiguousParentAndImageOwnershipNeverChooseFirst() {
        var input = Fixture.family()
        input.todos?.append(Fixture.todo(deleted: nil))
        let result = TrashTombstoneReader.read(input)
        #expect(result.objects.allSatisfy { $0.relation == .unresolved(parent: Fixture.ref(.todo), issue: .parentAmbiguous) })
        #expect(result.objects.first { $0.id.type == .image }?.restoration.independent == .undetermined)
        input = Fixture.family()
        input.images?.append(Fixture.image(parent: Fixture.otherID))
        let duplicate = TrashTombstoneReader.read(input)
        #expect(!duplicate.objects.contains { $0.id.type == .image })
        #expect(duplicate.diagnostics.contains { $0.issue == .duplicateIdentity && $0.object == Fixture.ref(.image, Fixture.imageID) })
    }

    @Test func embeddedSubtasksUseActualTodoIDAndNeverTrustTheirContainer() {
        var input = Fixture.input()
        var todo = Fixture.todo()
        todo.subtasks = [Fixture.child(parent: Fixture.otherID)]
        input.todos = [todo, Fixture.todo(Fixture.otherID)]
        let result = TrashTombstoneReader.read(input)
        #expect(!result.objects.contains { $0.id.type == .subtask })
        #expect(result.diagnostics.contains { $0.issue == .invalidSubtaskContainer })
        #expect(result.visibleMemberCount == 0)
        todo.subtasks = [Fixture.child()]
        input.todos = [todo]
        #expect(TrashTombstoneReader.read(input).visibleMemberCount == 1)
        input.subtasks = [Fixture.child()]
        #expect(TrashTombstoneReader.read(input).diagnostics.contains { $0.issue == .duplicateIdentity })
    }

    @Test func nonFiniteDeletedDatesAreNotNormalizedOrGrouped() {
        for seconds in [Double.nan, .infinity, -.infinity] {
            var input = Fixture.family()
            input.todos = [Fixture.todo(deleted: Date(timeIntervalSince1970: seconds))]
            let result = TrashTombstoneReader.read(input)
            #expect(!result.objects.contains { $0.id.type == .todo })
            #expect(result.diagnostics.contains { $0.issue == .invalidDeletedAt })
            #expect(result.objects.allSatisfy { $0.relation == .unresolved(parent: Fixture.ref(.todo), issue: .parentInvalid) })
            input = Fixture.family()
            input.subtasks = [Fixture.child(deleted: Date(timeIntervalSince1970: seconds))]
            #expect(!TrashTombstoneReader.read(input).objects.contains { $0.id.type == .subtask })
        }
    }

    @Test func partialEnumerationDoesNotClaimThereAreNoOtherChildren() {
        var input = Fixture.input()
        input.todos = [Fixture.todo()]
        input.coverage.types[.subtask] = .partial
        let parent = Fixture.ref(.todo)
        var result = TrashTombstoneReader.read(input)
        #expect(result.groups[0].visibleMemberCount == 0)
        #expect(result.groups[0].subtaskRead == .partial)
        input.coverage.members[.init(parent: parent, memberType: .subtask)] = .completeIncludingDeleted
        input.subtasks = [Fixture.child()]
        // 读全某父的子项不证明子 ID 在别的父项下没有重复。
        result = TrashTombstoneReader.read(input)
        #expect(result.groups[0].subtaskRead == .partial)
        #expect(result.diagnostics.contains { $0.issue == .identityPartial })
        input.coverage.objects[Fixture.ref(.subtask, Fixture.childID)] = .completeIncludingDeleted
        result = TrashTombstoneReader.read(input)
        #expect(result.groups[0].subtaskRead == .completeIncludingDeleted)
        #expect(result.groups[0].visibleMemberCount == 1)
        input.coverage.members[.init(parent: parent, memberType: .subtask)] = .partial
        #expect(TrashTombstoneReader.read(input).groups[0].subtaskRead == .partial)
    }

    @Test func malformedOwnerIsNotRepairedFromUUID() {
        var input = Fixture.family()
        input.images?[0].ownerKind = "subtask"
        let result = TrashTombstoneReader.read(input)
        #expect(!result.objects.contains { $0.id.type == .image })
        #expect(result.diagnostics.contains { $0.issue == .unknownOwnerKind && $0.object == nil })
    }

    @Test func imageEnumerationAndProtectedDisplayHaveSeparateCompleteness() {
        for state in [TrashReadCompleteness.notProvided, .partial, .completeIncludingDeleted, .invalid] {
            var input = Fixture.family()
            input.coverage.members[.init(parent: Fixture.ref(.todo), memberType: .image)] = state
            let group = TrashTombstoneReader.read(input).groups[0]
            #expect(group.imageInputRead == state)
            #expect(group.imageRead == .displayLimited)
            if state == .invalid {
                let image = TrashTombstoneReader.read(input).objects.first { $0.id.type == .image }
                #expect(image?.relation == .unresolved(parent: Fixture.ref(.todo), issue: .invalidCoverage))
                #expect(image?.restoration.independent == .undetermined)
                #expect(!group.members.contains(Fixture.ref(.image, Fixture.imageID)))
            }
        }
        var input = Fixture.family()
        input.images = nil
        #expect(TrashTombstoneReader.read(input).groups[0].imageInputRead == .notProvided)
    }

    @Test func invalidTimestampIsDiagnosedForAllTombstoneTypes() {
        var input = Fixture.family()
        let invalid = Date(timeIntervalSince1970: .infinity)
        input.todos?[0].deletedAt = invalid
        input.subtasks?[0].deletedAt = invalid
        input.routines = [Fixture.routine(deleted: invalid)]
        input.diaries = [Fixture.diary(deleted: invalid)]
        input.tags = [.init(id: Fixture.parentID, name: "合成", deletedAt: invalid)]
        input.images?[0].deletedAt = invalid
        let result = TrashTombstoneReader.read(input)
        #expect(result.objects.isEmpty)
        #expect(result.diagnostics.filter { $0.issue == .invalidDeletedAt }.count == 6)
    }

    @Test func invalidSubtaskAssociationDoesNotOverrideKnownIdentityOrInferCascade() {
        var input = Fixture.family()
        input.coverage.members[.init(parent: Fixture.ref(.todo), memberType: .subtask)] = .invalid
        let result = TrashTombstoneReader.read(input)
        let child = result.objects.first { $0.id.type == .subtask }
        #expect(child?.relation == .unresolved(parent: Fixture.ref(.todo), issue: .invalidCoverage))
        #expect(child?.restoration.mayRestoreWithParent == nil)
        #expect(result.groups[0].subtaskRead == .invalid)
        #expect(result.visibleTopLevelCount == 2)
    }
}
