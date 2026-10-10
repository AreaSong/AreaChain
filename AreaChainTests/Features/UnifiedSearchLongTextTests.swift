import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchLongTextTests {
    @Test func explicitAssemblyKeepsBodyOutOfQueryAndPreservesOperations() async throws {
        let f = try UnifiedSearchResultsFixture()
        defer { f.stop() }
        _ = try await f.publish()
        try f.startOperation("todo.notes")
        let parameter = try f.parameter(.notes).0
        #expect(!f.controller.supportsLongText(parameter))
        f.controller.assembleLongText(vault: f.vault)
        #expect(f.controller.supportsLongText(parameter))
        f.controller.beginLongText(.notes, source: f.controller.buffer)
        let editing = try #require(f.controller.longTextEditing)
        let editor = CommandProtectedTextView(session: editing.content)
        defer { editor.end() }
        try editing.attach(editor)
        editor.onRevision = { f.controller.longTextAdvanced(editing) }
        editor.insertText("正文 / # ! @\n第二行", replacementRange: NSRange(location: 0, length: 0))
        #expect(try f.draft.arguments.first?.value == .longText("正文 / # ! @\n第二行"))
        #expect(!f.controller.buffer.text.contains("正文"))
        #expect(f.controller.parameterText.isEmpty)
        let before = try f.handoff.owned()
        f.controller.requestOperationSubmit(f.controller.buffer)
        #expect(try f.handoff.owned() == before)
        try editor.changeOperation(.append)
        #expect(editor.access == nil)
        try editor.begin(using: editing.content.explicitlyEditOrdinary(f.draft.stamp, expecting: f.handoff.owned().lease))
        editor.insertText("追加", replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        #expect(try f.draft.arguments.first?.operation == .append)
        #expect(try f.draft.arguments.first?.value == .longText("追加"))
        try editor.changeOperation(.clear)
        #expect(!editor.isEditable)
        #expect(try f.draft.arguments.first?.operation == .clear && f.draft.arguments.first?.value == nil)
        #expect(try f.handoff.state().execution == nil)
    }

    @Test func twoContentServicesCannotAttachOwnersForSameField() throws {
        let f = try ProtectedDraftFixture(configured: false)
        try f.start()
        let other = CommandDraftContentSession(coordinator: f.host.coordinator, vault: f.vault)
        let first = CommandProtectedTextView(session: f.service)
        let second = CommandProtectedTextView(session: other)
        defer { first.end(); second.end() }
        let stamp = try f.draft().stamp
        let lease = try f.host.owned().lease
        try first.begin(using: f.service.explicitlyEditOrdinary(stamp, expecting: lease))
        #expect(throws: (any Error).self) { try second.begin(using: other.explicitlyEditOrdinary(stamp, expecting: lease)) }
        first.insertText("唯一", replacementRange: NSRange(location: 0, length: first.string.utf16.count))
        #expect(first.string == "唯一")
    }

    @Test func bodyPlanOwnerSurvivesCollapseAndRejectsOldEvents() async throws {
        let f = try UnifiedSearchResultsFixture()
        defer { f.stop() }
        _ = try await f.publish()
        f.controller.assembleLongText(vault: f.vault)
        try f.startOperation("diary.body")
        #expect(f.controller.enqueue(try f.draft.stamp, source: f.controller.buffer))
        let item = try #require(f.controller.plan?.items.first)
        f.controller.beginPlanEditing(item.stamp, source: f.controller.buffer)
        f.controller.beginLongText(.body, source: f.controller.buffer)
        let editing = try #require(f.controller.longTextEditing)
        let editor = CommandProtectedTextView(session: editing.content, parameter: .body)
        try editing.attach(editor)
        editor.onRevision = { f.controller.longTextAdvanced(editing) }
        editor.insertText("计划长文", replacementRange: NSRange(location: 0, length: 0))
        let old = try #require(editor.access)
        f.controller.endLongText()
        #expect(editor.string.isEmpty && editor.access == nil)
        f.controller.beginLongText(.body, source: f.controller.buffer)
        let resumed = try #require(f.controller.longTextEditing)
        let current = CommandProtectedTextView(session: resumed.content, parameter: .body)
        defer { current.end() }
        try resumed.attach(current)
        #expect(current.string == "计划长文")
        editor.synchronize("旧正文", selection: NSRange(location: 0, length: 0), expecting: old)
        editor.end()
        #expect(current.string == "计划长文" && current.access != nil)
        #expect(f.controller.operations?.active == nil)
        #expect(f.controller.plan?.items.first?.draft.arguments.first?.value == .longText("计划长文"))
        #expect(throws: (any Error).self) { try f.handoff.seal() }
    }

    @Test(.serialized, arguments: [false, true])
    func nativeParameterLayoutsAndCollapse(dark: Bool) async throws {
        let f = try UnifiedSearchResultsFixture()
        defer { f.stop() }
        _ = try await f.publish()
        f.controller.assembleLongText(vault: f.vault)
        try f.startOperation("todo.notes")
        let host = UnifiedSearchTestHost(layout: dark ? .compact : .standard, width: dark ? 480 : 740,
            locale: dark ? "zh-Hans" : "en", dark: dark, results: f.controller, operations: true)
        defer { host.close() }
        try await host.start()
        try await host.clickResult("unified.longText.open.notes")
        try await host.settle()
        let editor = try #require(f.controller.longTextEditing?.editor)
        try await SettingsButtonTestSupport.reveal(editor, in: host.window)
        try #require(host.window.makeFirstResponder(editor))
        editor.insertText(String(repeating: "合成正文 multilingual 🙂 / # ! @\n", count: 30),
                          replacementRange: NSRange(location: 0, length: 0))
        try await host.settle()
        #expect(editor.window === host.window && editor.enclosingScrollView != nil)
        #expect(editor.bounds.width > 100 && editor.enclosingScrollView!.bounds.height > 100)
        #expect(editor.string.contains("合成正文"))
        #expect(editor.frame.height > editor.enclosingScrollView!.contentSize.height)
        let originalLength = editor.string.utf16.count
        editor.insertText("追加", replacementRange: .init(location: editor.string.utf16.count, length: 0))
        try await host.key(6, "z", flags: .command)
        #expect(editor.string.utf16.count == originalLength)
        try await host.key(6, "z", flags: [.command, .shift])
        #expect(editor.string.utf16.count == originalLength + 2)
        try host.snapshot(dark ? "CM1-zh-dark-compact" : "CM1-en-light-standard")
        let count = editor.string.utf16.count
        let source = f.controller.buffer
        f.controller.operationExpanded = false
        f.controller.endLongText()
        try await host.settle()
        #expect(editor.string.isEmpty)
        #expect(f.controller.buffer == source)
        if case .longText(let body) = try f.draft.arguments.first?.value { #expect(body.utf16.count == count) }
        else { Issue.record("原参数未保留正文") }
    }
}
