import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchFileSettingRecoveryTests {
    @Test(arguments: [LocalPreferenceFileFault.replaceAfter, .replaceBefore, .cleanupBefore])
    func nativeUnknownVerificationAndCleanup(fault: LocalPreferenceFileFault) async throws {
        let fixture = try UnifiedSearchFileSettingFixture(fault: fault)
        defer { fixture.stop() }
        try fixture.queue(4); fixture.prepare()
        let host = try await fixture.host(count: 4)
        defer { host.close() }
        try await host.clickResult("unified.setting.submit")
        let report = try fixture.report
        try host.snapshot("group-recovery-\(fault)")
        #expect(!host.hasSettingControl("unified.setting.submit"))
        #expect(!host.hasSettingControl("unified.setting.retryPresentation"))
        if fault == .cleanupBefore {
            #expect(try fixture.unit.local == .committed)
            #expect(!host.hasSettingControl("unified.group.verify"))
            #expect(try host.settingStatus() == "整组已保存。")
        } else {
            #expect(!host.hasSettingControl("unified.setting.done") && !host.hasSettingControl("unified.group.return"))
            try await host.clickResult("unified.group.verify")
            #expect(try fixture.report.localReceipt == report.localReceipt)
            #expect(fixture.store.metrics.snapshot().commits == 1)
            if fault == .replaceAfter { try fixture.expectSaved(4) }
            else {
                #expect(try fixture.unit.local == .unknown)
                #expect(host.hasSettingControl("unified.group.verify"))
            }
            try host.snapshot("group-verified-\(fault)")
        }
    }

    @Test(arguments: [false, true])
    func nativePresentationRetryNeverWrites(superseded: Bool) async throws {
        let fixture = try UnifiedSearchFileSettingFixture()
        defer { fixture.stop() }
        try fixture.queue(); fixture.prepare()
        fixture.io.failAppearance = true
        let host = try await fixture.host(count: 3)
        defer { host.close() }
        try await host.clickResult("unified.setting.submit")
        #expect(try fixture.unit.local == .committed)
        #expect(try host.settingStatus() == "The group was saved. Applying its presentation is incomplete.")
        try host.snapshot("group-presentation-failed")
        fixture.io.failAppearance = false
        if superseded { fixture.prefs.appearance = .light }
        let before = try fixture.files.inventory()
        let calls = fixture.store.metrics.snapshot().commits
        try await host.clickResult("unified.setting.retryPresentation")
        #expect(fixture.controller.planMessage == "unified.plan.notExecutable")
        #expect(try fixture.files.inventory() == before)
        #expect(fixture.store.metrics.snapshot().commits == calls)
        if superseded {
            #expect(fixture.io.appearances == [.dark, .light])
            #expect(try host.settingStatus() == "The group was saved. Later changes have replaced its pending presentation.")
        } else { #expect(try fixture.unit.state == .succeeded) }
        try host.snapshot("group-presentation-retried-\(superseded)")
    }
}
