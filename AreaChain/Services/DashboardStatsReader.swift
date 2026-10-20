import Foundation
import SwiftData

/// 合并批 M-3 B：总览投影的唯一取数入口。总览页（@Query 的同一组模型）与统计指令（显式上下文读取）都经这里
/// 调 DashboardProjection，私密手记按 diarySource 的同一口径去掉正文并计为私密，不另算、不额外暴露。
enum DashboardStatsReader {
    static func snapshot(todos: [TodoItem], routines: [DailyRoutine], checks: [RoutineCheck], diaries: [DiaryEntry],
                         tags: [TagItem], todayKey: String, calendar: Calendar = .current) -> DashboardSnapshot {
        DashboardProjection.project(
            todos: todos.map(\.snapshot),
            routines: routines.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            diaries: diaries.map { DashboardProjection.diarySource($0.snapshot, tags: tags) },
            todayKey: todayKey,
            calendar: calendar
        )
    }

    /// 只读：与总览页的无条件 @Query 取同一全集。
    static func read(context: ModelContext, todayKey: String, calendar: Calendar = .current) throws -> DashboardSnapshot {
        snapshot(todos: try context.fetch(FetchDescriptor<TodoItem>()),
                 routines: try context.fetch(FetchDescriptor<DailyRoutine>()),
                 checks: try context.fetch(FetchDescriptor<RoutineCheck>()),
                 diaries: try context.fetch(FetchDescriptor<DiaryEntry>()),
                 tags: try context.fetch(FetchDescriptor<TagItem>()),
                 todayKey: todayKey, calendar: calendar)
    }
}

extension DashboardActivity {
    /// 活动行的显示标题：私密项只有占位文案键，与总览页活动区同一规则。
    func displayTitle(locale: Locale) -> String {
        titleKey.map { L10n.string(String.LocalizationValue($0), locale: locale) } ?? title
    }
}

extension DashboardActivityKind {
    /// 活动类型文案键；总览活动区与 stats.activity 共用。
    var titleKey: String {
        switch self {
        case .completed: "dashboard.activity.kind.completed"
        case .skipped: "dashboard.activity.kind.skipped"
        case .created: "dashboard.activity.kind.created"
        case .trashed: "dashboard.activity.kind.trashed"
        }
    }
}
