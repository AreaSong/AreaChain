import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchPlanDependencyTests {
    @Test func targetReferenceUsesDeclaredTypeAndNeverInventsObjects() throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        let producer = try fixture.enqueueOperation("todo.create")
        let consumer = try fixture.enqueueOperation("todo.completion")
        fixture.controller.setCreationReference(producer.stamp, parameter: .target,
            item: consumer.stamp, source: fixture.controller.buffer)
        let updated = try fixture.planItem(consumer.id)
        #expect(updated.links.results[.target]?.producer == producer.stamp)
        #expect(updated.draft.targets == .none && updated.draft.arguments.isEmpty)
        #expect(fixture.controller.plan?.check().items.last?.targets.isEmpty == true)
        #expect(fixture.controller.plan?.check().isExecutable == false)
    }
    @Test func declaredTodoOutputBindsParentWithoutPlaceholderAndRepairsEachStaleReference() throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        let parent = try fixture.enqueueOperation("todo.create")
        let children = try (0..<2).map { _ in try fixture.enqueueOperation("subtask.create") }
        for child in children {
            #expect(fixture.controller.creationSources(for: .parent, item: child).map(\.id) == [parent.id])
            fixture.controller.setCreationReference(parent.stamp, parameter: .parent, item: child.stamp, source: fixture.controller.buffer)
        }
        #expect(fixture.controller.plan?.check().dependencies.isEmpty == true)
        for child in children {
            #expect(try fixture.planItem(child.id).draft.arguments.isEmpty)
            #expect(try fixture.planItem(child.id).links.results[.parent]?.outputType == .todo)
        }
        fixture.controller.beginPlanEditing(parent.stamp, source: fixture.controller.buffer)
        try fixture.planText(.title, "Changed producer")
        let current = try fixture.planItem(parent.id)
        fixture.controller.endPlanEditing(current.stamp, source: fixture.controller.buffer)
        #expect(fixture.controller.plan?.check().dependencies.count == 2)
        for child in children {
            fixture.controller.setCreationReference(current.stamp, parameter: .parent,
                item: try fixture.planItem(child.id).stamp, source: fixture.controller.buffer)
        }
        #expect(fixture.controller.plan?.check().dependencies.isEmpty == true)
        #expect(fixture.controller.plan?.check().isExecutable == false)
    }

    @Test func dependencyOrderRemovalMissingProducerAndDirectValueAreRejectedWithoutMutation() throws {
        let fixture = try UnifiedSearchResultsFixture(.objectBatch())
        defer { fixture.stop() }
        let parent = try fixture.enqueueOperation("todo.create")
        let child = try fixture.enqueueOperation("subtask.create")
        fixture.controller.setCreationReference(parent.stamp, parameter: .parent, item: child.stamp, source: fixture.controller.buffer)
        let before = fixture.controller.plan
        fixture.controller.movePlanItem(parent.stamp, offset: 1, source: fixture.controller.buffer)
        #expect(fixture.controller.plan == before)
        #expect(!fixture.controller.removePlanItem(parent.stamp, source: fixture.controller.buffer))
        fixture.controller.setCreationReference(.init(id: UUID(), version: 0), parameter: .parent,
            item: try fixture.planItem(child.id).stamp, source: fixture.controller.buffer)
        #expect(fixture.controller.plan == before)
        fixture.controller.beginPlanEditing(try fixture.planItem(child.id).stamp, source: fixture.controller.buffer)
        let source = fixture.controller.buffer
        #expect(fixture.controller.sendOperation(.edit(try fixture.planItem(child.id).draft.stamp,
            PlanFixture.argument(.parent, .object(.object(0)))), source: source) == nil)
        fixture.controller.setCreationReference(nil, parameter: .parent, item: try fixture.planItem(child.id).stamp,
                                                source: fixture.controller.buffer)
        try setDirectParent(fixture, child: child)
        #expect(fixture.controller.creationSources(for: .parent, item: try fixture.planItem(child.id)).isEmpty)
    }

    private func setDirectParent(_ fixture: UnifiedSearchResultsFixture, child: CommandPlanItem) throws {
        // 直接值互斥走同一原领域编辑事件；候选实际确认另由对象契约/原生套件覆盖。
        let draft = try fixture.planItem(child.id).draft
        #expect(fixture.controller.sendOperation(.edit(draft.stamp, PlanFixture.argument(.parent, .object(.object(0)))),
                                                   source: fixture.controller.buffer) != nil)
    }

    @Test func reorderIndependentItemsAndAtomicGroupConstraintsUseDomainRules() throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        let first = try fixture.enqueueOperation("setting.language")
        let second = try fixture.enqueueOperation("setting.appearance")
        fixture.controller.movePlanItem(second.stamp, offset: -1, source: fixture.controller.buffer)
        #expect(fixture.controller.plan?.items.map(\.id) == [second.id, first.id])
        #expect(fixture.controller.sendPlan(.atomicGroup(UUID(), members: [second.id, first.id]), source: fixture.controller.buffer))
        let grouped = try fixture.planItem(first.id)
        #expect(!fixture.controller.removePlanItem(grouped.stamp, source: fixture.controller.buffer))
        #expect(fixture.controller.planMessage == "unified.plan.grouped")
        #expect(fixture.controller.plan?.items.count == 2)
    }
}
