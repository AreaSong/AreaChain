import Foundation

/// 只在选中的提供者需要任务事实时建立一次嵌套视图，不修改原数组或重新去重。
struct ContentQueryBatchAssembly {
    let batch: ContentQueryBatch
    let todos: [TodoSnapshot]?
    let taskIssues: [ContentQueryBatchConsistencyIssue]

    static func trashInputTypes(_ session: ContentQuerySession) -> Set<CommandObjectType> {
        let requested = session.typeAnalysis.possibleTypes
        var needed = requested
        if !requested.subtracting([.tag]).isEmpty {
            // 非标签墓碑组可能含图片；完整图片身份核验还需要跨 owner 的保护事实。
            needed.formUnion([.todo, .routine, .diary, .image])
        }
        if !requested.isDisjoint(with: [.todo, .subtask, .image]) { needed.insert(.subtask) }
        return needed
    }

    init(_ batch: ContentQueryBatch, needsTasks: Bool, needsSubtasks: Bool) {
        self.batch = batch
        guard needsTasks, let parents = batch.snapshots.todos.values else {
            todos = nil; taskIssues = []; return
        }
        guard !parents.contains(where: { !$0.subtasks.isEmpty }) else {
            todos = nil; taskIssues = [.nestedSubtaskInput]; return
        }
        let children = needsSubtasks ? batch.snapshots.subtasks.values ?? [] : []
        let grouped = Dictionary(grouping: children, by: \.todoId)
        let parentIDs = Set(parents.map(\.id))
        taskIssues = children.contains { !parentIDs.contains($0.todoId) } ? [.uncontainedSubtasks] : []
        todos = parents.map { parent in
            var value = parent
            value.subtasks = grouped[parent.id] ?? []
            return value
        }
    }

    var imageInput: ContentQueryImageInput {
        .init(images: batch.snapshots.images.values, coverage: imageCoverage, imagePrivacy: batch.facts.imagePrivacy)
    }
    var subtaskData: TodoQuerySubtaskData {
        batch.snapshots.subtasks.coverage == .complete ? .includedInSnapshots : .unavailable
    }

    func read(_ provider: ContentQueryProviderID) throws -> ContentQueryProviderRead? {
        let input = batch.snapshots
        let facts = batch.facts
        let session = batch.session
        let id = batch.requestID
        switch provider {
        case .todo:
            guard let todos else { return nil }
            return .todo(TodoQueryProvider.read(.init(requestID: id, session: session, todos: todos,
                tagNames: facts.metadata.tagNames, subtaskData: subtaskData, imageInput: imageInput)))
        case .subtask:
            guard let todos, input.subtasks.values != nil else { return nil }
            return .subtask(SubtaskQueryProvider.read(.init(requestID: id, session: session, todos: todos,
                tagNames: facts.metadata.tagNames, subtaskData: subtaskData)))
        case .routine:
            guard let values = input.routines.values else { return nil }
            return .routine(RoutineQueryProvider.read(.init(requestID: id, session: session, routines: values,
                tagNames: facts.metadata.tagNames, checks: facts.routine.checks, checkCoverage: facts.routine.checkCoverage,
                scheduleEvidence: facts.routine.scheduleEvidence, imageInput: imageInput)))
        case .diary:
            guard let values = input.diaries.values else { return nil }
            return .diary(DiaryQueryProvider.read(.init(requestID: id, session: session, diaries: values,
                metadata: facts.metadata, locale: batch.options.locale, imageInput: imageInput)))
        case .image: return readImages()
        case .tag:
            guard let values = input.tags.values else { return nil }
            return .tag(TagQueryProvider.read(.init(requestID: id, session: session, tags: values,
                usage: facts.tagUsage, view: batch.options.tagView)))
        case .clipboard:
            let query: ClipboardQueryInput
            switch batch.options.clipboardMode {
            case .unified: query = .unified(session)
            case .explicit(let mode, let needle):
                query = .explicit(try .init(mode: mode, needle: needle, filters: session))
            }
            return .clipboard(ClipboardQueryProvider.read(.init(requestID: id, input: query, records: input.clipboard)))
        case .trash: return readTrash()
        case .routineOccurrence: return readOccurrences()
        }
    }

    private func readImages() -> ContentQueryProviderRead? {
        let input = batch.snapshots
        guard input.images.values != nil else { return nil }
        let facts = batch.facts
        let association = ImageAssociationRequest(images: input.images.values,
            owners: .init(todos: todos, routines: input.routines.values, diaries: input.diaries.values),
            privacy: facts.metadata, coverage: imageCoverage, imagePrivacy: facts.imagePrivacy)
        return .image(ImageQueryProvider.read(.init(requestID: batch.requestID, session: batch.session,
            association: association, tagNames: facts.metadata.tagNames, checks: facts.routine.checks,
            checkCoverage: facts.routine.checkCoverage, scheduleEvidence: facts.routine.scheduleEvidence)))
    }

    private func readOccurrences() -> ContentQueryProviderRead? {
        guard let routines = batch.snapshots.routines.values else { return nil }
        let facts = batch.facts.routine
        return .routineOccurrence(RoutineOccurrenceQueryProvider.read(.init(requestID: batch.requestID,
            session: batch.session, routines: routines, checks: facts.checks, checkCoverage: facts.checkCoverage,
            scheduleEvidence: facts.scheduleEvidence,
            definitionCoverage: batch.snapshots.routines.coverage == .complete ? .complete : .partial,
            browseWindow: batch.options.occurrenceWindow, budget: batch.options.occurrenceBudget)))
    }

    private func readTrash() -> ContentQueryProviderRead {
        let input = batch.snapshots
        let facts = batch.facts
        let needed = Self.trashInputTypes(batch.session)
        // 墓碑直接消费平面权威源；不能把刚组装的嵌套子项再重复投递。
        let tombstones = TrashTombstoneInput(
            todos: needed.contains(.todo) && !taskIssues.contains(.nestedSubtaskInput) ? input.todos.values : nil,
            subtasks: needed.contains(.subtask) ? input.subtasks.values : nil,
            unconvertedSubtaskIDs: needed.contains(.subtask) ? facts.trashUnconvertedSubtaskIDs : [],
            routines: needed.contains(.routine) ? input.routines.values : nil,
            diaries: needed.contains(.diary) ? input.diaries.values : nil,
            tags: needed.contains(.tag) ? input.tags.values : nil,
            images: needed.contains(.image) ? input.images.values : nil, privacy: facts.metadata,
            diaryProtection: facts.imagePrivacy, coverage: trashCoverage, locale: batch.options.locale)
        let routine = TrashQueryRoutineInput(schedules: facts.routine.scheduleEvidence,
            checks: facts.routine.checks, checkCoverage: facts.routine.checkCoverage)
        return .trash(TrashQueryProvider.read(.init(requestID: batch.requestID, session: batch.session,
            input: tombstones, routineInput: routine, tagNames: facts.metadata.tagNames,
            tagNamesCoverage: facts.trashTagNamesCoverage)))
    }

    /// 整类型完整声明不得高于主源枚举；对象级的精确声明仍由原读取器按优先级核验。
    private var imageCoverage: ImageAssociationCoverage {
        var coverage = batch.facts.imageCoverage
        let input = batch.snapshots
        let owners: [(AttachmentOwner, ContentQuerySourceCoverage)] = [
            (.todo, input.todos.coverage), (.routine, input.routines.coverage), (.diary, input.diaries.coverage)
        ]
        for (kind, source) in owners where source != .complete {
            if coverage.owners.types[kind] == .completeIncludingDeleted { coverage.owners.types[kind] = .partial }
        }
        if input.images.coverage != .complete {
            for kind in [AttachmentOwner.todo, .routine, .diary] {
                if coverage.associations.types[kind] == .completeIncludingDeleted { coverage.associations.types[kind] = .partial }
            }
            if coverage.imageIdentities.allIDs == .completeIncludingDeleted { coverage.imageIdentities.allIDs = .partial }
        }
        return coverage
    }

    private var trashCoverage: TrashReadCoverage {
        var coverage = batch.facts.trashCoverage
        let input = batch.snapshots
        let sources: [(CommandObjectType, ContentQuerySourceCoverage)] = [
            (.todo, input.todos.coverage), (.subtask, input.subtasks.coverage), (.routine, input.routines.coverage),
            (.diary, input.diaries.coverage), (.image, input.images.coverage), (.tag, input.tags.coverage)
        ]
        for (type, source) in sources where source != .complete {
            if coverage.types[type] == .completeIncludingDeleted { coverage.types[type] = .partial }
        }
        return coverage
    }
}
