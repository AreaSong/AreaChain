import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 沿批量改期的隔离批量环境；转换能力只在这里显式打开。时钟固定，日历刷新是计数 fake。
@MainActor final class ConvertCommandFixture {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }()
    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    let base: BatchCommandFixture
    let todo: TodoItem
    let children: [SubtaskItem]
    let earlierChild: SubtaskItem
    let attachment: AttachmentItem
    let earlierAttachment: AttachmentItem
    let routineAttachment: AttachmentItem
    var today = "2026-10-18"
    var refreshes = 0
    private(set) var adapter: ConvertCommandAdapter!
    var context: ModelContext { base.context }
    var handoff: HandoffFixture { base.handoff }
    var routine: DailyRoutine { base.routine }

    init(capability: ConvertCommandAdapter.Capability = .convert) throws {
        base = try BatchCommandFixture(count: 2)
        todo = base.todos[0]
        children = [SubtaskItem(title: "已完成子项 · Done", isDone: true, sortOrder: 0, tagIDs: "tag-x", todo: todo),
                    SubtaskItem(title: "未完成子项 · Open", sortOrder: 1, todo: todo)]
        earlierChild = SubtaskItem(title: "早先删除 · Earlier", sortOrder: 2, deletedAt: Date(timeIntervalSince1970: 200), todo: todo)
        attachment = AttachmentItem(ownerKind: AttachmentOwner.todo.rawValue, ownerID: todo.id, filename: "convert.png")
        earlierAttachment = AttachmentItem(ownerKind: AttachmentOwner.todo.rawValue, ownerID: todo.id, filename: "earlier.png",
                                           deletedAt: Date(timeIntervalSince1970: 300))
        routineAttachment = AttachmentItem(ownerKind: AttachmentOwner.routine.rawValue, ownerID: base.routine.id,
                                           filename: "routine.png")
        base.routine.subtaskTemplates = [RoutineSubtaskTemplate(id: UUID(), title: "模板二", sortOrder: 1, tagIDs: "tag-y"),
                                         RoutineSubtaskTemplate(id: UUID(), title: "模板一", sortOrder: 0)]
        for child in children + [earlierChild] { context.insert(child) }
        for item in [attachment, earlierAttachment, routineAttachment] { context.insert(item) }
        try context.save()
        adapter = .init(coordinator: base.handoff.coordinator, environment: base.environment, capability: capability,
                        clock: .init(now: { Self.now }, today: { [unowned self] in today }, calendar: Self.calendar),
                        refreshCalendar: { [unowned self] in refreshes += 1 })
    }

    var todoTarget: CommandObjectReference { .init(type: .todo, id: todo.id) }
    var routineTarget: CommandObjectReference { .init(type: .routine, id: base.routine.id) }

    func queue(_ command: String, target: CommandObjectReference) throws {
        try handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: command),
            targets: .init(.single, objects: [target])))
    }
    func preview() throws -> CommandConvertPreview {
        try adapter.prepare(plan: handoff.state().plan.stamp, expecting: handoff.owned().lease)
    }
    func accept() throws -> CommandConvertAcceptance { try adapter.accept(preview(), expecting: handoff.owned().lease) }
    func confirm(_ accepted: CommandConvertAcceptance) throws -> CommandConvertConfirmation {
        try adapter.confirm(accepted, expecting: handoff.owned().lease)
    }
    func submit(_ accepted: CommandConvertAcceptance, _ confirmation: CommandConvertConfirmation) throws -> CommandConvertFacts {
        try adapter.submit(accepted: accepted, confirmation: confirmation, expecting: handoff.owned().lease)
    }
    func run(_ command: String, target: CommandObjectReference) throws -> (CommandConvertAcceptance, CommandConvertFacts) {
        try queue(command, target: target)
        let accepted = try accept()
        return (accepted, try submit(accepted, confirm(accepted)))
    }
    func count(_ action: String) -> Int { base.count(action) }

    func routines(_ id: UUID) throws -> [DailyRoutine] {
        try context.fetch(FetchDescriptor<DailyRoutine>(predicate: #Predicate { $0.id == id }))
    }
    func todos(_ id: UUID) throws -> [TodoItem] {
        try context.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id }))
    }
    /// 同容器的新 context：读出真实落盘结果，不受当前 context 回滚缓存影响。
    func stored(_ object: CommandObjectReference) throws -> [Date?] {
        let fresh = ModelContext(base.io.container)
        return try ConvertCommandTransaction.presence(object, context: fresh)
    }
}
