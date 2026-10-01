import Foundation
import Testing
@testable import AreaChain

@MainActor struct CommandExecutionIntegrationTests {
    @Test func fanoutReferencesCanBeExplicitlyRepairedAfterProducerEdit() throws {
        let fixture = try HandoffFixture()
        let producer = try fixture.queue(CommandIntegrationFixture.creation(host: HandoffFixture.source))
        let first = try fixture.queue(CommandIntegrationFixture.creation(host: HandoffFixture.source, child: true))
        let second = try fixture.queue(CommandIntegrationFixture.creation(host: HandoffFixture.source, child: true))
        try fixture.reference(first, producer: producer)
        try fixture.reference(second, producer: producer)
        try fixture.editItem(producer, argument: PlanFixture.argument(.title, .shortText("合成修订标题")))
        let stale = try fixture.state().plan.check()
        #expect(stale.dependencies.contains(.staleReference(first, .parent)))
        #expect(stale.dependencies.contains(.staleReference(second, .parent)))
        #expect(!stale.canSealProtocol)
        #expect(throws: CommandHandoffError.invalidPlan) { try fixture.prepare() }
        let unchanged = try fixture.owned()
        let wrongType = CommandCreationReference(producer: try fixture.item(producer).stamp, outputType: .diary)
        #expect(throws: CommandPlanError.self) {
            try fixture.plan(.link(fixture.item(first).stamp, .init(results: [.parent: wrongType])))
        }
        #expect(throws: CommandPlanError.self) {
            try fixture.plan(.link(fixture.item(first).stamp, fixture.item(first).links))
        }
        #expect(try fixture.owned() == unchanged)
        // 逐个显式刷新，不重新搜索、不自动换绑或构造内部“有效”状态。
        try fixture.reference(first, producer: producer)
        #expect(try fixture.state().plan.check().dependencies == [.staleReference(second, .parent)])
        #expect(throws: CommandPlanError.incomplete) { try fixture.seal() }
        try fixture.reference(second, producer: producer)
        #expect(try fixture.state().plan.check().canSealProtocol)
        try fixture.transfer()
        let target = try fixture.state(HandoffFixture.target)
        #expect(target.plan.check().dependencies.isEmpty)
        for id in [first, second] {
            #expect(try fixture.item(id, host: HandoffFixture.target).links.results[.parent]?.producer
                    == fixture.item(producer, host: HandoffFixture.target).stamp)
        }
    }

    @Test func dependencyPlanAndSyntheticFailureRecoveryContinueAfterHandoff() throws {
        let fixture = try HandoffFixture()
        let producer = try fixture.queue(CommandIntegrationFixture.creation(host: HandoffFixture.source))
        let child = try fixture.queue(CommandIntegrationFixture.creation(host: HandoffFixture.source, child: true))
        try fixture.reference(child, producer: producer)
        let independent = try fixture.queue(HandoffFixture.setting())
        let later = try fixture.queue(HandoffFixture.setting(value: "english"))
        try fixture.plan(.link(fixture.item(later).stamp, .init(predecessors: [producer])))
        let protected = try fixture.owned()
        #expect(throws: CommandPlanError.self) { try fixture.plan(.reorder([child, producer, independent, later])) }
        #expect(throws: CommandPlanError.dependents([child, later])) {
            try fixture.send(.removeFromPlan(fixture.item(producer).stamp, fixture.state().plan.stamp))
        }
        #expect(throws: CommandPlanError.mergeConflict(.dependency)) {
            try fixture.plan(.merge(earlier: fixture.item(independent).stamp, later: fixture.item(later).stamp))
        }
        #expect(try fixture.owned() == protected)
        try fixture.plan(.link(fixture.item(later).stamp, .init()))
        try fixture.plan(.merge(earlier: fixture.item(independent).stamp, later: fixture.item(later).stamp))
        #expect(try fixture.item(independent).draft.arguments == [PlanFixture.argument(.value, .choice("english"))])
        try fixture.plan(.reorder([producer, independent, child]))
        try fixture.transfer()
        let target = HandoffFixture.target
        let plan = try fixture.state(target).plan
        let run = try fixture.seal(host: target)
        #expect(run.plan == plan.stamp)
        #expect(try fixture.state(target).plan.items.isEmpty)
        #expect(try fixture.state(target).execution?.snapshot.items == plan.items)
        #expect(throws: CommandHandoffError.ineligible) { try fixture.prepare() }
        let failed = try fixture.begin(host: target)
        #expect(failed.unitID == producer)
        try fixture.result(.failedWithoutCommit, attempt: failed, host: target)
        #expect(try fixture.state(target).execution?.units.first { $0.id == child }?.block == .predecessor(producer))
        let other = try fixture.begin(host: target)
        #expect(other.unitID == independent)
        try fixture.result(.committed(outputs: [:], external: []), attempt: other, host: target)
        #expect(throws: CommandExecutionError.requiresAdapterConfirmation) { try fixture.send(.retry(failed, .unverified), host: target) }
        try fixture.send(.retry(failed, .safeLocalReplay), host: target)
        #expect(throws: CommandExecutionError.stale) { try fixture.result(.failedWithoutCommit, attempt: failed, host: target) }
        let retry = try fixture.begin(host: target)
        #expect(retry.number == failed.number + 1 && retry.phase == .local)
        let object = CommandObjectReference(type: .todo, id: UUID())
        try fixture.result(.committed(outputs: [producer: object], external: []), attempt: retry, host: target)
        try finishBoundConsumer(fixture, producerAttempt: retry, child: child, object: object)
        let complete = try #require(fixture.state(target).execution)
        #expect(complete.units.allSatisfy { $0.state == .succeeded } && !complete.isExecutable)
        #expect(complete.units.first { $0.id == independent }?.attempt == 1)
        #expect(throws: CommandHandoffError.ineligible) { try fixture.prepare() }
        try fixture.send(.releaseExecution(run), host: target)
        let reverse = try fixture.coordinator.prepare(id: UUID(), source: fixture.owned(target).lease, target: fixture.owned().lease)
        try fixture.coordinator.confirm(reverse, readiness: .init())
        try fixture.coordinator.commit(reverse)
        #expect(fixture.coordinator.status(reverse.id) == .completed)
    }

    private func finishBoundConsumer(
        _ fixture: HandoffFixture, producerAttempt: CommandAttemptStamp, child: UUID, object: CommandObjectReference
    ) throws {
        let target = HandoffFixture.target
        let attempt = try fixture.begin(host: target)
        #expect(attempt.unitID == child)
        let execution = try #require(fixture.state(target).execution)
        let identity = try #require(execution.operation(child))
        #expect(identity.execution == attempt.execution && identity.operationID == child)
        #expect(execution.resolvedInput(child)?.arguments.contains(PlanFixture.argument(.parent, .object(object))) == true)
        #expect(execution.snapshot.items.first { $0.id == child }?.draft.arguments.contains { $0.parameter == .parent } == false)
        try fixture.result(.failedWithoutCommit, attempt: attempt, host: target)
        try fixture.send(.retry(attempt, .safeLocalReplay), host: target)
        let retry = try fixture.begin(host: target)
        #expect(try fixture.state(target).execution?.bindings[child]?[.parent] == object)
        #expect(try fixture.state(target).execution?.operation(child) == identity)
        #expect(throws: CommandExecutionError.stale) {
            try fixture.result(.committed(outputs: [producerAttempt.unitID: .init(type: .todo, id: UUID())], external: []),
                               attempt: producerAttempt, host: target)
        }
        let receipt = CommandExecutionReceipt(attempt: retry, result: .committed(outputs: [:], external: []))
        try fixture.send(.result(receipt), host: target)
        let completed = try fixture.state(target).execution
        guard case .receipt(let accepted) = try fixture.send(.result(receipt), host: target) else {
            Issue.record("应返回纯回执受理结果"); return
        }
        #expect(!accepted)
        #expect(try fixture.state(target).execution == completed)
        let oldVersion = CommandPlanStamp(hostID: retry.execution.plan.hostID, planID: retry.execution.plan.planID,
                                          revision: retry.execution.plan.revision - 1)
        let stale = CommandAttemptStamp(execution: .init(runID: retry.execution.runID, plan: oldVersion),
                                        unitID: child, number: retry.number, phase: retry.phase)
        #expect(throws: CommandExecutionError.stale) { try fixture.result(.failedWithoutCommit, attempt: stale, host: target) }
        #expect(try fixture.state(target).execution == completed)
    }

    @Test func committedCreationOnlyRetriesFailedExternalEffectAndRetainsOutput() throws {
        let fixture = try HandoffFixture()
        let producer = try fixture.queue(CommandIntegrationFixture.creation(host: HandoffFixture.source))
        let child = try fixture.queue(CommandIntegrationFixture.creation(host: HandoffFixture.source, child: true))
        try fixture.reference(child, producer: producer)
        let run = try fixture.seal()
        let local = try fixture.begin(), object = CommandObjectReference(type: .todo, id: UUID())
        try fixture.result(.committed(outputs: [producer: object], external: [.notification, .calendar]), attempt: local)
        let external = try fixture.begin()
        #expect(external.phase == .external)
        try fixture.result(.external([.notification: .succeeded, .calendar: .failed]), attempt: external)
        #expect(throws: CommandExecutionError.requiresAdapterConfirmation) { try fixture.send(.retry(external, .safeLocalReplay)) }
        #expect(throws: CommandHandoffError.ineligible) { try fixture.prepare() }
        #expect(try fixture.state().execution?.units.first { $0.id == child }?.state == .blocked)
        try fixture.send(.retry(external, .idempotentExternal([.calendar])))
        let retry = try fixture.begin()
        #expect(retry.phase == .external && retry.number == external.number + 1)
        let current = try #require(fixture.state().execution)
        #expect(current.units[0].local == .committed && current.units[0].effects[.notification] == .succeeded)
        #expect(current.outputs[producer] == object)
        #expect(throws: CommandExecutionError.invalidResult) {
            try fixture.result(.committed(outputs: [producer: .init(type: .todo, id: UUID())], external: []), attempt: retry)
        }
        #expect(throws: CommandExecutionError.stale) {
            try fixture.result(.external([.notification: .succeeded, .calendar: .failed]), attempt: external)
        }
        try fixture.result(.external([.calendar: .succeeded]), attempt: retry)
        let dependent = try fixture.begin()
        #expect(dependent.unitID == child && dependent.phase == .local)
        #expect(try fixture.state().execution?.bindings[child]?[.parent] == object)
        try fixture.result(.committed(outputs: [:], external: []), attempt: dependent)
        #expect(throws: CommandHandoffError.ineligible) { try fixture.prepare() }
        try fixture.send(.releaseExecution(run))
        try fixture.transfer()
    }

    @Test(arguments: [false, true])
    func unknownOutcomePreservesSnapshotAndCannotRetryReleaseOrTransfer(external: Bool) throws {
        let fixture = try HandoffFixture()
        let producer = try fixture.queue(CommandIntegrationFixture.creation(host: HandoffFixture.source))
        let child = try fixture.queue(CommandIntegrationFixture.creation(host: HandoffFixture.source, child: true))
        try fixture.reference(child, producer: producer)
        let run = try fixture.seal()
        var attempt = try fixture.begin()
        if external {
            try fixture.result(.committed(outputs: [producer: .init(type: .todo, id: UUID())], external: [.calendar]), attempt: attempt)
            attempt = try fixture.begin()
            try fixture.result(.external([.calendar: .unknown]), attempt: attempt)
        } else {
            try fixture.result(.commitUnknown, attempt: attempt)
        }
        let before = try fixture.owned()
        let execution = try #require(before.session.execution)
        #expect(execution.retryAssessment(attempt, assurance: .safeLocalReplay) == .requiresVerification)
        #expect(execution.units[0].local == (external ? .committed : .unknown))
        #expect(execution.units[1].state == .blocked && before.session.requiresUnsavedContentHandling)
        #expect(throws: CommandExecutionError.requiresVerification) {
            try fixture.send(.retry(attempt, external ? .idempotentExternal([.calendar]) : .safeLocalReplay))
        }
        #expect(throws: CommandExecutionError.busy) { try fixture.send(.releaseExecution(run)) }
        #expect(throws: CommandHandoffError.ineligible) { try fixture.prepare() }
        #expect(try fixture.owned() == before)
        let descriptions = [String(reflecting: execution), String(reflecting: execution.snapshot),
                            String(reflecting: execution.units[0].receipt), String(describing: CommandExecutionError.requiresVerification)]
        #expect(descriptions.allSatisfy { !$0.contains("Synthetic task") })
    }
}
