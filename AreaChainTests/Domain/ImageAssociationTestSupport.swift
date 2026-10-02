import Foundation
@testable import AreaChain

enum ImageAssociationFixture {
    static let date = Date(timeIntervalSince1970: 1_700_000_000)
    static let key = AttachmentOwnerKey(kind: .todo, id: UUID(uuidString: "71000000-0000-0000-0000-000000000001")!)
    static var secret: String { ["IMAGE", "SYNTHETIC", "PRIVATE", "MARKER"].joined(separator: "_") }

    static func todo(_ id: UUID = key.id) -> TodoSnapshot {
        .init(id: id, title: secret, isDone: false, dayKey: "2026-10-01", createdAt: date, notes: secret)
    }
    static func routine(_ id: UUID = key.id) -> RoutineSnapshot {
        .init(id: id, title: secret, sortOrder: 0, isEnabled: true, createdDayKey: "2026-09-01", createdAt: date)
    }
    static func diary(_ id: UUID = key.id) -> DiarySnapshot {
        .init(id: id, text: secret, dayKey: "2026-10-01", createdAt: date)
    }
    static func image(owner: AttachmentOwnerKey = key, id: UUID = UUID()) -> ImageAttachmentMetadata {
        .init(id: id, ownerKind: owner.kind.rawValue, ownerID: owner.id, filename: "synthetic.png",
              createdAt: date, deletedAt: nil, protection: .unprotected)
    }
    static var coverage: ImageAssociationCoverage {
        let types: [AttachmentOwner: ImageReadCompleteness] = [
            .todo: .completeIncludingDeleted, .routine: .completeIncludingDeleted, .diary: .completeIncludingDeleted
        ]
        return .init(owners: .init(types: types), associations: .init(types: types),
                     imageIdentities: .init(allIDs: .completeIncludingDeleted), diaryPrivacy: .init(types: types))
    }
    static func request(
        images: [ImageAttachmentMetadata]? = [], owners: ImageOwnerSnapshots = .init(todos: [todo()], routines: [], diaries: []),
        coverage: ImageAssociationCoverage = coverage, privacy: DiaryQueryMetadata = .init(tagNames: [:], privateTagIDs: [])
    ) -> ImageAssociationRequest {
        .init(images: images, owners: owners, privacy: privacy, coverage: coverage)
    }
    static func containsSecret(_ value: Any) -> Bool {
        if let text = value as? String { return text.contains(secret) }
        return Mirror(reflecting: value).children.contains { containsSecret($0.value) }
    }
}
