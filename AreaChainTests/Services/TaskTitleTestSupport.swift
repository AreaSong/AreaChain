import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 共用原捕获的隔离 IO 夹具；标题、标签和系统消费者只存在于本测试内存库。
@MainActor final class TaskTitleFixture {
    let io: TaskCaptureFixture
    let todo: TodoItem
    let live: TagItem
    let deleted: TagItem
    let handoff: HandoffFixture
    var protection: CommandProtectionRequirement = .ordinary
    lazy var reader = TaskTitleCommandPreviewReader(context: io.context, sourceProtection: { [unowned self] in protection })
    static let deletion = Date(timeIntervalSince1970: 123)
    static let taskID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let liveID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let deletedID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    init() throws {
        io = try TaskCaptureFixture()
        handoff = try HandoffFixture()
        live = TagItem(id: Self.liveID, name: "Work", sortOrder: 0)
        deleted = TagItem(id: Self.deletedID, name: "恢复", sortOrder: 1, deletedAt: Self.deletion)
        todo = TodoItem(id: Self.taskID, title: "原标题", isDone: true, dayKey: "2026-10-05",
                        createdAt: Date(timeIntervalSince1970: 456), remindMinutes: 420,
                        tagIDs: TagIDList.encode([Self.liveID]), isImportant: true, isUrgent: false,
                        sourceBundleID: "qa.original", calendarEventID: "qa.calendar", notes: "原备注\n!p3 @10:00 #保留原文",
                        sortOrder: 7, dueMinutes: 600)
        io.context.insert(live)
        io.context.insert(deleted)
        io.context.insert(todo)
        try io.context.save()
    }

    var dependencies: TaskMutationService.TitleDependencies {
        .init(repository: { SwiftDataTaskRepository(context: $0) }, transaction: io.boundary,
              registerLocalModification: { [io] id in io.registered.append(id); io.trace.append("fact") },
              requestReminderAccessIfNeeded: io.dependencies.requestReminderAccessIfNeeded)
    }

    func edit(_ text: String, dependencies: TaskMutationService.TitleDependencies? = nil) -> TaskMutationService.TitleModification {
        TaskMutationService.editTitle(todo, rawInput: text, in: io.context, dependencies: dependencies ?? self.dependencies)
    }

    func queue(_ title: String, extra: [CommandArgument] = [], baseline: CommandDraftBaseline = .init(),
               target: CommandObjectReference? = nil) throws {
        let reference = target ?? .init(type: .todo, id: todo.id)
        let draft = CommandDraft(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.title"),
                                 targets: .init(.single, objects: [reference]), baseline: baseline,
                                 arguments: [.init(parameter: .title, operation: .assign, value: .shortText(title))] + extra)
        try handoff.queue(draft)
    }

    func preview() throws -> CommandTaskTitlePreview { try reader.prepare(in: handoff.owned()) }
    func validate(_ preview: CommandTaskTitlePreview) throws -> CommandTaskTitlePreview {
        try reader.validateCurrent(preview, in: handoff.owned())
    }

    func editArgument(_ argument: CommandArgument) throws {
        let item = try #require(handoff.state().plan.items.first)
        try handoff.plan(.beginEditing(item.stamp))
        try handoff.plan(.edit(item.stamp, argument))
        let current = try #require(handoff.state().plan.items.first)
        try handoff.plan(.endEditing(current.stamp, .finish))
    }

    /// 独立冻结旧算法，不通过被提取的 TaskTitleEdit 或共享服务间接证明等价。
    func original(_ rawInput: String) -> Bool {
        let text = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        let parsed = NaturalLanguageParser.parseTaskCapture(text)
        let repo = SwiftDataTaskRepository(context: io.context)
        let saved = ModelChanges.perform(in: io.context, boundary: io.boundary) {
            try repo.updateTodo(id: todo.id, title: parsed.cleanTitle, notes: parsed.notes.isEmpty ? nil : parsed.notes)
            if parsed.hasPriorityToken {
                try repo.setPriority(id: todo.id, isImportant: parsed.isImportant, isUrgent: parsed.isUrgent)
            }
            if let minutes = parsed.remindMinutes { try repo.setRemind(id: todo.id, minutes: minutes) }
            let merged = try InputTagResolver.merging(parsed.tagNames, into: todo.tagIDs, in: io.context)
            try repo.replaceTagIDs(id: todo.id, tagIDs: merged)
        }
        if saved { dependencies.requestReminderAccessIfNeeded(parsed.remindMinutes) }
        return saved
    }

    struct Fields: Equatable {
        var snapshot: TodoSnapshot
        let calendarEventID: String
        let tags: [String]
        let tagStates: [String: Date?]
    }

    func fields() throws -> Fields {
        let stored = try #require(io.readTodos().first)
        let tags = try io.context.fetch(FetchDescriptor<TagItem>())
        let names = TagIDList.parse(stored.tagIDs).map { id in tags.first { $0.id == id }?.name ?? "missing" }
        var snapshot = stored.snapshot
        // 新建标签的随机 UUID 不同，只在三库对照时投影名字；另有精确编码/顺序断言。
        snapshot.tagIDs = ""
        return .init(snapshot: snapshot, calendarEventID: stored.calendarEventID, tags: names,
                     tagStates: Dictionary(uniqueKeysWithValues: tags.map { ($0.name, $0.deletedAt) }))
    }
}
