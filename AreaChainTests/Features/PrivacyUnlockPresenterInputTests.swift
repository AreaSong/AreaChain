import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct PrivacyUnlockPresenterInputTests {
    typealias Host = PrivacyUnlockSecureTestSupport
    typealias Secure = SecureInputTestSupport
    private var locale: String { AppPreferences.shared.resolvedLocale.identifier }

    @Test(arguments: ["password", "system", "both"])
    func originalPanelConfigurationAndSuccess(method: String) async throws {
        try await withHost(method) { host in
            let window = try await host.start()
            #expect(Secure.fields(window).count == (method == "system" ? 0 : 1))
            print("Unlock Presenter initial fieldFocused=\(Secure.fields(window).first?.currentEditor() === window.firstResponder)")
            print("Unlock Presenter locale=\(locale) method=\(method) content=\(window.contentView!.bounds.size)")
            try Host.recordLayout(window, name: "presenter-\(method)")
            if method == "system" {
                try await Secure.click("privacy.unlock.system", locale: locale, in: window)
            } else {
                try await Secure.fill(window)
                try await FormInputTestSupport.key(36, text: "\r", in: window)
            }
            try await FormInputTestSupport.wait { host.requestEnded }
            #expect(host.completed == 1 && host.cancelled == 0 && host.requestError == nil)
            #expect(host.vault.isUnlocked && host.panel == nil && !window.isVisible)
        }
    }

    @Test func passwordFailureKeepsPanelAndRetryCompletesRequest() async throws {
        try await withHost("password") { host in
            let reason = String(repeating: "Synthetic long reason. ", count: 12)
            let window = try await host.start(reason: reason)
            try await Secure.enter("synthetic-wrong-password", in: window)
            try await Secure.click("privacy.unlock.password", locale: locale, in: window)
            try await FormInputTestSupport.wait { !host.vault.isAuthenticating }
            #expect(!host.requestEnded && host.panel === window && host.vault.passwordFailures == 1)
            #expect(Host.hasText(PrivacyError.wrongPassword.messageKey, locale: locale, in: window))
            #expect(Secure.fields(window).allSatisfy { $0.stringValue.isEmpty })
            try Host.recordLayout(window, name: "presenter-long-error")
            try await Task.sleep(for: .milliseconds(1100))
            try await Secure.fill(window)
            try await Secure.click("privacy.unlock.password", locale: locale, in: window)
            try await FormInputTestSupport.wait { host.requestEnded }
            #expect(host.completed == 1 && host.vault.isUnlocked && host.panel == nil)
        }
    }

    @Test(arguments: ["cancel", "close", "escape"], [false, true])
    func originalPresenterCancellationAndLateResult(action: String, busy: Bool) async throws {
        try await withHost("both") { host in
            // 从已解锁状态强制请求，取消后锁定必须由 Presenter 自己完成。
            try await host.vault.unlockWithPassword(Secure.sample)
            let window = try await host.start(force: true)
            if busy {
                await host.system.suspend()
                try await Secure.click("privacy.unlock.system", locale: locale, in: window)
                try #require(await host.system.pendingRead != nil)
                try await Secure.fill(window)
                try Secure.enabled("privacy.unlock.password", false, locale: locale, in: window)
                try Secure.enabled("privacy.unlock.system", false, locale: locale, in: window)
                try Host.recordLayout(window, name: "presenter-busy-\(action)")
            }
            try Secure.enabled("alert.cancel", true, locale: locale, in: window)
            let generation = host.vault.generation
            if action == "close" { window.performClose(nil) }
            else if action == "escape" { try await FormInputTestSupport.key(53, text: "\u{1b}", in: window) }
            else { try await Secure.click("alert.cancel", locale: locale, in: window) }
            try await FormInputTestSupport.wait { host.requestEnded }
            #expect(host.requestError == .cancelled && host.cancelled == 1 && host.completed == 0)
            #expect(host.panel == nil && !window.isVisible && !host.vault.isUnlocked)
            #expect(host.vault.generation > generation)
            if busy {
                await host.system.finishRead()
                try await SystemPageHost.settle(window)
                #expect(!host.vault.isUnlocked && !host.vault.isAuthenticating && host.panel == nil)
                #expect(host.completed == 0 && host.cancelled == 1)
            }
        }
    }

    @Test func visibleOriginalPanelForInspection() async throws {
        try await withHost("both") { host in
            let window = try await host.start(reason: "Synthetic panel for controlled visual inspection. Both unlock methods remain available.")
            try await Secure.fill(window)
            try Host.recordLayout(window, name: "presenter-visible")
            print("UNLOCK7C_VISIBLE window=\(window.windowNumber)")
            try await Task.sleep(for: .seconds(30))
            try await Secure.click("alert.cancel", locale: locale, in: window)
            try await FormInputTestSupport.wait { host.requestEnded }
            #expect(host.cancelled == 1 && !host.vault.isUnlocked)
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
