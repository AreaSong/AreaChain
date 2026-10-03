import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 同一组直接消费者在迁移前后运行；日志中的事件、原生编辑 API 与人工缺口分开。
@Suite(.serialized) @MainActor
struct FormInputConsumerBaselineTests {
    typealias Form = FormInputTestSupport
    typealias Native = SettingsButtonTestSupport

    @Test(arguments: [UInt16(36), 48, 53], [false, true])
    func tagKeyboard(code: UInt16, command: Bool) async throws {
        let fixture = try SettingsButtonTestSupport()
        defer { fixture.cleanup() }
        var created: [String] = []
        let host = fixture.window(TaskDetailTagSelector(tagIDs: "", tags: [], onToggleTag: { _ in }, onCreateTag: {
            created.append($0); return true
        }))
        defer { Form.release(host) }
        try await NativeSyntaxUI.prepareFocus(in: host)
        try await Native.click(Native.button("drawer.tag.add", in: host), in: host)
        let sheet = try await Form.sheet(in: host)
        let field = try #require(Form.fields(in: sheet).first)
        print("FORM_TAG initial=\(Form.describeFocus(in: sheet)) sheet=\(sheet.contentView!.bounds.size) field=\(field.frame.size)")
        #expect(Form.describeFocus(in: sheet) == "Tag name")
        #expect(sheet.contentView?.bounds.width == 240)
        try await Form.enter("common.save", into: field, in: sheet)
        let character = code == 36 ? "\r" : (code == 48 ? "\t" : "\u{1b}")
        try await Form.key(code, text: character, flags: command ? .command : [], in: sheet)
        print("FORM_TAG key=\(code) command=\(command) creates=\(created.count) attached=\(host.attachedSheet != nil) focus=\(Form.describeFocus(in: sheet)) value=\(field.stringValue.debugDescription)")
        #expect(created.isEmpty)
        #expect((host.attachedSheet != nil) == (code != 53 || command))
        #expect(field.stringValue == "common.save")
        if code != 53 { #expect(Form.describeFocus(in: sheet) == "Tag name") }
        try Native.snapshot(sheet, name: "form-tag-baseline-\(code)-\(command)")
    }

    @Test func clipboardKeyboardAndNativeEditing() async throws {
        let fixture = try ClipboardOptionsFixture()
        defer { fixture.cleanup() }
        fixture.seedPreferences(longLists: true)
        let session = fixture.session()
        let host = fixture.native.window(PrivacyButtonSheetHost(content: AnyView(ClipboardHistoryOptions(session: session)),
            onDismiss: {}), size: NSSize(width: 520, height: 650))
        defer { Form.release(host) }
        let sheet = try await Form.sheet(in: host)
        let saved = fixture.persisted
        print("FORM_CLIP initial=\(Form.describeFocus(in: sheet)) sheet=\(sheet.contentView!.bounds.size)")
        for key in ["clipboard.patterns.add", "clipboard.types.add"] {
            let field = try fixture.field(key, locale: "en", in: sheet)
            try await Form.enter("common.save # @ ! // \\(中文) 🧪", into: field, in: sheet)
            let editor = try #require(field.currentEditor() as? NSTextView)
            editor.setSelectedRange(NSRange(location: 0, length: 6))
            editor.insertText("替换", replacementRange: editor.selectedRange())
            try await SystemPageHost.settle(sheet)
            #expect(field.stringValue.hasPrefix("替换.save"))
            editor.setMarkedText("拼音", selectedRange: NSRange(location: 2, length: 0), replacementRange: editor.selectedRange())
            #expect(editor.hasMarkedText())
            editor.insertText("中文", replacementRange: editor.markedRange())
            try await SystemPageHost.settle(sheet)
            #expect(!editor.hasMarkedText() && field.stringValue.contains("中文"))
            for command in [false, true] {
                try await Form.key(36, text: "\r", flags: command ? .command : [], in: sheet)
                print("FORM_CLIP \(key) return command=\(command) focus=\(Form.describeFocus(in: sheet)) value=\(field.stringValue.debugDescription)")
                #expect(fixture.persisted == saved)
                _ = try await Form.editor(field, in: sheet)
            }
            try await Form.key(48, text: "\t", in: sheet)
            print("FORM_CLIP \(key) tab=\(Form.describeFocus(in: sheet)) field=\(field.frame.size)")
            #expect(Form.describeFocus(in: sheet) == (key == "clipboard.patterns.add" ? "Add a type" : "Add a pattern"))
            #expect(fixture.persisted == saved)
            try await Native.reveal(field, in: sheet)
            try fixture.assertVisible(field, in: sheet)
        }
        try Native.snapshot(sheet, name: "form-clipboard-baseline")
        try await Form.key(53, text: "\u{1b}", in: sheet)
        print("FORM_CLIP escape attached=\(host.attachedSheet != nil)")
        #expect(host.attachedSheet == nil)
        #expect(fixture.persisted == saved)
    }
}
