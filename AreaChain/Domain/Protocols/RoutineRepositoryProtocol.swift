import Foundation
import SwiftData

/// 常驻习惯创建参数 DTO
struct CreateRoutineParams: Sendable {
    var title: String
    var sortOrder: Int
    var weekdayMask: Int?
    var weekdaysOnly: Bool
    var remindMinutes: Int?
    var projectID: UUID?
    var tagIDs: [UUID]
    var isImportant: Bool
    var isUrgent: Bool
    var notes: String
    var createdDayKey: String

    init(
        title: String,
        sortOrder: Int = 0,
        weekdayMask: Int? = nil,
        weekdaysOnly: Bool = false,
        remindMinutes: Int? = nil,
        projectID: UUID? = nil,
        tagIDs: [UUID] = [],
        isImportant: Bool = false,
        isUrgent: Bool = false,
        notes: String = "",
        createdDayKey: String = DayKey.today()
    ) {
        self.title = title
        self.sortOrder = sortOrder
        self.weekdayMask = weekdayMask
        self.weekdaysOnly = weekdaysOnly
        self.remindMinutes = remindMinutes
        self.projectID = projectID
        self.tagIDs = tagIDs
        self.isImportant = isImportant
        self.isUrgent = isUrgent
        self.notes = notes
        self.createdDayKey = createdDayKey
    }
}

/// 习惯与例行任务数据访问与打卡契约
@MainActor
protocol RoutineRepositoryProtocol: AnyObject {
    // MARK: - 查询 (Query)
    /// 获取例行习惯列表（支持筛选停用与删除项）
    func fetchRoutines(includeDisabled: Bool, includeDeleted: Bool) throws -> [DailyRoutine]

    /// 获取全部活跃习惯（默认便捷方法）
    func fetchRoutines() throws -> [DailyRoutine]

    /// 按唯一标识查询习惯
    func fetchRoutine(id: UUID) throws -> DailyRoutine?

    /// 查询指定日期的所有打卡记录
    func fetchChecks(for dayKey: String) throws -> [RoutineCheck]

    /// 查询指定习惯的历史全部打卡记录
    func fetchChecks(for routineID: UUID) throws -> [RoutineCheck]

    // MARK: - 创建 (Create)
    /// 基于结构化参数创建习惯
    @discardableResult
    func addRoutine(_ params: CreateRoutineParams) throws -> DailyRoutine

    /// 便捷多参数重载（满足 PROJECT.md 规范）
    @discardableResult
    func addRoutine(
        title: String,
        sortOrder: Int?,
        weekdayMask: Int?,
        remindMinutes: Int?,
        projectID: UUID?,
        tagIDs: [UUID]?,
        priority: (isImportant: Bool, isUrgent: Bool)?,
        notes: String?
    ) throws -> DailyRoutine

    // MARK: - 属性与状态变更 (Update)
    /// 更新习惯基本信息
    func updateRoutine(id: UUID, title: String?, notes: String?) throws

    /// 启用/停用习惯（启用时自动执行断签跳过桥接）
    func setRoutineEnabled(id: UUID, enabled: Bool, todayKey: String) throws

    /// 更新习惯重复星期掩码
    func setWeekdayMask(id: UUID, mask: Int) throws

    /// 设置提醒分钟偏移
    func setRemind(id: UUID, minutes: Int?) throws

    /// 设置四象限优先级
    func setPriority(id: UUID, isImportant: Bool, isUrgent: Bool) throws

    /// 变更所属项目
    func setProject(id: UUID, projectID: UUID?) throws

    /// 切换关联标签
    func toggleTag(id: UUID, tagID: UUID) throws

    // MARK: - 打卡与跳过 (Check & Skip)
    /// 切换指定日期的打卡完成状态
    func toggleRoutine(id: UUID, dayKey: String) throws

    /// 将指定日期的习惯标记为已跳过（保留连续打卡桥接）
    func skipRoutine(id: UUID, dayKey: String) throws

    // MARK: - 批量操作 (Batch Operations)
    /// 批量设置打卡状态
    func batchSetRoutineChecks(ids: Set<UUID>, markDone: Bool, on dayKey: String) throws

    /// 批量软删除习惯
    func batchTrashRoutines(ids: Set<UUID>) throws

    /// 批量设置所属项目
    func batchSetProject(ids: Set<UUID>, projectID: UUID?) throws

    /// 批量切换标签关联
    func batchToggleTag(ids: Set<UUID>, tagID: UUID) throws

    // MARK: - 删除与恢复 (Delete & Restore)
    /// 删除习惯：soft=true 软删除；soft=false 彻底删除
    func deleteRoutine(id: UUID, soft: Bool) throws

    /// 恢复已软删除的习惯
    func restoreRoutine(id: UUID) throws

    /// 彻底物理清除习惯及打卡关联
    func purgeRoutine(id: UUID) throws

    // MARK: - 排序 (Reorder)
    /// 按 ID 序列重排习惯顺序
    func reorderRoutines(orderedIDs: [UUID]) throws

    /// 按 IndexSet 重排习惯顺序
    func reorderRoutines(from source: IndexSet, to destination: Int) throws

    // MARK: - 连续打卡计算集成 (Streak Calculation)
    /// 根据习惯 ID 实时计算当前连续打卡与最佳打卡成绩
    func calculateStreak(for routineID: UUID, todayKey: String, calendar: Calendar) throws -> StreakResult

    /// 根据习惯实体实时计算当前连续打卡与最佳打卡成绩
    func calculateStreak(for routine: DailyRoutine, todayKey: String, calendar: Calendar) throws -> StreakResult
}

extension RoutineRepositoryProtocol {
    func batchTrashRoutines(ids: Set<UUID>) throws {
        for id in ids {
            try? deleteRoutine(id: id, soft: true)
        }
    }

    func batchSetProject(ids: Set<UUID>, projectID: UUID?) throws {
        for id in ids {
            try? setProject(id: id, projectID: projectID)
        }
    }

    func batchToggleTag(ids: Set<UUID>, tagID: UUID) throws {
        for id in ids {
            try? toggleTag(id: id, tagID: tagID)
        }
    }

    func fetchRoutines() throws -> [DailyRoutine] {
        try fetchRoutines(includeDisabled: true, includeDeleted: false)
    }

    func calculateStreak(
        for routine: DailyRoutine,
        todayKey: String,
        calendar: Calendar = .current
    ) throws -> StreakResult {
        let checks = try fetchChecks(for: routine.id)
        return HabitStreakLogic.calculate(
            routine: routine.snapshot,
            checks: checks.compactMap(\.snapshot),
            todayKey: todayKey,
            calendar: calendar
        )
    }

    func calculateStreak(
        for routineID: UUID,
        todayKey: String,
        calendar: Calendar = .current
    ) throws -> StreakResult {
        guard let routine = try fetchRoutine(id: routineID) else {
            return StreakResult(currentStreak: 0, bestStreak: 0)
        }
        return try calculateStreak(for: routine, todayKey: todayKey, calendar: calendar)
    }

    func addRoutine(
        title: String,
        sortOrder: Int? = nil,
        weekdayMask: Int? = nil,
        remindMinutes: Int? = nil,
        projectID: UUID? = nil,
        tagIDs: [UUID]? = nil,
        priority: (isImportant: Bool, isUrgent: Bool)? = nil,
        notes: String? = nil
    ) throws -> DailyRoutine {
        let params = CreateRoutineParams(
            title: title,
            sortOrder: sortOrder ?? 0,
            weekdayMask: weekdayMask,
            remindMinutes: remindMinutes,
            projectID: projectID,
            tagIDs: tagIDs ?? [],
            isImportant: priority?.isImportant ?? false,
            isUrgent: priority?.isUrgent ?? false,
            notes: notes ?? ""
        )
        return try addRoutine(params)
    }
}
