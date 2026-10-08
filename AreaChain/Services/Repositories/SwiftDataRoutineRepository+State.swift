import Foundation
import SwiftData

extension SwiftDataRoutineRepository {
    /// 单项保留自己的合法接受；与批量仅共用精确物理应用，不伪造单项调用身份。
    func applyRoutineState(_ accepted: CommandRoutineAcceptance) throws {
        guard let context = routineMutationContext, ModelChanges.hasActiveTransaction(in: context),
              let impact = accepted.preview.stateImpact else { throw RoutineCommandIssue.invalidRepository }
        let input = RoutineStateApplication.Input(target: accepted.object, record: accepted.preview.record,
            impact: impact, creationIDs: accepted.checkCreationIDs)
        let applications = try RoutineStateApplication.prepare([input], in: context)
        for application in applications { try application.apply(in: context) }
        try ModelChanges.commit(context)
    }
}
