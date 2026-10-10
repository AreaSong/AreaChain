import Foundation
import SwiftData

/// 原搜索读取时记录的实体身份及元数据；没有正文、图片字节或可执行参数。
struct WorkspaceContentSource: Equatable {
    var tags: Set<Tag> = []
    var diaries: Set<Diary> = []
    var images: Set<Image> = []
    var owners: Set<Owner> = []

    struct Tag: Hashable {
        let identity: PersistentIdentifier
        let id: UUID
        let name: String
        let order: Int
        let deleted: Date?
        let isPrivate: Bool
        let color: String
        @MainActor init(_ row: TagItem) {
            identity = row.persistentModelID; id = row.id; name = row.name; order = row.sortOrder
            deleted = row.deletedAt; isPrivate = row.isPrivateDiary; color = row.colorToken
        }
    }

    struct Diary: Hashable {
        let identity: PersistentIdentifier
        let id: UUID
        let day: String
        let created: Date
        let deleted: Date?
        let tags: String
        let pinned: Bool
        let isPrivate: Bool
        let encrypted: Bool
        let vault: UUID?
        @MainActor init(_ row: DiaryEntry) {
            identity = row.persistentModelID; id = row.id; day = row.dayKey; created = row.createdAt
            deleted = row.deletedAt; tags = row.tagIDs; pinned = row.isPinned; isPrivate = row.isPrivate
            encrypted = row.encryptedText != nil; vault = row.privacyVaultID
        }
    }

    struct Image: Hashable {
        let identity: PersistentIdentifier
        let id: UUID
        let ownerKind: String
        let ownerID: UUID
        let reference: AttachmentRef
        let deleted: Date?
        let created: Date
        let retired: UUID?
        @MainActor init(_ row: AttachmentItem) {
            identity = row.persistentModelID; id = row.id; ownerKind = row.ownerKind; ownerID = row.ownerID
            reference = row.reference; deleted = row.deletedAt; created = row.createdAt; retired = row.retiredStorageID
        }
    }

    struct Owner: Hashable {
        let identity: PersistentIdentifier
        let id: UUID
        let kind: String
        let title: String
        let tags: String
        let deleted: Date?
        let day: String
        let parent: UUID?
        @MainActor init(_ row: TodoItem) {
            identity = row.persistentModelID; id = row.id; kind = "todo"; title = row.title
            tags = row.tagIDs; deleted = row.deletedAt; day = row.dayKey; parent = nil
        }
        @MainActor init(_ row: DailyRoutine) {
            identity = row.persistentModelID; id = row.id; kind = "routine"; title = row.title
            tags = row.tagIDs; deleted = row.deletedAt; day = row.createdDayKey; parent = nil
        }
        @MainActor init(_ row: SubtaskItem) {
            identity = row.persistentModelID; id = row.id; kind = "subtask"; title = row.title
            tags = row.tagIDs; deleted = row.deletedAt; day = ""; parent = row.todo?.id
        }
    }
}

extension WorkspaceContentReader {
    func source() throws -> WorkspaceContentSource {
        let tags = try bodies.tags.allTags()
        let diaries = try bodies.diaries.allDiaries()
        guard tags.allSatisfy({ $0.modelContext === context }), diaries.allSatisfy({ $0.modelContext === context }) else {
            throw WorkspaceContentFailure.invalidTarget
        }
        let todos = try context.fetch(FetchDescriptor<TodoItem>())
        let routines = try context.fetch(FetchDescriptor<DailyRoutine>())
        let children = try context.fetch(FetchDescriptor<SubtaskItem>())
        let images = try context.fetch(FetchDescriptor<AttachmentItem>())
        return .init(tags: Set(tags.map(WorkspaceContentSource.Tag.init)),
            diaries: Set(diaries.map(WorkspaceContentSource.Diary.init)),
            images: Set(images.map(WorkspaceContentSource.Image.init)),
            owners: Set(todos.map(WorkspaceContentSource.Owner.init)
                + routines.map(WorkspaceContentSource.Owner.init) + children.map(WorkspaceContentSource.Owner.init)))
    }
}
