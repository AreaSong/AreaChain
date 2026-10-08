import Foundation

/// 仅向普通集合字段公开可确定身份的候选；完整目录只留在读取边界用于失效核对。
struct CommandTaskTagCandidates: Equatable {
    let evidence: CommandTaskTagCatalog.Evidence
    let records: [CommandTaskTagRecord]

    init(catalog: CommandTaskTagCatalog, liveOnly: Bool = false) throws {
        let lookup = CommandTaskTagLookup(catalog)
        guard lookup.catalogProblems.isEmpty else { throw CommandTaskCreatePreviewIssue.invalidCatalog }
        evidence = try catalog.evidence()
        records = catalog.records.filter { row in
            guard !liveOnly || row.state == .live, let id = row.id,
                  case .success(.existing(let eligible)) = lookup.resolve(.id(id)) else { return false }
            return eligible == row
        }
    }

    func matching(_ query: String) -> [CommandTaskTagRecord] {
        let candidates = SyntaxAutocompleteEngine.candidates(
            for: .init(kind: .tag, query: query, range: .init(location: 0, length: 0)),
            availableTags: records.compactMap(\.name), context: .taskTags)
        let names = Set(candidates.filter { !$0.isCreation }.map(\.title))
        return records.filter { names.contains("#" + ($0.name ?? "")) }
    }
}
