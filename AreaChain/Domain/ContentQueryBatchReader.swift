import Foundation

/// 唯一入口只接受批次，不接受响应或提供者注册列表；每个选中提供者恰好调用一次。
enum ContentQueryBatchReader {
    static func read(_ batch: ContentQueryBatch) -> ContentQueryBatchResponse {
        let session = batch.session
        let queryState: ContentQueryBatchQueryState
        if case .command = session.input { queryState = .commandInput }
        else if !session.isStructurallyValid || Set(session.conditions.map(\.id)).count != session.conditions.count {
            queryState = .invalidStructure
        } else { queryState = .content }
        let providers = queryState == .content ? selectedProviders(session) : []
        let active = providers.filter { canRead($0, session: session) }
        let needsSubtasks = active.contains(.subtask) || (active.contains(.todo) && session.conditions.contains {
            if case .page(.tagID(_, matching: .taskOrSubtask)) = $0.value { return true }; return false
        })
        let assembly = ContentQueryBatchAssembly(batch, needsTasks: active.contains {
            [.todo, .subtask, .image].contains($0)
                || ($0 == .trash && ContentQueryBatchAssembly.trashInputTypes(session).contains(.todo))
        }, needsSubtasks: needsSubtasks)
        var readings: [ContentQueryProviderRead] = []
        var summaries: [ContentQueryProviderCompleteness] = []
        var issues: [ContentQueryBatchConsistencyIssue] = []
        for provider in providers {
            var summary = prepareSummary(provider, batch: batch)
            if canRead(provider, session: session) {
                collect(provider, assembly: assembly, readings: &readings, summary: &summary, issues: &issues)
            }
            summaries.append(summary)
        }
        return .init(requestID: batch.requestID, sortContext: .init(batch: batch), queryState: queryState, typeAnalysis: session.typeAnalysis,
            textDiagnostics: session.textDiagnostics, conditionDiagnostics: session.conditionDiagnostics,
            readings: readings, completeness: .init(queryState: queryState,
                requestedTypes: session.typeAnalysis.requestedTypes, possibleTypes: session.typeAnalysis.possibleTypes,
                providers: summaries), consistencyIssues: issues)
    }

    private static func selectedProviders(_ session: ContentQuerySession) -> [ContentQueryProviderID] {
        let types = session.typeAnalysis.requestedTypes
        if session.scope == .catalog(.trash) { return types.isEmpty ? [] : [.trash] }
        if session.scope == .routineOccurrences { return [.routineOccurrence] }
        if session.scope == .catalog(.clipboard) { return [.clipboard] }
        return ContentQueryProviderID.allCases.filter {
            ![.trash, .clipboard, .routineOccurrence].contains($0) && !$0.types.isDisjoint(with: types)
        }
    }

    private static func canRead(_ provider: ContentQueryProviderID, session: ContentQuerySession) -> Bool {
        let assessments = session.typeAnalysis.types.filter { provider.types.contains($0.type) }
        // 墓碑按类型保留限制，仍允许其他类型读取；缺习惯 on 留给其原对象诊断。
        if provider == .trash { return assessments.contains(where: \.isPossible) }
        return assessments.contains { $0.readRestriction == nil }
    }

    private static func prepareSummary(_ provider: ContentQueryProviderID, batch: ContentQueryBatch) -> ContentQueryProviderCompleteness {
        let types = provider.types.intersection(batch.session.typeAnalysis.requestedTypes)
        var summary = ContentQueryProviderCompleteness(provider: provider, requestedTypes: types)
        for assessment in batch.session.typeAnalysis.types where types.contains(assessment.type) {
            if assessment.readRestriction != nil { summary.limitations.append(.restriction(assessment)) }
        }
        return summary
    }

    private static func collect(
        _ provider: ContentQueryProviderID, assembly: ContentQueryBatchAssembly,
        readings: inout [ContentQueryProviderRead], summary: inout ContentQueryProviderCompleteness,
        issues: inout [ContentQueryBatchConsistencyIssue]
    ) {
        addSources(provider, assembly: assembly, summary: &summary)
        let relevantIssues = assembly.taskIssues.filter {
            $0 == .nestedSubtaskInput || (provider == .subtask && $0 == .uncontainedSubtasks)
        }
        if [.todo, .subtask, .image, .trash].contains(provider), !relevantIssues.isEmpty {
            summary.limitations.append(.taskInputConsistency)
            for issue in relevantIssues where !issues.contains(issue) { issues.append(issue) }
        }
        do {
            guard let raw = try assembly.read(provider) else { return }
            let conflicts = raw.conflictingIdentities
            let read = raw.removingConflicts(conflicts)
            read.summarize(into: &summary)
            for id in conflicts {
                summary.limitations.append(.conflictingResultIdentity(id))
                issues.append(.conflictingIdentity(provider: provider, object: id))
            }
            readings.append(read)
        } catch let error as ClipboardQueryRequestError {
            summary.limitations.append(.clipboardMode(error))
        } catch {
            summary.limitations.append(.providerState(.blocked))
        }
    }

    private static func addSources(
        _ provider: ContentQueryProviderID, assembly: ContentQueryBatchAssembly,
        summary: inout ContentQueryProviderCompleteness
    ) {
        let input = assembly.batch.snapshots
        var sources: [(CommandObjectType, ContentQuerySourceCoverage)]
        switch provider {
        case .todo: sources = [(.todo, input.todos.coverage)]
        case .subtask: sources = [(.todo, input.todos.coverage), (.subtask, input.subtasks.coverage)]
        case .routine, .routineOccurrence: sources = [(.routine, input.routines.coverage)]
        case .diary: sources = [(.diary, input.diaries.coverage)]
        case .image: sources = [(.image, input.images.coverage)]
        case .tag: sources = [(.tag, input.tags.coverage)]
        case .clipboard:
            let coverage: ContentQuerySourceCoverage
            switch input.clipboard.coverage {
            case .notProvided: coverage = .notProvided
            case .failed: coverage = .failed
            case .partial: coverage = .partial
            case .complete: coverage = .complete
            }
            sources = [(.clipboardEntry, coverage)]
        case .trash:
            sources = [(.todo, input.todos.coverage), (.subtask, input.subtasks.coverage),
                (.routine, input.routines.coverage), (.diary, input.diaries.coverage),
                (.image, input.images.coverage), (.tag, input.tags.coverage)]
                .filter { summary.requestedTypes.contains($0.0) }
        }
        summary.limitations += sources.filter { $0.1 != .complete }.map { .source($0.0, $0.1) }
        if let problem = assembly.batch.facts.routine.checkSourceProblem,
           [.routine, .routineOccurrence].contains(provider)
            || (provider == .trash && summary.requestedTypes.contains(.routine)) {
            summary.limitations.append(.checkSource(problem))
        }
    }
}
