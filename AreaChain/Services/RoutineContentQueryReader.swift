import Foundation
import SwiftData

/// 实体只在同步 MainActor 栈内投影；不保存、回滚、修复关系或调用旧打卡桥接。
@MainActor
struct RoutineContentQueryReader {
    let reads: RoutineContentQueryReads

    func readSources(into batch: inout ContentQueryBatch, observation: RoutineContentQueryObservation,
                     imageOwner: Bool = false)
        -> RoutineContentQueryReadDetails {
        var details = RoutineContentQueryReadDetails()
        if case .command = batch.session.input { return details }
        guard batch.session.isStructurallyValid,
              imageOwner || !batch.session.typeAnalysis.possibleTypes.isDisjoint(with: [.routine, .routineOccurrence])
        else { return details }
        var definitions: [DailyRoutine]?
        do {
            definitions = try reads.definitions()
            batch.snapshots.routines = .complete((definitions ?? []).map(\.snapshot))
            batch.facts.trashCoverage.types[.routine] = .completeIncludingDeleted
        } catch {
            batch.snapshots.routines = .failed
            details.issues.append(.definitionFetchFailed)
        }
        readFacts(into: &batch, definitions: definitions, observation: observation, details: &details)
        return details
    }

    /// 墓碑装配复用同一有界记录/当前观察证据，不重读定义或推测删除前历史。
    func readFacts(into batch: inout ContentQueryBatch, definitions: [DailyRoutine]?,
                   observation: RoutineContentQueryObservation, details: inout RoutineContentQueryReadDetails) {
        observe(batch: &batch, observation: observation, issues: &details.issues)
        details.requestedCoverage = RoutineContentQueryCheckPlan.coverage(in: batch, issues: &details.issues)
        guard RoutineContentQueryCheckPlan.needsRecords(in: batch, coverage: details.requestedCoverage) else { return }
        details.fetchScope = .allStoredRows
        do {
            let models = try reads.allChecks()
            let projection = RoutineContentQueryCheckProjection(models: models, definitions: definitions, dates: batch.dates)
            batch.facts.routine.checks = projection.checks
            batch.facts.routine.checkCoverage = projection.completeCoverage(details.requestedCoverage)
            if projection.globallyIncomplete { batch.facts.routine.checkSourceProblem = .incompleteUnattributedInput }
            details.rows = projection.rows
            details.issues += projection.issues
            details.checkSource = projection.issues.isEmpty && definitions != nil ? .complete : .partial
        } catch {
            details.issues.append(.checkFetchFailed)
            details.checkSource = .failed
            batch.facts.routine.checkSourceProblem = .readFailed
        }
    }

    private func observe(batch: inout ContentQueryBatch, observation: RoutineContentQueryObservation,
                         issues: inout [RoutineContentQueryReadIssue]) {
        guard observation.calendar == batch.dates.calendar else { issues.append(.observationCalendarMismatch); return }
        guard ContentQuerySnapshotValidation.validTimestamp(observation.instant, dates: batch.dates) else {
            issues.append(.invalidObservation); return
        }
        let day = DayKey.from(observation.instant, calendar: observation.calendar)
        let definitions = batch.snapshots.routines.values ?? []
        let groups = Dictionary(grouping: definitions, by: \.id)
        batch.facts.routine.scheduleEvidence = definitions.filter { groups[$0.id]?.count == 1 }.map {
            RoutineScheduleEvidence.currentDefinition($0, observedOn: day)
        }
    }
}

@MainActor
struct RoutineContentQueryCheckProjection {
    var checks: [CheckSnapshot] = []
    var rows: [RoutineContentQueryCheckRow] = []
    var issues: [RoutineContentQueryReadIssue] = []
    var restrictedIDs: Set<UUID> = []
    var globallyIncomplete = false

    init(models: [RoutineCheck], definitions: [DailyRoutine]?, dates: ContentQueryDateContext) {
        let parents = definitions.map { Dictionary(grouping: $0, by: \.id) }
        restrictedIDs = Set((parents ?? [:]).filter { $0.value.count != 1 }.keys)
        globallyIncomplete = definitions == nil
        for (index, model) in models.enumerated() {
            let value = model.snapshot
            rows.append(.init(recordID: model.id, inputIndex: index, snapshotIndex: value == nil ? nil : checks.count))
            guard let value, let parent = model.routine else {
                issues.append(.missingCheckParent(index: index))
                globallyIncomplete = true
                continue
            }
            checks.append(value)
            validateParent(parent, parents: parents, index: index)
            if !ContentQuerySnapshotValidation.validDay(value.dayKey, dates: dates) {
                issues.append(.invalidCheckDay(index: index))
                restrictedIDs.insert(value.routineId)
            }
        }
        // 记录 UUID 不是“习惯＋日期”；同业务日不同记录 UUID 保留给原归并器。
        for indices in Dictionary(grouping: models.indices, by: { models[$0].id }).values where indices.count > 1 {
            issues.append(.duplicateCheckID(indices: indices))
            for index in indices {
                if let id = models[index].routine?.id { restrictedIDs.insert(id) }
                else { globallyIncomplete = true }
            }
        }
    }

    func completeCoverage(_ requested: [RoutineCheckCoverage]) -> [RoutineCheckCoverage] {
        guard !globallyIncomplete else { return [] }
        return requested.filter { !restrictedIDs.contains($0.routineID) && !$0.completeIntervals.isEmpty }
    }

    private mutating func validateParent(_ parent: DailyRoutine, parents: [UUID: [DailyRoutine]]?, index: Int) {
        guard let parents else { issues.append(.uncheckedCheckParent(index: index)); return }
        let candidates = parents[parent.id] ?? []
        if candidates.count > 1 {
            issues.append(.ambiguousCheckParent(index: index))
            restrictedIDs.insert(parent.id)
        } else if candidates.first?.persistentModelID != parent.persistentModelID {
            issues.append(.uncontainedCheckParent(index: index))
            restrictedIDs.insert(parent.id)
        }
    }
}
