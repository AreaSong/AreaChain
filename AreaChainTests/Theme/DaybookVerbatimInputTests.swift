import AppKit
import Testing
import SwiftUI
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DaybookVerbatimInputTests {
    @Test func minimumNativeLayout() throws {
        let storage = NSTextStorage(string: "甲\r\n乙\n丙\u{2028}丁", attributes: [.font: NSFont.systemFont(ofSize: 13)])
        let layout = NSLayoutManager()
        let presentation = DaybookSingleLineLayout()
        layout.delegate = presentation
        let container = NSTextContainer(size: NSSize(width: 10000, height: 100))
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        layout.ensureLayout(for: container)
        var lines = 0
        layout.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: layout.numberOfGlyphs)) { _, _, _, _, _ in
            lines += 1
        }
        #expect(lines == 1)
        let first = layout.location(forGlyphAt: 0)
        let last = layout.location(forGlyphAt: layout.numberOfGlyphs - 1)
        #expect(last.x > first.x)
        #expect(storage.string == "甲\r\n乙\n丙\u{2028}丁")
    }
    @Test func minimumNativeEditing() async throws {
        let base = try SettingsButtonTestSupport()
        defer { base.cleanup() }
        let draft = SearchMultilineDraft()
        let content = DaybookTextField(text: Binding(get: { draft.text }, set: { draft.text = $0 }),
            placeholder: "VERBATIM", focus: .constant(false), onSubmit: {},
            allowsShiftNewline: false, newlinePolicy: .verbatim).frame(width: 260, height: 24)
        let window = base.window(content, size: NSSize(width: 300, height: 100))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        let field = try #require(FormInputTestSupport.fields(in: window).first)
        let editor = try await FormInputTestSupport.editor(field, in: window)
        let manager = try #require(editor.layoutManager)
        let container = try #require(editor.textContainer)
        let raw = String(repeating: "头🧪\r\n乙\n丙e\u{301}\u{2028}尾", count: 12)
        for board in [false, true] {
            try SearchMultilineBoundaryTests.importText(raw, editor: editor, namedBoard: board)
            try await SystemPageHost.settle(window)
            #expect(editor.string == raw && field.stringValue == raw && draft.text == raw)
            try assertActiveCellDoesNotOverprint(field)
            manager.ensureLayout(for: container)
            var lines = 0
            manager.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: manager.numberOfGlyphs)) { _, _, _, _, _ in
                lines += 1
            }
            #expect(lines == 1)
            let positions = (0..<raw.utf16.count).filter { (raw as NSString).character(at: $0) == 0x4E59 }
                .map { manager.location(forGlyphAt: manager.glyphIndexForCharacter(at: $0)).x }
            #expect(zip(positions, positions.dropFirst()).allSatisfy { $0 < $1 })
            #expect(editor.selectedRange() == NSRange(location: raw.utf16.count, length: 0))
            try #require(editor.tryToPerform(Selector(("undo:")), with: nil))
            #expect(editor.string.isEmpty && draft.text.isEmpty)
            try #require(editor.tryToPerform(Selector(("redo:")), with: nil))
            #expect(editor.string == raw && draft.text == raw)
            #expect(editor.selectedRange() == NSRange(location: raw.utf16.count, length: 0))
            try #require(editor.tryToPerform(Selector(("undo:")), with: nil))
            try await SystemPageHost.settle(window)
        }
    }

    private func assertActiveCellDoesNotOverprint(_ field: NSTextField) throws {
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 260, pixelsHigh: 24,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let context = try #require(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        field.cell?.drawInterior(withFrame: NSRect(x: 0, y: 0, width: 260, height: 24), in: field)
        NSGraphicsContext.restoreGraphicsState()
        for y in 0..<24 {
            for x in 0..<260 { #expect(bitmap.colorAt(x: x, y: y)?.alphaComponent == 0) }
        }
    }

}
