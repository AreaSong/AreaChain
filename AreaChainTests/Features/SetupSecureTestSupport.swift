import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 四字段用安全辅助节点的稳定身份定位，原生字段只做编辑和布尔比对，不读取明文 AX value。
@MainActor
enum SetupSecureTestSupport {
    typealias Native = SettingsButtonTestSupport

    enum Field: String, CaseIterable {
        case master = "privacy.setup.master"
        case masterConfirmation = "privacy.setup.master.confirmation"
        case backup = "privacy.setup.backup"
        case backupConfirmation = "privacy.setup.backup.confirmation"

        var title: String {
            switch self {
            case .master: "privacy.master.label"
            case .backup: "privacy.backup.password.title"
            case .masterConfirmation, .backupConfirmation: "privacy.password.repeat"
            }
        }
    }

    static func node(_ identity: Field, in window: NSWindow) throws -> NSObject {
        let matches = Native.elements(window.contentView).filter {
            Native.value($0, "accessibilityIdentifier") as? String == identity.rawValue
                && Native.value($0, "accessibilitySubrole") as? String == "AXSecureTextField"
        }
        try #require(matches.count == 1, "安全字段身份必须唯一")
        return try #require(matches.first)
    }

    static func field(_ identity: Field, in window: NSWindow) throws -> NSSecureTextField {
        let rect = try Native.frame(node(identity, in: window), in: window)
        let matches = SecureInputTestSupport.fields(window).filter {
            let frame = $0.convert($0.bounds, to: nil)
            return rect.contains(NSPoint(x: frame.midX, y: frame.midY))
        }
        try #require(matches.count == 1, "稳定身份应只对应一个原生安全字段")
        return try #require(matches.first)
    }

    static func enter(_ text: String, field identity: Field, in window: NSWindow) async throws {
        let native = try field(identity, in: window)
        let editor = try await FormInputTestSupport.editor(native, in: window)
        editor.insertText(text, replacementRange: NSRange(location: 0, length: (editor.string as NSString).length))
        try await SystemPageHost.settle(window)
        let matches = native.stringValue.utf8.elementsEqual(text.utf8)
        #expect(matches)
    }

    static func expectValues(_ expected: [Field: String], in window: NSWindow) throws {
        for identity in Field.allCases where expected[identity] != nil {
            let matches = try field(identity, in: window).stringValue.utf8.elementsEqual(expected[identity]!.utf8)
            #expect(matches, "字段草稿不符：\(identity.rawValue)")
        }
    }

    static func toggle(_ key: String, locale: String = "en", in window: NSWindow) async throws {
        let title = L10n.string(String.LocalizationValue(key), locale: Locale(identifier: locale))
        let node = try #require(Native.elements(window.contentView).first {
            Native.value($0, "accessibilityRole") as? String == "AXCheckBox"
                && Native.value($0, "accessibilityLabel") as? String == title
        })
        try await Native.reveal(node, in: window)
        try await Native.click(node, in: window)
    }

    static func hasText(_ key: String, locale: String = "en", in window: NSWindow) -> Bool {
        PrivacyUnlockSecureTestSupport.hasText(key, locale: locale, in: window)
    }

    static func focus(in window: NSWindow) -> String {
        for identity in visible(in: window) {
            if let field = try? field(identity, in: window), field.currentEditor() === window.firstResponder {
                return identity.rawValue
            }
        }
        return "outside-secure-fields"
    }

    static func visible(in window: NSWindow) -> [Field] {
        let identifiers = Set(Native.elements(window.contentView).compactMap {
            Native.value($0, "accessibilityIdentifier") as? String
        })
        return Field.allCases.filter { identifiers.contains($0.rawValue) }
    }

    static func recordLayout(_ window: NSWindow, name: String) async throws {
        let bounds = try #require(window.contentView).bounds
        #expect(bounds.width == 480)
        let scroll = try #require(Native.elements(window.contentView).compactMap { $0 as? NSScrollView }.first)
        #expect(scroll.bounds.height <= 430)
        for identity in visible(in: window) {
            let input = try field(identity, in: window)
            try await Native.reveal(input, in: window)
            try Native.assertBounds([input], in: window)
            #expect((input.cell as? NSSecureTextFieldCell)?.echosBullets == true)
            print("Setup layout \(name) field=\(identity.rawValue) size=\(input.bounds.size)")
        }
        print("Setup layout \(name) content=\(bounds.size) scroll=\(scroll.bounds.size)")
        try Native.snapshot(window, name: "setup7D-\(name)")
    }
}
