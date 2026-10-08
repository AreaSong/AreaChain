import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchRoutineInteractionTests {
    @Test(arguments: [0, 3]) func titleEffectsAndDisabledDefinition(style: Int) async throws {
        let fixture = try UnifiedSearchRoutineFixture(enabled: style == 0)
        defer { fixture.results.stop() }
        let before = fixture.service.routine.snapshot
        let checks = try fixture.service.checks()
        let host = try await fixture.host(style)
        defer { host.close() }
        try await fixture.selectCommand("/routines/title", host: host)
        try await fixture.title("Native 习惯 !p3 @09:30 #New #恢复", host: host)
        let accepted = try await fixture.prepare(host, name: "title-\(style)")
        #expect(accepted.preview.tags?.actions.final.contains { $0.effect == .createAndAssociate } == true)
        try await host.revealSettingControlInsidePanel("unified.routine.tags")
        try host.snapshot("rm1-title-tags-\(style)")
        let facts = try await fixture.submit(host, name: "title-\(style)", chord: style == 3)
        let stored = try fixture.service.stored()
        let newID = try #require(accepted.tagCreationIDs.values.first)
        #expect(stored.title == "Native 习惯" && stored.remindMinutes == 570 && !stored.isImportant && stored.isUrgent)
        #expect(TagIDList.parse(stored.tagIDs) == [fixture.service.base.live.id, newID, fixture.service.base.deleted.id])
        #expect(facts.savedValues?[.title] == .text("Native 习惯") && facts.authorizationRequest == .returned)
        #expect(try fixture.service.tags().count == 3 && fixture.service.tags().allSatisfy { $0.deletedAt == nil })
        #expect(fixture.service.base.io.authorizations == [570])
        try fixture.service.assertUnchanged(before, except: Set(accepted.preview.original.keys))
        #expect(try fixture.service.checks() == checks)
    }

    @Test func weekdayEmptySelectionAndStoredCompatibility() async throws {
        let fixture = try UnifiedSearchRoutineFixture()
        defer { fixture.results.stop() }
        let before = fixture.service.routine.snapshot
        let checks = try fixture.service.checks()
        let host = try await fixture.host(2)
        defer { host.close() }
        try await fixture.selectCommand("/routines/weekdays", host: host)
        try await host.clickCompositionControl("unified.routine.prepare")
        #expect(fixture.controller.routinePreview == nil && fixture.service.count("save") == 0)
        try WeekdayPickerTestSupport.expectMask(0, allowsEmpty: true, locale: "zh-Hans", in: host.window)
        let sunday = try WeekdayPickerTestSupport.day(1, locale: "zh-Hans", in: host.window)
        try await SettingsButtonTestSupport.click(sunday, in: host.window)
        try await host.settle()
        let saturday = try WeekdayPickerTestSupport.day(7, locale: "zh-Hans", in: host.window)
        try await SettingsButtonTestSupport.click(saturday, in: host.window)
        try await host.settle()
        #expect(fixture.controller.editingDraft?.arguments.first?.value == .weekdays(65))
        let accepted = try await fixture.prepare(host, name: "weekdays")
        _ = try await fixture.submit(host, name: "weekdays", chord: true)
        #expect(try fixture.service.stored().weekdayMask == 65 && !fixture.service.stored().weekdaysOnly)
        try fixture.service.assertUnchanged(before, except: Set(accepted.preview.original.keys))
        #expect(try fixture.service.checks() == checks)
    }

    @Test(arguments: [2, 3, 5]) func nativeReminderAndPriorityControls(kind: Int) async throws {
        let fixture = try UnifiedSearchRoutineFixture()
        defer { fixture.results.stop() }
        let before = fixture.service.routine.snapshot
        let checks = try fixture.service.checks()
        let host = try await fixture.host(kind == 3 ? 1 : 0)
        defer { host.close() }
        try await fixture.selectCommand(kind == 3 ? "/routines/priority" : "/routines/reminder", host: host)
        if kind == 3 {
            let picker = try await host.compositionPicker("unified.parameter.choice.priority")
            try await PickerNativeTestSupport.keyboardSelection(picker, moveDown: true, in: host.window)
        } else if kind == 2 {
            let time = try TimePickerNativeTestSupport.picker(in: host.window)
            try await SettingsButtonTestSupport.reveal(time, in: host.window)
            let frame = time.convert(time.bounds, to: nil)
            try await TimePickerNativeTestSupport.click(.init(x: frame.minX + 10, y: frame.midY), in: host.window)
            try await TimePickerNativeTestSupport.key(25, "9", in: host.window)
            try await TimePickerNativeTestSupport.key(124, "\u{F703}", in: host.window)
            try await TimePickerNativeTestSupport.key(20, "3", in: host.window)
            try await TimePickerNativeTestSupport.key(29, "0", in: host.window)
            try await host.settle()
        } else {
            for _ in 0..<2 {
                let mode = try await host.compositionPicker("unified.parameter.mode.time")
                try await PickerNativeTestSupport.keyboardSelection(mode, moveDown: true, in: host.window)
            }
        }
        let accepted = try await fixture.prepare(host, name: "field-\(kind)")
        _ = try await fixture.submit(host, name: "field-\(kind)", chord: kind == 3)
        let stored = try fixture.service.stored()
        if kind == 2 { #expect(stored.remindMinutes == 570 && fixture.service.base.io.authorizations == [570]) }
        if kind == 5 { #expect(stored.remindMinutes == nil && fixture.service.base.io.authorizations.isEmpty) }
        if case .priority(let important, let urgent) = accepted.preview.edit {
            #expect(stored.isImportant == important && stored.isUrgent == urgent)
        }
        try fixture.service.assertUnchanged(before, except: Set(accepted.preview.original.keys))
        #expect(try fixture.service.checks() == checks)
    }

    @Test(arguments: [CommandFieldOperation.add, .remove, .replaceAll, .clear]) func fourTagModes(mode: CommandFieldOperation) async throws {
        let fixture = try UnifiedSearchRoutineFixture()
        defer { fixture.results.stop() }
        let before = fixture.service.routine.snapshot
        let checks = try fixture.service.checks()
        let host = try await fixture.host(mode == .add ? 3 : 0)
        defer { host.close() }
        try await fixture.selectCommand("/routines/tags", host: host)
        try await fixture.mode(mode, host: host)
        if mode.requiresValue {
            let original = fixture.controller.editingDraft?.arguments
            try await host.clickCompositionControl("unified.tags.choose")
            let id = mode == .remove ? fixture.service.base.live.id : fixture.service.base.deleted.id
            try await host.clickCompositionControl("unified.tags.row." + id.uuidString)
            #expect(fixture.controller.editingDraft?.arguments == original)
            try await host.clickCompositionControl("unified.tags.accept")
        }
        _ = try await fixture.prepare(host, name: "tags-" + mode.rawValue)
        let facts = try await fixture.submit(host, name: "tags-" + mode.rawValue, chord: mode == .replaceAll)
        let expected = mode == .add ? [fixture.service.base.live.id, fixture.service.base.deleted.id]
            : mode == .replaceAll ? [fixture.service.base.deleted.id] : []
        #expect(facts.savedTagIDs == expected)
        #expect(try fixture.service.stored().tagIDs == TagIDList.encode(expected) && fixture.service.tags().count == 2)
        try fixture.service.assertUnchanged(before, except: [.tagIDs])
        #expect(try fixture.service.checks() == checks)
        try await host.revealSettingControlInsidePanel("unified.routine.savedTagCount")
        try host.snapshot("rm1-tags-count-" + mode.rawValue)
    }
}
