import Foundation

struct ImageOwnerResolution: CustomStringConvertible, CustomDebugStringConvertible {
    let state: ImageOwnerState
    let value: ImageOwnerInput?
    let privacy: ImageProtection
    let issues: [ImageAssociationIssue]
    var description: String { "ImageOwnerResolution(redacted)" }
    var debugDescription: String { description }
}

/// 与实体 ownerIndex 相同，先按类型和 ID 分组，再判唯一；墓碑始终参与。
struct ImageOwnerResolver: CustomStringConvertible, CustomDebugStringConvertible {
    let rows: [AttachmentOwnerKey: [ImageOwnerInput]]
    let request: ImageAssociationRequest
    var description: String { "ImageOwnerResolver(redacted)" }
    var debugDescription: String { description }

    init(_ request: ImageAssociationRequest) {
        self.request = request
        let values = (request.owners.todos ?? []).map(ImageOwnerInput.todo)
            + (request.owners.routines ?? []).map(ImageOwnerInput.routine)
            + (request.owners.diaries ?? []).map(ImageOwnerInput.diary)
        rows = Dictionary(grouping: values, by: \.key)
    }

    func resolve(_ key: AttachmentOwnerKey) -> ImageOwnerResolution {
        let values = rows[key] ?? []
        let protection = privacy(key, values: values)
        let privacyIssues: [ImageAssociationIssue] = protection == .unknown ? [.privacyMetadataIncomplete] : []
        if values.count > 1 {
            return .init(state: .ambiguous, value: nil, privacy: protection,
                         issues: [.duplicateOwnerID] + privacyIssues)
        }
        guard isProvided(key.kind) else {
            return .init(state: .unknown, value: nil, privacy: protection, issues: [.ownerNotProvided])
        }
        let coverage = request.coverage.owners.state(for: key)
        guard coverage == .completeIncludingDeleted else {
            return .init(state: .unknown, value: nil, privacy: protection,
                         issues: [coverage == .invalid ? .invalidOwnerData : .ownerCoverageIncomplete] + privacyIssues)
        }
        guard let value = values.first else {
            return .init(state: .missing, value: nil, privacy: .unknown, issues: [.missingOwner])
        }
        guard AttachmentAccess.isSingleLive(deletedAts: values.map(\.deletedAt)) else {
            return .init(state: .deleted, value: nil, privacy: protection, issues: [.deletedOwner])
        }
        return .init(state: .live, value: value, privacy: protection, issues: privacyIssues)
    }

    private func isProvided(_ kind: AttachmentOwner) -> Bool {
        switch kind {
        case .todo: request.owners.todos != nil
        case .routine: request.owners.routines != nil
        case .diary: request.owners.diaries != nil
        }
    }

    private func privacy(_ key: AttachmentOwnerKey, values: [ImageOwnerInput]) -> ImageProtection {
        guard key.kind == .diary else { return .unprotected }
        if let facts = request.imagePrivacy {
            guard request.coverage.diaryPrivacy.state(for: key) == .completeIncludingDeleted,
                  values.count == 1, case .diary(let diary) = values[0] else { return .unknown }
            return facts.protection(for: diary, metadata: request.privacy)
        }
        guard request.coverage.diaryPrivacy.state(for: key) == .completeIncludingDeleted,
              !values.isEmpty else { return .unknown }
        let evaluations = values.compactMap { value -> DiaryQueryPrivacy? in
            guard case .diary(let diary) = value else { return nil }
            return DiaryQueryPrivacy(diary: diary, metadata: request.privacy)
        }
        if evaluations.contains(where: { !$0.diagnostics.isEmpty }) { return .unknown }
        return evaluations.allSatisfy(\.canPublishBody) ? .unprotected : .protected
    }
}
