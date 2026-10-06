import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor final class TaskCreateCompositionFixture {
    let base: TaskCreateCommandFixture
    let adapter: TaskCreateCommandAdapter
    var context: ModelContext { base.io.capture.context }
    var environment: TaskCreateCommandEnvironment { base.environment }
    var handoff: HandoffFixture { base.handoff }

    init() throws {
        base = try TaskCreateCommandFixture()
        adapter = TaskCreateCommandAdapter(coordinator: base.handoff.coordinator, environment: base.environment,
                                           capability: .ordinaryComposition)
    }

    @discardableResult
    func seed(_ name: String, deleted: Bool = false, privateTag: Bool = false, id: UUID = UUID()) throws -> TagItem {
        let tag = TagItem(id: id, name: name, sortOrder: try context.fetchCount(FetchDescriptor<TagItem>()),
                          deletedAt: deleted ? Date(timeIntervalSince1970: 100) : nil)
        tag.isPrivateDiary = privateTag
        context.insert(tag)
        try context.save()
        return tag
    }

    func preview(_ title: String = "任务 #新建", extra: [CommandArgument] = []) throws -> CommandTaskCreatePreview {
        try base.queue(TaskCreateCommandFixture.arguments(title, day: "2026-10-06") + extra)
        return try adapter.preview(plan: handoff.state().plan.stamp, expecting: handoff.owned().lease)
    }

    func accept(_ preview: CommandTaskCreatePreview) throws -> CommandTaskCreatePreparation {
        try adapter.accept(preview, expecting: handoff.owned().lease)
    }

    func submit(_ accepted: CommandTaskCreatePreparation) throws -> CommandTaskCreateFacts {
        try adapter.submit(accepted: accepted, expecting: handoff.owned().lease)
    }

    func tags() throws -> [TagItem] {
        let reader = ModelContext(context.container)
        reader.autosaveEnabled = false
        return try reader.fetch(FetchDescriptor<TagItem>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    func expectNoCommandWrites() throws {
        #expect(try base.io.capture.readTodos().isEmpty)
        #expect(base.io.capture.trace.isEmpty && base.io.capture.registered.isEmpty)
        #expect(base.io.capture.authorizations.isEmpty)
        #expect(base.io.notificationProcessed == 0 && base.io.calendarProcessed == 0)
    }

    func edit(_ argument: CommandArgument) throws {
        let item = try #require(handoff.state().plan.items.first)
        try handoff.plan(.beginEditing(item.stamp))
        try handoff.plan(.edit(item.stamp, argument))
        let changed = try #require(handoff.state().plan.items.first)
        try handoff.plan(.endEditing(changed.stamp, .finish))
    }
}
