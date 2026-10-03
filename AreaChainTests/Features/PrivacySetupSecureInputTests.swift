import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 直接挂载生产 Setup；合法输入操作由原存储提前失败 guard 隔离，禁止进入安全业务。
@Suite(.serialized) @MainActor
struct PrivacySetupSecureInputTests {
    typealias Setup = SetupSecureTestSupport
    typealias Secure = SecureInputTestSupport
    typealias Native = SettingsButtonTestSupport

    @Test(arguments: ["en", "zh-Hans"])
    func tagCandidatesHideAndRestoreOnlyBackupGroup(locale: String) async throws {
        let support = try Native()
        defer { support.cleanup() }
        let fixture = try SetupFixture(support, configured: false, tagged: true)
        let host = fixture.host(creating: true, locale: locale, scheme: .light)
        defer { FormInputTestSupport.release(host) }
        let sheet = try await fixture.ready(host)
        try await Setup.toggle("privacy.methods.master", locale: locale, in: sheet)
        try await Setup.toggle("privacy.legacy.include", locale: locale, in: sheet)
        let expected: [Setup.Field: String] = [.master: "synthetic-master", .masterConfirmation: "synthetic-master",
                                              .backup: "synthetic-backup", .backupConfirmation: "synthetic-backup"]
        for identity in Setup.Field.allCases { try await Setup.enter(expected[identity]!, field: identity, in: sheet) }
        try await Setup.toggle("privacy.methods.system", locale: locale, in: sheet)
        try Setup.expectValues(expected, in: sheet)
        let tag = try #require(Native.elements(sheet.contentView).first {
            Native.value($0, "accessibilityRole") as? String == "AXCheckBox"
                && Native.value($0, "accessibilityLabel") as? String == fixture.tag.name
        })
        try await Native.reveal(tag, in: sheet)
        try await Native.click(tag, in: sheet)
        #expect(Setup.visible(in: sheet) == [.master, .masterConfirmation])
        try Setup.expectValues(expected.filter { $0.key == .master || $0.key == .masterConfirmation }, in: sheet)
        try Secure.enabled("privacy.apply", true, locale: locale, in: sheet)
        try await Native.click(tag, in: sheet)
        #expect(Setup.visible(in: sheet) == Setup.Field.allCases)
        try Setup.expectValues(expected, in: sheet)
        try Secure.enabled("privacy.apply", true, locale: locale, in: sheet)
        try await fixture.unchanged()
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func independentCharacterValidationAndNativeRoles(locale: String, scheme: ColorScheme) async throws {
        let support = try Native()
        defer { support.cleanup() }
        let fixture = try SetupFixture(support, configured: false)
        let host = fixture.host(creating: true, locale: locale, scheme: scheme)
        defer { FormInputTestSupport.release(host) }
        let sheet = try await fixture.ready(host)
        try await Setup.toggle("privacy.methods.master", locale: locale, in: sheet)
        #expect(Setup.visible(in: sheet) == Setup.Field.allCases)
        for identity in Setup.Field.allCases {
            let input = try Setup.field(identity, in: sheet)
            let node = try Setup.node(identity, in: sheet)
            let title = L10n.string(String.LocalizationValue(identity.title), locale: Locale(identifier: locale))
            #expect(input.placeholderString == title)
            #expect(Native.value(node, "accessibilityRole") as? String == "AXTextField")
            let label = Native.value(node, "accessibilityLabel") as? String
            #expect((label ?? input.placeholderString) == title)
            #expect((input.cell as? NSSecureTextFieldCell)?.echosBullets == true)
        }
        try await validatePairs(in: sheet, locale: locale)
        try await Setup.recordLayout(sheet, name: "four-\(locale)-\(scheme)")
        try await fixture.unchanged()
    }

    private func validatePairs(in sheet: NSWindow, locale: String) async throws {
        let twelve = String(repeating: "e\u{301}", count: 12)
        let eleven = String(repeating: "e\u{301}", count: 11)
        #expect(twelve.count == 12 && twelve.utf8.count > 12 && twelve.utf16.count > 12)
        let pairs: [(Setup.Field, Setup.Field)] = [(.master, .masterConfirmation), (.backup, .backupConfirmation)]
        for pair in pairs {
            for identity in Setup.Field.allCases { try await Setup.enter(twelve, field: identity, in: sheet) }
            for value in ["", eleven, twelve] {
                try await Setup.enter(value, field: pair.0, in: sheet)
                try await Setup.enter(value, field: pair.1, in: sheet)
                try Secure.enabled("privacy.apply", value.count == 12, locale: locale, in: sheet)
            }
            try await Setup.enter("different-12", field: pair.1, in: sheet)
            try Secure.enabled("privacy.apply", false, locale: locale, in: sheet)
            try await Setup.enter(twelve, field: pair.1, in: sheet)
            try Secure.enabled("privacy.apply", true, locale: locale, in: sheet)
        }
        // 每次只编辑一个字段，同时检查另外三个身份；两组允许各用不同密码。
        var expected = Dictionary(uniqueKeysWithValues: Setup.Field.allCases.map { ($0, twelve) })
        for (offset, identity) in Setup.Field.allCases.enumerated() {
            let value = String(repeating: " ", count: 12 + offset)
            try await Setup.enter(value, field: identity, in: sheet)
            expected[identity] = value
            try Setup.expectValues(expected, in: sheet)
        }
        for identity in [Setup.Field.master, .masterConfirmation] { try await Setup.enter(twelve, field: identity, in: sheet) }
        for identity in [Setup.Field.backup, .backupConfirmation] {
            try await Setup.enter(String(repeating: " ", count: 12), field: identity, in: sheet)
        }
        try Secure.enabled("privacy.apply", true, locale: locale, in: sheet)
    }

    @Test(arguments: ["en", "zh-Hans"])
    func keyboardCancelReopenAndEarlyStorageFailure(locale: String) async throws {
        try #require(Bundle.main.bundleIdentifier == "com.areachain.privacy-qa")
        let previous = StoreHealth.shared.isUsingMemoryFallback
        StoreHealth.shared.isUsingMemoryFallback = true
        defer { StoreHealth.shared.isUsingMemoryFallback = previous }
        let support = try Native()
        defer { support.cleanup() }
        let fixture = try SetupFixture(support, configured: false)
        for pass in 0..<2 {
            let host = fixture.host(creating: true, locale: locale, scheme: .light)
            defer { FormInputTestSupport.release(host) }
            let sheet = try await fixture.ready(host)
            #expect(Secure.fields(sheet).allSatisfy { $0.stringValue.isEmpty })
            print("Setup initial focus=\(Setup.focus(in: sheet))")
            try await Setup.toggle("privacy.methods.master", locale: locale, in: sheet)
            for identity in Setup.Field.allCases { try await Setup.enter(Secure.sample, field: identity, in: sheet) }
            try Secure.enabled("privacy.apply", true, locale: locale, in: sheet)
            for identity in Setup.Field.allCases {
                _ = try await FormInputTestSupport.editor(Setup.field(identity, in: sheet), in: sheet)
                try await FormInputTestSupport.key(36, text: "\r", in: sheet)
                try await FormInputTestSupport.key(36, text: "\r", flags: .command, in: sheet)
                #expect(!Setup.hasText(PrivacyError.storageFailure.messageKey, locale: locale, in: sheet))
                try Secure.enabled("privacy.apply", true, locale: locale, in: sheet)
                try await FormInputTestSupport.key(48, text: "\t", in: sheet)
                print("Setup Tab from=\(identity.rawValue) to=\(Setup.focus(in: sheet))")
            }
            try await fixture.unchanged()
            if pass == 0 { try await failBeforeBusiness(fixture, in: sheet, locale: locale) }
            try await FormInputTestSupport.key(53, text: "\u{1b}", in: sheet)
            try await fixture.wait { host.attachedSheet == nil && fixture.dismissed }
            try await fixture.unchanged()
        }
    }

    private func failBeforeBusiness(_ fixture: SetupFixture, in sheet: NSWindow, locale: String) async throws {
        try #require(StoreHealth.shared.isUsingMemoryFallback)
        try await Secure.click("privacy.apply", locale: locale, in: sheet)
        try await fixture.wait { Setup.hasText(PrivacyError.storageFailure.messageKey, locale: locale, in: sheet) }
        #expect(Secure.fields(sheet).count == 4 && Secure.fields(sheet).allSatisfy { $0.stringValue.isEmpty })
        try Secure.enabled("privacy.apply", false, locale: locale, in: sheet)
        try Secure.enabled("alert.cancel", true, locale: locale, in: sheet)
        #expect(Secure.fields(sheet).allSatisfy { $0.isEnabled })
        try await Setup.recordLayout(sheet, name: "storage-failure-\(locale)")
        try await fixture.unchanged()
    }

    @Test func nativeKeyLongInputAndExternalDisabled() async throws {
        let support = try Native()
        defer { support.cleanup() }
        let fixture = try SetupFixture(support, configured: false)
        let state = SetupEnvironment()
        let content = SetupEnvironmentHost(fixture: fixture, state: state)
        let host = support.window(content, size: NSSize(width: 520, height: 650))
        defer { FormInputTestSupport.release(host) }
        let sheet = try await fixture.ready(host)
        try await Setup.toggle("privacy.methods.master", in: sheet)
        let input = try Setup.field(.master, in: sheet)
        _ = try await FormInputTestSupport.editor(input, in: sheet)
        try await FormInputTestSupport.key(0, text: "a", in: sheet)
        let accepted = input.stringValue == "a"
        #expect(accepted)
        let long = String(repeating: Secure.sample, count: 40)
        for identity in Setup.Field.allCases { try await Setup.enter(long, field: identity, in: sheet) }
        try await Setup.recordLayout(sheet, name: "long")
        sheet.makeFirstResponder(nil)
        state.disabled = true
        try await SystemPageHost.settle(sheet)
        #expect(Secure.fields(sheet).allSatisfy { !$0.isEnabled })
        try Native.snapshot(sheet, name: "setup7D-disabled")
        state.disabled = false
        try await SystemPageHost.settle(sheet)
        #expect(Secure.fields(sheet).allSatisfy { $0.isEnabled })
        // 语言刷新可能触发原生空值回写，记录原/新对照而不新增恢复策略。
        state.locale = "zh-Hans"
        try await SystemPageHost.settle(sheet)
        for identity in Setup.Field.allCases {
            let field = try Setup.field(identity, in: sheet)
            #expect(field.placeholderString == L10n.string(String.LocalizationValue(identity.title), locale: Locale(identifier: state.locale)))
            print("Setup locale field=\(identity.rawValue) empty=\(field.stringValue.isEmpty) length=\(field.stringValue.count)")
        }
        try Setup.expectValues(Dictionary(uniqueKeysWithValues: Setup.Field.allCases.map { ($0, long) }), in: sheet)
        try Secure.enabled("privacy.apply", true, locale: state.locale, in: sheet)
        try await fixture.unchanged()
    }
}

@MainActor @Observable
private final class SetupEnvironment {
    var locale = "en"
    var disabled = false
}

private struct SetupEnvironmentHost: View {
    let fixture: SetupFixture
    @Bindable var state: SetupEnvironment

    var body: some View {
        PrivacyButtonSheetHost(content: AnyView(
            PrivacySetupSheet(vault: fixture.vault, tags: [fixture.tag], creating: true,
                              onComplete: { fixture.completed += 1 }, probeSystem: false)
                .disabled(state.disabled)), onDismiss: { fixture.dismissed = true })
            .environment(\.locale, Locale(identifier: state.locale))
    }
}
