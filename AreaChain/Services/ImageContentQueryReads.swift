import Foundation
import SwiftData

/// 只有显式注入的上下文；附件依赖只返回模型枚举，不具有图片文件能力。
@MainActor
struct ImageContentQueryReads {
    let bodies: ContentQueryBodyReads
    var tasks: TaskContentQueryReads
    var routines: RoutineContentQueryReads
    var attachments: () throws -> ContentQueryBatchSource<AttachmentItem>

    init(context: ModelContext, bodies: ContentQueryBodyReads? = nil) {
        self.bodies = bodies ?? .init(context: context)
        tasks = .init(context: context)
        routines = .init(context: context)
        attachments = { .complete(try context.fetch(FetchDescriptor<AttachmentItem>())) }
    }

    func read(query: ContentQuerySession, vault: PrivacyVault, observation: RoutineContentQueryObservation,
              options: ContentQueryBatchOptions, permit: ContentQueryBodyReadPermit) throws -> ContentQueryBatch {
        try permit.validate()
        let plan = ImageContentQueryPlan(query)
        let images = try readImages(required: plan.required, permit: permit)
        let capture = ImageContentQueryCapture(context: bodies.context, permit: permit)
        let owners = plan.owners
        let family = TaskFamilyContentQueryReader(tasks: capture.tasks(tasks), routines: capture.routines(routines),
            tags: capture.tags(bodies.tags), diaries: capture.diaries(bodies.diaries))
        var batch = family.read(session: query, requestID: UUID(), observation: observation,
                                options: options, imageOwners: owners).batch
        try permit.validate()
        batch.snapshots.images = images
        if plan.required { installCoverage(into: &batch, owners: owners) }
        if let rows = capture.diaryRows {
            try DiaryContentQueryReader.readBodies(into: &batch, rows: rows, tags: capture.tagRows,
                dependencies: bodies, vault: vault, permit: permit, imageOwners: plan.required && owners.contains(.diary))
        }
        try permit.validate()
        return batch
    }

    private func readImages(required: Bool, permit: ContentQueryBodyReadPermit) throws
        -> ContentQueryBatchSource<ImageAttachmentMetadata> {
        guard required else { return .notProvided }
        try permit.validate()
        let source: ContentQueryBatchSource<AttachmentItem>
        do { source = try attachments() } catch { try permit.validate(); return .failed }
        try permit.validate()
        guard let rows = source.values else { return source.coverage == .failed ? .failed : .notProvided }
        try ImageContentQueryCapture.retain(rows, context: bodies.context, permit: permit,
                                            complete: source.coverage == .complete, project: Self.metadata)
        let values = rows.map(Self.metadata)
        return source.coverage == .complete ? .complete(values) : .partial(values)
    }

    static func metadata(_ row: AttachmentItem) -> ImageAttachmentMetadata {
        .init(id: row.id, ownerKind: row.ownerKind, ownerID: row.ownerID, filename: row.filename,
              createdAt: row.createdAt, deletedAt: row.deletedAt,
              protection: row.privacyVaultID == nil ? .unprotected : .protected)
    }

    private func installCoverage(into batch: inout ContentQueryBatch, owners: Set<AttachmentOwner>) {
        let imageState = Self.coverage(batch.snapshots.images.coverage)
        batch.facts.imageCoverage = .init()
        batch.facts.imageCoverage.imageIdentities.allIDs = imageState
        for kind in owners {
            let state: ContentQuerySourceCoverage
            switch kind {
            case .todo: state = batch.snapshots.todos.coverage
            case .routine: state = batch.snapshots.routines.coverage
            case .diary: state = batch.snapshots.diaries.coverage
            }
            batch.facts.imageCoverage.owners.types[kind] = Self.coverage(state)
            batch.facts.imageCoverage.associations.types[kind] = imageState
        }
    }

    private static func coverage(_ value: ContentQuerySourceCoverage) -> ImageReadCompleteness {
        switch value {
        case .complete: .completeIncludingDeleted
        case .partial: .partial
        case .failed: .invalid
        case .notProvided: .notProvided
        }
    }
}

/// 图片页的拥有者是辅助输入；不会改 Session 的请求类型或额外选择记录提供者。
struct ImageContentQueryPlan {
    let imageResults: Bool
    let recordOwners: Set<AttachmentOwner>
    var required: Bool { imageResults || !recordOwners.isEmpty }

    init(_ query: ContentQuerySession) {
        guard query.isStructurallyValid, query.composition?.deletion == .liveOnly,
              !query.typeAnalysis.possibleTypes.isEmpty else {
            imageResults = false; recordOwners = []; return
        }
        let types = query.typeAnalysis.possibleTypes
        imageResults = types.contains(.image)
        recordOwners = ContentQueryImageRead.isRequired(query.conditions)
            ? Set([AttachmentOwner.todo, .routine, .diary].filter { kind in
                switch kind {
                case .todo: types.contains(.todo)
                case .routine: types.contains(.routine)
                case .diary: types.contains(.diary)
                }
            }) : []
    }

    var owners: Set<AttachmentOwner> {
        // 图片页三类拥有者均参与，包含零图的保护对象，避免读取形状暴露隐藏关联数量。
        recordOwners.union(imageResults ? [.todo, .routine, .diary] : [])
    }
}
