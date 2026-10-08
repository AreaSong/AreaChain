import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchBatchStateTests {
    @Test(arguments: [false, true]) func nativeTasksCompleteAndReopen(done: Bool) async throws {
        let state = try BatchStateFixture()
        for todo in state.base.todos { todo.isDone = !done }
        state.child.isDone = !done
        try state.context.save()
        let f = try UnifiedSearchBatchFixture(state: state)
        defer { f.results.stop() }
        let host = try await f.host(done ? 0 : 3)
        defer { host.close() }
        try await f.command("/tasks/batch/completion", host: host)
        try await f.select(Array(f.service.taskTargets.prefix(2)), host: host)
        try await f.setState(done, host: host)
        let accepted = try await f.prepare(host, name: done ? "complete" : "reopen")
        #expect(accepted.preview.writeSet?.counts.total == (done ? 3 : 2))
        if done {
            try await f.revealStateTarget(f.service.taskTargets[0], host: host)
            try await host.clickCompositionControl("unified.batch.cascade." + f.service.taskTargets[0].searchIdentifier)
            try await host.revealSettingControlInsidePanel("unified.batch.child." + state.child.id.uuidString)
            try host.snapshot("bm2-cascade-details")
        }
        let facts = try await f.submit(host, name: done ? "complete" : "reopen", chord: done)
        #expect(facts.state == .saved && f.service.count("save") == 1 && f.service.count("ui") == 1)
        #expect(f.service.todos.prefix(2).allSatisfy { $0.isDone == done })
        #expect(state.child.isDone && !state.deletedChild.isDone)
    }

    @Test func nativeMixedTasksAndTwoExplicitDatesKeepFixedTargets() async throws {
        let state = try BatchStateFixture()
        let f = try UnifiedSearchBatchFixture(state: state)
        defer { f.results.stop() }
        let host = try await f.host(2)
        defer { host.close() }
        try await f.command("/tasks/batch/completion", host: host)
        try await f.select([f.service.taskTargets[0]], host: host)
        try await f.appendOccurrence(state.definitionTargets[0], day: "2026-10-06", host: host)
        try await f.appendOccurrence(state.definitionTargets[0], day: "2026-10-07", host: host)
        try await f.setState(true, host: host)
        let accepted = try await f.prepare(host, name: "mixed-dates")
        #expect(accepted.preview.targets.objects == Array(state.mixed.prefix(3)))
        #expect(accepted.checkCreationIDs.count == 2 && Set(accepted.checkCreationIDs.values).count == 2)
        for target in accepted.preview.targets.objects where target.type == .routineOccurrence {
            try await f.revealStateTarget(target, host: host)
            try host.snapshot("bm2-occurrence-" + (target.dayKey ?? "") + "-preview")
        }
        let facts = try await f.submit(host, name: "mixed-dates", chord: false)
        #expect(facts.state == .saved && f.service.count("save") == 1 && f.service.count("ui") == 1)
        #expect(f.service.todos[0].isDone && state.child.isDone && !f.service.todos[1].isDone)
        try state.assertCreated(accepted)
        #expect(f.service.routine.checks.allSatisfy { $0.isDone && !$0.isSkipped })
        #expect(facts.external.map(\.target) == accepted.preview.targets.objects)
    }

    @Test(arguments: [false, true]) func nativeMultipleDefinitionsPauseAndResume(resume: Bool) async throws {
        let state = try BatchStateFixture(enabled: !resume)
        if resume { state.row(state.base.routine, "2026-10-05") }
        try state.context.save()
        let f = try UnifiedSearchBatchFixture(state: state, definitionsOnly: true)
        defer { f.results.stop() }
        let host = try await f.host(resume ? 1 : 2)
        defer { host.close() }
        try await f.command("/tasks/batch/enabled", host: host)
        try await f.select(state.definitionTargets, host: host)
        try await f.setState(resume, host: host)
        let accepted = try await f.prepare(host, name: resume ? "resume" : "disable")
        #expect(accepted.preview.writeSet?.counts.total == (resume ? 8 : 2))
        if resume {
            try await host.revealSettingControlInsidePanel("unified.routineState.counts")
            try host.snapshot("bm2-backfill-counts")
            try await host.revealSettingControlInsidePanel("unified.routineState.day.2026-10-05")
            try host.snapshot("bm2-backfill-raw-records")
        }
        let facts = try await f.submit(host, name: resume ? "resume" : "disable", chord: resume)
        #expect(facts.state == .saved && f.service.count("save") == 1 && f.service.count("ui") == 1)
        #expect(state.routines.allSatisfy { $0.isEnabled == resume })
        try state.assertCreated(accepted)
        if resume { #expect(try state.checks().allSatisfy { $0.done && $0.skipped }) }
    }
}

extension UnifiedSearchBatchFixture {
    func revealStateTarget(_ target: CommandObjectReference, host: UnifiedSearchTestHost) async throws {
        try await host.revealSettingControlInsidePanel("unified.batch.details")
        let candidates = ScrollNativeEvidence.views(host.window).compactMap { $0 as? NSScrollView }
            .filter { abs($0.bounds.height - 180) < 2 }
        let outer = try #require(candidates.first { candidate in
            var parent = candidate.superview
            while let view = parent {
                if candidates.contains(where: { $0 === view }) { return false }
                parent = view.superview
            }
            return true
        })
        let document = try #require(outer.documentView)
        document.scrollToVisible(.init(x: 0, y: document.isFlipped ? 0 : document.bounds.maxY - 1, width: 1, height: 1))
        outer.reflectScrolledClipView(outer.contentView)
        try await host.settle()
        let identifier = "unified.batch.remove." + target.searchIdentifier
        for _ in 0..<30 {
            let node = SettingsButtonTestSupport.elements(host.window.contentView).first {
                SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String == identifier
            }
            if let node {
                try await SettingsButtonTestSupport.reveal(node, in: host.window)
                let frame = try SettingsButtonTestSupport.frame(node, in: host.window)
                if outer.convert(outer.bounds, to: nil).contains(frame) { return }
            }
            let cg = try #require(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: -120, wheel2: 0, wheel3: 0))
            outer.scrollWheel(with: try #require(NSEvent(cgEvent: cg)))
            try await host.settle()
        }
        Issue.record("目标必须通过真实滚动完整可达")
    }

    func setState(_ enabled: Bool, host: UnifiedSearchTestHost) async throws {
        for _ in 0..<(enabled ? 1 : 2) {
            let picker = try await host.compositionPicker("unified.parameter.boolean.enabled")
            try await PickerNativeTestSupport.keyboardSelection(picker, moveDown: true, in: host.window)
            try await host.settle()
        }
        #expect(controller.editingDraft?.arguments.first?.value == .boolean(enabled))
    }

    func appendOccurrence(_ definition: CommandObjectReference, day: String, host: UnifiedSearchTestHost) async throws {
        try await host.clickCompositionControl("unified.batch.appendTargets")
        await controller.objectSelectionTask?.value
        try await host.settle()
        let picker = try #require(controller.objectSelection)
        host.window.makeFirstResponder(try host.field)
        for _ in 0...picker.browse.snapshot.visible.count {
            if controller.objectSelection?.browse.active == definition { break }
            let active = controller.objectSelection?.browse.active
            let sequence = picker.browse.snapshot.visible
            let forward = (active.flatMap(sequence.firstIndex) ?? -1) < (sequence.firstIndex(of: definition) ?? 0)
            try await host.key(forward ? 125 : 126, forward ? "\u{F701}" : "\u{F700}")
        }
        try await host.clickCompositionControl("unified.select." + definition.searchIdentifier)
        let selected = try #require(controller.objectSelection)
        #expect(controller.objectSelectionIssue(selected) == "unified.batch.chooseExecutionDay")
        try await host.clickCompositionControl("unified.batch.selectDay." + definition.searchIdentifier)
        try await host.revealTaskDatePicker()
        try host.snapshot("bm2-choosing-" + day)
        let cell = try DatePickerTestSupport.day(day, in: host.window)
        try await SettingsButtonTestSupport.reveal(cell, in: host.window)
        try await SettingsButtonTestSupport.click(cell, in: host.window)
        try await host.settle()
        #expect(controller.objectSelection?.occurrenceDays[definition] == day)
        #expect(!controller.acceptObjects(selected.stamp))
        try await acceptSelection(host)
        #expect(controller.editingDraft?.targets.objects.contains(.init(type: .routineOccurrence, id: definition.id, dayKey: day)) == true)
    }
}
