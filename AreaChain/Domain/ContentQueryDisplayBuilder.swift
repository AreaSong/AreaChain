import Foundation

/// 只重组既有排名；任何不唯一的组引用整体失效，合法命中仍独立展示。
enum ContentQueryDisplayBuilder {
    static func build(_ source: ContentQueryPresentationResponse,
                      visibility: ContentQueryDisplayVisibility? = nil) -> ContentQueryDisplaySnapshot {
        let matches = Dictionary(grouping: source.source.source.matches, by: \.id)
        let rows = Dictionary(grouping: source.rows, by: \.id)
        let ranks = Dictionary(grouping: source.source.ordered, by: \.id)
        var issues: [ContentQueryDisplayIssue] = []
        var seen: Set<CommandObjectReference> = []
        let ordered = source.source.ordered.compactMap { rank -> CommandObjectReference? in
            guard seen.insert(rank.id).inserted else { return nil }
            guard matches[rank.id]?.count == 1, rows[rank.id]?.count == 1, ranks[rank.id]?.count == 1 else {
                issues.append(.invalidHit(rank.id)); return nil
            }
            return rank.id
        }
        let groups = source.source.source.readings.flatMap { reading -> [TrashQueryGroup] in
            if case .trash(let value) = reading { return value.groups }; return []
        }
        let valid = validated(groups, known: Set(ordered), matches: matches, issues: &issues)
        let owners = Dictionary(uniqueKeysWithValues: valid.flatMap { group in group.matches.map { ($0, group) } })
        var rankedMembers: [CommandObjectReference: [CommandObjectReference]] = [:]
        for id in ordered {
            if let group = owners[id] { rankedMembers[group.source.id, default: []].append(id) }
        }
        var emitted: Set<CommandObjectReference> = []
        var units: [ContentQueryDisplayUnit] = []
        for id in ordered {
            if let group = owners[id] {
                guard emitted.insert(group.source.id).inserted else { continue }
                let hits = rankedMembers[group.source.id, default: []]
                units.append(.init(id: .trashGroup(group.source.id), hits: hits, sourceGroup: group.source.id,
                    displayAnchor: group.displayAnchor,
                    context: group.context.map { .init(group: group.source.id, object: $0.id) }))
            } else {
                if let match = matches[id]?.first, case .trash = match { issues.append(.ungroupedHit(id)) }
                units.append(.init(id: .row(id), hits: [id], sourceGroup: nil, displayAnchor: id, context: []))
            }
        }
        return .init(source: source, units: units, diagnostics: issues,
                     visibility: visibility ?? .all(units))
    }

    private static func validated(_ groups: [TrashQueryGroup], known: Set<CommandObjectReference>,
                                  matches: [CommandObjectReference: [ContentQueryBatchMatch]],
                                  issues: inout [ContentQueryDisplayIssue]) -> [TrashQueryGroup] {
        let ids = Dictionary(grouping: groups, by: { $0.source.id })
        let claims = Dictionary(grouping: groups.flatMap { group in
            ([group.source.id] + group.source.members).map { ($0, group.source.id) }
        }, by: { $0.0 })
        return groups.filter { group in
            let members = [group.source.id] + group.source.members
            guard ids[group.source.id]?.count == 1,
                  members.allSatisfy({ claims[$0]?.count == 1 }) else {
                issues.append(.conflictingGroup(group.source.id)); return false
            }
            let contexts = group.context.map(\.id)
            let provided = Set(group.matches + contexts)
            for missing in members where !provided.contains(missing) {
                issues.append(.missingGroupReference(group: group.source.id, object: missing))
            }
            for missing in group.matches where !known.contains(missing) {
                issues.append(.missingGroupReference(group: group.source.id, object: missing))
            }
            guard !group.matches.isEmpty, Set(group.matches).count == group.matches.count,
                  Set(contexts).count == contexts.count, Set(group.matches).isSubset(of: known),
                  Set(group.matches).isSubset(of: Set(members)),
                  Set(contexts).isSubset(of: Set(members)), Set(contexts).isDisjoint(with: known),
                  group.matches.contains(group.displayAnchor),
                  Set(group.matches + contexts) == Set(members),
                  group.matches.allSatisfy({ id in
                      guard let value = matches[id]?.first, case .trash(let match) = value else { return false }
                      return validRelation(match.object, group: group.source.id)
                  }), group.context.allSatisfy({ validRelation($0, group: group.source.id) }) else {
                issues.append(.invalidGroup(group.source.id)); return false
            }
            return true
        }
    }

    private static func validRelation(_ value: TrashTombstone, group: CommandObjectReference) -> Bool {
        if value.id == group { return true }
        if case .cascaded(let parent) = value.relation { return parent == group }
        return false
    }
}
