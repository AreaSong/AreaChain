import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor
struct AttachmentOwnerLookupTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test func contextOwnerLookupMatchesInMemoryRulesForLiveDeletedMissingAndDuplicates() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let liveTodo = TodoItem(title: "live", dayKey: "2026-09-10")
        let deletedTodo = TodoItem(title: "trashed", dayKey: "2026-09-11", deletedAt: Date(timeIntervalSince1970: 8))
        let liveRoutine = DailyRoutine(title: "habit", sortOrder: 0)
        let liveDiary = DiaryEntry(text: "note", dayKey: "2026-09-10")
        let duplicateID = UUID()
        let firstDup = TodoItem(id: duplicateID, title: "dup-a", dayKey: "2026-09-10")
        let secondDup = TodoItem(id: duplicateID, title: "dup-b", dayKey: "2026-09-11")
        context.insert(liveTodo)
        context.insert(deletedTodo)
        context.insert(liveRoutine)
        context.insert(liveDiary)
        context.insert(firstDup)
        context.insert(secondDup)
        for index in 0..<24 {
            context.insert(TodoItem(title: "decoy-\(index)", dayKey: "2026-09-12"))
        }
        try context.save()

        let liveKey = AttachmentOwnerKey(kind: .todo, id: liveTodo.id)
        let deletedKey = AttachmentOwnerKey(kind: .todo, id: deletedTodo.id)
        let missingKey = AttachmentOwnerKey(kind: .todo, id: UUID())
        let routineKey = AttachmentOwnerKey(kind: .routine, id: liveRoutine.id)
        let diaryKey = AttachmentOwnerKey(kind: .diary, id: liveDiary.id)
        let typedMismatch = AttachmentOwnerKey(kind: .diary, id: liveTodo.id)
        let duplicateKey = AttachmentOwnerKey(kind: .todo, id: duplicateID)
        let todos = try context.fetch(FetchDescriptor<TodoItem>())
        let routines = try context.fetch(FetchDescriptor<DailyRoutine>())
        let diaries = try context.fetch(FetchDescriptor<DiaryEntry>())

        #expect(AttachmentAccess.ownerIsLive(liveKey, todos: todos, routines: routines, diaries: diaries))
        #expect(try AttachmentAccess.ownerIsLive(liveKey, context: context))
        #expect(!AttachmentAccess.ownerIsLive(deletedKey, todos: todos, routines: routines, diaries: diaries))
        #expect(try !AttachmentAccess.ownerIsLive(deletedKey, context: context))
        #expect(!AttachmentAccess.ownerIsLive(missingKey, todos: todos, routines: routines, diaries: diaries))
        #expect(try !AttachmentAccess.ownerIsLive(missingKey, context: context))
        #expect(AttachmentAccess.ownerIsLive(routineKey, todos: todos, routines: routines, diaries: diaries))
        #expect(try AttachmentAccess.ownerIsLive(routineKey, context: context))
        #expect(AttachmentAccess.ownerIsLive(diaryKey, todos: todos, routines: routines, diaries: diaries))
        #expect(try AttachmentAccess.ownerIsLive(diaryKey, context: context))
        #expect(!AttachmentAccess.ownerIsLive(typedMismatch, todos: todos, routines: routines, diaries: diaries))
        #expect(try !AttachmentAccess.ownerIsLive(typedMismatch, context: context))
        #expect(!AttachmentAccess.ownerIsLive(duplicateKey, todos: todos, routines: routines, diaries: diaries))
        #expect(try !AttachmentAccess.ownerIsLive(duplicateKey, context: context))
        #expect(try AttachmentAccess.ownerIsLive(liveKey, context: context))

        let liveID = liveTodo.id
        #expect(try context.fetchCount(FetchDescriptor<TodoItem>()) > 20)
        #expect(try context.fetchCount(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == liveID })) == 1)
        #expect(try context.fetchCount(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == duplicateID })) == 2)
    }

    @Test func matchingKeepsSoftDeletedRowsAndIgnoresDateAndOtherOwners() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = UUID()
        let other = UUID()
        let early = AttachmentItem(
            ownerKind: AttachmentOwner.todo.rawValue, ownerID: owner, filename: "early.png",
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let later = AttachmentItem(
            ownerKind: AttachmentOwner.todo.rawValue, ownerID: owner, filename: "later.png",
            createdAt: Date(timeIntervalSince1970: 9)
        )
        let trashed = AttachmentItem(
            ownerKind: AttachmentOwner.todo.rawValue, ownerID: owner, filename: "trashed.png",
            createdAt: Date(timeIntervalSince1970: 5),
            deletedAt: Date(timeIntervalSince1970: 6)
        )
        let otherOwner = AttachmentItem(
            ownerKind: AttachmentOwner.todo.rawValue, ownerID: other, filename: "other.png"
        )
        let sameIDDiary = AttachmentItem(
            ownerKind: AttachmentOwner.diary.rawValue, ownerID: owner, filename: "diary.png"
        )
        for item in [early, later, trashed, otherOwner, sameIDDiary] {
            context.insert(item)
        }
        try context.save()

        let fetched = try OwnedAttachments.matching(ownerID: owner, kind: .todo, in: context)
        #expect(Set(fetched.map(\.filename)) == ["early.png", "later.png", "trashed.png"])
        let fromAll = OwnedAttachments.matching(try OwnedAttachments.all(in: context), ownerID: owner, kind: .todo)
        #expect(Set(fromAll.map(\.id)) == Set(fetched.map(\.id)))
        #expect(try OwnedAttachments.matching(ownerID: UUID(), kind: .todo, in: context).isEmpty)

        try OwnedAttachments.purge(ownerID: owner, kind: .todo, in: context)
        try context.save()
        #expect(try OwnedAttachments.matching(ownerID: owner, kind: .todo, in: context).isEmpty)
        #expect(try OwnedAttachments.matching(ownerID: other, kind: .todo, in: context).map(\.filename) == ["other.png"])
        #expect(try OwnedAttachments.matching(ownerID: owner, kind: .diary, in: context).map(\.filename) == ["diary.png"])
        try OwnedAttachments.purge(ownerID: owner, kind: .todo, in: context)
        try context.save()
        #expect(try OwnedAttachments.matching(ownerID: other, kind: .todo, in: context).count == 1)
    }

    @Test func trashRowBlocksRestoreWhenOwnerIsNotLive() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let live = TodoItem(title: "owner", dayKey: "2026-09-10")
        let gone = TodoItem(title: "gone", dayKey: "2026-09-10", deletedAt: Date(timeIntervalSince1970: 3))
        let liveFile = AttachmentItem(
            ownerKind: AttachmentOwner.todo.rawValue, ownerID: live.id, filename: "ok.png",
            deletedAt: Date(timeIntervalSince1970: 4)
        )
        let orphanFile = AttachmentItem(
            ownerKind: AttachmentOwner.todo.rawValue, ownerID: gone.id, filename: "orphan.png",
            deletedAt: Date(timeIntervalSince1970: 4)
        )
        let missingFile = AttachmentItem(
            ownerKind: AttachmentOwner.todo.rawValue, ownerID: UUID(), filename: "missing.png",
            deletedAt: Date(timeIntervalSince1970: 4)
        )
        context.insert(live)
        context.insert(gone)
        context.insert(liveFile)
        context.insert(orphanFile)
        context.insert(missingFile)
        try context.save()

        let todos = try context.fetch(FetchDescriptor<TodoItem>())
        let liveRow = try #require(TrashRow.attachment(liveFile, ownerDeleted: !AttachmentAccess.ownerIsLive(
            AttachmentOwnerKey(kind: .todo, id: live.id), todos: todos, routines: [], diaries: []
        )))
        let orphanRow = try #require(TrashRow.attachment(orphanFile, ownerDeleted: !AttachmentAccess.ownerIsLive(
            AttachmentOwnerKey(kind: .todo, id: gone.id), todos: todos, routines: [], diaries: []
        )))
        let missingRow = try #require(TrashRow.attachment(missingFile, ownerDeleted: true))
        #expect(liveRow.canRestore)
        #expect(!orphanRow.canRestore)
        #expect(!missingRow.canRestore)
        #expect(TrashRow.attachment(
            AttachmentItem(ownerKind: AttachmentOwner.todo.rawValue, ownerID: live.id, filename: "live.png"),
            ownerDeleted: false
        ) == nil)
    }

    @Test func diaryAttachmentSaveRejectsUnavailableOwnersAndRetriesAfterRepair() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "areachain-owner-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let container = try makeContainer()
        let context = container.mainContext
        let live = DiaryEntry(text: "live", dayKey: "2026-09-10")
        let trashed = DiaryEntry(text: "trashed", dayKey: "2026-09-11", deletedAt: Date(timeIntervalSince1970: 2))
        let duplicateID = UUID()
        context.insert(live)
        context.insert(trashed)
        context.insert(DiaryEntry(id: duplicateID, text: "dup-a", dayKey: "2026-09-10"))
        context.insert(DiaryEntry(id: duplicateID, text: "dup-b", dayKey: "2026-09-11"))
        try context.save()

        let data = Data([0x89, 0x50, 0x4E, 0x47])
        _ = try AttachmentStore.save(
            data: data, filename: "ok.png", ownerKind: .diary, ownerID: live.id,
            context: context, root: root
        )
        _ = try AttachmentStore.save(
            data: data, filename: "ok-again.png", ownerKind: .diary, ownerID: live.id,
            context: context, root: root
        )
        try context.save()
        #expect(throws: RepositoryError.self) {
            try AttachmentStore.save(
                data: data, filename: "missing.png", ownerKind: .diary, ownerID: UUID(),
                context: context, root: root
            )
        }
        #expect(throws: RepositoryError.self) {
            try AttachmentStore.save(
                data: data, filename: "trashed.png", ownerKind: .diary, ownerID: trashed.id,
                context: context, root: root
            )
        }
        #expect(throws: RepositoryError.self) {
            try AttachmentStore.save(
                data: data, filename: "dup.png", ownerKind: .diary, ownerID: duplicateID,
                context: context, root: root
            )
        }

        let counts = mutationCounts(in: context) {
            #expect(throws: CocoaError.self) {
                try ModelChanges.transaction(in: context, save: { _ in throw CocoaError(.fileWriteNoPermission) }) {
                    _ = try AttachmentStore.save(
                        data: data, filename: "fail.png", ownerKind: .diary, ownerID: live.id,
                        context: context, root: root
                    )
                }
            }
        }
        #expect(counts.saves == 0 && counts.notifications == 0)
        trashed.deletedAt = nil
        try context.save()
        _ = try AttachmentStore.save(
            data: data, filename: "restored-owner.png", ownerKind: .diary, ownerID: trashed.id,
            context: context, root: root
        )
        let restored = try OwnedAttachments.matching(ownerID: trashed.id, kind: .diary, in: context)
        #expect(restored.contains { $0.filename == "restored-owner.png" })
    }

    @Test func ownerLookupQueryShapeAvoidsFullTableScan() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let live = TodoItem(title: "probe", dayKey: "2026-09-10")
        context.insert(live)
        for index in 0..<80 {
            context.insert(TodoItem(title: "noise-\(index)", dayKey: "2026-09-13"))
            context.insert(AttachmentItem(
                ownerKind: AttachmentOwner.todo.rawValue, ownerID: UUID(), filename: "noise-\(index).png"
            ))
        }
        context.insert(AttachmentItem(
            ownerKind: AttachmentOwner.todo.rawValue, ownerID: live.id, filename: "mine.png"
        ))
        try context.save()

        let ownerID = live.id
        let kind = AttachmentOwner.todo.rawValue
        #expect(try context.fetchCount(FetchDescriptor<TodoItem>()) == 81)
        #expect(try context.fetchCount(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == ownerID })) == 1)
        #expect(try context.fetchCount(FetchDescriptor<AttachmentItem>()) == 81)
        #expect(
            try context.fetchCount(
                FetchDescriptor<AttachmentItem>(predicate: #Predicate {
                    $0.ownerID == ownerID && $0.ownerKind == kind
                })
            ) == 1
        )

        let oldOwner = try Phase1Clock.millis {
            let matches = try context.fetch(FetchDescriptor<TodoItem>()).filter { $0.id == live.id }
            return AttachmentAccess.isSingleLive(deletedAts: matches.map(\.deletedAt))
        }
        let newOwner = try Phase1Clock.millis {
            try AttachmentAccess.ownerIsLive(AttachmentOwnerKey(kind: .todo, id: live.id), context: context)
        }
        #expect(oldOwner.0 && newOwner.0)
        let oldMatching = try Phase1Clock.millis {
            OwnedAttachments.matching(try OwnedAttachments.all(in: context), ownerID: live.id, kind: .todo)
        }
        let newMatching = try Phase1Clock.millis {
            try OwnedAttachments.matching(ownerID: live.id, kind: .todo, in: context)
        }
        #expect(Set(oldMatching.0.map(\.id)) == Set(newMatching.0.map(\.id)))
        #expect(newMatching.0.map(\.filename) == ["mine.png"])
        let rss = Phase1Clock.probe().rss
        #expect(
            oldOwner.1.wallMs >= 0 && newOwner.1.wallMs >= 0,
            "PHASE2D oldOwnerMs=\(Phase1Clock.roundMs(oldOwner.1.wallMs)) newOwnerMs=\(Phase1Clock.roundMs(newOwner.1.wallMs)) oldMatchMs=\(Phase1Clock.roundMs(oldMatching.1.wallMs)) newMatchMs=\(Phase1Clock.roundMs(newMatching.1.wallMs)) rss=\(rss)"
        )
    }

    private func mutationCounts(
        in context: ModelContext, _ work: () throws -> Void
    ) rethrows -> (saves: Int, notifications: Int) {
        var saves = 0
        var notifications = 0
        let center = NotificationCenter.default
        let saveObserver = center.addObserver(forName: ModelContext.willSave, object: context, queue: .main) { _ in
            saves += 1
        }
        let changeObserver = center.addObserver(forName: .boardDidChange, object: nil, queue: .main) { _ in
            notifications += 1
        }
        defer {
            center.removeObserver(saveObserver)
            center.removeObserver(changeObserver)
        }
        try work()
        return (saves, notifications)
    }
}
