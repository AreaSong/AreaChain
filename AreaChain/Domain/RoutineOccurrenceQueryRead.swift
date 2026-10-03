import Foundation

/// 技术上限可由调用方调小/调大；不代表产品分页或真实数据规模预算。
struct RoutineOccurrenceQueryBudget: Equatable {
    var maxInputItems = 4_096
    var maxWork = 100_000
    var maxResults = 1_000

    var isValid: Bool { maxInputItems >= 0 && maxWork >= 0 && maxResults >= 0 }
}

enum RoutineOccurrenceDefinitionCoverage: Equatable { case complete, partial, unavailable }

struct RoutineOccurrenceQueryRequest: CustomStringConvertible, CustomDebugStringConvertible {
    let requestID: UUID
    let session: ContentQuerySession
    let routines: [RoutineSnapshot]
    let checks: [CheckSnapshot]
    let checkCoverage: [RoutineCheckCoverage]
    let scheduleEvidence: [RoutineScheduleEvidence]
    let definitionCoverage: RoutineOccurrenceDefinitionCoverage
    var browseWindow: ContentQueryDateWindow?
    var budget = RoutineOccurrenceQueryBudget()

    var description: String { "RoutineOccurrenceQueryRequest(redacted)" }
    var debugDescription: String { description }
}

enum RoutineOccurrenceQueryIssue: Equatable {
    case invalidQuery, invalidDateContext, missingWindow, inconsistentWindows, occurrenceOutsideWindow, invalidBudget
    case inputLimit, workLimit, resultLimit, duplicateRoutineID, missingRoutine, definitionsIncomplete
    case invalidCreatedDay, invalidScheduleEvidence
    case check(RoutineCheckIssue)
}

struct RoutineOccurrenceQueryDiagnostic: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let issue: RoutineOccurrenceQueryIssue
    var severity: RoutineQuerySeverity = .error
    var affectsDetermination = true
    var conditionIDs: [ContentQueryConditionID] = []
    var object: CommandObjectReference?
    var inputIndices: [Int] = []

    var description: String { "RoutineOccurrenceQueryDiagnostic(redacted)" }
    var debugDescription: String { description }
}

/// 三种来源分别保留；effective 是实际读取窗口，on 只收窄而不覆盖原窗口。
struct RoutineOccurrenceQueryWindow: Equatable {
    let date: ContentQueryDateWindow?
    let browse: ContentQueryDateWindow?
    let on: String?
    let effective: ContentQueryDateWindow
}

enum RoutineOccurrenceQuerySource: Equatable { case existingRecords, derivedUnprocessed }

struct RoutineOccurrenceQueryMatch: Equatable, Identifiable, CustomStringConvertible, CustomDebugStringConvertible {
    let id: CommandObjectReference
    let routine: CommandObjectReference
    let routineTitle: String
    let status: ContentQueryStatus
    let source: RoutineOccurrenceQuerySource
    let occurrence: RoutineOccurrenceEvaluation
    let evidence: [ContentQueryMatchEvidence]

    var hasIdenticalDuplicates: Bool { occurrence.records.diagnostics.contains(.identicalDuplicates) }
    var description: String { "RoutineOccurrenceQueryMatch(redacted)" }
    var debugDescription: String { description }
}

enum RoutineOccurrenceReviewKind: Equatable { case unknown, conflict, notScheduled, unattributed, invalidInput }

/// 待核对行不携带伪造标题；原始行位置只在同一 requestID 内有效。
struct RoutineOccurrenceQueryReview: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let id: CommandObjectReference
    let kind: RoutineOccurrenceReviewKind
    let records: RoutineCheckRead
    let schedule: RoutineScheduleDay?

    var description: String { "RoutineOccurrenceQueryReview(redacted)" }
    var debugDescription: String { description }
}

struct RoutineOccurrenceQueryGap: Equatable {
    enum Reason: Equatable {
        case schedule(RoutineScheduleReason), recordsIncomplete, invalidRecordInput, ambiguousDefinition
    }
    let routine: CommandObjectReference
    let interval: ContentQueryDateInterval
    /// 仅这些公历星期存在该缺口；不声称整个区间每天均未知。0 不会生成缺口。
    let weekdayMask: Int
    let reason: Reason
}

struct RoutineOccurrenceQueryRemainder: Equatable {
    /// nil 表示输入预检未通过，整个请求窗口尚未枚举。
    let routine: CommandObjectReference?
    let window: ContentQueryDateWindow
    let reason: RoutineOccurrenceQueryIssue
}

struct RoutineOccurrenceQueryCoverage: Equatable {
    let providerTypes: Set<CommandObjectType> = [.routineOccurrence]
    let requestedTypes: Set<CommandObjectType>
    let coveredTypes: Set<CommandObjectType>
    let deletion: ContentQueryDeletionPolicy?
    let definitions: RoutineOccurrenceDefinitionCoverage
    var window: RoutineOccurrenceQueryWindow?
    var gaps: [RoutineOccurrenceQueryGap] = []
    var unprocessed: [RoutineOccurrenceQueryRemainder] = []
    var unprocessedCheckIndices: [Int] = []
    var workUsed = 0
    var resultRowsUsed = 0
    var didEnumerate = false
    var hasUnattributedRecords = false
    var unattributedRecordsAreComplete = true

    var isPartialTypeCoverage: Bool { !requestedTypes.isSubset(of: coveredTypes) }
    var enumerationIsComplete: Bool { didEnumerate && unprocessed.isEmpty && unprocessedCheckIndices.isEmpty }
    var historyIsComplete: Bool {
        enumerationIsComplete && !hasUnattributedRecords && !gaps.contains {
            if case .schedule = $0.reason { return true }
            return $0.reason == .ambiguousDefinition
        }
    }
    var recordsAreComplete: Bool {
        enumerationIsComplete && unattributedRecordsAreComplete && !gaps.contains {
            [.recordsIncomplete, .invalidRecordInput, .ambiguousDefinition].contains($0.reason)
        }
    }
}

struct RoutineOccurrenceQueryResponse: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let requestID: UUID
    let queryIsValid: Bool
    let typeAnalysis: ContentQueryTypeAnalysis
    var state: TodoQueryReadState
    var coverage: RoutineOccurrenceQueryCoverage
    let textDiagnostics: [ContentQueryDiagnostic]
    let conditionDiagnostics: [ContentQueryConditionDiagnostic]
    var diagnostics: [RoutineOccurrenceQueryDiagnostic] = []
    var matches: [RoutineOccurrenceQueryMatch] = []
    var reviewRecords: [RoutineOccurrenceQueryReview] = []

    var isCompleteForCoveredTypes: Bool {
        state == .evaluated && coverage.definitions == .complete && coverage.enumerationIsComplete
            && coverage.gaps.isEmpty && reviewRecords.isEmpty && !diagnostics.contains { $0.affectsDetermination }
    }
    var description: String { "RoutineOccurrenceQueryResponse(redacted)" }
    var debugDescription: String { description }
}
