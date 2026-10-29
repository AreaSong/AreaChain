import Foundation
import SwiftData

/// G1 标签的四个简单指令，是简单指令骨架的第一批真实消费者。只调用原 CatalogRepositoryProtocol 的方法；
/// 名称规则（修剪空白、空名、规范化重名、预置标签）沿用 SwiftDataCatalogRepository 与 TagManagementPage。
/// 私密标签：原界面改名、改色、排序都不需要解锁，保护按标签 UUID 关联，本指令保持一致。
/// 新建标签只来自显式 tag.create；搜索仍不能创建标签。
@MainActor enum TagCommandSpecs {
    typealias Repository = @MainActor (ModelContext) -> any CatalogRepositoryProtocol
    typealias Preset = @MainActor (TagItem) -> Bool

    /// `isPreset` 生产沿用 TagItem.isDiaryPreset；测试可注入夹具判定（当前生产判定恒为 false）。
    static func all(repository: @escaping Repository = { SwiftDataCatalogRepository(context: $0) },
                    isPreset: @escaping Preset = { $0.isDiaryPreset }) -> [any SimpleCommandSpec] {
        [TagCreateSpec(repository: repository), TagRenameSpec(repository: repository),
         TagColorSpec(repository: repository, isPreset: isPreset), TagOrderSpec(repository: repository)]
    }

    /// 指令参数；目标已由固定集合派生出 target 参数，这里不再重复读取。
    static func arguments(_ input: CommandResolvedInput) -> [CommandArgument] {
        input.arguments.filter { $0.parameter != .target }
    }

    /// 与原界面一致：去掉首尾空白；空名拒绝；单行短文本不接受换行。
    static func name(_ input: CommandResolvedInput) throws -> String {
        let arguments = arguments(input)
        guard arguments.count == 1, let argument = arguments.first, argument.parameter == .name,
              argument.operation == .assign, case .shortText(let raw)? = argument.value,
              !raw.contains(where: \.isNewline) else { throw CommandSimpleIssue.invalidArguments }
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw CommandSimpleIssue.invalidTarget(.empty) }
        return name
    }

    /// 与仓储一致：同规范化名字的活标签（改名时排除自己）视为重名。
    static func requireUnique(_ name: String, except id: UUID? = nil, in context: ModelContext) throws {
        let key = TagSyntax.normalizedName(name)
        let live = try context.fetch(FetchDescriptor<TagItem>(predicate: #Predicate { $0.deletedAt == nil }))
        if live.contains(where: { $0.id != id && TagSyntax.normalizedName($0.name) == key }) {
            throw CommandSimpleIssue.invalidTarget(.nameTaken)
        }
    }

    /// 目标必须是唯一、未删除的标签；同 UUID 多行或已删除都拒绝，不换成同名或首项。
    static func tag(_ target: CommandObjectReference, in context: ModelContext) throws -> TagItem {
        let id = target.id
        let rows = try context.fetch(FetchDescriptor<TagItem>(predicate: #Predicate { $0.id == id }))
        guard let tag = rows.first else { throw CommandSimpleIssue.invalidTarget(.missing) }
        guard rows.count == 1 else { throw CommandSimpleIssue.invalidTarget(.duplicate) }
        guard tag.deletedAt == nil else { throw CommandSimpleIssue.invalidTarget(.deleted) }
        return tag
    }

    static func row(_ tag: TagItem, _ field: CommandSimpleField) -> CommandSimpleRow {
        .init(key: tag.id.uuidString, record: tag.persistentModelID, title: tag.name, fields: [field])
    }

    static func nameField(_ name: String) -> CommandSimpleField { .init(id: "name", value: name, display: .verbatim(name)) }

    static func colorField(_ token: String) -> CommandSimpleField {
        let display: CommandSimpleDisplay = TagColorToken(rawValue: token).map { .localized("tags.color." + $0.rawValue) }
            ?? .verbatim(token)
        return .init(id: "color", value: token, display: display)
    }

    static func orderField(_ order: Int) -> CommandSimpleField {
        .init(id: "order", value: String(order), display: .verbatim(String(order + 1)))
    }
}

/// tag.create → createTag(name:sortOrder: nil)：排在最后，与原界面新建一致；不带私密选项。
@MainActor struct TagCreateSpec: SimpleCommandSpec {
    let repository: TagCommandSpecs.Repository
    let command = CommandID(rawValue: "tag.create")
    let shape = CommandSimpleShape.none
    let copy = CommandSimpleCopy(preview: "unified.simple.tag.create.preview", saved: "unified.simple.tag.create.saved")

    /// 新标签没有可预知的 UUID：按规范化名字读取同名活标签。
    func observe(_ input: CommandResolvedInput, in context: ModelContext) throws -> CommandSimpleState {
        let name = try TagCommandSpecs.name(input)
        let key = TagSyntax.normalizedName(name)
        let live = try context.fetch(FetchDescriptor<TagItem>(predicate: #Predicate { $0.deletedAt == nil }))
        return .init(rows: live.filter { TagSyntax.normalizedName($0.name) == key }
            .map { .init(key: "name:" + key, record: nil, title: $0.name, fields: [TagCommandSpecs.nameField($0.name)]) })
    }

    func expect(_ input: CommandResolvedInput, from before: CommandSimpleState,
                in context: ModelContext) throws -> CommandSimpleState {
        let name = try TagCommandSpecs.name(input)
        guard before.rows.isEmpty else { throw CommandSimpleIssue.invalidTarget(.nameTaken) }
        try TagCommandSpecs.requireUnique(name, in: context)
        return .init(rows: [.init(key: "name:" + TagSyntax.normalizedName(name), record: nil, title: name,
                                  fields: [TagCommandSpecs.nameField(name)])])
    }

    func apply(_ input: CommandResolvedInput, in context: ModelContext) throws {
        try repository(context).createTag(name: TagCommandSpecs.name(input), sortOrder: nil)
    }
}

/// tag.rename → updateTag(id:name:sortOrder: nil, colorToken: nil)：只改名字。
@MainActor struct TagRenameSpec: SimpleCommandSpec {
    let repository: TagCommandSpecs.Repository
    let command = CommandID(rawValue: "tag.rename")
    let shape = CommandSimpleShape.single(.tag)
    let copy = CommandSimpleCopy(preview: "unified.simple.tag.rename.preview", saved: "unified.simple.tag.rename.saved")

    func observe(_ input: CommandResolvedInput, in context: ModelContext) throws -> CommandSimpleState {
        let tag = try TagCommandSpecs.tag(input.targets.objects[0], in: context)
        return .init(rows: [TagCommandSpecs.row(tag, TagCommandSpecs.nameField(tag.name))])
    }

    func expect(_ input: CommandResolvedInput, from before: CommandSimpleState,
                in context: ModelContext) throws -> CommandSimpleState {
        let tag = try TagCommandSpecs.tag(input.targets.objects[0], in: context)
        guard !tag.isDiaryPreset else { throw CommandSimpleIssue.invalidTarget(.protected) }
        let name = try TagCommandSpecs.name(input)
        try TagCommandSpecs.requireUnique(name, except: tag.id, in: context)
        return .init(rows: [.init(key: tag.id.uuidString, record: tag.persistentModelID, title: name,
                                  fields: [TagCommandSpecs.nameField(name)])])
    }

    func apply(_ input: CommandResolvedInput, in context: ModelContext) throws {
        try repository(context).updateTag(id: input.targets.objects[0].id, name: TagCommandSpecs.name(input),
                                          sortOrder: nil, colorToken: nil)
    }
}

/// tag.color → batchSetColor(ids:colorToken:)：固定集合一次改色。与原标签页一致：预置标签静默跳过，
/// 并在预览与回执里列出被跳过的标签；全部是预置标签时与仓储一样拒绝。
@MainActor struct TagColorSpec: SimpleCommandSpec {
    let repository: TagCommandSpecs.Repository
    var isPreset: TagCommandSpecs.Preset = { $0.isDiaryPreset }
    let command = CommandID(rawValue: "tag.color")
    let shape = CommandSimpleShape.fixed(.tag)
    let copy = CommandSimpleCopy(preview: "unified.simple.tag.color.preview", saved: "unified.simple.tag.color.saved")

    private func token(_ input: CommandResolvedInput) throws -> String {
        let arguments = TagCommandSpecs.arguments(input)
        guard arguments.count == 1, let argument = arguments.first, argument.parameter == .color,
              argument.operation == .assign, case .choice(let raw)? = argument.value,
              TagColorToken(rawValue: raw) != nil else { throw CommandSimpleIssue.invalidArguments }
        return TagColorToken.resolvedToken(raw)
    }

    private func tags(_ input: CommandResolvedInput, in context: ModelContext) throws -> [TagItem] {
        try input.targets.objects.map { try TagCommandSpecs.tag($0, in: context) }
    }

    /// 预置标签不进入字段行，只作为“已跳过”提示；读取前后都由同一判定给出，写后核对保持相等。
    private func state(_ tags: [TagItem], color: (TagItem) -> String) -> CommandSimpleState {
        .init(rows: tags.filter { !isPreset($0) }.map { TagCommandSpecs.row($0, TagCommandSpecs.colorField(color($0))) },
              notices: tags.filter(isPreset).map { .init(key: "unified.simple.tag.color.skipped", title: $0.name) })
    }

    func observe(_ input: CommandResolvedInput, in context: ModelContext) throws -> CommandSimpleState {
        _ = try token(input)
        return state(try tags(input, in: context)) { $0.colorToken }
    }

    func expect(_ input: CommandResolvedInput, from before: CommandSimpleState,
                in context: ModelContext) throws -> CommandSimpleState {
        let token = try token(input)
        let tags = try tags(input, in: context)
        guard tags.contains(where: { !isPreset($0) }) else { throw CommandSimpleIssue.invalidTarget(.protected) }
        return state(tags) { _ in token }
    }

    /// 只传非预置标签：生产上与仓储自己的跳过等价，注入判定的夹具也不会被仓储改色。
    func apply(_ input: CommandResolvedInput, in context: ModelContext) throws {
        let ids = try tags(input, in: context).filter { !isPreset($0) }.map(\.id)
        try repository(context).batchSetColor(ids: Set(ids), colorToken: token(input))
    }
}

/// tag.order → reorderTags(orderedIDs:)：全部活标签（同标签页拖动的口径）中把目标移到 position 指定的位置。
/// 与 subtask／routine／tasks.order 一致用 position，不再把选择器登记顺序当新顺序。
@MainActor struct TagOrderSpec: SimpleCommandSpec {
    let repository: TagCommandSpecs.Repository
    let command = CommandID(rawValue: "tag.order")
    let shape = CommandSimpleShape.single(.tag)
    let copy = CommandSimpleCopy(preview: "unified.simple.tag.order.preview", saved: "unified.simple.tag.order.saved")

    /// 标签页按 sortOrder 排活标签；同值时再按 UUID，保证每次读取顺序一致。
    private func rows(_ input: CommandResolvedInput, in context: ModelContext) throws -> [OrderRows.Item] {
        guard let target = input.targets.objects.first else { throw CommandSimpleIssue.invalidArguments }
        _ = try TagCommandSpecs.tag(target, in: context)
        return try context.fetch(FetchDescriptor<TagItem>(predicate: #Predicate { $0.deletedAt == nil }))
            .sorted { ($0.sortOrder, $0.id.uuidString) < ($1.sortOrder, $1.id.uuidString) }
            .map { ($0.id, $0.persistentModelID, $0.name) }
    }

    func observe(_ input: CommandResolvedInput, in context: ModelContext) throws -> CommandSimpleState {
        OrderRows.state(try rows(input, in: context))
    }

    func expect(_ input: CommandResolvedInput, from before: CommandSimpleState,
                in context: ModelContext) throws -> CommandSimpleState {
        let rows = try rows(input, in: context)
        let index = try TaskCommandSpecs.position(input, count: rows.count)
        return OrderRows.state(OrderRows.moved(rows, moving: input.targets.objects[0].id, to: index))
    }

    func apply(_ input: CommandResolvedInput, in context: ModelContext) throws {
        let rows = try rows(input, in: context)
        let index = try TaskCommandSpecs.position(input, count: rows.count)
        try repository(context).reorderTags(orderedIDs: OrderRows.moved(rows, moving: input.targets.objects[0].id, to: index).map(\.0))
    }
}
