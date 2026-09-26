import Foundation

// 快照值与投影计算分文件，只为把单文件压到结构上限以内；二者仍是同一模块的公开契约。

struct DashboardDayStat: Equatable, Sendable {
    var dayKey: String
    var scheduledCount: Int
    var completedCount: Int
    var skippedCount: Int
    var openCount: Int
    var completionRate: Double?

    static func make(
        dayKey: String,
        scheduledCount: Int,
        completedCount: Int,
        skippedCount: Int
    ) -> DashboardDayStat {
        let scheduled = max(0, scheduledCount)
        let completed = min(max(0, completedCount), scheduled)
        let skipped = min(max(0, skippedCount), max(0, scheduled - completed))
        let open = max(0, scheduled - completed - skipped)
        let rate = scheduled == 0 ? nil : Double(completed) / Double(scheduled)
        return DashboardDayStat(
            dayKey: dayKey,
            scheduledCount: scheduled,
            completedCount: completed,
            skippedCount: skipped,
            openCount: open,
            completionRate: rate
        )
    }
}

struct DashboardSummary: Equatable, Sendable {
    var todayStat: DashboardDayStat
    var overdueCount: Int
    var upcomingCount: Int
    var recentRangeStat: DashboardDayStat
    var activeRoutineCount: Int
    var strongestCurrentStreak: Int
    var strongestBestStreak: Int
    var todayDiaryCount: Int
}

struct DashboardHeatmapDay: Equatable, Sendable, Identifiable {
    var dayKey: String
    var completedCount: Int
    var skippedCount: Int
    var scheduledCount: Int
    var intensityLevel: Int
    var isPaddingCell: Bool

    var id: String { isPaddingCell ? "pad-\(dayKey)" : dayKey }
}

enum DashboardActivityKind: String, Equatable, Sendable, CaseIterable {
    case completed
    case skipped
    case created
    case trashed
}

enum DashboardSubjectKind: String, Equatable, Sendable {
    case todo
    case routine
    case diary
}

enum DashboardActivityRoute: Equatable, Sendable {
    case inspectItem(id: UUID, dayKey: String, kind: DashboardSubjectKind)
    case diaryPage
    case trash
}

struct DashboardActivity: Equatable, Sendable, Identifiable {
    var id: String
    var kind: DashboardActivityKind
    var dayKey: String
    var subjectID: UUID
    var subjectKind: DashboardSubjectKind
    var title: String
    var titleKey: String?
    var isPrivate: Bool
    var route: DashboardActivityRoute?
}

struct DashboardSnapshot: Equatable, Sendable {
    var summary: DashboardSummary
    var trend: [DashboardDayStat]
    var heatmap: [DashboardHeatmapDay]
    var activities: [DashboardActivity]
}
