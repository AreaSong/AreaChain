import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor
struct AttachmentSyntaxTests {
    @Test func extractsAttachmentNamesWhileIgnoringTimeScheduleAndProtectedSpans() {
        let text = """
        整理方案 @roadmap.png @"项目 架构图.png" @18:00 @上午 @一三五 \
        user@example.com `@ignored.png` \\@escaped.png @ROADMAP.PNG
        """
        let names = AttachmentSyntax.names(in: text)
        #expect(names == ["roadmap.png", "项目 架构图.png"])
        #expect(AttachmentSyntax.spelling(for: "roadmap.png") == "@roadmap.png")
        #expect(AttachmentSyntax.spelling(for: "项目 架构图.png") == "@\"项目 架构图.png\"")
    }

    @Test func uniqueFilenameKeepsFirstNameAndIncrementsCollisions() {
        #expect(AttachmentSyntax.uniqueFilename(base: "paste.png", existing: []) == "paste.png")
        #expect(
            AttachmentSyntax.uniqueFilename(base: "paste.png", existing: ["paste.png"])
                == "paste-2.png"
        )
        #expect(
            AttachmentSyntax.uniqueFilename(
                base: "paste.png",
                existing: ["paste.png", "paste-2.png"]
            ) == "paste-3.png"
        )
    }

    @Test func autocompleteSharesAtTriggerBetweenTimeAndAttachments() throws {
        let input = "复盘 @ro"
        let trigger = try #require(
            SyntaxAutocompleteEngine.detectTrigger(
                in: input,
                cursorLocation: (input as NSString).length
            )
        )
        let taskCandidates = SyntaxAutocompleteEngine.candidates(
            for: trigger,
            availableAttachments: ["roadmap.png", "项目 架构图.png"],
            context: .capture
        )
        #expect(taskCandidates.contains { $0.kind == .attachment && $0.insertText == "@roadmap.png " })

        let diaryTrigger = try #require(
            SyntaxAutocompleteEngine.detectTrigger(
                in: "手记记录 @项目",
                cursorLocation: ("手记记录 @项目" as NSString).length
            )
        )
        let diaryCandidates = SyntaxAutocompleteEngine.candidates(
            for: diaryTrigger,
            availableAttachments: ["roadmap.png", "项目 架构图.png"],
            context: .tags
        )
        #expect(diaryCandidates.map(\.insertText) == ["@\"项目 架构图.png\" "])
    }

    @Test func libraryProjectionDeduplicatesByStorageAndCarriesOwnerTagsAndSorting() throws {
        let fixture = try makeLibraryProjectionFixture()
        let library = fixture.library
        #expect(library.count == 3)

        let archItem = try #require(library.first { $0.storageID == fixture.sharedStorageID })
        #expect(archItem.references.count == 2)
        let todoRef = try #require(archItem.references.first { $0.kind == .todo })
        #expect(todoRef.tags.map(\.name) == ["工作"])
        let diaryRef = try #require(archItem.references.first { $0.kind == .diary })
        #expect(diaryRef.tags.map(\.name) == ["灵感"])

        #expect(
            AttachmentLibraryProjection.filterAndSort(library, filter: .unlinked, query: "", sort: .newest)
                .map(\.storageID) == [fixture.unlinkedID]
        )
        #expect(
            AttachmentLibraryProjection.filterAndSort(library, filter: .all, query: "灵感", sort: .newest)
                .map(\.storageID) == [fixture.sharedStorageID]
        )
        #expect(
            AttachmentLibraryProjection.filterAndSort(library, filter: .all, query: "", sort: .referenceCount)
                .first?.storageID == fixture.sharedStorageID
        )
    }

    private func makeLibraryProjectionFixture() throws -> (
        library: [AttachmentLibraryItem],
        sharedStorageID: UUID,
        unlinkedID: UUID
    ) {
        let container = try ModelContainer(
            for: TodoItem.self, DailyRoutine.self, DiaryEntry.self, AttachmentItem.self, TagItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let workTag = TagItem(name: "工作", sortOrder: 0, colorToken: "blue")
        let ideaTag = TagItem(name: "灵感", sortOrder: 1, colorToken: "amber")
        let encodedWorkTag = TagIDList.encode([workTag.id])
        let todo = TodoItem(title: "评审架构 #工作", dayKey: "2026-10-12", tagIDs: encodedWorkTag)
        let routine = DailyRoutine(title: "每周巡检", sortOrder: 0, createdDayKey: "2026-10-12", tagIDs: encodedWorkTag)
        let diary = DiaryEntry(text: "记录架构草图 #灵感", dayKey: "2026-10-12")
        for entity: any PersistentModel in [workTag, ideaTag, todo, routine, diary] {
            context.insert(entity)
        }
        let sharedStorageID = UUID()
        let firstRef = AttachmentItem(
            id: sharedStorageID, ownerKind: AttachmentOwner.todo.rawValue,
            ownerID: todo.id, filename: "arch.png", createdAt: Date(timeIntervalSince1970: 1_000)
        )
        firstRef.storageID = sharedStorageID
        let secondRef = AttachmentItem(
            ownerKind: AttachmentOwner.diary.rawValue,
            ownerID: diary.id, filename: "arch.png", createdAt: Date(timeIntervalSince1970: 2_000)
        )
        secondRef.storageID = sharedStorageID
        let routineStorageID = UUID()
        let routineRef = AttachmentItem(
            id: routineStorageID, ownerKind: AttachmentOwner.routine.rawValue,
            ownerID: routine.id, filename: "checklist.png", createdAt: Date(timeIntervalSince1970: 3_000)
        )
        routineRef.storageID = routineStorageID
        for att in [firstRef, secondRef, routineRef] { context.insert(att) }
        let unlinkedID = UUID()
        let unlinked = UnlinkedAttachmentEntry(
            id: unlinkedID, filename: "draft-sketch.png", createdAt: Date(timeIntervalSince1970: 4_000)
        )
        let allAttachments = [firstRef, secondRef, routineRef]
        let owners = try AttachmentAccess.ownerIndex(context: context, keys: allAttachments.compactMap(\.ownerKey))
        let library = AttachmentLibraryProjection.build(
            attachments: allAttachments, unlinked: [unlinked], owners: owners, tags: [workTag, ideaTag]
        )
        return (library, sharedStorageID, unlinkedID)
    }

    @Test func resolverLinksAtAttachmentTokensAndSynchronizesRenameAcrossOwners() throws {
        let container = try ModelContainer(
            for: TodoItem.self, DailyRoutine.self, DiaryEntry.self, AttachmentItem.self, TagItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let todoA = TodoItem(title: "主任务", dayKey: "2026-10-12")
        let todoB = TodoItem(title: "关联任务 @design.png", dayKey: "2026-10-12")
        let diary = DiaryEntry(text: "复盘手记 @design.png", dayKey: "2026-10-12")
        for entity: any PersistentModel in [todoA, todoB, diary] { context.insert(entity) }

        let baseAttachment = AttachmentItem(
            ownerKind: AttachmentOwner.todo.rawValue, ownerID: todoA.id, filename: "design.png"
        )
        baseAttachment.storageID = baseAttachment.id
        context.insert(baseAttachment)

        InputAttachmentResolver.linkIfPresent(in: todoB.title, ownerKind: .todo, ownerID: todoB.id, context: context)
        InputAttachmentResolver.linkIfPresent(in: diary.text, ownerKind: .diary, ownerID: diary.id, context: context)
        let allAttachments = try context.fetch(FetchDescriptor<AttachmentItem>())
        #expect(allAttachments.count == 3)
        #expect(allAttachments.allSatisfy { ($0.storageID ?? $0.id) == baseAttachment.id })

        let owners = try AttachmentAccess.ownerIndex(context: context, keys: allAttachments.compactMap(\.ownerKey))
        let library = AttachmentLibraryProjection.build(
            attachments: allAttachments, unlinked: [], owners: owners, tags: []
        )
        let libraryItem = try #require(library.first)
        #expect(AttachmentPoolStore.rename(item: libraryItem, newFilename: "architecture-v2", context: context))
        let updatedAttachments = try context.fetch(FetchDescriptor<AttachmentItem>())
        #expect(updatedAttachments.allSatisfy { $0.filename == "architecture-v2.png" })
    }

    @Test func historicalDuplicateNamesDisambiguateAndIdenticalHashesMerge() throws {
        let container = try ModelContainer(
            for: TodoItem.self, DailyRoutine.self, DiaryEntry.self, AttachmentItem.self, TagItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let diary = DiaryEntry(text: "123123", dayKey: "2026-10-12")
        context.insert(diary)

        let first = AttachmentItem(
            ownerKind: AttachmentOwner.diary.rawValue,
            ownerID: diary.id,
            filename: "paste.png",
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let second = AttachmentItem(
            ownerKind: AttachmentOwner.diary.rawValue,
            ownerID: diary.id,
            filename: "paste.png",
            createdAt: Date(timeIntervalSince1970: 2_000)
        )
        context.insert(first)
        context.insert(second)
        let owners = try AttachmentAccess.ownerIndex(context: context, keys: [first, second].compactMap(\.ownerKey))

        let distinctItems = AttachmentLibraryProjection.build(
            attachments: [first, second], unlinked: [], owners: owners, tags: [],
            contentHashes: [first.id: "hash-a", second.id: "hash-b"]
        )
        #expect(distinctItems.map(\.filename) == ["paste.png", "paste-2.png"])

        let mergedItems = AttachmentLibraryProjection.build(
            attachments: [first, second], unlinked: [], owners: owners, tags: [],
            contentHashes: [first.id: "same-hash", second.id: "same-hash"]
        )
        #expect(mergedItems.count == 1)
        #expect(mergedItems.first?.filename == "paste.png")
        #expect(mergedItems.first?.references.count == 1)
    }

    @Test func renameCollisionAppendsIncrementingSuffix() throws {
        let container = try ModelContainer(
            for: TodoItem.self, DailyRoutine.self, DiaryEntry.self, AttachmentItem.self, TagItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let todo = TodoItem(title: "测试重命名冲突", dayKey: "2026-10-12")
        context.insert(todo)
        let existingDemo = AttachmentItem(
            ownerKind: AttachmentOwner.todo.rawValue, ownerID: todo.id,
            filename: "demo.png", createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let target = AttachmentItem(
            ownerKind: AttachmentOwner.todo.rawValue, ownerID: todo.id,
            filename: "paste.png", createdAt: Date(timeIntervalSince1970: 2_000)
        )
        context.insert(existingDemo)
        context.insert(target)

        let owners = try AttachmentAccess.ownerIndex(context: context, keys: [existingDemo, target].compactMap(\.ownerKey))
        let library = AttachmentLibraryProjection.build(
            attachments: [existingDemo, target], unlinked: [], owners: owners, tags: []
        )
        let targetLibraryItem = try #require(library.first { $0.storageID == target.id })
        #expect(AttachmentPoolStore.rename(item: targetLibraryItem, newFilename: "demo", context: context))
        #expect(target.filename == "demo-2.png")
    }
}
