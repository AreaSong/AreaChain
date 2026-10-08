import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TaskTitlePreviewTests {
    @Test func previewHasExactImpactAndNeverWrites() throws {
        let fixture = try TaskTitleFixture()
        try fixture.queue("新标题 #Work #恢复 #新 !p3 @18:00")
        let host = try fixture.handoff.owned()
        let before = try fixture.fields()
        let preview = try fixture.preview()
        #expect(!preview.isExecutable)
        #expect(preview.impact.edit.title == "新标题" && preview.impact.edit.notes == nil)
        #expect(preview.impact.writeFields == [.title, .tagIDs, .isImportant, .isUrgent, .remindMinutes])
        #expect(preview.impact.synthesisDependencies == [.tagIDs])
        #expect(Set(preview.impact.originalValues.keys) == preview.impact.writeFields)
        #expect(preview.impact.tags.syntax.final.map(\.effect) == [.associateLive, .restoreAndAssociate, .createAndAssociate])
        #expect(preview.impact.tags.sideEffects.map(\.effect) == [.restoreAndAssociate, .createAndAssociate])
        #expect(preview.impact.tags.final.count == 3 && preview.impact.tags.finalEncodedIDs == nil)
        #expect(preview.baseline.original(.title, targets: host.session.plan.items[0].draft.targets) == .uniform(.shortText("原标题")))
        #expect(preview.baseline.original(.notes, targets: host.session.plan.items[0].draft.targets) == nil)
        _ = try fixture.validate(preview)
        #expect(try fixture.fields() == before)
        #expect(try fixture.handoff.owned() == host)
        #expect(!fixture.io.context.hasChanges && fixture.io.context.insertedModelsArray.isEmpty)
        #expect(fixture.io.context.changedModelsArray.isEmpty && fixture.io.context.deletedModelsArray.isEmpty)
        #expect(fixture.io.trace.isEmpty && fixture.io.registered.isEmpty && fixture.io.authorizations.isEmpty)
        #expect(fixture.deleted.deletedAt == TaskTitleFixture.deletion)
    }

    @Test(arguments: ["#Work", "!p1", "@18:00", "#新 !p1 @18:00"])
    func metadataCannotReplaceNonemptyTitle(text: String) throws {
        let fixture = try TaskTitleFixture()
        try fixture.queue(text)
        #expect(throws: CommandTaskTitlePreviewIssue.emptyTitle) { try fixture.preview() }
        #expect(!fixture.io.context.hasChanges && fixture.todo.title == "原标题")
    }

    @Test(arguments: ["标题 // 正文", "标题 ／／ 正文", "标题 //", "标题\n正文", "标题\r正文", "标题\u{2028}正文"])
    func notesAndMultilineCannotBypassShortTextGate(text: String) throws {
        let fixture = try TaskTitleFixture()
        try fixture.queue(text)
        #expect(throws: CommandTaskTitlePreviewIssue.self) { try fixture.preview() }
        #expect(!fixture.io.context.hasChanges && fixture.io.trace.isEmpty)
    }

    @Test func notesParameterAndLongTextBaselineStayBlocked() throws {
        let parameter = try TaskTitleFixture()
        try parameter.queue("标题", extra: [.init(parameter: .notes, operation: .clear)])
        #expect(throws: CommandTaskTitlePreviewIssue.notesNotSupported) { try parameter.preview() }
        let long = try TaskTitleFixture()
        let baseline = CommandDraftBaseline([.init(subject: .object(.init(type: .todo, id: long.todo.id)),
                                                   parameter: .notes): .uniform(.longText(""))])
        // 原计划可保留草稿，但不能封存执行；预览也不得通过隐藏基线绕过 C2B。
        try long.queue("标题", baseline: baseline)
        #expect(throws: CommandTaskTitlePreviewIssue.notesNotSupported) { try long.preview() }
        #expect(throws: CommandPlanError.protectedContent) { try long.handoff.seal() }
        let edit = try #require(TaskTitleEdit("标题 // 会覆盖备注"))
        let tags = try CommandTaskTitleTags.merge(rawIDs: "", title: "标题", catalog: emptyCatalog())
        let impact = CommandTaskTitleImpact(target: .init(type: .todo, id: long.todo.id), edit: edit,
                                           originalValues: [.title: .text("旧"), .tagIDs: .text(""), .notes: .text("原备注")], tags: tags)
        let draft = CommandDraft(id: UUID(), hostID: "qa", commandID: .init(rawValue: "todo.title"), baseline: impact.baseline)
        #expect(draft.blocksUnprotectedExport)
    }

    @Test func omittedFieldsStayLatestAndDoNotConflict() throws {
        let fixture = try TaskTitleFixture()
        try fixture.queue("只改标题")
        let preview = try fixture.preview()
        #expect(preview.impact.writeFields == [.title, .tagIDs])
        fixture.todo.notes = "并发备注"
        fixture.todo.isImportant = false
        fixture.todo.isUrgent = true
        fixture.todo.remindMinutes = 900
        fixture.todo.dayKey = "2026-10-06"
        fixture.todo.isDone = false
        fixture.todo.dueMinutes = 1000
        fixture.todo.sourceBundleID = "qa.latest"
        fixture.todo.calendarEventID = "qa.latest.calendar"
        let current = try fixture.validate(preview)
        #expect(current.followUpContext.dayKey == "2026-10-06" && !current.followUpContext.isDone)
        #expect(current.followUpContext.calendarEventID == "qa.latest.calendar")
        #expect(fixture.io.context.hasChanges && fixture.io.trace.isEmpty)
        try fixture.io.context.save()
        _ = try fixture.validate(preview)
        // 这是旧 UI 兼容调用，不是假装已实现命令执行。
        #expect(fixture.edit("只改标题").saved)
        #expect(fixture.todo.notes == "并发备注" && !fixture.todo.isImportant && fixture.todo.isUrgent)
        #expect(fixture.todo.remindMinutes == 900 && fixture.todo.dueMinutes == 1000)
        #expect(fixture.todo.dayKey == "2026-10-06" && !fixture.todo.isDone)
        #expect(fixture.todo.sourceBundleID == "qa.latest" && fixture.todo.calendarEventID == "qa.latest.calendar")
    }

    @Test(arguments: [TaskTitleField.title, .tagIDs, .isImportant, .isUrgent, .remindMinutes])
    func everyActuallyWrittenFieldHasConflictEvidence(field: TaskTitleField) throws {
        let fixture = try TaskTitleFixture()
        try fixture.queue("新标题 !p3 @18:00")
        let preview = try fixture.preview()
        switch field {
        case .title: fixture.todo.title = "并发标题"
        case .tagIDs: fixture.todo.tagIDs += "," + fixture.live.id.uuidString
        case .isImportant: fixture.todo.isImportant = false
        case .isUrgent: fixture.todo.isUrgent = true
        case .remindMinutes: fixture.todo.remindMinutes = nil
        case .notes: Issue.record("本测试不采样备注")
        }
        #expect(throws: CommandTaskTitlePreviewIssue.stale) { try fixture.validate(preview) }
        #expect(fixture.io.context.hasChanges && fixture.io.trace.isEmpty)
    }

    @Test func rawTagEncodingAndOrderAreRealEffects() throws {
        let fixture = try TaskTitleFixture()
        fixture.todo.tagIDs = "\(fixture.deleted.id),\(fixture.live.id.uuidString.lowercased()),\(fixture.deleted.id)"
        try fixture.io.context.save()
        try fixture.queue("原标题")
        let preview = try fixture.preview()
        #expect(preview.impact.changedFields == [.tagIDs])
        #expect(preview.impact.tags.finalEncodedIDs == TagIDList.encode([fixture.deleted.id, fixture.live.id]))
        #expect(preview.impact.tags.sideEffects.isEmpty)
        #expect(fixture.edit("原标题").saved)
        #expect(fixture.todo.tagIDs == preview.impact.tags.finalEncodedIDs)
        #expect(fixture.deleted.deletedAt == TaskTitleFixture.deletion)
        let normalized = try fixture.preview()
        #expect(normalized.impact.changedFields.isEmpty)
        fixture.todo.tagIDs = TagIDList.encode([fixture.live.id, fixture.deleted.id])
        #expect(throws: CommandTaskTitlePreviewIssue.stale) { try fixture.validate(normalized) }
    }

    @Test func previewAndCompatibilityWriteAgreeOnFinalOrdinaryFields() throws {
        let fixture = try TaskTitleFixture()
        try fixture.queue("预览 #恢复 !p4 @18:00")
        let preview = try fixture.preview()
        #expect(fixture.edit("预览 #恢复 !p4 @18:00").saved)
        #expect(preview.impact.finalValues[.title] == .text(fixture.todo.title))
        #expect(preview.impact.finalValues[.tagIDs] == .text(fixture.todo.tagIDs))
        #expect(preview.impact.finalValues[.isImportant] == .flag(fixture.todo.isImportant))
        #expect(preview.impact.finalValues[.isUrgent] == .flag(fixture.todo.isUrgent))
        #expect(preview.impact.finalValues[.remindMinutes] == .minutes(fixture.todo.remindMinutes))
    }

    private func emptyCatalog() -> CommandTaskTagCatalog {
        .init(directoryID: UUID(), readID: UUID(), revision: 0, coverage: .complete, records: [])
    }
}
