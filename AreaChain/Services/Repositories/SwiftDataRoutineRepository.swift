import Foundation
import SwiftData

/// 习惯与例行任务 SwiftData 具体仓储实现
@MainActor
final class SwiftDataRoutineRepository: RoutineRepositoryProtocol {
    private let context: ModelContext
    private let retainedContainer: ModelContainer?

    init(context: ModelContext, container: ModelContainer? = nil) {
        self.context = context
        self.retainedContainer = container
    }

    convenience init(container: ModelContainer) {
        self.init(context: container.mainContext, container: container)
    }

    private func saveAndNotify() throws {
        try ModelChanges.commit(context)
    }

    // MARK: - 查询 (Query)

    func fetchRoutines(includeDisabled: Bool, includeDeleted: Bool) throws -> [DailyRoutine] {
        let items = try context.fetch(FetchDescriptor<DailyRoutine>())
        return items
            .filter { routine in
                if !includeDeleted && routine.deletedAt != nil { return false }
                if !includeDisabled && !routine.isEnabled { return false }
                return true
            }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func fetchRoutine(id: UUID) throws -> DailyRoutine? {
        let items = try context.fetch(FetchDescriptor<DailyRoutine>())
        return items.first { $0.id == id }
    }

    func fetchChecks(for dayKey: String) throws -> [RoutineCheck] {
        let allChecks = try context.fetch(FetchDescriptor<RoutineCheck>())
        return allChecks.filter { $0.dayKey == dayKey }
    }

    func fetchChecks(for routineID: UUID) throws -> [RoutineCheck] {
        let allChecks = try context.fetch(FetchDescriptor<RoutineCheck>())
        return allChecks.filter { $0.routine?.id == routineID }
    }

    // MARK: - 创建 (Create)

    @discardableResult
    func addRoutine(_ params: CreateRoutineParams) throws -> DailyRoutine {
        let trimmed = params.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RepositoryError.invalidArgument("习惯标题不能为空")
        }
        let routine = DailyRoutine(
            title: trimmed,
            sortOrder: params.sortOrder,
            isEnabled: true,
            createdDayKey: params.createdDayKey,
            weekdaysOnly: params.weekdaysOnly,
            weekdayMask: params.weekdayMask,
            remindMinutes: params.remindMinutes,
            projectID: params.projectID,
            tagIDs: TagIDList.encode(params.tagIDs),
            isImportant: params.isImportant,
            isUrgent: params.isUrgent,
            notes: params.notes
        )
        context.insert(routine)
        try saveAndNotify()
        return routine
    }

    // MARK: - 属性与状态变更 (Update)

    func updateRoutine(id: UUID, title: String?, notes: String?) throws {
        guard let routine = try fetchRoutine(id: id) else {
            throw RepositoryError.notFound("DailyRoutine(id: \(id))")
        }
        if let title {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw RepositoryError.invalidArgument("习惯标题不能为空")
            }
            routine.title = trimmed
        }
        if let notes {
            routine.notes = notes
        }
        try saveAndNotify()
    }

    func setRoutineEnabled(id: UUID, enabled: Bool, todayKey: String) throws {
        guard let routine = try fetchRoutine(id: id) else {
            throw RepositoryError.notFound("DailyRoutine(id: \(id))")
        }
        if enabled {
            try enableRoutineAndBridgeSkips(routine, todayKey: todayKey)
        } else {
            disableRoutine(routine, todayKey: todayKey)
        }
        try saveAndNotify()
    }

    private func enableRoutineAndBridgeSkips(_ routine: DailyRoutine, todayKey: String) throws {
        if !routine.isEnabled {
            let checks = try fetchChecks(for: routine.id)
            let start = HabitStreakLogic.skipFillStart(
                pausedOnDayKey: routine.pausedOnDayKey,
                createdDayKey: routine.createdDayKey,
                checkDayKeys: checks.compactMap { $0.routine?.id == routine.id ? $0.dayKey : nil }
            )
            bridgeSkippedDays(routine, from: start, before: todayKey, checks: checks)
        }
        routine.pausedOnDayKey = nil
        routine.isEnabled = true
    }

    private func disableRoutine(_ routine: DailyRoutine, todayKey: String) {
        if routine.pausedOnDayKey == nil {
            routine.pausedOnDayKey = todayKey
        }
        routine.isEnabled = false
    }

    private func bridgeSkippedDays(
        _ routine: DailyRoutine,
        from start: String,
        before end: String,
        checks: [RoutineCheck]
    ) {
        let mask = routine.resolvedWeekdayMask
        let checksByDay = Dictionary(grouping: checks, by: \.dayKey)
        for key in DayKey.keys(from: start, before: end) {
            guard WeekdayMask.contains(mask, dayKey: key) else { continue }
            if let existing = checksByDay[key] {
                // 取消打卡会留下 false 记录；暂停期间它也应桥接，而非恢复后变成漏打。
                guard !existing.contains(where: { $0.isDone || $0.isSkipped }) else { continue }
                for check in existing {
                    check.isDone = true
                    check.isSkipped = true
                }
            } else {
                context.insert(RoutineCheck(dayKey: key, isDone: true, isSkipped: true, routine: routine))
            }
        }
    }

    func setWeekdayMask(id: UUID, mask: Int) throws {
        guard let routine = try fetchRoutine(id: id) else {
            throw RepositoryError.notFound("DailyRoutine(id: \(id))")
        }
        routine.setWeekdayMask(mask)
        try saveAndNotify()
    }

    func setRemind(id: UUID, minutes: Int?) throws {
        guard let routine = try fetchRoutine(id: id) else {
            throw RepositoryError.notFound("DailyRoutine(id: \(id))")
        }
        routine.remindMinutes = RemindMinutes.clamped(minutes)
        try saveAndNotify()
    }

    func setPriority(id: UUID, isImportant: Bool, isUrgent: Bool) throws {
        guard let routine = try fetchRoutine(id: id) else {
            throw RepositoryError.notFound("DailyRoutine(id: \(id))")
        }
        routine.isImportant = isImportant
        routine.isUrgent = isUrgent
        try saveAndNotify()
    }

    func setProject(id: UUID, projectID: UUID?) throws {
        guard let routine = try fetchRoutine(id: id) else {
            throw RepositoryError.notFound("DailyRoutine(id: \(id))")
        }
        routine.projectID = projectID
        try saveAndNotify()
    }

    func toggleTag(id: UUID, tagID: UUID) throws {
        guard let routine = try fetchRoutine(id: id) else {
            throw RepositoryError.notFound("DailyRoutine(id: \(id))")
        }
        routine.tagIDs = TagIDList.toggling(routine.tagIDs, tagID)
        try saveAndNotify()
    }

    // MARK: - 打卡与跳过 (Check & Skip)

    func toggleRoutine(id: UUID, dayKey: String) throws {
        guard let routine = try fetchRoutine(id: id) else {
            throw RepositoryError.notFound("DailyRoutine(id: \(id))")
        }
        let checks = try fetchChecks(for: routine.id)
        if let check = checks.first(where: { $0.dayKey == dayKey }) {
            check.isDone.toggle()
            if !check.isDone {
                check.isSkipped = false
            }
        } else {
            context.insert(RoutineCheck(dayKey: dayKey, isDone: true, routine: routine))
        }
        try saveAndNotify()
    }

    func skipRoutine(id: UUID, dayKey: String) throws {
        guard let routine = try fetchRoutine(id: id) else {
            throw RepositoryError.notFound("DailyRoutine(id: \(id))")
        }
        let checks = try fetchChecks(for: routine.id)
        if let check = checks.first(where: { $0.dayKey == dayKey }) {
            check.isDone = true
            check.isSkipped = true
        } else {
            context.insert(RoutineCheck(dayKey: dayKey, isDone: true, isSkipped: true, routine: routine))
        }
        try saveAndNotify()
    }

    func batchSetRoutineChecks(ids: Set<UUID>, markDone: Bool, on dayKey: String) throws {
        guard !ids.isEmpty else { return }
        let routines = try fetchRoutines(includeDisabled: true, includeDeleted: false)
        let dayChecks = try fetchChecks(for: dayKey)
        for routine in routines where ids.contains(routine.id) {
            applyCheck(to: routine, dayKey: dayKey, markDone: markDone, existing: dayChecks)
        }
        try saveAndNotify()
    }

    private func applyCheck(
        to routine: DailyRoutine,
        dayKey: String,
        markDone: Bool,
        existing: [RoutineCheck]
    ) {
        if let check = existing.first(where: { $0.routine?.id == routine.id && $0.dayKey == dayKey }) {
            check.isDone = markDone
            check.isSkipped = false
        } else if markDone {
            context.insert(RoutineCheck(dayKey: dayKey, isDone: true, routine: routine))
        }
    }

    func batchTrashRoutines(ids: Set<UUID>) throws {
        guard !ids.isEmpty else { return }
        let now = SoftDelete.stamp()
        let attachments = try fetchOwnedAttachments()
        let routines = try fetchRoutines(includeDisabled: true, includeDeleted: false)
        for routine in routines where ids.contains(routine.id) {
            routine.deletedAt = now
            SoftDelete.stampAttachments(ownerID: routine.id, at: now, attachments: attachments, ownerKind: .routine)
        }
        try saveAndNotify()
    }

    func batchSetProject(ids: Set<UUID>, projectID: UUID?) throws {
        guard !ids.isEmpty else { return }
        let routines = try fetchRoutines(includeDisabled: true, includeDeleted: false)
        for routine in routines where ids.contains(routine.id) {
            routine.projectID = projectID
        }
        try saveAndNotify()
    }

    func batchToggleTag(ids: Set<UUID>, tagID: UUID) throws {
        guard !ids.isEmpty else { return }
        let routines = try fetchRoutines(includeDisabled: true, includeDeleted: false)
        for routine in routines where ids.contains(routine.id) {
            routine.tagIDs = TagIDList.toggling(routine.tagIDs, tagID)
        }
        try saveAndNotify()
    }

    // MARK: - 删除与恢复 (Delete & Restore)

    func deleteRoutine(id: UUID, soft: Bool) throws {
        guard let routine = try fetchRoutine(id: id) else {
            throw RepositoryError.notFound("DailyRoutine(id: \(id))")
        }
        if soft {
            let now = SoftDelete.stamp()
            routine.deletedAt = now
            SoftDelete.stampAttachments(ownerID: routine.id, at: now, attachments: try fetchOwnedAttachments(), ownerKind: .routine)
        } else {
            try purgeAttachments(ownerID: routine.id)
            context.delete(routine)
        }
        try saveAndNotify()
    }

    func restoreRoutine(id: UUID) throws {
        guard let routine = try fetchRoutine(id: id) else {
            throw RepositoryError.notFound("DailyRoutine(id: \(id))")
        }
        let stamp = routine.deletedAt
        routine.deletedAt = nil
        SoftDelete.restoreCascadedAttachments(
            ownerID: routine.id,
            parentDeletedAt: stamp,
            attachments: try fetchOwnedAttachments(),
            ownerKind: .routine
        )
        try saveAndNotify()
    }

    func purgeRoutine(id: UUID) throws {
        try deleteRoutine(id: id, soft: false)
    }

    // MARK: - 排序 (Reorder)

    func reorderRoutines(orderedIDs: [UUID]) throws {
        let routines = try fetchRoutines(includeDisabled: true, includeDeleted: false)
        for (idx, id) in orderedIDs.enumerated() {
            if let routine = routines.first(where: { $0.id == id }) {
                routine.sortOrder = idx
            }
        }
        try saveAndNotify()
    }

    func reorderRoutines(from source: IndexSet, to destination: Int) throws {
        let routines = try fetchRoutines(includeDisabled: true, includeDeleted: false)
        Catalog.reindexRoutines(routines, from: source, to: destination)
        try saveAndNotify()
    }

    // MARK: - 内部辅助 (Internal Helpers)

    private func fetchOwnedAttachments() throws -> [AttachmentItem] {
        try context.fetch(FetchDescriptor<AttachmentItem>())
    }

    private func purgeAttachments(ownerID: UUID) throws {
        let attachments = try fetchOwnedAttachments()
        for item in attachments where item.ownerID == ownerID && item.ownerKind == AttachmentOwner.routine.rawValue {
            context.delete(item)
        }
    }
}
