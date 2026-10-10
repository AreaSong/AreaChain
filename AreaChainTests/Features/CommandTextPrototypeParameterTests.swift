#if AREACHAIN_QA
import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct CommandTextPrototypeParameterTests {
    @Test(arguments: CommandTextPrototype.allCases)
    func actualPlanBodyParameterRetainsOwnerAndProtectedRecovery(engine: CommandTextPrototype) async throws {
        let synthetic = try ProtectedDraftFixture()
        let f = try UnifiedSearchResultsFixture(testVault: synthetic.vault)
        defer { f.stop() }
        _ = try await f.publish()
        f.controller.assembleLongText(vault: synthetic.vault)
        try f.startOperation("diary.body")
        try #require(f.controller.enqueue(f.draft.stamp, source: f.controller.buffer))
        let item = try #require(f.controller.plan?.items.first)
        f.controller.beginPlanEditing(item.stamp, source: f.controller.buffer)
        let root = UnifiedSearchOperationTestContent(controller: f.controller, layout: .compact)
            .environment(\.commandTextPrototype, engine)
            .environment(\.locale, Locale(identifier: "zh-Hans"))
            .preferredColorScheme(.dark)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 960),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: root)
        defer { f.controller.endLongText(); SystemPageHost.release(window); window.close() }
        try await CommandTextPrototypeHost.show(window)
        f.controller.beginLongText(.body, source: f.controller.buffer)
        try await SystemPageHost.settle(window)
        let first = try #require(f.controller.longTextEditing?.editor)
        try await SettingsButtonTestSupport.reveal(first, in: window)
        try #require(window.makeFirstResponder(first))
        first.insertText("计划正文🙂e\u{301}\n第二行", replacementRange: .init(location: 0, length: 0))
        let original = first.string
        let old = try #require(first.access)
        f.controller.protectLongText(source: f.controller.buffer)
        try #require(f.controller.editingDraft?.protectedReference != nil)
        try #require(first.string.isEmpty && first.access == nil)
        try await SystemPageHost.settle(window)
        f.controller.beginLongText(.body, source: f.controller.buffer)
        try await SystemPageHost.settle(window)
        let restored = try #require(f.controller.longTextEditing?.editor)
        try await SettingsButtonTestSupport.reveal(restored, in: window)
        try #require(window.makeFirstResponder(restored))
        try #require(restored.string == original && restored.access?.isProtected == true)
        first.synchronize("旧 owner", selection: .init(location: 0, length: 0), expecting: old)
        first.end()
        try #require(restored.string == original && restored.access != nil)
        restored.setMarkedText("zhong", selectedRange: .init(location: 5, length: 0), replacementRange: .init(location: 0, length: 2))
        _ = try CommandTextPrototypeChecks.anchor(restored, range: restored.markedRange())
        restored.cancelOperation(nil)
        try #require(restored.string == original && f.controller.operations?.active == nil)
        let observation = CommandTextPrototypeObservation(restored, engine: engine)
        try observation.check()
        try CommandTextPrototypeChecks.snapshot(window, name: "CM2-plan-body-\(engine.rawValue)")
        f.controller.endLongText()
        try #require(restored.string.isEmpty && f.controller.plan?.items.first?.draft.protectedReference != nil)
        #expect(throws: (any Error).self) { try f.handoff.seal() }
    }
}
#endif
