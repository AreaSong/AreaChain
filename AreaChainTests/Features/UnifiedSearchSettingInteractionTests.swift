import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchSettingInteractionTests {
    @Test func nativeEnqueueOwnsDraftAndMultipleSubmissionWritesNothing() async throws {
        let fixture = try UnifiedSearchSettingFixture()
        defer { fixture.stop() }
        try fixture.start()
        let original = try fixture.draft
        let host = try await fixture.host(layout: .compact, width: 304)
        defer { host.close() }
        try await host.clickResult("unified.plan.enqueue")
        #expect(fixture.controller.operations?.active == nil && fixture.controller.plan?.items.first?.draft.id == original.id)
        #expect(fixture.controller.operations?.retained.contains { $0.id == original.id } == false)
        try fixture.start("setting.appearance", value: .choice("dark"))
        try await host.settle()
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.io.writes.isEmpty && fixture.controller.settingExecution == nil)
        try await host.clickResult("unified.plan.enqueue")
        let plan = fixture.controller.plan
        try await host.clickResult("unified.setting.submit")
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.controller.plan == plan && fixture.controller.settingExecution == nil)
        #expect(fixture.io.writes.isEmpty && fixture.io.local.events.isEmpty && fixture.io.local.appearances.isEmpty)
        try host.snapshot("setting-multiple-native-blocked")
    }

    @Test(arguments: [false, true])
    func unsupportedAndUnassembledNativeSubmissionRemainBlocked(assembled: Bool) async throws {
        let io = try PreferenceCommandIO()
        defer { io.cleanup() }
        let fixture = try UnifiedSearchResultsFixture(localPreferences: assembled ? io.preferences() : nil)
        defer { fixture.stop() }
        io.resetCounts()
        _ = try await fixture.publish()
        try fixture.startOperation(assembled ? "clipboard.limit" : "setting.language")
        let parameter: CommandValue = assembled ? .number(25) : .choice("english")
        _ = fixture.controller.editParameter(.init(parameter: .value, operation: .assign, value: parameter), source: fixture.controller.buffer)
        let host = UnifiedSearchTestHost(results: fixture.controller, operations: true)
        defer { host.close() }
        try await host.start()
        let before = try fixture.handoff.state()
        try await host.clickResult("unified.setting.submit")
        try await host.key(36, "\r", flags: .command)
        #expect(try fixture.handoff.state() == before)
        #expect(io.writes.isEmpty && io.local.events.isEmpty && io.local.appearances.isEmpty)
        #expect(fixture.controller.settingExecution == nil && fixture.opens.isEmpty)
    }

    @Test(arguments: 0..<4, [false, true])
    func completionBaselineParameterAndExplicitSubmission(index: Int, commandReturn: Bool) async throws {
        let fixture = try UnifiedSearchSettingFixture(hostID: index.isMultiple(of: 2) ? HandoffFixture.target : HandoffFixture.source)
        defer { fixture.stop() }
        let host = try await fixture.host(layout: index.isMultiple(of: 2) ? .standard : .compact)
        defer { host.close() }
        (try host.editor).insertText("/set", replacementRange: (try host.editor).selectedRange())
        try await host.settle()
        let state = try host.state
        let old = try #require(state.completion)
        let candidate = try #require(old.result.candidates.first { $0.command.id.rawValue == UnifiedSearchSettingSamples.ids[index] })
        state.suggestions.selectedIndex = try #require(old.result.candidates.firstIndex(of: candidate))
        try await host.settingKey(48, "\t", step: "completion-\(index)")
        let draft = try fixture.draft
        #expect(draft.baseline.preference != nil && draft.arguments.isEmpty)
        #expect(fixture.io.writes.isEmpty)
        let target = UnifiedSearchSettingSamples.values[index]
        try await host.chooseSettingValue(target)
        try await host.settle()
        #expect(try fixture.draft.arguments.first?.value == target && fixture.draft.id == draft.id)
        #expect(!state.accept(candidate, source: old))
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        try await host.settingKey(53, "\u{1b}", step: "dismiss-\(index)")
        try await host.settingKey(36, "\r", step: "return-\(index)")
        #expect(fixture.io.writes.isEmpty, "Return 只补全或确认当前控件")
        let source = fixture.controller.buffer
        if commandReturn { try await host.settingKey(36, "\r", step: "submit-\(index)", flags: .command) }
        else { try await host.clickResult("unified.setting.submit") }
        let expected = UnifiedSearchSettingSamples.preferences[index]
        #expect(fixture.io.writes == [expected])
        #expect(fixture.prefs.readLocalSetting(expected.field).storedValue == expected)
        #expect(try fixture.run.snapshot.items.first?.draft.id == draft.id)
        #expect(fixture.controller.operations?.active == nil && fixture.controller.plan?.items.isEmpty == true)
        #expect(try fixture.unit.local == .committed && fixture.unit.state == .succeeded)
        #expect(try host.settingStatus() == "Applied")
        fixture.controller.requestOperationSubmit(source)
        #expect(fixture.io.writes.count == 1 && fixture.results.opens.isEmpty)
        try host.snapshot("setting-applied-\(index)-\(commandReturn)")
        try await host.clickResult("unified.setting.done")
        #expect(fixture.controller.settingExecution == nil)
    }

    @Test(arguments: 0..<4)
    func noChangeHasZeroWritesAndZeroPresentationEffects(index: Int) async throws {
        let initial: [CommandValue] = [.choice("system"), .choice("system"), .choice("tail"), .boolean(false)]
        let fixture = try UnifiedSearchSettingFixture()
        defer { fixture.stop() }
        try fixture.start(UnifiedSearchSettingSamples.ids[index], value: initial[index])
        let host = try await fixture.host(locale: "zh-Hans")
        defer { host.close() }
        try await host.clickResult("unified.setting.submit")
        #expect(try fixture.report.outcome == .noChange && fixture.unit.local == .notSubmitted)
        #expect(fixture.io.writes.isEmpty && fixture.io.local.events.isEmpty && fixture.io.local.appearances.isEmpty)
        #expect(try host.settingStatus() == "当前已是此设置")
        #expect(!host.hasSettingControl("unified.setting.retryPresentation"))
        try host.snapshot("setting-no-change-\(index)")
    }

    @Test(arguments: ["unified.setting.adopt", "unified.setting.overwrite", "unified.setting.edit"])
    func threeConflictButtonsAndExpiredConfirmation(action: String) async throws {
        let fixture = try UnifiedSearchSettingFixture()
        defer { fixture.stop() }
        try fixture.start()
        let host = try await fixture.host(layout: .compact, width: 304, locale: "zh-Hans", dark: true)
        defer { host.close() }
        fixture.prefs.language = .chinese
        fixture.io.resetCounts()
        fixture.controller.refreshOperationPresentation()
        try await host.settle()
        try await host.clickResult("unified.setting.reviewConflict")
        let confirmation = try #require(fixture.controller.settingConfirmation)
        try host.snapshot("setting-conflict-" + action)
        try await host.clickResult(action)
        #expect(fixture.io.writes.isEmpty)
        #expect(fixture.controller.settingConfirmation == nil)
        if action == "unified.setting.adopt" {
            #expect(try fixture.draft.arguments.first?.value == .choice("chinese"))
        } else if action == "unified.setting.overwrite" {
            #expect(try fixture.draft.arguments.first?.value == .choice("english"))
            fixture.prefs.language = .system
            fixture.io.resetCounts()
            fixture.controller.resolveSettingConflict(confirmation, choice: .confirmOverwrite)
            fixture.submit()
            #expect(fixture.controller.settingExecution == nil && fixture.io.writes.isEmpty)
        } else { #expect(try fixture.draft.baseline.preference == confirmation.evidence.conflict.baseline) }
    }

    @Test func legacyBindingImmediatelyChangesValueAndConflictsWithUnsubmittedCommand() async throws {
        let fixture = try UnifiedSearchSettingFixture()
        defer { fixture.stop() }
        try fixture.start()
        let baseline = try fixture.draft.baseline.preference
        let state = SettingsPickerProbe()
        let native = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { native.cleanup() }
        let window = SystemPageHost.window(SettingsPickerForm(prefs: fixture.prefs, state: state),
            container: native.container, scheme: .light, locale: "en", size: .init(width: 420, height: 720), prefs: fixture.prefs)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let node = try MenuButtonTestSupport.menu("settings.language", in: window)
        let menu = try await MenuButtonTestSupport.openAndEscape(node, in: window)
        try MenuButtonTestSupport.dispatch(L10n.format("language.chinese", locale: .init(identifier: "en")), in: menu)
        try await SystemPageHost.settle(window)
        #expect(fixture.prefs.language == .chinese)
        #expect(fixture.io.writes == [.language(.chinese)])
        #expect(fixture.io.local.defaults.string(forKey: AppPreferences.languageKey) == "chinese")
        #expect(try fixture.draft.baseline.preference == baseline)
        fixture.io.resetCounts()
        fixture.submit()
        #expect(fixture.controller.settingExecution == nil && fixture.io.writes.isEmpty)
        guard case .conflict = fixture.controller.settingIssue else { Issue.record("旧 Binding 修改未触发冲突"); return }
        #expect(state.loginRequests.isEmpty)
        try SettingsButtonTestSupport.snapshot(window, name: "setting-command-old-binding")
    }

    @Test(arguments: [false, true])
    func focusedButtonSpaceAndCommandReturnUseOriginalSubmitEntry(commandReturn: Bool) async throws {
        let fixture = try UnifiedSearchSettingFixture()
        defer { fixture.stop() }
        try fixture.start()
        let host = try await fixture.host()
        defer { host.close() }
        let button = try host.resultNode("unified.setting.submit")
        try await SettingsButtonTestSupport.reveal(button, in: host.window)
        try await host.key(53, "\u{1b}")
        for _ in 0..<20 {
            if try UnifiedSearchPlanInteractionTests.focused(button) { break }
            try await host.key(48, "\t")
        }
        try #require(try UnifiedSearchPlanInteractionTests.focused(button))
        if commandReturn { try await host.key(36, "\r", flags: .command) }
        else { try await UnifiedSearchPlanInteractionTests.space(host) }
        #expect(fixture.io.writes == [.language(.english)])
    }
}
