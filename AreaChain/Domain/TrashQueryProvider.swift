import Foundation

/// 显式 trash 才读取本次输入；匹配器只得到 Reader 的安全投影。
enum TrashQueryProvider {
    static func read(_ request: TrashQueryRequest) -> TrashQueryResponse {
        let session = request.session
        let valid = session.isStructurallyValid
            && Set(session.conditions.map(\.id)).count == session.conditions.count
        let applicable = session.scope == .catalog(.trash) && session.composition?.deletion == .deletedOnly
        var response = TrashQueryResponse(requestID: request.requestID,
            state: valid ? (applicable ? .evaluated : .notApplicable) : .invalidQuery,
            typeAnalysis: session.typeAnalysis, textDiagnostics: session.textDiagnostics,
            conditionDiagnostics: session.conditionDiagnostics)
        guard valid && applicable else { return response }
        let reading = TrashTombstoneReader.read(request.input)
        let requested = session.composition?.types ?? []
        response.typeCoverage = reading.typeCoverage.filter { requested.contains($0.key) }
        response.readingDiagnostics = reading.diagnostics.filter { $0.object.map { requested.contains($0.type) } ?? true }
        for type in requested {
            if let assessment = session.typeAnalysis.assessment(for: type), !assessment.isPossible {
                response.restrictedTypes[type] = assessment
            }
        }
        let matcher = TrashQueryMatching(session: session, tagNames: request.tagNames,
                                        tagNamesCoverage: request.tagNamesCoverage, routineInput: request.routineInput)
        for object in reading.objects where requested.contains(object.id.type) {
            guard response.restrictedTypes[object.id.type] == nil else { continue }
            let result = matcher.evaluate(object)
            response.diagnostics += result.diagnostics.map {
                var diagnostic = $0
                diagnostic.object = object.id
                return diagnostic
            }
            switch result.value.truth {
            case .matches: response.matches.append(.init(object: object, evidence: result.value.evidence))
            case .doesNotMatch: response.nonmatchingObjects.append(object.id)
            case .unknown: response.undeterminedObjects.append(object.id)
            }
        }
        let visible = Set(reading.objects.map(\.id))
        for diagnostic in response.readingDiagnostics {
            if let id = diagnostic.object, !visible.contains(id), !response.undeterminedObjects.contains(id) {
                response.undeterminedObjects.append(id)
            }
        }
        response.groups = groups(reading, matches: Set(response.matches.map(\.id)))
        return response
    }

    private static func groups(_ reading: TrashTombstoneResponse, matches: Set<CommandObjectReference>) -> [TrashQueryGroup] {
        let objects = Dictionary(uniqueKeysWithValues: reading.objects.map { ($0.id, $0) })
        return reading.groups.compactMap { group in
            let identities = [group.id] + group.members
            let hits = identities.filter(matches.contains)
            guard let first = hits.first else { return nil }
            return .init(source: group, displayAnchor: first, matches: hits,
                         context: identities.filter { !matches.contains($0) }.compactMap { objects[$0] })
        }
    }
}
