import Foundation

enum UnifiedSearchSubtaskCopy {
    static func error(_ error: Error) -> String {
        if let issue = error as? SubtaskCommandIssue {
            switch issue {
            case .unassembled: return "unified.subtask.unassembled"
            case .unsupportedPlan: return "unified.subtask.single"
            case .invalidArguments: return "unified.subtask.input"
            case .fieldsChanged: return "unified.subtask.fields"
            case .invalidFamily, .identityCollision: return "unified.subtask.family"
            case .sourceUnavailable: return "unified.subtask.source"
            case .protectedContent: return "unified.composition.protectedContent"
            case .stale, .alreadyInvoked: return "unified.subtask.stale"
            }
        }
        return UnifiedSearchTaskTitleCopy.error(error).replacingOccurrences(of: "unified.title.", with: "unified.subtask.")
    }

    static func result(_ facts: CommandSubtaskFacts) -> String {
        if facts.state == .saved {
            if facts.createdObject != nil { return "unified.subtask.created" }
            if let done = facts.savedCompletion { return done ? "unified.subtask.completed" : "unified.subtask.reopened" }
            return facts.savedTitle != nil ? "unified.subtask.titleSaved" : "unified.subtask.tagsSaved"
        }
        return "unified.subtask." + (facts.state == .pending ? "pendingResult" : String(describing: facts.state))
    }
}
