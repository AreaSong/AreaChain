import Foundation

/// 与本次拥有者快照共同注入的原始关联资料，不接受另一请求的拥有者、标签表或预计算响应。
/// 完整性仍是调用方声明；requestID、重复使用这个值都不证明真实来源同代次或获得授权。
struct ContentQueryImageInput: CustomStringConvertible, CustomDebugStringConvertible {
    let images: [ImageAttachmentMetadata]?
    let coverage: ImageAssociationCoverage
    var imagePrivacy: DiaryImageProtectionFacts?

    var description: String { "ContentQueryImageInput(redacted)" }
    var debugDescription: String { description }
}

enum ContentQueryImageIssue: Equatable {
    case inputNotProvided, unknownAssociation, protectedAssociation
    case association(ImageAssociationIssue)
}

struct ContentQueryImageReason: Equatable {
    let issue: ContentQueryImageIssue
    let conditionID: ContentQueryConditionID
    let owner: AttachmentOwnerKey
    let isError: Bool
    var affectsDetermination: Bool
}

/// 只表达当前条件的存在性，不带图片明细。组合器可消解影响，但必须保留原因。
struct ContentQueryImageEvaluation {
    enum Truth { case matches, doesNotMatch, unknown }
    let truth: Truth
    let evidence: [ContentQueryMatchEvidence]
    let reasons: [ContentQueryImageReason]
}

/// 每次提供者 read 内构建一次；只在有效条件需要 has:image 时读取关联。
/// 私有 response 不可外部注入或跨请求拼接；拥有者与隐私事实由当前主请求直接传入。
struct ContentQueryImageRead: CustomStringConvertible, CustomDebugStringConvertible {
    private let response: ImageAssociationResponse?
    private let diagnostics: [AttachmentOwnerKey: [ImageAssociationDiagnostic]]

    init(conditions: [ContentQueryCondition], input: ContentQueryImageInput?,
         owners: ImageOwnerSnapshots, privacy: DiaryQueryMetadata = .init(tagNames: nil, privateTagIDs: nil)) {
        guard Self.isRequired(conditions), let input else {
            response = nil
            diagnostics = [:]
            return
        }
        let reading = ImageAssociationReader.read(.init(images: input.images, owners: owners,
                                                        privacy: privacy, coverage: input.coverage,
                                                        imagePrivacy: input.imagePrivacy))
        response = reading
        diagnostics = Dictionary(grouping: reading.diagnostics.compactMap { diagnostic in
            diagnostic.owner.map { ($0, diagnostic) }
        }, by: { $0.0 }).mapValues { $0.map { $0.1 } }
    }

    static func isRequired(_ conditions: [ContentQueryCondition]) -> Bool {
        conditions.contains { condition in
            guard case .clause(let terms) = condition.value else { return false }
            return terms.contains { $0.atom == .image }
        }
    }

    func evaluate(owner: AttachmentOwnerKey, conditionID: ContentQueryConditionID) -> ContentQueryImageEvaluation {
        let presence = response?.association(for: owner).presence ?? .unknown
        let truth: ContentQueryImageEvaluation.Truth
        switch presence {
        case .present: truth = .matches
        case .absent: truth = .doesNotMatch
        case .unknown, .protected: truth = .unknown
        }
        var issues = (diagnostics[owner] ?? []).map { ContentQueryImageIssue.association($0.issue) }
        if response == nil { issues.append(.inputNotProvided) }
        if presence == .protected { issues.append(.protectedAssociation) }
        if truth == .unknown && issues.isEmpty { issues.append(.unknownAssociation) }
        let reasons = issues.map { issue in
            ContentQueryImageReason(issue: issue, conditionID: conditionID, owner: owner,
                                    isError: Self.isError(issue), affectsDetermination: truth == .unknown)
        }
        return .init(truth: truth, evidence: truth == .matches
                     ? [.init(conditionID: conditionID, field: .imageAssociation, ownerObject: reference(owner))] : [],
                     reasons: reasons)
    }

    private static func isError(_ issue: ContentQueryImageIssue) -> Bool {
        switch issue {
        case .protectedAssociation, .association(.deletedImage): false
        default: true
        }
    }

    private func reference(_ owner: AttachmentOwnerKey) -> CommandObjectReference {
        switch owner.kind {
        case .todo: .init(type: .todo, id: owner.id)
        case .routine: .init(type: .routine, id: owner.id)
        case .diary: .init(type: .diary, id: owner.id)
        }
    }

    var description: String { "ContentQueryImageRead(redacted)" }
    var debugDescription: String { description }
}
