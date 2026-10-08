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
            try accepted.preview.writeSet?.validateLimit()
            let stateApplications = try prepareStates(accepted, context: environment.context)
            try ModelChanges.transaction(in: environment.context, boundary: boundary,
                                         observe: { result.transaction = $0 }) {
                for impact in accepted.preview.impacts where !impact.noChange {
                    if let application = stateApplications[impact.target] { try application.apply(in: environment.context) }
                    else { try apply(impact, edit: accepted.preview.edit, dependencies: environment.dependencies) }
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

    private static func prepareStates(_ accepted: CommandBatchAcceptance,
                                      context: ModelContext) throws -> [CommandObjectReference: RoutineStateApplication] {
        let impacts = accepted.preview.impacts.filter { $0.state != nil && !$0.noChange }
        guard !impacts.isEmpty else { return [:] }
        let inputs = try impacts.map { impact -> RoutineStateApplication.Input in
            guard let state = impact.state else { throw CommandBatchIssue.stale }
            let ids = try Dictionary(uniqueKeysWithValues: state.effects.filter { $0.action == .insert }.map { effect in
                let key = CommandObjectReference(type: .routineOccurrence, id: impact.target.id, dayKey: effect.day)
                guard let id = accepted.checkCreationIDs[key] else { throw CommandBatchIssue.stale }
                return (effect.day, id)
            })
            return .init(target: impact.target, record: impact.record, impact: state, creationIDs: ids)
        }
        let applications = try RoutineStateApplication.prepare(inputs, in: context)
        return Dictionary(uniqueKeysWithValues: zip(impacts.map(\.target), applications))
    }

    private static func apply(_ impact: CommandBatchTargetImpact, edit: CommandBatchEdit,
                              dependencies: BatchCommandEnvironment.Dependencies) throws {
        switch edit {
        case .move(let day): try dependencies.tasks.moveTodo(id: impact.target.id, to: day)
        case .tags:
            guard let encoded = impact.tags?.finalEncodedIDs else { throw CommandBatchIssue.stale }
            if impact.target.type == .todo { try dependencies.tasks.replaceTagIDs(id: impact.target.id, tagIDs: encoded) }
            else { try dependencies.routines.replaceTagIDs(id: impact.target.id, tagIDs: encoded) }
        case .completion(let done):
            guard impact.target.type == .todo, let completion = impact.completion,
                  completion.original != completion.final else { throw CommandBatchIssue.stale }
            if done { try dependencies.tasks.completeTodo(id: impact.target.id) }
            else { try dependencies.tasks.toggleTodo(id: impact.target.id) }
        case .enabled: throw CommandBatchIssue.stale
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
