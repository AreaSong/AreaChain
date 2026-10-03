import Foundation
import SwiftData
import Observation

enum ContentQueryBodyReadEvent { case willRead, didRead }

/// 只读依赖是装配信任边界，须来自同一 context；不能注入旧快照或跨库实体。
/// 不接收 Batch、查询或授权标志；生产默认始终调用 DiaryContent.read 的同批目录重载。
@MainActor
struct ContentQueryBodyReads {
    let context: ModelContext
    var diaries: DiaryContentQueryReads
    var tags: TagContentQueryReads
    // 故障/重入观察只接收阶段，不接收或返回正文，不能替换实际读取结果。
    var observeContent: (ContentQueryBodyReadEvent) throws -> Void = { _ in }

    init(context: ModelContext) {
        self.context = context
        diaries = .init(context: context)
        tags = .init(context: context)
    }

    func readContent(_ entry: DiaryEntry, vault: PrivacyVault, tags: [TagItem],
                     permit: ContentQueryBodyReadPermit) throws -> String {
        try observeContent(.willRead)
        try permit.validate()
        let changes = ContentQueryReadGate()
        let result = withObservationTracking {
            Result { try DiaryContent.read(entry, vault: vault, protectionTags: tags, permit: permit) }
        } onChange: { changes.revoke() }
        // 只观察实际合法读取过的字段；不为监视旧正文另取明文副本。
        permit.retainFacts {
            guard changes.state.epoch == 0 else { throw ContentQueryReadSessionError.stalePermit }
        }
        let value = try result.get()
        try observeContent(.didRead)
        try permit.validate()
        return value
    }

    /// 只有门禁内部生成的 capability 能进入；返回值仅流回该门禁的私有冻结所有者。
    func read(query: ContentQuerySession, vault: PrivacyVault, observation: RoutineContentQueryObservation,
              options: ContentQueryBatchOptions, permit: ContentQueryBodyReadPermit) throws -> ContentQueryBatch {
        try permit.validate()
        var rows: [DiaryEntry]?
        var catalog: [TagItem]?
        var diaryReads = diaries
        diaryReads.allDiaries = {
            try permit.validate()
            let values = try diaries.allDiaries()
            try permit.validate()
            rows = values
            return values
        }
        var tagReads = tags
        tagReads.allTags = {
            try permit.validate()
            let values = try tags.allTags()
            try permit.validate()
            catalog = values
            return values
        }
        var batch = TaskFamilyContentQueryReader(tasks: .init(context: context), routines: .init(context: context),
            tags: tagReads, diaries: diaryReads)
            .read(session: query, requestID: UUID(), observation: observation, options: options).batch
        try permit.validate()
        if let rows, let catalog {
            try DiaryContentQueryReader.readBodies(into: &batch, rows: rows, tags: catalog,
                dependencies: self, vault: vault, permit: permit)
        }
        try permit.validate()
        return batch
    }
}
