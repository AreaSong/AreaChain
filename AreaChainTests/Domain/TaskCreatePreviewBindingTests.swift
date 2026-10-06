import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TaskCreatePreviewBindingTests {
    typealias Fixture = TaskCreatePreviewFixture

    @Test func parameterPlanAndLeaseChangesInvalidatePreview() throws {
        let fixture = try Fixture("任务 #工作")
        let result = try fixture.preview()
        try result.validateCurrent(in: fixture.handoff.owned(), source: fixture.source, catalog: fixture.catalog)
        #expect(result.binding.parsingVersion == CommandTaskCreatePreview.parsingVersion)
        #expect(result.binding.compositionVersion == CommandTaskCreatePreview.compositionVersion)
        try fixture.edit(.init(parameter: .title, operation: .assign, value: .shortText("另一个 #工作")))
        #expect(throws: CommandTaskCreatePreviewIssue.stale) {
            try result.validateCurrent(in: fixture.handoff.owned(), source: fixture.source, catalog: fixture.catalog)
        }
        let edited = try fixture.preview()
        try fixture.handoff.plan(.reorder(fixture.handoff.state().plan.items.map(\.id)))
        #expect(throws: CommandTaskCreatePreviewIssue.stale) {
            try edited.validateCurrent(in: fixture.handoff.owned(), source: fixture.source, catalog: fixture.catalog)
        }
        let reordered = try fixture.preview()
        try fixture.handoff.send(.query(.setInput("合成查询")))
        #expect(throws: CommandTaskCreatePreviewIssue.stale) {
            try reordered.validateCurrent(in: fixture.handoff.owned(), source: fixture.source, catalog: fixture.catalog)
        }
    }

    @Test func directoryFactsAndReadIdentityInvalidateEvenWithoutRevisionBump() throws {
        let row = Fixture.record("工作")
        let fixture = try Fixture("任务 #工作 #待新建", records: [row])
        let result = try fixture.preview()
        let changedRows = [
            [Fixture.record("改名", id: try #require(row.id))],
            [Fixture.record("工作", id: try #require(row.id), deleted: true)],
            [Fixture.record("工作", id: try #require(row.id), privateTag: true)],
            [row, Fixture.record("待新建")], [row, row], []
        ]
        for rows in changedRows {
            #expect(throws: CommandTaskCreatePreviewIssue.stale) {
                try result.validateCurrent(in: fixture.handoff.owned(), source: fixture.source,
                                           catalog: fixture.replacingCatalog(records: rows))
            }
        }
        let old = fixture.catalog
        let catalogs = [
            CommandTaskTagCatalog(directoryID: UUID(), readID: old.readID, revision: old.revision, coverage: .complete, records: old.records),
            CommandTaskTagCatalog(directoryID: old.directoryID, readID: UUID(), revision: old.revision, coverage: .complete, records: old.records),
            CommandTaskTagCatalog(directoryID: old.directoryID, readID: old.readID, revision: 2, coverage: .complete, records: old.records),
            fixture.replacingCatalog(coverage: .partial)
        ]
        for catalog in catalogs {
            #expect(throws: CommandTaskCreatePreviewIssue.stale) {
                try result.validateCurrent(in: fixture.handoff.owned(), source: fixture.source, catalog: catalog)
            }
        }
    }

    @Test func catalogOrderDoesNotCreateFalseIdentityButSourceAndOwnershipDo() throws {
        let fixture = try Fixture("任务 #工作", records: [Fixture.record("工作"), Fixture.record("普通")])
        let result = try fixture.preview()
        try result.validateCurrent(in: fixture.handoff.owned(), source: fixture.source,
                                   catalog: fixture.replacingCatalog(records: fixture.catalog.records.reversed()))
        let source = CommandTaskCreateSource(protection: .ordinary, stampEnabled: true, bundleID: "qa.changed")
        #expect(throws: CommandTaskCreatePreviewIssue.stale) {
            try result.validateCurrent(in: fixture.handoff.owned(), source: source, catalog: fixture.catalog)
        }
        _ = try fixture.handoff.transfer()
        #expect(throws: CommandTaskCreatePreviewIssue.stale) {
            try result.validateCurrent(in: fixture.handoff.owned(HandoffFixture.target), source: fixture.source, catalog: fixture.catalog)
        }
    }

    @Test func unknownAndRequiredSourceCannotBecomeOrdinaryByClearingTags() throws {
        let fixture = try Fixture("任务 #普通", extra: [Fixture.tags(.clear)])
        for protection in [CommandProtectionRequirement.required, .unknown] {
            let source = CommandTaskCreateSource(protection: protection, stampEnabled: false, bundleID: "")
            #expect(throws: CommandTaskCreatePreviewIssue.protectedContent) {
                try CommandTaskCreatePreview.prepare(in: fixture.handoff.owned(), source: source, catalog: fixture.catalog)
            }
            let draft = CommandDraft(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.create"),
                                     arguments: TaskCreateCommandFixture.arguments(), protectionRequirement: protection)
            var plan = CommandPlan(hostID: draft.hostID)
            #expect(throws: CommandPlanError.protectedContent) { try plan.add(draft, id: UUID(), expecting: plan.stamp) }
        }
    }

    @Test func multipleItemsObjectsAndOtherCommandsStayUnsupported() throws {
        let multiple = try Fixture()
        try multiple.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.create"),
                                         arguments: TaskCreateCommandFixture.arguments()))
        #expect(throws: CommandTaskCreatePreviewIssue.unsupportedPlan) { try multiple.preview() }
        let targeted = try Fixture()
        let item = try #require(targeted.handoff.state().plan.items.first)
        try targeted.handoff.plan(.beginEditing(item.stamp))
        try targeted.handoff.plan(.selectTargets(item.stamp, .init(.single, objects: [.init(type: .todo, id: UUID())])))
        let current = try #require(targeted.handoff.state().plan.items.first)
        try targeted.handoff.plan(.endEditing(current.stamp, .finish))
        #expect(throws: CommandTaskCreatePreviewIssue.unsupportedPlan) { try targeted.preview() }
        let other = try HandoffFixture()
        try other.queue(HandoffFixture.setting())
        #expect(throws: CommandTaskCreatePreviewIssue.unsupportedPlan) {
            try CommandTaskCreatePreview.prepare(in: other.owned(), source: multiple.source, catalog: multiple.catalog)
        }
    }

    @Test func invalidModesValuesAndDatesUseCatalogValidation() throws {
        let cases: [CommandArgument] = [
            .init(parameter: .tags, operation: .assign, value: .tags([UUID()])),
            .init(parameter: .tags, operation: .replaceAll, value: .tags([])),
            .init(parameter: .time, operation: .setReminder, value: .time(1440)),
            .init(parameter: .priority, operation: .assign, value: .choice("p5")),
            .init(parameter: .time, operation: .cancelReminder, value: .time(30)),
            .init(parameter: .notes, operation: .unspecified)
        ]
        for argument in cases {
            let fixture = try Fixture(extra: [argument])
            #expect(throws: CommandTaskCreatePreviewIssue.self) { try fixture.preview() }
        }
        let fixture = try Fixture()
        try fixture.edit(.init(parameter: .day, operation: .assign, value: .day("2026-02-30")))
        #expect(throws: CommandTaskCreatePreviewIssue.self) { try fixture.preview() }
    }

    @Test func descriptionsDoNotExpandInputOrDirectory() throws {
        let fixture = try Fixture("synthetic-body #synthetic-tag", records: [Fixture.record("synthetic-tag", privateTag: true)])
        let result = try fixture.preview()
        let values: [Any] = [result, result.composition, result.composition.tags, fixture.catalog,
                             result.composition.tags.problems, result.issues]
        for value in values {
            #expect(!String(describing: value).contains("synthetic-"))
            #expect(!String(reflecting: value).contains("synthetic-"))
        }
        #expect(result.transactionPlan == nil)
    }
}
