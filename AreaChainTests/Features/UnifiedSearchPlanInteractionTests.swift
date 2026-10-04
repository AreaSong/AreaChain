import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchPlanInteractionTests {
    @Test func nativeCompletionEnqueueEditObjectsCollapseRemoveAndRestore() async throws {
        let fixture = try UnifiedSearchResultsFixture(.objectBatch())
        defer { fixture.stop() }
        let host = UnifiedSearchTestHost(results: fixture.controller, operations: true)
        defer { host.close() }
        try await host.start()
        let editor = try host.editor
        editor.insertText("/tasks/title", replacementRange: .init(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        try await host.key(48, "\t")
        try await host.settle()
        if fixture.controller.operations?.active == nil { try await host.key(36, "\r") }
        #expect(try fixture.draft.commandID.rawValue == "todo.title")
        try await host.clickResult("unified.plan.enqueue")
        let item = try #require(fixture.controller.plan?.items.first)
        #expect(fixture.controller.operations?.active == nil)
        try await host.clickResult("unified.plan.edit." + item.id.uuidString)
        let title = try await host.focusParameter(.title)
        title.insertText("Native synthetic title", replacementRange: title.selectedRange())
        try await host.settle()
        try await host.clickResult("unified.objects.choose.target")
        await fixture.controller.objectSelectionTask?.value
        try await host.settle()
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        try await host.key(125, "\u{F701}")
        try await host.key(36, "\r")
        await fixture.controller.objectSelectionTask?.value
        try await host.settle()
        #expect(try fixture.planItem(item.id).draft.targets.objects == [.object(0)])
        try host.snapshot("plan-native-object-edit")
        let before = try fixture.planItem(item.id).draft
        try await host.clickResult("unified.plan.close")
        #expect(fixture.controller.plan?.editing == nil)
        #expect(try fixture.planItem(item.id).draft == before)
        let edit = try host.resultNode("unified.plan.edit." + item.id.uuidString)
        #expect(try Self.focused(edit))
        try await Self.space(host)
        #expect(fixture.controller.plan?.editing == item.id)
        try await host.clickResult("unified.plan.close")
        try await host.key(48, "\t")
        #expect(try host.field.convert(host.field.bounds, to: nil).minY > 0)
        try await host.clickResult("unified.plan.remove." + item.id.uuidString)
        #expect(fixture.controller.plan?.items.isEmpty == true)
        #expect(fixture.controller.operations?.retained.first?.id == before.id)
        try await host.clickResult("unified.operation.restore.todo.title")
        #expect(try fixture.draft.id == before.id && fixture.draft.arguments == before.arguments)
        try host.snapshot("plan-native-restored")
    }

    @Test func nativeMergePreviewRequiresExplicitAccept() async throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        fixture.controller.syntheticBaselines[.init(rawValue: "setting.language")] = .init([
            .init(subject: .ambient, parameter: .value): .uniform(.choice("system"))])
        _ = try fixture.enqueueOperation("setting.language", arguments: [PlanFixture.argument(.value, .choice("chinese"))])
        let second = try fixture.enqueueOperation("setting.language", arguments: [PlanFixture.argument(.value, .choice("english"))])
        let host = UnifiedSearchTestHost(locale: "zh-Hans", results: fixture.controller, operations: true)
        defer { host.close() }
        try await host.start()
        try await host.clickResult("unified.plan.merge." + second.id.uuidString)
        #expect(fixture.controller.plan?.items.count == 2)
        try await SettingsButtonTestSupport.reveal(try host.resultNode("unified.plan.merge.accept"), in: host.window)
        try host.snapshot("plan-merge-review")
        try await host.clickResult("unified.plan.merge.accept")
        #expect(fixture.controller.plan?.items.count == 1)
    }

    static func focused(_ node: NSObject) throws -> Bool {
        let getter = NSSelectorFromString("isAccessibilityFocused")
        try #require(node.responds(to: getter))
        let read = unsafeBitCast(node.method(for: getter), to: (@convention(c) (AnyObject, Selector) -> Bool).self)
        return read(node, getter)
    }

    static func space(_ host: UnifiedSearchTestHost) async throws {
        try await host.key(49, " ")
        let up = try #require(NSEvent.keyEvent(with: .keyUp, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: host.window.windowNumber,
            context: nil, characters: " ", charactersIgnoringModifiers: " ", isARepeat: false, keyCode: 49))
        NSApp.sendEvent(up)
        try await host.settle()
    }

    @Test func keyboardReorderAndDependentRejectionKeepOriginalOrder() async throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        let first = try fixture.enqueueOperation("setting.language")
        let second = try fixture.enqueueOperation("setting.appearance")
        let host = UnifiedSearchTestHost(results: fixture.controller, operations: true)
        defer { host.close() }
        try await host.start()
        try await host.clickResult("unified.plan.edit." + first.id.uuidString)
        try await host.clickResult("unified.plan.close")
        let down = try host.resultNode("unified.plan.down." + first.id.uuidString)
        for _ in 0..<8 {
            if try Self.focused(down) { break }
            try await host.key(48, "\t")
        }
        try #require(try Self.focused(down))
        try await Self.space(host)
        #expect(fixture.controller.plan?.items.map(\.id) == [second.id, first.id])
        try await host.clickResult("unified.plan.edit." + first.id.uuidString)
        try await host.clickResult("unified.plan.close")
        let up = try host.resultNode("unified.plan.up." + first.id.uuidString)
        for _ in 0..<8 {
            if try Self.focused(up) { break }
            try await host.key(48, "\t")
        }
        try #require(try Self.focused(up))
        try await Self.space(host)
        #expect(fixture.controller.plan?.items.map(\.id) == [first.id, second.id])
        #expect(fixture.controller.sendPlan(.link(second.stamp, .init(predecessors: [first.id])), source: fixture.controller.buffer))
        try await host.settle()
        try await host.clickResult("unified.plan.down." + first.id.uuidString)
        #expect(fixture.controller.plan?.items.map(\.id) == [first.id, second.id])
        #expect(fixture.controller.planMessage == "unified.plan.graph")
        _ = try host.resultNode("unified.plan.message")
        try host.snapshot("plan-order-rejected")
    }
}
