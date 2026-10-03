import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 接入前后运行同一生产 View、宿主和操作；回调计数不代表 Presenter 关闭接线。
@Suite(.serialized) @MainActor
struct PrivacyUnlockSecureInputTests {
    typealias Host = PrivacyUnlockSecureTestSupport
    typealias Secure = SecureInputTestSupport
    typealias Native = SettingsButtonTestSupport

    @Test(arguments: ["password", "system", "both"], ["en", "zh-Hans"])
    func configurationsAndNativeIdentity(method: String, locale: String) async throws {
        try await withHost(method) { host in
            for scheme in [ColorScheme.light, .dark] {
                let window = try await host.mount(locale: locale, scheme: scheme)
                let fields = Secure.fields(window)
                #expect(fields.count == (method == "system" ? 0 : 1))
                let nodes = Native.elements(window.contentView).filter {
                    Native.value($0, "accessibilityIdentifier") as? String == "privacy.master.input"
                }
                #expect(nodes.count == fields.count)
                #expect(nodes.allSatisfy { Native.value($0, "accessibilitySubrole") as? String == "AXSecureTextField" })
                if let field = fields.first {
                    #expect(field.placeholderString == L10n.string("privacy.master.placeholder", locale: Locale(identifier: locale)))
                    #expect((field.cell as? NSSecureTextFieldCell)?.echosBullets == true)
                    print("Unlock initial fieldFocused=\(field.currentEditor() === window.firstResponder)")
                    #expect(Host.hasText("privacy.master.label", locale: locale, in: window))
                    try await Secure.fill(window)
                    let metadata = nodes.flatMap { node in
                        ["accessibilityLabel", "accessibilityHelp", "accessibilityTitle"].compactMap { Native.value(node, $0) as? String }
                    }
                    #expect(!metadata.contains { $0.contains(Secure.sample) })
                    try await FormInputTestSupport.key(48, text: "\t", in: window)
                    print("Unlock Tab fieldFocused=\(field.currentEditor() === window.firstResponder)")
                }
                #expect(host.completed == 0 && !host.vault.isUnlocked)
                try Host.recordLayout(window, name: "\(method)-\(locale)-\(scheme)")
                try await FormInputTestSupport.key(53, text: "\u{1b}", in: window)
                #expect(window.isVisible && host.cancelled > 0)
                SystemPageHost.release(window)
            }
        }
    }

    @Test func emptyReturnFailureRetryAndCommandReturn() async throws {
        try await withHost("password") { host in
            let window = try await host.mount()
            try Secure.enabled("privacy.unlock.password", false, in: window)
            _ = try await FormInputTestSupport.editor(#require(Secure.fields(window).first), in: window)
            let generation = host.vault.generation
            try await FormInputTestSupport.key(36, text: "\r", in: window)
            try await FormInputTestSupport.wait { !host.vault.isAuthenticating }
            #expect(host.vault.generation == generation + 1 && host.completed == 0)
            #expect(Host.hasText(PrivacyError.wrongPassword.messageKey, in: window))
            try await Task.sleep(for: .milliseconds(1100))
            try await Secure.enter("synthetic-wrong-password", in: window)
            try await Secure.click("privacy.unlock.password", in: window)
            try await FormInputTestSupport.wait { !host.vault.isAuthenticating }
            #expect(host.vault.passwordFailures == 2 && host.completed == 0)
            #expect(Secure.fields(window).allSatisfy { $0.stringValue.isEmpty })
            try await Task.sleep(for: .milliseconds(1100))
            try await Secure.fill(window)
            try await FormInputTestSupport.key(36, text: "\r", flags: .command, in: window)
            #expect(host.vault.generation == generation + 2 && host.completed == 0)
            try await FormInputTestSupport.key(36, text: "\r", in: window)
            try await FormInputTestSupport.wait { host.completed == 1 }
            #expect(host.vault.generation == generation + 3 && host.vault.isUnlocked)
            #expect(Secure.fields(window).allSatisfy { $0.stringValue.isEmpty })
        }
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func busyInputCancelFailureAndLongLayout(locale: String, scheme: ColorScheme) async throws {
        try await withHost("both") { host in
            let reason = String(repeating: locale == "en" ? "Synthetic long unlock reason. " : "合成长解锁说明。", count: 12)
            let window = try await host.mount(locale: locale, scheme: scheme, reason: reason)
            try await Secure.fill(window)
            await host.system.suspend()
            try await Secure.click("privacy.unlock.system", locale: locale, in: window)
            try #require(await host.system.pendingRead != nil)
            #expect(Secure.fields(window).allSatisfy { $0.stringValue.isEmpty && $0.isEnabled })
            let generation = host.vault.generation
            try await Secure.enter("pending-synthetic-input", in: window)
            for key in ["privacy.unlock.password", "privacy.unlock.system"] {
                try Secure.enabled(key, false, locale: locale, in: window)
                try await Secure.click(key, locale: locale, in: window)
            }
            try await FormInputTestSupport.key(36, text: "\r", in: window)
            try await FormInputTestSupport.key(36, text: "\r", flags: .command, in: window)
            #expect(host.vault.generation == generation && host.completed == 0)
            try Secure.enabled("alert.cancel", true, locale: locale, in: window)
            try await Secure.click("alert.cancel", locale: locale, in: window)
            #expect(host.cancelled == 1 && window.isVisible && host.vault.isAuthenticating)
            try Host.recordLayout(window, name: "busy-\(locale)-\(scheme)")
            // 直接 View 的取消只回调；替身返回损坏数据以验证错误恢复，不手动锁定来冒充取消接线。
            await host.system.failPendingRead()
            try await SystemPageHost.settle(window)
            #expect(Secure.hasError(window, locale: locale))
            #expect(Secure.fields(window).allSatisfy { !$0.stringValue.isEmpty })
            try Host.recordLayout(window, name: "error-\(locale)-\(scheme)")
            try await Secure.fill(window)
            try await Secure.click("privacy.unlock.password", locale: locale, in: window)
            try await FormInputTestSupport.wait { host.completed == 1 }
            #expect(host.vault.isUnlocked && Secure.fields(window).allSatisfy { $0.stringValue.isEmpty })
        }
    }

    private func withHost(_ method: String, _ work: (Host) async throws -> Void) async throws {
        let host = try Host()
        do {
            try await host.configure(method)
            try await work(host)
            await host.cleanup()
        } catch {
            await host.cleanup()
            throw error
        }
    }
}

extension FakeSystemVaultKeys {
    /// 仅测试替身释放失败等待，避免 cleanup 二次 resume；不改认证实现。
    func failPendingRead() {
        let continuation = pendingRead
        pendingRead = nil
        continuation?.resume(throwing: PrivacyError.corruptData)
    }
}
