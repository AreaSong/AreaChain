import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 锁住共享转换入口与原 DayBoardMutations 实现的行为；只用内存库与注入时钟，不碰真实日历。
@Suite(.serialized) @MainActor struct ItemConversionServiceTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }()
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    @MainActor private final class Store {
        let container: ModelContainer
        var context: ModelContext { container.mainContext }
        var refreshes = 0
        var publications = 0
        var failSave = false
        let todo: TodoItem
        let doneChild: SubtaskItem
        let openChild: SubtaskItem
        let earlierChild: SubtaskItem
        let attachment: AttachmentItem
        let earlierAttachment: AttachmentItem
        let routine: DailyRoutine
        let routineAttachment: AttachmentItem
        let laterTodo: TodoItem

        init() throws {
            container = try ModelContainer(for: Schema(AreaChainSchema.models),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            todo = TodoItem(title: "转换待办 · Convert todo", isDone: true, dayKey: "2026-10-13", remindMinutes: 480,
                            tagIDs: "tag-a", isImportant: true, isUrgent: true, sourceBundleID: "qa.source",
                            calendarEventID: "qa.event", notes: "备注 · notes", sortOrder: 4, dueMinutes: 900)
            doneChild = SubtaskItem(title: "已完成子项", isDone: true, sortOrder: 1, tagIDs: "tag-b", todo: todo)
            openChild = SubtaskItem(title: "未完成子项", sortOrder: 0, tagIDs: "", todo: todo)
            earlierChild = SubtaskItem(title: "早先删除", sortOrder: 2, deletedAt: Date(timeIntervalSince1970: 10), todo: todo)
            attachment = AttachmentItem(ownerKind: AttachmentOwner.todo.rawValue, ownerID: todo.id, filename: "live.png")
            earlierAttachment = AttachmentItem(ownerKind: AttachmentOwner.todo.rawValue, ownerID: todo.id,
                                               filename: "earlier.png", deletedAt: Date(timeIntervalSince1970: 20))
            routine = DailyRoutine(title: "转换习惯 · Convert routine", sortOrder: 9, isEnabled: false,
                                   createdDayKey: "2026-09-01", weekdayMask: WeekdayMask.workdays, remindMinutes: 420,
                                   tagIDs: "tag-c", isImportant: true, sourceBundleID: "qa.routine", notes: "习惯备注",
                                   pausedOnDayKey: "2026-10-01")
            routine.subtaskTemplates = [
                RoutineSubtaskTemplate(id: UUID(), title: "模板二", sortOrder: 1, tagIDs: "tag-d"),
                RoutineSubtaskTemplate(id: UUID(), title: "模板一", sortOrder: 0, tagIDs: "")
            ]
            routineAttachment = AttachmentItem(ownerKind: AttachmentOwner.routine.rawValue, ownerID: routine.id,
                                               filename: "routine.png")
            laterTodo = TodoItem(title: "今天的另一项", dayKey: "2026-10-18", sortOrder: 2)
            let context = container.mainContext
            context.insert(todo); context.insert(laterTodo)
            for child in [doneChild, openChild, earlierChild] { context.insert(child) }
            context.insert(routine)
            context.insert(RoutineCheck(dayKey: "2026-10-10", isDone: true, routine: routine))
            for item in [attachment, earlierAttachment, routineAttachment] { context.insert(item) }
            try context.save()
        }

        var dependencies: ItemConversionService.Dependencies {
            var value = ItemConversionService.Dependencies()
            value.clock = .init(now: { ItemConversionServiceTests.now }, today: { "2026-10-18" },
                                calendar: ItemConversionServiceTests.calendar)
            value.transaction = .init(save: { [unowned self] context in
                if failSave { throw TaskCreateCommandIO.Failure.injected }
                try context.save()
            }, publish: { [unowned self] in publications += 1 }, reportFailure: { _ in })
            value.refreshCalendar = { [unowned self] in refreshes += 1 }
            return value
        }

        func routines() throws -> [DailyRoutine] { try context.fetch(FetchDescriptor<DailyRoutine>()) }
        func todos() throws -> [TodoItem] { try context.fetch(FetchDescriptor<TodoItem>()) }
    }

    @Test func todoToRoutineMovesFieldsTemplatesAttachmentsAndStampsOnce() throws {
        let s = try Store()
        let id = try #require(ItemConversionService.convertTodoToRoutine(s.todo, dependencies: s.dependencies))
        let created = try #require(try s.routines().first { $0.id == id })
        #expect(id != s.todo.id && id != s.routine.id)
        #expect(created.title == s.todo.title && created.notes == s.todo.notes && created.tagIDs == s.todo.tagIDs)
        #expect(created.remindMinutes == 480 && created.isImportant && created.isUrgent && created.sourceBundleID == "qa.source")
        // 2026-10-13 是星期二：原日期只保留成每周这一天。
        #expect(created.weekdayMask == WeekdayMask.only(weekday: 3) && created.createdDayKey == "2026-10-18")
        #expect(created.isEnabled && created.pausedOnDayKey == nil && created.checks.isEmpty)
        // 活子任务按顺序变模板：新 UUID，保留标题、顺序与标签，不保留完成态；早先删除的不迁移。
        let templates = created.subtaskTemplates
        #expect(templates.map(\.title) == ["未完成子项", "已完成子项"] && templates.map(\.sortOrder) == [0, 1])
        #expect(templates.map(\.tagIDs) == ["", "tag-b"])
        #expect(Set(templates.map(\.id)).isDisjoint(with: [s.doneChild.id, s.openChild.id, s.earlierChild.id]))
        // 原待办与活子任务同一时间戳；早先删除的子项与附件不变。
        #expect(s.todo.deletedAt == Self.now && s.doneChild.deletedAt == Self.now && s.openChild.deletedAt == Self.now)
        #expect(s.earlierChild.deletedAt == Date(timeIntervalSince1970: 10))
        #expect(s.attachment.ownerID == id && s.attachment.ownerKind == AttachmentOwner.routine.rawValue && s.attachment.deletedAt == nil)
        #expect(s.earlierAttachment.ownerID == s.todo.id && s.earlierAttachment.ownerKind == AttachmentOwner.todo.rawValue)
        // 截止与完成态不迁移：习惯没有这两个字段。原日历身份随原待办留在回收站。
        #expect(s.todo.dueMinutes == 900 && s.todo.isDone && s.todo.calendarEventID == "qa.event")
        // 排序取全部活待办与活习惯的最大值 + 1（原待办在写入前仍是活的）。
        #expect(created.sortOrder == 10)
        #expect(s.publications == 1 && s.refreshes == 1 && !s.context.hasChanges)
    }

    @Test func routineToTodoCreatesTodayTodoWithFreshSubtasks() throws {
        let s = try Store()
        let routineAttachmentOwner = s.routineAttachment.ownerID
        let id = try #require(ItemConversionService.convertRoutineToTodo(s.routine, dependencies: s.dependencies))
        let created = try #require(try s.todos().first { $0.id == id })
        #expect(id != s.routine.id && routineAttachmentOwner == s.routine.id)
        #expect(created.title == s.routine.title && created.notes == "习惯备注" && created.tagIDs == "tag-c")
        #expect(created.remindMinutes == 420 && created.isImportant && !created.isUrgent && created.sourceBundleID == "qa.routine")
        #expect(created.dayKey == "2026-10-18" && !created.isDone && created.dueMinutes == nil && created.calendarEventID.isEmpty)
        let children = created.subtasks.sorted { $0.sortOrder < $1.sortOrder }
        #expect(children.map(\.title) == ["模板一", "模板二"] && children.allSatisfy { !$0.isDone && $0.deletedAt == nil })
        #expect(children.map(\.tagIDs) == ["", "tag-d"])
        #expect(Set(children.map(\.id)).isDisjoint(with: s.routine.subtaskTemplates.map(\.id)))
        #expect(s.routine.deletedAt == Self.now && s.routine.checks.count == 1)
        #expect(s.routineAttachment.ownerID == id && s.routineAttachment.ownerKind == AttachmentOwner.todo.rawValue)
        // 今天的活待办（2）与全部活习惯（9）的最大值 + 1；原待办在 2026-10-13，不参与。
        #expect(created.sortOrder == 10)
        // 反方向原本不额外刷新日历，只经发布请求刷新；保持现状。
        #expect(s.publications == 1 && s.refreshes == 0)
    }

    @Test func saveFailureLeavesOriginalsAndSkipsRefresh() throws {
        let s = try Store()
        s.failSave = true
        let before = (s.todo.snapshot, s.routine.snapshot, s.attachment.ownerID, s.routineAttachment.ownerID)
        #expect(ItemConversionService.convertTodoToRoutine(s.todo, dependencies: s.dependencies) == nil)
        #expect(ItemConversionService.convertRoutineToTodo(s.routine, dependencies: s.dependencies) == nil)
        #expect(s.todo.snapshot == before.0 && s.routine.snapshot == before.1)
        #expect(s.attachment.ownerID == before.2 && s.routineAttachment.ownerID == before.3)
        #expect(try s.routines().count == 1 && s.todos().count == 2 && !s.context.hasChanges)
        #expect(s.publications == 0 && s.refreshes == 0)
    }

    @Test func deletedOriginalsAreRejectedWithoutWrites() throws {
        let s = try Store()
        s.todo.deletedAt = Date(timeIntervalSince1970: 30)
        s.routine.deletedAt = Date(timeIntervalSince1970: 30)
        try s.context.save()
        #expect(ItemConversionService.convertTodoToRoutine(s.todo, dependencies: s.dependencies) == nil)
        #expect(ItemConversionService.convertRoutineToTodo(s.routine, dependencies: s.dependencies) == nil)
        #expect(s.publications == 0 && s.refreshes == 0 && s.attachment.ownerID == s.todo.id)
    }

    /// 原 DayBoardMutations 实现的逐字副本（去掉进程内无效的日历刷新）作对照：
    /// 除新 UUID 与时刻外，界面入口与旧实现写出的字段完全一致。
    @Test func uiEntryMatchesLegacyImplementation() throws {
        let current = try Store()
        let legacy = try Store()
        let routineID = try #require(DayBoardMutations.convertTodoToRoutine(current.todo))
        let legacyRoutineID = try #require(LegacyConversion.todoToRoutine(legacy.todo))
        let new = try #require(try current.routines().first { $0.id == routineID })
        let old = try #require(try legacy.routines().first { $0.id == legacyRoutineID })
        #expect(RoutineShape(new) == RoutineShape(old))
        #expect(current.todo.deletedAt != nil && legacy.todo.deletedAt != nil)
        #expect([current.doneChild, current.openChild].map { $0.deletedAt == current.todo.deletedAt }
            == [legacy.doneChild, legacy.openChild].map { $0.deletedAt == legacy.todo.deletedAt })
        #expect(current.attachment.ownerKind == legacy.attachment.ownerKind && current.earlierChild.deletedAt == legacy.earlierChild.deletedAt)

        let todoID = try #require(DayBoardMutations.convertRoutineToTodo(current.routine))
        let legacyTodoID = try #require(LegacyConversion.routineToTodo(legacy.routine))
        let newTodo = try #require(try current.todos().first { $0.id == todoID })
        let oldTodo = try #require(try legacy.todos().first { $0.id == legacyTodoID })
        #expect(TodoShape(newTodo) == TodoShape(oldTodo))
        #expect(current.routine.deletedAt != nil && legacy.routine.deletedAt != nil)
        #expect(current.routineAttachment.ownerKind == legacy.routineAttachment.ownerKind)
    }

    private struct RoutineShape: Equatable {
        let fields: [String]
        let templates: [String]
        init(_ routine: DailyRoutine) {
            fields = [routine.title, routine.notes, routine.tagIDs, routine.sourceBundleID, routine.createdDayKey,
                      String(describing: routine.weekdayMask), "\(routine.remindMinutes ?? -1)", "\(routine.isImportant)",
                      "\(routine.isUrgent)", "\(routine.sortOrder)", "\(routine.isEnabled)"]
            templates = routine.subtaskTemplates.map { "\($0.title)|\($0.sortOrder)|\($0.tagIDs)" }
        }
    }

    private struct TodoShape: Equatable {
        let fields: [String]
        let children: [String]
        init(_ todo: TodoItem) {
            fields = [todo.title, todo.notes, todo.tagIDs, todo.sourceBundleID, todo.dayKey, "\(todo.remindMinutes ?? -1)",
                      "\(todo.isImportant)", "\(todo.isUrgent)", "\(todo.sortOrder)", "\(todo.isDone)", "\(todo.dueMinutes ?? -1)"]
            children = todo.subtasks.sorted { $0.sortOrder < $1.sortOrder }
                .map { "\($0.title)|\($0.sortOrder)|\($0.tagIDs)|\($0.isDone)|\($0.deletedAt == nil)" }
        }
    }
}

/// 抽取前 DayBoardMutations+Convert 的实现副本，仅作等价对照，不被生产代码引用。
@MainActor private enum LegacyConversion {
    static func todoToRoutine(_ todo: TodoItem) -> UUID? {
        guard let context = todo.modelContext, todo.deletedAt == nil else { return nil }
        let routineID = UUID()
        let subtasks = todo.subtasks.filter { $0.deletedAt == nil }.sorted { $0.sortOrder < $1.sortOrder }
        let templates = subtasks.map {
            RoutineSubtaskTemplate(id: UUID(), title: $0.title, sortOrder: $0.sortOrder, tagIDs: $0.tagIDs)
        }
        let order = (try? nextSharedOrder(in: context)) ?? 0
        let saved = ModelChanges.perform(in: context) {
            let routine = DailyRoutine(id: routineID, title: todo.title, sortOrder: order, createdDayKey: DayKey.today(),
                weekdayMask: ItemConversion.weekdayMask(for: todo.dayKey), remindMinutes: todo.remindMinutes,
                tagIDs: todo.tagIDs, isImportant: todo.isImportant, isUrgent: todo.isUrgent, notes: todo.notes)
            routine.sourceBundleID = todo.sourceBundleID
            routine.subtaskTemplates = templates
            context.insert(routine)
            try moveAttachments(from: todo.id, kind: .todo, to: routineID, newKind: .routine, in: context)
            let now = SoftDelete.stamp()
            todo.deletedAt = now
            SoftDelete.stampLiveSubtasks(todo.subtasks, at: now)
        }
        return saved ? routineID : nil
    }

    static func routineToTodo(_ routine: DailyRoutine) -> UUID? {
        guard let context = routine.modelContext, routine.deletedAt == nil else { return nil }
        let todoID = UUID()
        let today = DayKey.today()
        let order = (try? nextSharedOrder(in: context, dayKey: today)) ?? 0
        let templates = routine.subtaskTemplates.sorted { $0.sortOrder < $1.sortOrder }
        let saved = ModelChanges.perform(in: context) {
            let todo = TodoItem(id: todoID, title: routine.title, dayKey: today, remindMinutes: routine.remindMinutes,
                tagIDs: routine.tagIDs, isImportant: routine.isImportant, isUrgent: routine.isUrgent,
                sourceBundleID: routine.sourceBundleID, notes: routine.notes, sortOrder: order)
            context.insert(todo)
            for template in templates {
                context.insert(SubtaskItem(id: UUID(), title: template.title, isDone: false, sortOrder: template.sortOrder,
                                           tagIDs: template.tagIDs, todo: todo))
            }
            try moveAttachments(from: routine.id, kind: .routine, to: todoID, newKind: .todo, in: context)
            routine.deletedAt = SoftDelete.stamp()
        }
        return saved ? todoID : nil
    }

    private static func nextSharedOrder(in context: ModelContext, dayKey: String? = nil) throws -> Int {
        let todos = try context.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.deletedAt == nil }))
        let routines = try context.fetch(FetchDescriptor<DailyRoutine>(predicate: #Predicate { $0.deletedAt == nil }))
        let orders = todos.filter { dayKey == nil || $0.dayKey == dayKey }.map(\.sortOrder) + routines.map(\.sortOrder)
        return (orders.max() ?? -1) + 1
    }

    private static func moveAttachments(from ownerID: UUID, kind: AttachmentOwner, to newID: UUID,
                                         newKind: AttachmentOwner, in context: ModelContext) throws {
        for item in try context.fetch(FetchDescriptor<AttachmentItem>())
        where item.deletedAt == nil && item.ownerID == ownerID && item.ownerKind == kind.rawValue {
            item.ownerID = newID
            item.ownerKind = newKind.rawValue
        }
    }
}
