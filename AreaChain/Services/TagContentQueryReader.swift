import Foundation
import SwiftData

/// 全目录读取与按 ID 的关联名字读取用途不同；只调用仓储的无副作用枚举入口。
@MainActor
struct TagContentQueryReads {
    var allTags: () throws -> [TagItem]

    init(context: ModelContext) {
        let repository: any CatalogRepositoryProtocol = SwiftDataCatalogRepository(context: context)
        allTags = { try repository.fetchTags(includeDeleted: true) }
    }
}

enum TagContentQueryReadIssue: Equatable { case fetchFailed }
enum TagContentQueryUsageOrigin: Equatable { case notProvided, injected, stored }

struct TagContentQueryReadDetails: CustomStringConvertible, CustomDebugStringConvertible {
    let source: ContentQuerySourceCoverage
    let usageOrigin: TagContentQueryUsageOrigin
    var issues: [TagContentQueryReadIssue] = []
    var description: String { "TagContentQueryReadDetails(redacted)" }
    var debugDescription: String { description }
}

/// 实体只在同一 MainActor 同步装配中使用；返回值不保留模型或延迟投影闭包。
@MainActor
struct TagContentQueryReader {
    private let reads: TagContentQueryReads

    init(context: ModelContext) { reads = .init(context: context) }
    init(reads: TagContentQueryReads) { self.reads = reads }

    /// 直接填入同一 Batch。真实统计由受控全来源适配提供，不从任务搜索子集推定完整。
    func readSources(into batch: inout ContentQueryBatch, injectedUsage: TagQueryUsageInput? = nil,
                     requiresDiaryMetadata: Bool = false, storedUsage: TagUsageContentQueryStatistics? = nil)
        -> (details: TagContentQueryReadDetails, associatedNames: ContentQueryTagNames?,
            diaryPrivacy: DiaryContentQueryTagPrivacy?) {
        let session = batch.session
        let skipped = TagContentQueryReadDetails(source: .notProvided, usageOrigin: .notProvided)
        if case .command = session.input { return (skipped, nil, nil) }
        let needsCatalog = session.typeAnalysis.possibleTypes.contains(.tag)
        guard session.isStructurallyValid, needsCatalog || requiresDiaryMetadata else { return (skipped, nil, nil) }
        let origin: TagContentQueryUsageOrigin = storedUsage != nil ? .stored : (injectedUsage == nil ? .notProvided : .injected)
        if needsCatalog { batch.facts.tagUsage = storedUsage?.input ?? injectedUsage }
        let ids = ContentQueryTagNames.associatedIDs(in: batch)
        do {
            let rows = try reads.allTags()
            // 不规范化原值、不排除墓碑、不按身份或名称去重；冲突由既有提供者隔离。
            if needsCatalog {
                batch.snapshots.tags = .complete(rows.map {
                    .init(id: $0.id, name: $0.name, sortOrder: $0.sortOrder, deletedAt: $0.deletedAt,
                          isPrivateDiary: $0.isPrivateDiary, colorToken: $0.colorToken)
                })
                batch.facts.trashCoverage.types[.tag] = .completeIncludingDeleted
            }
            return (needsCatalog ? .init(source: .complete, usageOrigin: origin) : skipped,
                    .project(ids, rows: rows), requiresDiaryMetadata ? .project(rows) : nil)
        } catch {
            if needsCatalog {
                batch.snapshots.tags = .failed
                batch.facts.trashCoverage.types[.tag] = .notProvided
            }
            let names = ids.isEmpty ? ContentQueryTagNames.project(ids, rows: [])
                : .init(values: nil, coverage: .failed, issues: [.fetchFailed])
            return (needsCatalog ? .init(source: .failed, usageOrigin: origin, issues: [.fetchFailed]) : skipped,
                    names, requiresDiaryMetadata ? .init(privateTagIDs: nil, coverage: .failed, issues: [.fetchFailed]) : nil)
        }
    }
}
