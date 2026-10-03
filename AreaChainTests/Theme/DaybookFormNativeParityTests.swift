import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DaybookFormNativeParityTests {
    typealias Form = FormInputTestSupport
    typealias Native = SettingsButtonTestSupport

    @Test func insertionPayloadMatchesOriginalNativeField() async throws {
        let fixture = try SettingsButtonTestSupport()
        defer { fixture.cleanup() }
        let state = FormFieldTestState()
        let host = fixture.window(VStack {
            DaybookFormTextField(verbatim: "public", text: state.binding(true))
            TextField("native", text: state.binding(false)).textFieldStyle(.plain).font(DaybookType.body)
        }.padding(), size: NSSize(width: 240, height: 140))
        defer { Form.release(host) }
        try await NativeSyntaxUI.prepareFocus(in: host)
        try await SystemPageHost.settle(host)
        let fields = Form.fields(in: host)
        let shared = try #require(fields.first { $0.placeholderString == "public" })
        let original = try #require(fields.first { $0.placeholderString == "native" })
        // 这是原生编辑 API 的合成粘贴负载对照，不访问 NSPasteboard，不代表系统粘贴验收。
        for payload in ["common.save", #"\(中文) # @ ! // 🧑🏽‍💻 é"#, "  first\nsecond\r\n第三行  ", "one\ttwo"] {
            for field in [shared, original] {
                let editor = try await Form.editor(field, in: host)
                editor.insertText(payload, replacementRange: NSRange(location: 0, length: (editor.string as NSString).length))
                try await SystemPageHost.settle(host)
            }
            #expect(state.first == state.second && shared.stringValue == original.stringValue)
            print("FORM_PAYLOAD \(payload.debugDescription) -> \(state.first.debugDescription)")
        }
    }

    @Test(arguments: ["en", "zh-Hans"], [false, true])
    func originalPreviewShowsFocusDisabledAndLongFields(locale: String, dark: Bool) async throws {
        let fixture = try SettingsButtonTestSupport()
        defer { fixture.cleanup() }
        let host = fixture.window(DaybookControlsPreview(localeID: locale, dark: dark, longLabels: true),
            locale: locale, scheme: dark ? .dark : .light, size: NSSize(width: 760, height: 640))
        defer { Form.release(host) }
        try await NativeSyntaxUI.prepareFocus(in: host)
        try await SystemPageHost.settle(host)
        let name = L10n.string("drawer.tag.create.name", locale: Locale(identifier: locale))
        let field = try #require(Form.fields(in: host).first { $0.placeholderString == name })
        host.makeFirstResponder(nil)
        try await SystemPageHost.settle(host)
        try Native.snapshot(host, name: "form-preview-blur-\(locale)-\(dark)")
        _ = try await Form.editor(field, in: host)
        #expect(field.currentEditor() === host.firstResponder)
        try Native.snapshot(host, name: "form-preview-focus-\(locale)-\(dark)")
        let disabled = try #require(Form.fields(in: host).first {
            $0.placeholderString == L10n.string("clipboard.types.add", locale: Locale(identifier: locale))
        })
        #expect(!disabled.isEnabled && disabled.stringValue == "common.save")
        let long = try #require(Form.fields(in: host).first { $0.placeholderString == "common.save" })
        try await Native.reveal(long, in: host)
        try Native.assertBounds([long], in: host)
        #expect(long.stringValue.count > 200 && long.frame.height < 28)
    }
}
