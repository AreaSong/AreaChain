import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct TaskCopyCommandTests {
    @Test(arguments: [TaskCopySection?.none, .record, .title, .notes])
    func copiesTheSharedRuleTextWithoutTouchingData(section: TaskCopySection?) throws {
        let f = try TaskCopyCommandFixture()
        let before = f.todo.snapshot
        try f.start(section)
        let preview = try f.preview()
        #expect(f.writer.writes.isEmpty)
        let expected = TaskCopyContent.text(section ?? .record, title: f.todo.title, notes: TaskCopyContent.notes(f.todo.notes))
        #expect(preview.text == expected && preview.section == (section ?? .record))
        let result = try f.submit(preview)
        #expect(f.writer.writes == [expected])
        #expect(result.characters == expected?.count && result.target == f.target)
        // 不建 Run、不改数据、不入撤销、不发布。
        #expect(f.todo.snapshot == before && !f.io.context.hasChanges)
        #expect(try f.handoff.state().execution == nil && f.handoff.state().plan.items.isEmpty)
        #expect(f.io.trace.isEmpty)
    }

    @Test func recordWithoutNotesIsTitleOnlyAndNotesModeRefuses() throws {
        let f = try TaskCopyCommandFixture(notes: " \n ")
        try f.start(.record)
        #expect(try f.submit(f.preview()) == .init(draft: f.handoff.state().operations.active!.stamp,
                                                    target: f.target, section: .record, characters: f.todo.title.count))
        #expect(f.writer.writes == [f.todo.title])
        let g = try TaskCopyCommandFixture(notes: "")
        try g.start(.notes)
        #expect(throws: TaskCopyCommandIssue.notesEmpty) { try g.preview() }
        #expect(g.writer.writes.isEmpty)
    }

    @Test func writeFailureIsReportedAndNothingIsClaimed() throws {
        let f = try TaskCopyCommandFixture()
        try f.start(.title)
        let preview = try f.preview()
        f.writer.fails = true
        #expect(throws: TaskCopyCommandIssue.writeFailed) { try f.submit(preview) }
        #expect(f.writer.writes.isEmpty)
        f.writer.fails = false
        #expect(try f.submit(preview).section == .title && f.writer.writes == [f.todo.title])
    }

    @Test func staleTargetChangedContentAndDeletedTargetAreRejected() throws {
        let f = try TaskCopyCommandFixture()
        try f.start(.record)
        let preview = try f.preview()
        f.todo.title = "外部改名"
        try f.io.context.save()
        #expect(throws: TaskCopyCommandIssue.changed) { try f.submit(preview) }
        let fresh = try f.preview()
        f.todo.deletedAt = Date(timeIntervalSince1970: 1)
        try f.io.context.save()
        #expect(throws: TaskCopyCommandIssue.deleted) { try f.submit(fresh) }
        #expect(throws: TaskCopyCommandIssue.deleted) { try f.preview() }
        #expect(f.writer.writes.isEmpty)
    }

    @Test func sectionEditInvalidatesPreviewAndDirtyContextBlocks() throws {
        let f = try TaskCopyCommandFixture()
        try f.start(.title)
        let preview = try f.preview()
        let draft = try #require(f.handoff.state().operations.active)
        try f.handoff.send(.operation(.edit(draft.stamp, .init(parameter: .section, operation: .assign, value: .choice("notes")))))
        #expect(throws: TaskCopyCommandIssue.self) { try f.submit(preview) }
        f.todo.title = "未保存"
        #expect(throws: TaskTitleCommandIssue.dirtyContext) { try f.preview() }
        f.io.context.rollback()
        #expect(f.writer.writes.isEmpty)
    }

    @Test func ineligibleSourcesAndShapesAreRejected() throws {
        let f = try TaskCopyCommandFixture()
        try f.start(.record)
        f.source = .init(revision: UUID(), protection: .required)
        #expect(throws: TaskCopyCommandIssue.protectedContent) { try f.preview() }
        // 备注证明由适配自读；没有协调者密钥即无法证明。
        f.source = .init(revision: UUID(), protection: .ordinary)
        let key = f.adapter.environment?.notesKey
        f.adapter.environment?.notesKey = nil
        #expect(throws: TaskCopyCommandIssue.notesUnverified) { try f.preview() }
        f.adapter.environment?.notesKey = key
        f.sourceRead = { throw TaskCreateCommandIO.Failure.injected }
        #expect(throws: TaskCopyCommandIssue.sourceUnavailable) { try f.preview() }
        let g = try TaskCopyCommandFixture()
        try g.start(.record, targets: [.init(type: .routine, id: g.todo.id)])
        // 目录层的目标类型校验先拒绝；与 invalidTarget 共用同一输入提示。
        #expect(throws: TaskCopyCommandIssue.invalidArguments) { try g.preview() }
        #expect(f.writer.writes.isEmpty && g.writer.writes.isEmpty)
    }

    @Test func unassembledAdapterAndProductionCatalogStayClosed() throws {
        let f = try TaskCopyCommandFixture()
        let closed = TaskCopyCommandAdapter(coordinator: f.handoff.coordinator)
        #expect(!closed.supports(.init(rawValue: "todo.copy")))
        try f.start(.record)
        let draft = try #require(f.handoff.state().operations.active)
        #expect(throws: TaskCopyCommandIssue.unassembled) { try closed.prepare(draft: draft.stamp, expecting: f.handoff.owned().lease) }
        let command = try #require(CommandCatalog.standard.command(id: .init(rawValue: "todo.copy")))
        #expect(!command.interactions.contains(.independentConfirmation) && command.queue == .excluded)
    }
}
