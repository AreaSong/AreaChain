import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct ConvertCommandBoundaryTests {
    /// 带备注可以转换，损失清单标出“备注搬到新对象”；受保护来源与无法证明仍拒绝。
    @Test func notesAreListedAndProtectedSourcesAreRejectedWithReason() throws {
        let f = try ConvertCommandFixture()
        f.todo.notes = "有备注"
        try f.context.save()
        try f.queue("todo.toRoutine", target: f.todoTarget)
        guard case .todoToRoutine(let losses) = try f.preview().impact.losses else { Issue.record("losses"); return }
        #expect(losses.notes)
        f.base.sourceOverride[f.todoTarget] = .init(revision: UUID(), protection: .required)
        #expect(throws: CommandConvertIssue.invalidTarget(.protectedContent)) { try f.preview() }
        f.base.sourceOverride = [:]
        f.base.environment.notesKey = nil
        #expect(throws: CommandConvertIssue.invalidTarget(.source)) { try f.preview() }
        let g = try ConvertCommandFixture()
        g.routine.notes = "习惯备注"
        try g.context.save()
        try g.queue("routine.toTodo", target: g.routineTarget)
        guard case .routineToTodo(let back) = try g.preview().impact.losses else { Issue.record("losses"); return }
        #expect(back.notes)
        #expect(f.count("save") == 0 && g.count("save") == 0)
    }

    @Test func changesAfterPreviewOrConfirmationRequireRepreview() throws {
        for change in ["title", "subtask", "attachment", "deleted", "nextDay"] {
            let f = try ConvertCommandFixture()
            let command = change == "nextDay" ? "routine.toTodo" : "todo.toRoutine"
            let target = change == "nextDay" ? f.routineTarget : f.todoTarget
            try f.queue(command, target: target)
            let accepted = try f.accept()
            let confirmation = try f.confirm(accepted)
            switch change {
            case "title": f.todo.title = "外部改名"
            case "subtask": f.context.insert(SubtaskItem(title: "确认后新增", sortOrder: 9, todo: f.todo))
            case "attachment": f.context.insert(AttachmentItem(ownerKind: "todo", ownerID: f.todo.id, filename: "late.png"))
            case "deleted": f.todo.deletedAt = Date(timeIntervalSince1970: 50)
            default: f.today = "2026-10-19"
            }
            try f.context.save()
            let issue = change == "deleted" ? CommandConvertIssue.invalidTarget(.deleted) : .invalidTarget(.changed)
            #expect(throws: issue) { try f.submit(accepted, confirmation) }
            // 拒绝后确认被撤销，必须重新预览；没有任何写入或新对象。
            #expect(throws: CommandConvertIssue.confirmationRequired) { try f.submit(accepted, confirmation) }
            #expect(try f.count("save") == 0 && f.handoff.state().execution == nil && f.refreshes == 0)
            #expect(try f.stored(accepted.created).isEmpty)
        }
    }

    @Test func confirmationIsBoundToTheAcceptanceAndSharedLedger() throws {
        let f = try ConvertCommandFixture()
        try f.queue("todo.toRoutine", target: f.todoTarget)
        let accepted = try f.accept()
        #expect(throws: CommandConvertIssue.confirmationRequired) { try f.submit(accepted, CommandConvertFixtureDummy.confirmation(f, accepted)) }
        let confirmation = try f.confirm(accepted)
        f.adapter.cancel(confirmation)
        #expect(try f.handoff.state().plan.items.first?.draft.targets.objects == [f.todoTarget])
        #expect(f.handoff.coordinator.conversions.acceptances[accepted.preview.draft.draftID] == accepted)
        #expect(throws: CommandConvertIssue.confirmationRequired) { try f.submit(accepted, confirmation) }
        let second = try f.confirm(accepted)
        #expect(second.id != confirmation.id)
        #expect(throws: CommandConvertIssue.confirmationStale) { try f.submit(accepted, confirmation) }
        #expect(f.count("save") == 0 && f.todo.deletedAt == nil)
        #expect(try f.submit(accepted, second).state == .saved)
        // 已执行的接受不能再签发确认或再次执行。
        #expect(throws: (any Error).self) { try f.confirm(accepted) }
        #expect(throws: (any Error).self) { try f.submit(accepted, second) }
        #expect(f.count("save") == 1)
    }

    @Test func singleItemPlansOnlyAndMultiPlanRejectsConversion() throws {
        let f = try ConvertCommandFixture()
        try f.queue("todo.toRoutine", target: f.todoTarget)
        try f.base.queue()
        #expect(throws: CommandConvertIssue.unsupportedPlan) { try f.preview() }
        let batch = BatchCommandAdapter(coordinator: f.handoff.coordinator, environment: f.base.environment)
        let multi = MultiPlanCommandAdapter(coordinator: f.handoff.coordinator, adapters: .init(batch: batch))
        for command in CommandConvertEdit.commands {
            #expect(throws: CommandMultiPlanIssue.independentConfirmation) { try multi.family(for: .init(rawValue: command)) }
        }
        let g = try ConvertCommandFixture()
        #expect(throws: (any Error).self) {
            try g.queue("routine.toTodo", target: g.todoTarget)
            _ = try g.preview()
        }
        #expect(f.count("save") == 0 && g.count("save") == 0)
    }

    @Test func capabilityStaysClosedByDefault() throws {
        let f = try ConvertCommandFixture(capability: .closed)
        for command in CommandConvertEdit.commands { #expect(!f.adapter.supports(.init(rawValue: command))) }
        let unassembled = ConvertCommandAdapter(coordinator: f.handoff.coordinator, capability: .convert,
                                                clock: .init(), refreshCalendar: {})
        #expect(!unassembled.supports(.init(rawValue: "todo.toRoutine")))
        try f.queue("todo.toRoutine", target: f.todoTarget)
        #expect(throws: CommandConvertIssue.unassembled) { try f.preview() }
        // 转换适配器只认这两个命令；回收适配器也不认转换。
        let open = try ConvertCommandFixture()
        #expect(!open.adapter.supports(.init(rawValue: "todo.trash")))
        let trash = TrashCommandAdapter(coordinator: open.handoff.coordinator, environment: open.base.environment, capability: .softTrash)
        for command in CommandConvertEdit.commands { #expect(!trash.supports(.init(rawValue: command))) }
    }
}

/// 构造一份从未登记的确认，用来证明“没有确认就不能提交”。
@MainActor private enum CommandConvertFixtureDummy {
    static func confirmation(_ f: ConvertCommandFixture, _ accepted: CommandConvertAcceptance) -> CommandConvertConfirmation {
        CommandIndependentConfirmationLedger<CommandConvertLosses>().issue(accepted.confirmationBinding, titles: [])
    }
}
