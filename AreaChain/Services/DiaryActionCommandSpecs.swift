import Foundation
import SwiftData

/// 手记动作里写库的两条——转今天任务、回收；复制走原卡片的剪贴板路径，不进骨架。
extension DiaryCommandSpecs {
    /// 默认不装配，只在隔离 QA 测试里显式传给 SimpleCommandAdapter。
    static func actions(_ dependencies: DiaryCommandDependencies) -> [any SimpleCommandSpec] {
        [DiaryToTodoSpec(dependencies: dependencies), DiaryTrashSpec(dependencies: dependencies)]
    }
}

/// diary.toTodo：沿原 convertDiaryToTodo 的规则（DiaryWriteService.todoText）——首行做标题、其余做备注、保留原手记、
/// 不带标签与附件、不做 NLP；敏感或受保护、标签读取失败一律拒绝。走共用独立确认、只能单项。
/// 新待办身份在准备时分配一次（仓储 creationID），重试不会另建；结果未知时沿骨架的只读核对。
@MainActor struct DiaryToTodoSpec: SimpleCommandCallSpec {
    let dependencies: DiaryCommandDependencies
    let command = CommandID(rawValue: "diary.toTodo")
    let shape = CommandSimpleShape.single(.diary)
    let copy = CommandSimpleCopy(preview: "unified.simple.diary.toTodo.preview", saved: "unified.simple.diary.toTodo.saved")
    var creates: CommandObjectType? { .todo }
    var confirms: Bool { true }

    private func creation(_ call: CommandSimpleCall) throws -> CommandObjectReference {
        guard let creation = call.creation, creation.type == .todo, TagCommandSpecs.arguments(call.input).isEmpty,
              call.input.targets.objects.count == 1 else { throw CommandSimpleIssue.invalidArguments }
        return creation
    }

    /// 普通手记的明文（不读受保护正文）与要建的标题、备注；空正文没有可转的内容。
    private func source(_ call: CommandSimpleCall, in context: ModelContext) throws -> (DiaryEntry, String, String) {
        let entry = try DiaryCommandSpecs.ordinary(call.input.targets.objects[0], in: context)
        guard let text = DiaryWriteService.todoText(from: entry.text) else { throw CommandSimpleIssue.invalidTarget(.diaryEmpty) }
        return (entry, text.title, text.notes)
    }

    private func todoRow(_ id: UUID, title: String, notes: String, day: String,
                         record: PersistentIdentifier?) -> CommandSimpleRow {
        .init(key: id.uuidString, record: record, title: title, fields: [
            .init(id: "title", value: title, display: .verbatim(title)),
            TaskCommandSpecs.notesField(notes, dependencies.digest), DiaryCommandSpecs.dayField(day)])
    }

    func observe(_ call: CommandSimpleCall, in context: ModelContext) throws -> CommandSimpleState {
        let creation = try creation(call)
        let (entry, _, _) = try source(call, in: context)
        var rows = [DiaryCommandSpecs.row(entry, fields: [])]
        let id = creation.id
        let created = try context.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id }))
        guard created.count <= 1 else { throw CommandSimpleIssue.invalidTarget(.duplicate) }
        if let todo = created.first {
            rows.append(todoRow(todo.id, title: todo.title, notes: todo.notes, day: todo.dayKey, record: nil))
        }
        return .init(rows: rows)
    }

    func expect(_ call: CommandSimpleCall, from before: CommandSimpleState, in context: ModelContext) throws -> CommandSimpleState {
        let creation = try creation(call)
        guard before.rows.allSatisfy({ $0.key != creation.id.uuidString }) else { throw CommandSimpleIssue.stale }
        let (_, title, notes) = try source(call, in: context)
        return .init(rows: before.rows + [todoRow(creation.id, title: title, notes: notes, day: dependencies.today(), record: nil)])
    }

    func apply(_ call: CommandSimpleCall, in context: ModelContext) throws {
        let creation = try creation(call)
        let (_, title, notes) = try source(call, in: context)
        _ = try dependencies.tasks(context).addTodo(.init(
            title: title, dayKey: dependencies.today(), notes: notes, sourceBundleID: dependencies.sourceBundleID(),
            creationID: creation.id))
    }

    /// 回执“打开新待办”：沿结果打开的同一解析（待办没有父对象）。
    func openTarget(_ creation: CommandObjectReference) -> ContentQueryBrowseOpen? {
        guard creation.type == .todo else { return nil }
        return .init(object: creation, parent: nil, viewingTrash: false)
    }
}

/// diary.trash：软删（与卡片“删除”同一仓储 deleteDiary(soft: true)，附件同戳回收），走共用独立确认、只能单项。
/// 目录要求的认证只为受保护手记：指令里从不认证，受保护目标拒绝并改为打开原手记页。
@MainActor struct DiaryTrashSpec: SimpleCommandSpec {
    let dependencies: DiaryCommandDependencies
    let command = CommandID(rawValue: "diary.trash")
    let shape = CommandSimpleShape.single(.diary)
    let copy = CommandSimpleCopy(preview: "unified.simple.diary.trash.preview", saved: "unified.simple.diary.trash.saved")
    var confirms: Bool { true }
    var refusesProtectedContent: Bool { true }

    private func attachments(_ id: UUID, in context: ModelContext) throws -> [AttachmentItem] {
        let kind = AttachmentOwner.diary.rawValue
        return try context.fetch(FetchDescriptor<AttachmentItem>(predicate: #Predicate { $0.ownerID == id && $0.ownerKind == kind }))
    }

    /// 确认面板列出随之回收的图片数（回收前数活的；回收后数与手记同一删除戳的）。
    private func state(_ entry: DiaryEntry, deleted: Bool, in context: ModelContext) throws -> CommandSimpleState {
        let items = try attachments(entry.id, in: context)
        let count = deleted ? items.filter { $0.deletedAt != nil && $0.deletedAt == entry.deletedAt }.count
            : items.filter { $0.deletedAt == nil }.count
        return .init(rows: [DiaryCommandSpecs.row(entry, fields: [TagOrganizeSpecs.stateField(deleted)])],
                     notices: [.init(key: "unified.simple.diary.trash.attachments", title: String(count))])
    }

    func observe(_ input: CommandResolvedInput, in context: ModelContext) throws -> CommandSimpleState {
        let entry = try DiaryCommandSpecs.ordinary(input.targets.objects[0], in: context, allowDeleted: true)
        return try state(entry, deleted: entry.deletedAt != nil, in: context)
    }

    func observe(_ call: CommandSimpleCall, in context: ModelContext) throws -> CommandSimpleState {
        let state = try observe(call.input, in: context)
        // 准备与复核时目标必须还活着；写后核对（frozen）读到的是回收后的状态。
        guard call.frozen != nil || state.rows.first?.fields.first?.value == "live" else {
            throw CommandSimpleIssue.invalidTarget(.deleted)
        }
        return state
    }

    func expect(_ input: CommandResolvedInput, from before: CommandSimpleState, in context: ModelContext) throws -> CommandSimpleState {
        let entry = try DiaryCommandSpecs.ordinary(input.targets.objects[0], in: context)
        let live = try attachments(entry.id, in: context).filter { $0.deletedAt == nil }.count
        return .init(rows: [DiaryCommandSpecs.row(entry, fields: [TagOrganizeSpecs.stateField(true)])],
                     notices: [.init(key: "unified.simple.diary.trash.attachments", title: String(live))])
    }

    func apply(_ input: CommandResolvedInput, in context: ModelContext) throws {
        let entry = try DiaryCommandSpecs.ordinary(input.targets.objects[0], in: context)
        try dependencies.diaries(context).deleteDiary(id: entry.id, soft: true)
    }
}
