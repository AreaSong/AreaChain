import Foundation
import SwiftData

extension TrashContentQueryReads {
    /// 唯一 Batch 只流回 ReadSession 私有 owner；外部不能用旧 Batch 替换同批保护事实。
    func read(query: ContentQuerySession, requestID: UUID, vault: PrivacyVault,
              observation: RoutineContentQueryObservation, options: ContentQueryBatchOptions,
              permit: ContentQueryBodyReadPermit) throws -> (ContentQueryBatch, TrashContentQueryReadDetails) {
        try permit.validate()
        var batch = ContentQueryBatch(requestID: requestID, session: query, options: options)
        var details = TrashContentQueryReadDetails()
        let needed = TrashContentQueryPlan.types(query)
        guard !needed.isEmpty else { return (batch, details) }
        let capture = TrashContentQueryCapture(context: bodies.context, permit: permit)
        let parents = try needed.contains(.todo) ? capture.read(todos, project: TrashContentQueryCapture.todo) : .notProvided
        batch.snapshots.todos = parents.projecting(TrashContentQueryCapture.todo)
        if needed.contains(.subtask) {
            let children = try capture.read(subtasks, project: TrashSubtaskStamp.init)
            installSubtasks(children, parents: parents, into: &batch, details: &details)
        }
        let definitions = try needed.contains(.routine) ? capture.read(routines, project: { $0.snapshot }) : .notProvided
        batch.snapshots.routines = definitions.projecting { $0.snapshot }
        let entries = try needed.contains(.diary) ? capture.read(diaries, project: TrashDiaryStamp.init) : .notProvided
        batch.snapshots.diaries = entries.projecting(DiaryContentQueryReader.metadataOnly)
        let catalog = try capture.read(tags, project: TrashContentQueryCapture.tag)
        batch.snapshots.tags = catalog.projecting(TrashContentQueryCapture.tag)
        if needed.contains(.image) {
            batch.snapshots.images = try capture.read(images, project: ImageContentQueryReads.metadata)
                .projecting(ImageContentQueryReads.metadata)
        }
        installCoverage(into: &batch, details: &details)
        installTags(catalog, into: &batch, details: &details)
        if needed.contains(.routine) {
            try readHistory(definitions, into: &batch, observation: observation, capture: capture)
        }
        if let rows = entries.values {
            try DiaryContentQueryReader.readTrashBodies(into: &batch, rows: rows,
                tags: catalog.coverage == .complete ? catalog.values : nil,
                dependencies: bodies, vault: vault, permit: permit)
            if rows.contains(where: { batch.facts.trashCoverage.diaryPrivacy.state(for: .init(kind: .diary, id: $0.id))
                != .completeIncludingDeleted }) { details.issues.insert(.protectionIncomplete) }
        }
        try permit.validate()
        return (batch, details)
    }

    private func installSubtasks(_ source: ContentQueryBatchSource<SubtaskItem>,
        parents: ContentQueryBatchSource<TodoItem>, into batch: inout ContentQueryBatch,
        details: inout TrashContentQueryReadDetails) {
        guard let rows = source.values else {
            batch.snapshots.subtasks = source.coverage == .failed ? .failed : .notProvided
            return
        }
        var values: [SubtaskSnapshot] = []
        let parentRows = Set((parents.values ?? []).map(\.persistentModelID))
        for row in rows {
            let id = CommandObjectReference(type: .subtask, id: row.id)
            if source.coverage == .complete { batch.facts.trashCoverage.objects[id] = .completeIncludingDeleted }
            guard let value = row.snapshot else {
                batch.facts.trashUnconvertedSubtaskIDs.append(row.id)
                details.issues.insert(.unconvertibleSubtask)
                continue
            }
            values.append(value)
            // 未读父类型与完整枚举内错关系不同；不把别的物理父行按业务 UUID 重挂。
            if parents.coverage == .complete, let parent = row.todo,
               !parentRows.contains(parent.persistentModelID) || parent.modelContext !== bodies.context {
                batch.facts.trashCoverage.objects[id] = .invalid
                details.issues.insert(.invalidSubtaskParent)
            }
        }
        let complete = source.coverage == .complete && batch.facts.trashUnconvertedSubtaskIDs.isEmpty
        batch.snapshots.subtasks = complete ? .complete(values) : .partial(values)
        // 原始表是否读全与可转换投影分开；孤立行不能证明任何父项的子项范围完整。
        details.sources[.subtask] = source.coverage
    }

    private func installTags(_ source: ContentQueryBatchSource<TagItem>, into batch: inout ContentQueryBatch,
                             details: inout TrashContentQueryReadDetails) {
        guard let rows = source.values else {
            details.tagNames = source.coverage
            batch.facts.trashTagNamesCoverage = Self.coverage(source.coverage)
            return
        }
        let ids = ContentQueryTagNames.associatedIDs(in: batch)
        let names = ContentQueryTagNames.project(ids, rows: rows)
        let groups = Dictionary(grouping: rows, by: \.id)
        let safeIDs = ids.filter { id in groups[id]?.count == 1 && groups[id]?.first?.isPrivateDiary == false }
        // 保留逐对象可核验的安全名字；一个私密标签不能抹掉其他普通手记的保护资料。
        let available = ContentQueryTagNames.project(Set(safeIDs), rows: rows)
        let privacy = source.coverage == .complete ? DiaryContentQueryTagPrivacy.project(rows) : nil
        batch.facts.metadata = .init(tagNames: available.values, privateTagIDs: privacy?.privateTagIDs)
        details.tagNames = source.coverage == .complete ? names.coverage : .partial
        batch.facts.trashTagNamesCoverage = Self.coverage(details.tagNames)
        if details.tagNames != .complete { details.issues.insert(.tagNamesIncomplete) }
    }

    private func readHistory(_ definitions: ContentQueryBatchSource<DailyRoutine>, into batch: inout ContentQueryBatch,
        observation: RoutineContentQueryObservation, capture: TrashContentQueryCapture) throws {
        var reads = history
        reads.allChecks = {
            let source = try capture.read({ .complete(try history.allChecks()) }) { row in
                TrashCheckStamp(row)
            }
            guard let rows = source.values else { throw ContentQueryReadSessionError.readFailed }
            return rows
        }
        var details = RoutineContentQueryReadDetails()
        RoutineContentQueryReader(reads: reads).readFacts(into: &batch,
            definitions: definitions.coverage == .complete ? definitions.values : nil,
            observation: observation, details: &details)
        // 原适配的失败分类不能吞掉隐私撤权或重入失效。
        try capture.permit.validate()
    }

    private func installCoverage(into batch: inout ContentQueryBatch, details: inout TrashContentQueryReadDetails) {
        let sources: [(CommandObjectType, ContentQuerySourceCoverage)] = [
            (.todo, batch.snapshots.todos.coverage), (.subtask, batch.snapshots.subtasks.coverage),
            (.routine, batch.snapshots.routines.coverage), (.diary, batch.snapshots.diaries.coverage),
            (.tag, batch.snapshots.tags.coverage), (.image, batch.snapshots.images.coverage)
        ]
        for (type, source) in sources {
            if details.sources[type] == nil { details.sources[type] = source }
            batch.facts.trashCoverage.types[type] = Self.coverage(source)
            if source == .failed { details.issues.insert(.fetchFailed(type)) }
            if source == .partial { details.issues.insert(.incompleteRows(type)) }
        }
    }

    private static func coverage(_ source: ContentQuerySourceCoverage) -> TrashReadCompleteness {
        switch source {
        case .complete: .completeIncludingDeleted
        case .partial: .partial
        case .failed: .invalid
        case .notProvided: .notProvided
        }
    }
}

private struct TrashCheckStamp: Equatable {
    let id: UUID
    let value: CheckSnapshot?
    let parent: PersistentIdentifier?
    @MainActor init(_ row: RoutineCheck) {
        id = row.id; value = row.snapshot; parent = row.routine?.persistentModelID
    }
}
