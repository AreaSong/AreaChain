import Foundation

/// newName 没有业务 UUID；只有未来事务实际创建并保存后才可输出标签身份。
enum CommandTaskTagTarget: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    case existing(CommandTaskTagRecord)
    case newName(String, normalized: String)
    var description: String { "CommandTaskTagTarget(redacted)" }
    var debugDescription: String { description }
}

struct CommandTaskTagAssociation: Equatable {
    enum Effect { case associateLive, restoreAndAssociate, createAndAssociate }
    enum Origin { case titleSyntax, explicitIDs }
    let target: CommandTaskTagTarget
    let effect: Effect
    let origins: [Origin]
}

struct CommandTaskTagPlan: Equatable {
    enum NoEffect: Equatable {
        case alreadyAssociated(CommandTaskTagTarget), notAssociated(CommandTaskTagTarget), empty
    }
    let final: [CommandTaskTagAssociation]
    let removed: [CommandTaskTagTarget]
    let noEffects: [NoEffect]
    let problems: [CommandTaskTagProblem]
}

enum CommandTaskTagPlanning {
    static func compose(title: String, argument: CommandArgument?, catalog: CommandTaskTagCatalog) -> CommandTaskTagPlan {
        let lookup = CommandTaskTagLookup(catalog)
        var problems = lookup.catalogProblems
        guard problems.isEmpty else { return .init(final: [], removed: [], noEffects: [], problems: problems) }
        // 包括 parser 有意不消费的预设。资格先于 clear/replaceAll，不能通过删候选降级保护来源。
        let syntax = resolve(TagSyntax.names(in: title).map(CommandTaskTagSelection.name), lookup: lookup, problems: &problems)
        let ids: [UUID]
        if case .tags(let values) = argument?.value { ids = TagIDList.normalized(values) } else { ids = [] }
        let explicit = resolve(ids.map(CommandTaskTagSelection.id), lookup: lookup, problems: &problems)
        var state = Composition(syntax: syntax)
        state.apply(argument?.operation ?? .unspecified, explicit: explicit)
        return .init(final: state.final, removed: state.removed, noEffects: state.noEffects, problems: problems)
    }

    private static func resolve(_ selections: [CommandTaskTagSelection], lookup: CommandTaskTagLookup,
                                problems: inout [CommandTaskTagProblem]) -> [CommandTaskTagTarget] {
        selections.compactMap { selection in
            switch lookup.resolve(selection) {
            case .success(let target): return target
            case .failure(let error):
                problems.append(.init(selection: selection, kind: error.kind))
                return nil
            }
        }
    }

    private struct Composition {
        var final: [CommandTaskTagAssociation]
        var removed: [CommandTaskTagTarget] = []
        var noEffects: [CommandTaskTagPlan.NoEffect] = []

        init(syntax: [CommandTaskTagTarget]) { final = syntax.map { Self.association($0, origins: [.titleSyntax]) } }

        mutating func apply(_ operation: CommandFieldOperation, explicit: [CommandTaskTagTarget]) {
            switch operation {
            case .add: add(explicit)
            case .remove:
                for target in explicit {
                    if final.contains(where: { $0.target == target }) { removed.append(target) }
                    else { noEffects.append(.notAssociated(target)) }
                }
                final.removeAll { explicit.contains($0.target) }
            case .replaceAll:
                removed = final.map(\.target).filter { !explicit.contains($0) }
                let previous = final
                final = explicit.map { target in
                    let origins = previous.first(where: { $0.target == target })?.origins ?? []
                    return Self.association(target, origins: origins + [.explicitIDs])
                }
                if removed.isEmpty && previous.map(\.target) == final.map(\.target) { noEffects.append(.empty) }
            case .clear:
                removed = final.map(\.target)
                final = []
                if removed.isEmpty { noEffects.append(.empty) }
            default: break
            }
        }

        private mutating func add(_ targets: [CommandTaskTagTarget]) {
            for target in targets {
                if let index = final.firstIndex(where: { $0.target == target }) {
                    noEffects.append(.alreadyAssociated(target))
                    final[index] = Self.association(target, origins: final[index].origins + [.explicitIDs])
                } else { final.append(Self.association(target, origins: [.explicitIDs])) }
            }
        }

        private static func association(_ target: CommandTaskTagTarget,
                                        origins: [CommandTaskTagAssociation.Origin]) -> CommandTaskTagAssociation {
            switch target {
            case .newName: return .init(target: target, effect: .createAndAssociate, origins: origins)
            case .existing(let row):
                return .init(target: target, effect: row.state == .live ? .associateLive : .restoreAndAssociate, origins: origins)
            }
        }
    }
}
