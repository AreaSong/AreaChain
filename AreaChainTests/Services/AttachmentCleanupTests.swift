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
        #expect(ModelChanges.perform(in: context) { try row.removeFromStore(context) })
        #expect(try context.fetchCount(FetchDescriptor<DiaryEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<AttachmentItem>()) == 1)
        try AttachmentCleanup.purge(ids: Set(row.filesToRemove), context: context, removeFile: { _ in })
        #expect(try context.fetchCount(FetchDescriptor<AttachmentItem>()) == 0)
    }

    @Test func emptyTrashFileIDsIncludeLiveAttachmentsOfPurgedOwners() throws {
        let container = try container()
        let context = container.mainContext
        let todo = TodoItem(title: "trashed", dayKey: "2026-09-12", deletedAt: Date(timeIntervalSince1970: 3))
        let live = AttachmentItem(
            ownerKind: AttachmentOwner.todo.rawValue, ownerID: todo.id, filename: "orphan.png"
        )
        let tombstone = AttachmentItem(
            ownerKind: AttachmentOwner.todo.rawValue, ownerID: todo.id, filename: "gone.png",
            deletedAt: Date(timeIntervalSince1970: 3)
        )
        let neighbor = TodoItem(title: "keep", dayKey: "2026-09-12")
        let other = AttachmentItem(
            ownerKind: AttachmentOwner.todo.rawValue, ownerID: neighbor.id, filename: "other.png"
        )
        let diary = AttachmentItem(
            ownerKind: AttachmentOwner.diary.rawValue, ownerID: todo.id, filename: "diary.png"
        )
        context.insert(todo)
        context.insert(live)
        context.insert(tombstone)
        context.insert(neighbor)
        context.insert(other)
        context.insert(diary)
        try context.save()

        let listed = try #require(TrashRow.todo(todo, attachments: [tombstone])).filesToRemove
        #expect(Set(listed) == [tombstone.id])
        let ids = try AttachmentCleanup.fileIDs(
            listed: listed,
            purgedOwners: [AttachmentOwnerKey(kind: .todo, id: todo.id)],
            context: context
        )
        #expect(ids == [live.id, tombstone.id])
        #expect(!ids.contains(other.id))
        #expect(!ids.contains(diary.id))
        #expect(try AttachmentCleanup.fileIDs(listed: [], purgedOwners: [], context: context).isEmpty)
    }
}
