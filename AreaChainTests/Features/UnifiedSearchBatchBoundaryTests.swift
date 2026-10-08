import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchBatchBoundaryTests {
    @Test(arguments: [false, true]) func noChangeAndConflictKeepWholeSet(conflict: Bool) async throws {
        let f = try UnifiedSearchBatchFixture(count: conflict ? 3 : 1)
        defer { f.results.stop() }
        try f.results.startOperation("batch.move")
        try await f.results.acceptObjects(f.service.taskTargets)
        _ = f.controller.editParameter(f.service.move, source: f.controller.buffer)
        await f.controller.objectSelectionTask?.value
        let host = try await f.host(conflict ? 2 : 0)
        defer { host.close() }
        let accepted = try await f.prepare(host, name: conflict ? "conflict" : "noChange")
        if conflict { f.service.todos[1].dayKey = "2026-10-10"; try f.service.context.save() }
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        try await host.key(36, "\r", flags: .command)
        if conflict {
            #expect(f.controller.settingExecution == nil && f.controller.batchFailure == "unified.batch.targetsChanged")
            #expect(f.controller.batchProblems.map(\.target) == [f.service.taskTargets[1]])
            #expect(f.controller.plan?.items.first?.draft.targets == accepted.preview.targets)
            #expect(f.controller.plan?.items.first?.draft.arguments == accepted.preview.arguments)
        } else { #expect(f.controller.batchUnit?.batch?.state == .noChange) }
        #expect(f.service.count("save") == 0 && f.service.count("ui") == 0)
        try await host.revealSettingControlInsidePanel(conflict ? "unified.batch.issue" : "unified.batch.status")
        try host.snapshot(conflict ? "bm1-conflict-retained" : "bm1-noChange-result")
        if conflict {
            let identifier = "unified.batch.problem." + f.service.taskTargets[1].searchIdentifier
            try await host.revealSettingControlInsidePanel(identifier)
            try SettingsButtonTestSupport.assertBounds([host.resultNode(identifier)], in: host.window)
            try host.snapshot("bm1-conflict-target-reason")
        }
    }

    @Test func markedTextNeverSubmits() async throws {
        let f = try UnifiedSearchBatchFixture()
        defer { f.results.stop() }
        try f.results.startOperation("batch.move")
        try await f.results.acceptObjects(f.service.taskTargets)
        _ = f.controller.editParameter(f.service.move, source: f.controller.buffer)
        await f.controller.objectSelectionTask?.value
        let host = try await f.host()
        defer { host.close() }
        _ = try await f.prepare(host, name: "marked")
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        let editor = try host.editor
        editor.setMarkedText("组合", selectedRange: .init(location: 2, length: 0), replacementRange: editor.selectedRange())
        f.controller.requestOperationSubmit(f.controller.buffer)
        try await host.key(36, "\r", flags: .command)
        #expect(f.controller.settingExecution == nil && f.service.count("save") == 0)
        editor.unmarkText()
    }

    @Test(arguments: [false, true]) func focusAndLockRevokeAcceptance(locked: Bool) async throws {
        let f = try UnifiedSearchBatchFixture()
        defer { f.results.stop() }
        try f.results.startOperation("batch.move")
        try await f.results.acceptObjects(f.service.taskTargets)
        _ = f.controller.editParameter(f.service.move, source: f.controller.buffer)
        await f.controller.objectSelectionTask?.value
        let host = try await f.host(3)
        defer { host.close() }
        let accepted = try await f.prepare(host, name: locked ? "lock" : "focus")
        let old = f.controller.buffer
        if locked { f.privacy.post(name: .privacyWillLock, object: f.results.vault) }
        else {
            let other = NSWindow(contentRect: .init(x: 20, y: 20, width: 100, height: 100),
                                 styleMask: [.titled], backing: .buffered, defer: false)
            other.isReleasedWhenClosed = false
            other.makeKeyAndOrderFront(nil)
            try await SystemPageHost.settle(other)
            SystemPageHost.release(other)
        }
        f.controller.requestOperationSubmit(old)
        #expect(f.controller.currentBatchAcceptance == nil && f.service.count("save") == 0)
        #expect(f.controller.plan?.items.first?.draft.targets == accepted.preview.targets)
    }

    @Test func unknownRetainsTargetsAndDisablesOrdinaryReplay() async throws {
        let f = try UnifiedSearchBatchFixture()
        defer { f.results.stop() }
        try f.results.startOperation("batch.move")
        try await f.results.acceptObjects(f.service.taskTargets)
        _ = f.controller.editParameter(f.service.move, source: f.controller.buffer)
        await f.controller.objectSelectionTask?.value
        let host = try await f.host(1)
        defer { host.close() }
        let accepted = try await f.prepare(host, name: "unknown")
        f.service.saveMode = .throwAfter
        let facts = try await f.submit(host, name: "unknown", chord: false)
        #expect(facts.state == .unknown && facts.impacts == accepted.preview.impacts)
        #expect(f.controller.settingExecution?.snapshot.items.first?.draft.targets == accepted.preview.targets)
        #expect(f.service.count("save") == 1 && f.service.count("ui") == 0)
    }
}
