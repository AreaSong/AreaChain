import Foundation

/// 热力格悬停用的已完成标题。跳过不算完成，私密手记不进入总览热力图。
enum DashboardCompletionTitles {
    static let previewLimit = 8

    static func previews(
        todos: [TodoSnapshot],
        routines: [RoutineSnapshot],
        marks: [UUID: [String: DashboardMark]]
    ) -> [String: [String]] {
        var titles: [String: [String]] = [:]
        func append(_ day: String, _ title: String) {
            var list = titles[day] ?? []
            guard list.count < previewLimit else { return }
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            list.append(trimmed)
            titles[day] = list
        }
        for todo in todos where todo.deletedAt == nil && todo.isDone {
            append(todo.dayKey, todo.title)
        }
        for routine in routines where routine.deletedAt == nil {
            let doneDays = (marks[routine.id] ?? [:]).filter { $0.value == .done }.map(\.key).sorted()
            for day in doneDays {
                append(day, routine.title)
            }
        }
        return titles
    }
}
