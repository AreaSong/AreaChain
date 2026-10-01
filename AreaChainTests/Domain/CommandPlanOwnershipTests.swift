import Foundation
import Testing
@testable import AreaChain

struct CommandPlanOwnershipTests {
    @Test func explicitMoveRejectsDuplicateAndStaleVersions() throws {
        var host = PlanFixture.host()
        let draft = PlanFixture.todo()
        host.operationEvent(.start(expectedRevision: 0, draft))
        let old = try #require(host.operations.active?.stamp)
        host.operationEvent(.edit(old, PlanFixture.argument(.title, .shortText("Synthetic edit"))))
        let before = host
        #expect(throws: CommandPlanError.stale) { try host.enqueue(old, itemID: UUID(), expecting: host.plan.stamp) }
        #expect(host == before)
        let current = try #require(host.operations.active?.stamp)
        let planStamp = host.plan.stamp, id = UUID()
        try host.enqueue(current, itemID: id, expecting: planStamp)
        #expect(host.operations.active == nil && host.operations.retained.isEmpty)
        #expect(host.plan.items.first?.draft.stamp == current)
        let queued = host
        #expect(throws: CommandPlanError.stale) { try host.enqueue(current, itemID: id, expecting: planStamp) }
        #expect(host.operationEvent(.edit(current, PlanFixture.argument(.title, .shortText("Late")))) == [.rejectedEvent])
        #expect(host == queued)
        #expect(host.requiresUnsavedContentHandling)
    }

    @Test func retainedIsNotQueueAndTransferWaitsForPendingDecision() throws {
        var host = PlanFixture.host()
        host.operationEvent(.start(expectedRevision: 0, PlanFixture.todo()))
        let first = try #require(host.operations.active?.stamp)
        host.operationEvent(.start(expectedRevision: host.operations.revision, PlanFixture.setting()))
        let pending = try #require(host.operations.pending)
        #expect(throws: CommandPlanError.stale) { try host.enqueue(first, itemID: UUID(), expecting: host.plan.stamp) }
        host.operationEvent(.resolve(pending, .retain))
        #expect(host.plan.items.isEmpty && host.operations.retained.count == 1)
        try host.enqueue(first, itemID: UUID(), expecting: host.plan.stamp)
        #expect(host.operations.retained.isEmpty)
        #expect(host.operations.active?.commandID.rawValue == "setting.language")
        #expect(host.plan.items.first?.draft.id == first.draftID)
    }

    @Test func editingCancellationRemovalAndOldEditorCallbacks() throws {
        var host = PlanFixture.host()
        let id = try PlanFixture.queue(PlanFixture.todo(), in: &host)
        let initial = try PlanFixture.item(id, in: host)
        try host.planEvent(.beginEditing(initial.stamp), expecting: host.plan.stamp)
        let editingRevision = host.plan.stamp
        let update = PlanFixture.argument(.title, .shortText("Synthetic retained edit"))
        try host.planEvent(.edit(initial.stamp, update), expecting: editingRevision)
        #expect(throws: CommandPlanError.stale) { try host.planEvent(.edit(initial.stamp, update), expecting: host.plan.stamp) }
        let current = try PlanFixture.item(id, in: host)
        #expect(throws: CommandPlanError.busy) { try host.removeFromPlan(current.stamp, expecting: host.plan.stamp) }
        #expect(throws: CommandPlanError.busy) { try PlanFixture.seal(&host) }
        try host.planEvent(.endEditing(current.stamp, .cancelKeepingChanges), expecting: host.plan.stamp)
        #expect(host.plan.items[0].draft.arguments.contains(update))
        try host.removeFromPlan(current.stamp, expecting: host.plan.stamp)
        #expect(host.plan.items.isEmpty && host.operations.retained.count == 1)
        let returned = host.operations.retained[0]
        #expect(returned.id == initial.draft.id && returned.version > current.draft.version)
        #expect(returned.arguments.contains(update) && host.requiresUnsavedContentHandling)
        #expect(throws: CommandPlanError.stale) { try host.removeFromPlan(current.stamp, expecting: host.plan.stamp) }
        host.operationEvent(.restore(expectedRevision: host.operations.revision, returned.stamp))
        #expect(host.operations.active?.id == returned.id && host.operations.retained.isEmpty)
    }

    @Test func incompleteBlocksWholePlanAndCatalogExclusionsAreAtomic() throws {
        var host = PlanFixture.host()
        try PlanFixture.queue(PlanFixture.setting(), in: &host)
        let child = try PlanFixture.queue(PlanFixture.child(), in: &host)
        #expect(host.plan.check().items.last?.status == .needsInput)
        #expect(throws: CommandPlanError.incomplete) { try PlanFixture.seal(&host) }
        #expect(host.plan.items.count == 2 && host.execution == nil)
        try PlanFixture.edit(child, argument: PlanFixture.argument(.parent, .object(.init(type: .todo, id: UUID()))), in: &host)
        #expect(host.plan.check().canSealProtocol)
        for command in CommandCatalog.standard.entries where command.queue == .excluded || command.availability != .declared {
            var excluded = PlanFixture.host()
            let seed = CommandDraft(id: UUID(), hostID: "workspace", commandID: command.id)
            excluded.operationEvent(.start(expectedRevision: 0, seed))
            let before = excluded
            #expect(throws: CommandPlanError.excluded) {
                try excluded.enqueue(#require(excluded.operations.active?.stamp), itemID: UUID(), expecting: excluded.plan.stamp)
            }
            #expect(excluded == before)
        }
        #expect(CommandCatalog.standard.entries.allSatisfy { !$0.isExecutable && !$0.canEnterOrdinaryQueue && $0.execution == .unwired })
    }

    @Test func queryNavigationAndCollapseLeavePlanAndRunUntouched() throws {
        var host = PlanFixture.host()
        try PlanFixture.queue(PlanFixture.todo(), in: &host)
        let plan = host.plan
        host.queryEvent(.setInput("Synthetic query"))
        host.queryEvent(.enterPage(QuerySessionFixture.page(.settings, visit: "settings")))
        host.queryEvent(.clearUserQuery)
        for event in CommandHostPresentationEvent.allCases { host.presentationEvent(event) }
        #expect(host.plan == plan && host.requiresUnsavedContentHandling)
        try PlanFixture.seal(&host)
        let attempt = try PlanFixture.begin(&host), execution = host.execution
        for event in CommandHostPresentationEvent.allCases { host.presentationEvent(event) }
        host.queryEvent(.clearUserQuery)
        #expect(host.execution == execution && host.isBusy)
        #expect(host.execution?.cancellationAssessment(attempt.unitID) == .requiresAdapterConfirmation)
    }
}
