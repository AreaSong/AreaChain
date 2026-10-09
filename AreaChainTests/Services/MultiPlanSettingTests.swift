import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct MultiPlanSettingTests {
    @Test func ordinaryFieldsAndFileGroupKeepSeparateTransactionBoundaries() throws {
        let settings = try FileSettingCommandFixture()
        let fields = try TaskFieldCommandFixture()
        fields.io.notificationResult = .succeeded
        fields.io.calendarResult = .succeeded
        let fieldAdapter = TaskFieldCommandAdapter(coordinator: settings.handoff.coordinator, environment: fields.environment)
        try settings.handoff.queue(field(0, fields: fields))
        let first = try settings.queue(FileSettingCommandFixture.paths[0])
        let second = try settings.queue(FileSettingCommandFixture.paths[1])
        let group = UUID()
        try settings.handoff.plan(.atomicGroup(group, members: [first, second]))
        try settings.handoff.queue(field(2, fields: fields))
        let adapter = MultiPlanCommandAdapter(coordinator: settings.handoff.coordinator,
                                              adapters: .init(taskField: fieldAdapter, fileSettings: settings.adapter))
        let preview = try adapter.prepare(plan: settings.state().plan.stamp, expecting: settings.owned().lease)
        try adapter.submit(preview, expecting: settings.owned().lease)
        let run = try #require(settings.state().execution)
        #expect(run.units.count == 3 && run.units.allSatisfy { $0.state == .succeeded })
        #expect(run.units[1].id == group && run.units[1].members == [first, second])
        #expect(run.units[1].preferenceGroupCommit != nil && run.units[1].taskField == nil)
        #expect(fields.count("save") == 2 && fields.count("ui") == 2)
        #expect(settings.prefs.language == .english && settings.prefs.appearance == .dark)
        #expect(try settings.adapter.report(for: run.stamp, unitID: group, expecting: settings.owned().lease)?.identity.members.count == 2)
    }

    @Test func fileFailureKeepsEarlierLocalCommitAndDoesNotSplitGroup() throws {
        let settings = try FileSettingCommandFixture(fault: .temporaryWrite)
        let fields = try TaskFieldCommandFixture()
        fields.io.notificationResult = .succeeded
        fields.io.calendarResult = .succeeded
        let fieldAdapter = TaskFieldCommandAdapter(coordinator: settings.handoff.coordinator, environment: fields.environment)
        try settings.handoff.queue(field(0, fields: fields))
        let group = try settings.group(prepare: false)
        let adapter = MultiPlanCommandAdapter(coordinator: settings.handoff.coordinator,
                                              adapters: .init(taskField: fieldAdapter, fileSettings: settings.adapter))
        let preview = try adapter.prepare(plan: settings.state().plan.stamp, expecting: settings.owned().lease)
        try adapter.submit(preview, expecting: settings.owned().lease)
        let run = try #require(settings.state().execution)
        #expect(run.units[0].local == .committed && run.units[1].id == group)
        #expect(run.units[1].local == .notSubmitted && run.units[1].state == .failed)
        #expect(settings.store.metrics.snapshot().commits == 1 && settings.store.metrics.snapshot().replacements == 0)
        #expect(settings.io.events.isEmpty && fields.count("save") == 1)
    }

    private func field(_ kind: Int, fields: TaskFieldCommandFixture) -> CommandDraft {
        .init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: TaskFieldCommandFixture.command(kind)),
              targets: .init(.single, objects: [.init(type: .todo, id: fields.base.todo.id)]),
              arguments: [TaskFieldCommandFixture.argument(kind)])
    }
}

extension MultiPlanSettingTests {
    @Test func fileUnknownPausesIndependentItemsAndOnlyExactVerificationResumes() throws {
        let settings = try FileSettingCommandFixture(fault: .replaceAfter)
        let group = try settings.group(prepare: false)
        let fields = try TaskFieldCommandFixture()
        fields.io.notificationResult = .succeeded
        fields.io.calendarResult = .succeeded
        try settings.handoff.queue(field(0, fields: fields))
        let fieldAdapter = TaskFieldCommandAdapter(coordinator: settings.handoff.coordinator, environment: fields.environment)
        let adapter = MultiPlanCommandAdapter(coordinator: settings.handoff.coordinator,
                                              adapters: .init(taskField: fieldAdapter, fileSettings: settings.adapter))
        let preview = try adapter.prepare(plan: settings.state().plan.stamp, expecting: settings.owned().lease)
        #expect(throws: CommandExecutionError.requiresVerification) { try adapter.submit(preview, expecting: settings.owned().lease) }
        let before = try #require(settings.state().execution)
        #expect(before.hasUnknownCommit && fields.count("save") == 0)
        let attempt = try #require(before.attempt(group))
        let result = try settings.adapter.verifyCommit(attempt, expecting: settings.owned().lease)
        #expect(result.verificationReceipt != nil)
        try adapter.resume(expecting: settings.owned().lease)
        let after = try #require(settings.state().execution)
        #expect(after.stamp == before.stamp && after.units.allSatisfy { $0.state == .succeeded })
        #expect(settings.store.metrics.snapshot().commits == 1 && fields.count("save") == 1)
    }

    @Test func failedFilePresentationRetriesOnlyExternalLedger() throws {
        let settings = try FileSettingCommandFixture()
        let group = try settings.group(prepare: false)
        let fields = try TaskFieldCommandFixture()
        fields.io.notificationResult = .succeeded
        fields.io.calendarResult = .succeeded
        try settings.handoff.queue(field(0, fields: fields))
        let fieldAdapter = TaskFieldCommandAdapter(coordinator: settings.handoff.coordinator, environment: fields.environment)
        let adapter = MultiPlanCommandAdapter(coordinator: settings.handoff.coordinator,
                                              adapters: .init(taskField: fieldAdapter, fileSettings: settings.adapter))
        let preview = try adapter.prepare(plan: settings.state().plan.stamp, expecting: settings.owned().lease)
        settings.io.failAppearance = true
        try adapter.submit(preview, expecting: settings.owned().lease)
        let before = try #require(settings.state().execution)
        #expect(before.units[0].local == .committed && before.units[0].state == .failed)
        #expect(before.units[1].state == .succeeded)
        settings.io.failAppearance = false
        _ = try settings.adapter.retryPresentation(#require(before.attempt(group)), expecting: settings.owned().lease)
        let after = try #require(settings.state().execution)
        #expect(after.units.allSatisfy { $0.state == .succeeded })
        #expect(settings.store.metrics.snapshot().commits == 1 && settings.io.events.count == 1)
        #expect(fields.count("save") == 1 && after.units[1] == before.units[1])
    }
}

extension MultiPlanSettingTests {
    @Test func groupRetryRequiresBackendRecoveryAndKeepsOriginalGroupAttemptHistory() throws {
        let settings = try FileSettingCommandFixture(fault: .temporaryWrite)
        let group = try settings.group(prepare: false)
        let fields = try TaskFieldCommandFixture()
        fields.io.notificationResult = .succeeded
        fields.io.calendarResult = .succeeded
        try settings.handoff.queue(field(0, fields: fields))
        let fieldAdapter = TaskFieldCommandAdapter(coordinator: settings.handoff.coordinator, environment: fields.environment)
        let adapter = MultiPlanCommandAdapter(coordinator: settings.handoff.coordinator,
                                              adapters: .init(taskField: fieldAdapter, fileSettings: settings.adapter))
        let preview = try adapter.prepare(plan: settings.state().plan.stamp, expecting: settings.owned().lease)
        try adapter.submit(preview, expecting: settings.owned().lease)
        let before = try #require(settings.state().execution)
        let attempt = try #require(before.attempt(group))
        #expect(!adapter.canRetryLocal(attempt, expecting: try settings.owned().lease))
        try settings.adapter.recoverMultiBackend(attempt, expecting: settings.owned().lease)
        #expect(adapter.canRetryLocal(attempt, expecting: try settings.owned().lease))
        // 故障注入是持续故障：新尝试仍应确定失败，不能因恢复入口可用而伪报保存。
        try adapter.retryLocal(attempt, expecting: settings.owned().lease)
        let after = try #require(settings.state().execution)
        #expect(after.units[0].id == group && after.units[0].attempt == attempt.number + 1)
        #expect(after.units[0].history.first?.receipt?.attempt == attempt && after.units[0].state == .failed)
        #expect(after.units[1] == before.units[1] && fields.count("save") == 1)
        #expect(settings.store.metrics.snapshot().commits == 2 && settings.store.metrics.snapshot().replacements == 0)
    }
}

extension MultiPlanSettingTests {
    @Test func aPlanContainingOnlyOneSettingsGroupCannotUseLegacyReturnToDraft() throws {
        let settings = try FileSettingCommandFixture(fault: .temporaryWrite)
        let group = try settings.group(prepare: false)
        let adapter = MultiPlanCommandAdapter(coordinator: settings.handoff.coordinator, adapters: .init(fileSettings: settings.adapter))
        let preview = try adapter.prepare(plan: settings.state().plan.stamp, expecting: settings.owned().lease)
        try adapter.submit(preview, expecting: settings.owned().lease)
        let before = try #require(settings.state().execution)
        let attempt = try #require(before.attempt(group))
        #expect(before.units.count == 1 && before.units[0].local == .notSubmitted)
        #expect(throws: CommandExecutionError.notRetryable) {
            try settings.adapter.returnUnsubmittedToPlan(attempt, expecting: settings.owned().lease)
        }
        #expect(throws: CommandExecutionError.requiresAdapterConfirmation) {
            try settings.handoff.send(.resolveValidation(attempt, .readyForProtocol))
        }
        #expect(try settings.state().execution == before)
        #expect(settings.store.metrics.snapshot().commits == 1)
    }
}
