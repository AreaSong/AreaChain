import Foundation
import Testing
@testable import AreaChain

struct TrashTombstoneRelationTests {
    private typealias Fixture = TrashFixture

    @Test func everyKindHasTypedIdentityAndLiveRowsAreExcluded() {
        var input = Fixture.input()
        input.todos = [Fixture.todo(), Fixture.todo(Fixture.otherID, deleted: nil)]
        input.subtasks = [Fixture.child(), Fixture.child(Fixture.otherID, deleted: nil)]
        input.routines = [Fixture.routine(), Fixture.routine(Fixture.otherID, deleted: nil)]
        input.diaries = [Fixture.diary(), Fixture.diary(Fixture.otherID, deleted: nil)]
        input.tags = [.init(id: Fixture.parentID, name: "合成标签", deletedAt: Fixture.date),
                      .init(id: Fixture.otherID, name: "活标签")]
        input.images = [Fixture.image(), Fixture.image(Fixture.otherID, deleted: nil)]
        let result = TrashTombstoneReader.read(input)
        #expect(Set(result.objects.map(\.id.type)) == Set(TrashTombstoneIndex.types))
        #expect(result.objects.count == 6)
        #expect(result.diagnostics.isEmpty)
        #expect(result.visibleTopLevelCount == 4)
        #expect(result.visibleMemberCount == 2)
    }

    @Test func exactFamilyGroupsOnceAndPreservesIndependentSearchTargets() throws {
        let result = TrashTombstoneReader.read(Fixture.family())
        let parent = Fixture.ref(.todo)
        #expect(result.groups.count == 1)
        #expect(result.groups[0].id == parent)
        #expect(result.groups[0].members == [Fixture.ref(.subtask, Fixture.childID), Fixture.ref(.image, Fixture.imageID)])
        #expect(Set(result.objects.map(\.id)).count == 3)
        #expect(result.objects.filter { $0.id != parent }.allSatisfy { $0.relation == .cascaded(parent: parent) })
        let task = try #require(result.objects.first { $0.id == parent })
        guard case .todo(let snapshot) = task.fields else { Issue.record("expected todo fields"); return }
        #expect(snapshot.subtasks.isEmpty)
        #expect(result.groups[0].subtaskRead == .completeIncludingDeleted)
        #expect(result.groups[0].imageRead == .displayLimited)
        #expect(result.countsDescribeVisibleProjectionOnly)
    }

    @Test func olderIndependentDeletionIsNotRecoveredWithParent() throws {
        var input = Fixture.family()
        input.subtasks = [Fixture.child(deleted: Fixture.date.addingTimeInterval(-1))]
        let result = TrashTombstoneReader.read(input)
        let child = try #require(result.objects.first { $0.id.type == .subtask })
        #expect(child.relation == .independent(parent: Fixture.ref(.todo), reason: .timestampsDiffer))
        #expect(child.restoration.independent == .notProvided)
        #expect(child.restoration.mayRestoreWithParent == nil)
        #expect(result.visibleTopLevelCount == 2)
        #expect(result.visibleMemberCount == 1)
    }

    @Test func noToleranceAndNoSameDayApproximation() {
        for delta in [-0.001, 0.001, 60, 86_400] {
            var input = Fixture.family()
            input.subtasks = [Fixture.child(deleted: Fixture.date.addingTimeInterval(delta))]
            let child = TrashTombstoneReader.read(input).objects.first { $0.id.type == .subtask }
            #expect(child?.relation == .independent(parent: Fixture.ref(.todo), reason: .timestampsDiffer))
        }
    }

    @Test func sameTimestampDoesNotCreateAnOwnershipRelation() throws {
        var input = Fixture.family()
        input.todos?.append(Fixture.todo(Fixture.otherID))
        input.subtasks = [Fixture.child(parent: Fixture.otherID)]
        input.images = [Fixture.image(parent: Fixture.otherID)]
        let result = TrashTombstoneReader.read(input)
        #expect(result.groups.first { $0.id == Fixture.ref(.todo) }?.members.isEmpty == true)
        #expect(result.groups.first { $0.id == Fixture.ref(.todo, Fixture.otherID) }?.members.count == 2)
        input.todos = [Fixture.todo()]
        let missing = TrashTombstoneReader.read(input)
        #expect(missing.visibleMemberCount == 0)
        let child = try #require(missing.objects.first { $0.id.type == .subtask })
        #expect(child.relation == .unresolved(parent: Fixture.ref(.todo, Fixture.otherID), issue: .parentMissing))
    }

    @Test func restoredParentCannotKeepCurrentCascadeGroup() {
        var input = Fixture.family()
        input.todos = [Fixture.todo(deleted: nil)]
        let result = TrashTombstoneReader.read(input)
        #expect(result.visibleTopLevelCount == 2)
        #expect(result.visibleMemberCount == 0)
        #expect(result.objects.allSatisfy { $0.relation == .independent(parent: Fixture.ref(.todo), reason: .parentIsLive) })
        #expect(result.objects.allSatisfy { $0.restoration.mayRestoreWithParent == nil })
        #expect(result.objects.first { $0.id.type == .image }?.restoration.independent == .existingEntry)
        #expect(result.objects.first { $0.id.type == .subtask }?.restoration.independent == .notProvided)
    }

    @Test func typedImageOwnersDoNotCrossFillTheSameUUID() {
        var input = Fixture.input()
        input.todos = [Fixture.todo()]
        input.routines = [Fixture.routine(deleted: nil)]
        input.images = [Fixture.image(owner: .routine)]
        let result = TrashTombstoneReader.read(input)
        #expect(result.visibleMemberCount == 0)
        #expect(result.objects.first { $0.id.type == .image }?.relation
            == .independent(parent: Fixture.ref(.routine), reason: .parentIsLive))
        input.routines = []
        let missing = TrashTombstoneReader.read(input).objects.first { $0.id.type == .image }
        #expect(missing?.relation == .unresolved(parent: Fixture.ref(.routine), issue: .parentMissing))
    }

    @Test func routineAndPublicDiaryImagesFollowTheirOwnParent() {
        for owner in [AttachmentOwner.routine, .diary] {
            var input = Fixture.input()
            input.routines = [Fixture.routine()]
            input.diaries = [Fixture.diary()]
            input.images = [Fixture.image(owner: owner)]
            let result = TrashTombstoneReader.read(input)
            let parent = Fixture.ref(owner.commandType)
            let image = result.objects.first { $0.id.type == .image }
            #expect(image?.relation == .cascaded(parent: parent))
            #expect(image?.restoration.independent == .requiresLiveOwner(parent))
            #expect(image?.restoration.mayRestoreWithParent == parent)
        }
    }

    @Test func orderIsStableAcrossInputPermutations() {
        var input = Fixture.family()
        input.todos?.append(Fixture.todo(Fixture.otherID))
        let first = TrashTombstoneReader.read(input)
        input.todos?.reverse()
        #expect(TrashTombstoneReader.read(input) == first)
    }
}
