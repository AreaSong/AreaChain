import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchSettingLifecycleTests {
    @Test(arguments: [LocalSettingConflictChoice.adoptCurrent, .confirmOverwrite, .continueEditing])
    func conflictChoicesUseAdapterEvidence(choice: LocalSettingConflictChoice) throws {
        let fixture = try UnifiedSearchSettingFixture()
        defer { fixture.stop() }
        try fixture.start()
        let baseline = try fixture.draft.baseline.preference
        fixture.prefs.language = .chinese
        fixture.io.resetCounts()
        fixture.submit()
        #expect(fixture.controller.settingExecution == nil && fixture.io.writes.isEmpty)
        let confirmation = try fixture.conflict()
        #expect(confirmation.evidence.conflict.baseline == baseline)
        #expect(confirmation.evidence.conflict.current.value == .language(.chinese))
        fixture.controller.resolveSettingConflict(confirmation, choice: choice)
        #expect(fixture.io.writes.isEmpty)
        fixture.submit()
        switch choice {
        case .adoptCurrent:
            #expect(try fixture.report.outcome == .noChange)
            #expect(fixture.io.writes.isEmpty && fixture.io.local.events.isEmpty)
        case .confirmOverwrite:
            #expect(fixture.io.writes == [.language(.english)])
            #expect(try fixture.unit.state == .succeeded)
        case .continueEditing:
            #expect(try fixture.draft.baseline.preference == baseline)
            #expect(fixture.controller.settingExecution == nil && fixture.io.writes.isEmpty)
            #expect(fixture.prefs.language == .chinese)
        }
    }

    @Test func expiredConfirmationAndExternalABARequireNewDecision() throws {
        let fixture = try UnifiedSearchSettingFixture()
        defer { fixture.stop() }
        try fixture.start()
        fixture.prefs.language = .chinese
        let confirmation = try fixture.conflict()
        fixture.prefs.language = .system
        fixture.io.resetCounts()
        fixture.controller.resolveSettingConflict(confirmation, choice: .confirmOverwrite)
        #expect(fixture.controller.settingConfirmation == nil)
        #expect(try fixture.draft.baseline.preference?.revision == 0)
        fixture.submit()
        #expect(fixture.io.writes.isEmpty && fixture.controller.settingExecution == nil)
        let current = try fixture.conflict()
        fixture.controller.resolveSettingConflict(confirmation, choice: .adoptCurrent)
        #expect(fixture.controller.settingConfirmation?.evidence == current.evidence)
        fixture.controller.resolveSettingConflict(current, choice: .confirmOverwrite)
        fixture.prefs.language = .chinese
        fixture.io.resetCounts()
        fixture.submit()
        #expect(fixture.io.writes.isEmpty && fixture.controller.settingExecution == nil)
    }

    @Test(arguments: [PreferenceCommandIO.WriteMode.drop, .throwBefore, .throwAfter, .unreadableAfter])
    func unknownHasNoRetryNoReleaseAndKeepsRun(mode: PreferenceCommandIO.WriteMode) throws {
        let fixture = try UnifiedSearchSettingFixture()
        defer { fixture.stop() }
        try fixture.start()
        fixture.io.mode = mode
        fixture.submit()
        let run = try fixture.run
        let report = try fixture.report
        #expect(try fixture.unit.local == .unknown)
        #expect(!fixture.adapter.canRetryPresentation(report.receipt.attempt, expecting: fixture.controller.buffer.lease))
        #expect(!fixture.adapter.canReturnToPlan(report.receipt.attempt, expecting: fixture.controller.buffer.lease))
        fixture.controller.retrySettingPresentation(report, source: fixture.controller.buffer)
        fixture.controller.returnSettingToPlan(report, source: fixture.controller.buffer)
        fixture.controller.acknowledgeSettingResult(report, source: fixture.controller.buffer)
        fixture.submit()
        #expect(try fixture.run == run && fixture.io.writes.count == 1)
    }

    @Test(arguments: [false, true])
    func displayRetryNeverRewritesAndLaterModificationSupersedes(superseded: Bool) throws {
        let fixture = try UnifiedSearchSettingFixture()
        defer { fixture.stop() }
        try fixture.start("setting.appearance", value: .choice("dark"))
        fixture.io.failAppearance = true
        fixture.submit()
        let first = try fixture.report
        #expect(try fixture.unit.local == .committed && fixture.unit.state == .failed)
        #expect(fixture.adapter.canRetryPresentation(first.receipt.attempt, expecting: fixture.controller.buffer.lease))
        fixture.io.failAppearance = false
        if superseded { fixture.prefs.appearance = .light }
        fixture.io.resetCounts()
        fixture.controller.retrySettingPresentation(first, source: fixture.controller.buffer)
        let second = try fixture.report
        #expect(second.operation == first.operation && second.receipt.attempt.number == first.receipt.attempt.number + 1)
        #expect(fixture.io.writes.isEmpty && fixture.io.local.events.isEmpty)
        if superseded {
            #expect(second.outcome == .presentation(.superseded))
            #expect(fixture.io.local.appearances.isEmpty)
            #expect(!fixture.adapter.canRetryPresentation(second.receipt.attempt, expecting: fixture.controller.buffer.lease))
        } else {
            #expect(fixture.io.local.appearances == [.dark])
            #expect(try fixture.unit.state == .succeeded)
        }
    }

    @Test(arguments: [false, true])
    func displayRevokedBeforeWriteRejectsAndAfterWritePreservesFacts(afterWrite: Bool) throws {
        let fixture = try UnifiedSearchSettingFixture()
        defer { fixture.stop() }
        try fixture.start()
        let source = fixture.controller.buffer
        let revoke = { try? fixture.results.session.loseFocus(expecting: source.lease.ownership) }
        if afterWrite { fixture.io.onWrite = { _ = revoke() } }
        else {
            fixture.io.onRead = { _, _ in
                if fixture.controller.settingExecution != nil { _ = revoke() }
            }
        }
        fixture.submit()
        #expect(!fixture.controller.operationVisible)
        #expect(fixture.controller.settingReport == nil)
        let run = try fixture.run
        #expect(try fixture.unit.local == (afterWrite ? .committed : .notSubmitted))
        #expect(fixture.io.writes.count == (afterWrite ? 1 : 0))
        fixture.io.onRead = nil
        try fixture.results.session.resumeDisplay(expecting: fixture.controller.buffer.lease)
        fixture.controller.refreshOperationPresentation()
        #expect(fixture.controller.settingReport == (try fixture.report))
        fixture.controller.requestOperationSubmit(source)
        #expect(try fixture.run == run && fixture.io.writes.count == (afterWrite ? 1 : 0))
    }

    @Test func postSealConflictReturnsOnlyUnsubmittedOriginalItem() throws {
        let fixture = try UnifiedSearchSettingFixture()
        defer { fixture.stop() }
        try fixture.start()
        let draftID = try fixture.draft.id
        var changed = false
        fixture.io.onRead = { field, _ in
            guard field == .language, !changed, fixture.controller.settingExecution != nil else { return }
            changed = true
            fixture.io.local.defaults.set("chinese", forKey: AppPreferences.languageKey)
        }
        fixture.submit()
        fixture.io.onRead = nil
        let report = try fixture.report
        #expect(try fixture.unit.state == .conflict && fixture.io.writes.isEmpty)
        fixture.controller.returnSettingToPlan(report, source: fixture.controller.buffer)
        let item = try #require(fixture.controller.plan?.items.first)
        #expect(item.draft.id == draftID && item.id == report.operation.item.id)
        #expect(item.returnedAttempts == [report.receipt.attempt])
        #expect(fixture.controller.operations?.active == nil && fixture.controller.settingExecution == nil)
        #expect(fixture.io.writes.isEmpty)
    }

    @Test func oldBufferAndTransferredLeaseCannotSubmitNewOwnership() throws {
        let fixture = try UnifiedSearchSettingFixture()
        defer { fixture.stop() }
        try fixture.start()
        let old = fixture.controller.buffer
        try fixture.edit(.choice("chinese"))
        fixture.controller.requestOperationSubmit(old)
        #expect(fixture.io.writes.isEmpty)
        let beforeTransfer = fixture.controller.buffer
        _ = try fixture.results.handoff.transfer()
        fixture.controller.requestOperationSubmit(beforeTransfer)
        #expect(fixture.io.writes.isEmpty && fixture.controller.operations == nil)
        #expect(try fixture.results.handoff.state(HandoffFixture.target).operations.active?.arguments.first?.value == .choice("chinese"))
    }
}
