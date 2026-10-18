import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct TrashCommandBoundaryTests {
    @Test func confirmationIsRequiredAndBoundToTheAcceptance() throws {
        let f = try TrashCommandFixture()
        try f.queue("todo.trash", targets: [f.todoTarget])
        let accepted = try f.accept()
        let confirmation = try f.confirm(accepted)
        f.adapter.cancel(confirmation)
        // Esc / 取消后草稿、计划和接受不变，但旧确认不能再提交。
        #expect(try f.handoff.state().plan.items.first?.draft.targets.objects == [f.todoTarget])
        #expect(f.handoff.coordinator.trashes.acceptances[accepted.preview.draft.draftID] == accepted)
        #expect(throws: CommandTrashIssue.confirmationRequired) { try f.submit(accepted, confirmation) }
        let second = try f.confirm(accepted)
        #expect(second.id != confirmation.id)
        #expect(throws: CommandTrashIssue.confirmationStale) { try f.submit(accepted, confirmation) }
        #expect(try f.count("save") == 0 && f.parent.deletedAt == nil && f.handoff.state().execution == nil)
        #expect(try f.submit(accepted, f.confirm(accepted)).state == .saved)
    }

    @Test func targetChangedOrDeletedAfterConfirmationIsRejectedWithoutWrites() throws {
        for change in ["title", "subtask", "attachment", "deleted"] {
            let f = try TrashCommandFixture()
            try f.queue("todo.trash", targets: [f.todoTarget])
            let accepted = try f.accept()
            let confirmation = try f.confirm(accepted)
            switch change {
            case "title": f.parent.title = "外部改名"
            case "subtask": f.context.insert(SubtaskItem(title: "确认后新增", sortOrder: 9, todo: f.parent))
            case "attachment": f.context.insert(AttachmentItem(ownerKind: "todo", ownerID: f.parent.id, filename: "late.png"))
            default: f.parent.deletedAt = Date(timeIntervalSince1970: 50)
            }
            try f.context.save()
            let reason: CommandTrashTargetProblem.Reason = change == "deleted" ? .deleted : .changed
            #expect(throws: CommandTrashIssue.invalidTargets([.init(target: f.todoTarget, reason: reason)])) {
                try f.submit(accepted, confirmation)
            }
            // 拒绝后确认被撤销：不能静默扩大或缩小目标，必须重新预览。
            #expect(throws: CommandTrashIssue.confirmationRequired) { try f.submit(accepted, confirmation) }
            #expect(try f.count("save") == 0 && f.handoff.state().execution == nil)
        }
    }

    @Test func newAcceptanceAndPlanEditsInvalidateConfirmation() throws {
        let f = try TrashCommandFixture()
        try f.queue("batch.trash", targets: f.base.mixedTargets)
        let accepted = try f.accept()
        let confirmation = try f.confirm(accepted)
        // 宿主任何新事件都会换 lease：旧确认绑定的计划视图失效。
        try f.handoff.send(.query(.setInput("synthetic")))
        #expect(throws: CommandTrashIssue.stale) { try f.submit(accepted, confirmation) }
        let renewed = try f.accept()
        let again = try f.confirm(renewed)
        f.base.todos[1].title = "确认后改名"
        try f.context.save()
        // 新预览产生新接受；旧确认随之撤销，不能套用到新集合上。
        let next = try f.accept()
        #expect(next.id != renewed.id && next.preview.impacts[1].title == "确认后改名")
        #expect(throws: CommandTrashIssue.confirmationRequired) { try f.submit(next, again) }
        #expect(throws: CommandTrashIssue.confirmationRequired) { try f.submit(renewed, again) }
        #expect(f.count("save") == 0)
    }

    @Test func ineligibleTargetsAreReportedPerTarget() throws {
        let f = try TrashCommandFixture()
        let notes = f.base.todos[1]
        notes.notes = "有备注"
        try f.context.save()
        try f.queue("batch.trash", targets: f.base.mixedTargets)
        f.base.sourceOverride[f.base.taskTargets[2]] = .init(revision: UUID(), protection: .required, notes: .absent)
        #expect(throws: CommandTrashIssue.invalidTargets([.init(target: f.base.taskTargets[2], reason: .protectedContent)])) {
            try f.preview()
        }
        f.base.sourceOverride = [:]
        #expect(throws: CommandTrashIssue.invalidTargets([.init(target: f.base.taskTargets[1], reason: .notes)])) {
            try f.preview()
        }
        f.base.sourceOverride[f.base.taskTargets[1]] = .init(revision: UUID(), protection: .ordinary, notes: .present)
        #expect(throws: CommandTrashIssue.invalidTargets([.init(target: f.base.taskTargets[1], reason: .notes)])) {
            try f.preview()
        }
        #expect(f.count("save") == 0)
    }

    @Test func deletedAndMissingTargetsAreRejected() throws {
        let f = try TrashCommandFixture()
        try f.queue("subtask.delete", targets: [.init(type: .subtask, id: f.earlierDeleted.id)])
        #expect(throws: CommandTrashIssue.invalidTargets([.init(target: .init(type: .subtask, id: f.earlierDeleted.id), reason: .deleted)])) {
            try f.preview()
        }
        let g = try TrashCommandFixture()
        let ghost = CommandObjectReference(type: .routine, id: UUID())
        try g.queue("routine.trash", targets: [ghost])
        #expect(throws: CommandTrashIssue.invalidTargets([.init(target: ghost, reason: .missing)])) { try g.preview() }
        let h = try TrashCommandFixture()
        h.parent.deletedAt = Date(timeIntervalSince1970: 10)
        try h.context.save()
        try h.queue("subtask.delete", targets: [h.subtaskTarget()])
        #expect(throws: CommandTrashIssue.invalidTargets([.init(target: h.subtaskTarget(), reason: .family)])) { try h.preview() }
    }

    @Test(arguments: [3997, 3998]) func batchUsesTheApprovedEntityLimit(subtasks: Int) throws {
        let f = try TrashCommandFixture(count: 1)
        for index in 0..<(subtasks - 2) { f.context.insert(SubtaskItem(title: "量 \(index)", sortOrder: 10 + index, todo: f.parent)) }
        try f.context.save()
        try f.queue("batch.trash", targets: [f.todoTarget])
        // 目标 1 + 子项 subtasks + 附件 2；4000 为批准上限。
        let total = 1 + subtasks + 2
        if total > CommandBatchWriteSet.Counts.entityLimit {
            #expect(throws: CommandTrashIssue.writeLimit(.init(targets: 1, subtasks: subtasks, attachments: 2))) { try f.preview() }
        } else {
            #expect(try f.preview().counts.total == total)
        }
        #expect(f.count("save") == 0)
    }

    @Test func singleCommandsAreNotLimitedButMustStaySingle() throws {
        let f = try TrashCommandFixture()
        try f.queue("todo.trash", targets: f.base.taskTargets)
        #expect(throws: CommandTrashIssue.invalidArguments) { try f.preview() }
        let g = try TrashCommandFixture()
        // 类型不符可能在入列或准备时被拒；两处都不能产生写入。
        #expect(throws: (any Error).self) {
            try g.queue("routine.trash", targets: [g.todoTarget])
            _ = try g.preview()
        }
        #expect(f.count("save") == 0 && g.count("save") == 0)
    }

    @Test func trashItemsAreRejectedFromMultiItemPlans() throws {
        let f = try TrashCommandFixture()
        try f.queue("todo.trash", targets: [f.todoTarget])
        try f.base.queue()
        #expect(throws: CommandTrashIssue.unsupportedPlan) { try f.preview() }
        let batch = BatchCommandAdapter(coordinator: f.handoff.coordinator, environment: f.base.environment)
        let multi = MultiPlanCommandAdapter(coordinator: f.handoff.coordinator, adapters: .init(batch: batch))
        #expect(throws: CommandMultiPlanIssue.independentConfirmation) {
            try multi.prepare(plan: f.handoff.state().plan.stamp, expecting: f.handoff.owned().lease)
        }
        #expect(throws: CommandMultiPlanIssue.independentConfirmation) { try multi.family(for: .init(rawValue: "batch.trash")) }
        #expect(f.count("save") == 0)
    }

    @Test func capabilityStaysClosedByDefaultAndOtherConfirmationsStayUnopened() throws {
        let f = try TrashCommandFixture()
        let closed = TrashCommandAdapter(coordinator: f.handoff.coordinator, environment: f.base.environment)
        for command in CommandTrashEdit.commands { #expect(!closed.supports(.init(rawValue: command))) }
        #expect(!TrashCommandAdapter(coordinator: f.handoff.coordinator, capability: .softTrash).supports(.init(rawValue: "todo.trash")))
        try f.queue("todo.trash", targets: [f.todoTarget])
        #expect(throws: CommandTrashIssue.unassembled) {
            try closed.prepare(plan: f.handoff.state().plan.stamp, expecting: f.handoff.owned().lease)
        }
        let declared = CommandCatalog.standard.entries.filter { $0.interactions.contains(.independentConfirmation) }.map(\.id.rawValue)
        #expect(CommandTrashEdit.commands.isSubset(of: Set(declared)))
        for other in declared where !CommandTrashEdit.commands.contains(other) {
            #expect(!f.adapter.supports(.init(rawValue: other)))
        }
    }

    @Test func runIsInvokedOnlyOnceAndUnknownIsNotReplayed() throws {
        let f = try TrashCommandFixture()
        try f.queue("todo.trash", targets: [f.todoTarget])
        let accepted = try f.accept()
        let confirmation = try f.confirm(accepted)
        #expect(try f.submit(accepted, confirmation).state == .saved)
        #expect(throws: (any Error).self) { try f.submit(accepted, confirmation) }
        let run = try #require(f.handoff.state().execution)
        let item = try #require(run.snapshot.items.first)
        let attempt = try #require(run.attempt(item.id))
        let operation = try #require(run.operation(item.id))
        #expect(throws: (any Error).self) {
            try f.adapter.execute(.init(lease: f.handoff.owned().lease, operation: operation, attempt: attempt))
        }
        #expect(f.count("save") == 1)
    }
}
