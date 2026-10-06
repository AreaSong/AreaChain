import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TaskCreateCompositionBoundaryTests {
    typealias Fixture = TaskCreateCompositionFixture

    @Test(arguments: [0, 1, 2, 3])
    func conflictingPriorityOrReminderCannotBeAccepted(kind: Int) throws {
        let fixture = try Fixture()
        let arguments: [CommandArgument] = [
            .init(parameter: .priority, operation: .assign, value: .choice("p1")),
            .init(parameter: .priority, operation: .clear),
            .init(parameter: .time, operation: .setReminder, value: .time(600)),
            .init(parameter: .time, operation: .cancelReminder)
        ]
        let preview = try fixture.preview("任务 #新建 !p2 @08:30", extra: [arguments[kind]])
        #expect(preview.transactionPlan == nil)
        #expect(throws: TaskCreateCommandIssue.invalidInput) { try fixture.accept(preview) }
        #expect(try fixture.tags().isEmpty && !fixture.context.hasChanges)
        #expect(fixture.handoff.coordinator.taskCreations.preparations.isEmpty)
        try fixture.expectNoCommandWrites()
    }

    @Test(arguments: [0, 1, 2, 3, 4])
    func protectedAmbiguousDuplicateAndMissingTagsRejectedEvenWhenCleared(kind: Int) throws {
        let fixture = try Fixture()
        var name = "测试"
        var extra = [CommandArgument(parameter: .tags, operation: .clear)]
        switch kind {
        case 0: try fixture.seed(name, privateTag: true)
        case 1: name = DiaryMemoTags.presets[0]
        case 2: try fixture.seed(name); try fixture.seed(name, deleted: true)
        case 3:
            let row = try fixture.seed(name)
            try fixture.seed("另名", deleted: true, id: row.id)
        default: extra = [TaskCreatePreviewFixture.tags(.add, [UUID()])]
        }
        let preview = try fixture.preview("任务 #\(name)", extra: extra)
        #expect(!preview.composition.tags.problems.isEmpty)
        #expect(throws: TaskCreateCommandIssue.invalidInput) { try fixture.accept(preview) }
        #expect(!fixture.context.hasChanges)
        try fixture.expectNoCommandWrites()
    }

    @Test(arguments: [0, 1, 2, 3, 4, 5])
    func notesAndUnsupportedMetadataStayClosed(kind: Int) throws {
        let fixture = try Fixture()
        let titles = ["任务\n备注", "任务//备注", "任务／／备注", "任务", "", "!p4"]
        let extra: [CommandArgument] = kind == 3 ? [.init(parameter: .notes, operation: .unspecified)] : []
        do {
            let preview = try fixture.preview(titles[kind], extra: extra)
            #expect(preview.transactionPlan == nil)
            #expect(throws: TaskCreateCommandIssue.invalidInput) { try fixture.accept(preview) }
        } catch { #expect(error is CommandTaskCreatePreviewIssue || error is TaskCreateCommandIssue) }
        try fixture.expectNoCommandWrites()
    }

    @Test(arguments: [0, 1, 2, 3, 4, 5, 6])
    func acceptedCatalogChangesExpireWithoutWrites(kind: Int) throws {
        let fixture = try Fixture()
        let tombstone = try fixture.seed("墓碑", deleted: true)
        let preview = try fixture.preview("任务 #墓碑 #新建")
        let accepted = try fixture.accept(preview)
        switch kind {
        case 0: tombstone.name = "改名"
        case 1: tombstone.deletedAt = nil
        case 2: tombstone.isPrivateDiary = true
        case 3: fixture.context.insert(TagItem(name: "新建", sortOrder: 2))
        case 4: tombstone.id = UUID()
        case 5:
            tombstone.name = "中间名"
            try fixture.context.save()
            tombstone.name = "墓碑"
        default: tombstone.name = DiaryMemoTags.presets[0]
        }
        try fixture.context.save()
        #expect(throws: TaskCreateCommandIssue.stale) { try fixture.submit(accepted) }
        #expect(fixture.handoff.coordinator.taskCreations.preparations[accepted.draft.draftID] == accepted)
        #expect(try fixture.handoff.state().execution == nil && !fixture.context.hasChanges)
        try fixture.expectNoCommandWrites()
    }

    @Test(arguments: [0, 1, 2, 3])
    func parametersSourceLeaseAndNewReadExpireAcceptance(kind: Int) throws {
        let fixture = try Fixture()
        let preview = try fixture.preview()
        let accepted = try fixture.accept(preview)
        switch kind {
        case 0: try fixture.edit(.init(parameter: .title, operation: .assign, value: .shortText("另一任务 #新建")))
        case 1: fixture.base.io.capture.source = "qa.changed"
        case 2: try fixture.handoff.send(.query(.setInput("合成查询")))
        default:
            _ = try fixture.adapter.preview(plan: fixture.handoff.state().plan.stamp, expecting: fixture.handoff.owned().lease)
        }
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        #expect(try fixture.tags().isEmpty)
        try fixture.expectNoCommandWrites()
    }

    @Test(arguments: [0, 1, 2])
    func forgedFactsIncompleteCoverageOrForeignHostCannotSupplyPreview(kind: Int) throws {
        let fixture = try Fixture()
        _ = try fixture.preview()
        let real = try fixture.environment.tagCatalog.current()
        let catalog = CommandTaskTagCatalog(directoryID: real.directoryID, readID: real.readID, revision: real.revision,
            coverage: kind == 1 ? .partial : .complete,
            records: kind == 0 ? [TaskCreatePreviewFixture.record("新建")] : real.records)
        let foreign = try TaskCreatePreviewFixture("伪造标题 #新建")
        let host = try kind == 2 ? foreign.handoff.owned() : fixture.handoff.owned()
        let forged = try CommandTaskCreatePreview.prepare(in: host, source: fixture.environment.source(), catalog: catalog)
        #expect(throws: (any Error).self) { try fixture.accept(forged) }
        #expect(fixture.handoff.coordinator.taskCreations.preparations.isEmpty)
        try fixture.expectNoCommandWrites()
    }

    @Test(arguments: [false, true])
    func dirtyContextRejectedBeforePreSaveAndOriginalEditingPreserved(atTransaction: Bool) throws {
        let fixture = try Fixture()
        let tag = try fixture.seed("原标签")
        let preview = try fixture.preview()
        let accepted = try fixture.accept(preview)
        if atTransaction {
            let request = try fixture.base.request()
            fixture.base.io.beforeTransaction = { tag.name = "未保存编辑" }
            let facts = try fixture.adapter.execute(request)
            #expect(facts.state == .notSubmitted && facts.save == .notCalled && facts.rollback == .notCalled)
        } else {
            tag.name = "未保存编辑"
            #expect(throws: TaskCreateCommandIssue.dirtyContext) { try fixture.submit(accepted) }
        }
        #expect(fixture.context.hasChanges && tag.name == "未保存编辑")
        #expect(try fixture.tags().first?.name == "原标签")
        try fixture.expectNoCommandWrites()
    }
}
