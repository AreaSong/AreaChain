import Foundation
import Testing
@testable import AreaChain

@MainActor struct TaskCreatePreviewFixture {
    let handoff: HandoffFixture
    let catalog: CommandTaskTagCatalog
    let source = CommandTaskCreateSource(protection: .ordinary, stampEnabled: false, bundleID: "")

    init(_ title: String = "合成任务", extra: [CommandArgument] = [], records: [CommandTaskTagRecord] = []) throws {
        handoff = try HandoffFixture()
        catalog = .init(directoryID: UUID(), readID: UUID(), revision: 1, coverage: .complete, records: records)
        let draft = CommandDraft(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.create"),
                                 arguments: TaskCreateCommandFixture.arguments(title) + extra)
        try handoff.queue(draft)
    }

    func preview(catalog: CommandTaskTagCatalog? = nil) throws -> CommandTaskCreatePreview {
        try .prepare(in: handoff.owned(), source: source, catalog: catalog ?? self.catalog)
    }

    func replacingCatalog(records: [CommandTaskTagRecord]? = nil,
                          coverage: CommandTaskTagCatalog.Coverage = .complete) -> CommandTaskTagCatalog {
        .init(directoryID: catalog.directoryID, readID: catalog.readID, revision: catalog.revision,
              coverage: coverage, records: records ?? catalog.records)
    }

    static func record(_ name: String, id: UUID = UUID(), deleted: Bool = false,
                       privateTag: Bool? = false) -> CommandTaskTagRecord {
        .init(id: id, name: name, state: deleted ? .deleted(Date(timeIntervalSince1970: 100)) : .live, isPrivateDiary: privateTag)
    }

    static func tags(_ operation: CommandFieldOperation, _ ids: [UUID] = []) -> CommandArgument {
        .init(parameter: .tags, operation: operation, value: operation.requiresValue ? .tags(ids) : nil)
    }

    func edit(_ argument: CommandArgument) throws {
        let item = try #require(handoff.state().plan.items.first)
        try handoff.plan(.beginEditing(item.stamp))
        try handoff.plan(.edit(item.stamp, argument))
        let current = try #require(handoff.state().plan.items.first)
        try handoff.plan(.endEditing(current.stamp, .finish))
    }
}
