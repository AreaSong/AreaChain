import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// image.trash 与详情面板、附件中心同一写入（只打删除戳）；资格同附件中心——孤儿与受保护附件拒绝；
/// 必须经共用独立确认。
@Suite(.serialized) @MainActor struct ImageCommandTests {
    @MainActor final class Fixture {
        let base: SimpleCommandFixture
        let todo = TodoItem(title: "带图待办", dayKey: "2026-10-20")
        let image: AttachmentItem
        let adapter: SimpleCommandAdapter
        var context: ModelContext { base.context }

        init() throws {
            base = try SimpleCommandFixture()
            image = AttachmentItem(ownerKind: "todo", ownerID: todo.id, filename: "合成图.png")
            base.context.insert(todo)
            base.context.insert(image)
            try base.context.save()
            adapter = .init(coordinator: base.handoff.coordinator, environment: base.environment,
                            specs: ImageCommandSpecs.all(), capability: .open)
        }

        func queue(_ item: AttachmentItem) throws {
            try base.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "image.trash"),
                                         targets: .init(.single, objects: [.init(type: .image, id: item.id)])))
        }
        func preview() throws -> CommandSimplePreview {
            try adapter.prepare(plan: base.handoff.state().plan.stamp, expecting: base.handoff.owned().lease)
        }
        func accept() throws -> CommandSimpleAcceptance { try adapter.accept(preview(), expecting: base.handoff.owned().lease) }
    }

    @Test func ordinaryImageIsTrashedOnlyAfterConfirmation() throws {
        let f = try Fixture()
        #expect(f.adapter.supports(.init(rawValue: "image.trash")) && f.adapter.needsConfirmation(.init(rawValue: "image.trash")))
        try f.queue(f.image)
        let accepted = try f.accept()
        #expect(accepted.preview.after.notices == [.init(key: "unified.simple.image.owner.todo", title: "合成图.png")])
        #expect(throws: CommandSimpleIssue.confirmationRequired) {
            try f.adapter.submit(accepted: accepted, expecting: f.base.handoff.owned().lease)
        }
        #expect(f.image.deletedAt == nil && f.base.count("save") == 0)
        _ = try f.adapter.confirm(accepted, expecting: f.base.handoff.owned().lease)
        let facts = try f.adapter.submit(accepted: accepted, expecting: f.base.handoff.owned().lease)
        #expect(facts.state == .saved && f.base.count("save") == 1 && f.image.deletedAt != nil)
        #expect(f.image.ownerID == f.todo.id && f.todo.deletedAt == nil)
        // 原详情面板入口（DayBoardMutations.trashAttachment → 同一写入）在另一份合成库里结果一致。
        let page = try Fixture()
        #expect(DayBoardMutations.trashAttachment(page.image) && page.image.deletedAt != nil && page.image.ownerID == page.todo.id)
    }

    /// 孤儿规则同附件中心：拥有者已删或不存在的附件不在附件中心里，拒绝；不会顺带改拥有者。
    @Test func orphanImagesAreRejectedLikeTheAttachmentCenter() throws {
        let deletedOwner = try Fixture()
        deletedOwner.todo.deletedAt = .now
        try deletedOwner.context.save()
        try deletedOwner.queue(deletedOwner.image)
        #expect(throws: CommandSimpleIssue.invalidTarget(.notListed)) { try deletedOwner.preview() }
        let missing = try Fixture()
        let stray = AttachmentItem(ownerKind: "routine", ownerID: UUID(), filename: "无主图.png")
        missing.context.insert(stray)
        try missing.context.save()
        try missing.queue(stray)
        #expect(throws: CommandSimpleIssue.invalidTarget(.notListed)) { try missing.preview() }
        let trashed = try Fixture()
        trashed.image.deletedAt = .now
        try trashed.context.save()
        try trashed.queue(trashed.image)
        #expect(throws: CommandSimpleIssue.invalidTarget(.deleted)) { try trashed.preview() }
        #expect(deletedOwner.base.count("save") + missing.base.count("save") + trashed.base.count("save") == 0)
    }

    /// 受保护附件需要解锁，指令里不认证：加密附件与敏感手记的图片一律拒绝。
    @Test func protectedImagesAreRejected() throws {
        let sealed = try Fixture()
        sealed.image.privacyVaultID = UUID()
        try sealed.context.save()
        try sealed.queue(sealed.image)
        #expect(throws: CommandSimpleIssue.invalidTarget(.protectedSource)) { try sealed.preview() }
        let diary = try Fixture()
        let entry = DiaryEntry(text: "私密", dayKey: "2026-10-20")
        entry.isPrivate = true
        let picture = AttachmentItem(ownerKind: "diary", ownerID: entry.id, filename: "手记图.png")
        diary.context.insert(entry)
        diary.context.insert(picture)
        try diary.context.save()
        try diary.queue(picture)
        #expect(throws: CommandSimpleIssue.invalidTarget(.protectedSource)) { try diary.preview() }
        #expect(sealed.image.deletedAt == nil && picture.deletedAt == nil)
    }
}
