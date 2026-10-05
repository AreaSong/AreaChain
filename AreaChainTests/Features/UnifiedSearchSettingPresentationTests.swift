import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchSettingPresentationTests {
    enum ResultScenario: String, CaseIterable {
        case success, noChange, conflict, unknown, presentationFailure, multiple
    }

    @Test(arguments: UnifiedSearchInputLayout.allCases, ["en", "zh-Hans"])
    func resultStatesAcrossHostMatrix(layout: UnifiedSearchInputLayout, locale: String) async throws {
        for dark in [false, true] {
            for minimum in [false, true] {
                let width = minimum ? layout.minimumWidth + 24 : (layout == .standard ? 620 : 380)
                for scenario in ResultScenario.allCases {
                    try await checkResult(scenario, layout: layout, locale: locale, dark: dark, width: width)
                }
            }
        }
    }

    private func checkResult(_ scenario: ResultScenario, layout: UnifiedSearchInputLayout,
                             locale: String, dark: Bool, width: CGFloat) async throws {
        let fixture = try UnifiedSearchSettingFixture(hostID: layout == .standard ? HandoffFixture.target : HandoffFixture.source)
        defer { fixture.stop() }
        try fixture.start("setting.appearance", value: .choice(scenario == .noChange ? "system" : "dark"))
        if scenario == .conflict { fixture.prefs.appearance = .light; fixture.io.resetCounts() }
        if scenario == .multiple {
            try fixture.queue()
            try fixture.start("setting.language", value: .choice("chinese"))
            try fixture.queue()
        }
        if scenario == .unknown { fixture.io.mode = .throwAfter }
        if scenario == .presentationFailure { fixture.io.failAppearance = true }
        let host = try await fixture.host(layout: layout, width: width, locale: locale, dark: dark)
        defer { host.close() }
        if scenario == .conflict { try await host.clickResult("unified.setting.reviewConflict") }
        else { try await host.clickResult("unified.setting.submit") }
        try assertResult(scenario, fixture: fixture, host: host, locale: locale)
        let control: String
        switch scenario {
        case .success, .noChange: control = "unified.setting.done"
        case .conflict: control = "unified.setting.edit"
        case .unknown: control = "unified.setting.status"
        case .presentationFailure: control = "unified.setting.retryPresentation"
        case .multiple: control = "unified.setting.submit"
        }
        try await host.revealSettingControlInsidePanel(control)
        try host.snapshot("setting-result-\(scenario.rawValue)-\(layout)-\(locale)-\(dark)-\(Int(width))")
    }

    private func assertResult(_ scenario: ResultScenario, fixture: UnifiedSearchSettingFixture,
                              host: UnifiedSearchTestHost, locale: String) throws {
        let key: String
        switch scenario {
        case .success: key = "unified.setting.applied"
        case .noChange: key = "unified.setting.noChange"
        case .conflict:
            #expect(fixture.controller.settingConfirmation != nil && fixture.io.writes.isEmpty)
            return
        case .unknown: key = "unified.setting.unknown"
        case .presentationFailure: key = "unified.setting.presentationFailed"
        case .multiple: key = "unified.setting.singleOnly"
        }
        #expect(try host.settingStatus() == L10n.format(key, locale: .init(identifier: locale)))
        if scenario == .multiple || scenario == .noChange {
            #expect(fixture.io.writes.isEmpty && fixture.io.local.events.isEmpty && fixture.io.local.appearances.isEmpty)
        } else { #expect(fixture.io.writes == [.appearance(.dark)]) }
        if scenario == .unknown {
            #expect(!host.hasSettingControl("unified.setting.retryPresentation") && !host.hasSettingControl("unified.setting.done"))
        }
        if scenario == .multiple {
            #expect(fixture.controller.settingExecution == nil && fixture.controller.plan?.items.count == 2)
        }
    }

    @Test(arguments: UnifiedSearchInputLayout.allCases)
    func submitRemainsInsideOperationBoundary(layout: UnifiedSearchInputLayout) async throws {
        let fixture = try UnifiedSearchSettingFixture()
        defer { fixture.stop() }
        try fixture.start("setting.appearance", value: .choice("dark"))
        let host = try await fixture.host(layout: layout, width: layout.minimumWidth + 24)
        defer { host.close() }
        let submit = try host.resultNode("unified.setting.submit")
        try await SettingsButtonTestSupport.reveal(submit, in: host.window)
        let boundary = try #require(SettingsButtonTestSupport.elements(host.window.contentView)
            .compactMap { $0 as? UnifiedSearchOperationBoundary }.first)
        let buttonFrame = try SettingsButtonTestSupport.frame(submit, in: host.window)
        let panelFrame = boundary.convert(boundary.bounds, to: nil)
        let count = try host.resultNode("unified.results.count")
        let countFrame = try SettingsButtonTestSupport.frame(count, in: host.window)
        let results = try #require(SettingsButtonTestSupport.elements(host.window.contentView)
            .compactMap { $0 as? UnifiedSearchResultsBoundary }.first)
        let resultsFrame = results.convert(results.bounds, to: nil)
        try host.snapshot("setting-submit-boundary-\(layout)")
        #expect(panelFrame.contains(buttonFrame), "提交必须在操作面板内：button=\(buttonFrame)，panel=\(panelFrame)")
        #expect(!countFrame.intersects(buttonFrame), "结果标题不得覆盖提交按钮：count=\(countFrame)，button=\(buttonFrame)")
        #expect(resultsFrame.contains(countFrame), "结果标题须在结果边界内：count=\(countFrame)，results=\(resultsFrame)")
        #expect(fixture.io.writes.isEmpty)
    }

    @Test func hostsLanguagesThemesAndMinimumWidths() async throws {
        for layout in UnifiedSearchInputLayout.allCases {
            for locale in ["en", "zh-Hans"] {
                for dark in [false, true] {
                    for minimum in [false, true] {
                        let fixture = try UnifiedSearchSettingFixture(hostID: layout == .standard ? HandoffFixture.target : HandoffFixture.source)
                        defer { fixture.stop() }
                        try fixture.start("setting.appearance", value: .choice("dark"))
                        let width = minimum ? layout.minimumWidth + 24 : (layout == .standard ? 620 : 380)
                        let host = try await fixture.host(layout: layout, width: width, locale: locale, dark: dark)
                        defer { host.close() }
                        let field = try host.field
                        let anchor = field.convert(field.bounds, to: nil)
                        let submit = try host.resultNode("unified.setting.submit")
                        try await SettingsButtonTestSupport.reveal(submit, in: host.window)
                        try SettingsButtonTestSupport.assertBounds([submit], in: host.window)
                        #expect(field.convert(field.bounds, to: nil) == anchor)
                        #expect(try host.settingStatus() == L10n.format("unified.setting.pending", locale: .init(identifier: locale)))
                        let labels = SettingsButtonTestSupport.elements(host.window.contentView).compactMap {
                            SettingsButtonTestSupport.value($0, "accessibilityValue") as? String
                                ?? SettingsButtonTestSupport.value($0, "accessibilityLabel") as? String
                        }.joined(separator: "\n")
                        #expect(labels.contains(L10n.format("unified.setting.system", locale: .init(identifier: locale))))
                        #expect(!labels.contains("handler") && !labels.contains("unwired"))
                        #expect(fixture.io.writes.isEmpty)
                        try host.snapshot("setting-matrix-\(layout)-\(locale)-\(dark)-\(minimum)")
                    }
                }
            }
        }
    }

    @Test(arguments: [false, true])
    func unknownAndDisplayFailureExposeOnlyLegalActions(unknown: Bool) async throws {
        let fixture = try UnifiedSearchSettingFixture()
        defer { fixture.stop() }
        try fixture.start("setting.appearance", value: .choice("dark"))
        let host = try await fixture.host(layout: .compact, width: 304, locale: "en", dark: true)
        defer { host.close() }
        if unknown { fixture.io.mode = .throwAfter }
        else { fixture.io.failAppearance = true }
        try await host.clickResult("unified.setting.submit")
        let expected = unknown ? "unified.setting.unknown" : "unified.setting.presentationFailed"
        #expect(try host.settingStatus() == L10n.format(expected, locale: .init(identifier: "en")))
        #expect(!host.hasSettingControl("unified.setting.done") && !host.hasSettingControl("unified.setting.return"))
        #expect(host.hasSettingControl("unified.setting.retryPresentation") == !unknown)
        try host.snapshot(unknown ? "setting-unknown" : "setting-presentation-failed")
        if !unknown {
            fixture.io.failAppearance = false
            try await host.clickResult("unified.setting.retryPresentation")
            #expect(try host.settingStatus() == "Applied")
            #expect(fixture.io.writes.count == 1 && fixture.io.local.events.count == 1)
            try host.snapshot("setting-presentation-retried")
        }
        #expect(fixture.io.writes.count == 1)
    }

    @Test func laterModificationDisablesOldDisplayRetryWithoutAWrite() async throws {
        let fixture = try UnifiedSearchSettingFixture()
        defer { fixture.stop() }
        try fixture.start("setting.appearance", value: .choice("dark"))
        let host = try await fixture.host(layout: .compact, width: 304, locale: "zh-Hans")
        defer { host.close() }
        fixture.io.failEvent = true
        try await host.clickResult("unified.setting.submit")
        fixture.io.failEvent = false
        fixture.prefs.appearance = .light
        fixture.io.resetCounts()
        try await host.clickResult("unified.setting.retryPresentation")
        #expect(try fixture.report.outcome == .presentation(.superseded))
        #expect(fixture.io.writes.isEmpty && fixture.io.local.events.isEmpty && fixture.io.local.appearances.isEmpty)
        #expect(!host.hasSettingControl("unified.setting.retryPresentation"))
        #expect(!host.hasSettingControl("unified.setting.done"))
        try host.snapshot("setting-superseded")
    }

    @Test func blurLockAndCloseOnlyWithdrawDisplayAfterCommit() async throws {
        let fixture = try UnifiedSearchSettingFixture()
        defer { fixture.stop() }
        try fixture.start()
        let host = try await fixture.host()
        defer { host.close() }
        try await host.clickResult("unified.setting.submit")
        let run = try fixture.run
        let source = fixture.controller.buffer
        let other = NSWindow(contentRect: .init(x: 20, y: 20, width: 100, height: 100),
            styleMask: [.titled], backing: .buffered, defer: false)
        other.isReleasedWhenClosed = false
        defer { SystemPageHost.release(other) }
        other.makeKeyAndOrderFront(nil)
        try await SystemPageHost.settle(other)
        #expect(!fixture.controller.operationVisible)
        #expect(try fixture.run == run && fixture.io.writes.count == 1)
        host.window.makeKeyAndOrderFront(nil)
        try await host.settle()
        #expect(!fixture.controller.operationVisible)
        try fixture.results.session.resumeDisplay(expecting: fixture.controller.buffer.lease)
        fixture.controller.refreshOperationPresentation()
        try await host.settle()
        #expect(try host.settingStatus() == "Applied" && fixture.run == run)
        NotificationCenter.default.post(name: .privacyWillLock, object: fixture.results.vault)
        #expect(!fixture.controller.operationVisible)
        #expect(try fixture.run == run && fixture.io.writes.count == 1)
        fixture.controller.acknowledgeSettingResult(try fixture.report, source: source)
        #expect(try fixture.run == run)
        try host.snapshot("setting-locked-after-commit")
        host.close()
        #expect(try fixture.run == run && fixture.io.writes.count == 1)
    }
}
