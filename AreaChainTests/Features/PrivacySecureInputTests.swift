import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 同一套生产 sheet 用例在接入前后执行，不进入父页面的认证/文件动作。
@Suite(.serialized) @MainActor
struct PrivacySecureInputTests {
    typealias Secure = SecureInputTestSupport
    typealias Native = SettingsButtonTestSupport

    @Test(arguments: [0, 1, 2, 3], ["en", "zh-Hans"])
    func layoutAndNativeRoles(configuration: Int, locale: String) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let probe = PasswordSheetProbe(configuration)
        let host = fixture.window(probe.host, locale: locale, scheme: locale == "en" ? .light : .dark)
        defer { FormInputTestSupport.release(host); probe.finish() }
        let sheet = try await FormInputTestSupport.sheet(in: host)
        let fields = Secure.fields(sheet)
        #expect(fields.count == (probe.confirmation ? 2 : 1))
        #expect(sheet.contentView?.bounds.width == 440)
        let first = try #require(fields.first)
        let title = L10n.string(String.LocalizationValue(probe.titleKey), locale: Locale(identifier: locale))
        #expect(first.placeholderString == title)
        print("Secure AX nativeRole=\(first.accessibilityRole()?.rawValue ?? "nil") nativeSubrole=\(first.accessibilitySubrole()?.rawValue ?? "nil")")
        let roles = Native.elements(sheet.contentView).filter { Native.value($0, "accessibilitySubrole") as? String == "AXSecureTextField" }
        #expect(roles.count == fields.count)
        #expect(roles.allSatisfy { Native.value($0, "accessibilityRole") as? String == "AXTextField" })
        #expect(fields.allSatisfy { ($0.cell as? NSSecureTextFieldCell)?.echosBullets == true })
        #expect(first.currentEditor() === sheet.firstResponder)
        print("Secure geometry config=\(configuration) locale=\(locale) sheet=\(sheet.contentView!.bounds.size) field=\(first.bounds.size) font=\(first.font!.pointSize) border=\(first.isBezeled)")
        try Native.assertBounds(fields + Native.buttons(in: sheet), in: sheet)
        try Native.snapshot(sheet, name: "secure-empty-\(configuration)-\(locale)")
        try await Secure.fill(sheet)
        try Native.snapshot(sheet, name: "secure-filled-\(configuration)-\(locale)")
        try await FormInputTestSupport.key(48, text: "\t", in: sheet)
        #expect(first.currentEditor() === sheet.firstResponder)
        #expect(probe.calls == 0)
        try await FormInputTestSupport.key(53, text: "\u{1b}", in: sheet)
        try await FormInputTestSupport.wait { host.attachedSheet == nil }
        #expect(probe.dismissals == 1 && probe.completed == 0)
        probe.presented = true
        let reopened = try await FormInputTestSupport.sheet(in: host)
        #expect(Secure.fields(reopened).allSatisfy { $0.stringValue.isEmpty })
    }

    @Test(arguments: [0, 1, 2, 3])
    func busyFailureRetryAndParentClose(configuration: Int) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let probe = PasswordSheetProbe(configuration)
        let host = fixture.window(probe.host)
        defer { FormInputTestSupport.release(host); probe.finish() }
        let sheet = try await FormInputTestSupport.sheet(in: host)
        probe.window = sheet
        try Secure.enabled("common.save", false, in: sheet)
        if probe.confirmation {
            try await Secure.enter(Secure.sample, in: sheet)
            try await Secure.enter("mismatch", index: 1, in: sheet)
            try Secure.enabled("common.save", false, in: sheet)
        }
        try await Secure.fill(sheet)
        try await Secure.click("common.save", in: sheet)
        try #require(probe.pending != nil)
        #expect(probe.correctInput && probe.emptyAtAction && probe.calls == 1 && probe.completed == 0)
        try await checkBusy(probe, sheet: sheet, host: host)
        probe.finish(failure: true)
        try await SystemPageHost.settle(sheet)
        #expect(Secure.hasError(sheet) && probe.completed == 0 && probe.correctAfterWait)
        try await Secure.fill(sheet)
        #expect(Secure.hasError(sheet), "编辑沿用原行为保留错误")
        try await Secure.click("common.save", in: sheet)
        #expect(!Secure.hasError(sheet) && probe.calls == 2 && probe.correctInput)
        print("Secure retry lengths=\(Secure.fields(sheet).map { $0.stringValue.count }) editors=\(Secure.fields(sheet).map { $0.currentEditor()?.string.count ?? -1 })")
        try Native.snapshot(sheet, name: "secure-retry-\(configuration)")
        #expect(Secure.fields(sheet).allSatisfy { $0.stringValue.isEmpty })
        probe.finish()
        try await SystemPageHost.settle(sheet)
        #expect(probe.completed == 1 && host.attachedSheet === sheet, "成功是否关闭由父页决定")
        probe.closeOnComplete = true
        try await Secure.fill(sheet)
        try await Secure.click("common.save", in: sheet)
        probe.finish()
        try await FormInputTestSupport.wait { host.attachedSheet == nil }
        #expect(probe.completed == 2 && probe.dismissals == 1)
    }

    @Test(arguments: [0, 2])
    func sameValueDuringBusyRetainsOriginalNativeReadbackBoundary(configuration: Int) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let probe = PasswordSheetProbe(configuration)
        let host = fixture.window(probe.host)
        defer { FormInputTestSupport.release(host); probe.finish() }
        let sheet = try await FormInputTestSupport.sheet(in: host)
        probe.window = sheet
        try await Secure.fill(sheet)
        try await Secure.click("common.save", in: sheet)
        try await Secure.fill(sheet)
        probe.finish(failure: true)
        try await SystemPageHost.settle(sheet)
        try await Secure.fill(sheet)
        try await Secure.click("common.save", in: sheet)
        #expect(probe.calls == 2 && probe.correctInput)
        print("Secure same-value retry lengths=\(Secure.fields(sheet).map { $0.stringValue.count }) editors=\(Secure.fields(sheet).map { $0.currentEditor()?.string.count ?? -1 })")
        try Native.snapshot(sheet, name: "secure-same-value-\(configuration)")
        // 原生基线 original.xcresult 已复现；保留失败证据，不用额外状态/重建绕过。
        withKnownIssue("原 SecureField 同值重试后确认字段残留，见工程记录第七阶段 B", isIntermittent: true) {
            #expect(Secure.fields(sheet).allSatisfy { $0.stringValue.isEmpty })
        }
        probe.finish()
        try await SystemPageHost.settle(sheet)
        try Secure.enabled("common.save", false, in: sheet)
        try await FormInputTestSupport.key(36, text: "\r", in: sheet)
        #expect(probe.calls == 2 && probe.completed == 1)
    }

    private func checkBusy(_ probe: PasswordSheetProbe, sheet: NSWindow, host: NSWindow) async throws {
        #expect(Secure.fields(sheet).allSatisfy { $0.stringValue.isEmpty && $0.isEnabled })
        try Secure.enabled("alert.cancel", false, in: sheet)
        for index in Secure.fields(sheet).indices { try await Secure.enter("pending-edit", index: index, in: sheet) }
        try Secure.enabled("common.save", false, in: sheet)
        try await Secure.click("common.save", in: sheet)
        try await Secure.click("alert.cancel", in: sheet)
        try await FormInputTestSupport.key(36, text: "\r", in: sheet)
        try await FormInputTestSupport.key(36, text: "\r", flags: .command, in: sheet)
        try await FormInputTestSupport.key(53, text: "\u{1b}", in: sheet)
        sheet.performClose(nil)
        try await SystemPageHost.settle(sheet)
        #expect(host.attachedSheet === sheet && probe.calls == 1 && probe.correctInput)
        #expect(Secure.fields(sheet).allSatisfy { !$0.stringValue.isEmpty })
    }

    @Test(arguments: [0, 1, 2, 3])
    func returnPathsAndIdleCancel(configuration: Int) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let probe = PasswordSheetProbe(configuration)
        let host = fixture.window(probe.host)
        defer { FormInputTestSupport.release(host); probe.finish() }
        let sheet = try await FormInputTestSupport.sheet(in: host)
        probe.window = sheet
        var expected = 0
        for index in Secure.fields(sheet).indices {
            for command in [false, true] {
                try await Secure.fill(sheet)
                _ = try await FormInputTestSupport.editor(Secure.fields(sheet)[index], in: sheet)
                try await FormInputTestSupport.key(36, text: "\r", flags: command ? .command : [], in: sheet)
                if !command { expected += 1 }
                print("Secure submit config=\(configuration) field=\(index) command=\(command) calls=\(probe.calls) expected=\(expected)")
                #expect(probe.calls == expected && probe.correctInput )
                probe.finish()
                try await SystemPageHost.settle(sheet)
                #expect(probe.completed == expected)
            }
        }
        try await Secure.fill(sheet)
        try await Secure.click("alert.cancel", in: sheet)
        try await FormInputTestSupport.wait { host.attachedSheet == nil }
        #expect(probe.calls == expected && probe.dismissals == 1)
    }
}
