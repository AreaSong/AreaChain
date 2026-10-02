import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor
struct AttachmentBrowseCompatibilityTests {
    private typealias Fixture = ImageAssociationFixture

    @Test func pureFactsKeepLegacyGateTruthTable() {
        for kind in [AttachmentOwner.todo, .routine, .diary] {
            for live in [false, true] {
                for privateImage in [false, true] {
                    check(kind: kind, live: live, privateImage: privateImage)
                }
            }
        }
        #expect(!AttachmentAccess.canBrowse(.init(attachmentIsLive: true, hasPrivacyVault: false,
                                                 owner: nil, ownerIsSingleLive: true, diaryIsSensitive: false)))
    }

    private func check(kind: AttachmentOwner, live: Bool, privateImage: Bool) {
        for unique in [false, true] {
            for sensitive in [false, true] {
                let expected = live && !privateImage && unique && (kind != .diary || !sensitive)
                let facts = AttachmentBrowseFacts(attachmentIsLive: live, hasPrivacyVault: privateImage,
                    owner: .init(kind: kind, id: Fixture.key.id), ownerIsSingleLive: unique, diaryIsSensitive: sensitive)
                #expect(AttachmentAccess.canBrowse(facts) == expected)
            }
        }
    }

    @Test func syntheticMemoryEntitiesAgreeWithSnapshotReader() throws {
        let container = try ModelContainer(for: TodoItem.self, DailyRoutine.self, DiaryEntry.self,
            AttachmentItem.self, TagItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let todo = TodoItem(title: "合成", dayKey: "2026-10-01")
        let routine = DailyRoutine(title: "合成", sortOrder: 0, createdDayKey: "2026-10-01")
        let diary = DiaryEntry(text: "合成", dayKey: "2026-10-01")
        context.insert(todo)
        context.insert(routine)
        context.insert(diary)
        let keys = [AttachmentOwnerKey(kind: .todo, id: todo.id), .init(kind: .routine, id: routine.id),
                    .init(kind: .diary, id: diary.id)]
        let owners = ImageOwnerSnapshots(todos: [todo.snapshot], routines: [routine.snapshot], diaries: [diary.snapshot])
        for key in keys {
            let item = AttachmentItem(ownerKind: key.kind.rawValue, ownerID: key.id, filename: "synthetic.png")
            context.insert(item)
            let metadata = ImageAttachmentMetadata(id: item.id, ownerKind: item.ownerKind, ownerID: item.ownerID,
                filename: item.filename, createdAt: item.createdAt, deletedAt: nil, protection: .unprotected)
            let result = ImageAssociationReader.read(Fixture.request(images: [metadata], owners: owners))
            #expect(AttachmentAccess.canBrowse(item, todos: [todo], routines: [routine], diaries: [diary], tags: []))
            #expect(result.images.map(\.id.id) == [item.id])
            item.deletedAt = Fixture.date
            #expect(!AttachmentAccess.canBrowse(item, todos: [todo], routines: [routine], diaries: [diary], tags: []))
            item.deletedAt = nil
            item.privacyVaultID = UUID()
            #expect(!AttachmentAccess.canBrowse(item, todos: [todo], routines: [routine], diaries: [diary], tags: []))
        }
        #expect(try context.fetchCount(FetchDescriptor<AttachmentItem>()) == 3)
    }
}
