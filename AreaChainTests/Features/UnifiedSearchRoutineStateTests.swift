import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchRoutineStateTests {
    @Test(arguments: [false, true]) func nativePauseAndResumeShowExactBackfill(resume: Bool) async throws {
        let f = try UnifiedSearchRoutineFixture(enabled: !resume, stateOperations: true)
        defer { f.results.stop() }
        let host = try await f.host(resume ? 3 : 0)
        defer { host.close() }
        try await f.selectCommand("/routines/enabled", host: host)
        for _ in 0..<(resume ? 1 : 2) {
            let picker = try await host.compositionPicker("unified.parameter.boolean.enabled")
            try await PickerNativeTestSupport.keyboardSelection(picker, moveDown: true, in: host.window)
        }
        #expect(f.controller.editingDraft?.arguments.first?.value == .boolean(resume))
        let accepted = try await f.prepare(host, name: resume ? "resume" : "pause")
        let impact = try #require(accepted.preview.stateImpact)
        if resume {
            #expect(impact.span == 7 && impact.inserted == 3 && impact.modified == 1)
            try await host.revealSettingControlInsidePanel("unified.routineState.counts")
            try host.snapshot("rm3-resume-counts")
            try await host.revealSettingControlInsidePanel("unified.routineState.details")
            try host.snapshot("rm3-resume-details")
            try await f.scrollStateDetails(host, lastDay: "2026-10-07")
        } else { #expect(impact.effects.isEmpty && impact.finalPause == "2026-10-08") }
        let facts = try await f.submit(host, name: resume ? "resume" : "pause", chord: resume)
        #expect(facts.stateImpact == impact && f.service.routine.isEnabled == resume)
        #expect(f.service.routine.pausedOnDayKey == (resume ? nil : "2026-10-08"))
        if resume {
            for (day, id) in accepted.checkCreationIDs {
                let row = try #require(f.service.routine.checks.first { $0.id == id })
                #expect(row.dayKey == day && row.isDone && row.isSkipped && row.routine === f.service.routine)
            }
        }
    }

    @Test(arguments: ["complete", "skip", "reopen"]) func selectedPastDateAndExplicitStates(action: String) async throws {
        let f = try UnifiedSearchRoutineFixture(stateOperations: true, occurrenceDay: "2026-10-07")
        defer { f.results.stop() }
        let row = RoutineCheck(dayKey: "2026-10-07", isDone: action == "reopen", isSkipped: action == "complete", routine: f.service.routine)
        f.service.context.insert(row)
        try f.service.context.save()
        let before = f.service.routine.snapshot, checks = try f.service.checks()
        let host = try await f.host(action == "skip" ? 1 : 2)
        defer { host.close() }
        try await f.selectCommand("/routines/checks/" + action, host: host)
        _ = try host.resultNode("unified.routineState.selectedDay")
        let accepted = try await f.prepare(host, name: action)
        #expect(accepted.object.id == f.service.routine.id && accepted.object.dayKey == "2026-10-07")
        try await host.revealSettingControlInsidePanel("unified.routineState.details")
        try host.snapshot("rm3-" + action + "-raw-effect")
        _ = try await f.submit(host, name: action, chord: action != "skip")
        #expect(row.isDone == (action != "reopen") && row.isSkipped == (action == "skip"))
        #expect(f.service.routine.snapshot == before)
        #expect(try f.service.checks().filter { $0.id != row.id } == checks.filter { $0.id != row.id })
    }

    @Test(arguments: [false, true]) func unboundedOrUnreliablePauseIsRejectedAndRetained(unreliable: Bool) async throws {
        let f = try UnifiedSearchRoutineFixture(enabled: false, stateOperations: true)
        defer { f.results.stop() }
        f.service.routine.createdDayKey = "2000-01-01"
        f.service.routine.pausedOnDayKey = unreliable ? "bad" : "2000-01-01"
        try f.service.context.save()
        try await f.start("routine.enabled", arguments: [.init(parameter: .enabled, operation: .assign, value: .boolean(true))])
        let host = try await f.host(unreliable ? 2 : 1)
        defer { host.close() }
        try await host.clickCompositionControl("unified.routine.prepare")
        #expect(f.controller.routineFailure == "unified.routineState.error." + (unreliable ? "unreliableStart" : "intervalLimit"))
        #expect(f.controller.currentRoutineAcceptance == nil && f.controller.plan?.items.first?.draft.arguments.first?.value == .boolean(true))
        f.controller.requestOperationSubmit(f.controller.buffer)
        #expect(f.service.count("save") == 0 && !f.service.routine.isEnabled)
        #expect(f.controller.routineFailure == "unified.routineState.error." + (unreliable ? "unreliableStart" : "intervalLimit"))
        try await host.revealSettingControlInsidePanel("unified.routine.issue")
        try host.snapshot(unreliable ? "rm3-unreliable" : "rm3-over-limit")
    }
}
