import AppKit
import ImageIO
import Observation
import SwiftData

enum WorkspaceContentFailure: String, Error {
    case invalidTarget, protectedContent, stale, missingFile, unreadableFile, invalidImage
}

struct WorkspaceDiaryContent {
    let text: String
    let day: String
    let tags: [String]
}

enum WorkspaceReadOnlyContent {
    case tag(TagItem)
    case diary(WorkspaceDiaryContent)
    case image(NSImage, filename: String, owner: CommandObjectReference, ownerLabel: String)
}

/// 仅显式装配。上下文、vault、文件存储和临时根都没有共享缺省值。
@MainActor struct WorkspaceContentReader {
    var bodies: ContentQueryBodyReads
    let vault: PrivacyVault
    let attachments: AttachmentStore
    let attachmentRoot: URL
    let navigation: WorkspaceObjectNavigation
    var beforeImageRead: () async throws -> Void = { await Task.yield() }
    var contentChanged: @MainActor @Sendable () -> Void = {}
    var watchFile: (URL) throws -> Void = { _ in }
    var context: ModelContext { bodies.context }

    func read(_ open: ContentQueryBrowseOpen, permit: ContentQueryBodyReadPermit) async throws -> WorkspaceReadOnlyContent {
        permit.retainFacts {
            guard context === navigation.context, try navigation.allows(open.object) else {
                throw WorkspaceContentFailure.invalidTarget
            }
        }
        try permit.validate()
        guard !open.viewingTrash, open.object.dayKey == nil else { throw WorkspaceContentFailure.invalidTarget }
        let tags = try catalog()
        switch open.object.type {
        case .tag:
            guard open.parent == nil else { throw WorkspaceContentFailure.invalidTarget }
            let matches = tags.filter { $0.id == open.object.id }
            guard matches.count == 1, let tag = matches.first, tag.deletedAt == nil else {
                throw WorkspaceContentFailure.invalidTarget
            }
            // 目录本来允许私密/预设标签的名字；查阅不套用修改标签的资格规则。
            return .tag(tag)
        case .diary:
            guard open.parent == nil else { throw WorkspaceContentFailure.invalidTarget }
            return .diary(try diary(open.object.id, tags: tags, permit: permit))
        case .image: return try await image(open, tags: tags, permit: permit)
        default: throw WorkspaceContentFailure.invalidTarget
        }
    }

    private func catalog() throws -> [TagItem] {
        let tags = try bodies.tags.allTags()
        guard tags.allSatisfy({ $0.modelContext === context }),
              Set(tags.map(ObjectIdentifier.init)) == Set(try context.fetch(FetchDescriptor<TagItem>()).map(ObjectIdentifier.init)),
              DiaryContentQueryTagPrivacy.project(tags).coverage == .complete else {
            throw WorkspaceContentFailure.invalidTarget
        }
        return tags
    }

    private func diary(_ id: UUID, tags: [TagItem], permit: ContentQueryBodyReadPermit) throws -> WorkspaceDiaryContent {
        let rows = try bodies.diaries.allDiaries()
        let matches = rows.filter { $0.id == id }
        guard rows.allSatisfy({ $0.modelContext === context }), matches.count == 1,
              Set(rows.map(ObjectIdentifier.init)) == Set(try context.fetch(FetchDescriptor<DiaryEntry>()).map(ObjectIdentifier.init)),
              let entry = matches.first, entry.deletedAt == nil,
              DiaryQueryMetadata.hasValidTagIDs(entry.tagIDs),
              Set(TagIDList.parse(entry.tagIDs)).isSubset(of: Set(tags.map(\.id))) else {
            throw WorkspaceContentFailure.invalidTarget
        }
        // 先阻断全部保护字段，已解锁 vault 也不能把本批提升为解密路径。
        guard !entry.hasProtectedContent else { throw WorkspaceContentFailure.protectedContent }
        let original = WorkspaceContentSource.Diary(entry)
        permit.retainFacts {
            guard entry.modelContext === context, WorkspaceContentSource.Diary(entry) == original,
                  !entry.hasProtectedContent else { throw WorkspaceContentFailure.stale }
        }
        let text = try bodies.readContent(entry, vault: vault, tags: tags, permit: permit)
        let changed = contentChanged
        let gate = ContentQueryReadGate()
        withObservationTracking { _ = entry.text } onChange: {
            gate.deliver(.observation) { _ in changed() }
        }
        var snapshot = DiaryContentQueryReader.metadataOnly(entry)
        snapshot.text = text; snapshot.isContentAvailable = true
        let metadata = DiaryQueryMetadata(tagNames: Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.name) }),
            privateTagIDs: DiaryContentQueryTagPrivacy.project(tags).privateTagIDs)
        guard !DiaryPrivacy.isSensitive(snapshot, tags: tags),
              !DiaryPrivacy.requiresProtection(text: text, tagIDs: Set(TagIDList.parse(entry.tagIDs)), tags: tags),
              DiaryQueryPrivacy(diary: snapshot, metadata: metadata).canPublishBody else {
            throw WorkspaceContentFailure.protectedContent
        }
        try permit.validate()
        return .init(text: text, day: entry.dayKey,
            tags: tags.filter { $0.deletedAt == nil && TagIDList.contains(entry.tagIDs, $0.id) }.map(\.name))
    }

    private func image(_ open: ContentQueryBrowseOpen, tags: [TagItem],
                       permit: ContentQueryBodyReadPermit) async throws -> WorkspaceReadOnlyContent {
        let id = open.object.id
        let rows = try context.fetch(FetchDescriptor<AttachmentItem>(predicate: #Predicate { $0.id == id }))
        guard rows.count == 1, let item = rows.first, item.modelContext === context,
              item.deletedAt == nil, let owner = item.ownerKey else { throw WorkspaceContentFailure.invalidTarget }
        guard item.privacyVaultID == nil else { throw WorkspaceContentFailure.protectedContent }
        let reference = CommandObjectReference(type: owner.kind == .todo ? .todo : (owner.kind == .routine ? .routine : .diary), id: owner.id)
        guard open.parent == reference else { throw WorkspaceContentFailure.invalidTarget }
        permit.retainFacts {
            guard try navigation.allows(reference) else { throw WorkspaceContentFailure.invalidTarget }
        }
        try permit.validate()
        let owners = try AttachmentAccess.ownerIndex(context: context, keys: [owner])
        guard owners.ownerIsLive(owner) else { throw WorkspaceContentFailure.invalidTarget }
        var label = ""
        switch owner.kind {
        case .todo: label = owners.liveTodos[owner.id]?.title ?? ""
        case .routine: label = owners.liveRoutines[owner.id]?.title ?? ""
        case .diary: label = try diary(owner.id, tags: tags, permit: permit).day
        }
        guard AttachmentAccess.canBrowse(.init(attachmentIsLive: true, hasPrivacyVault: false,
            owner: owner, ownerIsSingleLive: owners.ownerIsLive(owner), diaryIsSensitive: false)) else {
            throw WorkspaceContentFailure.protectedContent
        }
        let file = item.reference
        await Task.yield()
        try await beforeImageRead()
        try permit.validate()
        let bytes: Data
        do {
            let url = try attachments.ordinaryFileURL(reference: file, root: attachmentRoot)
            try watchFile(url)
            bytes = try attachments.readOrdinary(reference: file, root: attachmentRoot)
        }
        catch let error as CocoaError {
            throw error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile
                ? WorkspaceContentFailure.missingFile : WorkspaceContentFailure.unreadableFile
        } catch { throw WorkspaceContentFailure.invalidImage }
        try permit.validate()
        guard let source = CGImageSourceCreateWithData(bytes as CFData, nil),
              let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw WorkspaceContentFailure.invalidImage }
        try permit.validate()
        return .image(NSImage(cgImage: decoded, size: .zero), filename: item.filename, owner: reference, ownerLabel: label)
    }
}
