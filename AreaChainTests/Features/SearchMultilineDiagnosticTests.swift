import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 生产断言要求恢复正确查询；旧故障只保存在明确的冻结对照中。
@Suite(.serialized) @MainActor
struct SearchMultilineDiagnosticTests {
    @Test func frozenOriginalUndoTrace() {
        // I 诊断包 keyboard.xcresult 的历史片段；不是要求新实现再产生残留。
        let restoredIntermediate = "甲\n乙"
        let rewrittenIntermediate = "甲 // 乙"
        let remaining = (rewrittenIntermediate as NSString).substring(from: restoredIntermediate.utf16.count)
        #expect(DaybookTextField.sanitizeSingleLineText(restoredIntermediate) == rewrittenIntermediate)
        #expect(remaining == "/ 乙")
        #expect("x" + remaining == "x/ 乙")
    }

    @Test func workspaceNativeBaseline() async throws {
        let fixture = try SettingsButtonTestSupport(isolatedPreferences: true)
        defer { fixture.cleanup() }
        let navigation = WorkspaceNavigation(boardSelection: BoardSelection())
        let window = fixture.window(WorkspaceHeaderSearchCapsule(navigation: navigation, tagNames: ["工作"]),
                                    size: NSSize(width: 600, height: 300))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        let field = try #require(FormInputTestSupport.fields(in: window).first)
        let editor = try await FormInputTestSupport.editor(field, in: window)
        let trace = try SearchMultilineTrace(field)
        defer { trace.restore() }
        trace.record("before.insertText")
        editor.insertText("甲\n乙", replacementRange: NSRange(location: 0, length: 0))
        trace.record("after.insertText")
        try await SystemPageHost.settle(window)
        trace.record("settled")
        #expect(navigation.searchQuery == "甲 乙")
        #expect(editor.string == navigation.searchQuery)
        #expect(field.stringValue == navigation.searchQuery)
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
            fixture.assertResults(space: true, slash: kind == .workspace || kind == .menu || kind == .diary || kind == .clipboard)
            #expect(fixture.draft.commits == 0 && fixture.draft.tokenRemovals == 0)
        }
    }
}
