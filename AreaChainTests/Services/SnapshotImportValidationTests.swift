import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor
struct SnapshotImportValidationTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func emptySnapshot() -> ExportSnapshot {
        ExportSnapshot(exportedAt: .now, routines: [], checks: [], todos: [], diaries: [])
    }

    private func todo(id: UUID = UUID(), subtasks: [ExportedSubtask] = []) -> ExportedTodo {
        ExportedTodo(id: id, title: "导入", isDone: false, dayKey: "2026-09-11", createdAt: .now, subtasks: subtasks)
    }

    @Test(arguments: 0..<8)
    func duplicateIncomingIDsAreRejectedBeforeAnyWrites(kind: Int) throws {
        let context = try makeContext()
        let snapshot = duplicateSnapshot(kind: kind)
        let decoded = try SyncPort.decode(SyncPort.encode(snapshot))
        #expect(throws: SnapshotImportError.self) { try SnapshotImporter.apply(decoded, context: context) }
        #expect(!context.hasChanges)
        #expect(try context.fetchCount(FetchDescriptor<TodoItem>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<DailyRoutine>()) == 0)
    }

    private func duplicateSnapshot(kind: Int) -> ExportSnapshot {
        var snapshot = emptySnapshot()
        let id = UUID()
        switch kind {
        case 0:
            let item = ExportedRoutine(id: id, title: "习惯", sortOrder: 0, isEnabled: true, createdDayKey: "2026-09-01")
            snapshot.routines = [item, item]
        case 1:
            let item = ExportedCheck(id: id, routineId: UUID(), dayKey: "2026-09-11", isDone: true)
            snapshot.checks = [item, item]
        case 2:
            snapshot.todos = [todo(id: id), todo(id: id)]
        case 3:
            let item = ExportedSubtask(id: id, title: "子任务", isDone: false)
            snapshot.todos = [todo(subtasks: [item]), todo(subtasks: [item])]
        case 4:
            let item = ExportedDiary(id: id, text: "手记", dayKey: "2026-09-11", createdAt: .now)
            snapshot.diaries = [item, item]
        case 5:
            let item = ExportedProject(id: id, name: "项目", sortOrder: 0)
            snapshot.projects = [item, item]
        case 6:
            let item = ExportedTag(id: id, name: "标签", sortOrder: 0)
            snapshot.tags = [item, item]
        default:
            let item = ExportedAttachment(id: id, ownerKind: "todo", ownerID: UUID(), filename: "test.png", createdAt: .now)
            snapshot.attachments = [item, item]
        }
        return snapshot
    }

    @Test func existingDuplicatesReturnErrorWithoutCrashingOrCleaningData() throws {
        let context = try makeContext()
        let id = UUID()
        context.insert(TodoItem(id: id, title: "一", dayKey: "2026-09-11"))
        context.insert(TodoItem(id: id, title: "二", dayKey: "2026-09-11"))
        try context.save()
        #expect(throws: SnapshotImportError.self) {
            try SnapshotImporter.apply(emptySnapshot(), context: context)
        }
        #expect(try context.fetchCount(FetchDescriptor<TodoItem>()) == 2)
    }

    @Test func existingSubtaskCannotBeSilentlyDuplicatedUnderAnotherParent() throws {
        let context = try makeContext()
        let parent = TodoItem(title: "原父任务", dayKey: "2026-09-11")
        context.insert(parent)
        let subtask = SubtaskItem(title: "子任务", todo: parent)
        context.insert(subtask)
        try context.save()
        var snapshot = emptySnapshot()
        snapshot.todos = [todo(subtasks: [ExportedSubtask(id: subtask.id, title: "新标题", isDone: false)])]
        #expect(throws: SnapshotImportError.self) { try SnapshotImporter.apply(snapshot, context: context) }
        #expect(subtask.todo?.id == parent.id)
        #expect(subtask.title == "子任务")
        #expect(try context.fetchCount(FetchDescriptor<TodoItem>()) == 1)
    }

    @Test func logicalCheckConflictRejectsTheWholeImportBeforeUpdatingOtherModels() throws {
        let context = try makeContext()
        let routine = DailyRoutine(title: "习惯", sortOrder: 0)
        let existingTodo = TodoItem(title: "原文", dayKey: "2026-09-11")
        context.insert(routine)
        context.insert(existingTodo)
        context.insert(RoutineCheck(dayKey: "2026-09-11", isDone: false, routine: routine))
        try context.save()
        var snapshot = emptySnapshot()
        snapshot.todos = [todo(id: existingTodo.id)]
        snapshot.checks = [ExportedCheck(id: UUID(), routineId: routine.id, dayKey: "2026-09-11", isDone: true)]
        #expect(throws: SnapshotImportError.self) { try SnapshotImporter.apply(snapshot, context: context) }
        #expect(existingTodo.title == "原文")
        #expect(try context.fetchCount(FetchDescriptor<RoutineCheck>()) == 1)
    }

    @Test func finalCheckKeysAllowLegitimateDateSwapAndLocalOnlyRoutineReference() throws {
        let context = try makeContext()
        let routine = DailyRoutine(title: "习惯", sortOrder: 0)
        context.insert(routine)
        let first = RoutineCheck(dayKey: "2026-09-10", isDone: true, routine: routine)
        let second = RoutineCheck(dayKey: "2026-09-11", isDone: false, routine: routine)
        context.insert(first)
        context.insert(second)
        try context.save()
        var snapshot = emptySnapshot()
        snapshot.checks = [
            ExportedCheck(id: first.id, routineId: routine.id, dayKey: "2026-09-11", isDone: true),
            ExportedCheck(id: second.id, routineId: routine.id, dayKey: "2026-09-10", isDone: false)
        ]
        try SnapshotImporter.apply(snapshot, context: context)
        try SnapshotImporter.apply(snapshot, context: context)
        #expect(first.dayKey == "2026-09-11")
        #expect(second.dayKey == "2026-09-10")
        #expect(try context.fetchCount(FetchDescriptor<RoutineCheck>()) == 2)
    }

    @Test func unknownRoutineReferenceIsRejectedInsteadOfCreatingInvisibleCheck() throws {
        let context = try makeContext()
        var snapshot = emptySnapshot()
        snapshot.checks = [ExportedCheck(id: UUID(), routineId: UUID(), dayKey: "2026-09-11", isDone: true)]
        #expect(throws: SnapshotImportError.self) { try SnapshotImporter.apply(snapshot, context: context) }
        #expect(try context.fetchCount(FetchDescriptor<RoutineCheck>()) == 0)
    }

    @Test func failedSaveRollsBackImportButRetainsEarlierEdits() throws {
        let context = try makeContext()
        let existing = TodoItem(title: "原文", dayKey: "2026-09-11")
        context.insert(existing)
        try context.save()
        existing.title = "此前的编辑"
        var snapshot = emptySnapshot()
        snapshot.todos = [todo(id: existing.id), todo()]
        snapshot.diaries = [ExportedDiary(id: UUID(), text: "导入手记", dayKey: "2026-09-11", createdAt: .now)]
        #expect(throws: CocoaError.self) {
            try SnapshotImporter.apply(snapshot, context: context) { _ in
                throw CocoaError(.fileWriteNoPermission)
            }
        }
        #expect(existing.title == "此前的编辑")
        #expect(try context.fetchCount(FetchDescriptor<TodoItem>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<DiaryEntry>()) == 0)
        let stored = try ModelContext(context.container).fetch(FetchDescriptor<TodoItem>())
        #expect(stored.first?.title == "此前的编辑")
    }

    @Test func preflightFailureDoesNotFlushOrDiscardExistingDraftChanges() throws {
        let context = try makeContext()
        let existing = TodoItem(title: "已保存", dayKey: "2026-09-11")
        context.insert(existing)
        try context.save()
        existing.title = "未保存"
        #expect(throws: SnapshotImportError.self) {
            try SnapshotImporter.validate(duplicateSnapshot(kind: 2), context: context)
        }
        #expect(context.hasChanges)
        #expect(existing.title == "未保存")
        #expect(try ModelContext(context.container).fetch(FetchDescriptor<TodoItem>()).first?.title == "已保存")
    }
}
