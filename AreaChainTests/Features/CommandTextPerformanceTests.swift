import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct CommandTextPerformanceTests {
    @Test(arguments: [false, true])
    func inputCompositionConfirmationCheckpointAndUndoCosts(protected: Bool) throws {
        let f = try ProtectedDraftFixture(configured: protected)
        try f.start()
        if protected { _ = try f.service.protect(f.draft().stamp, expecting: f.host.owned().lease) }
        let editor = CommandProtectedTextView(session: f.service)
        let phases = CommandTextPerformancePhases()
        phases.install(in: editor)
        defer { editor.end(); CommandTextTiming.observe = nil }
        try editor.begin(using: protected ? f.restore() : f.service.explicitlyEditOrdinary(f.draft().stamp, expecting: f.host.owned().lease))
        var rows = ["mode,bytes,sample,operation,milliseconds,acceptedRevisions"]
        func measure(_ operation: String, bytes: Int, sample: Int, _ body: () -> Void) {
            phases.begin()
            let before = editor.checkpointCount
            let start = ContinuousClock.now
            body()
            let elapsed = start.duration(to: .now).components
            let milliseconds = Double(elapsed.seconds) * 1_000 + Double(elapsed.attoseconds) / 1e15
            phases.record(mode: protected ? "protected" : "ordinary", bytes: bytes, sample: sample, operation: operation, total: milliseconds)
            #expect(editor.issue == nil)
            rows.append("\(protected ? "protected" : "ordinary"),\(bytes),\(sample),\(operation),\(milliseconds),\(editor.checkpointCount - before)")
        }
        for bytes in [1_024, 65_536, 1_048_576] {
            editor.insertText(String(repeating: "中a🙂", count: bytes / 8),
                              replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
            editor.undoManager?.removeAllActions()
            for sample in 0..<6 {
                measure("input", bytes: bytes, sample: sample) { editor.insertText("字", replacementRange: .init(location: NSNotFound, length: 0)) }
                measure("compositionBegin", bytes: bytes, sample: sample) {
                    editor.setMarkedText("z", selectedRange: .init(location: 1, length: 0), replacementRange: .init(location: NSNotFound, length: 0))
                }
                measure("compositionUpdate", bytes: bytes, sample: sample) {
                    editor.setMarkedText("zhong", selectedRange: .init(location: 5, length: 0), replacementRange: .init(location: NSNotFound, length: 0))
                }
                measure("confirm", bytes: bytes, sample: sample) { editor.insertText("中", replacementRange: editor.markedRange()) }
                measure("selectionCheckpoint", bytes: bytes, sample: sample) { editor.setSelectedRange(.init(location: 0, length: 0)) }
                measure("undo", bytes: bytes, sample: sample) { editor.undoManager?.undo() }
                editor.setSelectedRange(.init(location: editor.string.utf16.count, length: 0))
            }
            #expect(editor.string.utf8.count == bytes + 18)
        }
        try phases.export()
        Attachment.record(Data(rows.joined(separator: "\n").utf8), named: "CM1-input-costs.csv")
    }
}
