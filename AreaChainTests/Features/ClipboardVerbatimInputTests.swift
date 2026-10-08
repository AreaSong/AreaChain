import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ClipboardVerbatimInputTests {
    @Test(arguments: [ClipboardSearchMode.mixed, .exact, .regex])
    func modeBoundariesAndSubmission(mode: ClipboardSearchMode) async throws {
        let fixture = try SearchMultilineFixture(.clipboard)
        defer { fixture.cleanup() }
        fixture.session.searchMode = mode
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        let stored = try Data(contentsOf: fixture.base.root.appendingPathComponent("history.json"))
        for raw in ["甲\n乙", #"甲\n乙"#, "", " \r\n ", " \n甲\n乙\r\n ", "甲\r\n乙", "[", "^", "甲 // 乙"] {
            for board in [false, true] {
                editor.setSelectedRange(NSRange(location: 0, length: editor.string.utf16.count))
                try SearchMultilineBoundaryTests.importText(raw, editor: editor, namedBoard: board)
                try await SystemPageHost.settle(fixture.window)
                #expect(fixture.session.query == raw && editor.string == raw && field.stringValue == raw)
                let expected: Set<String>
                switch raw {
                case "", " \r\n ": expected = Set(fixture.session.items.map(\.plainText))
                case "甲\n乙", " \n甲\n乙\r\n ": expected = ["甲\n乙 CLIP_LF"]
                case #"甲\n乙"#: expected = mode == .regex ? ["甲\n乙 CLIP_LF"] : [#"甲\n乙 CLIP_ESCAPE"#]
                case "^": expected = mode == .regex ? Set(fixture.session.items.map(\.plainText)) : []
                case "甲 // 乙": expected = ["甲 // 乙 CLIP_SLASH"]
                default: expected = []
                }
                #expect(Set(fixture.session.visibleItems.map(\.plainText)) == expected)
                #expect(fixture.session.noticeKey == nil)
                try await SearchMultilineBoundaryTests.key(command: true, in: fixture.window)
                #expect(fixture.session.query == raw && fixture.draft.commits == 0)
            }
        }
        editor.setSelectedRange(NSRange(location: 0, length: editor.string.utf16.count))
        try SearchMultilineBoundaryTests.importText("甲\n乙", editor: editor, namedBoard: true)
        try await SystemPageHost.settle(fixture.window)
        for next in [ClipboardSearchMode.mixed, .exact, .regex] {
            fixture.session.searchMode = next
            try await SystemPageHost.settle(fixture.window)
            #expect(fixture.session.query == "甲\n乙" && editor.string == "甲\n乙")
        }
        fixture.session.searchMode = mode
        try await SystemPageHost.settle(fixture.window)
        try await SearchMultilineBoundaryTests.key(shift: true, in: fixture.window)
        #expect(fixture.session.query == "甲\n乙" && fixture.draft.commits == 0)
        try await SearchMultilineBoundaryTests.key(in: fixture.window)
        let id = try #require(fixture.session.items.first { $0.plainText == "甲\n乙 CLIP_LF" }?.id)
        #expect(fixture.draft.committedIDs == [id])
        #expect(fixture.draft.committedOptions.count == 1)
        #expect(fixture.draft.committedOptions.first?.plain == fixture.session.plainByDefault)
        #expect(fixture.draft.committedOptions.first?.paste == false)
        #expect(fixture.session.query == "甲\n乙")
        #expect(fixture.window.makeFirstResponder(nil))
        try await SystemPageHost.settle(fixture.window)
        #expect(!fixture.session.clipboardFieldFocused)
        #expect(field.stringValue == "甲\n乙" && fixture.session.query == "甲\n乙")
        _ = try await FormInputTestSupport.editor(field, in: fixture.window)
        #expect(fixture.window.firstResponder === editor && editor.string == "甲\n乙")
        // AppKit 的 begin-editing 在修改时发出，单纯重获焦点不等于再次开始编辑。
        editor.insertText("!", replacementRange: NSRange(location: editor.string.utf16.count, length: 0))
        try await SystemPageHost.settle(fixture.window)
        #expect(fixture.session.clipboardFieldFocused)
        try #require(editor.tryToPerform(Selector(("undo:")), with: nil))
        #expect(editor.string == "甲\n乙" && fixture.session.query == "甲\n乙")
        try await SearchMultilineBoundaryTests.key(code: 53, text: "\u{1b}", in: fixture.window)
        #expect(fixture.session.query.isEmpty && fixture.draft.commits == 1)
        #expect(try Data(contentsOf: fixture.base.root.appendingPathComponent("history.json")) == stored)
        #expect(try fixture.base.rebuiltSession().query.isEmpty)
    }

    @Test func attributedSelectionAndNativePositions() async throws {
        let fixture = try SearchMultilineFixture(.clipboard)
        defer { fixture.cleanup() }
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        fixture.session.query = "头🧪尾"
        try await SystemPageHost.settle(fixture.window)
        #expect(editor.undoManager?.canUndo != true)
        let replacement = NSRange(location: 1, length: 2)
        editor.setSelectedRange(replacement)
        let raw = "e\u{301}\r\n甲\u{0085}乙\u{2028}丙\u{2029}丁\u{000B}戊\u{000C}己 \\n"
        editor.insertText(NSAttributedString(string: raw), replacementRange: replacement)
        try await SystemPageHost.settle(fixture.window)
        let expected = "头" + raw + "尾"
        #expect(Array(editor.string.utf16) == Array(expected.utf16) && fixture.session.query == expected)
        for _ in 0..<3 {
            try #require(editor.tryToPerform(Selector(("undo:")), with: nil))
            #expect(editor.string == "头🧪尾" && editor.selectedRange() == replacement)
            try #require(editor.tryToPerform(Selector(("redo:")), with: nil))
            #expect(Array(editor.string.utf16) == Array(expected.utf16) && fixture.session.query == expected)
            #expect(editor.selectedRange() == NSRange(location: 1 + raw.utf16.count, length: 0))
        }
        let layout = try #require(editor.layoutManager)
        let container = try #require(editor.textContainer)
        layout.ensureLayout(for: container)
        var lineRanges: [NSRange] = []
        layout.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: layout.numberOfGlyphs)) { _, _, _, range, _ in
            lineRanges.append(range)
        }
        #expect(lineRanges.count == 1)
        let afterLF = (expected as NSString).range(of: "甲").location
        editor.setSelectedRange(NSRange(location: afterLF, length: 0))
        editor.moveLeft(nil)
        #expect(editor.selectedRange().location < afterLF)
        editor.moveRight(nil)
        #expect(editor.selectedRange() == NSRange(location: afterLF, length: 0))
        editor.moveRightAndModifySelection(nil)
        #expect((expected as NSString).substring(with: editor.selectedRange()) == "甲")
        editor.insertText("中", replacementRange: editor.selectedRange())
        #expect(editor.string == expected.replacingOccurrences(of: "甲", with: "中"))
        #expect(field.currentEditor() === editor && fixture.window.firstResponder === editor)
    }

    @Test func compositionCancellationKeepsOriginalQuery() async throws {
        let fixture = try SearchMultilineFixture(.clipboard)
        defer { fixture.cleanup() }
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        fixture.session.query = "头\r\n尾"
        try await SystemPageHost.settle(fixture.window)
        editor.setMarkedText("拼音", selectedRange: NSRange(location: 2, length: 0),
                             replacementRange: NSRange(location: 3, length: 0))
        try #require(editor.hasMarkedText())
        editor.setMarkedText("", selectedRange: NSRange(location: 0, length: 0), replacementRange: editor.markedRange())
        editor.unmarkText()
        try await SystemPageHost.settle(fixture.window)
        #expect(!editor.hasMarkedText() && editor.string == "头\r\n尾")
        #expect(fixture.session.query == "头\r\n尾" && fixture.draft.commits == 0)
    }

    @Test(arguments: ["en", "zh-Hans"], [false, true])
    func narrowSingleLinePresentation(locale: String, dark: Bool) async throws {
        for width in [380.0, 440.0] {
            let fixture = try SearchMultilineFixture(.clipboard, locale: locale, scheme: dark ? .dark : .light,
                size: NSSize(width: width, height: 460), commitsOnClick: width == 380)
            defer { fixture.cleanup() }
            try await NativeSyntaxUI.prepareFocus(in: fixture.window)
            try await SystemPageHost.settle(fixture.window)
            let field = try #require(FormInputTestSupport.fields(in: fixture.window).first)
            let editor = try await FormInputTestSupport.editor(field, in: fixture.window)
            let originalHeight = field.frame.height
            let raw = String(repeating: "甲\r\n🧪e\u{301}乙 ", count: 20) + "END"
            editor.insertText(raw, replacementRange: NSRange(location: 0, length: 0))
            try await SystemPageHost.settle(fixture.window)
            let layout = try #require(editor.layoutManager)
            let container = try #require(editor.textContainer)
            layout.ensureLayout(for: container)
            #expect(field.frame.height == originalHeight)
            #expect(layout.usedRect(for: container).height <= field.frame.height + 2)
            editor.scrollRangeToVisible(NSRange(location: raw.utf16.count, length: 0))
            let glyph = layout.glyphIndexForCharacter(at: raw.utf16.count - 1)
            let tail = layout.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container)
            #expect(editor.visibleRect.intersects(tail))
            #expect(editor.string == raw && fixture.session.query == raw)
            try snapshot(fixture.window, name: "verbatim-\(locale)-\(dark)-\(width)-editing")
            #expect(fixture.window.makeFirstResponder(nil))
            try await SystemPageHost.settle(fixture.window)
            #expect(field.stringValue == raw && field.frame.height == originalHeight)
            let frame = try SettingsButtonTestSupport.frame(field, in: fixture.window)
            #expect(frame.minY >= 0 && frame.maxY <= fixture.window.contentView!.bounds.height)
            try snapshot(fixture.window, name: "verbatim-\(locale)-\(dark)-\(width)-idle")
            _ = try await FormInputTestSupport.editor(field, in: fixture.window)
            #expect(field.currentEditor() === editor && editor.string == raw)
            #expect(fixture.draft.commits == 0)
        }
    }

    private func snapshot(_ window: NSWindow, name: String) throws {
        let view = try #require(window.contentView)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        Attachment.record(Array(png), named: name + ".png")
    }
}
