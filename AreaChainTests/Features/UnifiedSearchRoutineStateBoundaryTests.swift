import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchRoutineStateBoundaryTests {
    @Test(arguments: [0, 1, 2]) func staleNoChangeAndUnknownRetainOriginalRun(kind: Int) async throws {
        let f = try UnifiedSearchRoutineFixture(stateOperations: true, occurrenceDay: "2026-10-07")
        defer { f.results.stop() }
        if kind == 1 {
            f.service.context.insert(RoutineCheck(dayKey: "2026-10-07", isDone: true, routine: f.service.routine))
            try f.service.context.save()
        }
        try await f.start("occurrence.complete", arguments: [])
        let host = try await f.host(kind == 0 ? 3 : 0)
        defer { host.close() }
        let accepted = try await f.prepare(host, name: "boundary-\(kind)")
        if kind == 0 {
            f.service.context.insert(RoutineCheck(dayKey: "2026-10-07", routine: f.service.routine))
            try f.service.context.save()
        }
        if kind == 2 { f.service.saveMode = .throwAfter }
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        try await host.key(36, "\r", flags: .command)
        if kind == 0 {
            #expect(f.controller.settingExecution == nil && f.controller.routineAcceptance == nil)
            #expect(f.controller.plan?.items.first?.draft.targets.objects == [accepted.object])
        } else {
            #expect(f.controller.routineUnit?.routine?.state == (kind == 1 ? .noChange : .unknown))
            #expect(f.controller.routineUnit?.routine?.checkCreationIDs == accepted.checkCreationIDs)
        }
        f.controller.requestOperationSubmit(f.controller.buffer)
        #expect(f.service.count("save") == (kind == 2 ? 1 : 0))
        try await host.revealSettingControlInsidePanel(kind == 0 ? "unified.routine.issue" : "unified.routine.status")
        try host.snapshot("rm3-boundary-\(kind)-result")
    }

    @Test func nativeDateControlChangesOnlyOccurrenceIdentityAndRevokesAcceptance() async throws {
        let f = try UnifiedSearchRoutineFixture(stateOperations: true, occurrenceDay: "2026-10-07")
        defer { f.results.stop() }
        try await f.start("occurrence.complete", arguments: [])
        let host = try await f.host(3)
        defer { host.close() }
        let accepted = try await f.prepare(host, name: "date-edit")
        try await host.clickCompositionControl("unified.plan.edit." + accepted.preview.item.id.uuidString)
        try await host.clickCompositionControl("unified.routineState.chooseDay")
        try await host.revealTaskDatePicker()
        let day = try DatePickerTestSupport.day("2026-10-08", in: host.window)
        try await SettingsButtonTestSupport.click(day, in: host.window)
        try await host.settle()
        #expect(f.controller.editingDraft?.targets.objects == [.init(type: .routineOccurrence, id: f.service.routine.id, dayKey: "2026-10-08")])
        #expect(f.controller.currentRoutineAcceptance == nil && f.service.count("save") == 0)
        try host.snapshot("rm3-date-changed")
    }
    @Test(arguments: [false, true]) func markedTextBlurAndLockDoNotCommit(locked: Bool) async throws {
        let f = try UnifiedSearchRoutineFixture(enabled: false, stateOperations: true)
        defer { f.results.stop() }
        try await f.start("routine.enabled", arguments: [.init(parameter: .enabled, operation: .assign, value: .boolean(true))])
        let host = try await f.host()
        defer { host.close() }
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        let editor = try host.editor
        editor.setMarkedText("组合", selectedRange: .init(location: 2, length: 0), replacementRange: editor.selectedRange())
        f.controller.prepareRoutine(f.controller.buffer)
        try await host.key(36, "\r", flags: .command)
        #expect(f.controller.routinePreview == nil && f.service.count("save") == 0)
        editor.unmarkText()
        try await host.key(48, "\t")
        let accepted = try await f.prepare(host, name: locked ? "state-lock" : "state-blur")
        let old = f.controller.buffer
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        let input = try host.editor
        input.setMarkedText("组合", selectedRange: .init(location: 2, length: 0), replacementRange: input.selectedRange())
        f.controller.requestOperationSubmit(f.controller.buffer)
        try await host.key(36, "\r", flags: .command)
        #expect(f.service.count("save") == 0 && f.controller.settingExecution == nil)
        input.unmarkText()
        if locked { f.privacy.post(name: .privacyWillLock, object: f.results.vault) }
        else {
            let other = NSWindow(contentRect: .init(x: 20, y: 20, width: 100, height: 100),
                                 styleMask: [.titled], backing: .buffered, defer: false)
            other.isReleasedWhenClosed = false
            other.makeKeyAndOrderFront(nil)
            try await SystemPageHost.settle(other)
            SystemPageHost.release(other)
        }
        #expect(f.controller.routineAcceptance == nil)
        f.controller.acceptRoutine(accepted.preview, source: old)
        f.controller.requestOperationSubmit(old)
        #expect(f.service.count("save") == 0 && !f.service.routine.isEnabled)
        #expect(f.controller.plan?.items.first?.draft.arguments == accepted.preview.arguments)
    }

}
