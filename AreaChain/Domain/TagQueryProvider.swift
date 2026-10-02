import Foundation

/// 仅返回活标签自身；完整 Session 是条件的唯一真值，视图选项不改写查询。
enum TagQueryProvider {
    static func read(_ request: TagQueryRequest) -> TagQueryResponse {
        let session = request.session
        let composition = session.composition
        let applicable = composition?.types.contains(.tag) == true && composition?.deletion == .liveOnly
        let valid = session.isStructurallyValid
        var response = TagQueryResponse(
            requestID: request.requestID, queryIsValid: valid, typeAnalysis: session.typeAnalysis,
            state: valid ? (applicable ? .evaluated : .notApplicable) : .invalidQuery,
            coverage: .init(requestedTypes: composition?.types ?? [], coveredTypes: applicable ? [.tag] : [],
                            deletion: composition?.deletion, usage: request.usage?.coverage),
            textDiagnostics: session.textDiagnostics, conditionDiagnostics: session.conditionDiagnostics,
            view: request.view, ordering: .init(view: request.view))
        guard valid else { response.diagnostics = [.init(issue: .invalidQuery)]; return response }
        guard applicable else { return response }
        if let restriction = response.typeAnalysis.assessment(for: .tag)?.readRestriction {
            response.state = restriction
            return response
        }
        let unsupported = session.conditions.filter { !supports($0.value) }
        guard unsupported.isEmpty else {
            response.state = .blocked
            response.diagnostics = [.init(issue: .unsupportedCondition, conditionIDs: unsupported.map(\.id))]
            return response
        }
        evaluate(request, response: &response)
        applyView(request.view, response: &response)
        return response
    }

    private static func supports(_ value: ContentQueryConditionValue) -> Bool {
        switch value {
        case .scope, .page(.contentTypes): true
        case .clause(let terms): terms.allSatisfy { $0.atom.dimension == .text }
        default: false
        }
    }

    private static func evaluate(_ request: TagQueryRequest, response: inout TagQueryResponse) {
        let positions = Dictionary(grouping: request.tags.indices, by: { request.tags[$0].id })
        let usage = TagQueryUsageReader(input: request.usage, dates: request.session.queryDates)
        if request.view.needsUsage && request.usage == nil {
            response.diagnostics.append(.init(issue: .usageUnavailable, severity: .warning, affectsDetermination: false))
        }
        for (index, tag) in request.tags.enumerated() {
            let object = CommandObjectReference(type: .tag, id: tag.id)
            let indices = positions[tag.id] ?? []
            if indices.count > 1 {
                if indices.first == index {
                    response.diagnostics.append(.init(issue: .duplicateTagID, object: object, inputIndices: indices))
                    response.undeterminedObjects.append(object)
                }
                continue
            }
            guard tag.deletedAt == nil else { continue }
            let evidence = match(tag, conditions: request.session.conditions)
            let reading = usage.read(tag.id)
            let diagnostics = evidence != nil || reading.state == .invalid ? reading.diagnostics : []
            response.diagnostics += diagnostics.map {
                var diagnostic = $0
                diagnostic.object = object
                diagnostic.inputIndices = [index]
                diagnostic.affectsDetermination = request.view.needsUsage && evidence != nil
                if reading.state != .invalid { diagnostic.severity = .warning }
                return diagnostic
            }
            guard let evidence else { continue }
            response.matches.append(.init(tag: tag, evidence: evidence, usage: reading.record, usageState: reading.state))
        }
    }

    private static func match(
        _ tag: TagQuerySnapshot, conditions: [ContentQueryCondition]
    ) -> [ContentQueryMatchEvidence]? {
        var evidence: [ContentQueryMatchEvidence] = []
        for condition in conditions {
            switch condition.value {
            case .scope: evidence.append(.init(conditionID: condition.id, field: .scope))
            case .page(.contentTypes): evidence.append(.init(conditionID: condition.id, field: .objectType))
            case .clause(let terms):
                let alternatives = terms.enumerated().compactMap { index, term -> [ContentQueryMatchEvidence]? in
                    guard case .text(let text, _) = term.atom,
                          let found = ContentQuerySnapshotMatching.text(text, excluded: term.excluded,
                              fields: [(.tagName, tag.name)], id: condition.id) else { return nil }
                    return found.map { item in
                        var item = item
                        item.alternativeIndex = index
                        return item
                    }
                }
                guard !alternatives.isEmpty else { return nil }
                evidence += alternatives.flatMap { $0 }
            default: return nil
            }
        }
        return evidence
    }

    private static func applyView(_ view: TagQueryView, response: inout TagQueryResponse) {
        guard case .catalog(let filter) = view else { return }
        let unknown = response.matches.filter { $0.usageState != .complete }
        if view.needsUsage && !unknown.isEmpty {
            response.ordering.isComplete = false
            if filter == .frequent {
                // frequent 不筛掉零使用项；无法可靠排序时保留所有名称命中与输入顺序。
                response.ordering.applied = .inputOrder
                return
            }
            response.undeterminedObjects += unknown.map(\.id)
            response.matches.removeAll { $0.usageState != .complete }
        }
        let records = Dictionary(uniqueKeysWithValues: response.matches.compactMap { match in
            match.usage.map { (match.tag.id, $0) }
        })
        response.matches = TagUsage.filteredValues(response.matches, filter: filter, usage: records) { $0.tag.listFacts }
    }
}
