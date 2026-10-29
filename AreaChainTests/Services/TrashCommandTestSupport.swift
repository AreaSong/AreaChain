import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 沿批量改期的隔离批量环境；回收能力只在这里显式打开。
@MainActor final class TrashCommandFixture {
    let base: BatchCommandFixture
    let adapter: TrashCommandAdapter
    let parent: TodoItem
    let liveSubtasks: [SubtaskItem]
    let earlierDeleted: SubtaskItem
    let attachments: [AttachmentItem]
    let earlierAttachment: AttachmentItem
    let routineAttachment: AttachmentItem
    var context: ModelContext { base.context }
    var handoff: HandoffFixture { base.handoff }

    init(count: Int = 3) throws {
        let base = try BatchCommandFixture(count: count)
        let parent = base.todos[0]
        self.base = base
        self.parent = parent
        let context = base.context
        liveSubtasks = (0..<2).map { SubtaskItem(title: "回收子项 \($0) · Synthetic child", isDone: $0 == 0, sortOrder: $0, todo: parent) }
        earlierDeleted = SubtaskItem(title: "已独立删除 · Earlier", sortOrder: 2,
                                     deletedAt: Date(timeIntervalSince1970: 200), todo: parent)
        attachments = (0..<2).map { AttachmentItem(ownerKind: AttachmentOwner.todo.rawValue, ownerID: parent.id,
                                                   filename: "synthetic-\($0).png") }
        earlierAttachment = AttachmentItem(ownerKind: AttachmentOwner.todo.rawValue, ownerID: parent.id,
                                           filename: "earlier.png", deletedAt: Date(timeIntervalSince1970: 300))
        routineAttachment = AttachmentItem(ownerKind: AttachmentOwner.routine.rawValue, ownerID: base.routine.id,
                                           filename: "routine.png")
        for child in liveSubtasks + [earlierDeleted] { context.insert(child) }
        for item in attachments + [earlierAttachment, routineAttachment] { context.insert(item) }
        try context.save()
        adapter = .init(coordinator: base.handoff.coordinator, environment: base.environment, capability: .softTrash)
    }

    var todoTarget: CommandObjectReference { .init(type: .todo, id: parent.id) }
    var routineTarget: CommandObjectReference { .init(type: .routine, id: base.routine.id) }
    func subtaskTarget(_ index: Int = 1) -> CommandObjectReference { .init(type: .subtask, id: liveSubtasks[index].id) }

    func queue(_ command: String, targets: [CommandObjectReference]) throws {
        try handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: command),
            targets: .init(targets.count == 1 ? .single : .selected, objects: targets)))
    }
    func preview() throws -> CommandTrashPreview {
        try adapter.prepare(plan: handoff.state().plan.stamp, expecting: handoff.owned().lease)
    }
    func accept() throws -> CommandTrashAcceptance { try adapter.accept(preview(), expecting: handoff.owned().lease) }
    func confirm(_ accepted: CommandTrashAcceptance) throws -> CommandTrashConfirmation {
        try adapter.confirm(accepted, expecting: handoff.owned().lease)
    }
    func submit(_ accepted: CommandTrashAcceptance, _ confirmation: CommandTrashConfirmation) throws -> CommandTrashFacts {
        try adapter.submit(accepted: accepted, confirmation: confirmation, expecting: handoff.owned().lease)
    }
    func run(_ command: String, targets: [CommandObjectReference]) throws -> CommandTrashFacts {
        try queue(command, targets: targets)
        let accepted = try accept()
        return try submit(accepted, confirm(accepted))
    }
    func count(_ action: String) -> Int { base.count(action) }
}

/// 写入失败可注入的剪贴板 fake；从不触碰系统剪贴板。
@MainActor final class FakeClipboardWriter: ClipboardTextWriting {
    var writes: [String] = []
    var fails = false
    func write(_ text: String) throws {
        if fails { throw ClipboardTextWriteError.rejected }
        writes.append(text)
    }
}

@MainActor final class TaskCopyCommandFixture {
    let io: TaskCaptureFixture
    let handoff: HandoffFixture
    let todo: TodoItem
    let writer = FakeClipboardWriter()
    var source = CommandTaskTitleEligibility(revision: UUID(), protection: .ordinary)
    var sourceRead: (() throws -> Void)?
    private(set) var adapter: TaskCopyCommandAdapter!

    init(title: String = "复制标题 · Copy title", notes: String = "  第一行\n第二行 👩🏽‍💻 e\u{301}  \n") throws {
        io = try TaskCaptureFixture()
        handoff = try HandoffFixture()
        todo = TodoItem(title: title, dayKey: "2026-10-18", notes: notes)
        io.context.insert(todo)
        try io.context.save()
        let environment = try TaskCopyCommandEnvironment(context: io.context, source: { [unowned self] _ in
            try sourceRead?()
            return source
        }, writer: writer)
        adapter = .init(coordinator: handoff.coordinator, environment: environment)
    }

    var target: CommandObjectReference { .init(type: .todo, id: todo.id) }

    func start(_ section: TaskCopySection?, targets: [CommandObjectReference]? = nil) throws {
        try handoff.start(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.copy"),
            targets: .init(.single, objects: targets ?? [target]),
            arguments: section.map { [.init(parameter: .section, operation: .assign, value: .choice($0.rawValue))] } ?? []))
    }
    func preview() throws -> CommandTaskCopyPreview {
        let draft = try #require(handoff.state().operations.active)
        return try adapter.prepare(draft: draft.stamp, expecting: handoff.owned().lease)
    }
    func submit(_ preview: CommandTaskCopyPreview) throws -> CommandTaskCopyResult {
        try adapter.submit(preview, expecting: handoff.owned().lease)
    }
}
