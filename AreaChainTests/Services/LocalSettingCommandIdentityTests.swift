import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct LocalSettingCommandIdentityTests {
    @Test func duplicateReentryAndForgedProtocolReceiptCannotWriteAgain() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        try fixture.queue()
        let request = try fixture.request()
        var nestedCalls = 0
        fixture.io.onWrite = {
            nestedCalls += 1
            #expect(throws: LocalSettingCommandIssue.busy) { try fixture.adapter.execute(request) }
            #expect(throws: CommandExecutionError.busy) {
                try fixture.handoff.send(.result(.init(attempt: request.attempt, result: .failedWithoutCommit)))
            }
            #expect(throws: CommandExecutionError.stale) {
                try fixture.handoff.coordinator.claimPreferenceInvocation(request.operation, attempt: request.attempt, expecting: request.lease)
            }
        }
        fixture.io.onEvent = { #expect(throws: LocalSettingCommandIssue.busy) { try fixture.adapter.execute(request) } }
        let report = try fixture.adapter.execute(request)
        #expect(nestedCalls == 1 && fixture.io.writes.count == 1 && fixture.io.local.events.count == 1)
        #expect(throws: CommandHandoffError.stale) { try fixture.adapter.execute(request) }
        let repeated = try fixture.handoff.send(.result(report.receipt))
        guard case .receipt(let accepted) = repeated else { Issue.record("期望回执响应"); return }
        #expect(!accepted && fixture.io.writes.count == 1)
    }

    @Test func oldLeaseRunAttemptAndOperationCannotInvokeStorage() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        try fixture.queue()
        let request = try fixture.request()
        let future = CommandAttemptStamp(execution: request.attempt.execution, unitID: request.attempt.unitID,
            number: request.attempt.number + 1, phase: .local)
        let foreign = CommandExecutionStamp(runID: UUID(), plan: request.attempt.execution.plan)
        let staleRun = CommandAttemptStamp(execution: foreign, unitID: request.attempt.unitID, number: 1, phase: .local)
        for attempt in [future, staleRun] {
            #expect(throws: LocalSettingCommandIssue.stale) {
                try fixture.adapter.execute(.init(lease: request.lease, operation: request.operation, attempt: attempt))
            }
        }
        let wrongOperation = CommandOperationIdentity(execution: request.operation.execution,
            item: .init(id: request.operation.item.id, version: request.operation.item.version + 1), operationID: request.operation.operationID)
        #expect(throws: LocalSettingCommandIssue.stale) {
            try fixture.adapter.execute(.init(lease: request.lease, operation: wrongOperation, attempt: request.attempt))
        }
        try fixture.handoff.send(.query(.privacyInvalidated))
        #expect(throws: CommandHandoffError.stale) { try fixture.adapter.execute(request) }
        #expect(fixture.io.writes.isEmpty && fixture.io.local.events.isEmpty)
    }

    @Test func readCallbackInvalidatesLeaseBeforeWriteAndPostWriteChangeStillCompletesOriginalRun() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        try fixture.queue()
        let request = try fixture.request()
        fixture.io.resetCounts()
        fixture.io.onRead = { _, count in
            if count == 2 { try fixture.handoff.send(.query(.privacyInvalidated)) }
        }
        let refused = try fixture.adapter.execute(request)
        guard case .write(let rejection) = refused.outcome else { Issue.record("共享入口应写前拒绝"); return }
        #expect(rejection.write == .notCalled && rejection.rejection == .executionInvalidated)
        #expect(fixture.io.writes.isEmpty)
        try fixture.adapter.returnUnsubmittedToPlan(request.attempt, expecting: fixture.owned().lease)
        fixture.io.onRead = nil
        fixture.io.onEvent = { _ = try? fixture.handoff.send(.query(.privacyInvalidated)) }
        let report = try fixture.submit()
        #expect(try fixture.unit().receipt == report.receipt && fixture.unit().state == .succeeded)
        #expect(report.operation.execution != request.operation.execution && fixture.io.writes.count == 1)
        #expect(throws: CommandHandoffError.stale) { try fixture.adapter.execute(request) }
    }

    @Test(arguments: [false, true])
    func multiItemPlansAndAtomicGroupsAreRejectedBeforeSealAndBeforeExecute(atomic: Bool) throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        let first = try fixture.queue()
        let second = try fixture.queue("setting.appearance", value: .choice("dark"))
        if atomic { try fixture.handoff.plan(.atomicGroup(UUID(), members: [first, second])) }
        let before = try fixture.owned()
        #expect(throws: LocalSettingCommandIssue.multipleOperations) { try fixture.submit() }
        #expect(try fixture.owned() == before)
        #expect(fixture.io.writes.isEmpty && fixture.io.local.appearances.isEmpty && fixture.io.local.events.isEmpty)
        _ = try fixture.handoff.seal()
        let attempt = try fixture.handoff.begin()
        let request = try LocalSettingCommandRequest(lease: fixture.owned().lease,
            operation: #require(fixture.state().execution?.operation(first)), attempt: attempt)
        #expect(throws: LocalSettingCommandIssue.multipleOperations) { try fixture.adapter.execute(request) }
        #expect(try fixture.state().execution?.snapshot.items.count == 2)
        #expect(fixture.io.writes.isEmpty)
    }

    @Test func activeDraftBesidePlanAndMissingRealBaselineRemainBlocked() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        try fixture.queue()
        try fixture.handoff.start(HandoffFixture.setting(value: "chinese"))
        let before = try fixture.owned()
        #expect(throws: LocalSettingCommandIssue.multipleOperations) { try fixture.submit() }
        #expect(try fixture.owned() == before && fixture.io.writes.isEmpty)
    }

    @Test func ordinaryHandoffCarriesEvidenceButOldLeaseCannotUseIt() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        try fixture.queue()
        let old = try fixture.owned()
        let evidence = old.session.plan.items[0].draft.baseline
        try fixture.handoff.transfer()
        let moved = try fixture.handoff.owned(HandoffFixture.target)
        #expect(moved.session.plan.items[0].draft.baseline == evidence)
        #expect(throws: CommandHandoffError.stale) {
            try fixture.adapter.submit(plan: old.session.plan.stamp, expecting: old.lease)
        }
        let report = try fixture.adapter.submit(plan: moved.session.plan.stamp, expecting: moved.lease)
        #expect(report.operation.execution.plan.hostID == HandoffFixture.target)
        #expect(fixture.io.writes == [.language(.english)])
    }
}
