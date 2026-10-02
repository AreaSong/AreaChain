import Foundation

/// 显式范围内求值调用方提供的记录；没有 Session/Store、系统剪贴板或执行能力。
enum ClipboardQueryProvider {
    static func read(_ request: ClipboardQueryRequest) -> ClipboardQueryResponse {
        let session = request.input.session
        let applicable = session.scope == .catalog(.clipboard)
            && session.composition?.types == [.clipboardEntry] && session.composition?.deletion == .liveOnly
        let valid = session.isStructurallyValid
        var response = ClipboardQueryResponse(
            requestID: request.requestID, mode: request.input.mode, queryIsValid: valid, typeAnalysis: session.typeAnalysis,
            state: valid ? (applicable ? .evaluated : .notApplicable) : .invalidQuery,
            coverage: .init(requestedTypes: session.composition?.types ?? [],
                            coveredTypes: applicable ? [.clipboardEntry] : [], records: request.records.coverage),
            textDiagnostics: session.textDiagnostics, conditionDiagnostics: session.conditionDiagnostics)
        guard valid else { response.diagnostics = [.init(issue: .invalidQuery)]; return response }
        guard applicable else { return response }
        guard ContentQuerySnapshotValidation.validDay(session.queryDates.todayKey, dates: session.queryDates) else {
            response.state = .blocked
            response.diagnostics = [.init(issue: .invalidDateContext)]
            return response
        }
        let matching = matcher(request.input)
        if matching?.isValid == false {
            response.queryIsValid = false
            response.state = .invalidQuery
            response.diagnostics = [.init(issue: .invalidRegex)]
            return response
        }
        if let restriction = response.typeAnalysis.assessment(for: .clipboardEntry)?.readRestriction {
            response.state = restriction
            return response
        }
        let unsupported = session.conditions.filter { !ClipboardQueryMatching.supports($0.value) }
        guard unsupported.isEmpty else {
            response.state = .blocked
            response.diagnostics = [.init(issue: .unsupportedCondition, conditionIDs: unsupported.map(\.id))]
            return response
        }
        guard checkCoverage(&response) else { return response }
        evaluate(request, matching: matching, response: &response)
        response.ordering.isComplete = response.coverage.records == .complete && response.undeterminedObjects.isEmpty
        return response
    }

    private static func matcher(_ input: ClipboardQueryInput) -> ClipboardTextMatching? {
        guard case .explicit(let mode) = input else { return nil }
        return .init(needle: mode.needle, mode: mode.mode)
    }

    private static func checkCoverage(_ response: inout ClipboardQueryResponse) -> Bool {
        switch response.coverage.records {
        case .complete: return true
        case .partial:
            response.diagnostics.append(.init(issue: .recordsPartial, severity: .warning))
            return true
        case .notProvided: response.diagnostics.append(.init(issue: .recordsNotProvided))
        case .failed: response.diagnostics.append(.init(issue: .recordsReadFailed))
        }
        response.state = .blocked
        return false
    }

    private static func evaluate(
        _ request: ClipboardQueryRequest, matching: ClipboardTextMatching?, response: inout ClipboardQueryResponse
    ) {
        response.coverage.didEvaluateRecords = true
        let records = request.records.records
        let positions = Dictionary(grouping: records.indices, by: { records[$0].id })
        for (index, record) in records.enumerated() {
            let object = CommandObjectReference(type: .clipboardEntry, id: record.id)
            let indices = positions[record.id] ?? []
            if indices.count > 1 {
                if indices.first == index {
                    response.diagnostics.append(.init(issue: .duplicateRecordID, object: object, inputIndices: indices))
                    response.undeterminedObjects.append(object)
                }
                continue
            }
            if let issue = invalidDate(record, dates: request.input.session.queryDates) {
                response.diagnostics.append(.init(issue: issue, object: object, inputIndices: [index]))
                response.undeterminedObjects.append(object)
                continue
            }
            evaluate(record, index: index, request: request, matching: matching, response: &response)
        }
    }

    private static func invalidDate(_ record: ClipboardHistoryRecord, dates: ContentQueryDateContext) -> ClipboardQueryIssue? {
        if !ContentQuerySnapshotValidation.validTimestamp(record.copiedAt, dates: dates) { return .invalidCopiedAt }
        if let pinned = record.pinnedAt, !ContentQuerySnapshotValidation.validTimestamp(pinned, dates: dates) { return .invalidPinnedAt }
        return nil
    }

    private static func evaluate(
        _ record: ClipboardHistoryRecord, index: Int, request: ClipboardQueryRequest,
        matching: ClipboardTextMatching?, response: inout ClipboardQueryResponse
    ) {
        let object = CommandObjectReference(type: .clipboardEntry, id: record.id)
        let payload = ClipboardQueryPayload(record)
        let ranges = matching?.matchRanges(in: record.plainText)
        let evaluation: ClipboardQueryEvaluation = matching != nil && ranges == nil ? .noMatch
            : ClipboardQueryMatching.evaluate(record, payload: payload, session: request.input.session)
        if payload.image == .invalidReference {
            let unknown: Bool = if case .unknown = evaluation { true } else { false }
            response.diagnostics.append(.init(issue: .invalidImageReference, severity: unknown ? .error : .warning,
                affectsDetermination: unknown, conditionIDs: request.input.session.conditions.filter {
                    $0.value.dimension == .content(.image)
                }.map(\.id), object: object, inputIndices: [index]))
        }
        switch evaluation {
        case .noMatch: return
        case .unknown: response.undeterminedObjects.append(object)
        case .match(let evidence):
            let modeEvidence: ClipboardQueryModeEvidence?
            if case .explicit(let mode) = request.input {
                modeEvidence = .init(mode: mode.mode, ranges: (ranges ?? []).map { NSRange($0, in: record.plainText) })
            } else { modeEvidence = nil }
            response.matches.append(.init(id: object, plainText: record.plainText, copiedAt: record.copiedAt,
                pinnedAt: record.pinnedAt, pinKey: record.pinKey, sourceBundleID: record.sourceBundleID, payload: payload,
                mode: request.input.mode, evidence: evidence, modeEvidence: modeEvidence))
        }
    }
}
