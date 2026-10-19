import Foundation
import SwiftData

/// 一次 ModelChanges 事务只调一次指令的仓储写入；保存前再读，实际结果必须等于预览，否则整体回滚。
/// 只有保存成功才登记事实并发布；失败不虚报，结果未知如实记为 unknown。
@MainActor enum SimpleCommandTransaction {
    final class Result {
        var facts: CommandSimpleFacts
        var transaction: ModelChanges.CommitFacts?
        init(_ facts: CommandSimpleFacts) { self.facts = facts }
    }

    static func apply(_ accepted: CommandSimpleAcceptance, spec: any SimpleCommandSpec,
                      environment: SimpleCommandEnvironment,
                      register: @escaping (CommandSimpleFacts) throws -> Void) -> CommandSimpleFacts {
        let result = Result(.init(accepted))
        let preview = accepted.preview
        let context = environment.context
        var boundary = environment.dependencies.transaction
        boundary.publish = { try environment.publish() }
        do {
            try ModelChanges.transaction(in: context, boundary: boundary, observe: { result.transaction = $0 }) {
                try spec.apply(preview.frozenCall, in: context)
                guard try spec.observe(preview.frozenCall, in: context) == preview.after else {
                    throw CommandSimpleIssue.invalidTarget(.changed)
                }
                ModelChanges.afterCommit(in: context) {
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

    private static func call(_ value: ModelChanges.CallFact?) -> CommandTaskTitleFacts.Call {
        switch value {
        case .called: return .called
        case .returned: return .returned
        default: return .notCalled
        }
    }
}
