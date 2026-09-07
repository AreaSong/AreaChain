import Foundation
import SwiftData

@Model
final class ProjectItem {
    var id: UUID
    var name: String
    var sortOrder: Int
    var parentID: UUID?
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        sortOrder: Int,
        parentID: UUID? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.parentID = parentID
        self.deletedAt = deletedAt
    }
}

@Model
final class TagItem {
    var id: UUID
    var name: String
    var sortOrder: Int
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        sortOrder: Int,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.deletedAt = deletedAt
    }
}

@Model
final class AttachmentItem {
    var id: UUID
    var ownerKind: String
    var ownerID: UUID
    var filename: String
    var createdAt: Date
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        ownerKind: String,
        ownerID: UUID,
        filename: String,
        createdAt: Date = .now,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.ownerKind = ownerKind
        self.ownerID = ownerID
        self.filename = filename
        self.createdAt = createdAt
        self.deletedAt = deletedAt
    }
}
