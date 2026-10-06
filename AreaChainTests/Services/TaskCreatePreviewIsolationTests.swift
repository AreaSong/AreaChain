import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TaskCreatePreviewIsolationTests {
    @Test func completePreviewAndInvalidationDoNotWriteModelsOrEvents() throws {
        let fixture = try TaskCreateCommandFixture()
        let context = fixture.io.capture.context
        let live = TagItem(name: "活标签", sortOrder: 0)
        let deleted = TagItem(name: "已删除", sortOrder: 1)
        deleted.deletedAt = Date(timeIntervalSince1970: 100)
        context.insert(live)
        context.insert(deleted)
        try context.save()
        let tags = try context.fetch(FetchDescriptor<TagItem>())
        let catalog = CommandTaskTagCatalog(directoryID: UUID(), readID: UUID(), revision: 0, coverage: .complete,
                                           records: tags.map {
            .init(id: $0.id, name: $0.name, state: $0.deletedAt.map(CommandTaskTagRecord.State.deleted) ?? .live,
                  isPrivateDiary: $0.isPrivateDiary)
        })
        let source = CommandTaskCreateSource(protection: .ordinary, stampEnabled: false, bundleID: "")
        try fixture.queue(TaskCreateCommandFixture.arguments("任务 #活标签 #已删除 #新建 !p2 @08:30"))
        let host = try fixture.handoff.owned()
        let before = try counts(context)
        #expect(!context.hasChanges)
        let result = try CommandTaskCreatePreview.prepare(in: host, source: source, catalog: catalog)
        #expect(result.canPrepareExecution)
        #expect(result.composition.tags.final.map(\.effect) == [.associateLive, .restoreAndAssociate, .createAndAssociate])
        try result.validateCurrent(in: host, source: source, catalog: catalog)
        #expect(try counts(context) == before)
        #expect(!context.hasChanges && deleted.deletedAt == Date(timeIntervalSince1970: 100))
        #expect(context.insertedModelsArray.isEmpty && context.changedModelsArray.isEmpty && context.deletedModelsArray.isEmpty)
        #expect(try fixture.handoff.owned() == host && fixture.handoff.coordinator.taskCreations.preparations.isEmpty)
        #expect(fixture.io.capture.trace.isEmpty && fixture.io.capture.registered.isEmpty && fixture.io.capture.authorizations.isEmpty)
        #expect(fixture.io.notificationProcessed == 0 && fixture.io.calendarProcessed == 0)
        #expect(throws: TaskCreateCommandIssue.invalidInput) { try fixture.prepare() }
        #expect(throws: TaskCreateCommandIssue.invalidInput) { try fixture.submit() }
        #expect(try counts(context) == before && !context.hasChanges && fixture.io.capture.trace.isEmpty)
        // 未保存的外部编辑不被预览保存、回滚或藏到另一个 context。
        live.name = "外部待保存"
        let changed = CommandTaskTagCatalog(directoryID: catalog.directoryID, readID: catalog.readID, revision: catalog.revision,
                                           coverage: .complete, records: [TaskCreatePreviewFixture.record(live.name, id: live.id)])
        #expect(throws: CommandTaskCreatePreviewIssue.stale) { try result.validateCurrent(in: host, source: source, catalog: changed) }
        #expect(context.hasChanges && live.name == "外部待保存" && fixture.io.capture.trace.isEmpty)
    }

    @Test(arguments: [CommandFieldOperation.add, .remove, .replaceAll, .clear])
    func minimalAdapterRejectsEveryExtendedTagMode(operation: CommandFieldOperation) throws {
        let fixture = try TaskCreateCommandFixture()
        try fixture.queue(TaskCreateCommandFixture.arguments() + [TaskCreatePreviewFixture.tags(operation, [UUID()])])
        #expect(throws: TaskCreateCommandIssue.invalidInput) { try fixture.submit() }
        #expect(try fixture.io.capture.readTodos().isEmpty && fixture.io.capture.trace.isEmpty)
    }

    private func counts(_ context: ModelContext) throws -> [Int] {
        try [context.fetchCount(FetchDescriptor<TodoItem>()), context.fetchCount(FetchDescriptor<TagItem>()),
             context.fetchCount(FetchDescriptor<DailyRoutine>()), context.fetchCount(FetchDescriptor<SubtaskItem>()),
             context.fetchCount(FetchDescriptor<RoutineCheck>()), context.fetchCount(FetchDescriptor<DiaryEntry>()),
             context.fetchCount(FetchDescriptor<AttachmentItem>())]
    }
}
