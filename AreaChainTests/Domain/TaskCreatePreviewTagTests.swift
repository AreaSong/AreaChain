import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TaskCreatePreviewTagTests {
    typealias Fixture = TaskCreatePreviewFixture

    @Test func liveRestoredAndNewTagsAreDistinctPlans() throws {
        let live = Fixture.record("Work")
        let deleted = Fixture.record("归档", deleted: true)
        let result = try Fixture("任务 #work #归档 #新建", records: [live, deleted]).preview()
        #expect(result.canPrepareExecution)
        #expect(result.composition.tags.final.map(\.effect) == [.associateLive, .restoreAndAssociate, .createAndAssociate])
        #expect(result.composition.tags.final.map(\.target) == [.existing(live), .existing(deleted), .newName("新建", normalized: "新建")])
    }

    @Test(arguments: [CommandFieldOperation.add, .remove, .replaceAll, .clear])
    func tagOperationsApplyAfterSyntax(operation: CommandFieldOperation) throws {
        let first = Fixture.record("一")
        let second = Fixture.record("二", deleted: true)
        let third = Fixture.record("三")
        let explicit = [try #require(first.id), try #require(third.id)]
        let result = try Fixture("任务 #一 #二 #新建", extra: [Fixture.tags(operation, explicit)],
                                 records: [first, second, third]).preview().composition.tags
        switch operation {
        case .add:
            #expect(result.final.map(\.target) == [.existing(first), .existing(second), .newName("新建", normalized: "新建"), .existing(third)])
            #expect(result.noEffects == [.alreadyAssociated(.existing(first))])
            #expect(result.final[0].origins == [.titleSyntax, .explicitIDs])
        case .remove:
            #expect(result.final.map(\.target) == [.existing(second), .newName("新建", normalized: "新建")])
            #expect(result.removed == [.existing(first)] && result.noEffects == [.notAssociated(.existing(third))])
        case .replaceAll:
            #expect(result.final.map(\.target) == [.existing(first), .existing(third)])
            #expect(result.removed == [.existing(second), .newName("新建", normalized: "新建")])
            #expect(result.final.allSatisfy { $0.effect == .associateLive })
        case .clear:
            #expect(result.final.isEmpty && result.removed.count == 3)
        default: Issue.record("意外操作")
        }
    }

    @Test func removalDoesNotRestoreAndNoOpsDoNotInventInheritedTags() throws {
        let deleted = Fixture.record("墓碑", deleted: true)
        let id = try #require(deleted.id)
        let removed = try Fixture("任务 #墓碑", extra: [Fixture.tags(.remove, [id])], records: [deleted]).preview()
        #expect(removed.composition.tags.final.isEmpty && removed.composition.tags.removed == [.existing(deleted)])
        let absent = try Fixture(extra: [Fixture.tags(.remove, [id])], records: [deleted]).preview()
        #expect(absent.composition.tags.final.isEmpty && absent.composition.tags.noEffects == [.notAssociated(.existing(deleted))])
        let empty = try Fixture(extra: [Fixture.tags(.clear)]).preview()
        #expect(empty.canPrepareExecution && empty.composition.tags.noEffects == [.empty])
    }

    @Test(arguments: [CommandFieldOperation.add, .remove, .replaceAll, .clear])
    func protectedSyntaxCannotBeErasedToOrdinary(operation: CommandFieldOperation) throws {
        let privateTag = Fixture.record("私有", privateTag: true)
        let ordinary = Fixture.record("普通")
        for title in ["任务 #私有", "任务 #密码", "任务 #日记", "任务 #小巧思"] {
            let result = try Fixture(title, extra: [Fixture.tags(operation, [#require(ordinary.id)])],
                                     records: [privateTag, ordinary]).preview()
            #expect(!result.canPrepareExecution && result.composition.tags.problems.map(\.kind) == [.protectedTag])
        }
    }

    @Test func explicitPrivatePresetMissingAndUnknownFactsAreRejected() throws {
        let rows = [Fixture.record("私有", privateTag: true), Fixture.record("密码"),
                    Fixture.record("未知保护", privateTag: nil),
                    CommandTaskTagRecord(id: UUID(), name: "未知状态", state: .unknown, isPrivateDiary: false)]
        for row in rows {
            let result = try Fixture(extra: [Fixture.tags(.add, [#require(row.id)])], records: [row]).preview()
            #expect(!result.canPrepareExecution && result.composition.tags.final.isEmpty)
        }
        let missing = try Fixture(extra: [Fixture.tags(.add, [UUID()])], records: [Fixture.record("任意名字")]).preview()
        #expect(missing.composition.tags.problems.map(\.kind) == [.missingID])
        #expect(missing.composition.tags.final.isEmpty && !missing.canPrepareExecution)
    }

    @Test func duplicateIDsAndNormalizedNamesNeverUseFirstMatch() throws {
        let live = Fixture.record("WORK")
        let cases: [([CommandTaskTagRecord], CommandTaskTagProblem.Kind)] = [
            ([live, Fixture.record("work", deleted: true)], .ambiguousName),
            ([live, Fixture.record("另一个", id: try #require(live.id))], .duplicateID),
            ([live, live], .ambiguousName)
        ]
        for (rows, kind) in cases {
            let result = try Fixture("任务 #work", extra: [Fixture.tags(.clear)], records: rows).preview()
            #expect(!result.canPrepareExecution && result.composition.tags.problems.first?.kind == kind)
            let selected = try Fixture(extra: [Fixture.tags(.add, [#require(live.id)])], records: rows).preview()
            #expect(!selected.canPrepareExecution && selected.composition.tags.final.isEmpty)
        }
    }

    @Test func incompleteCatalogAndMissingIdentityOrNameBlockEvenClear() throws {
        let fixture = try Fixture("任务 #新建", extra: [Fixture.tags(.clear)])
        for coverage in [CommandTaskTagCatalog.Coverage.partial, .unavailable] {
            let result = try fixture.preview(catalog: fixture.replacingCatalog(coverage: coverage))
            #expect(!result.canPrepareExecution && result.composition.tags.problems.map(\.kind) == [.incompleteCatalog])
        }
        for row in [CommandTaskTagRecord(id: nil, name: "缺身份", state: .live, isPrivateDiary: false),
                    CommandTaskTagRecord(id: UUID(), name: nil, state: .live, isPrivateDiary: false)] {
            let result = try fixture.preview(catalog: fixture.replacingCatalog(records: [row]))
            #expect(!result.canPrepareExecution && result.composition.tags.problems.map(\.kind) == [.incompleteRecord])
        }
    }
}
