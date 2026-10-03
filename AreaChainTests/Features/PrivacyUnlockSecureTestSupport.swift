import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 与原自动锁定夹具相同的归属识别；所有请求必须显式注入内存 vault。
@MainActor
final class PrivacyUnlockSecureTestSupport {
    typealias Secure = SecureInputTestSupport
    typealias Native = SettingsButtonTestSupport
    let preferences: Native
    let system = FakeSystemVaultKeys()
    let vault: PrivacyVault
    let presenter = PrivacyUnlockPresenter()
    let previousWindows: Set<ObjectIdentifier>
    var requestTask: Task<Void, Never>?
    var completed = 0
    var cancelled = 0
    var requestError: PrivacyError?
    var requestEnded = false
    var directWindow: NSWindow?

    init() throws {
        try #require(Bundle.main.bundleIdentifier == "com.areachain.privacy-qa")
        preferences = try Native()
        vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: system)
        previousWindows = Set(NSApp.windows.map(ObjectIdentifier.init))
    }

    func configure(_ method: String) async throws {
        try await vault.create(password: method == "system" ? nil : Secure.sample, systemUnlock: method != "password")
        vault.lock()
    }

    var panel: NSWindow? {
        NSApp.windows.first {
            !previousWindows.contains(ObjectIdentifier($0)) && $0.isVisible && $0.delegate === presenter
        }
    }

    func start(reason: String = "Synthetic unlock reason", force: Bool = false) async throws -> NSWindow {
        // 与 PrivacyAutolockTestSupport 一致，先建立应用内父窗口，再由原 Presenter 创建面板。
        if directWindow == nil {
            let parent = preferences.window(Color.clear)
            directWindow = parent
            try await Secure.ready(parent)
        }
        requestEnded = false
        requestTask = Task {
            do {
                try await presenter.request(reason: reason, force: force, vault: vault)
                completed += 1
            } catch {
                requestError = error as? PrivacyError
                if requestError == .cancelled { cancelled += 1 }
            }
            requestEnded = true
        }
        try await FormInputTestSupport.wait { self.panel != nil }
        let window = try #require(panel)
        try await Secure.ready(window)
        return window
    }

    func mount(locale: String = "en", scheme: ColorScheme = .light, reason: String = "Synthetic unlock reason") async throws -> NSWindow {
        let view = PrivacyUnlockView(vault: vault, reason: reason,
            onComplete: { self.completed += 1 }, onCancel: { self.cancelled += 1 })
        let window = preferences.window(view, locale: locale, scheme: scheme, size: NSSize(width: 390, height: 560))
        directWindow = window
        try await Secure.ready(window)
        return window
    }

    func cleanup() async {
        panel?.close()
        if await system.pendingRead != nil { await system.finishRead() }
        await requestTask?.value
        if let directWindow {
            try? await SystemPageHost.settle(directWindow)
            SystemPageHost.release(directWindow)
        }
        preferences.cleanup()
    }

    static func hasText(_ key: String, locale: String = "en", in window: NSWindow) -> Bool {
        let title = L10n.string(String.LocalizationValue(key), locale: Locale(identifier: locale))
        return Native.elements(window.contentView).contains { node in
            Native.value(node, "accessibilityRole") as? String == "AXStaticText"
                && ["accessibilityLabel", "accessibilityValue"].contains { name in Native.value(node, name) as? String == title }
        }
    }

    static func recordLayout(_ window: NSWindow, name: String) throws {
        let bounds = try #require(window.contentView).bounds
        let nodes = Native.elements(window.contentView).filter {
            ["AXButton", "AXStaticText"].contains(Native.value($0, "accessibilityRole") as? String ?? "")
                || Native.value($0, "accessibilitySubrole") as? String == "AXSecureTextField"
        }
        // AX 包装节点可能与原生字段重合；这里只检查每项边界，不把包装重合作为按钮重叠。
        for node in nodes { try Native.assertBounds([node], in: window) }
        #expect(bounds.width == 390)
        print("Unlock layout \(name) content=\(bounds.size) fitting=\(window.contentView!.fittingSize) fields=\(Secure.fields(window).map { $0.bounds.size })")
        try Native.snapshot(window, name: "unlock7C-\(name)")
    }
}
