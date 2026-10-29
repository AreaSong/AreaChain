import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 标签合并、对象解绑、回收与恢复。写入只调原仓储；私密标签合并整条拒绝（用户决定）；
/// 受保护手记解绑拿不到资格就拒绝；回收与恢复必须经共用独立确认、只能单项执行。
@Suite(.serialized) @MainActor struct TagOrganizeCommandTests {
    private func destination(_ tag: TagItem) -> CommandArgument {
        .init(parameter: .destination, operation: .assign, value: .object(.init(type: .tag, id: tag.id)))
    }
    private func tags(_ items: [TagItem]) -> CommandArgument { .init(parameter: .tags, operation: .assign, value: .tags(items.map(\.id))) }
    private func ids(_ encoded: String) -> Set<UUID> { Set(TagIDList.parse(encoded)) }

    /// 与原标签页同一入口：结果与直接调用 mergeTags 一致；关联改挂目标，来源进回收站。
    @Test func mergeOrdinaryTagsMatchesTheTagPage() throws {
        let f = try SimpleCommandFixture(organize: true)
        let todo = TodoItem(title: "合并待办", dayKey: "2026-10-20", tagIDs: TagIDList.encode([f.tags[0].id]))
        let routine = DailyRoutine(title: "合并习惯", sortOrder: 0, createdDayKey: "2026-10-01")
        routine.tagIDs = TagIDList.encode([f.tags[1].id])
        f.context.insert(todo)
        f.context.insert(routine)
        try f.context.save()
        try f.queue("tag.merge", targets: [f.target(f.tags[0])], arguments: [destination(f.tags[1])])
        let preview = try f.preview()
        #expect(preview.before.changes(to: preview.after).map(\.field) == ["state", "links"])
        let facts = try f.submit(f.adapter.accept(preview, expecting: f.handoff.owned().lease))
        #expect(facts.state == .saved && f.count("save") == 1)
        #expect(f.tags[0].deletedAt != nil && f.tags[1].deletedAt == nil)
        #expect(ids(todo.tagIDs) == [f.tags[1].id] && ids(routine.tagIDs) == [f.tags[1].id])
        // 原页面路径（DayBoardMutations.mergeTags → 同一仓储）在另一份合成库里得到同样的结果。
        let page = try SimpleCommandFixture()
        let pageTodo = TodoItem(title: "合并待办", dayKey: "2026-10-20", tagIDs: TagIDList.encode([page.tags[0].id]))
        page.context.insert(pageTodo)
        try page.context.save()
        #expect(DayBoardMutations.mergeTags(sourceIDs: [page.tags[0].id], into: page.tags[1].id, context: page.context))
        #expect(page.tags[0].deletedAt != nil && ids(pageTodo.tagIDs) == [page.tags[1].id])
    }

    /// 来源或目标里有私密标签就整条拒绝，不写库；预置标签与原页面一样不能参与。
    @Test func mergeInvolvingPrivateOrPresetTagsIsRejected() throws {
        let f = try SimpleCommandFixture(organize: true)
        try f.queue("tag.merge", targets: [f.target(f.tags[2])], arguments: [destination(f.tags[0])])
        #expect(throws: CommandSimpleIssue.invalidTarget(.protected)) { try f.preview() }
        let into = try SimpleCommandFixture(organize: true)
        try into.queue("tag.merge", targets: [into.target(into.tags[0])], arguments: [destination(into.tags[2])])
        #expect(throws: CommandSimpleIssue.invalidTarget(.protected)) { try into.preview() }
        let preset = try SimpleCommandFixture(isPreset: { $0.name == "工作 · Work" }, organize: true)
        try preset.queue("tag.merge", targets: [preset.target(preset.tags[0])], arguments: [destination(preset.tags[1])])
        #expect(throws: CommandSimpleIssue.invalidTarget(.protected)) { try preset.preview() }
        #expect(f.count("save") + into.count("save") + preset.count("save") == 0)
        #expect(f.tags.allSatisfy { $0.deletedAt == nil })
        // 只剩目标自己时没有可合并的来源。
        let alone = try SimpleCommandFixture(organize: true)
        try alone.queue("tag.merge", targets: [alone.target(alone.tags[0])], arguments: [destination(alone.tags[0])])
        #expect(throws: CommandSimpleIssue.invalidArguments) { try alone.preview() }
    }

    @Test func unlinkRemovesTagsFromTasksAndOrdinaryDiaries() throws {
        let f = try SimpleCommandFixture(organize: true)
        let both = TagIDList.encode([f.tags[0].id, f.tags[1].id])
        let todo = TodoItem(title: "解绑待办", dayKey: "2026-10-20", tagIDs: both)
        let child = SubtaskItem(title: "解绑子任务", sortOrder: 0)
        child.todo = todo
        child.tagIDs = TagIDList.encode([f.tags[0].id])
        let routine = DailyRoutine(title: "解绑习惯", sortOrder: 0, createdDayKey: "2026-10-01")
        routine.tagIDs = TagIDList.encode([f.tags[0].id])
        let diary = DiaryEntry(text: "普通手记\n第二行", dayKey: "2026-10-20", tagIDs: TagIDList.encode([f.tags[0].id]))
        f.context.insert(todo)
        f.context.insert(child)
        f.context.insert(routine)
        f.context.insert(diary)
        try f.context.save()
        let targets: [CommandObjectReference] = [.init(type: .todo, id: todo.id), .init(type: .subtask, id: child.id),
                                                 .init(type: .routine, id: routine.id), .init(type: .diary, id: diary.id)]
        try f.queue("tag.unlinkObject", targets: targets, arguments: [tags([f.tags[0]])])
        let preview = try f.preview()
        #expect(preview.after.rows.count == 4 && preview.after.rows.last?.title == "普通手记")
        let facts = try f.submit(f.adapter.accept(preview, expecting: f.handoff.owned().lease))
        #expect(facts.state == .saved && f.count("save") == 1)
        #expect(ids(todo.tagIDs) == [f.tags[1].id])
        #expect(ids(child.tagIDs).isEmpty && ids(routine.tagIDs).isEmpty && ids(diary.tagIDs).isEmpty)
        #expect(f.tags[0].deletedAt == nil)
    }

    /// 隐私门禁：私密手记、挂着私密标签的手记都拿不到资格，整条拒绝，不读正文、不写库。
    @Test func unlinkFromProtectedDiaryIsRejected() throws {
        for privateEntry in [true, false] {
            let f = try SimpleCommandFixture(organize: true)
            let diary = DiaryEntry(text: "受保护", dayKey: "2026-10-20",
                                   tagIDs: TagIDList.encode(privateEntry ? [f.tags[0].id] : [f.tags[0].id, f.tags[2].id]))
            diary.isPrivate = privateEntry
            f.context.insert(diary)
            try f.context.save()
            try f.queue("tag.unlinkObject", targets: [.init(type: .diary, id: diary.id)], arguments: [tags([f.tags[0]])])
            #expect(throws: CommandSimpleIssue.invalidTarget(.protectedSource)) { try f.preview() }
            #expect(f.count("save") == 0 && ids(diary.tagIDs).contains(f.tags[0].id))
        }
        let guarded = try SimpleCommandFixture(organize: true)
        let todo = TodoItem(title: "受保护来源", dayKey: "2026-10-20", tagIDs: TagIDList.encode([guarded.tags[0].id]))
        guarded.context.insert(todo)
        try guarded.context.save()
        guarded.protected = [todo.id]
        try guarded.queue("tag.unlinkObject", targets: [.init(type: .todo, id: todo.id)], arguments: [tags([guarded.tags[0]])])
        #expect(throws: CommandSimpleIssue.invalidTarget(.protectedSource)) { try guarded.preview() }
    }

    /// 回收：确认面板列出受影响的对象数；未确认不能提交；结果与原标签页的“删除”一致（进回收站、关联保留）。
    @Test func trashNeedsConfirmationAndMatchesThePage() throws {
        let f = try SimpleCommandFixture(organize: true)
        let todo = TodoItem(title: "挂着工作", dayKey: "2026-10-20", tagIDs: TagIDList.encode([f.tags[0].id]))
        let diary = DiaryEntry(text: "也挂着", dayKey: "2026-10-20", tagIDs: TagIDList.encode([f.tags[0].id]))
        f.context.insert(todo)
        f.context.insert(diary)
        try f.context.save()
        #expect(f.adapter.supports(.init(rawValue: "tag.trash")) && f.adapter.needsConfirmation(.init(rawValue: "tag.trash")))
        try f.queue("tag.trash", targets: [f.target(f.tags[0])])
        let accepted = try f.accept()
        #expect(accepted.preview.after.notices == [.init(key: "unified.simple.tag.trash.affected", title: "2")])
        #expect(throws: CommandSimpleIssue.confirmationRequired) { try f.submit(accepted) }
        #expect(f.count("save") == 0 && f.tags[0].deletedAt == nil)
        let confirmation = try f.adapter.confirm(accepted, expecting: f.handoff.owned().lease)
        #expect(confirmation.summary.notices.first?.title == "2" && confirmation.titles == [f.tags[0].name])
        let facts = try f.submit(accepted)
        #expect(facts.state == .saved && f.count("save") == 1 && f.tags[0].deletedAt != nil)
        #expect(ids(todo.tagIDs) == [f.tags[0].id])
        let page = try SimpleCommandFixture()
        #expect(DayBoardMutations.batchTrashTags(ids: [page.tags[0].id], context: page.context))
        #expect(page.tags[0].deletedAt != nil)
    }

    @Test func restoreNeedsConfirmationAndOnlyTakesTrashedTags() throws {
        let f = try SimpleCommandFixture(organize: true)
        try f.queue("tag.restore", targets: [f.target(f.deleted)])
        let accepted = try f.accept()
        #expect(throws: CommandSimpleIssue.confirmationRequired) { try f.submit(accepted) }
        _ = try f.adapter.confirm(accepted, expecting: f.handoff.owned().lease)
        #expect(try f.submit(accepted).state == .saved && f.deleted.deletedAt == nil)
        let page = try SimpleCommandFixture()
        #expect(DayBoardMutations.batchRestoreTags([page.deleted]) && page.deleted.deletedAt == nil)
        let live = try SimpleCommandFixture(organize: true)
        try live.queue("tag.restore", targets: [live.target(live.tags[0])])
        #expect(throws: CommandSimpleIssue.invalidTarget(.notTrashed)) { try live.preview() }
    }

    /// 确认只绑当前接受：重新接受（预览变了）撤销旧确认；取消也撤销。回收不进多项计划。
    @Test func confirmationIsBoundToTheAcceptanceAndSingleItemOnly() throws {
        let f = try SimpleCommandFixture(organize: true)
        try f.queue("tag.trash", targets: [f.target(f.tags[1])])
        let first = try f.accept()
        let confirmation = try f.adapter.confirm(first, expecting: f.handoff.owned().lease)
        f.handoff.coordinator.simples.cancel(confirmation)
        #expect(throws: CommandSimpleIssue.confirmationRequired) { try f.submit(first) }
        _ = try f.adapter.confirm(first, expecting: f.handoff.owned().lease)
        let todo = TodoItem(title: "新挂上", dayKey: "2026-10-20", tagIDs: TagIDList.encode([f.tags[1].id]))
        f.context.insert(todo)
        try f.context.save()
        // 受影响对象数变了：旧接受不再匹配，重新接受撤销旧确认。
        #expect(throws: CommandSimpleIssue.invalidTarget(.changed)) { try f.submit(first) }
        let second = try f.accept()
        #expect(second.id != first.id)
        #expect(throws: CommandSimpleIssue.confirmationRequired) { try f.submit(second) }
        let multi = MultiPlanCommandAdapter(coordinator: f.handoff.coordinator, adapters: .init())
        for command in ["tag.trash", "tag.restore", "image.trash"] {
            #expect(throws: CommandMultiPlanIssue.independentConfirmation) { try multi.family(for: .init(rawValue: command)) }
        }
        #expect(f.tags[1].deletedAt == nil)
    }
}
