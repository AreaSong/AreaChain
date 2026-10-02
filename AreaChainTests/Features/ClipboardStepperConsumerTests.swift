import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ClipboardStepperConsumerTests {
    typealias Native = SettingsButtonTestSupport

    @Test func defaultPresentationDoesNotWritePreferences() async throws {
        let fixture = try ClipboardOptionsFixture()
        defer { fixture.cleanup() }
        let session = fixture.session()
        let window = fixture.native.window(ClipboardHistoryOptions(session: session), size: NSSize(width: 440, height: 560))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        #expect(session.limit == 200 && session.interval == 0.5)
        #expect(fixture.persisted.count == 0 && session.items.isEmpty)
        try StepperTestSupport.assertValue("200", id: "clipboard.limit", in: window)
        try StepperTestSupport.assertValue("0.5", id: "clipboard.interval", in: window)
    }

    @Test(arguments: ["en", "zh-Hans"], [false, true])
    func immediateSaveCancelReopenAndRebuild(locale: String, dark: Bool) async throws {
        let fixture = try ClipboardOptionsFixture()
        defer { fixture.cleanup() }
        fixture.seedPreferences()
        fixture.defaults.set(25, forKey: "areachain.clipboard.limit")
        fixture.defaults.set(0.35, forKey: "areachain.clipboard.interval")
        let history = try seedHistory(fixture)
        let original = fixture.persisted
        let session = fixture.session()
        for pass in 0..<3 {
            let current = pass == 2 ? try fixture.rebuiltSession() : session
            var dismissed = false
            let host = fixture.native.window(PrivacyButtonSheetHost(
                content: AnyView(ClipboardHistoryOptions(session: current)), onDismiss: { dismissed = true }),
                locale: locale, scheme: dark ? .dark : .light, size: NSSize(width: 520, height: 650))
            defer { SystemPageHost.release(host) }
            try await waitUntil { host.attachedSheet != nil }
            let sheet = try #require(host.attachedSheet)
            try await NativeSyntaxUI.prepareFocus(in: sheet)
            try await SystemPageHost.settle(sheet)
            #expect(sheet.contentView?.bounds.size == NSSize(width: 440, height: 560))
            if pass == 0 {
                #expect(fixture.persisted == original && current.limit == 25 && current.interval == 0.35)
                try await StepperTestSupport.click("clipboard.limit", increase: false, in: sheet)
                #expect(current.limit == 20)
                assertTrimmed(current.items, original: history)
                try await StepperTestSupport.click("clipboard.interval", increase: true, in: sheet)
                #expect(current.interval == 0.44999999999999996)
                let expected = try #require(original.mutableCopy() as? NSMutableDictionary)
                expected["areachain.clipboard.limit"] = 20
                expected["areachain.clipboard.interval"] = current.interval
                #expect(fixture.persisted == expected)
            }
            #expect(current.limit == 20 && current.interval == 0.44999999999999996)
            fixture.assertStoredModel(current)
            assertTrimmed(current.items, original: history)
            let nodes = try ["clipboard.limit", "clipboard.interval"].map { try StepperTestSupport.node($0, in: sheet) }
            try Native.assertBounds(nodes, in: sheet)
            #expect(MenuButtonTestSupport.title(nodes[0]) == L10n.format("clipboard.limit %lld", locale: Locale(identifier: locale), 20))
            #expect(MenuButtonTestSupport.title(nodes[1]) == L10n.format("clipboard.interval", locale: Locale(identifier: locale), current.interval))
            try fixture.snapshot(sheet, name: "stepper-\(locale)-\(dark)-\(pass)")
            let saved = fixture.persisted
            try await Native.click(Native.button("alert.cancel", locale: locale, in: sheet), in: sheet)
            try await waitUntil { host.attachedSheet == nil && dismissed }
            #expect(fixture.persisted == saved)
            assertTrimmed(try fixture.rebuiltSession().items, original: history)
        }
        let names = try FileManager.default.contentsOfDirectory(atPath: fixture.root.path).filter { $0.hasSuffix(".png") }
        #expect(Set(names) == Set(session.items.compactMap(\.imageFile)))
    }

    @Test func failedHistorySaveStillPersistsLimitWithoutPruningOrRollback() async throws {
        let fixture = try ClipboardOptionsFixture()
        defer { fixture.cleanup() }
        fixture.seedPreferences()
        fixture.defaults.set(25, forKey: "areachain.clipboard.limit")
        let original = try seedHistory(fixture)
        let session = fixture.session()
        let saved = fixture.persisted
        let imageNames = try FileManager.default.contentsOfDirectory(atPath: fixture.root.path).filter { $0.hasSuffix(".png") }
        // 只在本例拥有的目录阻断临时文件写入；不改服务接口、权限或真实历史。
        let blocker = fixture.root.appending(path: "history.json.tmp")
        try FileManager.default.createDirectory(at: blocker, withIntermediateDirectories: false)
        try Data([1]).write(to: blocker.appending(path: "owned-blocker"))
        let window = fixture.native.window(ClipboardHistoryOptions(session: session), size: NSSize(width: 440, height: 560))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try await StepperTestSupport.click("clipboard.limit", increase: false, in: window)
        #expect(session.limit == 20 && session.noticeKey == "clipboard.save.failed")
        #expect(session.items == original)
        let rebuilt = try fixture.rebuiltSession()
        #expect(rebuilt.limit == 20 && rebuilt.items == original)
        let expected = try #require(saved.mutableCopy() as? NSMutableDictionary)
        expected["areachain.clipboard.limit"] = 20
        #expect(fixture.persisted == expected)
        #expect(Set(try FileManager.default.contentsOfDirectory(atPath: fixture.root.path).filter { $0.hasSuffix(".png") }) == Set(imageNames))
        try StepperTestSupport.assertValue("20", id: "clipboard.limit", in: window)
    }

    @Test(arguments: ["en", "zh-Hans"], [false, true])
    func draftsExternalUpdatesDisabledAndScroll(locale: String, dark: Bool) async throws {
        let fixture = try ClipboardOptionsFixture()
        defer { fixture.cleanup() }
        fixture.seedPreferences(longLists: true)
        let session = fixture.session()
        let window = fixture.native.window(ClipboardHistoryOptions(session: session), locale: locale,
                                          scheme: dark ? .dark : .light, size: NSSize(width: 440, height: 560))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let pattern = try fixture.field("clipboard.patterns.add", locale: locale, in: window)
        let type = try fixture.field("clipboard.types.add", locale: locale, in: window)
        for (field, text) in [(pattern, "^unsubmitted$"), (type, "com.example.unsubmitted")] {
            try await Native.reveal(field, in: window)
            #expect(window.makeFirstResponder(field))
            let editor = try #require(field.currentEditor() as? NSTextView)
            editor.insertText(text, replacementRange: editor.selectedRange())
            try await SystemPageHost.settle(window)
        }
        let saved = fixture.persisted
        for id in ["clipboard.limit", "clipboard.interval"] {
            let node = try StepperTestSupport.node(id, in: window)
            try await Native.reveal(node, in: window)
            try fixture.assertVisible(node, in: window)
            try await StepperTestSupport.click(id, increase: true, in: window)
            #expect(pattern.stringValue == "^unsubmitted$" && type.stringValue == "com.example.unsubmitted")
        }
        let expected = try #require(saved.mutableCopy() as? NSMutableDictionary)
        expected["areachain.clipboard.limit"] = 80
        expected["areachain.clipboard.interval"] = 0.9
        #expect(fixture.persisted == expected)
        session.setLimit(995)
        session.setInterval(1.95)
        try await SystemPageHost.settle(window)
        try StepperTestSupport.assertValue("995", id: "clipboard.limit", in: window)
        try StepperTestSupport.assertValue("1.95", id: "clipboard.interval", in: window)
        try await Native.reveal(type, in: window)
        try fixture.assertVisible(type, in: window)
        try fixture.snapshot(window, name: "stepper-drafts-\(locale)-\(dark)")
        #expect(!session.patterns.contains(pattern.stringValue) && !session.extraTypes.contains(type.stringValue))
        fixture.assertStoredModel(try fixture.rebuiltSession())
        let disabled = fixture.native.window(ClipboardHistoryOptions(session: session).disabled(true), locale: locale,
                                            scheme: dark ? .dark : .light, size: NSSize(width: 440, height: 560))
        defer { SystemPageHost.release(disabled) }
        try await NativeSyntaxUI.prepareFocus(in: disabled)
        try await SystemPageHost.settle(disabled)
        let before = fixture.persisted
        for id in ["clipboard.limit", "clipboard.interval"] {
            try await StepperTestSupport.click(id, increase: false, in: disabled)
            try StepperTestSupport.adjust(id, increase: false, in: disabled)
        }
        #expect(fixture.persisted == before)
    }

    private func seedHistory(_ fixture: ClipboardOptionsFixture) throws -> [ClipboardHistoryRecord] {
        let store = ClipboardHistoryStore(root: fixture.root)
        let records = try (0..<32).map { index in
            let id = UUID()
            let image = try store.writeImage(Data([0, 1, 2, UInt8(index)]), id: id)
            return ClipboardHistoryRecord(id: id, copiedAt: Date(timeIntervalSince1970: Double(index)),
                pinnedAt: index < 2 ? Date(timeIntervalSince1970: Double(index)) : nil,
                pinKey: index < 2 ? String(index) : nil, sourceBundleID: "com.example.synthetic",
                plainText: "Synthetic \(index)", html: nil, rtf: nil, imageFile: image, contentHash: "synthetic-\(index)")
        }
        try store.save(records)
        return records
    }

    private func assertTrimmed(_ items: [ClipboardHistoryRecord], original: [ClipboardHistoryRecord]) {
        #expect(items.filter { !$0.isPinned }.count == 20)
        #expect(items.filter(\.isPinned) == Array(original.prefix(2)))
        #expect(items.map(\.id) == (Array(original.prefix(2)) + Array(original.suffix(20).reversed())).map(\.id))
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !condition(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(40)) }
        try #require(condition())
    }
}
