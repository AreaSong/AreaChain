import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct RoutineMutationCompatibilityTests {
    @Test(arguments: ["原习惯", "新标题", "Title !p3 @09:30 #Work #恢复", "Title // 原备注", "   "])
    func legacyTitleDelegationPreservesFieldsAndEffects(raw: String) throws {
        let original = try RoutineCommandFixture()
        let extracted = try RoutineCommandFixture()
        let left = try legacy(original, raw: raw)
        let right = DayBoardMutations.editRoutineWithSyntax(extracted.routine, rawInput: raw,
            dependencies: extracted.environment.dependencies)
        #expect(left == right)
        #expect(try original.stored().snapshot == extracted.stored().snapshot)
        #expect(original.count("save") == extracted.count("save") && original.count("ui") == extracted.count("ui"))
        #expect(original.base.io.authorizations == extracted.base.io.authorizations)
        #expect(original.base.deleted.deletedAt == extracted.base.deleted.deletedAt)
    }

    @Test func oldUIStillSavesSameValueAndKeepsNotes() throws {
        let fixture = try RoutineCommandFixture()
        fixture.routine.notes = "合成旧备注"
        try fixture.context.save()
        let checks = try fixture.checks()
        #expect(DayBoardMutations.editRoutineWithSyntax(fixture.routine, rawInput: fixture.routine.title,
            dependencies: fixture.environment.dependencies))
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1 && fixture.routine.notes == "合成旧备注")
        #expect(try fixture.checks() == checks)
    }

    @Test(arguments: [false, true]) func nestedLegacyBoolMatchesFrozenAlgorithm(fail: Bool) throws {
        let fixtures = try [RoutineCommandFixture(), RoutineCommandFixture()]
        for (index, fixture) in fixtures.enumerated() {
            let before = fixture.routine.snapshot
            do {
                try ModelChanges.transaction(in: fixture.context, boundary: fixture.base.io.boundary) {
                    let accepted = index == 0 ? try legacy(fixture, raw: "嵌套 #恢复 !p3 // 备注")
                        : DayBoardMutations.editRoutineWithSyntax(fixture.routine, rawInput: "嵌套 #恢复 !p3 // 备注",
                                                                 dependencies: fixture.environment.dependencies)
                    #expect(accepted && fixture.count("save") == 0 && fixture.count("ui") == 0)
                    #expect(try fixture.stored().snapshot == before)
                    if fail { throw TaskCreateCommandIO.Failure.injected }
                }
                #expect(!fail)
            } catch { #expect(fail) }
            #expect(fixture.count("save") == (fail ? 0 : 1) && fixture.count("ui") == (fail ? 0 : 1))
            if fail { #expect(fixture.routine.snapshot == before) }
        }
        #expect(try fixtures[0].stored().snapshot == fixtures[1].stored().snapshot)
        #expect(fixtures[0].base.deleted.deletedAt == fixtures[1].base.deleted.deletedAt)
    }

    /// 冻结原算法用于等价对照；不通过新共享服务间接证明自己。
    private func legacy(_ fixture: RoutineCommandFixture, raw: String) throws -> Bool {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        let parsed = NaturalLanguageParser.parseTaskCapture(text)
        let repository = SwiftDataRoutineRepository(context: fixture.context)
        let routine = fixture.routine
        let saved = ModelChanges.perform(in: fixture.context, boundary: fixture.base.io.boundary) {
            try repository.updateRoutine(id: routine.id, title: parsed.cleanTitle, notes: parsed.notes.isEmpty ? nil : parsed.notes)
            if parsed.hasPriorityToken {
                try repository.setPriority(id: routine.id, isImportant: parsed.isImportant, isUrgent: parsed.isUrgent)
            }
            if let minutes = parsed.remindMinutes { try repository.setRemind(id: routine.id, minutes: minutes) }
            let tags = try InputTagResolver.merging(parsed.tagNames, into: routine.tagIDs, in: fixture.context)
            try repository.replaceTagIDs(id: routine.id, tagIDs: tags)
        }
        if saved { fixture.base.io.dependencies.requestReminderAccessIfNeeded(parsed.remindMinutes) }
        return saved
    }
}
