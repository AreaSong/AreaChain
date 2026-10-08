import Foundation
import SwiftData
@testable import AreaChain

/// 使用已有仓储注入点与事务失败设施，失败发生在真实模型变更之后。
@MainActor
final class RecurringToggleRepository: RoutineRepositoryProtocol {
    let context: ModelContext
    let base: SwiftDataRoutineRepository
    var afterStateWork: (() throws -> Void)?
    var fail = false
    var failRead = false
    var routineMutationContext: ModelContext? { context }
    var creations = 0
    var switches = 0
    var reminderWrites: [Int?] = []
    var reminderSaveBoundaries = 0
    var weekdayWrites: [Int] = []

    init(_ context: ModelContext) {
        self.context = context
        base = SwiftDataRoutineRepository(context: context)
    }

    func addRoutine(_ params: CreateRoutineParams) throws -> DailyRoutine {
        creations += 1
        let value = try base.addRoutine(params)
        // 新建入口已在 ModelChanges.perform 内；错误交还外层以触发原有回滚与草稿保留。
        if fail { throw CocoaError(.fileWriteNoPermission) }
        return value
    }

    func applyRoutineState(_ accepted: CommandRoutineAcceptance) throws {
        try base.applyRoutineState(accepted)
        try afterStateWork?()
    }

    func setRoutineEnabled(id: UUID, enabled: Bool, todayKey: String) throws {
        switches += 1
        try ModelChanges.transaction(in: context, save: { context in
            if self.fail { throw CocoaError(.fileWriteNoPermission) }
            try context.save()
        }) {
            try base.setRoutineEnabled(id: id, enabled: enabled, todayKey: todayKey)
        }
    }

    func fetchRoutines(includeDisabled: Bool, includeDeleted: Bool) throws -> [DailyRoutine] {
        if failRead { throw CocoaError(.fileReadUnknown) }
        return try base.fetchRoutines(includeDisabled: includeDisabled, includeDeleted: includeDeleted)
    }

    func fetchRoutine(id: UUID) throws -> DailyRoutine? {
        try base.fetchRoutine(id: id)
    }

    func fetchChecks(for dayKey: String) throws -> [RoutineCheck] {
        try base.fetchChecks(for: dayKey)
    }

    func fetchChecks(for routineID: UUID) throws -> [RoutineCheck] {
        try base.fetchChecks(for: routineID)
    }

    func updateRoutine(id: UUID, title: String?, notes: String?) throws {
        try base.updateRoutine(id: id, title: title, notes: notes)
    }

    func setWeekdayMask(id: UUID, mask: Int) throws {
        weekdayWrites.append(mask)
        try ModelChanges.transaction(in: context, save: { context in
            if self.fail { throw CocoaError(.fileWriteNoPermission) }
            try context.save()
        }) {
            try base.setWeekdayMask(id: id, mask: mask)
        }
    }

    func setRemind(id: UUID, minutes: Int?) throws {
        reminderWrites.append(minutes)
        try ModelChanges.transaction(in: context, save: { context in
            self.reminderSaveBoundaries += 1
            if self.fail { throw CocoaError(.fileWriteNoPermission) }
            try context.save()
        }) {
            try base.setRemind(id: id, minutes: minutes)
        }
    }

    func setPriority(id: UUID, isImportant: Bool, isUrgent: Bool) throws {
        try base.setPriority(id: id, isImportant: isImportant, isUrgent: isUrgent)
    }

    func toggleTag(id: UUID, tagID: UUID) throws {
        try base.toggleTag(id: id, tagID: tagID)
    }

    func replaceTagIDs(id: UUID, tagIDs: String) throws {
        try base.replaceTagIDs(id: id, tagIDs: tagIDs)
    }

    func applyParsedNotes(id: UUID, update: ParsedNoteUpdate) throws {
        try base.applyParsedNotes(id: id, update: update)
    }

    func toggleRoutine(id: UUID, dayKey: String) throws {
        try base.toggleRoutine(id: id, dayKey: dayKey)
    }

    func markRoutineDone(id: UUID, dayKey: String) throws {
        try base.markRoutineDone(id: id, dayKey: dayKey)
    }

    func skipRoutine(id: UUID, dayKey: String) throws {
        try base.skipRoutine(id: id, dayKey: dayKey)
    }

    func batchSetRoutineChecks(ids: Set<UUID>, markDone: Bool, on dayKey: String) throws {
        try base.batchSetRoutineChecks(ids: ids, markDone: markDone, on: dayKey)
    }

    func batchTrashRoutines(ids: Set<UUID>) throws {
        try base.batchTrashRoutines(ids: ids)
    }

    func batchApplyTag(ids: Set<UUID>, tagID: UUID, present: Bool) throws {
        try base.batchApplyTag(ids: ids, tagID: tagID, present: present)
    }

    func batchToggleTag(ids: Set<UUID>, tagID: UUID) throws {
        try base.batchToggleTag(ids: ids, tagID: tagID)
    }

    func deleteRoutine(id: UUID, soft: Bool) throws {
        try base.deleteRoutine(id: id, soft: soft)
    }

    func restoreRoutine(id: UUID) throws {
        try base.restoreRoutine(id: id)
    }

    func purgeRoutine(id: UUID) throws {
        try base.purgeRoutine(id: id)
    }

    func reorderRoutines(orderedIDs: [UUID]) throws {
        try base.reorderRoutines(orderedIDs: orderedIDs)
    }

    func reorderRoutines(from source: IndexSet, to destination: Int) throws {
        try base.reorderRoutines(from: source, to: destination)
    }
}
