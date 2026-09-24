import Foundation
import SwiftData
import Testing
@testable import AreaChain

struct BoardItemProjectionTests {
    private let today = "2026-09-07" // Monday
    private let shared = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!

    @Test func referencesStayDistinctWhenUUIDMatches() {
        let oneOff = BoardItemReference.todo(shared)
        let recurring = BoardItemReference.recurring(shared)
        #expect(oneOff.id == "todo:\(shared.uuidString)")
        #expect(recurring.id == "recurring:\(shared.uuidString)")
        #expect(oneOff.id != recurring.id)
        #expect(oneOff.kind == .oneOff)
        #expect(recurring.kind == .recurring)
        #expect(oneOff.canReschedule)
        #expect(!recurring.canReschedule)
    }

    @Test func mixedListUsesSamePrecedence() {
        let later = Date(timeIntervalSince1970: 20)
        let earlier = Date(timeIntervalSince1970: 10)
        let urgent = TodoSnapshot(
            id: UUID(), title: "一次性", isDone: false, dayKey: today,
            createdAt: later, isImportant: true, isUrgent: true
        )
        let routine = RoutineSnapshot(
            id: UUID(), title: "重复", sortOrder: 0, isEnabled: true,
            createdDayKey: "2026-09-01", createdAt: earlier
        )
        let items = DayBoardLogic.openBoardItems(
            routines: [routine], checks: [], todos: [urgent], dayKey: today
        )
        #expect(items == [.todo(urgent.id), .recurring(routine.id)])
    }

    @Test func progressCountsDueRecurringAndSkipsAsComplete() {
        let due = RoutineSnapshot(
            id: UUID(), title: "每天", sortOrder: 0, isEnabled: true, createdDayKey: "2026-09-01"
        )
        let weekendOnly = RoutineSnapshot(
            id: UUID(), title: "周末", sortOrder: 1, isEnabled: true,
            createdDayKey: "2026-09-01", weekdayMask: 1
        )
        let skipped = CheckSnapshot(routineId: due.id, dayKey: today, isDone: false, isSkipped: true)
        let child = SubtaskSnapshot(id: UUID(), todoId: UUID(), title: "子任务", isDone: false)
        let open = TodoSnapshot(id: UUID(), title: "待办", isDone: false, dayKey: today, subtasks: [child])
        let deleted = TodoSnapshot(id: UUID(), title: "已删", isDone: false, dayKey: today, deletedAt: Date())
        let progress = DayBoardLogic.todayProgress(
            routines: [due, weekendOnly], checks: [skipped], todos: [open, deleted], dayKey: today
        )
        #expect(progress.completed == 1)
        #expect(progress.total == 2)
        #expect(progress.ratio == 0.5)
    }

    @Test func emptyDayDoesNotReportFullProgress() {
        let progress = DayBoardLogic.todayProgress(routines: [], checks: [], todos: [], dayKey: today)
        #expect(progress.total == 0)
        #expect(progress.ratio == 0)
    }

    @Test func oneOffMoveDoesNotChangeRecurringMask() {
        var todo = TodoSnapshot(id: shared, title: "一次", isDone: false, dayKey: today)
        todo = DayBoardLogic.moveTodo(todo, to: "2026-09-08")
        let routine = RoutineSnapshot(
            id: shared, title: "重复", sortOrder: 0, isEnabled: true,
            createdDayKey: "2026-09-01", weekdayMask: WeekdayMask.workdays
        )
        #expect(todo.dayKey == "2026-09-08")
        #expect(BoardItemReference.todo(todo.id).kind == .oneOff)
        #expect(routine.weekdayMask == WeekdayMask.workdays)
        #expect(!BoardItemReference.recurring(routine.id).canReschedule)
    }

    @Test func legacySnapshotKeepsRoutineAndCheckKeys() throws {
        let snapshot = ExportSnapshot(
            exportedAt: Date(timeIntervalSince1970: 1),
            routines: [],
            checks: [],
            todos: [],
            diaries: []
        )
        let data = try JSONEncoder().encode(snapshot)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains("\"routines\""))
        #expect(text.contains("\"checks\""))
        let decoded = try JSONDecoder().decode(ExportSnapshot.self, from: data)
        #expect(decoded.routines.isEmpty)
        #expect(decoded.checks.isEmpty)
    }
}

@MainActor
struct RecurringCaptureDraftTests {
    private func context() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func emptyWeekdayMaskDoesNotSaveOrClearCallerDraft() throws {
        let model = try context()
        var draft = RecurringCaptureDraft.fresh
        draft.title = "晨跑"
        draft.weekdayMask = 0
        #expect(DayBoardMutations.addRecurringItem(draft, sortOrder: 0, context: model) == false)
        #expect(draft.title == "晨跑")
        #expect(try model.fetch(FetchDescriptor<DailyRoutine>()).isEmpty)
        #expect(try model.fetch(FetchDescriptor<TodoItem>()).isEmpty)
    }

    @Test func cancelPathInsertsNothing() throws {
        let model = try context()
        #expect(try model.fetch(FetchDescriptor<DailyRoutine>()).isEmpty)
    }

    @Test func saveCreatesRoutineWithoutMatchingTodo() throws {
        let model = try context()
        var draft = RecurringCaptureDraft.fresh
        draft.title = "写日报 #工作"
        draft.notes = "多行备注"
        #expect(DayBoardMutations.addRecurringItem(draft, sortOrder: 0, context: model))
        let routines = try model.fetch(FetchDescriptor<DailyRoutine>())
        #expect(routines.count == 1)
        #expect(routines.first?.title == "写日报")
        #expect(routines.first?.notes == "多行备注")
        #expect(routines.first?.weekdayMask == WeekdayMask.all)
        #expect(try model.fetch(FetchDescriptor<TodoItem>()).isEmpty)
        #expect(try model.fetch(FetchDescriptor<TagItem>()).isEmpty == false)
    }
}
