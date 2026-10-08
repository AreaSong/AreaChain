import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TaskTitlePreviewBoundaryTests {
    @Test(arguments: [0, 1, 2, 3])
    func missingDeletedAndDuplicateIDsAreExplicitlyRejected(kind: Int) throws {
        let fixture = try TaskTitleFixture()
        try fixture.queue("标题", target: .init(type: .todo, id: kind == 0 ? UUID() : fixture.todo.id))
        if kind == 1 { fixture.todo.deletedAt = TaskTitleFixture.deletion }
        if kind >= 2 {
            fixture.io.context.insert(TodoItem(id: fixture.todo.id, title: "重复", dayKey: "2026-10-05",
                                               deletedAt: kind == 3 ? TaskTitleFixture.deletion : nil))
        }
        let expected: CommandTaskTitlePreviewIssue = kind == 0 ? .missingTarget : (kind == 1 ? .deletedTarget : .duplicateTarget)
        #expect(throws: expected) { try fixture.preview() }
        #expect(fixture.io.trace.isEmpty)
    }

    @Test func sameUUIDInAnotherTypeDoesNotSubstituteForTodo() throws {
        let fixture = try TaskTitleFixture()
        let id = UUID()
        let routine = DailyRoutine(title: "习惯", sortOrder: 0)
        routine.id = id
        fixture.io.context.insert(routine)
        try fixture.queue("标题", target: .init(type: .todo, id: id))
        #expect(throws: CommandTaskTitlePreviewIssue.missingTarget) { try fixture.preview() }
        let wrongType = try TaskTitleFixture()
        try wrongType.queue("标题", target: .init(type: .routine, id: wrongType.todo.id))
        #expect(throws: CommandTaskTitlePreviewIssue.invalidArguments) { try wrongType.preview() }
    }

    @Test(arguments: ["private", "preset", "ambiguous", "duplicate", "missing", "invalid"])
    func existingAssociationsMustHaveKnownOrdinaryQualification(kind: String) throws {
        let fixture = try TaskTitleFixture()
        switch kind {
        case "private": fixture.live.isPrivateDiary = true
        case "preset": fixture.live.name = "日记"
        case "ambiguous": fixture.io.context.insert(TagItem(name: "work", sortOrder: 2))
        case "duplicate": fixture.io.context.insert(TagItem(id: fixture.live.id, name: "另名", sortOrder: 2))
        case "missing": fixture.todo.tagIDs = UUID().uuidString
        default: fixture.todo.tagIDs = "invalid-identity"
        }
        try fixture.queue("没有标签 token 的普通标题")
        #expect(throws: CommandTaskTitlePreviewIssue.self) { try fixture.preview() }
        #expect(fixture.todo.title == "原标题" && fixture.io.trace.isEmpty)
    }

    @Test(arguments: ["标题 #私密", "标题 #日记", "标题 #歧义"])
    func newAssociationCannotBypassD3(title: String) throws {
        let fixture = try TaskTitleFixture()
        let privateTag = TagItem(name: "私密", sortOrder: 2)
        privateTag.isPrivateDiary = true
        fixture.io.context.insert(privateTag)
        fixture.io.context.insert(TagItem(name: "歧义", sortOrder: 3))
        fixture.io.context.insert(TagItem(name: "歧义", sortOrder: 4, deletedAt: TaskTitleFixture.deletion))
        try fixture.io.context.save()
        try fixture.queue(title)
        #expect(throws: CommandTaskTitlePreviewIssue.self) { try fixture.preview() }
        #expect(!fixture.io.context.hasChanges && fixture.io.trace.isEmpty)
    }

    @Test(arguments: ["name", "deleted", "private", "duplicate", "newName", "remove"])
    func directoryFactsInvalidatePreviewEvenWithoutSave(kind: String) throws {
        let fixture = try TaskTitleFixture()
        try fixture.queue("标题 #新 #恢复")
        let preview = try fixture.preview()
        switch kind {
        case "name": fixture.live.name = "改名"
        case "deleted": fixture.deleted.deletedAt = nil
        case "private": fixture.live.isPrivateDiary = true
        case "duplicate": fixture.io.context.insert(TagItem(id: fixture.live.id, name: "另名", sortOrder: 2))
        case "newName": fixture.io.context.insert(TagItem(name: "新", sortOrder: 2))
        default: fixture.io.context.delete(fixture.live)
        }
        #expect(throws: CommandTaskTitlePreviewIssue.self) { try fixture.validate(preview) }
        #expect(fixture.io.context.hasChanges && fixture.io.trace.isEmpty)
    }

    @Test func parametersTargetsSourceAndReadIdentityInvalidate() throws {
        let fixture = try TaskTitleFixture()
        try fixture.queue("标题")
        let first = try fixture.preview()
        try fixture.editArgument(.init(parameter: .title, operation: .assign, value: .shortText("标题")))
        #expect(throws: CommandTaskTitlePreviewIssue.stale) { try fixture.validate(first) }
        let next = try fixture.preview()
        fixture.protection = .unknown
        #expect(throws: CommandTaskTitlePreviewIssue.protectedContent) { try fixture.validate(next) }
        fixture.protection = .ordinary
        _ = try fixture.preview()
        #expect(throws: CommandTaskTitlePreviewIssue.stale) { try fixture.validate(next) }
        let current = try fixture.preview()
        let other = TodoItem(title: "另一个", dayKey: "2026-10-06")
        fixture.io.context.insert(other)
        let item = try #require(fixture.handoff.state().plan.items.first)
        try fixture.handoff.plan(.beginEditing(item.stamp))
        try fixture.handoff.plan(.selectTargets(item.stamp, .init(.single, objects: [.init(type: .todo, id: other.id)])))
        let updated = try #require(fixture.handoff.state().plan.items.first)
        try fixture.handoff.plan(.endEditing(updated.stamp, .finish))
        #expect(throws: CommandTaskTitlePreviewIssue.stale) { try fixture.validate(current) }
    }

    @Test func incompleteDirectoryAndUnknownProtectionAreNotEmptyCatalogs() throws {
        let fixture = try TaskTitleFixture()
        let base = CommandTaskTagCatalog(directoryID: UUID(), readID: UUID(), revision: 0,
                                        coverage: .complete, records: [TaskCreateTagCatalogReader.record(fixture.live)])
        let catalogs = [
            CommandTaskTagCatalog(directoryID: base.directoryID, readID: base.readID, revision: 0, coverage: .partial, records: base.records),
            CommandTaskTagCatalog(directoryID: base.directoryID, readID: base.readID, revision: 0, coverage: .unavailable, records: []),
            CommandTaskTagCatalog(directoryID: base.directoryID, readID: base.readID, revision: 0, coverage: .complete,
                                  records: [.init(id: fixture.live.id, name: "Work", state: .unknown, isPrivateDiary: false)]),
            CommandTaskTagCatalog(directoryID: base.directoryID, readID: base.readID, revision: 0, coverage: .complete,
                                  records: [.init(id: fixture.live.id, name: "Work", state: .live, isPrivateDiary: nil)]),
            CommandTaskTagCatalog(directoryID: base.directoryID, readID: base.readID, revision: 0, coverage: .complete,
                                  records: base.records + [.init(id: nil, name: nil, state: .unknown, isPrivateDiary: nil)])
        ]
        for catalog in catalogs {
            #expect(throws: CommandTaskTitlePreviewIssue.self) {
                try CommandTaskTitleTags.merge(rawIDs: fixture.todo.tagIDs, title: "标题", catalog: catalog)
            }
        }
    }

    @Test func illegalArgumentShapesAndBaselineAreRejected() throws {
        let cases: [CommandArgument] = [.init(parameter: .title, operation: .clear),
                                       .init(parameter: .title, operation: .assign, value: .shortText(" ")),
                                       .init(parameter: .title, operation: .assign, value: .boolean(true))]
        for argument in cases {
            let fixture = try TaskTitleFixture()
            try fixture.queue("标题")
            try fixture.editArgument(argument)
            #expect(throws: CommandTaskTitlePreviewIssue.self) { try fixture.preview() }
        }
        let fixture = try TaskTitleFixture()
        let baseline = CommandDraftBaseline([.init(subject: .object(.init(type: .todo, id: fixture.todo.id)),
                                                   parameter: .title): .uniform(.shortText("陈旧标题"))])
        try fixture.queue("标题", baseline: baseline)
        #expect(throws: CommandTaskTitlePreviewIssue.invalidBaseline) { try fixture.preview() }
    }
}
