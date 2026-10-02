import Foundation
import Testing
@testable import AreaChain

struct TrashQueryGroupingTests {
    @Test func parentOnlyChildOnlyAndTogetherHaveDistinctCounts() throws {
        let parent = TrashQueryFixture.read("/trash 合成任务")
        #expect(parent.definiteMatchCount == 1 && parent.visibleGroupCount == 1 && parent.visibleContextCount == 2)
        let child = TrashQueryFixture.read("/trash 合成子任务")
        #expect(child.definiteMatchCount == 1 && child.visibleGroupCount == 1 && child.visibleContextCount == 2)
        #expect(child.groups.first?.displayAnchor == TrashFixture.ref(.subtask, TrashFixture.childID))
        #expect(child.groups.first?.source.id == TrashFixture.ref(.todo))
        let both = TrashQueryFixture.read("/trash 合成")
        #expect(both.definiteMatchCount == 2 && both.visibleGroupCount == 1 && both.visibleContextCount == 1)
        let all = TrashQueryFixture.read("/trash")
        #expect(all.definiteMatchCount == 3 && all.visibleGroupCount == 1 && all.visibleContextCount == 0)
        let image = TrashQueryFixture.read("/trash synthetic")
        #expect(image.groups.first?.displayAnchor == TrashFixture.ref(.image, TrashFixture.imageID))
        #expect(try #require(image.matches.first).object.restoration.independent == .requiresLiveOwner(TrashFixture.ref(.todo)))
    }

    @Test func independentDeletionAndUnrelatedTimestampNeverMerge() {
        var input = TrashFixture.family()
        input.subtasks?[0].deletedAt = Date(timeIntervalSince1970: 42)
        input.todos?.append(TrashFixture.todo(TrashFixture.otherID))
        let result = TrashQueryFixture.read("/trash", input)
        #expect(result.definiteMatchCount == 4 && result.visibleGroupCount == 3)
        #expect(result.groups.contains { $0.source.id.type == .subtask && $0.matches.count == 1 })
    }

    @Test func restoredParentStillSuppliesVerifiedDateWithoutBecomingHit() {
        var input = TrashFixture.family()
        input.todos?[0].deletedAt = nil
        let result = TrashQueryFixture.read("/trash date:2026-10-02", input)
        #expect(Set(result.matches.map(\.id.type)) == [.subtask, .image])
        #expect(result.visibleGroupCount == 2 && result.visibleContextCount == 0)
        #expect(result.matches.allSatisfy { $0.object.parentAttributes?.relatedObject == TrashFixture.ref(.todo) })
        #expect(result.matches.first?.object.restoration.mayRestoreWithParent == nil)
    }

    @Test func missingPartialAndDuplicateParentsOnlyBlockParentDependentFields() {
        for mode in 0..<4 {
            var input = TrashFixture.family()
            switch mode {
            case 0: input.todos = nil
            case 1: input.todos = []
            case 2: input.coverage.types[.todo] = .partial
            default: input.todos?.append(TrashFixture.todo())
            }
            let text = TrashQueryFixture.read("/trash 合成子任务", input)
            #expect(text.definiteMatchCount == 1)
            #expect(text.matches.first?.object.parentAttributes == nil)
            #expect(text.matches.first?.object.restoration.independent == .notProvided)
            let date = TrashQueryFixture.read("/trash 合成子任务 date:2026-10-02", input)
            #expect(date.matches.isEmpty)
            #expect(date.undeterminedObjects.contains(TrashFixture.ref(.subtask, TrashFixture.childID)))
        }
    }

    @Test func explicitDeletedSubtasksAndDuplicateIdentitiesAreNotSilentlyDropped() {
        var input = TrashFixture.input()
        var todo = TrashFixture.todo()
        todo.subtasks = [TrashFixture.child()]
        input.todos = [todo]
        #expect(TrashQueryFixture.read("/trash 合成子任务", input).definiteMatchCount == 1)
        input.subtasks = [TrashFixture.child()]
        let duplicate = TrashQueryFixture.read("/trash 合成子任务", input)
        #expect(duplicate.matches.isEmpty)
        #expect(duplicate.undeterminedObjects.contains(TrashFixture.ref(.subtask, TrashFixture.childID)))
        #expect(duplicate.readingDiagnostics.contains { $0.issue == .duplicateIdentity })
    }

    @Test func restorationIsDescriptionOnlyAndResultsKeepDeterministicOrder() {
        let result = TrashQueryFixture.read("/trash", TrashQueryFixture.all())
        #expect(result.matches.map(\.id.type) == [.todo, .subtask, .routine, .diary, .tag, .image])
        #expect(result.matches.allSatisfy { $0.object.restoration.requiresFreshBusinessValidation })
        #expect(result.matches.allSatisfy { !$0.object.restoration.provesFileAvailability })
        #expect(!TrashQueryFixture.strings(result).contains("canRestore"))
        let again = TrashQueryFixture.read("/trash", TrashQueryFixture.all())
        #expect(result.groups == again.groups)
    }
}
