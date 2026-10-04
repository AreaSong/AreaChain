import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchPlanContractTests {
    @Test func planParentSelectionUsesReadSessionWithoutChangingTargets() async throws {
        let fixture = try UnifiedSearchResultsFixture(.objectBatch())
        defer { fixture.stop() }
        let child = try fixture.enqueueOperation("subtask.create")
        fixture.controller.beginPlanEditing(child.stamp, source: fixture.controller.buffer)
        try await fixture.acceptObjects([.object(0)], location: .parameter(.parent))
        #expect(try fixture.planItem(child.id).draft.arguments.contains { $0.parameter == .parent && $0.value == .object(.object(0)) })
        #expect(try fixture.planItem(child.id).draft.targets == .none)
        #expect(fixture.controller.operations?.active == nil)
    }
    @Test func sameCommandRetainedDraftsRestoreByIdentity() throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        let first = try fixture.enqueueOperation("todo.create", arguments: [PlanFixture.argument(.title, .shortText("First"))])
        let second = try fixture.enqueueOperation("todo.create", arguments: [PlanFixture.argument(.title, .shortText("Second"))])
        #expect(fixture.controller.removePlanItem(first.stamp, source: fixture.controller.buffer))
        #expect(fixture.controller.removePlanItem(second.stamp, source: fixture.controller.buffer))
        let retained = try #require(fixture.controller.operations?.retained.first { $0.id == second.draft.id })
        fixture.controller.restoreOperation(retained.stamp, source: fixture.controller.buffer)
        #expect(try fixture.draft.id == second.draft.id)
        #expect(fixture.controller.operations?.retained.map(\.id) == [first.draft.id])
    }
    @Test func enqueueOwnsDraftOnceAndRejectsDoubleClickStampsAndExcludedCommands() throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        try fixture.startOperation("todo.create")
        let old = fixture.controller.buffer
        let draft = try fixture.draft
        #expect(fixture.controller.enqueue(draft.stamp, source: old))
        #expect(!fixture.controller.enqueue(draft.stamp, source: old))
        #expect(!fixture.controller.enqueue(draft.stamp, source: fixture.controller.buffer))
        #expect(fixture.controller.operations?.active == nil && fixture.controller.operations?.retained.isEmpty == true)
        #expect(fixture.controller.plan?.items.map(\.draft.id) == [draft.id])
        #expect(fixture.controller.plan?.check().canSealProtocol == false)
        try fixture.startOperation("app.quit")
        let excluded = try fixture.draft
        #expect(!fixture.controller.enqueue(excluded.stamp, source: fixture.controller.buffer))
        #expect(try fixture.draft == excluded)
        #expect(fixture.controller.planMessage == "unified.plan.excluded")
    }

    @Test func retainedEnqueueRemovalAndRestorePreserveUniqueParameters() throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        try fixture.startOperation("todo.create")
        try fixture.typeParameter(.title, text: "Synthetic retained")
        let draft = try fixture.draft
        try fixture.startOperation("setting.language")
        let decision = try #require(fixture.controller.operations?.pending)
        fixture.controller.resolveOperation(decision, choice: .retain, source: fixture.controller.buffer)
        let retained = try #require(fixture.controller.operations?.retained.first)
        #expect(fixture.controller.enqueue(retained.stamp, source: fixture.controller.buffer))
        let item = try #require(fixture.controller.plan?.items.first)
        #expect(item.draft.id == draft.id && fixture.controller.operations?.retained.isEmpty == true)
        #expect(fixture.controller.removePlanItem(item.stamp, source: fixture.controller.buffer))
        #expect(fixture.controller.operations?.retained.first?.arguments == draft.arguments)
        try fixture.startOperation("todo.create")
        #expect(try fixture.draft.id == draft.id && fixture.controller.plan?.items.isEmpty == true)
    }

    @Test func planEditingCompletesParametersKeepsChangesAndRejectsOldCallbacks() throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        let first = try fixture.enqueueOperation("todo.create")
        let second = try fixture.enqueueOperation("todo.create")
        fixture.controller.beginPlanEditing(first.stamp, source: fixture.controller.buffer)
        let old = fixture.controller.buffer
        try fixture.planText(.title, "Synthetic plan title")
        try fixture.planText(.day, "2026-10-03")
        #expect(fixture.controller.plan?.check().items.first?.arguments.isEmpty == true)
        fixture.controller.beginPlanEditing(second.stamp, source: fixture.controller.buffer)
        #expect(fixture.controller.editingPlanItem?.id == second.id)
        #expect(fixture.controller.editParameter(PlanFixture.argument(.title, .shortText("OLD")), source: old) == nil)
        #expect(try fixture.planItem(first.id).draft.arguments.contains { $0.value == .shortText("Synthetic plan title") })
        #expect(fixture.controller.operations?.active == nil)
        let closing = try fixture.planItem(second.id)
        fixture.controller.endPlanEditing(closing.stamp, source: fixture.controller.buffer)
        #expect(fixture.controller.plan?.editing == nil)
        #expect(!fixture.controller.removePlanItem(first.stamp, source: old))
    }

    @Test func objectSelectionEditsPlanItemAndStalePickerCannotWriteNextItem() async throws {
        let fixture = try UnifiedSearchResultsFixture(.objectBatch())
        defer { fixture.stop() }
        let first = try fixture.enqueueOperation("todo.completion")
        let second = try fixture.enqueueOperation("todo.completion")
        fixture.controller.beginPlanEditing(first.stamp, source: fixture.controller.buffer)
        let picker = try await fixture.chooseObjects()
        fixture.controller.toggleObject(.object(0), stamp: picker.stamp)
        #expect(fixture.controller.acceptObjects(picker.stamp))
        await fixture.controller.objectSelectionTask?.value
        #expect(try fixture.planItem(first.id).draft.targets.objects == [.object(0)])
        fixture.controller.beginPlanEditing(second.stamp, source: fixture.controller.buffer)
        #expect(!fixture.controller.acceptObjects(picker.stamp))
        #expect(try fixture.planItem(second.id).draft.targets == .none)
        try await fixture.acceptObjects([.object(1)])
        #expect(try fixture.planItem(second.id).draft.targets.objects == [.object(1)])
        #expect(fixture.controller.operations?.active == nil)
    }

    @Test func mergeNeedsExplicitAcceptanceAndPreservesUnsupportedAssignments() throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        fixture.controller.syntheticBaselines[.init(rawValue: "setting.language")] = .init([
            .init(subject: .ambient, parameter: .value): .uniform(.choice("system"))])
        let first = try fixture.enqueueOperation("setting.language", arguments: [PlanFixture.argument(.value, .choice("chinese"))])
        let second = try fixture.enqueueOperation("setting.language", arguments: [PlanFixture.argument(.value, .choice("english"))])
        let proposal = try #require(fixture.controller.proposePlanMerge(second.stamp, source: fixture.controller.buffer))
        #expect(fixture.controller.plan?.items.count == 2)
        fixture.controller.acceptPlanMerge(proposal)
        #expect(fixture.controller.plan?.items.count == 1)
        #expect(try fixture.planItem(first.id).draft.arguments.first?.value == .choice("english"))
        fixture.controller.acceptPlanMerge(proposal)
        #expect(fixture.controller.plan?.items.count == 1)
        let unsupported = try fixture.enqueueOperation("todo.create")
        #expect(fixture.controller.proposePlanMerge(unsupported.stamp, source: fixture.controller.buffer) == nil)
        #expect(fixture.controller.plan?.items.count == 2)
    }
}
