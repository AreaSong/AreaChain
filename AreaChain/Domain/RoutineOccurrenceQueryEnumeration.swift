import Foundation

/// 有界、同步、局部读取投影。预算为输入个数、估算读取工作单位及实际返回行数，均不持久化。
struct RoutineOccurrenceQueryEnumeration {
    let request: RoutineOccurrenceQueryRequest
    var response: RoutineOccurrenceQueryResponse
    private var limit: RoutineOccurrenceQueryIssue?

    init(request: RoutineOccurrenceQueryRequest, response: RoutineOccurrenceQueryResponse) {
        self.request = request
        self.response = response
    }

    private var window: ContentQueryDateWindow { response.coverage.window!.effective }
    private var dates: ContentQueryDateContext { request.session.queryDates }

    mutating func run() {
        guard acceptsInput() else {
            response.coverage.unprocessed.append(.init(routine: nil, window: window, reason: .inputLimit))
            response.diagnostics.append(.init(issue: .inputLimit))
            return
        }
        response.coverage.didEnumerate = true
        if request.definitionCoverage != .complete { response.diagnostics.append(.init(issue: .definitionsIncomplete)) }
        let positions = Dictionary(grouping: request.routines.indices, by: { request.routines[$0].id })
        readUnattributed(positions)
        for (index, routine) in request.routines.enumerated() {
            let indices = positions[routine.id] ?? []
            guard indices.first == index else { continue }
            if indices.count > 1 {
                response.diagnostics.append(.init(issue: .duplicateRoutineID,
                    object: .init(type: .routine, id: routine.id), inputIndices: indices))
                addWholeWindowGap(routine.id, reason: .ambiguousDefinition)
                continue
            }
            guard routine.deletedAt == nil else { continue }
            let input = RoutineOccurrenceQueryInput(request, routine: routine)
            enumerate(input)
        }
        if let limit { response.diagnostics.append(.init(issue: limit)) }
    }

    private func acceptsInput() -> Bool {
        // 先检查外层计数，再展开区间/条件，避免为拒绝的请求构造大索引。
        let sizes = [request.routines.count, request.checks.count, request.checkCoverage.count,
                     request.scheduleEvidence.count, request.session.conditions.count, window.intervals.count,
                     request.browseWindow?.intervals.count ?? 0]
        var remaining = request.budget.maxInputItems
        for size in sizes {
            guard size <= remaining else { return false }
            remaining -= size
        }
        for coverage in request.checkCoverage {
            guard coverage.completeIntervals.count <= remaining else { return false }
            remaining -= coverage.completeIntervals.count
        }
        for condition in request.session.conditions {
            if case .clause(let terms) = condition.value {
                guard terms.count <= remaining else { return false }
                remaining -= terms.count
            }
        }
        return true
    }

    private mutating func takeWork(_ cost: Int) -> Bool {
        guard limit == nil else { return false }
        guard cost <= request.budget.maxWork - response.coverage.workUsed else {
            limit = .workLimit
            return false
        }
        response.coverage.workUsed += cost
        return true
    }

    private mutating func takeRow() -> Bool {
        guard response.coverage.resultRowsUsed < request.budget.maxResults else {
            limit = .resultLimit
            return false
        }
        response.coverage.resultRowsUsed += 1
        return true
    }

    private mutating func enumerate(_ input: RoutineOccurrenceQueryInput) {
        guard takeWork(input.readCost) else { leaveRemainder(input.object, from: nil); return }
        if !ContentQuerySnapshotValidation.validDay(input.routine.createdDayKey, dates: dates) {
            response.diagnostics.append(.init(issue: .invalidCreatedDay, object: input.object))
        }
        if !input.history.hasValidInput {
            response.diagnostics.append(.init(issue: .invalidScheduleEvidence, object: input.object))
        }
        if !input.hasValidRecords {
            addWholeWindowGap(input.routine.id, reason: .invalidRecordInput)
            if let day = window.intervals.first?.lowerBound { appendDiagnostics(input.read(day).records) }
        }
        for interval in window.intervals {
            guard takeWork(input.readCost) else { leaveRemainder(input.object, from: interval.lowerBound); return }
            let segments = input.history.hasValidInput ? input.history.segments(in: interval) : [interval]
            for segment in segments {
                guard takeWork(input.readCost) else { leaveRemainder(input.object, from: segment.lowerBound); return }
                for part in input.splitCoverage(segment) {
                    guard enumerate(part, input: input) else { return }
                }
            }
        }
    }

    private mutating func enumerate(_ interval: ContentQueryDateInterval, input: RoutineOccurrenceQueryInput) -> Bool {
        guard takeWork(7 * input.readCost) else { leaveRemainder(input.object, from: interval.lowerBound); return false }
        let pattern = RoutineOccurrenceQueryPattern.read(interval, history: input.history)
        for (reason, mask) in pattern.unknown {
            response.coverage.gaps.append(.init(routine: input.object, interval: interval,
                                               weekdayMask: mask, reason: .schedule(reason)))
        }
        let complete = input.coverage.covers(interval, calendar: dates.calendar) && input.hasValidRecords
        if !complete {
            response.coverage.gaps.append(.init(routine: input.object, interval: interval,
                                               weekdayMask: WeekdayMask.all, reason: .recordsIncomplete))
        }
        let actual = Set(input.checks.filter {
            ContentQuerySnapshotValidation.validDay($0.dayKey, dates: dates)
                && ContentQuerySnapshotMatching.contains(interval, day: $0.dayKey)
        }.map(\.dayKey)).sorted()
        var actualIndex = 0
        var due = complete ? pattern.nextScheduled(from: interval.lowerBound, through: interval.upperBound, calendar: dates.calendar) : nil
        while due != nil || actualIndex < actual.count {
            let observed = actualIndex < actual.count ? actual[actualIndex] : nil
            let day = [due, observed].compactMap { $0 }.min()!
            guard read(day, input: input) else { leaveRemainder(input.object, from: day); return false }
            if observed == day { actualIndex += 1 }
            if due == day {
                let next = day < interval.upperBound ? DayKey.shifted(day, by: 1, calendar: dates.calendar) : nil
                due = pattern.nextScheduled(from: next, through: interval.upperBound, calendar: dates.calendar)
            }
        }
        return true
    }

    private mutating func read(_ day: String, input: RoutineOccurrenceQueryInput) -> Bool {
        guard takeWork(input.readCost) else { return false }
        let occurrence = input.read(day)
        let status: ContentQueryStatus?
        switch occurrence.state {
        case .open: status = .open
        case .done: status = .done
        case .skipped: status = .skipped
        default: status = nil
        }
        if let status {
            if let evidence = RoutineOccurrenceQueryMatching.evidence(session: request.session, occurrence: occurrence) {
                guard takeRow() else { return false }
                response.matches.append(.init(id: occurrence.records.object, routine: input.object, routineTitle: input.routine.title,
                    status: status, source: occurrence.records.state == .absent ? .derivedUnprocessed : .existingRecords,
                    occurrence: occurrence, evidence: evidence))
            }
        } else {
            guard takeRow() else { return false }
            response.reviewRecords.append(.init(id: occurrence.records.object, kind: reviewKind(occurrence),
                                                records: occurrence.records, schedule: occurrence.schedule))
        }
        appendDiagnostics(occurrence.records)
        return true
    }

    private func reviewKind(_ occurrence: RoutineOccurrenceEvaluation) -> RoutineOccurrenceReviewKind {
        // 非应执行与记录冲突可同时存在；kind 保留异常类别，records 仍完整保留冲突诊断。
        if occurrence.schedule.state == .notScheduled { return .notScheduled }
        if occurrence.records.state == .conflict { return .conflict }
        return occurrence.state == .invalidInput ? .invalidInput : .unknown
    }

    private mutating func appendDiagnostics(_ read: RoutineCheckRead) {
        response.diagnostics += read.diagnostics.map {
            .init(issue: .check($0), severity: $0.affectsDetermination ? .error : .warning,
                  affectsDetermination: $0.affectsDetermination, object: read.object, inputIndices: read.inputIndices)
        }
    }

    private mutating func leaveRemainder(_ routine: CommandObjectReference, from day: String?) {
        let intervals = window.intervals.compactMap { interval -> ContentQueryDateInterval? in
            guard let day else { return interval }
            return interval.intersection(.init(lowerBound: day, upperBound: "9999-12-31"))
        }
        let remaining = ContentQueryDateWindow(intervals: intervals, calendar: dates.calendar)!
        response.coverage.unprocessed.append(.init(routine: routine, window: remaining, reason: limit ?? .workLimit))
    }

    private mutating func addWholeWindowGap(_ id: UUID, reason: RoutineOccurrenceQueryGap.Reason) {
        response.coverage.gaps += window.intervals.map {
            .init(routine: .init(type: .routine, id: id), interval: $0, weekdayMask: WeekdayMask.all, reason: reason)
        }
    }

    private mutating func readUnattributed(_ positions: [UUID: [Int]]) {
        let indices = request.checks.indices.filter {
            let owners = positions[request.checks[$0].routineId] ?? []
            return owners.count != 1
        }
        let groups = Dictionary(grouping: indices) {
            CommandObjectReference(type: .routineOccurrence, id: request.checks[$0].routineId, dayKey: request.checks[$0].dayKey)
        }
        for index in indices {
            let check = request.checks[index]
            let object = CommandObjectReference(type: .routineOccurrence, id: check.routineId, dayKey: check.dayKey)
            guard groups[object]?.first == index else { continue }
            guard ContentQuerySnapshotValidation.validDay(check.dayKey, dates: dates) else {
                response.diagnostics.append(.init(issue: .check(.invalidRecordDay), inputIndices: groups[object] ?? []))
                response.coverage.hasUnattributedRecords = true
                response.coverage.unattributedRecordsAreComplete = false
                continue
            }
            guard window.contains(check.dayKey) else { continue }
            guard takeWork(request.checks.count + 1), takeRow() else {
                response.coverage.unprocessedCheckIndices += groups[object] ?? []
                continue
            }
            let coverage = RoutineCheckCoverage(routineID: check.routineId, completeIntervals: request.checkCoverage.filter {
                $0.routineID == check.routineId
            }.flatMap(\.completeIntervals))
            let read = RoutineCheckReading.read(routineID: check.routineId, on: check.dayKey, checks: request.checks,
                                                 coverage: coverage, dates: dates)
            response.coverage.hasUnattributedRecords = true
            response.coverage.unattributedRecordsAreComplete = response.coverage.unattributedRecordsAreComplete && read.isComplete
            response.reviewRecords.append(.init(id: object, kind: .unattributed, records: read, schedule: nil))
            let issue: RoutineOccurrenceQueryIssue = positions[check.routineId] == nil ? .missingRoutine : .duplicateRoutineID
            response.diagnostics.append(.init(issue: issue, object: object, inputIndices: read.inputIndices))
            appendDiagnostics(read)
        }
    }
}
