import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchFileSettingInteractionTests {
    @Test(arguments: 2...4)
    func nativeGroupSavesWholeTemporaryFile(count: Int) async throws {
        let fixture = try UnifiedSearchFileSettingFixture()
        defer { fixture.stop() }
        let host = try await fixture.host(count: count)
        defer { host.close() }
        for index in 0..<count {
            try fixture.start(index)
            try await host.settle()
            try await host.clickResult("unified.plan.enqueue")
        }
        try await host.clickResult("unified.group.prepare")
        #expect(fixture.controller.fileSettingIssue == nil)
        try await host.revealSettingControlInsidePanel("unified.group.title")
        try host.snapshot("group-title-\(count)")
        try await host.revealSettingControlInsidePanel("unified.setting.submit")
        try host.snapshot("group-prepared-\(count)")
        let before = fixture.controller.buffer
        fixture.io.onEvent = {
            #expect(fixture.prefs.committedLocalPreferenceRecord == (try? fixture.files.current()))
            #expect(fixture.controller.settingExecution?.units.first?.local == .committed)
        }
        if count == 3 {
            host.window.makeFirstResponder(try host.field)
            try await host.settle()
            try await host.settingKey(36, "\r", step: "group-return")
            #expect(fixture.store.metrics.snapshot().commits == 0)
            try await host.settingKey(36, "\r", step: "group-submit", flags: .command)
        } else { try await host.clickResult("unified.setting.submit") }
        fixture.controller.requestOperationSubmit(before)
        try fixture.expectSaved(count)
        #expect(try host.settingStatus() == (count == 4 ? "整组已保存。" : "All settings saved together."))
        try host.snapshot("group-saved-\(count)")
        try await host.clickResult("unified.setting.done")
        #expect(fixture.controller.settingExecution == nil)
    }

    @Test func fileSingleAndNoChangeUseSameNativeEntry() async throws {
        let fixture = try UnifiedSearchFileSettingFixture()
        defer { fixture.stop() }
        try fixture.start(0)
        let host = try await fixture.host()
        defer { host.close() }
        try await host.clickResult("unified.setting.readBaseline")
        try await host.clickResult("unified.setting.submit")
        try fixture.expectSaved(1)
        try host.snapshot("group-file-single")
    }

    @Test(arguments: [false, true])
    func nativeAllAndPartialNoChange(all: Bool) async throws {
        let fixture = try UnifiedSearchFileSettingFixture()
        defer { fixture.stop() }
        let unchanged: Set<Int> = all ? [0, 1] : [0]
        try fixture.queue(unchanged: unchanged)
        let host = try await fixture.host(count: 4)
        defer { host.close() }
        try await host.clickResult("unified.group.prepare")
        let before = try fixture.files.inventory()
        try host.snapshot("group-no-change-preview-\(all)")
        try await host.clickResult("unified.setting.submit")
        if all {
            #expect(try fixture.files.inventory() == before)
            #expect(fixture.store.metrics.snapshot().replacements == 0 && fixture.io.events.isEmpty)
            #expect(try host.settingStatus() == "全部设置已满足目标，无新保存。")
        } else { try fixture.expectSaved(2, unchanged: unchanged) }
        try host.snapshot("group-no-change-result-\(all)")
    }

    @Test func nativeEditInvalidatesAndRequiresExplicitPreparation() async throws {
        let fixture = try UnifiedSearchFileSettingFixture()
        defer { fixture.stop() }
        try fixture.queue(); fixture.prepare()
        let host = try await fixture.host(count: 3)
        defer { host.close() }
        try #require(host.window.isKeyWindow && fixture.controller.operationVisible,
                     "场景开始时必须有焦点且操作面板未被遮罩；不自动恢复显示")
        let item = try #require(fixture.controller.plan?.items.first)
        try await host.clickResult("unified.plan.remove." + item.id.uuidString)
        #expect(fixture.controller.plan?.items.count == 2)
        #expect(fixture.controller.planMessage == "unified.plan.grouped")
        _ = try host.resultNode("unified.plan.message")
        try host.snapshot("group-removal-rejected")
        try await host.clickResult("unified.plan.edit." + item.id.uuidString)
        let picker = try MenuButtonTestSupport.menu("unified.operation.value", in: host.window)
        try await SettingsButtonTestSupport.reveal(picker, in: host.window)
        let point = try SettingsButtonTestSupport.frame(picker, in: host.window)
        let center = NSPoint(x: point.midX, y: point.midY)
        NSApp.postEvent(try MenuButtonTestSupport.mouse(.leftMouseUp, at: center, in: host.window), atStart: false)
        NSApp.postEvent(try PickerNativeTestSupport.key(code: 126, chars: "\u{F700}", in: host.window), atStart: false)
        NSApp.postEvent(try PickerNativeTestSupport.key(code: 36, chars: "\r", in: host.window), atStart: false)
        NSApp.sendEvent(try MenuButtonTestSupport.mouse(.leftMouseDown, at: center, in: host.window))
        try await host.settle()
        #expect(fixture.controller.editingDraft?.arguments.first?.value == .choice("chinese"))
        try await host.clickResult("unified.plan.close")
        #expect(fixture.controller.fileSettingIssue != nil)
        try await host.clickResult("unified.setting.submit")
        #expect(fixture.store.metrics.snapshot().commits == 0)
        try await host.clickResult("unified.group.prepare")
        #expect(fixture.controller.fileSettingIssue == nil)
        try await host.clickResult("unified.setting.submit")
        #expect(try fixture.files.current().values.language == .chinese)
        #expect(fixture.store.metrics.snapshot().commits == 1)
        try host.snapshot("group-edit-reprepared")
    }

    @Test func nativeConflictAndExpiredConfirmation() async throws {
        let fixture = try UnifiedSearchFileSettingFixture()
        defer { fixture.stop() }
        try fixture.queue(); fixture.prepare()
        let host = try await fixture.host(count: 3)
        defer { host.close() }
        try fixture.external([.language(.chinese)])
        fixture.controller.refreshOperationPresentation()
        try await host.settle()
        try await host.clickResult("unified.setting.reviewConflict")
        try host.snapshot("group-conflict")
        try fixture.external([.language(.system)])
        try await host.clickResult("unified.setting.overwrite")
        #expect(fixture.store.metrics.snapshot().commits == 0)
        fixture.controller.refreshOperationPresentation()
        // 过期提示保留到下次明确准备，准备仍拒绝旧基线。
        try await host.clickResult("unified.group.prepare")
        try await host.clickResult("unified.setting.reviewConflict")
        try await host.clickResult("unified.setting.overwrite")
        try await host.clickResult("unified.setting.submit")
        try fixture.expectSaved(2)
    }
    @Test(arguments: [false, true], [false, true])
    func nativeRevocationAndLateSubmission(lock: Bool, after: Bool) async throws {
        let fixture = try UnifiedSearchFileSettingFixture()
        defer { fixture.stop() }
        try fixture.queue(); fixture.prepare()
        let host = try await fixture.host()
        defer { host.close() }
        let source = fixture.controller.buffer
        let revoke = {
            if lock { NotificationCenter.default.post(name: .privacyWillLock, object: fixture.results.vault) }
            else { fixture.results.focus.post(name: UnifiedSearchResultsFixture.focusLost, object: fixture.results.focusObject) }
        }
        if after {
            fixture.io.onEvent = revoke
            try await host.clickResult("unified.setting.submit")
        } else { revoke(); try await host.settle() }
        #expect(!fixture.controller.operationVisible)
        #expect(!host.hasSettingControl("unified.setting.submit"))
        fixture.controller.requestOperationSubmit(source)
        let count = fixture.store.metrics.snapshot().commits
        #expect(count == (after ? 1 : 0))
        try fixture.results.session.resumeDisplay(expecting: fixture.controller.buffer.lease)
        fixture.controller.refreshOperationPresentation()
        try await host.settle()
        fixture.controller.requestOperationSubmit(source)
        #expect(fixture.store.metrics.snapshot().commits == count)
        if after { #expect(try fixture.unit.local == .committed) }
    }

    @Test(arguments: ["duplicate", "mixed", "notReady"])
    func nativeRejectedPlansKeepAllItems(mode: String) async throws {
        let fixture = try UnifiedSearchFileSettingFixture(ready: mode != "notReady")
        defer { fixture.stop() }
        try fixture.start(0); try fixture.enqueue()
        if mode == "mixed" { try fixture.results.startOperation("clipboard.limit") }
        else { try fixture.start(mode == "duplicate" ? 0 : 1) }
        try fixture.enqueue()
        let host = try await fixture.host(count: 3)
        defer { host.close() }
        let ids = fixture.controller.plan?.items.map(\.id)
        try await host.clickResult("unified.group.prepare")
        try await host.clickResult("unified.setting.submit")
        #expect(fixture.controller.plan?.items.map(\.id) == ids)
        #expect(fixture.store.metrics.snapshot().commits == 0)
        try host.snapshot("group-blocked-" + mode)
    }

}
