import Foundation

/// 看板闭合索引：同一 `(routineId, dayKey)` 只保留**第一条**打卡。
/// 后写的完成/跳过不能覆盖先写的未闭合。待处理逾期用「任一条闭合」，不能共用这张表。
struct DayBoardCheckIndex: Equatable {
    private let firstByRoutineDay: [UUID: [String: CheckSnapshot]]

    init(_ checks: [CheckSnapshot]) {
        var map: [UUID: [String: CheckSnapshot]] = [:]
        for check in checks {
            var days = map[check.routineId] ?? [:]
            if days[check.dayKey] == nil {
                days[check.dayKey] = check
                map[check.routineId] = days
            }
        }
        firstByRoutineDay = map
    }

    func mark(routineId: UUID, dayKey: String) -> CheckSnapshot? {
        firstByRoutineDay[routineId]?[dayKey]
    }

    func isClosed(routineId: UUID, dayKey: String) -> Bool {
        guard let mark = firstByRoutineDay[routineId]?[dayKey] else { return false }
        return mark.isDone || mark.isSkipped
    }

    func isSkipped(routineId: UUID, dayKey: String) -> Bool {
        firstByRoutineDay[routineId]?[dayKey]?.isSkipped == true
    }
}
