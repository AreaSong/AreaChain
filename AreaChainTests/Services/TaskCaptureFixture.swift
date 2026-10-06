import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 业务链全部显式注入；不靠 XCTest 跳过 shared 系统服务来隔离。
@MainActor
final class TaskCaptureFixture {
    let container: ModelContainer
    let context: ModelContext
    let center = NotificationCenter()
    var trace: [String] = []
    var failures = 0
    var source = "qa.capture.source"
    var calendarEnabled = true
    var registered: [UUID] = []
    var authorizations: [Int] = []
    var observer: NSObjectProtocol?

    init() throws {
        container = try ModelContainer(for: Schema(AreaChainSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
        context.autosaveEnabled = false
        observer = center.addObserver(forName: .boardDidChange, object: nil, queue: nil) { [weak self] _ in
            MainActor.assumeIsolated { self?.trace.append("ui") }
        }
    }

    var events: BoardEvents.Dependencies {
        .init(center: center) { [self] includeCalendar in
            trace.append("reminderRefresh")
            if includeCalendar && calendarEnabled { trace.append("calendarRefresh") }
        }
    }

    var boundary: ModelChanges.Boundary {
        .init(preSave: { [self] context in
            trace.append("preSave")
            try context.save()
        }, save: { [self] context in
            trace.append("save")
            try context.save()
            trace.append("saved")
        }, publish: { [self] in BoardEvents.changed(dependencies: events) },
        reportFailure: { [self] _ in failures += 1 })
    }

    var dependencies: TaskMutationService.Dependencies {
        .init(sourceBundleID: { [self] in source },
              repository: { SwiftDataTaskRepository(context: $0) }, transaction: boundary,
              registerLocalCreation: { [self] id in registered.append(id); trace.append("fact") },
              requestReminderAccessIfNeeded: { [self] minutes in
                  if let minutes { authorizations.append(minutes); trace.append("authorize") }
              })
    }

    func create(_ text: String, dependencies: TaskMutationService.Dependencies? = nil) -> TaskMutationService.Creation {
        TaskMutationService.createCaptured(.init(text: text, dayKey: "2026-10-05"),
                                           in: context, dependencies: dependencies ?? self.dependencies)
    }

    func readTodos() throws -> [TodoItem] {
        let reader = ModelContext(container)
        reader.autosaveEnabled = false
        return try reader.fetch(FetchDescriptor<TodoItem>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    /// 冻结提取前算法，只替换 IO；不调用新服务，防止两个委托互相比对的伪等价。
    func original(_ input: TaskMutationService.CaptureInput) -> Bool {
        let text = input.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        let parsed = NaturalLanguageParser.parseTaskCapture(text)
        let important = parsed.hasPriorityToken ? parsed.isImportant : (input.fallbackQuadrant?.isImportant ?? parsed.isImportant)
        let urgent = parsed.hasPriorityToken ? parsed.isUrgent : (input.fallbackQuadrant?.isUrgent ?? parsed.isUrgent)
        let saved = ModelChanges.perform(in: context, boundary: boundary) {
            let ids = try InputTagResolver.merging(parsed.tagNames, into: TagIDList.encode(input.tagIDs), in: context)
            _ = try SwiftDataTaskRepository(context: context).addTodo(CreateTodoParams(
                title: parsed.cleanTitle, dayKey: input.dayKey, notes: parsed.notes,
                remindMinutes: parsed.remindMinutes, isImportant: important, isUrgent: urgent,
                tagIDs: TagIDList.parse(ids), sourceBundleID: source
            ))
        }
        if saved { dependencies.requestReminderAccessIfNeeded(parsed.remindMinutes) }
        return saved
    }

    struct Fields: Equatable {
        let title: String
        let day: String
        let notes: String
        let remind: Int?
        let important: Bool
        let urgent: Bool
        let source: String
        let order: Int
        let tagNames: [String]
    }

    func fields() throws -> [Fields] {
        let tags = try context.fetch(FetchDescriptor<TagItem>())
        return try readTodos().map { todo in
            #expect(todo.deletedAt == nil && !todo.isDone && todo.dueMinutes == nil)
            #expect(todo.calendarEventID.isEmpty && todo.subtasks.isEmpty)
            #expect(todo.createdAt <= Date.now && todo.createdAt > Date.now.addingTimeInterval(-60))
            return Fields(title: todo.title, day: todo.dayKey, notes: todo.notes,
                          remind: todo.remindMinutes, important: todo.isImportant, urgent: todo.isUrgent,
                          source: todo.sourceBundleID, order: todo.sortOrder,
                          tagNames: TagIDList.parse(todo.tagIDs).map { id in tags.first { $0.id == id }?.name ?? "missing" })
        }
    }
}
