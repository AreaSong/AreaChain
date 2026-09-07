import Foundation

struct GanttTodoBar: Equatable, Identifiable {
    var id: UUID
    var title: String
    var dayKey: String
}

struct GanttRoutineMark: Equatable, Identifiable {
    var id: String { "\(routineID.uuidString)-\(dayKey)" }
    var routineID: UUID
    var title: String
    var dayKey: String
}

enum GanttLayout {
    static func todoBars(todos: [TodoSnapshot], monthKeys: Set<String>) -> [GanttTodoBar] {
        todos
            .filter { $0.deletedAt == nil && !$0.isDone && monthKeys.contains($0.dayKey) }
            .sorted {
                if $0.dayKey != $1.dayKey { return $0.dayKey < $1.dayKey }
                return $0.createdAt < $1.createdAt
            }
            .map { GanttTodoBar(id: $0.id, title: $0.title, dayKey: $0.dayKey) }
    }

    static func routineMarks(
        routines: [RoutineSnapshot],
        monthKeys: [String],
        calendar: Calendar
    ) -> [GanttRoutineMark] {
        routines
            .filter { $0.deletedAt == nil && $0.isEnabled }
            .sorted { $0.sortOrder < $1.sortOrder }
            .flatMap { routine in
                monthKeys.compactMap { key -> GanttRoutineMark? in
                    guard routine.createdDayKey <= key,
                          WeekdayMask.contains(routine.weekdayMask, dayKey: key, calendar: calendar)
                    else { return nil }
                    return GanttRoutineMark(routineID: routine.id, title: routine.title, dayKey: key)
                }
            }
    }
}
