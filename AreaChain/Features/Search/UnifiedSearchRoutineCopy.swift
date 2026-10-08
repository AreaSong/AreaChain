import Foundation

enum UnifiedSearchRoutineCopy {
    static func error(_ error: Error) -> String {
        if let issue = error as? RoutineStateIssue { return "unified.routineState.error." + issue.rawValue }
        if let issue = error as? RoutineCommandIssue {
            switch issue {
            case .unassembled: return "unified.routine.unassembled"
            case .unsupportedPlan: return "unified.routine.single"
            case .invalidArguments: return "unified.routine.input"
            case .fieldsChanged: return "unified.routine.fields"
            case .invalidRepository: return "unified.routine.repository"
            case .sourceUnavailable: return "unified.routine.source"
            case .protectedContent: return "unified.composition.protectedContent"
            case .stale, .alreadyInvoked: return "unified.routine.stale"
            }
        }
        return UnifiedSearchTaskTitleCopy.error(error).replacingOccurrences(of: "unified.title.", with: "unified.routine.")
    }
    static func result(_ facts: CommandRoutineFacts) -> String {
        if facts.stateImpact != nil {
            if facts.state == .saved { return facts.object.type == .routineOccurrence
                ? "unified.routineState.occurrenceSaved" : "unified.routineState.definitionSaved" }
            if facts.state == .noChange { return "unified.routineState.noChange" }
            if facts.state == .unknown { return "unified.routineState.unknownResult" }
        }
        return "unified.routine." + (facts.state == .pending ? "pendingResult" : String(describing: facts.state))
    }
}
