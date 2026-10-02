import Foundation

/// 只读公开图片子集，不读取文件或原始附件数组中的文件名，不接其他提供者的 has:image。
enum ImageQueryProvider {
    static func read(_ request: ImageQueryRequest) -> ImageQueryResponse {
        let session = request.session
        let composition = session.composition
        let applicable = composition?.types.contains(.image) == true && composition?.deletion == .liveOnly
        let valid = session.isStructurallyValid
        var response = ImageQueryResponse(
            requestID: request.requestID, queryIsValid: valid, typeAnalysis: session.typeAnalysis,
            state: valid ? (applicable ? .evaluated : .notApplicable) : .invalidQuery,
            coverage: .init(requestedTypes: composition?.types ?? [], coveredTypes: applicable ? [.image] : [],
                            deletion: composition?.deletion),
            textDiagnostics: session.textDiagnostics, conditionDiagnostics: session.conditionDiagnostics)
        guard valid else { response.diagnostics = [.init(issue: .invalidQuery)]; return response }
        guard applicable else { return response }
        if let restriction = response.typeAnalysis.assessment(for: .image)?.readRestriction {
            response.state = restriction
            return response
        }
        guard ContentQuerySnapshotValidation.validDay(session.queryDates.todayKey, dates: session.queryDates) else {
            response.state = .blocked
            response.diagnostics = [.init(issue: .invalidDateContext)]
            return response
        }
        let association = ImageAssociationReader.read(request.association)
        response.associationDiagnostics = association.diagnostics
        response.associations = association.associations
        response.coverage.containsProtectedContent = association.associations.values.contains { $0.browse == .protected }
        response.coverage.associations = completeness(association, input: request.association)
        response.diagnostics = capabilities(session)
        for image in association.images {
            let owner = association.owners[image.owner]
            let matcher = ImageQueryMatching(request: request, image: image, owner: owner)
            let result = matcher.evaluate(assessment: response.typeAnalysis.assessment(for: .image))
            response.diagnostics += result.diagnostics.map {
                var diagnostic = $0
                diagnostic.object = image.id
                diagnostic.owner = image.owner
                return diagnostic
            }
            switch result.truth {
            case .matches:
                response.owners[image.owner] = owner
                response.matches.append(.init(image: image, evidence: result.evidence, businessDay: matcher.businessDay,
                                              dateExistence: matcher.temporal.existence, occurrence: matcher.temporal.occurrence))
            case .unknown, .invalidInput:
                response.owners[image.owner] = owner
                response.undeterminedObjects.append(image.id)
            case .doesNotMatch: break
            }
        }
        return response
    }

    private static func completeness(
        _ response: ImageAssociationResponse, input: ImageAssociationRequest
    ) -> ImageQueryAssociationCompleteness {
        // 属性未知独立于关联完整性；墓碑的确定排除也不是丢失数据。
        // 未知类型可能没有可公开的记录级状态；只校验输入类型覆盖，不发布该行的身份、数量或保护细节。
        guard let images = input.images, images.allSatisfy({ $0.ownerKey != nil }) else { return .incomplete }
        let nonBlocking: [ImageAssociationIssue] = [.deletedImage, .deletedOwner, .invalidOwnerAttributes]
        let incomplete = response.diagnostics.contains { !nonBlocking.contains($0.issue) }
        return incomplete ? .incomplete : .completeForDeclaredInput
    }

    private static func capabilities(_ session: ContentQuerySession) -> [ImageQueryDiagnostic] {
        session.conditions.compactMap { condition in
            let issue: ImageQueryIssue
            switch condition.value {
            case .page(.sourceApplication): issue = .ownerSourceUnavailable
            case .page(.boardDate): issue = .unsupportedOwnerPageDate
            default: return nil
            }
            return .init(issue: issue, affectsDetermination: false, conditionIDs: [condition.id])
        }
    }
}
