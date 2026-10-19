import Foundation
import SwiftData

/// G1 标签的四个简单指令，是 X-1 骨架的第一批真实消费者。只调用原 CatalogRepositoryProtocol 的方法；
/// 名称规则（修剪空白、空名、规范化重名、预置标签）沿用 SwiftDataCatalogRepository 与 TagManagementPage。
/// 私密标签：原界面改名、改色、排序都不需要解锁，保护按标签 UUID 关联，本指令保持一致。
/// 新建标签只来自显式 tag.create；搜索仍不能创建标签。
@MainActor enum TagCommandSpecs {
    typealias Repository = @MainActor (ModelContext) -> any CatalogRepositoryProtocol

    static func all(repository: @escaping Repository = { SwiftDataCatalogRepository(context: $0) }) -> [any SimpleCommandSpec] {
        [TagCreateSpec(repository: repository), TagRenameSpec(repository: repository),
         TagColorSpec(repository: repository), TagOrderSpec(repository: repository)]
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

/// tag.color → batchSetColor(ids:colorToken:)：固定集合一次改色。预置标签整组拒绝，不像仓储那样静默跳过。
@MainActor struct TagColorSpec: SimpleCommandSpec {
    let repository: TagCommandSpecs.Repository
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

    func observe(_ input: CommandResolvedInput, in context: ModelContext) throws -> CommandSimpleState {
        _ = try token(input)
        return .init(rows: try input.targets.objects.map {
            let tag = try TagCommandSpecs.tag($0, in: context)
            return TagCommandSpecs.row(tag, TagCommandSpecs.colorField(tag.colorToken))
        })
    }

    func expect(_ input: CommandResolvedInput, from before: CommandSimpleState,
                in context: ModelContext) throws -> CommandSimpleState {
        let token = try token(input)
        return .init(rows: try input.targets.objects.map {
            let tag = try TagCommandSpecs.tag($0, in: context)
            guard !tag.isDiaryPreset else { throw CommandSimpleIssue.invalidTarget(.protected) }
            return TagCommandSpecs.row(tag, TagCommandSpecs.colorField(token))
        })
    }

    func apply(_ input: CommandResolvedInput, in context: ModelContext) throws {
        try repository(context).batchSetColor(ids: Set(input.targets.objects.map(\.id)), colorToken: token(input))
    }
}

/// tag.order → reorderTags(orderedIDs:)：与原界面拖动一致，固定集合必须是全部活标签的新顺序。
@MainActor struct TagOrderSpec: SimpleCommandSpec {
    let repository: TagCommandSpecs.Repository
    let command = CommandID(rawValue: "tag.order")
    let shape = CommandSimpleShape.fixed(.tag)
    let copy = CommandSimpleCopy(preview: "unified.simple.tag.order.preview", saved: "unified.simple.tag.order.saved")

    func observe(_ input: CommandResolvedInput, in context: ModelContext) throws -> CommandSimpleState {
        guard TagCommandSpecs.arguments(input).isEmpty else { throw CommandSimpleIssue.invalidArguments }
        let tags = try input.targets.objects.map { try TagCommandSpecs.tag($0, in: context) }
        let live = try context.fetch(FetchDescriptor<TagItem>(predicate: #Predicate { $0.deletedAt == nil }))
        guard Set(live.map(\.id)) == Set(tags.map(\.id)), live.count == tags.count else {
            throw CommandSimpleIssue.invalidTarget(.incompleteOrder)
        }
        return .init(rows: tags.map { TagCommandSpecs.row($0, TagCommandSpecs.orderField($0.sortOrder)) })
    }

    func expect(_ input: CommandResolvedInput, from before: CommandSimpleState,
                in context: ModelContext) throws -> CommandSimpleState {
        let tags = try input.targets.objects.map { try TagCommandSpecs.tag($0, in: context) }
        return .init(rows: tags.enumerated().map { TagCommandSpecs.row($1, TagCommandSpecs.orderField($0)) })
    }

    func apply(_ input: CommandResolvedInput, in context: ModelContext) throws {
        try repository(context).reorderTags(orderedIDs: input.targets.objects.map(\.id))
    }
}
