import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct PrivacyRenderingTests {
    // SwiftUI 的 @Query 观察者可能晚于窗口拆卸释放；与现有渲染矩阵保持相同的容器寿命。
    private static var retainedContainers: [ModelContainer] = []
    @Test func privacySettingsAndDualUnlockRenderInBothAppearances() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        _ = try f.tag()
        try await f.vault.enableSystemUnlock()
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            let settings = host(Form { PrivacySettingsSection(vault: f.vault) }.formStyle(.grouped),
                                fixture: f, scheme: scheme, size: NSSize(width: 560, height: 640))
            try await settle(settings)
            try snapshot(settings, name: "privacy-settings-\(suffix)")
            release(settings)
            let unlock = host(PrivacyUnlockView(vault: f.vault, reason: "访问私密手记需要验证身份。",
                                                onComplete: {}, onCancel: {}),
                              fixture: f, scheme: scheme, size: NSSize(width: 400, height: 390))
            try await settle(unlock)
            #expect(collect(unlock.contentView!, as: NSSecureTextField.self).count == 1)
            try snapshot(unlock, name: "privacy-unlock-\(suffix)")
            release(unlock)
        }
    }

    @Test func lockingRemovesPrivateEditorFromNativeHierarchy() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let tag = try f.tag()
        let secret = "UI_PRIVATE_EDITOR_SENTINEL"
        let note = try f.repository.addDiary(text: secret, dayKey: "2026-09-15", tagIDs: [tag.id])
        let session = DiaryEditorSession(source: .entry(note), context: f.context, vault: f.vault)
        session.reveal()
        let window = host(DiaryWindowView(session: session, onPin: {}), fixture: f,
                          scheme: .light, size: NSSize(width: 420, height: 360))
        defer { release(window) }
        try await settle(window)
        #expect(collect(window.contentView!, as: NSTextView.self).contains { $0.string.contains(secret) })
        f.vault.lock()
        try await settle(window)
        #expect(collect(window.contentView!, as: NSTextView.self).allSatisfy { !$0.string.contains(secret) })
        #expect(!session.canRevealContent && session.text.isEmpty)
        try snapshot(window, name: "privacy-locked-note")
    }

    @Test func setupExplainsProtectionAndDoesNotMutateModelsWhileRendering() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let tag = try f.tag(private: false)
        let note = try f.repository.addDiary(text: "测试记录", dayKey: "2026-09-15", tagIDs: [tag.id])
        let unconfigured = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
        let window = host(PrivacySetupSheet(vault: unconfigured, tags: [tag], creating: true, onComplete: {}, probeSystem: false),
                          fixture: f, scheme: .light, size: NSSize(width: 500, height: 540))
        defer { release(window) }
        try await settle(window)
        try snapshot(window, name: "privacy-setup")
        #expect(!tag.isPrivateDiary && !note.hasProtectedContent && !unconfigured.isConfigured)
    }

    @Test func quickDraftSealsOnApplicationAndWindowFocusLoss() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let tag = try f.tag()
        let capture = BoardComposerSession(vault: f.vault)
        let secret = "QUICK_PRIVATE_DRAFT_SENTINEL"
        capture.diary = BoardComposerDraft(text: secret, selectedTagIDs: [tag.id], needsProtection: true)
        let binding = Binding(get: { capture.diary }, set: { capture.diary = $0 })
        let content = DiaryPage(todayKey: "2026-09-15", entries: [],
                                options: DiaryPageOptions(composerDraft: binding, vault: f.vault))
        let window = host(content, fixture: f, scheme: .light, size: NSSize(width: 560, height: 500))
        defer { release(window) }
        let notifications: [(Notification.Name, Any)] = [
            (.privacyMask, f.vault), (NSApplication.didResignActiveNotification, NSApp!),
            (NSWindow.didResignKeyNotification, window)
        ]
        for (name, object) in notifications {
            try capture.diary.restore(vault: f.vault)
            try await settle(window)
            #expect(collect(window.contentView!, as: NSTextView.self).contains { $0.string.contains(secret) })
            NotificationCenter.default.post(name: name, object: object)
            try await settle(window)
            #expect(capture.diary.text.isEmpty && capture.diary.sealed != nil && f.vault.isUnlocked)
            #expect(collect(window.contentView!, as: NSTextView.self).allSatisfy { !$0.string.contains(secret) })
            #expect(collect(window.contentView!, as: DaybookAppKitTextView.self).isEmpty, "Focus notification: \(name.rawValue)")
        }
        try snapshot(window, name: "privacy-masked-quick-draft")
    }

    @Test func aNewPrivateTagInACardDraftCannotRemainVisibleAfterLock() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let tag = try f.tag()
        let note = try f.repository.addDiary(text: "普通原文", dayKey: "2026-09-15", tagIDs: [])
        let drafts = DiaryCardDrafts()
        let editor = drafts.begin(note, context: f.context, vault: f.vault)
        let card = DiaryNoteCard(entry: note, activeTags: [tag], attachments: [], onDelete: {},
                                 draftStore: drafts, vault: f.vault)
        let window = host(card, fixture: f, scheme: .light, size: NSSize(width: 480, height: 260))
        defer { release(window) }
        try await settle(window)
        #expect(collect(window.contentView!, as: NSTextView.self).contains { $0.string == "普通原文" })
        let secret = "NEW_PRIVATE_CARD_SENTINEL #私人"
        editor.text = secret
        try await settle(window)
        #expect(editor.needsUnlock && !note.hasProtectedContent)
        f.vault.lock()
        try await settle(window)
        #expect(editor.text.isEmpty && editor.hasUnsavedChanges)
        #expect(collect(window.contentView!, as: NSTextView.self).allSatisfy { !$0.string.contains("NEW_PRIVATE_CARD_SENTINEL") })
        try await f.vault.unlockWithPassword("fixture-master-password")
        #expect(editor.text == secret && !editor.canRevealContent)
        #expect(note.text == "普通原文")
        try snapshot(window, name: "privacy-locked-card-draft")
    }

    private func host<Content: View>(_ content: Content, fixture: PrivacyFixture, scheme: ColorScheme, size: NSSize) -> NSWindow {
        Self.retainedContainers.append(fixture.container)
        let root = content.modelContainer(fixture.container)
            .environment(\.locale, Locale(identifier: "zh-Hans"))
            .environment(AppPreferences.shared)
            .preferredColorScheme(scheme).background(DaybookTheme.paper).transaction { $0.disablesAnimations = true }
        let hosting = NSHostingView(rootView: root)
        hosting.safeAreaRegions = []
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentView = hosting
        window.setContentSize(size)
        window.orderFront(nil)
        return window
    }

    private func settle(_ window: NSWindow) async throws {
        window.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(180))
        window.contentView?.layoutSubtreeIfNeeded()
    }

    private func collect<T: NSView>(_ root: NSView, as type: T.Type) -> [T] {
        (root as? T).map { [$0] } ?? root.subviews.flatMap { collect($0, as: type) }
    }

    private func snapshot(_ window: NSWindow, name: String) throws {
        let view = try #require(window.contentView)
        view.displayIfNeeded()
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        #if compiler(>=6.2)
        Attachment.record(Array(png), named: name + ".png")
        #endif
    }

    private func release(_ window: NSWindow) {
        window.makeFirstResponder(nil)
        window.orderOut(nil)
        window.contentView = nil
    }
}
