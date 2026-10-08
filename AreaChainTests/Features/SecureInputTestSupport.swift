import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 仅用于合成安全输入；断言只暴露布尔/长度，禁止收集输入或读取明文 AX value。
@MainActor
enum SecureInputTestSupport {
    typealias Native = SettingsButtonTestSupport
    static var sample: String { "  e\u{301} 中🧪 #!@\\()  " }
    static var alternateSample: String { sample + "x" }

    enum Replacement: String, Sendable {
        case whole = "A", inPlace = "B", growing = "C"
    }

    struct ReplacementResult {
        var calls = 0
        var differentIntermediates = 0
    }

    /// 只枚举完整扩展字素；NSRange 用原字符串转换，避免拆开组合标记或代理对。
    static func characterRanges(_ text: String) -> [NSRange] {
        text.indices.map { NSRange($0..<text.index(after: $0), in: text) }
    }

    /// 三组共用公开输入入口；整段操作中没有 await、清空或原生 stringValue 赋值。
    @discardableResult
    static func replaceSample(_ mode: Replacement, in editor: NSTextView) -> ReplacementResult {
        let text = sample
        if mode == .whole {
            editor.insertText(text, replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
            return ReplacementResult(calls: 1,
                differentIntermediates: editor.string.utf8.elementsEqual(text.utf8) ? 0 : 1)
        }
        let ranges = characterRanges(text)
        var result = ReplacementResult()
        for (index, range) in ranges.enumerated() {
            let character = (text as NSString).substring(with: range)
            let target: NSRange
            if mode == .inPlace { target = range }
            else { target = NSRange(location: index == 0 ? 0 : editor.string.utf16.count,
                                    length: index == 0 ? editor.string.utf16.count : 0) }
            editor.insertText(character, replacementRange: target)
            result.calls += 1
            if !editor.string.utf8.elementsEqual(text.utf8) { result.differentIntermediates += 1 }
        }
        return result
    }

    static func fields(_ window: NSWindow) -> [NSSecureTextField] {
        Native.elements(window.contentView).compactMap { $0 as? NSSecureTextField }.sorted {
            $0.convert($0.bounds, to: nil).midY > $1.convert($1.bounds, to: nil).midY
        }
    }

    static func ready(_ window: NSWindow) async throws {
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
    }

    static func enter(_ text: String, index: Int = 0, in window: NSWindow) async throws {
        let field = try #require(fields(window).dropFirst(index).first)
        let editor = try await FormInputTestSupport.editor(field, in: window)
        editor.insertText(text, replacementRange: NSRange(location: 0, length: (editor.string as NSString).length))
        try await SystemPageHost.settle(window)
        let matches = field.stringValue.utf8.elementsEqual(text.utf8)
        #expect(matches)
    }

    static func fill(_ window: NSWindow) async throws {
        for index in fields(window).indices { try await enter(sample, index: index, in: window) }
    }

    static func click(_ key: String, locale: String = "en", in window: NSWindow) async throws {
        try await Native.click(Native.button(key, locale: locale, in: window), in: window)
    }

    static func enabled(_ key: String, _ expected: Bool, locale: String = "en", in window: NSWindow) throws {
        let button = try Native.button(key, locale: locale, in: window)
        #expect((button.value(forKey: "accessibilityEnabled") as? Bool) == expected)
    }

    static func hasError(_ window: NSWindow, locale: String = "en") -> Bool {
        let error = L10n.string(String.LocalizationValue(PrivacyError.corruptData.messageKey), locale: Locale(identifier: locale))
        return Native.elements(window.contentView).contains {
            Native.value($0, "accessibilityRole") as? String == "AXStaticText"
                && (Native.value($0, "accessibilityValue") as? String == error
                    || Native.value($0, "accessibilityLabel") as? String == error)
        }
    }
}

@MainActor @Observable
final class PasswordSheetProbe {
    let configuration: Int
    var presented = true
    var calls = 0
    var completed = 0
    var dismissals = 0
    var correctInput = false
    var alternateInput = false
    var correctAfterWait = false
    var emptyAtAction = false
    var closeOnComplete = false
    var pending: CheckedContinuation<Void, Error>?
    var observeAction: (() -> Void)?
    weak var window: NSWindow?
    var confirmation: Bool { configuration % 2 == 0 }
    var title: LocalizedStringKey { configuration < 2 ? "privacy.master.label" : "privacy.backup.password.title" }
    var titleKey: String { configuration < 2 ? "privacy.master.label" : "privacy.backup.password.title" }
    var explanation: LocalizedStringKey { configuration < 2 ? "privacy.master.help" : "privacy.backup.password.help" }

    init(_ configuration: Int) { self.configuration = configuration }

    func action(_ input: String) async throws {
        calls += 1
        defer { correctAfterWait = input.utf8.elementsEqual(SecureInputTestSupport.sample.utf8) }
        correctInput = input.utf8.elementsEqual(SecureInputTestSupport.sample.utf8)
        alternateInput = input.utf8.elementsEqual(SecureInputTestSupport.alternateSample.utf8)
        emptyAtAction = window.map { SecureInputTestSupport.fields($0).allSatisfy { $0.stringValue.isEmpty } } ?? false
        observeAction?()
        try await withCheckedThrowingContinuation { pending = $0 }
    }

    func finish(failure: Bool = false) {
        let continuation = pending
        pending = nil
        if failure { continuation?.resume(throwing: PrivacyError.corruptData) }
        else { continuation?.resume() }
    }

    var content: AnyView {
        AnyView(PrivacyPasswordSheet(title: title, confirmation: confirmation, explanation: explanation,
            action: action, onComplete: {
                self.completed += 1
                if self.closeOnComplete { self.presented = false }
            }))
    }

    var host: some View {
        PrivacyButtonSheetHost(content: content, onDismiss: { self.dismissals += 1 },
            presentation: Binding(get: { self.presented }, set: { self.presented = $0 }))
    }
}
