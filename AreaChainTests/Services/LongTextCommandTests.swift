import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 服务层：三条长文指令经 prepare → accept → 托管封存 → 借用 → 提交的完整流程；
/// 私密／预置标签在预览时就判为不可执行；原界面保存行为不变。
@Suite(.serialized) @MainActor struct LongTextCommandTests {
    static let commands: [(String, CommandObjectType?)] = [("todo.notes", .todo), ("routine.notes", .routine), ("routine.capture", nil)]

    /// 按指令放一个目标并入队带该正文的草稿。
    static func queue(_ f: TaskSimpleFixture, _ command: String, _ type: CommandObjectType?, text: String) throws {
        switch type {
        case .todo?:
            let todo = try f.insert(TodoItem(title: "待办", dayKey: TaskSimpleFixture.today, notes: "原"))
            try f.queue(command, targets: [.init(type: .todo, id: todo.id)], arguments: [f.notes(.append, text)])
        case .routine?:
            let routine = try f.insert(DailyRoutine(title: "习惯", sortOrder: 0, createdDayKey: "2026-10-01", notes: "原"))
            try f.queue(command, targets: [.init(type: .routine, id: routine.id)], arguments: [f.notes(.append, text)])
        default: try f.queue(command, arguments: [f.body(text)])
        }
    }

    @Test(arguments: commands)
    func privateTagMakesCommandNotExecutable(_ command: String, _ type: CommandObjectType?) throws {
        let f = try TaskSimpleFixture(longText: true)
        try f.insert(TagItem(name: "私密", sortOrder: 0, isPrivateDiary: true))
        try f.insert(TagItem(name: "旧私密", sortOrder: 1, deletedAt: .now, isPrivateDiary: true))
        try f.insert(TagItem(name: "普通", sortOrder: 2))
        try Self.queue(f, command, type, text: "标题 #私密 #旧私密 #普通 #新建")
        let preview = try f.preview()
        #expect(!preview.executable)
        #expect(preview.after.notices == [.init(key: "unified.simple.notice.privateTag", title: "私密", blocking: true),
                                         .init(key: "unified.simple.notice.privateTag", title: "旧私密", blocking: true)])
        // 普通、新建标签照常逐行列出；只是整条不可接受。
        let changes = preview.before.changes(to: preview.after)
        #expect(changes.contains { $0.title == "#新建" && $0.before == nil })
        #expect(throws: CommandSimpleIssue.invalidTarget(.protectedTag)) {
            try f.adapter.accept(preview, expecting: f.handoff.owned().lease)
        }
        #expect(throws: (any Error).self) { try f.handoff.send(.sealPlan(f.handoff.state().plan.stamp, runID: UUID())) }
        #expect(f.count("save") == 0 && f.escrow.count == 0 && f.handoff.coordinator.simples.acceptances.isEmpty)
        #expect(try f.stored(TagItem.self).count == 3)
    }

    /// 同一判定，结果不同——指令整条拒绝（上一用例），详情页照常保存文字、不关联私密标签并提示。
    @Test func detailPanelSavesTextButSkipsPrivateTag() throws {
        let f = try TaskSimpleFixture(longText: true)
        _ = try f.insert(TagItem(name: "私密", sortOrder: 0, isPrivateDiary: true))
        let todo = try f.insert(TodoItem(title: "界面", dayKey: TaskSimpleFixture.today))
        #expect(TaskNotesService.save("界面保存 #私密", for: todo, in: f.context, repository: SwiftDataTaskRepository(context: f.context),
                                      requestReminderAccess: { _ in }))
        #expect(todo.notes == "界面保存 #私密" && TagIDList.parse(todo.tagIDs).isEmpty)
        #expect(MutationFeedback.shared.lastSkippedTags == ["私密"])
    }

    /// 预置名在任务备注里不被解析成标签（沿 TagSyntax），因此不会关联；规则本身与命令标签一致地拒绝预置名。
    @Test func presetNamesAreRejectedByTheSameRule() throws {
        let f = try TaskSimpleFixture(longText: true)
        let notices = try TaskDerivedRows.protectedTagNotices(["日记", "普通"], in: f.context)
        #expect(notices == [.init(key: "unified.simple.notice.presetTag", title: "日记", blocking: true)])
        try Self.queue(f, "todo.notes", .todo, text: "写 #日记")
        let preview = try f.preview()
        #expect(preview.executable && !preview.after.rows.contains { $0.key.hasPrefix("tag:") })
    }

    /// 习惯备注固定多目标：一次借用、一次事务写全部；预览逐项列出，回执沿原 Run。
    @Test func routineNotesWritesAllFrozenTargetsOnce() throws {
        let f = try TaskSimpleFixture(longText: true)
        let routines = try (0..<3).map { try f.insert(DailyRoutine(title: "习惯\($0)", sortOrder: $0, createdDayKey: "2026-10-01",
                                                                   notes: $0 == 0 ? "" : "原\($0)")) }
        let (accepted, facts) = try f.run("routine.notes", targets: routines.map { .init(type: .routine, id: $0.id) }, single: false,
                                          arguments: [f.notes(.append, "共同追加 !p3")])
        #expect(Set(accepted.preview.before.changes(to: accepted.preview.after).map(\.key)).count == 3)
        #expect(facts.state == .saved && f.count("save") == 1 && f.escrow.count == 0)
        #expect(routines.map(\.notes) == ["共同追加 !p3", "原1\n共同追加 !p3", "原2\n共同追加 !p3"])
        #expect(routines.allSatisfy { !$0.isImportant && $0.isUrgent })
    }

    /// 快速新增：回执给出“打开新习惯”的位置（今天的执行日，父对象为新习惯）；其他两条没有。
    @Test func captureReceiptOffersOpeningTheNewHabit() throws {
        let f = try TaskSimpleFixture(longText: true)
        let (_, facts) = try f.run("routine.capture", arguments: [f.body("散步 @19:00")])
        let creation = try #require(facts.creation)
        #expect(f.adapter.openTarget(facts) == .init(object: .init(type: .routineOccurrence, id: creation.id,
                                                                    dayKey: TaskSimpleFixture.today),
                                                      parent: creation, viewingTrash: false))
        let g = try TaskSimpleFixture(longText: true)
        let todo = try g.insert(TodoItem(title: "无新对象", dayKey: TaskSimpleFixture.today))
        let (_, notes) = try g.run("todo.notes", targets: [.init(type: .todo, id: todo.id)], arguments: [g.notes(.replace, "x")])
        #expect(notes.state == .saved && g.adapter.openTarget(notes) == nil)
    }
}
