import Foundation

/// 一次性注入读取；没有查询、文件访问、仓储或可执行句柄。只输出公开图片明细与记录级存在性。
enum ImageAssociationReader {
    static func read(_ request: ImageAssociationRequest) -> ImageAssociationResponse {
        let resolver = ImageOwnerResolver(request)
        let images = request.images ?? []
        let byOwner = Dictionary(grouping: images.compactMap { image in
            image.ownerKey.map { ($0, image) }
        }, by: { $0.0 }).mapValues { $0.map { $0.1 } }
        let byID = Dictionary(grouping: images, by: \.id)
        let unknownOwners = Set(images.filter { $0.ownerKey == nil }.map(\.ownerID))
        let keys = Set(resolver.rows.keys).union(byOwner.keys)
            .union(request.coverage.owners.objects.keys).union(request.coverage.associations.objects.keys)
        var response = ImageAssociationResponse()
        if images.contains(where: { $0.ownerKey == nil && $0.protection != .protected }) {
            response.diagnostics.append(.init(issue: .unknownOwnerKind, owner: nil))
        }
        let context = Context(request: request, resolver: resolver, byOwner: byOwner,
                              byID: byID, unknownOwners: unknownOwners)
        for key in keys.sorted(by: ownerOrder) {
            evaluate(key, context: context, response: &response)
        }
        // 只对公开图恢复输入顺序；不返回隐藏行位置或数量。
        let order = Dictionary(uniqueKeysWithValues: images.enumerated().compactMap { index, value in
            byID[value.id]?.count == 1 ? (value.id, index) : nil
        })
        response.images.sort { (order[$0.id.id] ?? 0) < (order[$1.id.id] ?? 0) }
        return response
    }

    private struct Context {
        let request: ImageAssociationRequest
        let resolver: ImageOwnerResolver
        let byOwner: [AttachmentOwnerKey: [ImageAttachmentMetadata]]
        let byID: [UUID: [ImageAttachmentMetadata]]
        let unknownOwners: Set<UUID>
    }

    private static func evaluate(
        _ key: AttachmentOwnerKey, context: Context, response: inout ImageAssociationResponse
    ) {
        let resolved = context.resolver.resolve(key)
        for issue in resolved.issues { diagnose(issue, key: key, response: &response) }
        let images = context.byOwner[key] ?? []
        let protected = resolved.privacy == .protected || images.contains {
            $0.deletedAt == nil && $0.protection == .protected
        }
        // 无论有零、一或多张图，受保护记录只给同一个不公开状态。
        if protected || (key.kind == .diary && resolved.privacy == .unknown) {
            response.associations[key] = .init(owner: key, ownerState: resolved.state,
                                              presence: .protected, browse: .protected)
            return
        }
        if images.contains(where: { $0.deletedAt == nil && $0.protection == .unknown }) {
            diagnose(.privacyMetadataIncomplete, key: key, response: &response)
            response.associations[key] = .init(owner: key, ownerState: resolved.state,
                                              presence: .protected, browse: .protected)
            return
        }
        if context.unknownOwners.contains(key.id) { diagnose(.unknownOwnerKind, key: key, response: &response) }
        if images.contains(where: { context.byID[$0.id, default: []].count > 1 }) {
            diagnose(.duplicateImageID, key: key, response: &response)
        }
        if context.request.coverage.associations.state(for: key) == .invalid {
            diagnose(.invalidAssociationData, key: key, response: &response)
            response.associations[key] = .init(owner: key, ownerState: resolved.state,
                                              presence: .unknown, browse: .unknown)
            return
        }
        guard resolved.state == .live, let owner = resolved.value else {
            response.associations[key] = .init(owner: key, ownerState: resolved.state,
                                              presence: .unknown, browse: .unavailable)
            return
        }
        response.owners[key] = owner.projection
        if response.owners[key] == nil { diagnose(.invalidOwnerAttributes, key: key, response: &response) }
        let evaluation = evaluateImages(images, key: key, context: context, response: &response)
        let complete = associationIsComplete(key, context: context, response: &response)
        let presence: ImageAssociationPresence = evaluation.exists ? .present
            : (complete && !evaluation.ambiguous ? .absent : .unknown)
        let browse: ImageBrowseState = evaluation.browsable ? .available
            : (presence == .absent ? .unavailable : .unknown)
        response.associations[key] = .init(owner: key, ownerState: .live, presence: presence, browse: browse)
    }

    private static func evaluateImages(
        _ images: [ImageAttachmentMetadata], key: AttachmentOwnerKey,
        context: Context, response: inout ImageAssociationResponse
    ) -> (exists: Bool, browsable: Bool, ambiguous: Bool) {
        var exists = false
        var browsable = false
        var ambiguous = context.unknownOwners.contains(key.id)
        for image in images {
            let identity = context.request.coverage.imageIdentities.state(for: image.id)
            if context.byID[image.id, default: []].count != 1 {
                diagnose(.duplicateImageID, key: key, response: &response)
                ambiguous = true
                continue
            }
            guard identity == .completeIncludingDeleted else {
                diagnose(identity == .invalid ? .invalidImageIdentity : .imageIdentityIncomplete,
                         key: key, response: &response)
                ambiguous = true
                continue
            }
            if image.deletedAt != nil {
                diagnose(.deletedImage, key: key, response: &response)
                continue
            }
            exists = true
            guard image.createdAt.timeIntervalSince1970.isFinite, !image.filename.isEmpty else {
                diagnose(.invalidImageMetadata, key: key, response: &response)
                continue
            }
            if AttachmentAccess.canBrowse(.init(attachmentIsLive: true, hasPrivacyVault: false,
                                                owner: key, ownerIsSingleLive: true, diaryIsSensitive: false)) {
                response.images.append(.init(id: .init(type: .image, id: image.id), owner: key,
                                             filename: image.filename, createdAt: image.createdAt))
                browsable = true
            }
        }
        return (exists, browsable, ambiguous)
    }

    private static func associationIsComplete(
        _ key: AttachmentOwnerKey, context: Context, response: inout ImageAssociationResponse
    ) -> Bool {
        if context.unknownOwners.contains(key.id) {
            diagnose(.unknownOwnerKind, key: key, response: &response)
            return false
        }
        guard context.request.images != nil else {
            diagnose(.imagesNotProvided, key: key, response: &response)
            return false
        }
        let coverage = context.request.coverage.associations.state(for: key)
        guard coverage == .completeIncludingDeleted else {
            diagnose(coverage == .invalid ? .invalidAssociationData : .associationCoverageIncomplete,
                     key: key, response: &response)
            return false
        }
        return true
    }

    private static func diagnose(
        _ issue: ImageAssociationIssue, key: AttachmentOwnerKey, response: inout ImageAssociationResponse
    ) {
        let diagnostic = ImageAssociationDiagnostic(issue: issue, owner: key)
        // 每个拥有者只处理一次，诊断连续追加；去重仅扫描当前对象，避免跨对象反复全表查找。
        let current = response.diagnostics.reversed().prefix { $0.owner == key }
        if !current.contains(diagnostic) { response.diagnostics.append(diagnostic) }
    }

    private static func ownerOrder(_ lhs: AttachmentOwnerKey, _ rhs: AttachmentOwnerKey) -> Bool {
        (lhs.kind.rawValue, lhs.id.uuidString) < (rhs.kind.rawValue, rhs.id.uuidString)
    }
}
