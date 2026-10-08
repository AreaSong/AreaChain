import AppKit
import SwiftData
import Testing
@testable import AreaChain

@MainActor final class UnifiedSearchRoutineFixture {
    let service: RoutineCommandFixture
    let results: UnifiedSearchResultsFixture
    let privacy = NotificationCenter()
    var controller: UnifiedSearchController { results.controller }
    let occurrenceDay: String?
    var target: CommandObjectReference { .init(type: occurrenceDay == nil ? .routine : .routineOccurrence,
                                             id: service.routine.id, dayKey: occurrenceDay) }
    var second: CommandObjectReference { .init(type: .routine, id: service.other.id) }

    init(enabled: Bool = true, assembled: Bool = true, stateOperations: Bool = false, occurrenceDay: String? = nil) throws {
        self.occurrenceDay = occurrenceDay
        service = try RoutineCommandFixture(enabled: enabled, stateOperations: stateOperations)
        var batch = occurrenceDay == nil ? QueryBatchFixture.empty("/routines")
            : QueryBatchFixture.occurrences("date:2026-10-07..2026-10-08")
        if occurrenceDay != nil { batch.snapshots.diaries = .complete([]) }
        if let day = occurrenceDay {
            service.stateHistory = [.init(routineID: service.routine.id, interval: .init(lowerBound: day, upperBound: day),
                rule: .weekdays(WeekdayMask.all), source: .synthetic(reference: "rm3-native-history"))]
        }
        let reads = RoutineContentQueryReads(context: service.context)
        let observation = RoutineContentQueryFixture.observation(stateOperations ? service.today : batch.dates.todayKey)
        _ = RoutineContentQueryReader(reads: reads).readSources(into: &batch, observation: observation)
        batch.facts.routine.scheduleEvidence += service.stateHistory
        batch.facts.metadata = .init(tagNames: [service.base.live.id: service.base.live.name,
            service.base.deleted.id: service.base.deleted.name], privateTagIDs: [])
        results = try .init(batch, pageSize: 20, privacyCenter: privacy,
                            routineEnvironment: assembled ? service.environment : nil)
    }

    func start(_ command: String, arguments: [CommandArgument]) async throws {
        try results.startOperation(command)
        try await results.acceptObjects([target])
        for argument in arguments {
            _ = controller.editParameter(argument, source: controller.buffer)
            await controller.objectSelectionTask?.value
        }
    }

    func host(_ style: Int = 0) async throws -> UnifiedSearchTestHost {
        _ = try await results.publish()
        let host = UnifiedSearchTestHost(layout: style % 2 == 0 ? .standard : .compact,
            width: style % 2 == 0 ? 444 : 304, locale: style < 2 ? "en" : "zh-Hans",
            dark: style == 1 || style == 2, results: controller, operations: true)
        try await host.start()
        return host
    }

    func selectCommand(_ path: String, host: UnifiedSearchTestHost) async throws {
        let editor = try host.editor
        editor.insertText(path, replacementRange: .init(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        try await host.key(48, "\t")
        try await select(target, location: "target", host: host)
    }

    func select(_ object: CommandObjectReference, location: String, host: UnifiedSearchTestHost) async throws {
        try await host.clickCompositionControl("unified.objects.choose." + location)
        await controller.objectSelectionTask?.value
        try await host.settle()
        let picker = try #require(controller.objectSelection)
        let candidates = picker.browse.snapshot.units.flatMap(\.hits)
        #expect(candidates.contains(target))
        if occurrenceDay == nil { #expect(candidates.contains(second)) }
        host.window.makeFirstResponder(try host.field)
        for _ in 0...candidates.count {
            if controller.objectSelection?.browse.active == object { break }
            try await host.key(125, "\u{F701}")
        }
        try #require(controller.objectSelection?.browse.active == object)
        try await host.clickCompositionControl("unified.select." + object.searchIdentifier)
        try await host.clickCompositionControl("unified.objects.accept")
        await controller.objectSelectionTask?.value
        try await host.settle()
    }

    func title(_ text: String, host: UnifiedSearchTestHost) async throws {
        let editor = try await host.focusParameter(.title)
        editor.insertText(text, replacementRange: .init(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        try await host.key(36, "\r")
        await controller.objectSelectionTask?.value
        try await host.settle()
    }

    func mode(_ mode: CommandFieldOperation, host: UnifiedSearchTestHost) async throws {
        for _ in 0..<6 {
            if controller.editingDraft?.arguments.first(where: { $0.parameter == .tags })?.operation == mode { return }
            let picker = try await host.compositionPicker("unified.parameter.mode.tags")
            try await PickerNativeTestSupport.keyboardSelection(picker, moveDown: true, in: host.window)
            try await host.settle()
        }
        try #require(controller.editingDraft?.arguments.first { $0.parameter == .tags }?.operation == mode)
    }

    func prepare(_ host: UnifiedSearchTestHost, name: String) async throws -> CommandRoutineAcceptance {
        try await host.clickCompositionControl("unified.routine.prepare")
        let preview = try #require(controller.currentRoutinePreview, "真实影响未准备：\(controller.routineFailure ?? "none")")
        #expect(service.count("save") == 0 && service.count("ui") == 0 && !service.context.hasChanges)
        try await host.revealSettingControlInsidePanel("unified.routine.values")
        try SettingsButtonTestSupport.assertBounds([host.resultNode("unified.routine.values")], in: host.window)
        try host.snapshot((service.stateOperations ? "rm3-" : "rm1-") + name + "-preview")
        let labels = DetailCompletionFixture.strings(in: host.window)
        #expect(!labels.contains("接受子任务影响") && !labels.contains("预览子任务影响"))
        try await host.clickCompositionControl("unified.routine.accept")
        let accepted = try #require(controller.currentRoutineAcceptance)
        #expect(accepted.preview == preview && service.count("save") == 0 && service.count("ui") == 0)
        return accepted
    }

    func submit(_ host: UnifiedSearchTestHost, name: String, chord: Bool) async throws -> CommandRoutineFacts {
        let old = controller.buffer
        if chord {
            host.window.makeFirstResponder(try host.field)
            try await host.settle()
            try await host.key(36, "\r", flags: .command)
        } else { try await host.clickCompositionControl("unified.routine.save") }
        let facts = try #require(controller.routineUnit?.routine)
        #expect(facts.state == .saved && service.count("save") == 1 && service.count("ui") == 1)
        #expect(service.notificationProcessed == 1 && service.calendarProcessed == 1)
        controller.requestOperationSubmit(old)
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        try await host.key(36, "\r", flags: .command)
        #expect(service.count("save") == 1 && service.count("ui") == 1)
        if facts.savedValues?.keys.contains(where: { [.weekdayMask, .remindMinutes, .isImportant].contains($0) }) == true {
            _ = try host.resultNode("unified.routine.savedValues")
        }
        try await host.revealSettingControlInsidePanel("unified.routine.status")
        try host.snapshot((service.stateOperations ? "rm3-" : "rm1-") + name + "-saved")
        return facts
    }

    func scrollStateDetails(_ host: UnifiedSearchTestHost, lastDay: String) async throws {
        let scrolls = ScrollNativeEvidence.views(host.window).compactMap { $0 as? NSScrollView }
        let candidates = scrolls.filter { abs($0.bounds.height - 180) < 2 }
        let scroll = try #require(candidates.count == 1 ? candidates.first : nil)
        let document = try #require(scroll.documentView)
        try #require(document.bounds.height > scroll.contentView.bounds.height)
        document.scrollToVisible(.init(x: 0, y: document.isFlipped ? 0 : document.bounds.maxY - 1, width: 1, height: 1))
        scroll.reflectScrolledClipView(scroll.contentView)
        try await host.settle()
        try host.snapshot("rm3-resume-details-top")
        let original = scroll.contentView.bounds.origin
        for _ in 0..<8 {
            let cg = try #require(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
                                         wheel1: -200, wheel2: 0, wheel3: 0))
            scroll.scrollWheel(with: try #require(NSEvent(cgEvent: cg)))
            try await host.settle()
        }
        #expect(scroll.contentView.bounds.origin != original)
        let last = try host.resultNode("unified.routineState.day." + lastDay)
        let frame = try SettingsButtonTestSupport.frame(last, in: host.window)
        #expect(scroll.convert(scroll.bounds, to: nil).contains(frame))
        #expect(service.count("save") == 0 && controller.currentRoutineAcceptance != nil)
        try host.snapshot("rm3-resume-details-bottom")
    }

}
