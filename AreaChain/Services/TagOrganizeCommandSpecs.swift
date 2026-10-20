import Foundation
import SwiftData

/// 合并批 M-2 B：标签整理的简单指令。全部只调原仓储方法（与 TagManagementPage／各对象的标签切换同一入口），
/// 依赖由调用方注入；只在测试夹具里构造，生产没有构造点。永久删除与清理未使用（tag.delete／tag.cleanup）不在这里。
@MainActor struct TagOrganizeDependencies {
    var catalog: (ModelContext) -> any CatalogRepositoryProtocol = { SwiftDataCatalogRepository(context: $0) }
    var tasks: (ModelContext) -> any TaskRepositoryProtocol = { SwiftDataTaskRepository(context: $0) }
    var routines: (ModelContext) -> any RoutineRepositoryProtocol = { SwiftDataRoutineRepository(context: $0) }
    /// 手记写标签要重写正文：仓储须带调用方给出的隐私保险箱（隔离环境注入），没有生产默认值。
    var diaries: (ModelContext) -> any DiaryRepositoryProtocol
    /// 待办、习惯、子任务的普通来源证明，同任务类指令；不是 ordinary 时拒绝。
    var source: (CommandObjectReference) throws -> CommandTaskTitleEligibility
    var isPreset: TagCommandSpecs.Preset = { $0.isDiaryPreset }
}

@MainActor enum TagOrganizeSpecs {
    static func all(_ dependencies: TagOrganizeDependencies) -> [any SimpleCommandSpec] {
        [TagMergeSpec(dependencies: dependencies), TagUnlinkSpec(dependencies: dependencies),
         TagTrashSpec(dependencies: dependencies), TagRestoreSpec(dependencies: dependencies)]
    }

    /// 同 UUID 唯一的一行，删除与否都读（回收、恢复、合并后的写后核对要读到墓碑）。
    static func anyTag(_ id: UUID, in context: ModelContext) throws -> TagItem {
        let rows = try context.fetch(FetchDescriptor<TagItem>(predicate: #Predicate { $0.id == id }))
        guard let tag = rows.first else { throw CommandSimpleIssue.invalidTarget(.missing) }
        guard rows.count == 1 else { throw CommandSimpleIssue.invalidTarget(.duplicate) }
        return tag
    }

    /// 与标签页计数同一口径（TagUsage）：未删除的待办、习惯、子任务与手记里，挂了其中任一标签的对象数。
    static func linkedCount(_ ids: Set<UUID>, in context: ModelContext) throws -> Int {
        let subjects = TagUsage.subjects(todos: try context.fetch(FetchDescriptor<TodoItem>()),
                                         routines: try context.fetch(FetchDescriptor<DailyRoutine>()),
                                         diaries: try context.fetch(FetchDescriptor<DiaryEntry>()))
        return subjects.filter { !$0.isDeleted && !ids.isDisjoint(with: TagIDList.parse($0.tagIDs)) }.count
    }

    static func stateField(_ deleted: Bool, merged: Bool = false) -> CommandSimpleField {
        let value = deleted ? (merged ? "merged" : "trashed") : "live"
        return .init(id: "state", value: value, display: .localized("unified.simple.value." + value))
    }

    static func countField(_ id: String, _ count: Int) -> CommandSimpleField {
        .init(id: id, value: String(count), display: .verbatim(String(count)))
    }
}

/// tag.merge → mergeTags(sourceIDs:into:)：只合并普通标签。来源或目标里有私密标签整条拒绝（用户决策 3，
/// 涉及私密标签的合并要去原标签页做）；预置标签与原标签页一样不能参与合并。目标出现在来源里时按原页面从来源里去掉。
@MainActor struct TagMergeSpec: SimpleCommandCallSpec {
    let dependencies: TagOrganizeDependencies
    let command = CommandID(rawValue: "tag.merge")
    let shape = CommandSimpleShape.fixed(.tag)
    let copy = CommandSimpleCopy(preview: "unified.simple.tag.merge.preview", saved: "unified.simple.tag.merge.saved")

    private func ids(_ input: CommandResolvedInput) throws -> (sources: [UUID], target: UUID) {
        guard let argument = TagCommandSpecs.arguments(input).first(where: { $0.parameter == .destination }),
              case .object(let destination)? = argument.value, destination.type == .tag else {
            throw CommandSimpleIssue.invalidArguments
        }
        let sources = input.targets.objects.map(\.id).filter { $0 != destination.id }
        guard !sources.isEmpty else { throw CommandSimpleIssue.invalidArguments }
        return (sources, destination.id)
    }

    /// 准备与复核：来源与目标都须是活的普通标签。
    private func live(_ input: CommandResolvedInput, in context: ModelContext) throws -> (sources: [TagItem], target: TagItem) {
        let (sources, target) = try ids(input)
        let tags = try (sources + [target]).map { try TagCommandSpecs.tag(.init(type: .tag, id: $0), in: context) }
        guard !tags.contains(where: \.isPrivateDiary), !tags.contains(where: dependencies.isPreset) else {
            throw CommandSimpleIssue.invalidTarget(.protected)
        }
        return (Array(tags.dropLast()), tags[tags.count - 1])
    }

    private func state(_ sources: [TagItem], target: TagItem, merged: Bool, links: Int) -> CommandSimpleState {
        .init(rows: sources.map { TagCommandSpecs.row($0, TagOrganizeSpecs.stateField(merged, merged: true)) }
            + [TagCommandSpecs.row(target, TagOrganizeSpecs.countField("links", links))])
    }

    func observe(_ call: CommandSimpleCall, in context: ModelContext) throws -> CommandSimpleState {
        guard call.frozen != nil else {
            let (sources, target) = try live(call.input, in: context)
            return state(sources, target: target, merged: false, links: try TagOrganizeSpecs.linkedCount([target.id], in: context))
        }
        let (sourceIDs, targetID) = try ids(call.input)
        let sources = try sourceIDs.map { try TagOrganizeSpecs.anyTag($0, in: context) }
        let target = try TagOrganizeSpecs.anyTag(targetID, in: context)
        return .init(rows: sources.map { TagCommandSpecs.row($0, TagOrganizeSpecs.stateField($0.deletedAt != nil, merged: true)) }
            + [TagCommandSpecs.row(target, TagOrganizeSpecs.countField("links", try TagOrganizeSpecs.linkedCount([targetID], in: context)))])
    }

    func expect(_ call: CommandSimpleCall, from before: CommandSimpleState, in context: ModelContext) throws -> CommandSimpleState {
        let (sources, target) = try live(call.input, in: context)
        let links = try TagOrganizeSpecs.linkedCount(Set(sources.map(\.id) + [target.id]), in: context)
        return state(sources, target: target, merged: true, links: links)
    }

    func apply(_ call: CommandSimpleCall, in context: ModelContext) throws {
        let (sources, target) = try live(call.input, in: context)
        try dependencies.catalog(context).mergeTags(sourceIDs: sources.map(\.id), into: target.id)
    }
}

/// tag.unlinkObject：从待办、习惯、子任务、手记上移除指定的活标签，逐个调对象原有的标签切换入口
/// （只切换确实挂着的标签）。受保护的手记（私密或挂着私密标签）拿不到解锁资格，整条拒绝；任务一侧沿普通来源证明。
@MainActor struct TagUnlinkSpec: SimpleCommandSpec {
    let dependencies: TagOrganizeDependencies
    let command = CommandID(rawValue: "tag.unlinkObject")
    let shape = CommandSimpleShape.fixedAny([.todo, .routine, .subtask, .diary])
    let copy = CommandSimpleCopy(preview: "unified.simple.tag.unlink.preview", saved: "unified.simple.tag.unlink.saved")

    private struct Owner {
        let reference: CommandObjectReference
        let record: PersistentIdentifier
        let title: String
        let tagIDs: String
    }

    private func tags(_ input: CommandResolvedInput, in context: ModelContext) throws -> Set<UUID> {
        guard let argument = TagCommandSpecs.arguments(input).first(where: { $0.parameter == .tags }),
              case .tags(let ids)? = argument.value, !ids.isEmpty else { throw CommandSimpleIssue.invalidArguments }
        for id in ids { _ = try TagCommandSpecs.tag(.init(type: .tag, id: id), in: context) }
        return Set(ids)
    }

    private func owner(_ target: CommandObjectReference, in context: ModelContext) throws -> Owner {
        switch target.type {
        case .todo:
            let todo = try TaskCommandSpecs.todo(target.id, in: context)
            try qualify(target)
            return .init(reference: target, record: todo.persistentModelID, title: todo.title, tagIDs: todo.tagIDs)
        case .routine:
            let routine = try TaskCommandSpecs.routine(target.id, in: context)
            try qualify(target)
            return .init(reference: target, record: routine.persistentModelID, title: routine.title, tagIDs: routine.tagIDs)
        case .subtask:
            let subtask = try TaskCommandSpecs.subtask(target.id, in: context)
            try qualify(target)
            return .init(reference: target, record: subtask.persistentModelID, title: subtask.title, tagIDs: subtask.tagIDs)
        case .diary:
            let id = target.id
            let entry = try TaskCommandSpecs.unique(context.fetch(FetchDescriptor<DiaryEntry>(predicate: #Predicate { $0.id == id })),
                                                    deletedAt: \.deletedAt)
            // 隐私门禁：受保护手记的标签要解锁后在原页面改；指令拿不到资格就拒绝，不读正文、不显示标题。
            guard !entry.hasProtectedContent,
                  !DiaryPrivacy.isSensitive(entry.snapshot, tags: try context.fetch(FetchDescriptor<TagItem>())) else {
                throw CommandSimpleIssue.invalidTarget(.protectedSource)
            }
            // 普通手记没有标题字段，行标题取正文首行（与结果列表的普通手记同为原文）。
            let firstLine = entry.text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
            return .init(reference: target, record: entry.persistentModelID, title: String(firstLine.prefix(40)), tagIDs: entry.tagIDs)
        default: throw CommandSimpleIssue.invalidArguments
        }
    }

    private func qualify(_ target: CommandObjectReference) throws {
        let source: CommandTaskTitleEligibility
        do { source = try dependencies.source(target) } catch { throw CommandSimpleIssue.invalidTarget(.protectedSource) }
        guard source.protection == .ordinary else { throw CommandSimpleIssue.invalidTarget(.protectedSource) }
    }

    private func row(_ owner: Owner, tagIDs: [UUID], in context: ModelContext) throws -> CommandSimpleRow {
        let names = try TaskCommandSpecs.tagNames(TagIDList.encode(tagIDs), in: context)
        return .init(key: owner.reference.type.rawValue + ":" + owner.reference.id.uuidString, record: owner.record,
                     title: owner.title, fields: [TaskCommandSpecs.tagsField(names)])
    }

    func observe(_ input: CommandResolvedInput, in context: ModelContext) throws -> CommandSimpleState {
        _ = try tags(input, in: context)
        return .init(rows: try input.targets.objects.map { target in
            let owner = try owner(target, in: context)
            return try row(owner, tagIDs: TagIDList.parse(owner.tagIDs), in: context)
        })
    }

    func expect(_ input: CommandResolvedInput, from before: CommandSimpleState, in context: ModelContext) throws -> CommandSimpleState {
        let removing = try tags(input, in: context)
        return .init(rows: try input.targets.objects.map { target in
            let owner = try owner(target, in: context)
            return try row(owner, tagIDs: TagIDList.parse(owner.tagIDs).filter { !removing.contains($0) }, in: context)
        })
    }

    func apply(_ input: CommandResolvedInput, in context: ModelContext) throws {
        let removing = try tags(input, in: context)
        for target in input.targets.objects {
            let owner = try owner(target, in: context)
            for tag in TagIDList.parse(owner.tagIDs) where removing.contains(tag) {
                switch target.type {
                case .todo: try dependencies.tasks(context).toggleTag(id: target.id, tagID: tag)
                case .subtask: try dependencies.tasks(context).toggleSubtaskTag(id: target.id, tagID: tag)
                case .routine: try dependencies.routines(context).toggleTag(id: target.id, tagID: tag)
                default: try dependencies.diaries(context).toggleTag(id: target.id, tagID: tag)
                }
            }
        }
    }
}

/// tag.trash → deleteTag(id:soft: true)：与原标签页“删除”同一入口（进回收站、保留关联）。独立确认，
/// 确认面板列出会受影响的对象数（同标签页计数口径）。私密与预置标签与原页面一样可以回收。
@MainActor struct TagTrashSpec: SimpleCommandCallSpec {
    let dependencies: TagOrganizeDependencies
    let command = CommandID(rawValue: "tag.trash")
    let shape = CommandSimpleShape.single(.tag)
    let copy = CommandSimpleCopy(preview: "unified.simple.tag.trash.preview", saved: "unified.simple.tag.trash.saved")
    var confirms: Bool { true }

    private func state(_ tag: TagItem, deleted: Bool, in context: ModelContext) throws -> CommandSimpleState {
        let count = try TagOrganizeSpecs.linkedCount([tag.id], in: context)
        return .init(rows: [TagCommandSpecs.row(tag, TagOrganizeSpecs.stateField(deleted))],
                     notices: [.init(key: "unified.simple.tag.trash.affected", title: String(count))])
    }

    func observe(_ call: CommandSimpleCall, in context: ModelContext) throws -> CommandSimpleState {
        let target = call.input.targets.objects[0]
        let tag = call.frozen == nil ? try TagCommandSpecs.tag(target, in: context) : try TagOrganizeSpecs.anyTag(target.id, in: context)
        return try state(tag, deleted: tag.deletedAt != nil, in: context)
    }

    func expect(_ call: CommandSimpleCall, from before: CommandSimpleState, in context: ModelContext) throws -> CommandSimpleState {
        try state(TagCommandSpecs.tag(call.input.targets.objects[0], in: context), deleted: true, in: context)
    }

    func apply(_ call: CommandSimpleCall, in context: ModelContext) throws {
        try dependencies.catalog(context).deleteTag(id: call.input.targets.objects[0].id, soft: true)
    }
}

/// tag.restore → restoreTag(id:)：与原标签页“恢复”同一入口；目标须是回收站里的标签。独立确认，列出恢复后重新出现的对象数。
@MainActor struct TagRestoreSpec: SimpleCommandCallSpec {
    let dependencies: TagOrganizeDependencies
    let command = CommandID(rawValue: "tag.restore")
    let shape = CommandSimpleShape.single(.tag)
    let copy = CommandSimpleCopy(preview: "unified.simple.tag.restore.preview", saved: "unified.simple.tag.restore.saved")
    var confirms: Bool { true }

    private func state(_ tag: TagItem, deleted: Bool, in context: ModelContext) throws -> CommandSimpleState {
        let count = try TagOrganizeSpecs.linkedCount([tag.id], in: context)
        return .init(rows: [TagCommandSpecs.row(tag, TagOrganizeSpecs.stateField(deleted))],
                     notices: [.init(key: "unified.simple.tag.restore.affected", title: String(count))])
    }

    private func trashed(_ call: CommandSimpleCall, in context: ModelContext) throws -> TagItem {
        let tag = try TagOrganizeSpecs.anyTag(call.input.targets.objects[0].id, in: context)
        guard call.frozen != nil || tag.deletedAt != nil else { throw CommandSimpleIssue.invalidTarget(.notTrashed) }
        return tag
    }

    func observe(_ call: CommandSimpleCall, in context: ModelContext) throws -> CommandSimpleState {
        let tag = try trashed(call, in: context)
        return try state(tag, deleted: tag.deletedAt != nil, in: context)
    }

    func expect(_ call: CommandSimpleCall, from before: CommandSimpleState, in context: ModelContext) throws -> CommandSimpleState {
        try state(trashed(call, in: context), deleted: false, in: context)
    }

    func apply(_ call: CommandSimpleCall, in context: ModelContext) throws {
        try dependencies.catalog(context).restoreTag(id: call.input.targets.objects[0].id)
    }
}
