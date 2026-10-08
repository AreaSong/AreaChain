import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TaskTitleCommandBoundaryTests {
    @Test func defaultAssemblyAndDirtyOrNestedContextRejectWithoutTouchingPendingChanges() throws {
        let fixture = try TaskTitleCommandFixture()
        let off = TaskTitleCommandAdapter(coordinator: fixture.handoff.coordinator)
        #expect(!off.supports(.init(rawValue: "todo.title")))
        #expect(throws: TaskTitleCommandIssue.unassembled) {
            try off.prepare(plan: fixture.handoff.state().plan.stamp, expecting: fixture.handoff.owned().lease)
        }
        let preview = try fixture.prepare()
        fixture.base.todo.title = "pending"
        #expect(throws: TaskTitleCommandIssue.dirtyContext) { try fixture.accept(preview) }
        #expect(fixture.base.todo.title == "pending" && fixture.base.io.context.hasChanges && fixture.base.io.trace.isEmpty)
        fixture.base.io.context.rollback()
        try ModelChanges.transaction(in: fixture.base.io.context, boundary: fixture.base.io.boundary) {
            #expect(throws: TaskTitleCommandIssue.nestedTransaction) { try fixture.accept(preview) }
        }
        fixture.base.io.context.autosaveEnabled = true
        #expect(throws: TaskTitleCommandIssue.ineligibleEnvironment) { try fixture.accept(preview) }
        fixture.base.io.context.autosaveEnabled = false
    }

    @Test(arguments: ["title", "tagIDs", "priority", "reminder"])
    func frozenRunReportsExactImpactFieldConflict(field: String) throws {
        let fixture = try TaskTitleCommandFixture()
        let accepted = try fixture.accept(fixture.prepare("新标题 !p3 @18:00"))
        let request = try fixture.request()
        let expected: TaskTitleField
        switch field {
        case "title": fixture.base.todo.title = "他处修改"; expected = .title
        case "tagIDs": fixture.base.todo.tagIDs = ""; expected = .tagIDs
        case "priority": fixture.base.todo.isImportant = false; expected = .isImportant
        default: fixture.base.todo.remindMinutes = 600; expected = .remindMinutes
        }
        try fixture.base.io.context.save()
        #expect(throws: TaskTitleCommandIssue.fieldsChanged([expected])) { try fixture.adapter.execute(request) }
        #expect(try fixture.unit().state == .conflict && fixture.unit().local == .notSubmitted)
        #expect(try fixture.unit().taskTitle?.conflict == .fieldsChanged([expected]))
        #expect(try fixture.handoff.state().execution?.snapshot.items.first?.draft.arguments == accepted.preview.arguments)
        #expect(fixture.base.io.trace.isEmpty && fixture.base.deleted.deletedAt != nil)
    }

    @Test func unrelatedFieldsAndLatestFollowUpArePreservedThroughFinalCallback() throws {
        let fixture = try TaskTitleCommandFixture()
        let accepted = try fixture.accept(fixture.prepare("新标题"))
        fixture.io.beforeTransaction = {
            fixture.base.todo.dayKey = "2026-10-09"
            fixture.base.todo.isDone = false
            fixture.base.todo.calendarEventID = "qa.changed"
            fixture.base.todo.sourceBundleID = "qa.new.source"
            fixture.base.todo.dueMinutes = 900
            fixture.base.todo.sortOrder = 12
            fixture.base.todo.isImportant = false
            fixture.base.todo.remindMinutes = 600
            try fixture.base.io.context.save()
        }
        let facts = try fixture.submit(accepted)
        let todo = try #require(fixture.base.io.readTodos().first)
        #expect(todo.title == "新标题" && todo.dayKey == "2026-10-09" && !todo.isDone && todo.calendarEventID == "qa.changed")
        #expect(todo.sourceBundleID == "qa.new.source" && todo.dueMinutes == 900 && todo.sortOrder == 12)
        #expect(!todo.isImportant && todo.remindMinutes == 600 && todo.notes.isEmpty)
        #expect(facts.followUpContext == .init(dayKey: "2026-10-09", isDone: false, calendarEventID: "qa.changed"))
        #expect(fixture.io.observedContexts == [facts.followUpContext!])
        #expect(fixture.count("save") == 1 && fixture.base.io.authorizations.isEmpty)
    }

    @Test(arguments: ["newName", "restore", "private", "duplicate", "missing", "rename"])
    func acceptedDirectoryChangesCannotSilentlySelectAnotherTag(kind: String) throws {
        let fixture = try TaskTitleCommandFixture()
        let accepted = try fixture.accept(fixture.prepare("新标题 #新 #恢复"))
        let request = try fixture.request()
        switch kind {
        case "newName": fixture.base.io.context.insert(TagItem(name: "新", sortOrder: 2))
        case "restore": fixture.base.deleted.deletedAt = nil
        case "private": fixture.base.live.isPrivateDiary = true
        case "duplicate": fixture.base.io.context.insert(TagItem(id: fixture.base.live.id, name: "另名", sortOrder: 2))
        case "missing": fixture.base.io.context.delete(fixture.base.live)
        default: fixture.base.live.name = "改名"
        }
        try fixture.base.io.context.save()
        #expect(throws: TaskTitleCommandIssue.catalogChanged) { try fixture.adapter.execute(request) }
        #expect(fixture.base.todo.title == "原标题" && fixture.count("save") == 0)
        #expect(try fixture.unit().taskTitle?.conflict == .catalogChanged)
        #expect(try fixture.handoff.coordinator.taskTitles.acceptances[accepted.preview.binding.draft.draftID] == accepted)
    }

    @Test(arguments: ["missing", "deleted", "duplicate"])
    func liveTargetMustRemainUnique(kind: String) throws {
        let fixture = try TaskTitleCommandFixture()
        _ = try fixture.accept(fixture.prepare())
        let request = try fixture.request()
        if kind == "missing" { fixture.base.io.context.delete(fixture.base.todo) }
        if kind == "deleted" { fixture.base.todo.deletedAt = TaskTitleFixture.deletion }
        if kind == "duplicate" {
            fixture.base.io.context.insert(TodoItem(id: fixture.base.todo.id, title: "重复", dayKey: "2026-10-05"))
        }
        try fixture.base.io.context.save()
        let issue: CommandTaskTitlePreviewIssue = kind == "missing" ? .missingTarget : kind == "deleted" ? .deletedTarget : .duplicateTarget
        #expect(throws: issue) { try fixture.adapter.execute(request) }
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
    }

    @Test func acceptanceDoesNotSurviveParameterSourceOrDirectoryReadRevision() throws {
        let fixture = try TaskTitleCommandFixture()
        let accepted = try fixture.accept(fixture.prepare())
        try fixture.base.editArgument(.init(parameter: .title, operation: .assign, value: .shortText("另标题")))
        #expect(throws: TaskTitleCommandIssue.stale) { try fixture.submit(accepted) }
        let current = try fixture.adapter.prepare(plan: fixture.handoff.state().plan.stamp, expecting: fixture.handoff.owned().lease)
        let second = try fixture.accept(current)
        fixture.io.revision = UUID()
        #expect(throws: TaskTitleCommandIssue.sourceChanged) { try fixture.submit(second) }
        #expect(fixture.base.io.trace.isEmpty && fixture.base.todo.title == "原标题")
    }

    @Test(arguments: ["标题 // 备注", "标题 //", "标题\n正文", "#新 !p1 @18:00"])
    func notesDerivedTextAndEmptyParsedTitleNeverEnterTransaction(text: String) throws {
        let fixture = try TaskTitleCommandFixture()
        #expect(throws: CommandTaskTitlePreviewIssue.self) { try fixture.prepare(text) }
        #expect(fixture.base.io.trace.isEmpty && !fixture.base.io.context.hasChanges)
    }

    @Test(arguments: [CommandTaskTitleEligibility.Notes.present, .unknown])
    func missingNoNotesProofRejectsBeforeProjection(notes: CommandTaskTitleEligibility.Notes) throws {
        let fixture = try TaskTitleCommandFixture()
        fixture.io.notes = notes
        #expect(throws: TaskTitleCommandIssue.notesNotSupported) { try fixture.prepare() }
        #expect(fixture.base.io.trace.isEmpty)
    }

    @Test(arguments: [CommandProtectionRequirement.required, .unknown])
    func protectedSourcesAndDraftsAreNeverExported(protection: CommandProtectionRequirement) throws {
        let fixture = try TaskTitleCommandFixture()
        fixture.base.protection = protection
        #expect(throws: CommandTaskTitlePreviewIssue.protectedContent) { try fixture.prepare() }
        let other = try TaskTitleCommandFixture()
        let draft = CommandDraft(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.title"),
            targets: .init(.single, objects: [.init(type: .todo, id: other.base.todo.id)]),
            arguments: [.init(parameter: .title, operation: .assign, value: .shortText("普通标题"))], protectionRequirement: protection)
        try other.handoff.start(draft)
        #expect(try other.handoff.state().operations.allDrafts.isEmpty)
        var plan = CommandPlan(hostID: HandoffFixture.source)
        #expect(throws: CommandPlanError.protectedContent) { try plan.add(draft, id: UUID(), expecting: plan.stamp) }
        #expect(throws: CommandTaskTitlePreviewIssue.protectedContent) {
            try CommandTaskTitlePreview.input(item: .init(id: UUID(), draft: draft), hostID: HandoffFixture.source)
        }
        #expect(other.base.io.trace.isEmpty)
    }

    @Test func createThenTitlePlanRemainsClosedIncludingOutputReference() throws {
        let fixture = try TaskTitleCommandFixture()
        let producer = try fixture.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source,
            commandID: .init(rawValue: "todo.create"), arguments: TaskCreateCommandFixture.arguments()))
        try fixture.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source,
            commandID: .init(rawValue: "todo.title"),
            arguments: [.init(parameter: .title, operation: .assign, value: .shortText("新标题"))]))
        let items = try fixture.handoff.state().plan.items
        let first = try #require(items.first { $0.id == producer })
        let second = try #require(items.last)
        try fixture.handoff.plan(.link(second.stamp, .init(results: [
            .target: .init(producer: first.stamp, outputType: .todo)
        ])))
        #expect(throws: CommandTaskTitlePreviewIssue.unsupportedPlan) {
            try fixture.adapter.prepare(plan: fixture.handoff.state().plan.stamp, expecting: fixture.handoff.owned().lease)
        }
        #expect(throws: TaskCreateCommandIssue.unsupportedPlan) {
            try fixture.handoff.coordinator.taskCreatePlan(fixture.handoff.state().plan.stamp, expecting: fixture.handoff.owned().lease)
        }
        #expect(fixture.count("save") == 0 && fixture.base.todo.title == "原标题")
        #expect(try fixture.base.io.readTodos().count == 1)
    }
}
