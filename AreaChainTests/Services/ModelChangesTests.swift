import AppKit
import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor
struct ModelChangesTests {
    private func container() throws -> ModelContainer {
        try ModelContainer(for: Schema(AreaChainSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    @Test func compositeRepositoriesCommitOnceAndRollBackTogether() throws {
        let container = try container()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let todo = TodoItem(title: "原文", dayKey: "2026-09-11")
        context.insert(todo)
        try context.save()
        let tasks = SwiftDataTaskRepository(context: context)
        let routines = SwiftDataRoutineRepository(context: context)
        var notifications = 0
        let observer = NotificationCenter.default.addObserver(forName: .boardDidChange, object: nil, queue: .main) { _ in notifications += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }
        #expect(throws: CocoaError.self) {
            try ModelChanges.transaction(in: context, save: { _ in throw CocoaError(.fileWriteNoPermission) }) {
                try tasks.updateTodo(id: todo.id, title: "新标题", notes: nil)
                _ = try routines.addRoutine(title: "新习惯")
            }
        }
        #expect(todo.title == "原文")
        #expect(try context.fetchCount(FetchDescriptor<DailyRoutine>()) == 0)
        #expect(notifications == 0)
        try ModelChanges.transaction(in: context) {
            try tasks.updateTodo(id: todo.id, title: "已保存", notes: nil)
            _ = try routines.addRoutine(title: "习惯")
        }
        #expect(notifications == 1)
        #expect(try ModelContext(context.container).fetch(FetchDescriptor<TodoItem>()).first?.title == "已保存")
    }

    @Test func failedDiaryMutationReturnsFailureAndReportsIt() throws {
        let container = try container()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let previous = DayBoardMutations.diaryRepositoryProvider
        defer { DayBoardMutations.diaryRepositoryProvider = previous }
        let repository = RejectingDiaryRepository()
        DayBoardMutations.diaryRepositoryProvider = { _ in repository }
        let count = MutationFeedback.shared.failureCount
        #expect(!DayBoardMutations.addDiary(text: "保留草稿", dayKey: "2026-09-11", context: context))
        #expect(repository.attempts == 1)
        #expect(MutationFeedback.shared.failureCount == count + 1)
        #expect(try context.fetchCount(FetchDescriptor<DiaryEntry>()) == 0)
    }

    @Test func captureIsSavedBeforeOtherContextsReadItsBadgeCount() throws {
        let container = try container()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        #expect(DayBoardMutations.addCapturedTodo(text: "!p1 @18:00 完成核验 #工作", dayKey: "2026-09-11", context: context))
        let reader = ModelContext(context.container)
        let todo = try #require(reader.fetch(FetchDescriptor<TodoItem>()).first)
        #expect(todo.title == "完成核验")
        #expect(todo.isImportant && todo.isUrgent && todo.remindMinutes == 18 * 60)
        #expect(!todo.tagIDs.isEmpty)
        #expect(try reader.fetchCount(FetchDescriptor<TagItem>()) == 1)
    }

    @Test func clipboardImageFailureDoesNotLeaveAnEmptyTaskOrReportSuccess() throws {
        let container = try container()
        let clipboard = NSPasteboard(name: .init("areachain.capture.tests.\(UUID())"))
        defer { clipboard.clearContents() }
        let data = try png()
        clipboard.setData(data, forType: .png)
        let storage = FakeAttachmentStorage()
        storage.rejectWrites = true
        #expect(!ClipboardCapture.ingest(container: container, pasteboard: clipboard, storage: storage))
        #expect(try container.mainContext.fetchCount(FetchDescriptor<TodoItem>()) == 0)
        #expect(storage.removed.count == 1)
    }

    @Test func attachmentSaveRequiresLiveTypedOwnerAndReportsStorageFailure() throws {
        let container = try container()
        defer { withExtendedLifetime(container) {} }
        let context = container.mainContext
        let todo = TodoItem(title: "附件拥有者", dayKey: "2026-09-11")
        context.insert(todo)
        try context.save()
        let data = try png()
        let storage = FakeAttachmentStorage()
        let owner = AttachmentOwnerKey(kind: .todo, id: todo.id)
        storage.rejectWrites = true
        #expect(!AttachmentPicker.saveImage(data: data, filename: "test.png", owner: owner, context: context, store: storage))
        #expect(try context.fetchCount(FetchDescriptor<AttachmentItem>()) == 0)
        storage.rejectWrites = false
        #expect(AttachmentPicker.saveImage(data: data, filename: "test.png", owner: owner, context: context, store: storage))
        #expect(try ModelContext(context.container).fetchCount(FetchDescriptor<AttachmentItem>()) == 1)
        let wrongOwner = AttachmentOwnerKey(kind: .diary, id: todo.id)
        #expect(!AttachmentPicker.saveImage(data: data, filename: "test.png", owner: wrongOwner, context: context, store: storage))
    }

    @Test func activeFilterCanAlwaysBeClearedWithoutCatalogChoices() {
        let bar = BoardFilterBar(filter: BoardFilter(tagID: UUID()), projects: [], tags: [], bundleIDs: [], onChange: { _ in })
        #expect(bar.isVisible)
    }

    @Test func sharedTagFilterAlsoFiltersYesterdayAndUpcoming() {
        let tag = UUID()
        let allowed = TodoItem(title: "匹配", dayKey: "2026-09-10", tagIDs: tag.uuidString)
        let hidden = TodoItem(title: "不匹配", dayKey: "2026-09-10")
        let future = TodoItem(title: "未来不匹配", dayKey: "2026-09-12")
        let page = TasksPage(todayKey: "2026-09-11", routines: [], checks: [], todos: [allowed, hidden, future],
                             config: TasksPageConfig(externalFilter: .constant(BoardFilter(tagID: tag))))
        #expect(page.yesterdayItems.map(\.id) == [allowed.id])
        #expect(page.upcomingModels.isEmpty)
    }

    private func png() throws -> Data {
        let image = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: 1,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 4, bitsPerPixel: 32))
        return try #require(image.representation(using: .png, properties: [:]))
    }
}

@MainActor
private final class RejectingDiaryRepository: DiaryRepositoryProtocol {
    var attempts = 0
    func fetchDiaries(for dayKey: String?, includeDeleted: Bool) throws -> [DiaryEntry] { [] }
    func fetchDiary(id: UUID) throws -> DiaryEntry? { nil }
    func searchDiaries(query: String, tagID: UUID?, includeDeleted: Bool) throws -> [DiaryEntry] { [] }
    func addDiary(text: String, dayKey: String, tagIDs: Set<UUID>) throws -> DiaryEntry {
        attempts += 1
        throw CocoaError(.fileWriteNoPermission)
    }
    func editDiary(id: UUID, text: String) throws { throw CocoaError(.fileWriteNoPermission) }
    func togglePin(id: UUID) throws {}
    func setPinned(id: UUID, isPinned: Bool) throws {}
    func toggleTag(id: UUID, tagID: UUID) throws {}
    func setTags(id: UUID, tagIDs: Set<UUID>) throws {}
    func deleteDiary(id: UUID, soft: Bool) throws {}
    func restoreDiary(id: UUID) throws {}
    func purgeDiary(id: UUID) throws {}
}

private final class FakeAttachmentStorage: AttachmentStorageProtocol, @unchecked Sendable {
    var rejectWrites = false
    var removed: Set<UUID> = []
    func directory(fileManager: FileManager) -> URL { fileManager.temporaryDirectory }
    func fileURL(id: UUID, root: URL?) -> URL { (root ?? directory(fileManager: .default)).appending(path: id.uuidString) }
    func save(data: Data, filename: String, ownerKind: AttachmentOwner, ownerID: UUID,
              context: ModelContext, root: URL?, id: UUID, createdAt: Date) throws -> AttachmentItem {
        if rejectWrites { throw CocoaError(.fileWriteNoPermission) }
        let item = AttachmentItem(id: id, ownerKind: ownerKind.rawValue, ownerID: ownerID, filename: filename, createdAt: createdAt)
        context.insert(item)
        return item
    }
    func loadData(id: UUID, root: URL?) -> Data? { nil }
    func removeFile(id: UUID, root: URL?) { removed.insert(id) }
    func purge(ownerID: UUID, attachments: [AttachmentItem], context: ModelContext, root: URL?) {}
    func resetDirectory(fileManager: FileManager) throws {}
}
