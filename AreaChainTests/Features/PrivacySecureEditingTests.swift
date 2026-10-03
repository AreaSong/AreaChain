import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct PrivacySecureEditingTests {
    typealias Secure = SecureInputTestSupport

    @Test func nativeEditingRestrictionsAndSelection() async throws {
        let fixture = try SettingsButtonTestSupport()
        defer { fixture.cleanup() }
        let probe = PasswordSheetProbe(1)
        let host = fixture.window(probe.host)
        defer { FormInputTestSupport.release(host); probe.finish() }
        let sheet = try await FormInputTestSupport.sheet(in: host)
        probe.window = sheet
        let field = try #require(Secure.fields(sheet).first)
        let editor = try await FormInputTestSupport.editor(field, in: sheet)
        editor.selectAll(nil)
        try await FormInputTestSupport.key(0, text: "a", in: sheet)
        let nativeKeyAccepted = field.stringValue == "a"
        #expect(nativeKeyAccepted)
        editor.setSelectedRange(NSRange(location: 0, length: 1))
        editor.insertText(Secure.sample, replacementRange: editor.selectedRange())
        try await SystemPageHost.settle(sheet)
        let exact = field.stringValue.utf8.elementsEqual(Secure.sample.utf8)
        #expect(exact)
        print("Secure editing selectionLength=\(editor.selectedRange().length) allowsUndo=\(editor.allowsUndo) canUndo=\(editor.undoManager?.canUndo ?? false) marked=\(editor.hasMarkedText())")
        // 只查询原生能力，不调用复制、剪切或启用撤销，不触碰系统剪贴板。
        let copy = NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "")
        let cut = NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "")
        editor.selectAll(nil)
        print("Secure editing copyEnabled=\(editor.validateMenuItem(copy)) cutEnabled=\(editor.validateMenuItem(cut))")
        let long = String(repeating: Secure.sample, count: 30)
        try await Secure.enter(long, in: sheet)
        editor.moveToEndOfDocument(nil)
        #expect(editor.selectedRange().location == (long as NSString).length)
        try SettingsButtonTestSupport.assertBounds([field], in: sheet)
        try await Secure.fill(sheet)
        try await Secure.click("common.save", in: sheet)
        #expect(probe.correctInput && probe.emptyAtAction && probe.calls == 1)
        probe.finish(failure: true)
        try await SystemPageHost.settle(sheet)
        #expect(Secure.fields(sheet).allSatisfy { $0.stringValue.isEmpty })
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func longExplanationAndErrorStayInsideActualSheet(locale: String, scheme: ColorScheme) async throws {
        let fixture = try SettingsButtonTestSupport()
        defer { fixture.cleanup() }
        let explanation = String(repeating: locale == "en"
            ? "Synthetic explanation with additional context for this password operation. "
            : "用于说明本次密码操作的合成长说明，请核对后继续。", count: 6)
        let content = PrivacyPasswordSheet(title: "privacy.backup.password.title", confirmation: true,
            explanation: LocalizedStringKey(explanation), action: { _ in throw PrivacyError.corruptData }, onComplete: {})
        let host = fixture.window(PrivacyButtonSheetHost(content: AnyView(content), onDismiss: {}), locale: locale, scheme: scheme)
        defer { FormInputTestSupport.release(host) }
        let sheet = try await FormInputTestSupport.sheet(in: host)
        try await Secure.fill(sheet)
        try await Secure.click("common.save", locale: locale, in: sheet)
        #expect(Secure.hasError(sheet, locale: locale))
        #expect(sheet.contentView?.bounds.width == 440)
        let nodes = SettingsButtonTestSupport.elements(sheet.contentView).filter {
            SettingsButtonTestSupport.value($0, "accessibilityRole") as? String == "AXStaticText"
                || SettingsButtonTestSupport.value($0, "accessibilityRole") as? String == "AXButton"
                || SettingsButtonTestSupport.value($0, "accessibilitySubrole") as? String == "AXSecureTextField"
        }
        try SettingsButtonTestSupport.assertBounds(nodes, in: sheet)
        try SettingsButtonTestSupport.snapshot(sheet, name: "secure-long-error-\(locale)-\(scheme)")
    }

}
