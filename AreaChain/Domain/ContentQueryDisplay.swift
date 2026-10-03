import Foundation

/// 身份独立于排名和 displayAnchor；分组异常回退为 row 时不宣称父子关系。
enum ContentQueryDisplayUnitID: Hashable {
    case row(CommandObjectReference), trashGroup(CommandObjectReference)
}

struct ContentQueryDisplayContext: Hashable {
    let group: CommandObjectReference
    let object: CommandObjectReference
}

enum ContentQueryDisplayControl: Hashable {
    case contextToggle(CommandObjectReference)
    case context(ContentQueryDisplayContext)
    case bodyToggle(CommandObjectReference, ContentQueryMatchField)
    case body(CommandObjectReference, ContentQueryMatchField)
}

struct ContentQueryDisplayUnit: Equatable, Identifiable {
    let id: ContentQueryDisplayUnitID
    let hits: [CommandObjectReference]
    let sourceGroup: CommandObjectReference?
    let displayAnchor: CommandObjectReference
    let context: [ContentQueryDisplayContext]
    var bestMatch: CommandObjectReference { hits[0] }
}

enum ContentQueryDisplayIssue: Equatable {
    case invalidHit(CommandObjectReference)
    case invalidGroup(CommandObjectReference)
    case missingGroupReference(group: CommandObjectReference, object: CommandObjectReference)
    case conflictingGroup(CommandObjectReference)
    case ungroupedHit(CommandObjectReference)
}

/// 唯一保存安全呈现来源；单位、可见性和选择均不复制正文或完整响应。
struct ContentQueryDisplaySnapshot: CustomStringConvertible, CustomDebugStringConvertible {
    let version: UUID
    private let storage: ContentQueryDisplaySource
    var sourceID: UUID { storage.id }
    var source: ContentQueryPresentationResponse { storage.response }
    var units: [ContentQueryDisplayUnit] { storage.units }
    var diagnostics: [ContentQueryDisplayIssue] { storage.diagnostics }
    let visibility: ContentQueryDisplayVisibility
    var known: Set<CommandObjectReference> { storage.known }
    var visible: [CommandObjectReference] {
        units.filter { visibility.units.contains($0.id) }.flatMap { unit in
            unit.hits.filter { visibility.members.contains($0) }
        }
    }
    var knownUndisplayedCount: Int { known.count - visible.count }
    var description: String { "ContentQueryDisplaySnapshot(redacted)" }
    var debugDescription: String { description }

    init(source: ContentQueryPresentationResponse, units: [ContentQueryDisplayUnit],
         diagnostics: [ContentQueryDisplayIssue], visibility: ContentQueryDisplayVisibility) {
        self.init(storage: .init(response: source, units: units, diagnostics: diagnostics), visibility: visibility)
    }

    private init(storage: ContentQueryDisplaySource, visibility: ContentQueryDisplayVisibility) {
        self.storage = storage
        self.visibility = visibility
        version = UUID()
    }

    /// 只更新身份可见范围；不接受替换响应、外部版本或追加数组。
    func revisingVisibility(_ visibility: ContentQueryDisplayVisibility) -> Self {
        .init(storage: storage, visibility: visibility)
    }

    func sharesSource(with other: Self) -> Bool { storage === other.storage }

    func visibleContext(in unit: ContentQueryDisplayUnit) -> [ContentQueryDisplayContext] {
        guard visibility.units.contains(unit.id) else { return [] }
        return unit.context.filter { visibility.contexts?.contains($0) ?? true }
    }

    func knownUndisplayedCount(in unitID: ContentQueryDisplayUnitID) -> Int {
        guard let unit = units.first(where: { $0.id == unitID }) else { return 0 }
        guard visibility.units.contains(unitID) else { return unit.hits.count }
        return unit.hits.filter { !visibility.members.contains($0) }.count
    }

    func row(_ id: CommandObjectReference) -> ContentQueryPresentationRow? {
        guard let index = storage.rowIndices[id] else { return nil }
        return source.rows[index]
    }

    /// 只解析提供者已发布的安全 context，绝不访问原始输入或墓碑读取器。
    func context(_ reference: ContentQueryDisplayContext) -> TrashTombstone? {
        guard units.contains(where: { $0.context.contains(reference) }) else { return nil }
        for reading in source.source.source.readings {
            if case .trash(let response) = reading,
               let group = response.groups.first(where: { $0.source.id == reference.group }) {
                return group.context.first { $0.id == reference.object }
            }
        }
        return nil
    }
}

/// 后续分页只需提交单位与成员身份集合；顺序始终来自展示模型，不接受外部下标。
struct ContentQueryDisplayVisibility: Equatable {
    let units: Set<ContentQueryDisplayUnitID>
    let members: Set<CommandObjectReference>
    /// nil 保持 2J-3A 显式展示调用的兼容语义；分页始终传入有界集合。
    var contexts: Set<ContentQueryDisplayContext>?

    static func all(_ units: [ContentQueryDisplayUnit]) -> Self {
        .init(units: Set(units.map(\.id)), members: Set(units.flatMap(\.hits)))
    }
}

/// 每次 build 新建来源；UUID 与正文、requestID 无关，调用方不能替换已绑定内容。
private final class ContentQueryDisplaySource {
    let id = UUID()
    let response: ContentQueryPresentationResponse
    let units: [ContentQueryDisplayUnit]
    let diagnostics: [ContentQueryDisplayIssue]
    let known: Set<CommandObjectReference>
    let rowIndices: [CommandObjectReference: Int]

    init(response: ContentQueryPresentationResponse, units: [ContentQueryDisplayUnit],
         diagnostics: [ContentQueryDisplayIssue]) {
        self.response = response
        self.units = units
        self.diagnostics = diagnostics
        let known = Set(units.flatMap(\.hits))
        self.known = known
        let rows = Dictionary(grouping: response.rows.indices, by: { response.rows[$0].id })
        rowIndices = rows.compactMapValues { $0.count == 1 ? $0.first : nil }.filter { known.contains($0.key) }
    }
}
