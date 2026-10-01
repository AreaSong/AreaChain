import Foundation
import Testing
@testable import AreaChain

struct CommandExecutionTests {
    @Test func sealedSnapshotIsImmutableAndDuplicateOrForeignSubmissionCannotReplayIt() throws {
        var host = PlanFixture.host()
        let id = try PlanFixture.queue(PlanFixture.todo(), in: &host)
        let oldPlan = host.plan.stamp, oldItem = try PlanFixture.item(id, in: host).stamp, runID = UUID()
        try host.sealPlanForProtocol(oldPlan, runID: runID)
        let snapshot = host.execution?.snapshot
        #expect(host.plan.items.isEmpty && host.operations.active == nil)
        #expect(throws: CommandPlanError.busy) { try host.sealPlanForProtocol(oldPlan, runID: runID) }
        let next = try PlanFixture.queue(PlanFixture.setting(), in: &host)
        try PlanFixture.edit(next, argument: PlanFixture.argument(.value, .choice("english")), in: &host)
        #expect(host.execution?.snapshot == snapshot)
        #expect(throws: CommandPlanError.stale) { try host.planEvent(.beginEditing(oldItem), expecting: host.plan.stamp) }
        #expect(throws: CommandPlanError.stale) {
            try host.planEvent(.merge(earlier: oldItem, later: PlanFixture.item(next, in: host).stamp), expecting: host.plan.stamp)
        }
        let attempt = try PlanFixture.begin(&host)
        let receipt = CommandExecutionReceipt(attempt: attempt, result: .committed(outputs: [:], external: []))
        #expect(try host.receiveProtocolResult(receipt))
        let succeeded = host.execution
        #expect(try !host.receiveProtocolResult(receipt))
        #expect(host.execution == succeeded)
        let foreign = CommandAttemptStamp(execution: .init(runID: UUID(), plan: oldPlan), unitID: id, number: 1, phase: .local)
        #expect(throws: CommandExecutionError.stale) { try host.receiveProtocolResult(.init(attempt: foreign, result: .failedWithoutCommit)) }
        try host.releaseSuccessfulExecution(expecting: #require(host.execution?.stamp))
        #expect(throws: CommandPlanError.duplicate) { try host.sealPlanForProtocol(host.plan.stamp, runID: runID) }
        try PlanFixture.seal(&host)
        #expect(throws: CommandExecutionError.stale) { try host.receiveProtocolResult(receipt) }
        #expect(host.execution?.snapshot.items[0].id == next)
    }

    @Test func oldAttemptsAndOutOfOrderResultsAreRejected() throws {
        var host = PlanFixture.host()
        try PlanFixture.queue(PlanFixture.todo(), in: &host)
        try PlanFixture.seal(&host)
        let first = try PlanFixture.begin(&host)
        let future = CommandAttemptStamp(execution: first.execution, unitID: first.unitID, number: first.number + 1, phase: .local)
        #expect(throws: CommandExecutionError.stale) { try PlanFixture.result(.failedWithoutCommit, attempt: future, in: &host) }
        #expect(throws: CommandExecutionError.busy) { _ = try PlanFixture.begin(&host) }
        try PlanFixture.result(.failedWithoutCommit, attempt: first, in: &host)
        #expect(host.execution?.retryAssessment(first, assurance: .unverified) == .requiresAdapterConfirmation)
        #expect(throws: CommandExecutionError.requiresAdapterConfirmation) { try host.retryProtocolStep(first, assurance: .unverified) }
        try host.retryProtocolStep(first, assurance: .safeLocalReplay)
        #expect(throws: CommandExecutionError.stale) { try PlanFixture.result(.failedWithoutCommit, attempt: first, in: &host) }
        let second = try PlanFixture.begin(&host)
        #expect(second == future)
        #expect(throws: CommandExecutionError.stale) { try PlanFixture.result(.committed(outputs: [:], external: []), attempt: first, in: &host) }
        try PlanFixture.result(.committed(outputs: [:], external: []), attempt: second, in: &host)
        #expect(throws: CommandExecutionError.notRetryable) { try host.retryProtocolStep(second, assurance: .safeLocalReplay) }
    }

    @Test func localCommitAndExternalFailureRetryNeverRecreate() throws {
        var host = PlanFixture.host()
        let id = try PlanFixture.queue(PlanFixture.todo(), in: &host)
        try PlanFixture.seal(&host)
        let local = try PlanFixture.begin(&host), object = CommandObjectReference(type: .todo, id: UUID())
        try PlanFixture.result(.committed(outputs: [id: object], external: [.notification, .calendar]), attempt: local, in: &host)
        #expect(host.execution?.units[0].local == .committed)
        let external = try PlanFixture.begin(&host)
        #expect(external.phase == .external && external.number == 2)
        try PlanFixture.result(.external([.notification: .succeeded, .calendar: .failed]), attempt: external, in: &host)
        #expect(host.execution?.units[0].state == .failed && host.execution?.units[0].local == .committed)
        #expect(throws: CommandExecutionError.requiresAdapterConfirmation) { try host.retryProtocolStep(external, assurance: .safeLocalReplay) }
        #expect(throws: CommandExecutionError.requiresAdapterConfirmation) {
            try host.retryProtocolStep(external, assurance: .idempotentExternal([.notification]))
        }
        try host.retryProtocolStep(external, assurance: .idempotentExternal([.calendar]))
        let retry = try PlanFixture.begin(&host)
        #expect(retry.phase == .external && host.execution?.outputs[id] == object)
        #expect(host.execution?.units[0].effects[.notification] == .succeeded)
        #expect(throws: CommandExecutionError.invalidResult) {
            try PlanFixture.result(.committed(outputs: [id: .init(type: .todo, id: UUID())], external: []), attempt: retry, in: &host)
        }
        try PlanFixture.result(.external([.calendar: .succeeded]), attempt: retry, in: &host)
        #expect(host.execution?.units[0].state == .succeeded && host.execution?.outputs[id] == object)
        #expect(!host.requiresUnsavedContentHandling)
        #expect(host.execution?.cancellationAssessment(id) == .cannotCancelCommitted)
    }

    @Test func unknownLocalOrExternalCommitRequiresVerificationRegardlessOfAssurance() throws {
        var localHost = PlanFixture.host()
        try PlanFixture.queue(PlanFixture.todo(), in: &localHost)
        try PlanFixture.seal(&localHost)
        let local = try PlanFixture.begin(&localHost)
        try PlanFixture.result(.commitUnknown, attempt: local, in: &localHost)
        #expect(localHost.execution?.units[0].state == .verificationRequired)
        #expect(throws: CommandExecutionError.requiresVerification) { try localHost.retryProtocolStep(local, assurance: .safeLocalReplay) }
        #expect(throws: CommandExecutionError.busy) { try localHost.releaseSuccessfulExecution(expecting: local.execution) }
        var externalHost = PlanFixture.host()
        try PlanFixture.queue(PlanFixture.todo(), in: &externalHost)
        try PlanFixture.seal(&externalHost)
        let first = try PlanFixture.begin(&externalHost)
        try PlanFixture.result(.committed(outputs: [:], external: [.calendar]), attempt: first, in: &externalHost)
        let external = try PlanFixture.begin(&externalHost)
        try PlanFixture.result(.external([.calendar: .unknown]), attempt: external, in: &externalHost)
        #expect(externalHost.execution?.units[0].local == .committed)
        #expect(throws: CommandExecutionError.requiresVerification) {
            try externalHost.retryProtocolStep(external, assurance: .idempotentExternal([.calendar]))
        }
        #expect(externalHost.requiresUnsavedContentHandling && localHost.requiresUnsavedContentHandling)
    }

    @Test func cancellationOnlyMarksUnstartedAndAuthorizationDoesNotBecomeExecutionPermission() throws {
        var host = PlanFixture.host()
        let first = try PlanFixture.queue(PlanFixture.todo(), in: &host)
        let next = try PlanFixture.queue(PlanFixture.setting(), in: &host)
        try PlanFixture.seal(&host)
        let stamp = try #require(host.execution?.stamp)
        #expect(host.execution?.cancellationAssessment(first) == .canMarkNotStarted)
        try host.cancelUnstartedProtocolStep(first, expecting: stamp)
        #expect(host.execution?.units[0].state == .notExecuted)
        let attempt = try PlanFixture.begin(&host)
        #expect(attempt.unitID == next)
        #expect(throws: CommandExecutionError.requiresAdapterConfirmation) { try host.cancelUnstartedProtocolStep(next, expecting: stamp) }
        try PlanFixture.result(.waitingAuthorization, attempt: attempt, in: &host)
        #expect(host.execution?.units[1].state == .waitingAuthorization && host.isBusy)
        #expect(host.execution?.isExecutable == false && host.plan.check().isExecutable == false)
        #expect(host.execution?.retryAssessment(attempt, assurance: .safeLocalReplay) == .notRetryable)
        try host.resolveProtocolValidation(attempt, resolution: .readyForProtocol)
        #expect(host.execution?.isExecutable == false && !host.isBusy)
        let resumed = try PlanFixture.begin(&host)
        #expect(resumed.number == attempt.number + 1)
        #expect(throws: CommandExecutionError.stale) {
            try host.resolveProtocolValidation(attempt, resolution: .readyForProtocol)
        }
        try PlanFixture.result(.notExecuted, attempt: resumed, in: &host)
        #expect(host.execution?.units[1].state == .notExecuted)
    }
}
