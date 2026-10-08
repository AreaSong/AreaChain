import Foundation

/// 从当前关联计算集合操作；actions 仅包含显式效果，未触及的墓碑关联不会被恢复。
struct CommandTaskTagMutation: Equatable {
    let original: [CommandTaskTagTarget]
    let final: [CommandTaskTagTarget]
    let actions: CommandTaskTagPlan

    var finalEncodedIDs: String? {
        let ids = final.compactMap { target -> UUID? in
            guard case .existing(let row) = target else { return nil }
            return row.id
        }
        return ids.count == final.count ? TagIDList.encode(ids) : nil
    }

    func noChange(rawIDs: String) -> Bool {
        finalEncodedIDs == rawIDs && actions.final.allSatisfy { $0.effect == .associateLive }
    }

    static func prepare(rawIDs: String, edit: TaskFieldEdit, catalog: CommandTaskTagCatalog) throws -> Self? {
        guard case .tags = edit else {
            if case .createTag(let name) = edit {
                return try compose(rawIDs: rawIDs, selections: [.name(name)], operation: .add, catalog: catalog)
            }
            return nil
        }
        guard case .tags(let argument) = edit else { return nil }
        return try prepare(rawIDs: rawIDs, argument: argument, catalog: catalog)
    }

    static func prepare(rawIDs: String, argument: CommandArgument, catalog: CommandTaskTagCatalog) throws -> Self {
        let ids: [UUID]
        if case .tags(let values) = argument.value { ids = TagIDList.normalized(values) } else { ids = [] }
        return try compose(rawIDs: rawIDs, selections: ids.map(CommandTaskTagSelection.id),
                           operation: argument.operation, catalog: catalog)
    }

    private static func compose(rawIDs: String, selections: [CommandTaskTagSelection],
                                operation: CommandFieldOperation, catalog: CommandTaskTagCatalog) throws -> Self {
        // 先核对原关联，clear/remove 也不能绕过 D3。
        let original = try CommandTaskTitleTags.merge(rawIDs: rawIDs, title: "", catalog: catalog).original
        let lookup = CommandTaskTagLookup(catalog)
        let selected = try selections.map { selection in
            switch lookup.resolve(selection) {
            case .success(let target): return target
            case .failure(let failure):
                throw CommandTaskTitlePreviewIssue.tags([.init(selection: selection, kind: failure.kind)])
            }
        }
        var final = original
        var effects: [CommandTaskTagAssociation] = []
        var noEffects: [CommandTaskTagPlan.NoEffect] = []
        switch operation {
        case .add:
            for target in selected {
                if final.contains(target) { noEffects.append(.alreadyAssociated(target)) }
                else { final.append(target) }
            }
            effects = selected.filter { !original.contains($0) || isDeleted($0) }.map(association)
        case .remove:
            final.removeAll { selected.contains($0) }
            noEffects = selected.filter { !original.contains($0) }.map { .notAssociated($0) }
        case .replaceAll:
            final = selected
            effects = selected.filter { !original.contains($0) || isDeleted($0) }.map(association)
        case .clear: final = []
        default: throw TaskFieldCommandIssue.invalidArguments
        }
        if final == original && effects.isEmpty { noEffects.append(.empty) }
        return .init(original: original, final: final, actions: .init(final: effects,
            removed: original.filter { !final.contains($0) }, noEffects: noEffects, problems: []))
    }

    private static func isDeleted(_ target: CommandTaskTagTarget) -> Bool {
        if case .existing(let row) = target, case .deleted = row.state { return true }
        return false
    }

    private static func association(_ target: CommandTaskTagTarget) -> CommandTaskTagAssociation {
        let effect: CommandTaskTagAssociation.Effect
        switch target {
        case .newName: effect = .createAndAssociate
        case .existing: effect = isDeleted(target) ? .restoreAndAssociate : .associateLive
        }
        return .init(target: target, effect: effect, origins: [.explicitIDs])
    }
}
