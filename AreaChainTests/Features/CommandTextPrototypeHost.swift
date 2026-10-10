#if AREACHAIN_QA
import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@MainActor final class CommandTextPrototypeHost {
    let window: NSWindow
    let editor: CommandProtectedTextView
    let service: CommandDraftContentSession
    let vault: PrivacyVault
    private let closeFixture: () -> Void

    init(window: NSWindow, editor: CommandProtectedTextView, service: CommandDraftContentSession,
         vault: PrivacyVault, close: @escaping () -> Void) {
        self.window = window; self.editor = editor; self.service = service; self.vault = vault
        closeFixture = close
    }

    func close() {
        editor.end()
        SystemPageHost.release(window)
        window.close()
        closeFixture()
    }

    static func make(_ journal: CommandTextPrototypeJournal, protected: Bool) async throws -> Self {
        if journal.host == "probe" { return try await probe(journal, protected: protected) }
        return try await parameter(journal, protected: protected)
    }

    private static func probe(_ journal: CommandTextPrototypeJournal, protected: Bool) async throws -> Self {
        let f = try ProtectedDraftFixture(configured: protected)
        try f.start()
        try journal.measure("fixtureBodyAndProtection") {
            try f.host.send(.operation(.edit(f.draft().stamp, .init(parameter: .notes, operation: .replace, value: .longText(journal.body())))))
            if protected { _ = try f.service.protect(f.draft().stamp, expecting: f.host.owned().lease) }
        }
        let editor = CommandProtectedTextView(session: f.service, textSystem: journal.engine.system())
        editor.font = NSFont.systemFont(ofSize: 12)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        scroll.hasVerticalScroller = true
        scroll.scrollerStyle = .overlay
        scroll.documentView = editor
        let window = NSWindow(contentRect: scroll.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = scroll
        try await show(window)
        editor.setFrameSize(NSSize(width: scroll.contentSize.width, height: scroll.contentSize.height))
        try journal.measure("restoreAndAttach") {
            try editor.begin(using: protected ? f.restore() : f.service.explicitlyEditOrdinary(f.draft().stamp, expecting: f.host.owned().lease))
        }
        try #require(window.makeFirstResponder(editor))
        return Self(window: window, editor: editor, service: f.service, vault: f.vault, close: { _ = f })
    }

    private static func parameter(_ journal: CommandTextPrototypeJournal, protected: Bool) async throws -> Self {
        let synthetic = try ProtectedDraftFixture(configured: protected)
        let f = try UnifiedSearchResultsFixture(testVault: synthetic.vault)
        _ = try await f.publish()
        f.controller.assembleLongText(vault: synthetic.vault)
        try f.startOperation("todo.notes")
        try journal.measure("fixtureBodyAndProtection") {
            try f.handoff.send(.operation(.edit(f.draft.stamp, .init(parameter: .notes, operation: .replace, value: .longText(journal.body())))))
            _ = f.controller.publishOperation(text: f.controller.buffer.text)
            if protected {
                f.controller.protectLongText(source: f.controller.buffer)
                try #require(f.controller.editingDraft?.protectedReference != nil)
            }
        }
        let compact = journal.host == "compact"
        let width: CGFloat = compact ? 480 : 740
        let root = UnifiedSearchOperationTestContent(controller: f.controller, layout: compact ? .compact : .standard)
            .environment(\.commandTextPrototype, journal.engine)
            .environment(\.locale, Locale(identifier: compact ? "zh-Hans" : "en"))
            .preferredColorScheme(compact ? .dark : .light)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 960),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: root)
        try await show(window)
        try f.session.resumeDisplay(expecting: f.controller.buffer.lease)
        f.controller.refreshOperationPresentation()
        let start = ContinuousClock.now
        journal.resetPhases()
        try journal.record("openRequest.start", values: ["protected": protected])
        f.controller.beginLongText(.notes, source: f.controller.buffer)
        try await SystemPageHost.settle(window)
        let editor = try #require(f.controller.longTextEditing?.editor)
        try await SettingsButtonTestSupport.reveal(editor, in: window)
        try #require(window.makeFirstResponder(editor))
        try journal.record("openRequest", values: ["totalMS": CommandTextPrototypeChecks.milliseconds(start)])
        return Self(window: window, editor: editor, service: try #require(f.controller.longTextContent),
                    vault: synthetic.vault, close: { f.stop() })
    }

    static func show(_ window: NSWindow) async throws {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
    }
}
#endif
