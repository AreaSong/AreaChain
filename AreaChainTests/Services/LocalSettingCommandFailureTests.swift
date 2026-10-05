import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct LocalSettingCommandFailureTests {
    @Test func writeCallAndReadbackMatrixRetainsUncertaintyAndNeverRetries() throws {
        let cases: [(PreferenceCommandIO.WriteMode, PreferenceCallOutcome, PreferenceReadback)] = [
            (.normal, .returned, .matches), (.drop, .returned, .differs),
            (.throwBefore, .threw, .differs), (.throwAfter, .threw, .matches),
            (.unreadableAfter, .returned, .unavailable), (.throwAfterUnreadable, .threw, .unavailable)
        ]
        for (mode, call, readback) in cases {
            let fixture = try LocalSettingCommandFixture()
            defer { fixture.cleanup() }
            try fixture.queue("setting.appearance", value: .choice("dark"))
            fixture.io.mode = mode
            let request = try fixture.request()
            let report = try fixture.adapter.execute(request)
            guard case .write(let result) = report.outcome else { Issue.record("必须保留真实调用"); continue }
            #expect(result.write == call && result.readback == readback)
            #expect(try fixture.unit().preferenceWrite?.write == call && fixture.unit().preferenceWrite?.readback == readback)
            let confirmed = call == .returned && readback == .matches
            #expect(try fixture.unit().local == (confirmed ? .committed : .unknown))
            #expect(try fixture.unit().state == (confirmed ? .succeeded : .verificationRequired))
            #expect(fixture.io.writes == [.appearance(.dark)])
            #expect(fixture.io.local.appearances == (readback == .matches ? [.dark] : []))
            #expect(fixture.io.local.events.count == (readback == .matches ? 1 : 0))
            #expect(throws: (any Error).self) { try fixture.adapter.execute(request) }
            #expect(throws: LocalSettingCommandIssue.notRetryable) {
                try fixture.adapter.returnUnsubmittedToPlan(request.attempt, expecting: fixture.owned().lease)
            }
            if !confirmed {
                #expect(throws: CommandExecutionError.requiresVerification) {
                    try fixture.handoff.send(.retry(request.attempt, .safeLocalReplay))
                }
                #expect(throws: LocalSettingCommandIssue.notRetryable) {
                    try fixture.adapter.retryPresentation(request.attempt, expecting: fixture.owned().lease)
                }
            }
            #expect(fixture.io.writes.count == 1)
        }
    }

    @Test func sharedEntryReadFailureBeforeWriteCanReturnToOriginalPlan() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        let id = try fixture.queue()
        let request = try fixture.request()
        fixture.io.resetCounts()
        fixture.io.onRead = { _, count in if count == 2 { throw PreferenceCommandIO.Failure.injected } }
        let report = try fixture.adapter.execute(request)
        guard case .write(let result) = report.outcome else { Issue.record("应进入共享入口的写前拒绝"); return }
        #expect(result.rejection == .unreadableStorage && result.write == .notCalled && result.readback == .notRead)
        #expect(try fixture.unit().state == .failed && fixture.unit().local == .notSubmitted)
        #expect(fixture.io.writes.isEmpty && fixture.io.local.events.isEmpty)
        try fixture.adapter.returnUnsubmittedToPlan(request.attempt, expecting: fixture.owned().lease)
        #expect(try fixture.state().plan.items[0].id == id)
        fixture.io.onRead = nil
        _ = try fixture.submit()
        #expect(fixture.io.writes == [.language(.english)])
    }

    @Test func secondReadChangingStorageIsAConflictWithNoWrite() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        try fixture.queue()
        let request = try fixture.request()
        fixture.io.resetCounts()
        fixture.io.onRead = { _, count in
            if count == 2 { fixture.io.local.defaults.set("chinese", forKey: AppPreferences.languageKey) }
        }
        let report = try fixture.adapter.execute(request)
        guard case .conflict = report.outcome else { Issue.record("写入前第二次读取必须核对"); return }
        #expect(fixture.io.writes.isEmpty && fixture.io.local.events.isEmpty)
        #expect(try fixture.unit().local == .notSubmitted)
    }

    @Test(arguments: [true, false])
    func presentationFailureKeepsCommitAndRetriesOnlyFailedStep(failAppearance: Bool) throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        try fixture.queue("setting.appearance", value: .choice("dark"))
        fixture.io.failAppearance = failAppearance
        fixture.io.failEvent = !failAppearance
        let report = try fixture.submit()
        guard case .write(let result) = report.outcome else { Issue.record("缺写入事实"); return }
        #expect(result.write == .returned && result.readback == .matches)
        #expect(result.appearance == (failAppearance ? .threw : .returned))
        #expect(result.event == (failAppearance ? .returned : .threw))
        #expect(try fixture.unit().local == .committed && fixture.unit().state == .failed)
        #expect(try fixture.unit().effects == [.preferencePresentation: .failed])
        fixture.io.failAppearance = false
        fixture.io.failEvent = false
        let retry = try fixture.adapter.retryPresentation(report.receipt.attempt, expecting: fixture.owned().lease)
        #expect(retry.receipt.attempt.phase == .external)
        #expect(try fixture.unit().local == .committed && fixture.unit().state == .succeeded)
        #expect(fixture.io.writes.count == 1)
        #expect(fixture.io.local.appearances.count == (failAppearance ? 2 : 1))
        #expect(fixture.io.local.events.count == (failAppearance ? 1 : 2))
    }

    @Test func bothEffectsFailAndSuccessfulRetryStepIsNotRepeated() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        try fixture.queue("setting.appearance", value: .choice("dark"))
        fixture.io.failAppearance = true
        fixture.io.failEvent = true
        let report = try fixture.submit()
        fixture.io.failAppearance = false
        let first = try fixture.adapter.retryPresentation(report.receipt.attempt, expecting: fixture.owned().lease)
        #expect(try fixture.unit().local == .committed && fixture.unit().state == .failed)
        fixture.io.failEvent = false
        _ = try fixture.adapter.retryPresentation(first.receipt.attempt, expecting: fixture.owned().lease)
        #expect(fixture.io.writes.count == 1 && fixture.io.local.appearances.count == 2 && fixture.io.local.events.count == 3)
        #expect(try fixture.unit().state == .succeeded)
    }

    @Test func laterPreferenceWriteSupersedesOldPresentationEvenAfterABA() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        try fixture.queue("setting.appearance", value: .choice("dark"))
        fixture.io.failAppearance = true
        let report = try fixture.submit()
        fixture.io.failAppearance = false
        fixture.prefs.appearance = .light
        fixture.prefs.appearance = .dark
        fixture.io.resetCounts()
        let retry = try fixture.adapter.retryPresentation(report.receipt.attempt, expecting: fixture.owned().lease)
        #expect(retry.outcome == .presentation(.superseded))
        #expect(try fixture.unit().local == .committed && fixture.unit().preferencePresentation == .superseded)
        #expect(fixture.io.writes.isEmpty && fixture.io.local.appearances.isEmpty && fixture.io.local.events.isEmpty)
        #expect(throws: CommandExecutionError.notRetryable) {
            try fixture.adapter.retryPresentation(retry.receipt.attempt, expecting: fixture.owned().lease)
        }
    }
}
