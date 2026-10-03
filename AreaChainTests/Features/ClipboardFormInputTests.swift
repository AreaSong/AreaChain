import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ClipboardFormInputTests {
    typealias Form = FormInputTestSupport
    typealias Native = SettingsButtonTestSupport

    @Test(arguments: ["en", "zh-Hans"])
    func addRejectEditCancelAndRebuild(locale: String) async throws {
        let fixture = try ClipboardOptionsFixture()
        defer { fixture.cleanup() }
        fixture.seedPreferences(longLists: true)
        let session = fixture.session()
        let host = fixture.native.window(PrivacyButtonSheetHost(content: AnyView(ClipboardHistoryOptions(session: session)),
            onDismiss: {}), locale: locale, scheme: locale == "en" ? .light : .dark,
            size: NSSize(width: 520, height: 650))
        defer { Form.release(host) }
        let sheet = try await Form.sheet(in: host)
        #expect(sheet.contentView?.bounds.size == NSSize(width: 440, height: 560))
        let pattern = try fixture.field("clipboard.patterns.add", locale: locale, in: sheet)
        let type = try fixture.field("clipboard.types.add", locale: locale, in: sheet)
        let saved = fixture.persisted
        try await Form.enter("com.example.待添加", into: type, in: sheet)
        try await Form.enter("[", into: pattern, in: sheet)
        #expect(fixture.persisted == saved)
        try await add(pattern, locale: locale, in: sheet)
        #expect(pattern.stringValue == "[" && fixture.persisted == saved)
        let message = L10n.string("clipboard.pattern.invalid", locale: Locale(identifier: locale))
        #expect(Form.labels(in: sheet).contains(message))
        try await Form.enter("^synthetic$", into: pattern, in: sheet)
        #expect(Form.labels(in: sheet).contains(message), "普通编辑不清除正则拒绝提示")
        try await add(pattern, locale: locale, in: sheet)
        #expect(pattern.stringValue == "^synthetic$" && fixture.persisted == saved)
        try await recordErrorGeometry(pattern, message: message, in: sheet, locale: locale)
        let regex = #"^\(中文\) # @ ! // \s+🧪$"#
        try await Form.enter("  \(regex)  ", into: pattern, in: sheet)
        try await add(pattern, locale: locale, in: sheet)
        #expect(pattern.stringValue.isEmpty && session.patterns.last == regex)
        #expect(type.stringValue == "com.example.待添加" && !Form.labels(in: sheet).contains(message))
        fixture.assertStoredModel(try fixture.rebuiltSession())
        try await rejectedTypes(type, fixture: fixture, locale: locale, in: sheet)
        try await Form.enter("  common.save  ", into: type, in: sheet)
        try await add(type, locale: locale, in: sheet)
        #expect(type.stringValue.isEmpty && session.extraTypes.last == "common.save")
        fixture.assertStoredModel(try fixture.rebuiltSession())
        try await Form.enter("unsubmitted", into: type, in: sheet)
        let committed = fixture.persisted
        try await Native.click(Native.button("alert.cancel", locale: locale, in: sheet), in: sheet)
        try await Form.wait { host.attachedSheet == nil }
        #expect(fixture.persisted == committed)
        let rebuilt = try fixture.rebuiltSession()
        #expect(rebuilt.patterns == session.patterns && rebuilt.extraTypes == session.extraTypes)
        let reopened = fixture.native.window(ClipboardHistoryOptions(session: rebuilt), locale: locale,
                                            size: NSSize(width: 440, height: 560))
        defer { Form.release(reopened) }
        try await SystemPageHost.settle(reopened)
        #expect(try fixture.field("clipboard.patterns.add", locale: locale, in: reopened).stringValue.isEmpty)
        #expect(try fixture.field("clipboard.types.add", locale: locale, in: reopened).stringValue.isEmpty)
        #expect(fixture.persisted == committed && session.items.isEmpty && !session.ignoreNext)
    }

    private func add(_ field: NSTextField, locale: String, in window: NSWindow) async throws {
        try await Native.reveal(field, in: window)
        let button = try Form.addButton(nextTo: field, in: window, locale: locale)
        try Native.assertBounds([field, button], in: window)
        try await Native.click(button, in: window)
    }

    private func rejectedTypes(_ field: NSTextField, fixture: ClipboardOptionsFixture,
                               locale: String, in window: NSWindow) async throws {
        let saved = fixture.persisted
        for value in ["   ", "com.example.synthetic-type", "org.nspasteboard.ConcealedType"] {
            try await Form.enter(value, into: field, in: window)
            try await add(field, locale: locale, in: window)
            #expect(field.stringValue == value && fixture.persisted == saved)
        }
    }

    private func recordErrorGeometry(_ field: NSTextField, message: String, in window: NSWindow,
                                     locale: String) async throws {
        try await Native.reveal(field, in: window)
        let error = try #require(Native.elements(window.contentView).first {
            Native.value($0, "accessibilityRole") as? String == "AXStaticText"
                && Native.value($0, "accessibilityValue") as? String == message
        })
        let fieldRect = try Native.frame(field, in: window)
        let errorRect = try Native.frame(error, in: window)
        print("FORM_ERROR \(locale) field=\(fieldRect) error=\(errorRect) overlaps=\(fieldRect.intersects(errorRect))")
        let button = try Form.addButton(nextTo: field, in: window, locale: locale)
        try Native.assertBounds([field, error, button], in: window)
        #expect(!fieldRect.intersects(errorRect))
        try Native.snapshot(window, name: "form-error-\(locale)")
    }
}
