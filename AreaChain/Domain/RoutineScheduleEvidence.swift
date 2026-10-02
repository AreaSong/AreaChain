import Foundation

/// 来源性质与适用区间不可省略。recordedSchedule 仍是调用方对真实来源的映射声明，领域层不核验仓储。
struct RoutineScheduleEvidence: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    var description: String { "RoutineScheduleEvidence(redacted)" }
    var debugDescription: String { description }

    enum Source: Equatable {
        case currentDefinition(observedOn: String)
        case recordedSchedule(reference: String)
        case synthetic(reference: String)
    }
    enum Rule: Equatable { case weekdays(Int), notScheduled }

    let routineID: UUID
    let interval: ContentQueryDateInterval
    let rule: Rule
    let source: Source

    /// 当前定义只能证明明确观察日；pausedOnDayKey 不足以恢复历次启停和星期变更。
    static func currentDefinition(_ routine: RoutineSnapshot, observedOn day: String) -> Self {
        .init(routineID: routine.id, interval: .init(lowerBound: day, upperBound: day),
              rule: routine.isEnabled ? .weekdays(WeekdayMask.sanitized(routine.weekdayMask)) : .notScheduled,
              source: .currentDefinition(observedOn: day))
    }

    func isValid(calendar: Calendar) -> Bool {
        guard ContentQueryDateWindow.valid(interval, calendar: calendar) else { return false }
        if case .weekdays(let mask) = rule, mask != WeekdayMask.sanitized(mask) { return false }
        switch source {
        case .currentDefinition(let day): return interval.lowerBound == day && interval.upperBound == day
        case .recordedSchedule(let reference), .synthetic(let reference):
            return !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

enum RoutineScheduleDayState: Equatable { case scheduled, notScheduled, unknown, invalidInput }
enum RoutineScheduleReason: Equatable { case evidence, beforeCreation, missingHistory, conflictingEvidence, invalidInput }

struct RoutineScheduleDay: Equatable {
    let object: CommandObjectReference
    let state: RoutineScheduleDayState
    let reason: RoutineScheduleReason
    let evidenceIndices: [Int]
}

/// 仅组合一个定义及有界证据；不把当前字段套到过去，不把偶然存在的打卡当排程历史。
struct RoutineScheduleHistory {
    let routineID: UUID
    let createdDayKey: String
    let evidence: [RoutineScheduleEvidence]
    let dates: ContentQueryDateContext

    init(routine: RoutineSnapshot, evidence: [RoutineScheduleEvidence], dates: ContentQueryDateContext) {
        self.init(routineID: routine.id, createdDayKey: routine.createdDayKey, evidence: evidence, dates: dates)
    }

    /// 图片只提供公开的身份与创建日；历史算法不要求复制拥有者标题或构造伪快照。
    init(routineID: UUID, createdDayKey: String, evidence: [RoutineScheduleEvidence], dates: ContentQueryDateContext) {
        self.routineID = routineID
        self.createdDayKey = createdDayKey
        self.evidence = evidence
        self.dates = dates
    }

    func day(_ day: String) -> RoutineScheduleDay {
        let object = CommandObjectReference(type: .routineOccurrence, id: routineID, dayKey: day)
        guard ContentQuerySnapshotValidation.validDay(day, dates: dates), hasValidInput else {
            return .init(object: object, state: .invalidInput, reason: .invalidInput, evidenceIndices: [])
        }
        guard day >= createdDayKey else {
            return .init(object: object, state: .notScheduled, reason: .beforeCreation, evidenceIndices: [])
        }
        let indices = evidence.indices.filter {
            evidence[$0].routineID == routineID && ContentQuerySnapshotMatching.contains(evidence[$0].interval, day: day)
        }
        guard !indices.isEmpty else {
            return .init(object: object, state: .unknown, reason: .missingHistory, evidenceIndices: [])
        }
        let scheduled = indices.map { index in
            switch evidence[index].rule {
            case .weekdays(let mask): return WeekdayMask.contains(mask, dayKey: day, calendar: dates.calendar)
            case .notScheduled: return false
            }
        }
        guard let first = scheduled.first, scheduled.allSatisfy({ $0 == first }) else {
            return .init(object: object, state: .unknown, reason: .conflictingEvidence, evidenceIndices: indices)
        }
        return .init(object: object, state: first ? .scheduled : .notScheduled, reason: .evidence, evidenceIndices: indices)
    }

    var hasValidInput: Bool {
        ContentQuerySnapshotValidation.validDay(createdDayKey, dates: dates)
            && evidence.filter { $0.routineID == routineID }.allSatisfy { $0.isValid(calendar: dates.calendar) }
    }
}
