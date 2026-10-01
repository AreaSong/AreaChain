import Foundation
import Testing
@testable import AreaChain

@MainActor struct CommandHandoffIdentityTests {
    @Test func oldSourceCopiesCannotEditSubmitOrReceiveCallbacks() throws {
        let fixture = try HandoffFixture()
        try fixture.queue(HandoffFixture.setting())
        try fixture.start(HandoffFixture.setting())
        let old = try fixture.owned()
        let oldDraft = try #require(old.session.operations.active)
        try fixture.transfer()
        let received = try fixture.owned(HandoffFixture.target)
        #expect(throws: CommandHandoffError.stale) {
            try fixture.coordinator.send(.operation(.edit(oldDraft.stamp, PlanFixture.argument(.value, .choice("system")))), expecting: old.lease)
        }
        #expect(throws: CommandHandoffError.stale) {
            try fixture.coordinator.send(.sealPlan(old.session.plan.stamp, runID: UUID()), expecting: old.lease)
        }
        let callback = CommandAttemptStamp(execution: .init(runID: UUID(), plan: old.session.plan.stamp),
                                          unitID: old.session.plan.items[0].id, number: 1, phase: .local)
        #expect(throws: CommandHandoffError.stale) {
            try fixture.coordinator.send(.result(.init(attempt: callback, result: .failedWithoutCommit)), expecting: old.lease)
        }
        // 脱离协调者的 Swift 值仍能做纯计算，但不会改登记状态或取得有效 lease。
        var detached = old.session
        try detached.sealPlanForProtocol(detached.plan.stamp, runID: UUID())
        #expect(detached.execution?.isExecutable == false)
        #expect(try fixture.owned(HandoffFixture.target) == received)
        #expect(throws: CommandHandoffError.stale) { try fixture.coordinator.validate(old.lease) }
        let rejected = try fixture.send(.operation(.edit(oldDraft.stamp, PlanFixture.argument(.value, .choice("system")))), host: HandoffFixture.target)
        if case .operation(let intents) = rejected { #expect(intents == [.rejectedEvent]) } else { Issue.record("Expected rejection") }
        #expect(throws: CommandPlanError.stale) {
            try fixture.send(.sealPlan(old.session.plan.stamp, runID: UUID()), host: HandoffFixture.target)
        }
    }

    @Test func fixedIdentitiesBodiesBaselinesAndEditingRemainSingleOwned() throws {
        let fixture = try HandoffFixture()
        let object = CommandObjectReference(type: .routine, id: UUID())
        let baseline = CommandDraftBaseline([.init(subject: .object(object), parameter: .notes): .uniform(.longText("Synthetic baseline"))])
        let draft = CommandDraft(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "routine.notes"),
                                 targets: .init(.allResults, objects: [object]), baseline: baseline,
                                 arguments: [.init(parameter: .notes, operation: .append, value: .longText("Synthetic body\n unchanged"))])
        try fixture.queue(draft)
        let original = try fixture.state().plan.items[0]
        try fixture.plan(.beginEditing(original.stamp))
        try fixture.transfer()
        let state = try fixture.state(HandoffFixture.target)
        let moved = state.plan.items[0]
        #expect(moved.id == original.id && moved.draft.id == draft.id)
        #expect(moved.draft.targets == draft.targets && moved.draft.baseline == baseline)
        #expect(moved.draft.arguments == draft.arguments)
        #expect(moved.draft.hostID == HandoffFixture.target)
        #expect(moved.version == original.version + 1 && moved.draft.version == original.draft.version + 1)
        #expect(state.plan.editing == moved.id)
        #expect(state.operations.active == nil && state.operations.retained.isEmpty)
        #expect(try fixture.state().plan.items.isEmpty)
        #expect(throws: CommandPlanError.stale) {
            try fixture.plan(.edit(original.stamp, PlanFixture.argument(.notes, .longText("Synthetic late"))), host: HandoffFixture.target)
        }
    }

    @Test func routineOccurrenceKeepsDefinitionIDAndCivilDate() throws {
        let fixture = try HandoffFixture()
        let occurrence = CommandObjectReference(type: .routineOccurrence, id: UUID(), dayKey: "2026-10-01")
        try fixture.start(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "occurrence.skip"),
                                targets: .init(.single, objects: [occurrence])))
        let before = try #require(fixture.state().operations.active)
        #expect(before.check().staticallyValid)
        try fixture.transfer()
        let received = try #require(fixture.state(HandoffFixture.target).operations.active)
        #expect(received.targets.objects == [occurrence])
        #expect(received.check().staticallyValid)
        #expect(received.modification == before.modification)
    }

    @Test func creationReferencesAreRemappedTogetherAndStillValidate() throws {
        let fixture = try HandoffFixture()
        let producer = CommandDraft(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.create"),
                                    arguments: [PlanFixture.argument(.title, .shortText("Synthetic task")), PlanFixture.argument(.day, .day("2026-10-01"))])
        try fixture.queue(producer)
        let parent = try fixture.state().plan.items[0]
        try fixture.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "subtask.create"),
                                arguments: [PlanFixture.argument(.title, .shortText("Synthetic child"))]))
        let child = try fixture.state().plan.items[1]
        try fixture.plan(.link(child.stamp, .init(predecessors: [parent.id], results: [
            .parent: .init(producer: parent.stamp, outputType: .todo)
        ])))
        let before = try fixture.state().plan
        try fixture.transfer()
        let plan = try fixture.state(HandoffFixture.target).plan
        #expect(plan.items.map(\.id) == before.items.map(\.id))
        #expect(plan.items[1].links.predecessors == [parent.id])
        #expect(plan.items[1].links.results[.parent]?.producer == plan.items[0].stamp)
        #expect(plan.items[1].links.results[.parent]?.producer != parent.stamp)
        #expect(plan.check().dependencies.isEmpty && plan.check().canSealProtocol)
        #expect(plan.items[0].draft.targets.objects.isEmpty)
        #expect(plan.items[1].draft.arguments == before.items[1].draft.arguments)
        #expect(try fixture.state(HandoffFixture.target).execution == nil)
    }

    @Test func atomicGroupsMergeProvenanceAndUsedItemIDsSurvive() throws {
        let fixture = try HandoffFixture()
        let firstID = try fixture.queue(HandoffFixture.setting())
        let discardedID = try fixture.queue(HandoffFixture.setting(value: "english"))
        let beforeMerge = try fixture.state().plan.items
        try fixture.plan(.merge(earlier: beforeMerge[0].stamp, later: beforeMerge[1].stamp))
        let groupMate = try fixture.queue(HandoffFixture.setting(value: "system"))
        let groupID = UUID()
        try fixture.plan(.atomicGroup(groupID, members: [firstID, groupMate]))
        let before = try fixture.state().plan
        try fixture.transfer()
        let after = try fixture.state(HandoffFixture.target).plan
        #expect(after.items.map(\.atomicGroup) == before.items.map(\.atomicGroup))
        #expect(after.items[0].mergedOrigins == before.items[0].mergedOrigins)
        #expect(after.items[0].mergedOrigins == [beforeMerge[1].draft.stamp])
        #expect(after.check().dependencies.isEmpty)
        try fixture.start(HandoffFixture.setting(HandoffFixture.target))
        let host = try fixture.state(HandoffFixture.target)
        #expect(throws: CommandPlanError.duplicate) {
            try fixture.send(.enqueue(#require(host.operations.active?.stamp), itemID: discardedID, plan: host.plan.stamp), host: HandoffFixture.target)
        }
        #expect(try fixture.state(HandoffFixture.target) == host)
        #expect(throws: CommandPlanError.invalidInput) { try fixture.plan(.atomicGroup(groupID, members: [firstID, groupMate]), host: HandoffFixture.target) }
    }

    @Test func usedDraftAndRunIDsFromBothSidesSurviveRoundTrip() throws {
        let fixture = try HandoffFixture()
        let sourceDraft = HandoffFixture.setting(), targetDraft = HandoffFixture.setting(HandoffFixture.target)
        let sourceRunID = UUID(), targetRunID = UUID()
        for (draft, runID) in [(sourceDraft, sourceRunID), (targetDraft, targetRunID)] {
            try fixture.queue(draft)
            let run = try fixture.seal(host: draft.hostID, id: runID)
            try fixture.result(.committed(outputs: [:], external: []), attempt: fixture.begin(host: draft.hostID), host: draft.hostID)
            try fixture.send(.releaseExecution(run), host: draft.hostID)
        }
        try fixture.transfer()
        for draft in [sourceDraft, targetDraft] {
            let replay = CommandDraft(id: draft.id, hostID: HandoffFixture.target, commandID: draft.commandID)
            try fixture.start(replay)
            #expect(try fixture.state(HandoffFixture.target).operations.active == nil)
        }
        try fixture.queue(HandoffFixture.setting(HandoffFixture.target))
        for runID in [sourceRunID, targetRunID] {
            #expect(throws: CommandPlanError.duplicate) { try fixture.seal(host: HandoffFixture.target, id: runID) }
        }
        let reverse = try fixture.coordinator.prepare(id: UUID(), source: fixture.owned(HandoffFixture.target).lease,
                                                      target: fixture.owned().lease)
        try fixture.coordinator.confirm(reverse, readiness: .init())
        try fixture.coordinator.commit(reverse)
        for runID in [sourceRunID, targetRunID] {
            #expect(throws: CommandPlanError.duplicate) { try fixture.seal(id: runID) }
        }
        try fixture.start(sourceDraft)
        #expect(try fixture.state().operations.active == nil)
    }

    @Test func receivedRetainedAndPlanDraftsContinueThroughOriginalOwnershipEntrypoints() throws {
        let fixture = try HandoffFixture()
        let planned = HandoffFixture.setting()
        try fixture.queue(planned)
        try fixture.start(HandoffFixture.setting())
        try fixture.start(HandoffFixture.setting(value: "english"))
        try fixture.send(.operation(.resolve(#require(fixture.state().operations.pending), .retain)))
        let before = try fixture.state()
        let oldRetained = before.operations.retained[0]
        try fixture.transfer()
        let target = HandoffFixture.target
        let received = try fixture.state(target)
        try fixture.send(.operation(.restore(expectedRevision: received.operations.revision, received.operations.retained[0].stamp)), host: target)
        try fixture.send(.operation(.resolve(#require(fixture.state(target).operations.pending), .retain)), host: target)
        let restored = try #require(fixture.state(target).operations.active)
        #expect(restored.id == oldRetained.id && restored.arguments == oldRetained.arguments)
        #expect(restored.hostID == target && restored.version > oldRetained.version)
        let plan = try fixture.state(target).plan
        try fixture.send(.removeFromPlan(plan.items[0].stamp, plan.stamp), host: target)
        let final = try fixture.state(target)
        #expect(final.plan.items.isEmpty)
        #expect(final.operations.retained.contains { $0.id == planned.id && $0.arguments == planned.arguments })
        let ids = final.operations.retained.map(\.id) + [restored.id]
        #expect(Set(ids).count == ids.count && ids.count == 3)
        #expect(try fixture.state().operations.retained.isEmpty && fixture.state().plan.items.isEmpty)
    }
}
