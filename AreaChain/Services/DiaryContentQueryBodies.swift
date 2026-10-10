import Foundation
import SwiftData

extension DiaryContentQueryReader {
    /// 墓碑专用许可路径；不扩展旧 live-only 守卫，已知保护对象无论解锁与否都不读正文。
    static func readTrashBodies(into batch: inout ContentQueryBatch, rows: [DiaryEntry], tags: [TagItem]?,
        dependencies: ContentQueryBodyReads, vault: PrivacyVault, permit: ContentQueryBodyReadPermit) throws {
        try permit.validate()
        guard batch.session.scope == .catalog(.trash), batch.session.composition?.deletion == .deletedOnly else {
            throw ContentQueryReadSessionError.queryMismatch
        }
        var facts = DiaryImageProtectionFacts(metadata: batch.facts.metadata)
        let originals = rows.map(metadataOnly)
        let groups = Dictionary(grouping: rows, by: \.id)
        var values = originals
        let complete = batch.snapshots.diaries.coverage == .complete
        let catalogComplete = tags.map { DiaryContentQueryTagPrivacy.project($0).coverage == .complete } ?? false
        let ids = Set((tags ?? []).map(\.id))
        let needsBody = batch.session.typeAnalysis.possibleTypes.contains(.diary)
        for index in rows.indices where groups[rows[index].id]?.count == 1 && complete {
            try permit.validate()
            let row = rows[index]
            if row.hasProtectedContent {
                facts.record(originals[index], protection: .protected)
                continue
            }
            guard catalogComplete, let tags, DiaryQueryMetadata.hasValidTagIDs(row.tagIDs),
                  Set(TagIDList.parse(row.tagIDs)).isSubset(of: ids),
                  row.deletedAt.map({ ContentQuerySnapshotValidation.validTimestamp($0, dates: batch.dates) }) != false
            else { continue }
            // 活行只作为图片拥有者保护核验；正文从不变成墓碑候选。
            let text = try? dependencies.readContent(row, vault: vault, tags: tags, permit: permit)
            try permit.validate()
            guard let text else { continue }
            var value = originals[index]
            value.text = text; value.isContentAvailable = true
            let sensitive = DiaryPrivacy.isSensitive(value, tags: tags)
                || DiaryPrivacy.requiresProtection(text: text, tagIDs: Set(TagIDList.parse(row.tagIDs)), tags: tags)
            if sensitive { continue }
            guard DiaryQueryPrivacy(diary: value, metadata: batch.facts.metadata).canPublishBody else { continue }
            facts.record(originals[index], protection: .unprotected)
            if needsBody && row.deletedAt != nil { values[index] = value }
        }
        try permit.validate()
        guard rows.map(metadataOnly) == originals else { throw ContentQueryReadSessionError.stalePermit }
        batch.snapshots.diaries = complete ? .complete(values) : .partial(values)
        batch.facts.imagePrivacy = facts
        batch.facts.trashCoverage.diaryPrivacy = .init(objects: Dictionary(uniqueKeysWithValues:
            facts.checkedIDs.map { (AttachmentOwnerKey(kind: .diary, id: $0), .completeIncludingDeleted) }))
    }

    /// 全枚举身份先于任何解密；正文和标签保护资料均来自当前装配，失败不回填模型。
    static func readBodies(into batch: inout ContentQueryBatch, rows: [DiaryEntry], tags: [TagItem]?,
                          dependencies: ContentQueryBodyReads, vault: PrivacyVault,
                          permit: ContentQueryBodyReadPermit, imageOwners: Bool = false) throws {
        try permit.validate()
        var imageFacts = DiaryImageProtectionFacts(metadata: batch.facts.metadata)
        let originals = rows.map(metadataOnly)
        let groups = Dictionary(grouping: rows, by: \.id)
        if imageOwners {
            for row in rows where groups[row.id]?.count == 1 && row.hasProtectedContent {
                imageFacts.record(metadataOnly(row), protection: .protected)
            }
            installImageFacts(imageFacts, into: &batch)
        }
        guard let tags, batch.snapshots.diaries.coverage == .complete,
              rows.allSatisfy({ $0.modelContext === dependencies.context }),
              tags.allSatisfy({ $0.modelContext === dependencies.context }),
              DiaryContentQueryTagPrivacy.project(tags).coverage == .complete else { return }
        guard batch.snapshots.diaries.values == originals else { throw ContentQueryReadSessionError.stalePermit }
        let protection = rows.map { ProtectionStamp($0) }
        let tagStamps = tags.map { TagStamp($0) }
        permit.retainFacts {
            guard rows.allSatisfy({ $0.modelContext === dependencies.context }),
                  tags.allSatisfy({ $0.modelContext === dependencies.context }),
                  rows.map(metadataOnly) == originals, rows.map({ ProtectionStamp($0) }) == protection,
                  tags.map({ TagStamp($0) }) == tagStamps else { throw ContentQueryReadSessionError.stalePermit }
        }
        let tagIDs = Set(tags.map(\.id))
        let needsBodies = batch.session.typeAnalysis.possibleTypes.contains(.diary)
        var values = originals
        for index in rows.indices {
            try permit.validate()
            let row = rows[index]
            guard groups[row.id]?.count == 1, row.deletedAt == nil,
                  DiaryQueryMetadata.hasValidTagIDs(row.tagIDs),
                  Set(TagIDList.parse(row.tagIDs)).isSubset(of: tagIDs) else { continue }
            // 锁定不能阻断可靠普通正文；保护行则必须使用当前（而非捕获的）解锁事实。
            if row.hasProtectedContent && (dependencies.ordinaryOnly || !needsBodies || !vault.isUnlocked) { continue }
            let text = try? dependencies.readContent(row, vault: vault, tags: tags, permit: permit)
            try permit.validate()
            guard let text else { continue }
            var value = originals[index]
            value.text = text
            value.isContentAvailable = true
            // 旧明文即使 API 可读也不成为搜索事实；含名称匹配的私密标签检查不可省略。
            let sensitive = DiaryPrivacy.isSensitive(value, tags: tags)
                || DiaryPrivacy.requiresProtection(text: text, tagIDs: Set(TagIDList.parse(value.tagIDs)), tags: tags)
            if imageOwners {
                imageFacts.record(originals[index], protection: sensitive ? .protected : .unprotected)
            }
            if !row.hasProtectedContent && sensitive { continue }
            if needsBodies { values[index] = value }
        }
        try permit.validate()
        batch.snapshots.diaries = .complete(values)
        if imageOwners { installImageFacts(imageFacts, into: &batch) }
    }

    private static func installImageFacts(_ facts: DiaryImageProtectionFacts, into batch: inout ContentQueryBatch) {
        batch.facts.imagePrivacy = facts
        // 只对完成检查的对象声明；没有 diary 类型级的完整保护声明。
        batch.facts.imageCoverage.diaryPrivacy = .init(objects: Dictionary(uniqueKeysWithValues:
            facts.checkedIDs.map { (AttachmentOwnerKey(kind: .diary, id: $0), .completeIncludingDeleted) }))
    }
}

/// 纯值证据没有正文；构造与写入仅限本文件中受许可保护的真实检查。
/// 与当前主快照和同批 metadata 不符时失败关闭，不能由任意 isPublic 标志构造。
struct DiaryImageProtectionFacts: CustomStringConvertible, CustomDebugStringConvertible {
    private let metadata: DiaryQueryMetadata
    private var values: [UUID: (DiarySnapshot, ImageProtection)] = [:]
    fileprivate init(metadata: DiaryQueryMetadata) { self.metadata = metadata }
    fileprivate var checkedIDs: [UUID] { Array(values.keys) }
    fileprivate mutating func record(_ diary: DiarySnapshot, protection: ImageProtection) {
        values[diary.id] = (diary, protection)
    }
    func protection(for diary: DiarySnapshot, metadata: DiaryQueryMetadata) -> ImageProtection {
        guard self.metadata.tagNames == metadata.tagNames, self.metadata.privateTagIDs == metadata.privateTagIDs,
              let (original, protection) = values[diary.id] else { return .unknown }
        var current = diary
        current.text = ""; current.isContentAvailable = false
        return current == original ? protection : .unknown
    }
    var description: String { "DiaryImageProtectionFacts(redacted)" }
    var debugDescription: String { description }
}

/// 仅比较同次读取期间的保护资料；不复制原始明文，不声称替代宿主的模型变化事件。
private struct ProtectionStamp: Equatable {
    let encrypted: Data?
    let vaultID: UUID?
    init(_ row: DiaryEntry) { encrypted = row.encryptedText; vaultID = row.privacyVaultID }
}

private struct TagStamp: Equatable {
    let id: UUID
    let name: String
    let isPrivate: Bool
    let deletedAt: Date?
    init(_ row: TagItem) {
        id = row.id; name = row.name; isPrivate = row.isPrivateDiary; deletedAt = row.deletedAt
    }
}
