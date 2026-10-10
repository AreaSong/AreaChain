import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchContentLegacyTests {
    @Test func existingDiaryWindowKeepsEditableDraftWhenReadonlyViewerOpens() async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        let editor = DiaryEditorSession(source: .entry(f.diary), context: f.context, vault: f.base.vault,
                                       commit: { _ in Issue.record("只读回归不能保存") })
        editor.text = "原小窗未提交内容"
        let root = DiaryWindowView(session: editor, onPin: {}, shortcuts: f.base.hostContext.shortcuts)
            .modelContainer(f.base.data.container).environment(\.modelContext, f.context).environment(f.base.prefs)
            .environment(\.workspaceHostContext, f.base.hostContext)
        let window = NSWindow(contentViewController: NSHostingController(rootView: root))
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 520, height: 400))
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil); window.contentViewController = nil }
        try await SystemPageHost.settle(window)
        let texts = SettingsButtonTestSupport.elements(window.contentView).compactMap { $0 as? NSTextView }
        #expect(texts.contains { $0.isEditable && $0.string == "原小窗未提交内容" })
        try await f.start()
        try await f.query("/diaries")
        try await f.nativeOpen(.init(type: .diary, id: f.diary.id))
        guard case .diary(let content) = f.content.content else { Issue.record("普通全文缺失"); return }
        #expect(content.text == UnifiedSearchContentFixture.text)
        try await f.base.back()
        #expect(editor.text == "原小窗未提交内容" && editor.hasUnsavedChanges)
        #expect(f.diary.text == UnifiedSearchContentFixture.text)
        try f.assertNoWrites()
    }

    @Test func existingAttachmentBrowserUsesExplicitTemporaryStore() async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        try await f.start()
        try await f.base.go("/go/images")
        #expect(f.base.router.mounted("page.attachments"))
        try await f.base.click("attachments.preview." + f.image.id.uuidString)
        #expect(try f.store.readOrdinary(reference: f.image.reference, root: f.root) == UnifiedSearchContentFixture.png())
        try f.assertNoWrites()
    }

    @Test func ordinaryFocusMaskClearsBodyButKeepsQueryAndDoesNotResumeAutomatically() async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        try await f.start()
        try await f.query("/diaries")
        let query = try f.base.handoff.state().query
        try await f.nativeOpen(.init(type: .diary, id: f.diary.id))
        let other = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
                             styleMask: [.titled], backing: .buffered, defer: false)
        other.isReleasedWhenClosed = false
        defer { other.orderOut(nil) }
        other.makeKeyAndOrderFront(nil)
        try await NativeSyntaxUI.prepareFocus(in: other)
        #expect(f.content.content == nil && f.session.isMasked)
        #expect(try f.base.handoff.state().query == query)
        f.base.window?.makeKeyAndOrderFront(nil)
        try await f.base.settle()
        #expect(f.content.content == nil && f.session.isMasked)
        try await f.base.back()
        #expect(f.base.navigation.isSearching && f.content.content == nil)
        #expect(try f.base.handoff.state().query == query)
    }
}
