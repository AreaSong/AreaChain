import Foundation
import SwiftData

/// 只组合已经校验的两个仓储；所有 throwing 应用都处于同一次 ModelChanges 中。
@MainActor enum BatchCommandTransaction {
    final class Result {
        var facts: CommandBatchFacts
        var transaction: ModelChanges.CommitFacts?
        init(_ accepted: CommandBatchAcceptance) { facts = .init(accepted) }
    }

    static func apply(_ accepted: CommandBatchAcceptance, environment: BatchCommandEnvironment,
                      register: @escaping (CommandBatchFacts) throws -> Void) -> CommandBatchFacts {
        let result = Result(accepted)
        var boundary = environment.dependencies.transaction
        boundary.publish = { try environment.publish(result) }
        do {
            try ModelChanges.transaction(in: environment.context, boundary: boundary,
                                         observe: { result.transaction = $0 }) {
                for impact in accepted.preview.impacts where !impact.noChange {
                    try apply(impact, edit: accepted.preview.edit, dependencies: environment.dependencies)
                    try environment.dependencies.afterApply(impact.target)
                }
                ModelChanges.afterCommit(in: environment.context) {
                    result.facts.state = .saved
                    result.facts.save = .returned
                    do {
                        try register(result.facts)
                        try environment.dependencies.registerLocalModification()
                    } catch {
                        result.facts.registrationFailed = true
                        boundary.reportFailure(error)
                    }
                }
            }
        } catch {
            result.facts.state = result.transaction?.save == .called || result.transaction?.phase == .recoveryFailed
                ? .unknown : .notSubmitted
            boundary.reportFailure(error)
        }
        result.facts.save = call(result.transaction?.save)
        result.facts.rollback = call(result.transaction?.rollback)
        result.facts.publication = call(result.transaction?.publication)
        result.facts.publicationFailed = result.transaction?.publicationFailed == true
        return result.facts
    }

    private static func apply(_ impact: CommandBatchTargetImpact, edit: CommandBatchEdit,
                              dependencies: BatchCommandEnvironment.Dependencies) throws {
        switch edit {
        case .move(let day): try dependencies.tasks.moveTodo(id: impact.target.id, to: day)
        case .tags:
            guard let encoded = impact.tags?.finalEncodedIDs else { throw CommandBatchIssue.stale }
            if impact.target.type == .todo { try dependencies.tasks.replaceTagIDs(id: impact.target.id, tagIDs: encoded) }
            else { try dependencies.routines.replaceTagIDs(id: impact.target.id, tagIDs: encoded) }
        }
    }

    private static func call(_ value: ModelChanges.CallFact?) -> CommandTaskTitleFacts.Call {
        switch value {
        case .called: return .called
        case .returned: return .returned
        default: return .notCalled
        }
    }
}
