import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 直接挂载隐私弹窗；Setup 只验证提交前状态，不进入默认认证、文件面板和内容保护链路。
@Suite(.serialized) @MainActor
struct PrivacyButtonConsumerTests {
    private static var retainedContainers: [ModelContainer] = []

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func passwordValidationBusyFailureAndRetry(locale: String, scheme: ColorScheme) async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        var calls = 0
        var completed = 0
        var pending: CheckedContinuation<Void, Error>?
        defer { pending?.resume(throwing: PrivacyError.cancelled) }
        let sheet = PrivacyPasswordSheet(title: "privacy.master.label", confirmation: true,
            explanation: "privacy.master.help", action: { _ in
                calls += 1
                try await withCheckedThrowingContinuation { pending = $0 }
            }, onComplete: { completed += 1 })
        let window = host(sheet, f: f, locale: locale, scheme: scheme, size: NSSize(width: 440, height: 330))
        defer { SystemPageHost.release(window) }
        try await ready(window)
        try expectEnabled("common.save", false, locale: locale, in: window)
        try await click("common.save", locale: locale, in: window)
        #expect(calls == 0)
        try await enter("synthetic-password", index: 0, in: window)
        try await enter("different-password", index: 1, in: window)
        try expectEnabled("common.save", false, locale: locale, in: window)
        try await enter("synthetic-password", index: 1, in: window)
        try expectEnabled("common.save", true, locale: locale, in: window)
        try snapshot(window, name: "password-ready-\(locale)-\(scheme)")
        try await click("common.save", locale: locale, in: window)
        try #require(pending != nil)
        try expectEnabled("common.save", false, locale: locale, in: window)
        try expectEnabled("alert.cancel", false, locale: locale, in: window)
        #expect(fields(window.contentView).allSatisfy { $0.stringValue.isEmpty })
        try await click("common.save", locale: locale, in: window)
        try await click("alert.cancel", locale: locale, in: window)
        #expect(calls == 1 && completed == 0)
        pending?.resume(throwing: PrivacyError.corruptData)
        pending = nil
        try await SystemPageHost.settle(window)
        #expect(labels(window).contains(localized(PrivacyError.corruptData.messageKey, locale)))
        try expectEnabled("alert.cancel", true, locale: locale, in: window)
        try snapshot(window, name: "password-error-\(locale)-\(scheme)")
        try await enter("synthetic-password", index: 0, in: window)
        try await enter("synthetic-password", index: 1, in: window)
        try await click("common.save", locale: locale, in: window)
        try #require(pending != nil)
        pending?.resume()
        pending = nil
        try await SystemPageHost.settle(window)
        #expect(calls == 2 && completed == 1)
    }

    @Test func unlockBusyCancelAndErrorRecoveryUseOnlyFakeKeys() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let system = FakeSystemVaultKeys()
        let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: system)
        try await vault.create(password: "synthetic-password", systemUnlock: true)
        vault.lock()
        await system.suspend()
        var completed = 0
        var cancelled = 0
        let content = PrivacyUnlockView(vault: vault, reason: "Synthetic authentication reason",
                                       onComplete: { completed += 1 }, onCancel: { cancelled += 1 })
        let window = host(content, f: f, locale: "en", scheme: .light, size: NSSize(width: 390, height: 390))
        defer { SystemPageHost.release(window) }
        try await ready(window)
        try expectEnabled("privacy.unlock.password", false, locale: "en", in: window)
        try await enter("synthetic-password", index: 0, in: window)
        try await click("privacy.unlock.system", locale: "en", in: window)
        try #require(await system.pendingRead != nil)
        // 确保测试失败也释放替身等待；不让认证任务悬挂到下一场景。
        do {
            try expectEnabled("privacy.unlock.system", false, locale: "en", in: window)
            try expectEnabled("privacy.unlock.password", false, locale: "en", in: window)
            try expectEnabled("alert.cancel", true, locale: "en", in: window)
            try await click("privacy.unlock.system", locale: "en", in: window)
            try await click("privacy.unlock.password", locale: "en", in: window)
            try await click("alert.cancel", locale: "en", in: window)
            #expect(completed == 0 && cancelled == 1)
            #expect(fields(window.contentView).allSatisfy { $0.stringValue.isEmpty })
        } catch {
            vault.lock()
            await system.finishRead()
            throw error
        }
        // 此处主动使等待失效以验证错误恢复；不声称覆盖 Presenter 的取消/continuation 生命周期。
        vault.lock()
        await system.finishRead()
        try await SystemPageHost.settle(window)
        #expect(labels(window).contains(localized(PrivacyError.staleOperation.messageKey, "en")))
        try expectEnabled("privacy.unlock.system", true, locale: "en", in: window)
        try await enter("synthetic-password", index: 0, in: window)
        try await click("privacy.unlock.password", locale: "en", in: window)
        try await waitUntil { completed == 1 }
        #expect(vault.isUnlocked && completed == 1 && cancelled == 1)
    }

    @Test func fakeSystemUnlockCompletesOnce() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        try await f.vault.enableSystemUnlock()
        f.vault.lock()
        var completed = 0
        let view = PrivacyUnlockView(vault: f.vault, reason: "Synthetic system unlock",
                                    onComplete: { completed += 1 }, onCancel: {})
        let window = host(view, f: f, locale: "en", scheme: .dark, size: NSSize(width: 390, height: 300))
        defer { SystemPageHost.release(window) }
        try await ready(window)
        for key in ["privacy.unlock.system", "privacy.unlock.password", "alert.cancel"] {
            _ = try buttonFrame(key, locale: "en", in: window)
        }
        try snapshot(window, name: "unlock-initial-size")
        try await click("privacy.unlock.system", locale: "en", in: window)
        try await waitUntil { completed == 1 }
        #expect(f.vault.isUnlocked && completed == 1)
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func setupValidationAndLongUnlockLayout(locale: String, scheme: ColorScheme) async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        try await f.vault.enableSystemUnlock()
        let reason = locale == "en"
            ? "Verify your identity to access this synthetic private note. Both configured unlock methods remain available."
            : "访问此合成私密手记需要验证身份。系统验证与主密码均可使用，请选择已配置的验证方式继续。"
        let unlock = host(PrivacyUnlockView(vault: f.vault, reason: reason, onComplete: {}, onCancel: {}),
                          f: f, locale: locale, scheme: scheme, size: NSSize(width: 390, height: 390))
        try await ready(unlock)
        for key in ["privacy.unlock.system", "privacy.unlock.password", "alert.cancel"] {
            _ = try buttonFrame(key, locale: locale, in: unlock)
        }
        let fullWidth = try buttonFrame("privacy.unlock.system", locale: locale, in: unlock)
        #expect(fullWidth.width >= 340)
        try snapshot(unlock, name: "unlock-\(locale)-\(scheme)")
        SystemPageHost.release(unlock)
        let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
        let tag = try f.tag(private: false)
        tag.name = "Synthetic long classification abcdefghijklmnopqrstuvwxyz"
        let content = PrivacySetupSheet(vault: vault, tags: [tag], creating: true, onComplete: {}, probeSystem: false)
        let setup = host(content, f: f, locale: locale, scheme: scheme, size: NSSize(width: 480, height: 540))
        defer { SystemPageHost.release(setup) }
        try await ready(setup)
        try expectEnabled("privacy.apply", true, locale: locale, in: setup)
        try await click("privacy.methods.system", role: "AXCheckBox", locale: locale, in: setup)
        try expectEnabled("privacy.apply", false, locale: locale, in: setup)
        try await click("privacy.methods.master", role: "AXCheckBox", locale: locale, in: setup)
        try expectEnabled("privacy.apply", false, locale: locale, in: setup)
        try await enter("short", index: 0, in: setup)
        try await enter("short", index: 1, in: setup)
        try expectEnabled("privacy.apply", false, locale: locale, in: setup)
        try await enter("synthetic-password", index: 0, in: setup)
        try expectEnabled("privacy.apply", false, locale: locale, in: setup)
        try await enter("synthetic-password", index: 1, in: setup)
        try expectEnabled("privacy.apply", true, locale: locale, in: setup)
        _ = try buttonFrame("alert.cancel", locale: locale, in: setup)
        _ = try buttonFrame("privacy.apply", locale: locale, in: setup)
        try snapshot(setup, name: "setup-\(locale)-\(scheme)")
        #expect(!vault.isConfigured && !tag.isPrivateDiary)
    }

    @Test(arguments: [false, true])
    func idleCancelDismissesActualSheetWithoutSubmitting(setup: Bool) async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        var calls = 0
        var completed = 0
        var dismissals = 0
        let content: AnyView
        if setup {
            content = AnyView(PrivacySetupSheet(vault: f.vault, tags: [], creating: false,
                onComplete: { completed += 1 }, probeSystem: false))
        } else {
            content = AnyView(PrivacyPasswordSheet(title: "privacy.master.label", confirmation: false,
                explanation: "privacy.master.help", action: { _ in calls += 1 }, onComplete: { completed += 1 }))
        }
        let window = host(PrivacyButtonSheetHost(content: content, onDismiss: { dismissals += 1 }),
                          f: f, locale: "en", scheme: .light, size: NSSize(width: 520, height: 600))
        defer { SystemPageHost.release(window) }
        try await waitUntil { window.attachedSheet != nil }
        let sheet = try #require(window.attachedSheet)
        try await ready(sheet)
        // 原生 sheet 的呈现有位移；坐标需在过渡结束后读取。
        var previous = sheet.frame
        var stable = 0
        try await waitUntil {
            stable = sheet.frame == previous ? stable + 1 : 0
            previous = sheet.frame
            return stable >= 3
        }
        if !setup {
            try await enter("synthetic-cancelled", index: 0, in: sheet)
            try expectEnabled("common.save", true, locale: "en", in: sheet)
        }
        try await click("alert.cancel", locale: "en", in: sheet)
        try await waitUntil { window.attachedSheet == nil && dismissals == 1 }
        #expect(calls == 0 && completed == 0 && dismissals == 1)
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func homeMethodsAndFallbackKeepButtonContracts(locale: String, scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let previous = StoreHealth.shared.isUsingMemoryFallback
        defer { StoreHealth.shared.isUsingMemoryFallback = previous }
        for method in ["password", "system", "both"] {
            let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
            try await vault.create(password: method == "system" ? nil : "synthetic-password", systemUnlock: method != "password")
            for locked in [false, true] {
                if locked { vault.lock() }
                StoreHealth.shared.isUsingMemoryFallback = false
                let window = support.window(PrivacyUnlockSettingsView(vault: vault), locale: locale, scheme: scheme)
                defer { SystemPageHost.release(window) }
                try await ready(window)
                let keys = ["privacy.tags.manage", locked ? "privacy.unlock.title" : "privacy.lock.now",
                            method == "password" ? "privacy.system.enable" : "privacy.system.disable",
                            method == "system" ? "privacy.master.set" : "privacy.master.change"]
                    + (method == "system" ? [] : ["privacy.master.remove"])
                let buttons = try keys.map { try element($0, locale: locale, in: window) }
                try SettingsButtonTestSupport.assertBounds(buttons, in: window)
                try expectEnabled(keys[2], method != "system", locale: locale, in: window)
                if method != "system" { try expectEnabled("privacy.master.remove", method == "both", locale: locale, in: window) }
                try snapshot(window, name: "home-\(method)-\(locked)-\(locale)-\(scheme)")
                StoreHealth.shared.isUsingMemoryFallback = true
                try await SystemPageHost.settle(window)
                for key in keys { try expectEnabled(key, false, locale: locale, in: window) }
            }
        }
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func backupButtonsAndPasswordCancelStayIsolated(locale: String, scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let previous = StoreHealth.shared.isUsingMemoryFallback
        defer { StoreHealth.shared.isUsingMemoryFallback = previous }
        StoreHealth.shared.isUsingMemoryFallback = false
        let window = support.window(DataBackupView(), locale: locale, scheme: scheme)
        defer { SystemPageHost.release(window) }
        try await ready(window)
        let keys = ["settings.export", "settings.import", "privacy.backup.export", "privacy.backup.restore"]
        try SettingsButtonTestSupport.assertBounds(try keys.map { try element($0, locale: locale, in: window) }, in: window)
        #expect(!SystemPageHost.identifiers(in: window).contains("dataBackup.reset"))
        try snapshot(window, name: "backup-\(locale)-\(scheme)")
        for key in keys.suffix(2) {
            try await ready(window)
            try await click(key, locale: locale, in: window)
            try await waitUntil { window.attachedSheet != nil }
            let sheet = try #require(window.attachedSheet)
            try await ready(sheet)
            // 只打开/取消密码 sheet；Save 后才进入默认 vault、文件面板及备份服务。
            try expectEnabled(keys[2], false, locale: locale, in: window)
            try expectEnabled(keys[3], false, locale: locale, in: window)
            try expectEnabled("common.save", false, locale: locale, in: sheet)
            try await Task.sleep(for: .milliseconds(350))
            try await click("alert.cancel", locale: locale, in: sheet)
            try await waitUntil { window.attachedSheet == nil }
            try expectEnabled(keys[2], true, locale: locale, in: window)
            try expectEnabled(keys[3], true, locale: locale, in: window)
        }
        StoreHealth.shared.isUsingMemoryFallback = true
        try await SystemPageHost.settle(window)
        let reset = try element("settings.reset", locale: locale, in: window)
        try await SettingsButtonTestSupport.reveal(reset, in: window)
        _ = try buttonFrame("settings.reset", locale: locale, in: window)
        try snapshot(window, name: "backup-fallback-\(locale)-\(scheme)")
        #expect(try support.container.mainContext.fetchCount(FetchDescriptor<DiaryEntry>()) == 0)
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func homeUnconfiguredUnavailableAndCleanupLayout(locale: String, scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        for unavailable in [false, true] {
            let store = MemoryVaultConfigurationStore()
            store.pendingSystemKeyIDs = [UUID()]
            if unavailable { store.loadError = PrivacyError.storageFailure }
            let vault = PrivacyVault(store: store, systemKeys: FakeSystemVaultKeys())
            let window = support.window(PrivacyUnlockSettingsView(vault: vault), locale: locale, scheme: scheme)
            defer { SystemPageHost.release(window) }
            try await ready(window)
            let ids = SystemPageHost.identifiers(in: window)
            #expect(ids.contains("privacy.setup") == !unavailable)
            #expect(!ids.contains("privacy.tags.manage"))
            if unavailable {
                #expect(!ids.contains("privacy.system.cleanup.retry"))
            } else {
                _ = try buttonFrame("privacy.system.cleanup.retry", locale: locale, in: window)
            }
            try snapshot(window, name: "home-unavailable-\(unavailable)-\(locale)-\(scheme)")
            if !unavailable {
                let attachment = AttachmentItem(ownerKind: "diary", ownerID: UUID(), filename: "synthetic.png")
                attachment.retiredStorageID = UUID()
                support.container.mainContext.insert(attachment)
                try support.container.mainContext.save()
                try await SystemPageHost.settle(window)
                _ = try buttonFrame("privacy.cleanup.retry", locale: locale, in: window)
                try snapshot(window, name: "home-attachment-cleanup-\(locale)-\(scheme)")
            }
        }
    }

    @Test func homeManagementSheetsCancelWithoutChangingMethods() async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
        try await vault.create(password: "synthetic-password", systemUnlock: true)
        let revision = vault.revision
        let window = support.window(PrivacyUnlockSettingsView(vault: vault))
        defer { SystemPageHost.release(window) }
        // 标签管理 creating=false 不执行系统探测；密码 sheet 在 Save 前不调用认证。
        for key in ["privacy.tags.manage", "privacy.master.change", "privacy.system.disable"] {
            try await ready(window)
            try await click(key, locale: "en", in: window)
            try await waitUntil { window.attachedSheet != nil }
            let sheet = try #require(window.attachedSheet)
            try await ready(sheet)
            try await Task.sleep(for: .milliseconds(350))
            try await click("alert.cancel", locale: "en", in: sheet)
            try await waitUntil { window.attachedSheet == nil }
            #expect(vault.revision == revision && vault.hasMasterPassword && vault.hasSystemUnlock)
        }
    }

    private func host<Content: View>(_ content: Content, f: PrivacyFixture, locale: String,
                                     scheme: ColorScheme, size: NSSize) -> NSWindow {
        Self.retainedContainers.append(f.container)
        return SystemPageHost.window(content, container: f.container, scheme: scheme,
                                     locale: locale, size: size, embedded: false)
    }

    private func ready(_ window: NSWindow) async throws {
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !condition(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(40)) }
        try #require(condition())
    }

    private func localized(_ key: String, _ locale: String) -> String {
        L10n.string(String.LocalizationValue(key), locale: Locale(identifier: locale))
    }

    private func element(_ key: String, role: String = "AXButton", locale: String, in window: NSWindow) throws -> NSObject {
        let title = localized(key, locale)
        return try #require(elements(window.contentView).first {
            value($0, "accessibilityRole") as? String == role
                && ((value($0, "accessibilityLabel") as? String) == title
                    || (value($0, "accessibilityTitle") as? String) == title)
        }, "未找到生产控件：\(key)")
    }

    private func expectEnabled(_ key: String, _ enabled: Bool, locale: String, in window: NSWindow) throws {
        let button = try element(key, locale: locale, in: window)
        let actual = try #require(button.value(forKey: "accessibilityEnabled") as? Bool)
        #expect(actual == enabled, "按钮禁用状态：\(key)")
    }

    private func buttonFrame(_ key: String, role: String = "AXButton", locale: String, in window: NSWindow) throws -> NSRect {
        let control = try element(key, role: role, locale: locale, in: window)
        let screen = try #require(control.value(forKey: "accessibilityFrame") as? NSValue).rectValue
        let rect = window.convertFromScreen(screen)
        let bounds = try #require(window.contentView).bounds
        #expect(rect.width > 0 && rect.height > 0)
        #expect(rect.minX >= 0 && rect.maxX <= bounds.width && rect.minY >= 0 && rect.maxY <= bounds.height)
        return rect
    }

    private func click(_ key: String, role: String = "AXButton", locale: String, in window: NSWindow) async throws {
        let rect = try buttonFrame(key, role: role, locale: locale, in: window)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(with: type, location: NSPoint(x: rect.midX, y: rect.midY),
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            NSApp.sendEvent(event)
        }
        try await SystemPageHost.settle(window)
    }

    private func fields(_ root: NSView?) -> [NSSecureTextField] {
        guard let root else { return [] }
        if let field = root as? NSSecureTextField { return [field] }
        return root.subviews.flatMap { fields($0) }
    }

    private func enter(_ text: String, index: Int, in window: NSWindow) async throws {
        let fields = fields(window.contentView).sorted {
            $0.convert($0.bounds, to: nil).midY > $1.convert($1.bounds, to: nil).midY
        }
        try #require(fields.indices.contains(index))
        let field = fields[index]
        window.makeFirstResponder(field)
        let editor = try #require(field.currentEditor())
        editor.string = text
        NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: field)
        try await SystemPageHost.settle(window)
    }

    private func value(_ node: NSObject, _ name: String) -> Any? {
        let selector = NSSelectorFromString(name)
        return node.responds(to: selector) ? node.perform(selector)?.takeUnretainedValue() : nil
    }

    private func elements(_ root: NSView?) -> [NSObject] {
        guard let root else { return [] }
        var queue: [NSObject] = [root]
        var seen = Set<ObjectIdentifier>()
        var result: [NSObject] = []
        while let node = queue.popLast() {
            guard seen.insert(ObjectIdentifier(node)).inserted else { continue }
            result.append(node)
            if let view = node as? NSView { queue.append(contentsOf: view.subviews) }
            if let children = value(node, "accessibilityChildren") as? [NSObject] { queue.append(contentsOf: children) }
        }
        return result
    }

    private func labels(_ window: NSWindow) -> String {
        elements(window.contentView).compactMap {
            (value($0, "accessibilityLabel") ?? value($0, "accessibilityTitle") ?? value($0, "accessibilityValue")) as? String
        }.joined(separator: "\n")
    }

    private func snapshot(_ window: NSWindow, name: String) throws {
        let view = try #require(window.contentView)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        let directory = FileManager.default.temporaryDirectory.appending(path: "AreaChainButtonConsumersQA")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appending(path: "privacy-\(name).png"))
    }
}

struct PrivacyButtonSheetHost: View {
    @Environment(\.locale) private var locale
    let content: AnyView
    var onDismiss: () -> Void
    @State private var presented = true
    var body: some View {
        Color.clear.sheet(isPresented: $presented, onDismiss: onDismiss) { content.environment(\.locale, locale) }
    }
}
