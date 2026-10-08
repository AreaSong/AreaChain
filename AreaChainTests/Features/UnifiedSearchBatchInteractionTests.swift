import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchBatchInteractionTests {
    @Test(arguments: [0, 3]) func nativeMoveCompleteAllPreviewRemoveAndSubmit(style: Int) async throws {
        let f = try UnifiedSearchBatchFixture(count: 8)
        defer { f.results.stop() }
        let before = f.service.todos.map(\.snapshot)
        let other = f.service.other.snapshot
        let host = try await f.host(style)
        defer { host.close() }
        try await f.command("/tasks/batch/move", host: host)
        try await host.clickCompositionControl("unified.objects.allResults")
        try host.snapshot("bm1-all-\(style)")
        try await f.acceptSelection(host)
        #expect(f.controller.editingDraft?.targets.selection == .allResults)
        #expect(f.controller.editingDraft?.targets.objects.count == 8)
        try await host.clickCompositionControl("unified.parameter.date")
        try await host.revealTaskDatePicker()
        try await host.clickCompositionControl("daybook.date." + DayKey.today())
        let accepted = try await f.prepare(host, name: "move-\(style)")
        #expect(accepted.preview.impacts.count == 8)
        let last = try #require(accepted.preview.impacts.last?.target)
        try await f.scrollDetails(host, last: last, name: "move-\(style)")
        try await host.clickCompositionControl("unified.batch.remove." + last.searchIdentifier)
        await f.controller.objectSelectionTask?.value
        #expect(f.controller.currentBatchAcceptance == nil && f.controller.plan?.items.count == 1)
        #expect(f.controller.plan?.items.first?.draft.targets.objects.count == 7)
        let next = try await f.prepare(host, name: "move-revised-\(style)")
        #expect(next.preview.targets.objects.count == 7 && next.id != accepted.id)
        let facts = try await f.submit(host, name: "move-\(style)", chord: style == 3)
        #expect(facts.state == .saved && f.service.count("save") == 1 && f.service.count("ui") == 1)
        for (todo, old) in zip(f.service.todos, before) {
            #expect(todo.dayKey == (todo.id == last.id ? old.dayKey : DayKey.today()))
            #expect(todo.title == old.title && todo.isDone == old.isDone && todo.tagIDs == old.tagIDs)
            #expect(todo.remindMinutes == old.remindMinutes && todo.createdAt == old.createdAt)
        }
        #expect(f.service.other.snapshot == other)
    }

    @Test(arguments: [CommandFieldOperation.add, .remove]) func nativeMixedTags(mode: CommandFieldOperation) async throws {
        let f = try UnifiedSearchBatchFixture(move: false)
        defer { f.results.stop() }
        let host = try await f.host(mode == .add ? 1 : 2)
        defer { host.close() }
        let tags = f.service.tags.map(TaskCreateTagCatalogReader.record)
        let other = f.service.other.snapshot
        try await f.command("/tasks/batch/tags", host: host)
        try await f.select([f.service.taskTargets[0], .init(type: .routine, id: f.service.routine.id)], host: host)
        for _ in 0..<4 {
            let current = f.controller.editingDraft?.arguments.first { $0.parameter == .tags }?.operation ?? .add
            if current == mode { break }
            let picker = try await host.compositionPicker("unified.parameter.mode.tags")
            try await PickerNativeTestSupport.keyboardSelection(picker, moveDown: true, in: host.window)
            try await host.settle()
        }
        try await host.clickCompositionControl("unified.tags.choose")
        #expect(f.controller.tagSelection?.candidates.records.contains { $0.id == f.service.tags[2].id } == false)
        try await host.clickCompositionControl("unified.tags.row." + f.service.tags[0].id.uuidString)
        try await host.clickCompositionControl("unified.tags.accept")
        let accepted = try await f.prepare(host, name: "tags-" + mode.rawValue)
        #expect(accepted.preview.changedCount == 1 && accepted.preview.impacts.count == 2)
        let facts = try await f.submit(host, name: "tags-" + mode.rawValue, chord: mode == .remove)
        #expect(facts.state == .saved && facts.changedCount == 1 && f.service.count("save") == 1 && f.service.count("ui") == 1)
        #expect(f.service.todos[0].tagIDs == (mode == .add ? f.service.tags[0].id.uuidString : ""))
        #expect(TagIDList.parse(f.service.routine.tagIDs) == (mode == .add ? [f.service.tags[2].id, f.service.tags[0].id] : [f.service.tags[2].id]))
        #expect(f.service.tags.map(TaskCreateTagCatalogReader.record) == tags && f.service.other.snapshot == other)
    }

    @Test func incompleteAllExplainsGapAndExplicitKnownSelectionWorks() async throws {
        let f = try UnifiedSearchBatchFixture(incomplete: true)
        defer { f.results.stop() }
        let host = try await f.host(3)
        defer { host.close() }
        try await f.command("/tasks/batch/move", host: host)
        _ = try host.resultNode("unified.objects.incompleteAll")
        try host.snapshot("bm1-incomplete")
        try await host.clickCompositionControl("unified.objects.known")
        try await f.acceptSelection(host)
        #expect(f.controller.editingDraft?.targets.selection == .selected)
        #expect(f.controller.editingDraft?.targets.objects.count == 3 && f.service.count("save") == 0)
    }
}
