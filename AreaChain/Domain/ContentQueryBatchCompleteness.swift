import Foundation

/// 原因只索引同一 provider reading；具体诊断/条件/身份仍在该分型响应内，不合并不同对象的错误。
enum ContentQueryBatchLimitation: Equatable {
    case source(CommandObjectType, ContentQuerySourceCoverage)
    case restriction(ContentQueryTypeAssessment)
    case providerState(TodoQueryReadState)
    case undeterminedObjects([CommandObjectReference])
    case determiningDiagnostics
    case associationCoverage(ImageQueryAssociationCompleteness)
    case trashCoverage
    case nonPublicCoverage
    case historyCoverage, recordCoverage, enumerationRemainder, reviewRecords
    case checkSource(RoutineCheckSourceProblem)
    case taskInputConsistency
    case clipboardMode(ClipboardQueryRequestError)
    case conflictingResultIdentity(CommandObjectReference)
}

enum ContentQueryBatchHint: Equatable {
    case providerDiagnostics
    case nonPublicPresentation
    case nonPublicCoverage
    case tagOrdering(TagQueryOrdering)
    case clipboardOrdering(ClipboardQueryOrdering)
}

struct ContentQueryProviderCompleteness: Equatable {
    let provider: ContentQueryProviderID
    let requestedTypes: Set<CommandObjectType>
    var evaluatedTypes: Set<CommandObjectType> = []
    var limitations: [ContentQueryBatchLimitation] = []
    var hints: [ContentQueryBatchHint] = []

    var matchingIsComplete: Bool { limitations.isEmpty }
}

struct ContentQueryBatchCompleteness: Equatable {
    let queryState: ContentQueryBatchQueryState
    let requestedTypes: Set<CommandObjectType>
    let possibleTypes: Set<CommandObjectType>
    let providers: [ContentQueryProviderCompleteness]
    var evaluatedTypes: Set<CommandObjectType> { providers.reduce(into: []) { $0.formUnion($1.evaluatedTypes) } }
    var matchingIsComplete: Bool {
        queryState == .content && !requestedTypes.isEmpty && providers.allSatisfy(\.matchingIsComplete)
            && requestedTypes.isSubset(of: providers.reduce(into: []) { $0.formUnion($1.requestedTypes) })
    }
}

extension ContentQueryProviderRead {
    /// 不调用各响应的 isComplete Bool；匹配、枚举、保护、历史与排序按各自契约拆开。
    func summarize(into summary: inout ContentQueryProviderCompleteness) {
        guard state == .evaluated else {
            summary.limitations.append(.providerState(state)); return
        }
        summary.evaluatedTypes = summary.requestedTypes
        switch self {
        case .todo(let value):
            appendObjects(value.undeterminedObjects, to: &summary)
            appendDiagnostics(value.diagnostics.map(\.affectsDetermination), to: &summary)
            appendProtection(value.diagnostics.filter { $0.issue == .imageAssociation(.protectedAssociation) }
                .map(\.affectsDetermination), to: &summary)
        case .subtask(let value):
            appendDiagnostics(value.diagnostics.map { _ in true }, to: &summary)
        case .routine(let value):
            appendObjects(value.undeterminedObjects, to: &summary)
            appendDiagnostics(value.diagnostics.map(\.affectsDetermination), to: &summary)
            appendProtection(value.diagnostics.filter { $0.issue == .imageAssociation(.protectedAssociation) }
                .map(\.affectsDetermination), to: &summary)
        case .diary(let value):
            appendObjects(value.undeterminedObjects, to: &summary)
            appendDiagnostics(value.diagnostics.map(\.affectsDetermination), to: &summary)
            appendProtection(value.diagnostics.filter { $0.issue == .imageAssociation(.protectedAssociation) }
                .map(\.affectsDetermination), to: &summary)
            if value.matches.contains(where: { if case .hiddenTitle = $0.presentation { return true }; return false }) {
                summary.hints.append(.nonPublicPresentation)
            }
        case .image(let value):
            appendObjects(value.undeterminedObjects, to: &summary)
            appendDiagnostics(value.diagnostics.map(\.affectsDetermination), to: &summary)
            if value.coverage.associations != .completeForDeclaredInput {
                summary.limitations.append(.associationCoverage(value.coverage.associations))
            }
            if value.coverage.containsProtectedContent { summary.limitations.append(.nonPublicCoverage) }
        case .tag(let value):
            appendObjects(value.undeterminedObjects, to: &summary)
            appendDiagnostics(value.diagnostics.map { diagnostic in
                let orderingOnly = value.view == .catalog(.frequent) && diagnostic.issue.isUsageIssue
                return diagnostic.affectsDetermination && !orderingOnly
            }, to: &summary)
            // frequent 的回退只影响顺序；recent/unused 成员未知由原 undeterminedObjects 表达。
            if !value.ordering.isComplete { summary.hints.append(.tagOrdering(value.ordering)) }
        case .clipboard(let value):
            appendObjects(value.undeterminedObjects, to: &summary)
            appendDiagnostics(value.diagnostics.map(\.affectsDetermination), to: &summary)
            if !value.coverage.didEvaluateRecords { summary.evaluatedTypes = [] }
            if !value.ordering.isComplete { summary.hints.append(.clipboardOrdering(value.ordering)) }
        case .trash(let value): summarizeTrash(value, into: &summary)
        case .routineOccurrence(let value): summarizeOccurrences(value, into: &summary)
        }
    }

    private func summarizeTrash(_ value: TrashQueryResponse, into summary: inout ContentQueryProviderCompleteness) {
        summary.evaluatedTypes.subtract(value.restrictedTypes.keys)
        if value.hasIncompleteInput { summary.limitations.append(.trashCoverage) }
        appendObjects(value.undeterminedObjects, to: &summary)
        appendDiagnostics(value.diagnostics.map(\.affectsDetermination), to: &summary)
        // 这是提供者固定的公开展示限制，不能根据隐藏图片的数量或有无改写。
        if value.imageDisplayLimited { summary.limitations.append(.nonPublicCoverage) }
    }

    private func summarizeOccurrences(_ value: RoutineOccurrenceQueryResponse, into summary: inout ContentQueryProviderCompleteness) {
        appendDiagnostics(value.diagnostics.map(\.affectsDetermination), to: &summary)
        if !value.coverage.didEnumerate { summary.evaluatedTypes = [] }
        if !value.coverage.historyIsComplete { summary.limitations.append(.historyCoverage) }
        if !value.coverage.recordsAreComplete { summary.limitations.append(.recordCoverage) }
        if !value.coverage.enumerationIsComplete { summary.limitations.append(.enumerationRemainder) }
        if !value.reviewRecords.isEmpty { summary.limitations.append(.reviewRecords) }
    }

    private func appendObjects(_ objects: [CommandObjectReference], to summary: inout ContentQueryProviderCompleteness) {
        if !objects.isEmpty { summary.limitations.append(.undeterminedObjects(objects)) }
    }

    private func appendProtection(_ affects: [Bool], to summary: inout ContentQueryProviderCompleteness) {
        if affects.contains(true) { summary.limitations.append(.nonPublicCoverage) }
        else if !affects.isEmpty { summary.hints.append(.nonPublicCoverage) }
    }

    private func appendDiagnostics(_ affects: [Bool], to summary: inout ContentQueryProviderCompleteness) {
        if affects.contains(true) { summary.limitations.append(.determiningDiagnostics) }
        if affects.contains(false) { summary.hints.append(.providerDiagnostics) }
    }
}

private extension TagQueryIssue {
    var isUsageIssue: Bool {
        switch self {
        case .usageUnavailable, .usageIncomplete, .duplicateUsageID, .negativeUsageCount,
             .invalidUsageTimestamp, .inconsistentUsageRecord: true
        case .invalidQuery, .duplicateTagID, .unsupportedCondition: false
        }
    }
}
