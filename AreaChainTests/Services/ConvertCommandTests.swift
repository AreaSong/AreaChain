import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct ConvertCommandTests {
    @Test func todoToRoutineListsLossesConfirmsAndConvertsOnce() throws {
        let f = try ConvertCommandFixture()
        let other = f.base.todos[1].snapshot
        let routine = f.routine.snapshot
        try f.queue("todo.toRoutine", target: f.todoTarget)
        let preview = try f.preview()
        // 2026-10-09 是星期五；两个活子任务中 1 个已完成，1 个活附件；早先删除的不计。
        let losses = CommandConvertLosses.todoToRoutine(.init(dayKey: "2026-10-09", weekdayMask: WeekdayMask.only(weekday: 6),
            dueMinutes: 600, wasDone: true, subtasks: 2, doneSubtasks: 1, attachments: 1))
        #expect(preview.impact.losses == losses && preview.impact.subtasks.count == 2 && preview.impact.attachments.count == 1)
        #expect(f.count("save") == 0 && !f.context.hasChanges && f.todo.deletedAt == nil)
        let accepted = try f.adapter.accept(preview, expecting: f.handoff.owned().lease)
        #expect(try f.adapter.accept(preview, expecting: f.handoff.owned().lease) == accepted)
        let confirmation = try f.confirm(accepted)
        #expect(confirmation.summary == losses && confirmation.titles == [f.todo.title] && confirmation.targets == [f.todoTarget])
        #expect(try f.routines(accepted.createdID).isEmpty && f.count("save") == 0 && f.refreshes == 0)
        let facts = try f.submit(accepted, confirmation)
        #expect(facts.state == .saved && facts.save == .returned && f.count("save") == 1 && f.count("ui") == 1 && f.count("fact") == 1)
        #expect(facts.created == .init(type: .routine, id: accepted.createdID) && facts.deletedAt == ConvertCommandFixture.now)
        let created = try #require(try f.routines(accepted.createdID).first)
        #expect(created.title == f.todo.title && created.weekdayMask == WeekdayMask.only(weekday: 6))
        #expect(created.createdDayKey == "2026-10-18" && created.remindMinutes == 420 && created.isImportant)
        #expect(created.subtaskTemplates.map(\.title) == f.children.map(\.title))
        #expect(f.todo.deletedAt == ConvertCommandFixture.now && f.children.allSatisfy { $0.deletedAt == ConvertCommandFixture.now })
        #expect(f.earlierChild.deletedAt == Date(timeIntervalSince1970: 200))
        #expect(f.attachment.ownerID == accepted.createdID && f.attachment.ownerKind == AttachmentOwner.routine.rawValue)
        #expect(f.earlierAttachment.ownerID == f.todo.id && f.routineAttachment.ownerID == f.routine.id)
        // 同 UUID 的习惯与非目标待办不受波及。
        #expect(f.routine.snapshot == routine && f.base.todos[1].snapshot == other)
        // 沿原界面实现：待办转习惯保存成功后额外请求一次日历刷新（fake）。
        #expect(f.refreshes == 1 && facts.calendarRefreshRequested)
        #expect(f.base.refreshTargets == [f.todoTarget, facts.created])
        let unit = try #require(f.handoff.state().execution?.units.first)
        #expect(unit.conversion == facts && unit.local == .committed)
    }

    @Test func routineToTodoKeepsChecksOnOriginalAndSkipsExtraRefresh() throws {
        let f = try ConvertCommandFixture()
        let sameID = f.todo.snapshot
        try f.queue("routine.toTodo", target: f.routineTarget)
        let accepted = try f.accept()
        let losses = CommandConvertLosses.routineToTodo(.init(today: "2026-10-18", weekdayMask: WeekdayMask.workdays,
            isEnabled: false, paused: true, checks: 1, templates: 2, attachments: 1))
        #expect(accepted.preview.impact.losses == losses && accepted.preview.impact.checks.count == 1)
        let facts = try f.submit(accepted, f.confirm(accepted))
        #expect(facts.state == .saved && f.count("save") == 1 && f.refreshes == 0 && !facts.calendarRefreshRequested)
        let created = try #require(try f.todos(accepted.createdID).first)
        #expect(created.dayKey == "2026-10-18" && !created.isDone && created.dueMinutes == nil)
        let children = created.subtasks.sorted { $0.sortOrder < $1.sortOrder }
        #expect(children.map(\.title) == ["模板一", "模板二"] && children.allSatisfy { !$0.isDone })
        #expect(f.routine.deletedAt == ConvertCommandFixture.now && f.routine.checks.count == 1)
        #expect(f.routineAttachment.ownerID == accepted.createdID && f.routineAttachment.ownerKind == AttachmentOwner.todo.rawValue)
        // 习惯与 todos[0] 同 UUID：按类型取对象，同 UUID 的待办与其附件不变。
        #expect(f.todo.snapshot == sameID && f.attachment.ownerID == f.todo.id)
    }

    /// 指令与详情页按钮走同一个共享入口：除新 UUID 外写出的字段一致；原对象可经现有回收站恢复。
    @Test func commandMatchesDetailButtonAndOriginalRestoresThroughTrashPage() throws {
        let command = try ConvertCommandFixture()
        let (accepted, _) = try command.run("todo.toRoutine", target: command.todoTarget)
        let ui = try ConvertCommandFixture()
        var dependencies = ItemConversionService.Dependencies()
        dependencies.clock = .init(now: { ConvertCommandFixture.now }, today: { "2026-10-18" }, calendar: ConvertCommandFixture.calendar)
        dependencies.refreshCalendar = { ui.refreshes += 1 }
        let uiID = try #require(ItemConversionService.convertTodoToRoutine(ui.todo, dependencies: dependencies))
        let a = try #require(try command.routines(accepted.createdID).first)
        let b = try #require(try ui.routines(uiID).first)
        func shape(_ r: DailyRoutine) -> [String] {
            [r.title, r.notes, r.sourceBundleID, r.createdDayKey, String(describing: r.weekdayMask),
             String(describing: r.remindMinutes), "\(r.isImportant)\(r.isUrgent)\(r.isEnabled)\(r.sortOrder)"]
                + r.subtaskTemplates.map { "\($0.title)|\($0.sortOrder)|\($0.tagIDs)" }
        }
        #expect(shape(a) == shape(b), "\(shape(a)) ≠ \(shape(b))")
        // 两个夹具各自生成标签 UUID：标签按各自原待办比较。
        #expect(a.tagIDs == command.todo.tagIDs && b.tagIDs == ui.todo.tagIDs && command.refreshes == ui.refreshes)
        #expect(command.children.map(\.deletedAt) == ui.children.map(\.deletedAt) && command.todo.deletedAt == ui.todo.deletedAt)
        // 回收站页面：原待办与随之进入的子任务一起恢复；改挂的附件仍属于新习惯，不在回收站。
        let deleted = try command.context.fetch(FetchDescriptor<AttachmentItem>(predicate: SoftDelete.deletedAttachments))
        let row = try #require(TrashRow.todo(command.todo, attachments: deleted))
        #expect(row.canRestore && row.title == command.todo.title)
        row.restore()
        #expect(command.todo.deletedAt == nil && command.children.allSatisfy { $0.deletedAt == nil })
        #expect(command.earlierChild.deletedAt != nil && command.attachment.ownerID == accepted.createdID)
        #expect(try command.routines(accepted.createdID).first?.deletedAt == nil)

        let routineCase = try ConvertCommandFixture()
        _ = try routineCase.run("routine.toTodo", target: routineCase.routineTarget)
        let resident = try #require(TrashRow.resident(routineCase.routine, attachments: []))
        resident.restore()
        #expect(routineCase.routine.deletedAt == nil && routineCase.routine.checks.count == 1)
    }

    @Test(arguments: [TaskCreateCommandIO.SaveMode.throwBefore, .throwAfter])
    func unknownSaveIsNotReplayedAndVerifiesByNewIdentity(mode: TaskCreateCommandIO.SaveMode) throws {
        let f = try ConvertCommandFixture()
        f.base.saveMode = mode
        try f.queue("todo.toRoutine", target: f.todoTarget)
        let accepted = try f.accept()
        let confirmation = try f.confirm(accepted)
        let facts = try f.submit(accepted, confirmation)
        #expect(facts.state == .unknown && facts.save == .called && facts.rollback == .returned && facts.deletedAt == nil)
        #expect(f.count("save") == 1 && f.count("ui") == 0 && f.count("fact") == 0 && f.refreshes == 0)
        // 同一计划不能再执行；同一对象在核对前也不能重新接受转换。
        #expect(throws: (any Error).self) { try f.submit(accepted, confirmation) }
        #expect(throws: CommandConvertIssue.verificationRequired) { try f.handoff.coordinator.conversions.requireResolved([f.todoTarget]) }
        #expect(try f.handoff.state().execution?.units.first?.local == .unknown && f.count("save") == 1)
        let run = try #require(f.handoff.state().execution)
        let operation = try #require(run.snapshot.items.first.flatMap { run.operation($0.id) })
        let verification = try f.adapter.verifyUnknown(operation, expecting: f.handoff.owned().lease)
        if mode == .throwAfter {
            #expect(verification.created == .live && verification.original == .deleted && verification.outcome == .converted)
        } else {
            #expect(verification.created == .absent && verification.original == .live && verification.outcome == .notConverted)
        }
        #expect(try f.stored(facts.created).count == (mode == .throwAfter ? 1 : 0))
        // 确定结果才解除阻止；原 unknown 回执不提升。
        #expect((try? f.handoff.coordinator.conversions.requireResolved([f.todoTarget])) != nil)
        #expect(try f.handoff.state().execution?.units.first?.local == .unknown && f.count("save") == 1)
    }

    @Test func memberFailureRollsBackBothSides() throws {
        let f = try ConvertCommandFixture()
        let before = (f.todo.snapshot, f.children.map(\.deletedAt), f.attachment.ownerID)
        f.base.afterApply = { _ in throw TaskCreateCommandIO.Failure.injected }
        let (accepted, facts) = try f.run("todo.toRoutine", target: f.todoTarget)
        #expect(facts.state == .notSubmitted && facts.rollback == .returned && f.count("save") == 0 && f.refreshes == 0)
        #expect(f.todo.snapshot == before.0 && f.children.map(\.deletedAt) == before.1 && f.attachment.ownerID == before.2)
        #expect(try f.routines(accepted.createdID).isEmpty && f.handoff.state().execution?.units.first?.local == .notSubmitted)
    }

    @Test func publicationFailureKeepsLocalSaveAndDoesNotRetry() throws {
        let f = try ConvertCommandFixture()
        f.base.environment.beforePublication = { throw TaskCreateCommandIO.Failure.injected }
        let (accepted, facts) = try f.run("routine.toTodo", target: f.routineTarget)
        #expect(facts.state == .saved && facts.publicationFailed && f.count("save") == 1)
        #expect(try f.todos(accepted.createdID).count == 1 && f.routine.deletedAt != nil && f.base.refreshTargets.isEmpty)
        #expect(try f.handoff.state().execution?.units.first?.effects[.taskPublication] == .unknown)
    }
}
