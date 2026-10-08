import Foundation

struct RoutineQueryMatching {
    typealias Result = RoutineQueryEvaluationResult
    let request: RoutineQueryRequest
    let routine: RoutineSnapshot
    let existence: RoutineScheduleExistence?
    let occurrence: RoutineOccurrenceEvaluation?
    let images: ContentQueryImageRead

    init(request: RoutineQueryRequest, routine: RoutineSnapshot, images: ContentQueryImageRead) {
        self.request = request
        self.routine = routine
        self.images = images
        let history = RoutineScheduleHistory(routine: routine, evidence: request.scheduleEvidence, dates: request.session.queryDates)
        if case .window(let window) = ContentQueryDateWindow.resolve(request.session.conditions, dates: request.session.queryDates) {
            existence = history.existence(in: window)
        } else { existence = nil }
        if case .selected(let day) = request.session.occurrenceDay {
            let coverage = RoutineQueryPageRules.coverage(request, routineID: routine.id)
            occurrence = .init(schedule: history.day(day), records: RoutineCheckReading.read(
                routineID: routine.id, on: day, checks: request.checks, coverage: coverage, dates: request.session.queryDates))
        } else { occurrence = nil }
    }

    func evaluate() -> Result {
        var values = request.session.conditions.map(match)
        // 范围的启停约束来自 composition；不是页面名或 source 的猜测。
        let allowed = request.session.composition?.routines != .enabledOnly || routine.isEnabled
        values.append(.init(truth: allowed ? .matches : .doesNotMatch))
        return Result.combine(values, any: false)
    }

    private func match(_ condition: ContentQueryCondition) -> Result {
        switch condition.value {
        case .scope: return .known(true, id: condition.id, field: .scope)
        case .page(let predicate): return page(predicate, id: condition.id)
        case .clause(let terms):
            let values = terms.enumerated().map { index, term in
                var result = termMatch(term, id: condition.id)
                result.evidence = result.evidence.map { item in
                    var item = item
                    item.alternativeIndex = index
                    return item
                }
                return result
            }
            return Result.combine(values, any: true)
        }
    }

    private func termMatch(_ term: ContentQuerySemanticTerm, id: ContentQueryConditionID) -> Result {
        switch term.atom {
        case .text(let needle, _):
            let evidence = ContentQuerySnapshotMatching.text(needle, excluded: term.excluded,
                                                            fields: [(.title, routine.title), (.notes, routine.notes)], id: id)
            return .init(truth: evidence == nil ? .doesNotMatch : .matches, evidence: evidence ?? [])
        case .tag(let name): return tag(name, excluded: term.excluded, id: id)
        case .priority(let flags):
            return .known(routine.isImportant == flags.isImportant && routine.isUrgent == flags.isUrgent, id: id, field: .priority)
        case .reminder(let minutes): return .known(routine.remindMinutes == minutes, id: id, field: .reminder)
        case .created(let interval):
            return .known(ContentQuerySnapshotMatching.contains(interval, day: DayKey.from(
                routine.createdAt, calendar: request.session.queryDates.calendar)), id: id, field: .createdAt)
        case .date(let interval): return date(interval, id: id)
        case .on: return on(id: id, status: nil)
        case .status(let status): return on(id: id, status: status)
        case .image: return images.evaluate(owner: .init(kind: .routine, id: routine.id), conditionID: id).routine
        }
    }

    private func tag(_ name: String, excluded: Bool, id: ContentQueryConditionID) -> Result {
        guard let names = request.tagNames else { return .unknown(.missingTagNames, id: id) }
        let missing = TagIDList.normalized(TagIDList.parse(routine.tagIDs)).filter { names[$0] == nil }
        guard missing.isEmpty else {
            return .init(truth: .unknown, diagnostics: missing.map {
                .init(issue: .missingAssociatedTagName($0), conditionIDs: [id])
            })
        }
        let evidence = ContentQuerySnapshotMatching.tag(name, excluded: excluded, tagIDs: routine.tagIDs,
                                                        normalizedNames: names.mapValues(TagSyntax.normalizedName), id: id)
        return .init(truth: evidence == nil ? .doesNotMatch : .matches, evidence: evidence ?? [])
    }

    private func date(_ interval: ContentQueryDateInterval, id: ContentQueryConditionID) -> Result {
        guard let existence else { return .unknown(.invalidScheduleEvidence, id: id) }
        var result = Result(truth: existence.truth)
        if existence.truth == .invalidInput { result.diagnostics.append(.init(issue: .invalidScheduleEvidence, conditionIDs: [id])) }
        if !existence.intervalsContainingUnknownDays.isEmpty {
            result.diagnostics.append(.init(issue: .uncertainSchedule, severity: .warning, conditionIDs: [id]))
        }
        result.diagnostics += existence.unknownReasons.map {
            .init(issue: .schedule($0), severity: .warning, conditionIDs: [id])
        }
        if let day = existence.witnessDay {
            // 每个 date 组只为包含同一最终见证日的分支提供证据。
            return ContentQuerySnapshotMatching.contains(interval, day: day)
                ? .init(truth: .matches, evidence: [.init(conditionID: id, field: .scheduleExistence)], diagnostics: result.diagnostics)
                : .init(truth: .doesNotMatch, diagnostics: result.diagnostics)
        }
        return result
    }

    private func on(id: ContentQueryConditionID, status: ContentQueryStatus?) -> Result {
        guard let occurrence else { return .unknown(.missingOccurrenceDay, id: id) }
        let truth: RoutineQueryTruth
        if let status { truth = occurrence.matching(status) }
        else {
            switch occurrence.schedule.state {
            case .scheduled: truth = .matches
            case .notScheduled: truth = .doesNotMatch
            case .unknown: truth = .unknown
            case .invalidInput: truth = .invalidInput
            }
        }
        var result = Result(truth: truth, evidence: truth == .matches
                            ? [.init(conditionID: id, field: status == nil ? .occurrenceDay : .completion)] : [])
        if occurrence.schedule.state == .unknown {
            result.diagnostics.append(.init(issue: .schedule(occurrence.schedule.reason), conditionIDs: [id]))
        }
        if occurrence.schedule.state == .invalidInput {
            result.diagnostics.append(.init(issue: .invalidScheduleEvidence, conditionIDs: [id]))
        }
        // on 单独只要求应执行，读取诊断仍保留，但记录不足不改变纯排程条件。
        result.diagnostics += occurrence.records.diagnostics.map {
            .init(issue: .check($0), severity: $0.affectsDetermination ? .error : .warning,
                  affectsDetermination: $0.affectsDetermination, conditionIDs: [id],
                  inputIndices: occurrence.records.inputIndices)
        }
        return result
    }

    private func page(_ predicate: ContentQueryPagePredicate, id: ContentQueryConditionID) -> Result {
        switch predicate {
        case .boardDate(let scope, let rule):
            return RoutineQueryPageRules.date(scope, rule: rule, request: request, routine: routine, id: id)
        case .tagID(let tagID, _):
            var result = Result.known(TagIDList.contains(routine.tagIDs, tagID), id: id, field: .tags)
            result.evidence = result.evidence.map { item in
                var item = item
                item.relatedObject = .init(type: .tag, id: tagID)
                return item
            }
            return result
        case .noTags:
            var result = Result.known(TagIDList.parse(routine.tagIDs).isEmpty, id: id, field: .tags)
            result.evidence = result.evidence.map { item in
                var item = item
                item.kind = .absence
                return item
            }
            return result
        case .taskPriority(let priority): return .known(Classification.matches(routine.classifyBits, filter: priority.filter),
                                                        id: id, field: .priority)
        case .sourceApplication(let bundle): return .known(Classification.matches(routine.classifyBits, filter: .init(bundleID: bundle)),
                                                           id: id, field: .sourceApplication)
        case .reminderPresence(let scope): return .known(Classification.matchesReminder(routine.remindMinutes, scope: scope),
                                                        id: id, field: .reminder)
        case .contentTypes(let types): return .known(types.contains(.routine), id: id, field: .objectType)
        case .todoStatus:
            return .init(truth: .matches, evidence: [.init(conditionID: id, field: .objectType, kind: .typeNeutral)])
        case .itemKind(let kind): return listed(kind: kind, id: id)
        case .routineStatus(let status): return listed(status: status, id: id)
        }
    }

    private func listed(kind: ItemKindScope = .all, status: RoutineStatusScope = .all, id: ContentQueryConditionID) -> Result {
        let query = ItemsListingQuery(kind: kind, routineStatus: status, todayKey: request.session.queryDates.todayKey)
        return .known(!ItemsListing.routines([routine], checks: [], query: query,
                                            calendar: request.session.queryDates.calendar).isEmpty,
                      id: id, field: status == .all ? .objectType : .routineEnabled)
    }
}
