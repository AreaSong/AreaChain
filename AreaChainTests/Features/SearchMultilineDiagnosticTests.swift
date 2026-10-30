import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 生产断言要求恢复正确查询；旧故障只保存在明确的冻结对照中。
@Suite(.serialized) @MainActor
struct SearchMultilineDiagnosticTests {
    @Test func frozenOriginalUndoTrace() {
        // 诊断包 keyboard.xcresult 里的片段；不是要求新实现再产生残留。
        let restoredIntermediate = "甲\n乙"
        let rewrittenIntermediate = "甲 // 乙"
        let remaining = (rewrittenIntermediate as NSString).substring(from: restoredIntermediate.utf16.count)
        #expect(DaybookTextField.sanitizeSingleLineText(restoredIntermediate) == rewrittenIntermediate)
        #expect(remaining == "/ 乙")
        #expect("x" + remaining == "x/ 乙")
    }

    @Test(arguments: SearchMultilineConsumer.searches)
    func productionImports(kind: SearchMultilineConsumer) async throws {
        let fixture = try SearchMultilineFixture(kind)
        defer { fixture.cleanup() }
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        let trace = try SearchMultilineTrace(field)
        defer { trace.restore() }
        for pasteboard in [false, true] {
            trace.reset()
            editor.setSelectedRange(NSRange(location: 0, length: (editor.string as NSString).length))
            trace.record("\(kind).before.\(pasteboard ? "namedPasteboard" : "insertText")")
            if pasteboard {
                let board = NSPasteboard(name: NSPasteboard.Name("areachain.search-multiline.\(UUID())"))
                defer { board.releaseGlobally() }
                board.declareTypes([.string], owner: nil)
                #expect(board.setString("甲\n乙", forType: .string))
                #expect(editor.readSelection(from: board, type: .string))
            } else {
                editor.insertText("甲\n乙", replacementRange: editor.selectedRange())
            }
            trace.record("\(kind).afterImport")
            try await SystemPageHost.settle(fixture.window)
            trace.record("\(kind).settled")
            #expect(trace.coordinator.parent.text == "甲 乙")
            #expect(field.stringValue == "甲 乙")
            #expect(editor.string == "甲 乙")
            fixture.assertResults(space: true, slash: kind == .diary || kind == .clipboard)
            #expect(fixture.draft.commits == 0)
        }
    }
}
