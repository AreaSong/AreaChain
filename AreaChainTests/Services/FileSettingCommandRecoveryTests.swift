import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct FileSettingCommandRecoveryTests {
    @Test(arguments: [LocalPreferenceFileFault.encoding, .temporaryWrite, .qualification, .replaceBefore, .replaceAfter, .readback, .cleanupBefore])
    func realFaultsKeepWholeLocalStateAndDoNotReplay(fault: LocalPreferenceFileFault) throws {
        let fixture = try FileSettingCommandFixture(fault: fault)
        try fixture.group(4)
        let original = try #require(fixture.prefs.committedLocalPreferenceRecord)
        let report = try fixture.submit()
        #expect(fixture.store.metrics.snapshot().commits == 1)
        if fault == .cleanupBefore {
            #expect((try? fixture.unit().local) == .committed)
            guard case .preferenceGroupCommit(.committed(_, cleanupPending: true)) = report.localReceipt.result else {
                Issue.record("清理待处理不能否定共同保存"); return
            }
            #expect(fixture.prefs.language == .english && fixture.io.events.count == 1)
        } else {
            #expect(fixture.prefs.committedLocalPreferenceRecord == original && fixture.io.events.isEmpty)
            let unknown = [.replaceBefore, .replaceAfter, .readback].contains(fault)
            #expect(try fixture.unit().local == (unknown ? .unknown : .notSubmitted))
            #expect(!fixture.prefs.canWriteLocalPreferences)
            if unknown {
                #expect(throws: FileLocalSettingCommandIssue.notRetryable) {
                    try fixture.adapter.returnUnsubmittedToPlan(report.localReceipt.attempt, expecting: fixture.owned().lease)
                }
                #expect(throws: CommandExecutionError.requiresVerification) {
                    try fixture.handoff.send(.retry(report.localReceipt.attempt, .safeLocalReplay))
                }
            }
        }
        let count = fixture.store.metrics.snapshot().commits
        fixture.prefs.appearance = .light
        #expect(fixture.store.metrics.snapshot().commits == count)
    }

    @Test func unknownExactIdentityVerificationUpdatesOriginalRunBeforePublication() throws {
        let fixture = try FileSettingCommandFixture(fault: .replaceAfter)
        try fixture.group(4)
        let report = try fixture.submit()
        fixture.io.onAppearance = { #expect((try? fixture.unit().local) == .committed) }
        let verified = try fixture.adapter.verifyCommit(report.localReceipt.attempt, expecting: fixture.owned().lease)
        #expect(verified.localReceipt == report.localReceipt && verified.verificationReceipt != nil)
        #expect(verified.identity == report.identity && verified.presentationReceipt?.attempt.phase == .external)
        #expect(try fixture.unit().local == .committed && fixture.unit().state == .succeeded)
        #expect(fixture.store.metrics.snapshot().commits == 1 && fixture.store.metrics.snapshot().replacements == 1)
        #expect(fixture.io.events.count == 1 && fixture.io.appearances == [.dark])
        #expect(throws: FileLocalSettingCommandIssue.notRetryable) {
            try fixture.adapter.verifyCommit(report.localReceipt.attempt, expecting: fixture.owned().lease)
        }
    }

    @Test func equalValuesWithDifferentIdentityRemainUnknownAndSupersededNeverRollsBack() throws {
        let fixture = try FileSettingCommandFixture(fault: .replaceAfter)
        try fixture.group()
        let report = try fixture.submit()
        let submitted = try fixture.io.legacy.files.current()
        let other = try submitted.changing([.language(.english)])
        try fixture.io.legacy.files.write(other, name: "current.json")
        let verified = try fixture.adapter.verifyCommit(report.localReceipt.attempt, expecting: fixture.owned().lease)
        guard case .superseded = verified.recovery else { Issue.record("仅值相等不足以确认原提交"); return }
        #expect(verified.verificationReceipt == nil && verified.localReceipt == report.localReceipt)
        #expect(try fixture.unit().local == .unknown && fixture.io.legacy.files.current() == other)
        #expect(fixture.store.metrics.snapshot().commits == 1 && fixture.io.events.isEmpty)
        #expect(!fixture.prefs.canWriteLocalPreferences)
    }

    @Test func baseStillPresentIsHistoricalUnknownAndRestartDoesNotRestoreQueue() throws {
        let fixture = try FileSettingCommandFixture(fault: .replaceBefore)
        try fixture.group()
        let report = try fixture.submit()
        let verified = try fixture.adapter.verifyCommit(report.localReceipt.attempt, expecting: fixture.owned().lease)
        guard case .historicalUnknown = verified.recovery else { Issue.record("旧文件不证明历史未提交"); return }
        #expect(try fixture.unit().local == .unknown && fixture.store.metrics.snapshot().replacements == 0)
        let restarted = try HandoffFixture()
        let adapter = try FileLocalSettingCommandAdapter(coordinator: restarted.coordinator, filePreferences: fixture.prefs)
        #expect(throws: FileLocalSettingCommandIssue.notRetryable) {
            try adapter.verifyCommit(report.localReceipt.attempt, expecting: restarted.owned().lease)
        }
        #expect(try restarted.state().execution == nil)
    }

    @Test func failedPresentationRetriesOnlyLedgerAndLaterSameFieldSupersedes() throws {
        let fixture = try FileSettingCommandFixture()
        try fixture.group()
        fixture.io.failAppearance = true
        let report = try fixture.submit()
        #expect(try fixture.unit().local == .committed && fixture.unit().state == .failed)
        #expect(fixture.io.events.count == 1)
        fixture.io.failAppearance = false
        let retried = try fixture.adapter.retryPresentation(report.latestAttempt, expecting: fixture.owned().lease)
        #expect(retried.localReceipt == report.localReceipt && retried.latestAttempt.number > report.latestAttempt.number)
        #expect(fixture.io.events.count == 1 && fixture.io.appearances == [.dark, .dark])
        #expect(fixture.store.metrics.snapshot().commits == 1 && fixture.store.metrics.snapshot().replacements == 1)
        let replaced = try FileSettingCommandFixture()
        try replaced.group()
        replaced.io.failAppearance = true
        let old = try replaced.submit()
        replaced.io.failAppearance = false
        replaced.prefs.appearance = .light
        let count = replaced.store.metrics.snapshot().commits
        let superseded = try replaced.adapter.retryPresentation(old.latestAttempt, expecting: replaced.owned().lease)
        guard case .preferenceGroupPresentation(let presentation) = superseded.presentationReceipt?.result else {
            Issue.record("缺少展示结果"); return
        }
        #expect(presentation.appearance == .superseded)
        #expect(replaced.io.appearances == [.dark, .light] && replaced.store.metrics.snapshot().commits == count)
        #expect(try replaced.unit().local == .committed)
    }

    @Test func unrelatedFieldChangeDoesNotCancelPendingAppearance() throws {
        let fixture = try FileSettingCommandFixture()
        try fixture.group()
        fixture.io.failAppearance = true
        fixture.io.failEvent = true
        let report = try fixture.submit()
        fixture.io.failAppearance = false
        fixture.io.failEvent = false
        fixture.prefs.stampCaptureApp = true
        let calls = fixture.store.metrics.snapshot().commits
        _ = try fixture.adapter.retryPresentation(report.latestAttempt, expecting: fixture.owned().lease)
        #expect(fixture.store.metrics.snapshot().commits == calls && fixture.io.appearances == [.dark, .dark])
        #expect(try fixture.unit().state == .succeeded)
    }

    @Test func oldPresentationReportDisappearsOnceProtocolRetryClearsReceipt() throws {
        let fixture = try FileSettingCommandFixture()
        try fixture.group()
        fixture.io.failEvent = true
        let report = try fixture.submit()
        try fixture.handoff.send(.retry(report.latestAttempt, .idempotentExternal([.preferencePresentation])))
        #expect(try fixture.adapter.report(for: report.identity.execution, expecting: fixture.owned().lease) == nil)
        #expect(throws: FileLocalSettingCommandIssue.notRetryable) {
            try fixture.adapter.retryPresentation(report.latestAttempt, expecting: fixture.owned().lease)
        }
        #expect(fixture.store.metrics.snapshot().commits == 1)
    }
}
