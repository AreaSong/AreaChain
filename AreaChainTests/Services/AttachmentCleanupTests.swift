import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor
struct AttachmentCleanupTests {
    private func container() throws -> ModelContainer {
        try ModelContainer(for: Schema(AreaChainSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    @Test func cascadesRespectOwnerTypeEvenWhenIDsMatch() throws {
        let container = try container()
        let context = container.mainContext
        let id = UUID()
        let todo = TodoItem(id: id, title: "公开待办", dayKey: "2026-09-12")
        let diary = DiaryEntry(id: id, text: "#密码 私密手记", dayKey: "2026-09-12")
        let taskImage = AttachmentItem(ownerKind: "todo", ownerID: id, filename: "task.png")
        let privateImage = AttachmentItem(ownerKind: "diary", ownerID: id, filename: "private.png")
        context.insert(todo)
        context.insert(diary)
        context.insert(taskImage)
        context.insert(privateImage)
        try context.save()
        let repo = SwiftDataTaskRepository(container: container)
        try repo.deleteTodo(id: id, soft: true)
        #expect(taskImage.deletedAt != nil)
        #expect(privateImage.deletedAt == nil && diary.deletedAt == nil)
        try repo.restoreTodo(id: id)
        #expect(taskImage.deletedAt == nil && privateImage.deletedAt == nil)
    }

    @Test func failedFileDeletionLeavesMetadataForRetryAndContinuesOtherFiles() throws {
        let container = try container()
        let context = container.mainContext
        let first = AttachmentItem(ownerKind: "diary", ownerID: UUID(), filename: "private.png", deletedAt: .now)
        let second = AttachmentItem(ownerKind: "todo", ownerID: UUID(), filename: "other.png", deletedAt: .now)
        context.insert(first)
        context.insert(second)
        try context.save()
        let firstID = first.id
        let secondID = second.id
        var removed: Set<UUID> = []
        #expect(throws: AttachmentCleanupError.self) {
            try AttachmentCleanup.purge(ids: [firstID, secondID], context: context) { id in
                if id == firstID { throw CocoaError(.fileWriteNoPermission) }
                removed.insert(id)
            }
        }
        let remaining = try context.fetch(FetchDescriptor<AttachmentItem>())
        #expect(remaining.map(\.id) == [firstID])
        #expect(remaining[0].deletedAt != nil)
        #expect(removed == [secondID])
        try AttachmentCleanup.purge(ids: Set(remaining.map(\.id)), context: context) { removed.insert($0) }
        #expect(try context.fetchCount(FetchDescriptor<AttachmentItem>()) == 0)
        #expect(removed == [firstID, secondID])
    }

    @Test func purgingParentKeepsItsAttachmentTombstonesUntilFileCleanup() throws {
        let container = try container()
        let context = container.mainContext
        let diary = DiaryEntry(text: "#密码 测试", dayKey: "2026-09-12", deletedAt: .now)
        let image = AttachmentItem(ownerKind: "diary", ownerID: diary.id, filename: "private.png", deletedAt: .now)
        context.insert(diary)
        context.insert(image)
        try context.save()
        let row = try #require(TrashRow.diary(diary, attachments: [image], tags: { [] }, locale: .current))
        #expect(ModelChanges.perform(in: context) { row.removeFromStore(context) })
        #expect(try context.fetchCount(FetchDescriptor<DiaryEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<AttachmentItem>()) == 1)
        try AttachmentCleanup.purge(ids: Set(row.filesToRemove), context: context, removeFile: { _ in })
        #expect(try context.fetchCount(FetchDescriptor<AttachmentItem>()) == 0)
    }
}
