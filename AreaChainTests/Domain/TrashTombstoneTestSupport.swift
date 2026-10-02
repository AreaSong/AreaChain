import Foundation
@testable import AreaChain

enum TrashFixture {
    static let date = Date(timeIntervalSince1970: 1_790_870_400)
    static let parentID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let childID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let imageID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    static let otherID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!

    static func ref(_ type: CommandObjectType, _ id: UUID = parentID) -> CommandObjectReference {
        .init(type: type, id: id)
    }

    static func todo(_ id: UUID = parentID, deleted: Date? = date) -> TodoSnapshot {
        .init(id: id, title: "合成任务", isDone: false, dayKey: "2026-10-02", createdAt: date, deletedAt: deleted)
    }

    static func child(_ id: UUID = childID, parent: UUID = parentID, deleted: Date? = date) -> SubtaskSnapshot {
        .init(id: id, todoId: parent, title: "合成子任务", isDone: false, createdAt: date, deletedAt: deleted)
    }

    static func routine(_ id: UUID = parentID, deleted: Date? = date) -> RoutineSnapshot {
        .init(id: id, title: "合成习惯", sortOrder: 0, isEnabled: false,
              createdDayKey: "2026-10-02", createdAt: date, deletedAt: deleted)
    }

    static func diary(_ id: UUID = parentID, deleted: Date? = date) -> DiarySnapshot {
        .init(id: id, text: "合成正文", dayKey: "2026-10-02", createdAt: date, deletedAt: deleted)
    }

    static func image(_ id: UUID = imageID, owner: AttachmentOwner = .todo,
                      parent: UUID = parentID, deleted: Date? = date) -> ImageAttachmentMetadata {
        .init(id: id, ownerKind: owner.rawValue, ownerID: parent, filename: "synthetic.png",
              createdAt: date, deletedAt: deleted, protection: .unprotected)
    }

    static func input() -> TrashTombstoneInput {
        .init(todos: [], subtasks: [], routines: [], diaries: [], tags: [], images: [],
              privacy: .init(tagNames: [:], privateTagIDs: []),
              coverage: .init(types: Dictionary(uniqueKeysWithValues: TrashTombstoneIndex.types.map {
                  ($0, .completeIncludingDeleted)
              }), diaryPrivacy: .init(types: [.diary: .completeIncludingDeleted])))
    }

    static func family() -> TrashTombstoneInput {
        var input = input()
        input.todos = [todo()]
        input.subtasks = [child()]
        input.images = [image()]
        return input
    }
}
