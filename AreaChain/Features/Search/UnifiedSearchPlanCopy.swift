import Foundation

enum UnifiedSearchPlanCopy {
    static func errorKey(_ error: Error) -> String {
        guard let error = error as? CommandPlanError else { return "unified.plan.stale" }
        switch error {
        case .stale, .duplicate: return "unified.plan.stale"
        case .protectedContent: return "unified.operation.protected"
        case .busy: return "unified.plan.busy"
        case .excluded: return "unified.plan.excluded"
        case .invalidInput, .incomplete: return "unified.plan.invalid"
        case .dependents: return "unified.plan.dependents"
        case .grouped: return "unified.plan.grouped"
        case .graph: return "unified.plan.graph"
        case .mergeConflict(let conflict): return mergeKey(conflict)
        }
    }

    static func mergeKey(_ conflict: CommandMergeConflict) -> String {
        switch conflict {
        case .protectedContent: "unified.operation.protected"
        case .order: "unified.plan.merge.order"
        case .differentBusinessField: "unified.plan.merge.field"
        case .targets: "unified.plan.merge.targets"
        case .baseline: "unified.plan.merge.baseline"
        case .sequentialOperation: "unified.plan.merge.sequential"
        case .dependency: "unified.plan.merge.dependency"
        case .atomicGroup: "unified.plan.grouped"
        case .invalidArguments: "unified.plan.invalid"
        }
    }

    static func dependency(_ issue: CommandDependencyIssue, item: UUID) -> String? {
        switch issue {
        case .unknown(let id, _) where id == item: return "unified.plan.reference.missing"
        case .order(let id, _) where id == item: return "unified.plan.reference.order"
        case .staleReference(let id, _) where id == item: return "unified.plan.reference.stale"
        case .invalidReference(let id, _) where id == item: return "unified.plan.reference.invalid"
        case .selfDependency(let id) where id == item: return "unified.plan.reference.invalid"
        case .cycle, .duplicateItem: return "unified.plan.graph"
        default: return nil
        }
    }
}
