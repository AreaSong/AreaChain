import CryptoKit
import Foundation

/// 由调用方提供的值事实。缺字段与未知状态不能冒充普通、活标签。
struct CommandTaskTagRecord: Equatable, Codable, CustomStringConvertible, CustomDebugStringConvertible {
    enum State: Equatable, Codable { case live, deleted(Date), unknown }
    let id: UUID?
    let name: String?
    let state: State
    let isPrivateDiary: Bool?

    var normalizedName: String? { name.map(TagSyntax.normalizedName) }
    var isPreset: Bool {
        normalizedName.map { key in DiaryMemoTags.presets.contains { TagSyntax.normalizedName($0) == key } } ?? false
    }
    var description: String { "CommandTaskTagRecord(redacted)" }
    var debugDescription: String { description }
}

struct CommandTaskTagCatalog: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    enum Coverage: String { case complete, partial, unavailable }
    let directoryID: UUID
    let readID: UUID
    let revision: UInt64
    let coverage: Coverage
    let records: [CommandTaskTagRecord]

    /// 全目录事实摘要保守失效；不在预览中留下全目录或存储访问能力。
    func evidence() throws -> Evidence {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let rows = try records.map { try encoder.encode($0).base64EncodedString() }.sorted()
        let digest = Array(SHA256.hash(data: try encoder.encode(rows)))
        return Evidence(directoryID: directoryID, readID: readID, revision: revision,
                        coverage: coverage, digest: digest)
    }

    struct Evidence: Equatable {
        let directoryID: UUID
        let readID: UUID
        let revision: UInt64
        let coverage: Coverage
        let digest: [UInt8]
    }
    var description: String { "CommandTaskTagCatalog(redacted)" }
    var debugDescription: String { description }
}

enum CommandTaskTagSelection: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    case name(String), id(UUID)
    var description: String { "CommandTaskTagSelection(redacted)" }
    var debugDescription: String { description }
}

struct CommandTaskTagProblem: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    enum Kind { case incompleteCatalog, incompleteRecord, duplicateID, ambiguousName, missingID, protectedTag }
    let selection: CommandTaskTagSelection?
    let kind: Kind
    var description: String { "CommandTaskTagProblem(\(kind))" }
    var debugDescription: String { description }
}

/// 与 InputTagResolver 共用名字规范化及活/恢复/新建语义；新命令有意拒绝旧 UI 的 first-wins。
struct CommandTaskTagLookup {
    let catalog: CommandTaskTagCatalog
    private let byID: [UUID: [CommandTaskTagRecord]]
    private let byName: [String: [CommandTaskTagRecord]]
    let catalogProblems: [CommandTaskTagProblem]

    init(_ catalog: CommandTaskTagCatalog) {
        self.catalog = catalog
        byID = Dictionary(grouping: catalog.records.filter { $0.id != nil }, by: { $0.id! })
        byName = Dictionary(grouping: catalog.records.filter { $0.normalizedName != nil }, by: { $0.normalizedName! })
        catalogProblems = Self.problems(catalog)
    }

    private static func problems(_ catalog: CommandTaskTagCatalog) -> [CommandTaskTagProblem] {
        var result: [CommandTaskTagProblem] = []
        if catalog.coverage != .complete { result.append(.init(selection: nil, kind: .incompleteCatalog)) }
        // 无身份或名字的行可能隐藏另一个匹配，不能仅跳过这些行。
        if catalog.records.contains(where: { $0.id == nil || $0.normalizedName?.isEmpty != false }) {
            result.append(.init(selection: nil, kind: .incompleteRecord))
        }
        return result
    }

    func resolve(_ selection: CommandTaskTagSelection) -> Result<CommandTaskTagTarget, Failure> {
        let matches: [CommandTaskTagRecord]
        switch selection {
        case .id(let id):
            matches = byID[id] ?? []
            if matches.isEmpty { return .failure(.init(kind: .missingID)) }
        case .name(let name):
            let key = TagSyntax.normalizedName(name)
            if DiaryMemoTags.presets.contains(where: { TagSyntax.normalizedName($0) == key }) {
                return .failure(.init(kind: .protectedTag))
            }
            matches = byName[key] ?? []
            if matches.isEmpty {
                return .success(.newName(name.trimmingCharacters(in: .whitespacesAndNewlines), normalized: key))
            }
        }
        guard matches.count == 1, let row = matches.first else {
            return .failure(.init(kind: selection.isID ? .duplicateID : .ambiguousName))
        }
        guard let id = row.id, let key = row.normalizedName, !key.isEmpty,
              row.isPrivateDiary != nil, row.state != .unknown else { return .failure(.init(kind: .incompleteRecord)) }
        guard byID[id]?.count == 1 else { return .failure(.init(kind: .duplicateID)) }
        // 显式 ID 也不绕过同名歧义：后续名字解析必须能得到同一个身份。
        guard byName[key]?.count == 1 else { return .failure(.init(kind: .ambiguousName)) }
        guard row.isPrivateDiary == false, !row.isPreset else { return .failure(.init(kind: .protectedTag)) }
        return .success(.existing(row))
    }

    struct Failure: Error { let kind: CommandTaskTagProblem.Kind }
}

private extension CommandTaskTagSelection {
    var isID: Bool { if case .id = self { return true }; return false }
}
