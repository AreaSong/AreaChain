import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DaybookFormTextFieldTests {
    typealias Form = FormInputTestSupport
    typealias Native = SettingsButtonTestSupport

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func localizationExternalUpdatesDisabledAndIndependentFields(locale: String, scheme: ColorScheme) async throws {
        let fixture = try SettingsButtonTestSupport()
        defer { fixture.cleanup() }
        let state = FormFieldTestState()
        let host = fixture.window(FormFieldTestContent(state: state), locale: locale, scheme: scheme,
                                  size: NSSize(width: 240, height: 210))
        defer { Form.release(host) }
        try await NativeSyntaxUI.prepareFocus(in: host)
        try await SystemPageHost.settle(host)
        let fields = Form.fields(in: host)
        #expect(fields.count == 3 && state.writes == 0)
        let first = try #require(fields.first { $0.placeholderString == L10n.string("clipboard.patterns.add", locale: Locale(identifier: locale)) })
        let second = try #require(fields.first { $0.placeholderString == "common.save" })
        let disabled = try #require(fields.first { $0.placeholderString == "disabled" })
        #expect(!disabled.isEnabled)
        #expect(first.accessibilityLabel() == first.placeholderString)
        #expect(second.accessibilityLabel() == "common.save")
        try await Form.enter(#"common.save \(中文) # @ ! // 🧪"#, into: first, in: host)
        #expect(state.first == first.stringValue && state.second == "original" && state.writes > 0)
        let writes = state.writes
        state.first = "外部更新 e\u{301} 🧑🏽‍💻"
        try await SystemPageHost.settle(host)
        #expect(first.stringValue == state.first && state.writes == writes)
        try await Form.enter("independent", into: second, in: host)
        #expect(state.first == "外部更新 e\u{301} 🧑🏽‍💻" && state.second == "independent")
        try Native.assertBounds(fields, in: host)
        try Native.snapshot(host, name: "form-fields-\(locale)-\(scheme)")
    }

    @Test func nativeTypingSelectionMarkedTextAndUndo() async throws {
        let fixture = try SettingsButtonTestSupport()
        defer { fixture.cleanup() }
        let state = FormFieldTestState()
        let host = fixture.window(FormFieldTestContent(state: state), size: NSSize(width: 240, height: 210))
        defer { Form.release(host) }
        try await NativeSyntaxUI.prepareFocus(in: host)
        try await SystemPageHost.settle(host)
        let field = try #require(Form.fields(in: host).first { $0.placeholderString == "common.save" })
        let editor = try await Form.editor(field, in: host)
        editor.selectAll(nil)
        try await Form.key(0, text: "a", in: host)
        #expect(state.second == "a")
        editor.setSelectedRange(NSRange(location: 0, length: 1))
        editor.insertText("中文 🧪", replacementRange: editor.selectedRange())
        try await SystemPageHost.settle(host)
        #expect(state.second == "中文 🧪")
        editor.breakUndoCoalescing()
        editor.insertText("追加", replacementRange: NSRange(location: (editor.string as NSString).length, length: 0))
        try await SystemPageHost.settle(host)
        let manager = try #require(editor.undoManager)
        #expect(manager.canUndo)
        manager.undo()
        try await SystemPageHost.settle(host)
        #expect(state.second == "original", "原生撤销恢复本次合并编辑之前的内容")
        #expect(manager.canRedo)
        manager.redo()
        try await SystemPageHost.settle(host)
        #expect(state.second == "中文 🧪追加")
        editor.setMarkedText("拼音", selectedRange: NSRange(location: 2, length: 0), replacementRange: editor.selectedRange())
        #expect(editor.hasMarkedText())
        editor.insertText("组合", replacementRange: editor.markedRange())
        try await SystemPageHost.settle(host)
        #expect(!editor.hasMarkedText() && state.second.contains("组合"))
        let long = String(repeating: #"\(中文) # @ ! // 🧪 "#, count: 30)
        try await Form.enter(long, into: field, in: host)
        #expect(state.second == long && field.bounds.width < 240 && field.bounds.height < 28)
        editor.moveToBeginningOfDocument(nil)
        editor.moveToEndOfDocument(nil)
        #expect(editor.selectedRange().location == (long as NSString).length)
        try Native.assertBounds([field], in: host)
    }

    @Test func rejectedBindingRebuildAndClosingNeverSubmit() async throws {
        let fixture = try SettingsButtonTestSupport()
        defer { fixture.cleanup() }
        let state = FormFieldTestState()
        state.reject = true
        let content = FormFieldTestContent(state: state)
        let host = fixture.window(content, size: NSSize(width: 240, height: 210))
        try await NativeSyntaxUI.prepareFocus(in: host)
        try await SystemPageHost.settle(host)
        let field = try #require(Form.fields(in: host).first { $0.placeholderString == "common.save" })
        let editor = try await Form.editor(field, in: host)
        editor.insertText("rejected", replacementRange: NSRange(location: 0, length: (editor.string as NSString).length))
        try await SystemPageHost.settle(host)
        #expect(state.second == "original" && state.writes > 0)
        // 原生 TextField 可以暂留正在编辑的提案；失焦/外部刷新不得把它提交给业务。
        host.makeFirstResponder(nil)
        let writes = state.writes
        Form.release(host)
        let reopened = fixture.window(content, size: NSSize(width: 240, height: 210))
        defer { Form.release(reopened) }
        try await SystemPageHost.settle(reopened)
        let restored = try #require(Form.fields(in: reopened).first { $0.placeholderString == "common.save" })
        #expect(restored.stringValue == "original" && state.writes == writes)
        #expect(state.submits == 0)
    }
}

@MainActor @Observable
final class FormFieldTestState {
    var first = ""
    var second = "original"
    var writes = 0
    var submits = 0
    var reject = false

    func binding(_ firstField: Bool) -> Binding<String> {
        Binding(get: { firstField ? self.first : self.second }, set: {
            self.writes += 1
            guard !self.reject else { return }
            if firstField { self.first = $0 } else { self.second = $0 }
        })
    }
}

private struct FormFieldTestContent: View {
    @Bindable var state: FormFieldTestState

    var body: some View {
        VStack(spacing: DaybookSpacing.md) {
            DaybookFormTextField("clipboard.patterns.add", text: state.binding(true))
            DaybookFormTextField(verbatim: "common.save", text: state.binding(false))
            DaybookFormTextField(verbatim: "disabled", text: .constant("不可编辑")).disabled(true)
        }
        .padding(DaybookSpacing.lg)
        .background(DaybookPalette.fill.page)
        .onSubmit { state.submits += 1 }
    }
}
