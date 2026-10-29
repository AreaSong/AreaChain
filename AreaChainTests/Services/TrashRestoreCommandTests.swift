import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// trash.restore 与回收站页同一写入（TrashRestoreService）；必须经共用独立确认、只能单项；
/// 受保护手记及其图片、加密图片拒绝；拥有者也在回收站的图片不能单独恢复。
@Suite(.serialized) @MainActor struct TrashRestoreCommandTests {
    @MainActor final class Fixture {
        let base: SimpleCommandFixture
        let todo = TodoItem(title: "回收待办", dayKey: "2026-10-21")
        var context: ModelContext { base.context }
        var adapter: SimpleCommandAdapter { base.adapter }

        init() throws {
            base = try SimpleCommandFixture(restore: true)
            context.insert(todo)
            try context.save()
            let repo = SwiftDataTaskRepository(context: context)
            _ = try repo.addSubtask(to: todo.id, title: "子项一")
            _ = try repo.addSubtask(to: todo.id, title: "子项二")
            context.insert(AttachmentItem(ownerKind: "todo", ownerID: todo.id, filename: "附图.png"))
            try context.save()
            try repo.deleteTodo(id: todo.id, soft: true)
            base.io.trace.removeAll()
        }

        func queue(_ object: CommandObjectReference) throws { try base.queue("trash.restore", targets: [object]) }
        func confirmAndSubmit(_ accepted: CommandSimpleAcceptance) throws -> CommandSimpleFacts {
            _ = try adapter.confirm(accepted, expecting: base.handoff.owned().lease)
            return try base.submit(accepted)
        }
        func attachments() throws -> [AttachmentItem] { try context.fetch(FetchDescriptor<AttachmentItem>()) }
    }

    @Test func todoComesBackWithChildrenLikeTheTrashPage() throws {
        let f = try Fixture()
        #expect(f.todo.deletedAt != nil && f.todo.subtasks.allSatisfy { $0.deletedAt != nil })
        #expect(f.adapter.supports(.init(rawValue: "trash.restore")) && f.adapter.needsConfirmation(.init(rawValue: "trash.restore")))
        try f.queue(.init(type: .todo, id: f.todo.id))
        let accepted = try f.base.accept()
        #expect(accepted.preview.after.notices.map(\.title) == ["2", "1"], "确认面板列出随之恢复的子任务与图片")
        #expect(throws: CommandSimpleIssue.confirmationRequired) { try f.base.submit(accepted) }
        #expect(f.todo.deletedAt != nil && f.base.count("save") == 0)
        let facts = try f.confirmAndSubmit(accepted)
        #expect(facts.state == .saved && f.base.count("save") == 1)
        #expect(f.todo.deletedAt == nil && f.todo.subtasks.allSatisfy { $0.deletedAt == nil })
        #expect(try f.attachments().allSatisfy { $0.deletedAt == nil })
        // 回收站页入口（TrashRow.restore → DayBoardMutations.restoreTodo → 同一写入）在另一份合成库里结果一致。
        let page = try Fixture()
        #expect(DayBoardMutations.restoreTodo(page.todo))
        #expect(page.todo.deletedAt == nil && page.todo.subtasks.allSatisfy { $0.deletedAt == nil })
        #expect(try page.attachments().allSatisfy { $0.deletedAt == nil })
    }

    /// 每个场景一份新的合成库：只排一条计划，互不影响。
    private func trashed(_ insert: (ModelContext) throws -> CommandObjectReference) throws -> (Fixture, CommandObjectReference) {
        let f = try Fixture()
        let object = try insert(f.context)
        try f.context.save()
        f.base.io.trace.removeAll()
        try f.queue(object)
        return (f, object)
    }

    @Test func otherKindsRestoreAndLiveOrOrphanTargetsAreRejected() throws {
        let (r, routineRef) = try trashed { context in
            let routine = DailyRoutine(title: "回收习惯", sortOrder: 0, createdDayKey: "2026-10-01")
            context.insert(routine)
            try context.save()
            try SwiftDataRoutineRepository(context: context).deleteRoutine(id: routine.id, soft: true)
            return .init(type: .routine, id: routine.id)
        }
        #expect(try r.confirmAndSubmit(r.base.accept()).state == .saved)
        #expect(try r.context.fetch(FetchDescriptor<DailyRoutine>()).first { $0.id == routineRef.id }?.deletedAt == nil)
        let (d, diaryRef) = try trashed { context in
            let diary = DiaryEntry(text: "普通手记\n正文", dayKey: "2026-10-21")
            context.insert(diary)
            try context.save()
            try SwiftDataDiaryRepository(context: context).deleteDiary(id: diary.id, soft: true)
            return .init(type: .diary, id: diary.id)
        }
        #expect(try d.confirmAndSubmit(d.base.accept()).state == .saved)
        #expect(try d.context.fetch(FetchDescriptor<DiaryEntry>()).first { $0.id == diaryRef.id }?.deletedAt == nil)
        let tag = try SimpleCommandFixture(restore: true)
        try tag.queue("trash.restore", targets: [tag.target(tag.deleted)])
        let accepted = try tag.accept()
        _ = try tag.adapter.confirm(accepted, expecting: tag.handoff.owned().lease)
        #expect(try tag.submit(accepted).state == .saved && tag.deleted.deletedAt == nil)
        // 拥有者（待办）还在回收站：图片不能单独恢复；活对象不在回收站里。
        let (o, _) = try trashed { context in
            let orphan = AttachmentItem(ownerKind: "todo", ownerID: UUID(), filename: "孤儿.png")
            context.insert(orphan)
            orphan.deletedAt = .now
            return .init(type: .image, id: orphan.id)
        }
        #expect(throws: CommandSimpleIssue.invalidTarget(.ownerTrashed)) { try o.base.preview() }
        let (owned, _) = try trashed { context in
            let fixtureTodo = try context.fetch(FetchDescriptor<TodoItem>()).first!
            let image = AttachmentItem(ownerKind: "todo", ownerID: fixtureTodo.id, filename: "随父.png")
            context.insert(image)
            image.deletedAt = .now
            return .init(type: .image, id: image.id)
        }
        #expect(throws: CommandSimpleIssue.invalidTarget(.ownerTrashed)) { try owned.base.preview() }
        let live = try SimpleCommandFixture(restore: true)
        try live.queue("trash.restore", targets: [live.target(live.tags[0])])
        #expect(throws: CommandSimpleIssue.invalidTarget(.notTrashed)) { try live.preview() }
        #expect(o.base.count("save") + owned.base.count("save") == 0)
    }

    @Test func protectedDiariesAndImagesAreRejected() throws {
        var saves = 0
        for kind in 0..<4 {
            let (f, _) = try trashed { context in
                let secret = DiaryEntry(text: "私密手记", dayKey: "2026-10-21")
                secret.isPrivate = true
                context.insert(secret)
                secret.deletedAt = .now
                switch kind {
                case 0: return .init(type: .diary, id: secret.id)
                case 1:
                    let privateTag = try context.fetch(FetchDescriptor<TagItem>()).first { $0.isPrivateDiary }!
                    let tagged = DiaryEntry(text: "挂私密标签", dayKey: "2026-10-21", tagIDs: TagIDList.encode([privateTag.id]))
                    context.insert(tagged)
                    tagged.deletedAt = .now
                    return .init(type: .diary, id: tagged.id)
                case 2:
                    let sealed = AttachmentItem(ownerKind: "routine", ownerID: UUID(), filename: "加密.png")
                    sealed.privacyVaultID = UUID()
                    context.insert(sealed)
                    sealed.deletedAt = .now
                    return .init(type: .image, id: sealed.id)
                default:
                    let image = AttachmentItem(ownerKind: "diary", ownerID: secret.id, filename: "私密附图.png")
                    context.insert(image)
                    image.deletedAt = .now
                    return .init(type: .image, id: image.id)
                }
            }
            #expect(throws: CommandSimpleIssue.invalidTarget(.protectedSource), "场景 \(kind)") { try f.base.preview() }
            saves += f.base.count("save")
        }
        #expect(saves == 0)
    }

    @Test func singleItemOnlyAndCatalogStaysConfirmed() throws {
        let catalog = try #require(CommandCatalog.standard.command(id: .init(rawValue: "trash.restore")))
        #expect(catalog.category == .modification && catalog.queue == .eligibleAfterWiring)
        #expect(catalog.interactions.contains(.independentConfirmation) && catalog.batch == .singleOnly)
        let f = try Fixture()
        let multi = MultiPlanCommandAdapter(coordinator: f.base.handoff.coordinator, adapters: .init())
        #expect(throws: CommandMultiPlanIssue.independentConfirmation) { try multi.family(for: .init(rawValue: "trash.restore")) }
        #expect(!CommandSimpleShape.singleAny(TrashRestoreService.types).allows(.init(.selected, objects: [
            .init(type: .todo, id: f.todo.id), .init(type: .tag, id: f.base.deleted.id),
        ])))
    }
}
