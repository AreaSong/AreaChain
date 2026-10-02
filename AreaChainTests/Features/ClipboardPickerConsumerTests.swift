import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ClipboardPickerConsumerTests {
    typealias Native = SettingsButtonTestSupport
    typealias Menus = MenuButtonTestSupport

    @Test(arguments: ClipboardOptionsConsumerTests.environments)
    func initialValuesNativeMenusAndCurrentSelection(environment: (String, ColorScheme)) async throws {
        let fixture = try ClipboardOptionsFixture()
        defer { fixture.cleanup() }
        let session = fixture.session()
        let window = fixture.native.window(ClipboardHistoryOptions(session: session),
            locale: environment.0, scheme: environment.1, size: NSSize(width: 440, height: 560))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let nodes = Menus.menus(in: window)
        #expect(nodes.count == 3)
        try Native.assertBounds(nodes, in: window)
        #expect(fixture.persisted.count == 0)
        for (index, node) in nodes.enumerated() {
            let key = ["searchMode", "panelAnchor", "clickAction"][index]
            let raw = ["mixed", "cursor", "copy"][index]
            #expect(Menus.title(node) == Menus.localized("clipboard.\(key)", environment.0))
            #expect(Native.value(node, "accessibilityValue") as? String == Menus.localized("clipboard.\(key).\(raw)", environment.0))

            let before = fixture.persisted
            let menu = try await Menus.openAndEscape(node, in: window)
            #expect(fixture.persisted == before)
            #expect(menu.items.filter { $0.state == .on }.count == 1)
            if let current = menu.items.first(where: { $0.state == .on && $0.action != nil }) {
                fixture.defaults.removePersistentDomain(forName: fixture.suite)
                try Menus.dispatch(current.title, in: menu)
                try await SystemPageHost.settle(window)
                #expect(fixture.persisted.count == 13, "再选当前项应调用原 setter 保存偏好")
            }
        }
        try fixture.snapshot(window, name: "picker-production-\(environment.0)-\(environment.1)")
    }

    @Test func keyboardSelectionPreservesNeighbor() async throws {
        let fixture = try ClipboardOptionsFixture()
        defer { fixture.cleanup() }
        let session = fixture.session()
        let window = fixture.native.window(ClipboardHistoryOptions(session: session), size: NSSize(width: 440, height: 560))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let field = try fixture.field("clipboard.patterns.add", locale: "en", in: window)
        #expect(window.makeFirstResponder(field))
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.insertText("unsubmitted", replacementRange: editor.selectedRange())
        let node = try #require(Menus.menus(in: window).first)
        try await PickerNativeTestSupport.keyboardSelection(node, moveDown: false, in: window)
        #expect(fixture.persisted.count == 13 && field.currentEditor() === window.firstResponder)
        try await PickerNativeTestSupport.keyboardSelection(node, moveDown: true, in: window)
        #expect(field.currentEditor() === window.firstResponder)
        #expect(session.searchMode == .exact)
        #expect(field.stringValue == "unsubmitted" && session.patterns.isEmpty)
    }

    @Test(arguments: ClipboardOptionsConsumerTests.environments)
    func everyOptionPersistsWithoutChangingDraftsOrHistory(environment: (String, ColorScheme)) async throws {
        let fixture = try ClipboardOptionsFixture()
        defer { fixture.cleanup() }
        fixture.seedPreferences(longLists: true)
        let record = ClipboardHistoryRecord(id: UUID(), copiedAt: Date(timeIntervalSince1970: 10),
            pinnedAt: nil, pinKey: nil, sourceBundleID: "com.example.synthetic", plainText: "Synthetic picker fixture",
            html: nil, rtf: nil, imageFile: nil, contentHash: "picker-fixture")
        try ClipboardHistoryStore(root: fixture.root).save([record])
        let historyURL = fixture.root.appending(path: "history.json")
        let historyBytes = try Data(contentsOf: historyURL)
        let session = fixture.session()
        let window = fixture.native.window(ClipboardHistoryOptions(session: session), locale: environment.0,
            scheme: environment.1, size: NSSize(width: 440, height: 560))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let pattern = try fixture.field("clipboard.patterns.add", locale: environment.0, in: window)
        let type = try fixture.field("clipboard.types.add", locale: environment.0, in: window)
        for (field, draft) in [(pattern, "^unsubmitted$"), (type, "com.example.unsubmitted")] {
            try await Native.reveal(field, in: window)
            #expect(window.makeFirstResponder(field))
            let editor = try #require(field.currentEditor() as? NSTextView)
            editor.insertText(draft, replacementRange: editor.selectedRange())
        }
        let groups = [("searchMode", ["mixed", "exact", "regex"]),
                      ("panelAnchor", ["cursor", "center"]), ("clickAction", ["copy", "paste"])]
        for (key, options) in groups {
            let node = try Menus.menu("clipboard.\(key)", locale: environment.0, in: window)
            try await Native.reveal(node, in: window)
            for raw in options {
                let expected = try #require(fixture.persisted.mutableCopy() as? NSMutableDictionary)
                expected["areachain.clipboard.\(key)"] = raw
                let menu = try await Menus.openAndEscape(node, in: window)
                #expect(menu.items.map(\.title) == options.map { Menus.localized("clipboard.\(key).\($0)", environment.0) })
                try Menus.dispatch(Menus.localized("clipboard.\(key).\(raw)", environment.0), in: menu)
                try await SystemPageHost.settle(window)
                #expect(fixture.persisted == expected)
                fixture.assertStoredModel(session)
                fixture.assertStoredModel(try fixture.rebuiltSession())
                #expect(pattern.stringValue == "^unsubmitted$" && type.stringValue == "com.example.unsubmitted")
                #expect(session.items == [record] && !session.recording && !session.ignoreNext)
                #expect(try Data(contentsOf: historyURL) == historyBytes)
                #expect(Native.value(node, "accessibilityValue") as? String == Menus.localized("clipboard.\(key).\(raw)", environment.0))
            }
        }
        session.setSearchMode(.mixed)
        session.setPanelAnchor(.cursor)
        session.setClickAction(.copy)
        try await SystemPageHost.settle(window)
        for (key, options) in groups {
            let node = try Menus.menu("clipboard.\(key)", locale: environment.0, in: window)
            #expect(Native.value(node, "accessibilityValue") as? String == Menus.localized("clipboard.\(key).\(options[0])", environment.0))
        }
        try await Native.reveal(type, in: window)
        try fixture.assertVisible(type, in: window)
        try fixture.snapshot(window, name: "picker-scrolled-\(environment.0)-\(environment.1)")
    }

    @Test(arguments: ClipboardOptionsConsumerTests.environments)
    func cancelReopenRebuildAndDisabled(environment: (String, ColorScheme)) async throws {
        let fixture = try ClipboardOptionsFixture()
        defer { fixture.cleanup() }
        fixture.seedPreferences()
        let session = fixture.session()
        for pass in 0..<3 {
            let current = pass == 2 ? try fixture.rebuiltSession() : session
            var dismissed = false
            let host = fixture.native.window(PrivacyButtonSheetHost(content: AnyView(ClipboardHistoryOptions(session: current)),
                onDismiss: { dismissed = true }), locale: environment.0, scheme: environment.1,
                size: NSSize(width: 520, height: 650))
            defer { SystemPageHost.release(host) }
            try await waitUntil { host.attachedSheet != nil }
            let sheet = try #require(host.attachedSheet)
            try await NativeSyntaxUI.prepareFocus(in: sheet)
            try await SystemPageHost.settle(sheet)
            for key in ["searchMode", "panelAnchor", "clickAction"] {
                let node = try Menus.menu("clipboard.\(key)", locale: environment.0, in: sheet)
                let menu = try await Menus.openAndEscape(node, in: sheet)
                if pass == 0 { menu.performActionForItem(at: 0) }
                else { #expect(menu.items.first?.state == .on) }
            }
            try await SystemPageHost.settle(sheet)
            let saved = fixture.persisted
            try await Native.click(Native.button("alert.cancel", locale: environment.0, in: sheet), in: sheet)
            try await waitUntil { host.attachedSheet == nil && dismissed }
            #expect(fixture.persisted == saved)
            fixture.assertStoredModel(current)
        }
        let saved = fixture.persisted
        let window = fixture.native.window(ClipboardHistoryOptions(session: session).disabled(true),
            locale: environment.0, scheme: environment.1, size: NSSize(width: 440, height: 560))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        for node in Menus.menus(in: window) {
            #expect((node.value(forKey: "accessibilityEnabled") as? NSNumber)?.boolValue == false)
            try await Native.click(node, in: window)
        }
        #expect(fixture.persisted == saved)
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !condition(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(40)) }
        try #require(condition())
    }

}
