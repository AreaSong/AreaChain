import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchBatchStateBoundaryTests {
    @Test func overLimitKeepsWholeSelectionAndRemovalRequiresNewAcceptance() async throws {
        let state = try BatchStateFixture(enabled: false)
        let start = DayKey.shifted(state.base.today, by: -3999, calendar: RoutineQueryFixture.dates.calendar)
        state.base.routine.createdDayKey = start; state.base.routine.pausedOnDayKey = start
        try state.context.save()
        let f = try UnifiedSearchBatchFixture(state: state, definitionsOnly: true)
        defer { f.results.stop() }
        let host = try await f.host(3)
        defer { host.close() }
        try await f.command("/tasks/batch/enabled", host: host)
        try await f.select(state.definitionTargets, host: host)
        try await f.setState(true, host: host)
        try await host.clickCompositionControl("unified.batch.prepare")
        let preview = try #require(f.controller.currentBatchPreview)
        #expect(preview.writeSet?.counts.total == 4004 && f.controller.currentBatchAcceptance == nil)
        try await host.revealSettingControlInsidePanel("unified.batch.overLimit")
        try host.snapshot("bm2-over-limit-counts")
        f.controller.acceptBatch(preview, source: f.controller.buffer)
        #expect(f.controller.batchFailure == "unified.batch.writeLimit" && f.controller.currentBatchAcceptance == nil)
        #expect(Set(f.controller.plan?.items.first?.draft.targets.objects ?? []) == Set(state.definitionTargets))
        try await f.revealStateTarget(state.definitionTargets[0], host: host)
        try await host.clickCompositionControl("unified.batch.remove." + state.definitionTargets[0].searchIdentifier)
        await f.controller.objectSelectionTask?.value
        let accepted = try await f.prepare(host, name: "limit-reduced")
        #expect(accepted.preview.targets.objects == [state.definitionTargets[1]] && accepted.preview.writeSet?.counts.total == 4)
        #expect(try await f.submit(host, name: "limit-reduced", chord: false).state == .saved)
        #expect(!state.base.routine.isEnabled && state.second.isEnabled && state.base.routine.checks.isEmpty)
    }

    @Test(arguments: [false, true]) func noChangeOrConflictRetainsStateFacts(conflict: Bool) async throws {
        let state = try BatchStateFixture()
        state.base.todos[0].isDone = !conflict
        try state.context.save()
        let f = try UnifiedSearchBatchFixture(state: state)
        defer { f.results.stop() }
        try f.results.startOperation("batch.completion")
        try await f.results.acceptObjects([state.base.taskTargets[0]])
        _ = f.controller.editParameter(.init(parameter: .enabled, operation: .assign, value: .boolean(true)), source: f.controller.buffer)
        await f.controller.objectSelectionTask?.value
        let host = try await f.host(conflict ? 2 : 0)
        defer { host.close() }
        let accepted = try await f.prepare(host, name: conflict ? "conflict" : "noChange")
        if conflict { state.child.isDone = true; try state.context.save() }
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        try await host.key(36, "\r", flags: .command)
        if conflict {
            #expect(f.controller.settingExecution == nil && f.controller.batchProblems.map(\.target) == [state.base.taskTargets[0]])
            #expect(f.controller.plan?.items.first?.draft.targets == accepted.preview.targets)
            try await host.revealSettingControlInsidePanel("unified.batch.problem." + state.base.taskTargets[0].searchIdentifier)
        } else {
            #expect(f.controller.batchUnit?.batch?.state == .noChange && !state.child.isDone)
            try await host.revealSettingControlInsidePanel("unified.batch.status")
        }
        #expect(f.service.count("save") == 0 && f.service.count("ui") == 0)
        try host.snapshot(conflict ? "bm2-conflict-reason" : "bm2-noChange")
    }

    @Test(arguments: [0, 1, 2]) func markedTextFocusAndLockRejectOldSubmission(kind: Int) async throws {
        let state = try BatchStateFixture()
        let f = try UnifiedSearchBatchFixture(state: state)
        defer { f.results.stop() }
        try f.results.startOperation("batch.completion")
        try await f.results.acceptObjects([state.base.taskTargets[0]])
        _ = f.controller.editParameter(.init(parameter: .enabled, operation: .assign, value: .boolean(true)), source: f.controller.buffer)
        await f.controller.objectSelectionTask?.value
        let host = try await f.host(3)
        defer { host.close() }
        let accepted = try await f.prepare(host, name: "gate-\(kind)")
        let source = f.controller.buffer
        if kind == 0 {
            host.window.makeFirstResponder(try host.field)
            try await host.settle()
            let editor = try host.editor
            editor.setMarkedText("组合", selectedRange: .init(location: 2, length: 0), replacementRange: editor.selectedRange())
            f.controller.requestOperationSubmit(source)
            try await host.key(36, "\r", flags: .command)
            editor.unmarkText()
        } else if kind == 1 {
            let other = NSWindow(contentRect: .init(x: 20, y: 20, width: 100, height: 100), styleMask: [.titled], backing: .buffered, defer: false)
            other.isReleasedWhenClosed = false; other.makeKeyAndOrderFront(nil)
            try await SystemPageHost.settle(other)
            f.controller.requestOperationSubmit(source)
            SystemPageHost.release(other)
        } else {
            f.privacy.post(name: .privacyWillLock, object: f.results.vault)
            f.controller.requestOperationSubmit(source)
        }
        #expect(f.controller.settingExecution == nil && f.service.count("save") == 0)
        #expect(f.controller.plan?.items.first?.draft.targets == accepted.preview.targets)
        if kind != 0 { #expect(f.controller.currentBatchAcceptance == nil) }
    }

    @Test func unknownAndDateEditKeepStableExplicitIdentities() async throws {
        let state = try BatchStateFixture()
        let f = try UnifiedSearchBatchFixture(state: state)
        defer { f.results.stop() }
        let host = try await f.host(1)
        defer { host.close() }
        try await f.command("/tasks/batch/completion", host: host)
        try await f.select([state.base.taskTargets[0]], host: host)
        try await f.appendOccurrence(state.definitionTargets[0], day: "2026-10-06", host: host)
        try await f.setState(true, host: host)
        let accepted = try await f.prepare(host, name: "date-before")
        try await host.clickCompositionControl("unified.plan.edit." + accepted.preview.item.id.uuidString)
        let object = state.occurrence(state.base.routine, "2026-10-06")
        try await host.clickCompositionControl("unified.routineState.chooseDay." + object.searchIdentifier)
        try await host.revealTaskDatePicker()
        try await host.clickCompositionControl("daybook.date.2026-10-07")
        await f.controller.objectSelectionTask?.value
        #expect(f.controller.currentBatchAcceptance == nil)
        let item = try #require(f.controller.editingPlanItem)
        f.controller.endPlanEditing(item.stamp, source: f.controller.buffer)
        await f.controller.objectSelectionTask?.value
        let revised = try await f.prepare(host, name: "date-after")
        #expect(revised.preview.targets.objects.last?.dayKey == "2026-10-07")
        f.service.saveMode = .throwAfter
        let facts = try await f.submit(host, name: "unknown", chord: true)
        #expect(facts.state == .unknown && facts.checkCreationIDs == revised.checkCreationIDs && f.service.count("save") == 1)
    }
}
