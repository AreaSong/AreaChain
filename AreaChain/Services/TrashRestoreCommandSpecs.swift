import Foundation
import SwiftData

/// trash.restore → TrashRestoreService（与回收站页“恢复”同一写入）。目标须在回收站里；
/// 待办连同同一删除戳的子任务与附件、习惯与手记连同附件一并恢复（原仓储规则），确认面板列出连带数量。
/// 走共用独立确认、只能单项（多项计划按目录的独立确认拒绝）。受保护手记及其附件、加密附件要解锁，
/// 指令里从不认证，一律拒绝；拥有者也在回收站里的附件不能单独恢复。
@MainActor struct TrashRestoreSpec: SimpleCommandCallSpec {
    var restorer: (ModelContext) -> TrashRestoreService = { context in
        .init(tasks: SwiftDataTaskRepository(context: context), routines: SwiftDataRoutineRepository(context: context),
              diaries: SwiftDataDiaryRepository(context: context), catalog: SwiftDataCatalogRepository(context: context))
    }
    let command = CommandID(rawValue: "trash.restore")
    let shape = CommandSimpleShape.singleAny(TrashRestoreService.types)
    let copy = CommandSimpleCopy(preview: "unified.simple.trash.restore.preview", saved: "unified.simple.trash.restore.saved")
    var confirms: Bool { true }
    var refusesProtectedContent: Bool { true }

    static func all() -> [any SimpleCommandSpec] { [TrashRestoreSpec()] }

    private struct Subject {
        let title: String
        let record: PersistentIdentifier
        let deletedAt: Date?
        let notices: (Children) throws -> [CommandSimpleNotice]
    }

    /// 连带计数的口径：预览前数“与父项同一删除戳、会随之恢复”的子项；预期与写后重读都数“恢复后活着”的子项。
    private enum Children {
        case willRestore(Date), liveAfter(Date?)

        func count(_ stamps: [Date?]) -> Int {
            stamps.filter { stamp in
                switch self {
                case .willRestore(let parent): SoftDelete.shouldRestoreChild(parentDeletedAt: parent, childDeletedAt: stamp)
                case .liveAfter(let parent):
                    stamp == nil || SoftDelete.shouldRestoreChild(parentDeletedAt: parent, childDeletedAt: stamp)
                }
            }.count
        }
    }

    private func unique<T>(_ rows: [T]) throws -> T {
        guard let row = rows.first else { throw CommandSimpleIssue.invalidTarget(.missing) }
        guard rows.count == 1 else { throw CommandSimpleIssue.invalidTarget(.duplicate) }
        return row
    }

    private func attachments(_ owner: AttachmentOwnerKey, in context: ModelContext) throws -> [Date?] {
        let id = owner.id, kind = owner.kind.rawValue
        return try context.fetch(FetchDescriptor<AttachmentItem>(predicate: #Predicate { $0.ownerID == id && $0.ownerKind == kind }))
            .map(\.deletedAt)
    }

    private func attachmentNotice(_ owner: AttachmentOwnerKey, _ children: Children, in context: ModelContext) throws -> CommandSimpleNotice {
        .init(key: "unified.simple.trash.restore.attachments", title: String(children.count(try attachments(owner, in: context))))
    }

    private func subject(_ target: CommandObjectReference, in context: ModelContext) throws -> Subject {
        let id = target.id
        switch target.type {
        case .todo:
            let todo = try unique(context.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id })))
            return .init(title: todo.title, record: todo.persistentModelID, deletedAt: todo.deletedAt) { children in
                [.init(key: "unified.simple.trash.restore.subtasks", title: String(children.count(todo.subtasks.map(\.deletedAt)))),
                 try attachmentNotice(.init(kind: .todo, id: id), children, in: context)]
            }
        case .routine:
            let routine = try unique(context.fetch(FetchDescriptor<DailyRoutine>(predicate: #Predicate { $0.id == id })))
            return .init(title: routine.title, record: routine.persistentModelID, deletedAt: routine.deletedAt) { children in
                [try attachmentNotice(.init(kind: .routine, id: id), children, in: context)]
            }
        case .diary:
            let entry = try unique(context.fetch(FetchDescriptor<DiaryEntry>(predicate: #Predicate { $0.id == id })))
            // 隐私门禁：受保护手记要在回收站页解锁后恢复；不读正文、不显示标题。
            guard !entry.hasProtectedContent,
                  !DiaryPrivacy.isSensitive(entry.snapshot, tags: try context.fetch(FetchDescriptor<TagItem>())) else {
                throw CommandSimpleIssue.invalidTarget(.protectedSource)
            }
            let firstLine = entry.text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
            return .init(title: String(firstLine.prefix(40)), record: entry.persistentModelID, deletedAt: entry.deletedAt) { children in
                [try attachmentNotice(.init(kind: .diary, id: id), children, in: context)]
            }
        case .image: return try image(id, in: context)
        case .tag:
            let tag = try TagOrganizeSpecs.anyTag(id, in: context)
            return .init(title: tag.name, record: tag.persistentModelID, deletedAt: tag.deletedAt) { _ in
                [.init(key: "unified.simple.tag.restore.affected", title: String(try TagOrganizeSpecs.linkedCount([id], in: context)))]
            }
        default: throw CommandSimpleIssue.invalidArguments
        }
    }

    private func image(_ id: UUID, in context: ModelContext) throws -> Subject {
        let row = try ImageCommandSpecs.attachment(id, in: context)
        guard let owner = row.ownerKey else { throw CommandSimpleIssue.invalidTarget(.ownerTrashed) }
        // 加密附件、属于受保护手记的附件同附件中心的可见性：要解锁，拒绝。
        if row.privacyVaultID != nil { throw CommandSimpleIssue.invalidTarget(.protectedSource) }
        if owner.kind == .diary {
            let ownerID = owner.id
            let entries = try context.fetch(FetchDescriptor<DiaryEntry>(predicate: #Predicate { $0.id == ownerID }))
            let tags = try context.fetch(FetchDescriptor<TagItem>())
            if entries.contains(where: { $0.hasProtectedContent || DiaryPrivacy.isSensitive($0.snapshot, tags: tags) }) {
                throw CommandSimpleIssue.invalidTarget(.protectedSource)
            }
        }
        guard try AttachmentAccess.ownerIsLive(owner, context: context) else { throw CommandSimpleIssue.invalidTarget(.ownerTrashed) }
        return .init(title: row.filename, record: row.persistentModelID, deletedAt: row.deletedAt) { _ in
            [.init(key: "unified.simple.image.owner." + owner.kind.rawValue, title: row.filename)]
        }
    }

    private func state(_ subject: Subject, key: UUID, deleted: Bool, children: Children) throws -> CommandSimpleState {
        .init(rows: [.init(key: key.uuidString, record: subject.record, title: subject.title,
                           fields: [TagOrganizeSpecs.stateField(deleted)])],
              notices: try subject.notices(children))
    }

    private func trashed(_ call: CommandSimpleCall, in context: ModelContext) throws -> (Subject, UUID) {
        let target = call.input.targets.objects[0]
        let subject = try subject(target, in: context)
        guard call.frozen != nil || subject.deletedAt != nil else { throw CommandSimpleIssue.invalidTarget(.notTrashed) }
        return (subject, target.id)
    }

    func observe(_ call: CommandSimpleCall, in context: ModelContext) throws -> CommandSimpleState {
        let (subject, id) = try trashed(call, in: context)
        let children: Children = subject.deletedAt.map { .willRestore($0) } ?? .liveAfter(nil)
        return try state(subject, key: id, deleted: subject.deletedAt != nil, children: children)
    }

    func expect(_ call: CommandSimpleCall, from before: CommandSimpleState, in context: ModelContext) throws -> CommandSimpleState {
        let (subject, id) = try trashed(call, in: context)
        // 恢复后连带项与父项一起是活的：按“恢复后活着的子项”计数，与写后重读一致。
        return try state(subject, key: id, deleted: false, children: .liveAfter(subject.deletedAt))
    }

    func apply(_ call: CommandSimpleCall, in context: ModelContext) throws {
        _ = try trashed(call, in: context)
        do { try restorer(context).restore(call.input.targets.objects[0], in: context) }
        catch TrashRestoreService.Refusal.ownerDeleted { throw CommandSimpleIssue.invalidTarget(.ownerTrashed) }
    }
}
