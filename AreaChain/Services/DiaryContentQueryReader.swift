import Foundation
import SwiftData

/// 仅接受已打开上下文；共享仓储全枚举，不构造带全局隐私依赖的仓储实例。
@MainActor
struct DiaryContentQueryReads {
    var allDiaries: () throws -> [DiaryEntry]

    init(context: ModelContext) {
        allDiaries = { try SwiftDataDiaryRepository.fetchAllDiaries(in: context) }
    }
}

enum DiaryContentQueryReadMode: Equatable { case metadataOnly }
enum DiaryContentQueryReadIssue: Equatable {
    case fetchFailed, bodyNotRead, protectionNotEstablished, invalidDeletedAt(UUID)
}

struct DiaryContentQueryReadDetails: CustomStringConvertible, CustomDebugStringConvertible {
    var source: ContentQuerySourceCoverage = .notProvided
    let mode: DiaryContentQueryReadMode = .metadataOnly
    var issues: [DiaryContentQueryReadIssue] = []
    var description: String { "DiaryContentQueryReadDetails(redacted)" }
    var debugDescription: String { description }
}

/// SwiftData 可能物化正文；这里仅手工投影元数据，不声称模型或上下文从未持有正文。
/// 不可读值只交给既有安全投影；isPrivate=false 也不证明公开或保护转换完成。
@MainActor
struct DiaryContentQueryReader {
    private let reads: DiaryContentQueryReads

    init(context: ModelContext) { reads = .init(context: context) }
    init(reads: DiaryContentQueryReads) { self.reads = reads }

    func readSources(into batch: inout ContentQueryBatch, imageOwner: Bool = false) -> DiaryContentQueryReadDetails {
        let session = batch.session
        if case .command = session.input { return .init() }
        guard session.isStructurallyValid, imageOwner || session.typeAnalysis.possibleTypes.contains(.diary),
              session.composition?.deletion == .liveOnly else { return .init() }
        do {
            let rows = try reads.allDiaries()
            batch.snapshots.diaries = .complete(rows.map(Self.metadataOnly))
            let invalidDates = rows.compactMap { row -> DiaryContentQueryReadIssue? in
                guard let date = row.deletedAt,
                      !ContentQuerySnapshotValidation.validTimestamp(date, dates: batch.dates) else { return nil }
                return .invalidDeletedAt(row.id)
            }
            return .init(source: .complete, issues: [.bodyNotRead, .protectionNotEstablished] + invalidDates)
        } catch {
            batch.snapshots.diaries = .failed
            return .init(source: .failed, issues: [.fetchFailed])
        }
    }

    static func metadataOnly(_ entry: DiaryEntry) -> DiarySnapshot {
        // 空串是明确的无正文占位；保护存在性只读 Bool，不复制密文或 vault 标识。
        .init(id: entry.id, text: "", dayKey: entry.dayKey, createdAt: entry.createdAt,
              deletedAt: entry.deletedAt, tagIDs: entry.tagIDs, isPinned: entry.isPinned,
              isPrivate: entry.hasProtectedContent, isContentAvailable: false)
    }
}
