import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ControlsPreviewInteractionTests {
    typealias Support = ControlsPreviewTestSupport
    typealias Native = SettingsButtonTestSupport

    @Test func dateAndTimePopoversStayWithTheirWindow() async throws {
        let support = try Support()
        defer { support.cleanup() }
        let window = try await support.open()
        try await Support.press("preview.date.open", in: window)
        let date = try DatePickerTestSupport.popup(excluding: window)
        try await NativeSyntaxUI.prepareFocus(in: date)
        try await DatePickerTestSupport.select("2026-09-19", in: date)
        #expect(try DatePickerTestSupport.selected("2026-09-19", in: date))
        try await DatePickerTestSupport.key(53, "\u{1b}", in: date)
        try await NativeSyntaxUI.prepareFocus(in: window)
        #expect(!date.isVisible && window.isVisible)
        try await Support.press("preview.time.open", in: window)
        let time = try #require(NSApp.windows.first { $0 !== window && $0.isVisible &&
            Native.elements($0.contentView).contains { $0 is NSDatePicker } })
        try await NativeSyntaxUI.prepareFocus(in: time)
        let picker = try TimePickerNativeTestSupport.picker(in: time)
        let before = picker.dateValue
        let rect = picker.convert(picker.bounds, to: nil)
        try await TimePickerNativeTestSupport.click(NSPoint(x: rect.minX + 10, y: rect.midY), in: time)
        try await TimePickerNativeTestSupport.key(126, "\u{F700}", in: time)
        #expect(picker.dateValue != before)
        try await NativeSyntaxUI.prepareFocus(in: support.workspace)
        try await Support.commandReturn(in: support.workspace)
        #expect(try Support.actions(in: window) == "0")
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await Support.commandReturn(in: window)
        #expect(try Support.actions(in: window) == "1")
        window.close()
        try await SystemPageHost.settle(support.workspace)
        #expect(!date.isVisible && !time.isVisible && support.workspace.isVisible)
        #expect(support.businessEvents == 0)
    }

    @Test func formKeyboardFocusAndCopyFeedbackAreLocal() async throws {
        let support = try Support()
        defer { support.cleanup() }
        let window = try await support.open()
        let label = L10n.string("drawer.tag.create.name", locale: Locale(identifier: "en"))
        let field = try #require(FormInputTestSupport.fields(in: window).first { $0.placeholderString == label })
        let editor = try await FormInputTestSupport.editor(field, in: window)
        #expect(window.firstResponder === editor)
        editor.insertText("Preview input", replacementRange: NSRange(location: 0, length: 0))
        try await FormInputTestSupport.key(48, text: "\t", in: window)
        #expect(field.currentEditor() !== window.firstResponder)
        #expect(field.stringValue == "Preview input")
        let copyBefore = NSPasteboard.general.changeCount
        let bubble = try #require(Native.elements(window.contentView).first {
            Native.value($0, "accessibilityValue") as? String == "Synthetic 合成长标题气泡"
        })
        try await Native.reveal(bubble, in: window)
        try await Native.click(bubble, in: window)
        _ = try Support.node("preview.copyFeedback", in: window)
        #expect(NSPasteboard.general.changeCount == copyBefore)
        #expect(support.businessEvents == 0)
        let oldCount = try Support.actions(in: window)
        try await Support.press("preview.disabled", in: window)
        try await Support.press("preview.reset", in: window)
        #expect(oldCount == "0")
        #expect(try Support.actions(in: window) == "0")
        #expect(!Native.elements(window.contentView).contains {
            Native.value($0, "accessibilityIdentifier") as? String == "preview.copyFeedback"
        })
    }
}
