import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ClipboardOptionsConsumerTests {
    typealias Native = SettingsButtonTestSupport
    static let environments: [(String, ColorScheme)] = [
        ("en", .light), ("en", .dark), ("zh-Hans", .light), ("zh-Hans", .dark)
    ]

    @Test(arguments: environments)
    func productionNamesValuesAndLayout(environment: (String, ColorScheme)) async throws {
        let fixture = try ClipboardOptionsFixture()
        defer { fixture.cleanup() }
        let session = fixture.session()
        let window = fixture.native.window(ClipboardHistoryOptions(session: session),
            locale: environment.0, scheme: environment.1, size: NSSize(width: 440, height: 560))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let nodes = try ClipboardOptionsFixture.keys.map { try fixture.toggle($0, locale: environment.0, in: window) }
        try Native.assertBounds(nodes, in: window)
        for node in nodes {
            #expect((Native.value(node, "accessibilityValue") as? NSNumber)?.boolValue == false)
        }
        try fixture.snapshot(window, name: "\(environment.0)-\(environment.1)")
        #expect(fixture.persisted.count == 0)
        #expect(session.items.isEmpty)
    }

    @Test(arguments: environments)
    func immediatePreferencesSurviveCancelReopenAndRebuild(environment: (String, ColorScheme)) async throws {
        let fixture = try ClipboardOptionsFixture()
        defer { fixture.cleanup() }
        fixture.seedPreferences()
        let session = fixture.session()
        for pass in 0..<3 {
            // 第三次连 UserDefaults 对象都重建，避免只验证原会话缓存。
            let current = pass == 2 ? try fixture.rebuiltSession() : session
            var dismissed = false
            let content = PrivacyButtonSheetHost(content: AnyView(ClipboardHistoryOptions(session: current)),
                                                 onDismiss: { dismissed = true })
            let host = fixture.native.window(content, locale: environment.0, scheme: environment.1,
                                             size: NSSize(width: 520, height: 650))
            defer { SystemPageHost.release(host) }
            try await waitUntil { host.attachedSheet != nil }
            let sheet = try #require(host.attachedSheet)
            try await NativeSyntaxUI.prepareFocus(in: sheet)
            try await SystemPageHost.settle(sheet)
            #expect(sheet.contentView?.bounds.size == NSSize(width: 440, height: 560))
            try fixture.assertValues(current, locale: environment.0, in: sheet)
            if pass == 0 {
                try await exerciseBindings(current, fixture: fixture, locale: environment.0, in: sheet)
            }
            let saved = fixture.persisted
            try fixture.snapshot(sheet, name: "sheet-\(environment.0)-\(environment.1)-\(pass)")
            try await Native.click(Native.button("alert.cancel", locale: environment.0, in: sheet), in: sheet)
            try await waitUntil { host.attachedSheet == nil && dismissed }
            #expect(fixture.persisted == saved)
            fixture.assertStoredModel(current)
            fixture.assertStoredModel(try fixture.rebuiltSession())
        }
    }

    private func exerciseBindings(_ session: ClipboardHistorySession, fixture: ClipboardOptionsFixture,
                                  locale: String, in window: NSWindow) async throws {
        for key in ClipboardOptionsFixture.keys {
            for _ in 0..<3 {
                let expected = try #require(fixture.persisted.mutableCopy() as? NSMutableDictionary)
                let storedKey = "areachain.clipboard.\(key)"
                let old = try #require(expected[storedKey] as? Bool)
                expected[storedKey] = !old
                try await Native.click(fixture.toggle(key, locale: locale, in: window), in: window)
                #expect(fixture.persisted == expected, "每次仅允许对应偏好变化")
                fixture.assertStoredModel(session)
                fixture.assertStoredModel(try fixture.rebuiltSession())
                try fixture.assertValues(session, locale: locale, in: window)
            }
        }
        // 更新来自原会话 setter；宿主不添加 onChange 或镜像状态来强制刷新。
        session.setIgnoreUniversal(false)
        session.setPlainByDefault(false)
        session.setPlaySound(false)
        try await SystemPageHost.settle(window)
        try fixture.assertValues(session, locale: locale, in: window)
        session.setIgnoreUniversal(true)
        try await SystemPageHost.settle(window)
        try fixture.assertValues(session, locale: locale, in: window)
        fixture.assertStoredModel(session)
        #expect(session.items.isEmpty && !session.ignoreNext && session.noticeKey == nil)
    }

    @Test(arguments: environments)
    func disabledOptionsDoNotWrite(environment: (String, ColorScheme)) async throws {
        let fixture = try ClipboardOptionsFixture()
        defer { fixture.cleanup() }
        fixture.seedPreferences()
        let session = fixture.session()
        session.setIgnoreUniversal(true)
        session.setPlaySound(true)
        let saved = fixture.persisted
        let window = fixture.native.window(ClipboardHistoryOptions(session: session).disabled(true),
            locale: environment.0, scheme: environment.1, size: NSSize(width: 440, height: 560))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        for key in ClipboardOptionsFixture.keys {
            let node = try fixture.toggle(key, locale: environment.0, in: window)
            #expect((node.value(forKey: "accessibilityEnabled") as? NSNumber)?.boolValue == false)
            try await Native.click(node, in: window)
            let press = NSSelectorFromString("accessibilityPerformPress")
            try #require(node.responds(to: press))
            _ = node.perform(press)
            try await SystemPageHost.settle(window)
            #expect(fixture.persisted == saved)
            fixture.assertStoredModel(session)
            try fixture.assertValues(session, locale: environment.0, in: window)
        }
        try fixture.snapshot(window, name: "disabled-\(environment.0)-\(environment.1)")
    }

    @Test(arguments: environments)
    func unsubmittedInputsAndScrolledBoundariesRemain(environment: (String, ColorScheme)) async throws {
        let fixture = try ClipboardOptionsFixture()
        defer { fixture.cleanup() }
        fixture.seedPreferences(longLists: true)
        let session = fixture.session()
        let window = fixture.native.window(ClipboardHistoryOptions(session: session),
            locale: environment.0, scheme: environment.1, size: NSSize(width: 440, height: 560))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let pattern = try fixture.field("clipboard.patterns.add", locale: environment.0, in: window)
        let type = try fixture.field("clipboard.types.add", locale: environment.0, in: window)
        try await enter("^unsubmitted-example$", into: pattern, in: window)
        try await enter("com.example.unsubmitted", into: type, in: window)
        let original = fixture.persisted
        for key in ClipboardOptionsFixture.keys {
            let node = try fixture.toggle(key, locale: environment.0, in: window)
            try await Native.reveal(node, in: window)
            try fixture.assertVisible(node, in: window)
            try await Native.click(node, in: window)
            #expect(pattern.stringValue == "^unsubmitted-example$")
            #expect(type.stringValue == "com.example.unsubmitted")
            let expected = try #require(original.mutableCopy() as? NSMutableDictionary)
            for changed in ClipboardOptionsFixture.keys.prefix(through: try #require(ClipboardOptionsFixture.keys.firstIndex(of: key))) {
                expected["areachain.clipboard.\(changed)"] = true
            }
            #expect(fixture.persisted == expected)
            fixture.assertStoredModel(session)
        }
        try await Native.reveal(type, in: window)
        try fixture.assertVisible(type, in: window)
        try fixture.snapshot(window, name: "drafts-scrolled-\(environment.0)-\(environment.1)")
        #expect(!session.patterns.contains(pattern.stringValue) && !session.extraTypes.contains(type.stringValue))
    }

    private func enter(_ text: String, into field: NSTextField, in window: NSWindow) async throws {
        try await Native.reveal(field, in: window)
        #expect(window.makeFirstResponder(field))
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.insertText(text, replacementRange: editor.selectedRange())
        try await SystemPageHost.settle(window)
        #expect(field.stringValue == text)
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !condition(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(40)) }
        try #require(condition())
    }
}

/// 每次只拥有新建的空历史目录和独立偏好；初始化可以读它，但不启动监控或写剪贴板。
@MainActor
final class ClipboardOptionsFixture {
    static let keys = ["ignoreUniversal", "plainByDefault", "playSound"]
    let native: SettingsButtonTestSupport
    let suite = "areachain.clipboard.options.\(UUID())"
    let runID = UUID().uuidString
    let defaults: UserDefaults
    let root: URL

    init() throws {
        native = try SettingsButtonTestSupport()
        defaults = try #require(UserDefaults(suiteName: suite))
        root = FileManager.default.temporaryDirectory.appending(path: "clipboard-options-\(runID)", directoryHint: .isDirectory)
        try #require(!FileManager.default.fileExists(atPath: root.path))
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    }

    func session() -> ClipboardHistorySession {
        ClipboardHistorySession(store: ClipboardHistoryStore(root: root), defaults: defaults, pasteboard: nil,
            gate: ClipboardHistoryPasteGate(isTrusted: { false }, prompt: {}, sendCommandV: {}))
    }

    func rebuiltSession() throws -> ClipboardHistorySession {
        let restoredDefaults = try #require(UserDefaults(suiteName: suite))
        return ClipboardHistorySession(store: ClipboardHistoryStore(root: root), defaults: restoredDefaults, pasteboard: nil,
            gate: ClipboardHistoryPasteGate(isTrusted: { false }, prompt: {}, sendCommandV: {}))
    }

    func seedPreferences(longLists: Bool = false) {
        let values: [String: Any] = [
            "recording": false, "limit": 70, "interval": 0.8, "searchMode": "regex",
            "ignoreUniversal": false, "panelAnchor": "center", "panelStaysOnTop": false,
            "clickAction": "paste", "plainByDefault": false, "playSound": false,
            "ignoredApps": longLists ? (0..<8).map { "com.example.synthetic-long-application-name-\($0)" } : ["com.example.test"],
            "extraTypes": ["com.example.synthetic-type"], "patterns": ["^synthetic$"]
        ]
        for (key, value) in values { defaults.set(value, forKey: "areachain.clipboard.\(key)") }
        defaults.set("unchanged", forKey: "qa.unrelated")
    }

    func assertStoredModel(_ session: ClipboardHistorySession) {
        let values: [String: Any] = [
            "recording": session.recording, "limit": session.limit, "interval": session.interval,
            "searchMode": session.searchMode.rawValue, "ignoreUniversal": session.ignoreUniversal,
            "panelAnchor": session.panelAnchor.rawValue, "panelStaysOnTop": session.panelStaysOnTop,
            "clickAction": session.clickAction.rawValue, "plainByDefault": session.plainByDefault,
            "playSound": session.playSound, "ignoredApps": session.ignoredApps,
            "extraTypes": session.extraTypes, "patterns": session.patterns
        ]
        for (key, value) in values {
            let actual = defaults.object(forKey: "areachain.clipboard.\(key)")
            #expect((actual as? NSObject) == (value as? NSObject), "持久化值与会话不一致：\(key)")
        }
        #expect(defaults.string(forKey: "qa.unrelated") == "unchanged")
    }

    func assertValues(_ session: ClipboardHistorySession, locale: String, in window: NSWindow) throws {
        for (key, expected) in zip(Self.keys, [session.ignoreUniversal, session.plainByDefault, session.playSound]) {
            let node = try toggle(key, locale: locale, in: window)
            #expect((SettingsButtonTestSupport.value(node, "accessibilityValue") as? NSNumber)?.boolValue == expected)
        }
    }

    func field(_ key: String, locale: String, in window: NSWindow) throws -> NSTextField {
        let placeholder = L10n.string(String.LocalizationValue(key), locale: Locale(identifier: locale))
        return try #require(nativeNodes(window).compactMap { $0 as? NSTextField }.first {
            $0.isEditable && $0.placeholderString == placeholder
        })
    }

    func assertVisible(_ node: NSObject, in window: NSWindow) throws {
        try SettingsButtonTestSupport.assertBounds([node], in: window)
        let scroll = try #require(nativeNodes(window).compactMap { $0 as? NSScrollView }.first)
        let visible = scroll.contentView.convert(scroll.contentView.bounds, to: nil)
        // SwiftUI 按 AppKit alignment rect 排版，原生文本字段的外框另含对齐边缘。
        let frame: CGRect
        if let view = node as? NSView {
            let parent = try #require(view.superview)
            frame = parent.convert(view.alignmentRect(forFrame: view.frame), to: nil)
        } else {
            frame = try SettingsButtonTestSupport.frame(node, in: window)
        }
        #expect(visible.contains(frame), "滚动后控件必须完整留在内容区")
    }

    var persisted: NSDictionary { (defaults.persistentDomain(forName: suite) ?? [:]) as NSDictionary }

    func cleanup() {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: root)
        native.cleanup()
    }

    func toggle(_ key: String, locale: String = "en", in window: NSWindow) throws -> NSObject {
        let localizationKey = "clipboard.\(key)"
        let title = L10n.string(String.LocalizationValue(localizationKey), locale: Locale(identifier: locale))
        return try #require(nativeNodes(window).first {
            SettingsButtonTestSupport.value($0, "accessibilityRole") as? String == "AXCheckBox"
                && (SettingsButtonTestSupport.value($0, "accessibilityLabel") as? String == title
                    || SettingsButtonTestSupport.value($0, "accessibilityTitle") as? String == title)
        }, "必须找到指定语言的生产 Toggle：\(key), \(locale)")
    }

    private func nativeNodes(_ window: NSWindow) -> [NSObject] {
        SettingsButtonTestSupport.elements(window.contentView)
    }

    func snapshot(_ window: NSWindow, name: String) throws {
        let name = "clipboard-options-\(runID)-\(name)"
        try SettingsButtonTestSupport.snapshot(window, name: name)
    }
}
