import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct TrashCommandTests {
    /// 只比较删除形状：哪些实体被打戳、是否与父项同戳；不比较具体时刻。
    private struct Shape: Equatable {
        let todos: [Bool]
        let routine: Bool
        let subtasks: [String]
        let attachments: [String]
    }

    private func shape(_ f: TrashCommandFixture) -> Shape {
        let stamp = f.parent.deletedAt
        func mark(_ date: Date?) -> String { date == nil ? "live" : date == stamp ? "cascade" : "own" }
        return .init(todos: f.base.todos.map { $0.deletedAt != nil }, routine: f.base.routine.deletedAt != nil,
                     subtasks: (f.liveSubtasks + [f.earlierDeleted]).map { mark($0.deletedAt) },
                     attachments: (f.attachments + [f.earlierAttachment]).map { mark($0.deletedAt) })
    }

    @Test func todoTrashCascadesWithOneStampAndOneSave() throws {
        let f = try TrashCommandFixture()
        let others = f.base.todos.dropFirst().map(\.snapshot)
        let routine = f.base.routine.snapshot
        let earlier = (f.earlierDeleted.deletedAt, f.earlierAttachment.deletedAt)
        try f.queue("todo.trash", targets: [f.todoTarget])
        let accepted = try f.accept()
        #expect(accepted.preview.counts == .init(targets: 1, subtasks: 2, attachments: 2))
        let confirmation = try f.confirm(accepted)
        #expect(confirmation.titles == [f.parent.title] && confirmation.targets == [f.todoTarget])
        #expect(f.count("save") == 0 && f.count("ui") == 0 && f.parent.deletedAt == nil && !f.context.hasChanges)
        let facts = try f.submit(accepted, confirmation)
        #expect(facts.state == .saved && facts.save == .returned && f.count("save") == 1 && f.count("ui") == 1 && f.count("fact") == 1)
        let stamp = try #require(f.parent.deletedAt)
        #expect(facts.deletedAt == [f.todoTarget: stamp])
        #expect(f.liveSubtasks.allSatisfy { $0.deletedAt == stamp } && f.attachments.allSatisfy { $0.deletedAt == stamp })
        #expect((f.earlierDeleted.deletedAt, f.earlierAttachment.deletedAt) == earlier)
        #expect(f.base.todos.dropFirst().map(\.snapshot) == others && f.base.routine.snapshot == routine)
        #expect(f.routineAttachment.deletedAt == nil && f.base.other.deletedAt == nil)
        #expect(f.base.refreshTargets == [f.todoTarget])
        let unit = try #require(f.handoff.state().execution?.units.first)
        #expect(unit.trash == facts && unit.local == .committed)
    }

    @Test func commandTrashMatchesUITrashAndRestoresThroughTrashPage() throws {
        let command = try TrashCommandFixture()
        _ = try command.run("todo.trash", targets: [command.todoTarget])
        let legacy = try TrashCommandFixture()
        #expect(DayBoardMutations.trashTodo(legacy.parent))
        #expect(shape(command) == shape(legacy))
        // 回收站页面同一入口：可见行、子项摘要与恢复结果一致。
        let deleted = try command.context.fetch(FetchDescriptor<AttachmentItem>(predicate: SoftDelete.deletedAttachments))
        let row = try #require(TrashRow.todo(command.parent, attachments: deleted))
        let legacyRow = try #require(TrashRow.todo(legacy.parent, attachments: try legacy.context.fetch(
            FetchDescriptor<AttachmentItem>(predicate: SoftDelete.deletedAttachments))))
        #expect(row.section == .todo && row.title == legacyRow.title && row.canRestore)
        guard case .todo(let detail) = row.detail, case .todo(let legacyDetail) = legacyRow.detail else {
            Issue.record("回收站行缺少待办详情"); return
        }
        #expect(detail.subtasks.map(\.title) == legacyDetail.subtasks.map(\.title) && detail.subtasks.count == 2)
        #expect(detail.attachmentCount == 3 && legacyDetail.attachmentCount == 3)
        row.restore()
        #expect(command.parent.deletedAt == nil && command.liveSubtasks.allSatisfy { $0.deletedAt == nil })
        #expect(command.attachments.allSatisfy { $0.deletedAt == nil })
        #expect(command.earlierDeleted.deletedAt != nil && command.earlierAttachment.deletedAt != nil)
    }

    @Test func subtaskDeleteMatchesUIAndUpdatesParentProgressByExistingRule() throws {
        let f = try TrashCommandFixture()
        let parent = f.parent.snapshot
        let sibling = f.liveSubtasks[0].snapshot
        let facts = try f.run("subtask.delete", targets: [f.subtaskTarget(1)])
        #expect(facts.state == .saved && f.count("save") == 1 && facts.counts == .init(targets: 1, subtasks: 0, attachments: 0))
        #expect(f.liveSubtasks[1].deletedAt != nil && f.liveSubtasks[0].snapshot == sibling)
        #expect(f.parent.deletedAt == nil && f.parent.isDone == parent.isDone && f.parent.title == parent.title)
        // 进度胶囊沿 TaskRowFactory 的活子项过滤：2/3 → 1/2（完成 1 个）。
        let live = f.parent.subtasks.filter { $0.deletedAt == nil }
        #expect(live.count == 1 && live.filter(\.isDone).count == 1)
        #expect(f.base.refreshTargets == [f.todoTarget])
        let legacy = try TrashCommandFixture()
        #expect(DayBoardMutations.deleteSubtask(legacy.liveSubtasks[1]))
        #expect(legacy.liveSubtasks.map { $0.deletedAt != nil } == f.liveSubtasks.map { $0.deletedAt != nil })
        // 独立删除的子项在待办仍存活时不出现在回收站页面，与界面删除一致。
        #expect(TrashRow.todo(f.parent, attachments: []) == nil && TrashRow.todo(legacy.parent, attachments: []) == nil)
    }

    @Test func routineTrashStampsOwnAttachmentAndLeavesSameUUIDTodo() throws {
        let f = try TrashCommandFixture()
        let todo = f.parent.snapshot
        let facts = try f.run("routine.trash", targets: [f.routineTarget])
        let stamp = try #require(f.base.routine.deletedAt)
        #expect(facts.state == .saved && facts.deletedAt == [f.routineTarget: stamp] && f.count("save") == 1)
        #expect(f.routineAttachment.deletedAt == stamp && f.base.routine.checks.count == 1)
        #expect(f.parent.snapshot == todo && f.attachments.allSatisfy { $0.deletedAt == nil })
        #expect(TrashRow.resident(f.base.routine, attachments: [f.routineAttachment]) != nil)
    }

    @Test func batchTrashKeepsTypedIdentityFrozenSetAndOneSave() throws {
        let f = try TrashCommandFixture(count: 4)
        let first = f.parent.snapshot
        let targets = Array(f.base.taskTargets.dropFirst()) + [f.routineTarget]
        try f.queue("batch.trash", targets: targets)
        let accepted = try f.accept()
        let confirmation = try f.confirm(accepted)
        #expect(confirmation.targets == targets && confirmation.titles.count == CommandTrashConfirmation.sampleLimit)
        #expect(confirmation.counts == .init(targets: 4, subtasks: 0, attachments: 1))
        let facts = try f.submit(accepted, confirmation)
        #expect(facts.state == .saved && f.count("save") == 1 && f.count("ui") == 1)
        // 习惯与 todos[0] 同 UUID：按类型分开传 ID，未选中的待办不能被波及。
        #expect(f.parent.snapshot == first && f.liveSubtasks.allSatisfy { $0.deletedAt == nil })
        let stamps = Set(f.base.todos.dropFirst().compactMap(\.deletedAt))
        #expect(stamps.count == 1 && f.base.todos.dropFirst().allSatisfy { $0.deletedAt != nil })
        #expect(f.base.routine.deletedAt != nil && f.routineAttachment.deletedAt == f.base.routine.deletedAt)
        #expect(Set(facts.deletedAt.keys) == Set(targets) && f.base.other.deletedAt == nil)
        #expect(f.base.refreshTargets == targets)
    }

    /// 保存已调用后失败沿 B-M1：一律 unknown、不发布、不重放；以新 context 读出真实落盘结果。
    @Test(arguments: [TaskCreateCommandIO.SaveMode.throwBefore, .throwAfter])
    func saveFailureNeverReportsSuccess(mode: TaskCreateCommandIO.SaveMode) throws {
        let f = try TrashCommandFixture()
        f.base.saveMode = mode
        try f.queue("todo.trash", targets: [f.todoTarget])
        let accepted = try f.accept()
        let confirmation = try f.confirm(accepted)
        let facts = try f.submit(accepted, confirmation)
        #expect(facts.state == .unknown && facts.save == .called && facts.rollback == .returned && facts.deletedAt.isEmpty)
        #expect(f.count("save") == 1 && f.count("ui") == 0 && f.count("fact") == 0 && facts.publication == .notCalled)
        #expect(throws: (any Error).self) { try f.submit(accepted, confirmation) }
        #expect(f.count("save") == 1)
        let run = try #require(f.handoff.state().execution)
        #expect(run.snapshot.items.first?.draft.targets.objects == [f.todoTarget])
        #expect(run.units.first?.local == .unknown && run.units.first?.trash == facts)
        let fresh = ModelContext(f.base.io.container)
        let id = f.parent.id
        let stored = try #require(try fresh.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id })).first)
        #expect((stored.deletedAt != nil) == (mode == .throwAfter))
    }

    @Test func memberFailureRollsBackWholeBatch() throws {
        let f = try TrashCommandFixture()
        let before = (f.base.todos.map(\.snapshot), f.base.routine.snapshot)
        var applied = 0
        f.base.afterApply = { _ in
            applied += 1
            if applied == 2 { throw TaskCreateCommandIO.Failure.injected }
        }
        let facts = try f.run("batch.trash", targets: f.base.mixedTargets)
        #expect(facts.state == .notSubmitted && facts.rollback == .returned && f.count("save") == 0)
        #expect(f.base.todos.map(\.snapshot) == before.0 && f.base.routine.snapshot == before.1)
        #expect(f.liveSubtasks.allSatisfy { $0.deletedAt == nil } && f.attachments.allSatisfy { $0.deletedAt == nil })
    }

    @Test func publicationFailureKeepsLocalSaveAndDoesNotRetry() throws {
        let f = try TrashCommandFixture()
        f.base.environment.beforePublication = { throw TaskCreateCommandIO.Failure.injected }
        let facts = try f.run("todo.trash", targets: [f.todoTarget])
        #expect(facts.state == .saved && facts.publicationFailed && f.count("save") == 1)
        #expect(f.parent.deletedAt != nil && f.base.refreshTargets.isEmpty)
        #expect(try f.handoff.state().execution?.units.first?.effects[.taskPublication] == .unknown)
    }
}
