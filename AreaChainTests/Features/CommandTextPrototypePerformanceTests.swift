#if AREACHAIN_QA
import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct CommandTextPrototypePerformanceTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["AREACHAIN_CM2_ENGINE"] != nil))
    func boundedComparison() async throws {
        let journal = try CommandTextPrototypeJournal()
        defer { CommandTextTiming.observe = nil }
        let mode = ProcessInfo.processInfo.environment["AREACHAIN_CM2_PROTECTION"]
        try #require(mode == nil || ["ordinary", "protected"].contains(mode!))
        let protections = mode.map { [$0 == "protected"] } ?? [false, true]
        for protected in protections {
            let start = ContinuousClock.now
            try journal.record("hostConstruction.start", values: ["protected": protected])
            let host = try await CommandTextPrototypeHost.make(journal, protected: protected)
            defer { host.close() }
            let editor = host.editor
            let observation = CommandTextPrototypeObservation(editor, engine: journal.engine)
            try observation.check()
            try #require((editor.string as NSString).isEqual(to: journal.body()))
            try #require(host.window.isVisible && host.window.isKeyWindow && host.window.firstResponder === editor)
            try journal.measure("visibleLayout") {
                if let layout = editor.textLayoutManager {
                    layout.ensureLayout(for: editor.visibleRect)
                    layout.textViewportLayoutController.layoutViewport()
                } else if journal.engine == .viewport, let container = editor.textContainer {
                    editor.layoutManager?.ensureLayout(forBoundingRect: editor.visibleRect, in: container)
                }
                host.window.displayIfNeeded()
            }
            try journal.measure("firstInput") { editor.insertText("字", replacementRange: .init(location: 0, length: 0)) }
            try #require(editor.string.hasPrefix("字") && editor.issue == nil)
            let readyMS = CommandTextPrototypeChecks.milliseconds(start)
            var ready: [String: Any] = ["protected": protected, "openToUsableFirstInputMS": readyMS,
                "editorWidth": editor.frame.width, "viewportWidth": editor.enclosingScrollView!.contentSize.width,
                "containerWidth": editor.textContainer!.size.width, "fontSize": editor.font?.pointSize ?? 12,
                "windowWidth": host.window.frame.width, "insetX": editor.textContainerInset.width,
                "readyMeans": "mounted-visible-key-first-input-accepted", "warmDocument": false]
            ready.merge(observation.metadata) { _, value in value }
            if let bounded = editor.enclosingScrollView as? CommandTextPrototypeScrollView {
                ready["attachedWidth"] = bounded.attachedWidth
                ready["widthChanges"] = bounded.widthChanges
                ready["sizeStabilizationMS"] = bounded.sizeStabilizationMS
            }
            try journal.record("ready", values: ready)
            editor.undoManager?.undo()
            try #require((editor.string as NSString).isEqual(to: journal.body()))
            _ = try CommandTextPrototypeChecks.current(editor, service: host.service, vault: host.vault)
            for position in ["start", "middle", "end"] {
                try exercise(host, journal: journal, observation: observation, position: position, protected: protected)
            }
            try observation.check()
            try journal.record("hostFinished", values: ["protected": protected, "totalExperienceMS": CommandTextPrototypeChecks.milliseconds(start)])
        }
    }

    private func exercise(_ host: CommandTextPrototypeHost, journal: CommandTextPrototypeJournal,
                          observation: CommandTextPrototypeObservation, position: String, protected: Bool) throws {
        let editor = host.editor
        let original = journal.body()
        let middle = (original as NSString).rangeOfComposedCharacterSequence(at: original.utf16.count / 2).location
        let location = position == "start" ? 0 : (position == "end" ? original.utf16.count : middle)
        for sample in 0..<2 {
            let values: [String: Any] = ["protected": protected, "position": position, "sample": sample,
                                      "utf16Location": location, "firstAtPosition": sample == 0]
            try journal.measure("selection", values: values) { editor.setSelectedRange(.init(location: location, length: 0)) }
            try journal.measure("scroll", values: values) { editor.scrollRangeToVisible(editor.selectedRange()) }
            try journal.measure("insert", values: values) { editor.insertText("字", replacementRange: editor.selectedRange()) }
            try journal.measure("insertUndo", values: values) { editor.undoManager?.undo() }
            try #require((editor.string as NSString).isEqual(to: original))
            try journal.measure("compositionBegin", values: values) {
                editor.setMarkedText("z", selectedRange: .init(location: 1, length: 0), replacementRange: .init(location: location, length: 0))
            }
            try observation.check()
            var anchor = values
            anchor.merge(try CommandTextPrototypeChecks.anchor(editor, range: editor.markedRange())) { _, value in value }
            try journal.record("candidateAnchor", values: anchor)
            try #require(try CommandTextPrototypeChecks.current(editor, service: host.service, vault: host.vault).confirmedText == original)
            try journal.measure("compositionUpdate", values: values) {
                editor.setMarkedText("zhong", selectedRange: .init(location: 5, length: 0), replacementRange: .init(location: NSNotFound, length: 0))
            }
            try journal.measure("confirm", values: values) { editor.insertText("中", replacementRange: editor.markedRange()) }
            let confirmed = editor.string
            _ = try CommandTextPrototypeChecks.current(editor, service: host.service, vault: host.vault)
            try journal.measure("undo", values: values) { editor.undoManager?.undo() }
            try #require((editor.string as NSString).isEqual(to: original))
            try journal.measure("redo", values: values) { editor.undoManager?.redo() }
            try #require((editor.string as NSString).isEqual(to: confirmed))
            editor.undoManager?.undo()
            editor.setMarkedText("取消🙂", selectedRange: .init(location: 4, length: 0), replacementRange: .init(location: location, length: 0))
            try journal.measure("cancel", values: values) { editor.cancelOperation(nil) }
            try #require((editor.string as NSString).isEqual(to: original) && !editor.hasMarkedText())
            _ = try CommandTextPrototypeChecks.current(editor, service: host.service, vault: host.vault)
            try observation.check()
            if sample == 0 && position == "end" {
                try CommandTextPrototypeChecks.snapshot(host.window, name: "CM2-\(journal.engine.rawValue)-\(journal.host)-\(journal.bytes)-\(protected)")
            }
            editor.undoManager?.removeAllActions()
        }
    }
}
#endif
