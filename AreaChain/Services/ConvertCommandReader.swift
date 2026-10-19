import Foundation
import SwiftData

/// 只读核验 T8 转换目标与随之变化的子任务、附件、打卡记录；不调用任何写入口。
/// 损失清单取自 ItemConversionService 与写入共用的同一组规则（活子任务、模板顺序、星期）。
@MainActor final class ConvertCommandReader {
    unowned let environment: BatchCommandEnvironment
    let clock: ItemConversionService.Clock

    init(environment: BatchCommandEnvironment, clock: ItemConversionService.Clock) {
        self.environment = environment
        self.clock = clock
    }

    func prepare(in host: CommandOwnedHost) throws -> CommandConvertPreview {
        let item = try CommandConvertPreview.input(in: host)
        return try read(item, lease: host.lease, plan: host.session.plan.stamp)
    }

    /// 预览后对象被改、被删、连带集合变化或跨日，都拒绝并要求重新预览。
    func validate(_ preview: CommandConvertPreview, item: CommandPlanItem) throws {
        guard preview.semanticsVersion == 1, preview.environmentID == environment.id,
              preview.contextID == ObjectIdentifier(environment.context),
              preview.storageID == ObjectIdentifier(environment.context.container),
              item.stamp == preview.item, item.draft.stamp == preview.draft,
              item.draft.targets == preview.targets else { throw CommandConvertIssue.stale }
        let current = try read(item, lease: preview.lease, plan: preview.plan)
        guard current.edit == preview.edit, current.impact.target == preview.impact.target else {
            throw CommandConvertIssue.stale
        }
        guard current.impact == preview.impact else { throw CommandConvertIssue.invalidTarget(.changed) }
    }

    func read(_ item: CommandPlanItem, lease: CommandHostLease, plan: CommandPlanStamp) throws -> CommandConvertPreview {
        try CommandConvertPreview.validate(item)
        let edit = try CommandConvertEdit(command: item.draft.commandID)
        let targets = item.draft.targets
        let target = targets.objects[0]
        try environment.validateClean()
        let source = try qualification(target)
        let impact = edit == .todoToRoutine ? try todoImpact(target, source: source) : try routineImpact(target, source: source)
        // 来源回调可能重入；整次采样后再核对一次来源资格。
        guard try qualification(target) == source else { throw CommandConvertIssue.stale }
        try environment.validateClean()
        return CommandConvertPreview(lease: lease, plan: plan, item: item.stamp, draft: item.draft.stamp, targets: targets,
            edit: edit, environmentID: environment.id, contextID: ObjectIdentifier(environment.context),
            storageID: ObjectIdentifier(environment.context.container), impact: impact)
    }

    /// 沿 B-M1／T-M4 的“普通无备注”门槛：来源 ordinary、声明无备注，且真实备注为空。
    private func qualification(_ target: CommandObjectReference) throws -> CommandTaskTitleEligibility {
        let source: CommandTaskTitleEligibility
        do { source = try environment.source(target) } catch { throw CommandConvertIssue.invalidTarget(.source) }
        guard source.protection == .ordinary else { throw CommandConvertIssue.invalidTarget(.protectedContent) }
        guard source.notes == .absent else { throw CommandConvertIssue.invalidTarget(.notes) }
        return source
    }

    private func todoImpact(_ target: CommandObjectReference, source: CommandTaskTitleEligibility) throws -> CommandConvertImpact {
        let todo = try live(SwiftDataTaskRepository(context: environment.context).fetchTodos(withID: target.id),
                            deleted: \.deletedAt)
        guard TaskCopyContent.notes(todo.notes) == nil else { throw CommandConvertIssue.invalidTarget(.notes) }
        let children = ItemConversionService.liveSubtasks(of: todo)
        let family: [SubtaskItem]
        do { family = try TaskFamilyCommandIdentity.children(of: todo, in: environment.context) }
        catch { throw CommandConvertIssue.invalidTarget(.family) }
        // 写入沿关系取活子任务；与按身份查得的活子任务不一致时不能预测迁移结果。
        guard Set(family.filter { $0.deletedAt == nil }.map(\.persistentModelID)) == Set(children.map(\.persistentModelID)) else {
            throw CommandConvertIssue.invalidTarget(.family)
        }
        let attachments = try liveAttachments(todo.id, kind: .todo)
        let losses = CommandConvertLosses.FromTodo(dayKey: todo.dayKey,
            weekdayMask: ItemConversionService.weekdayMask(for: todo, calendar: clock.calendar), dueMinutes: todo.dueMinutes,
            wasDone: todo.isDone, subtasks: children.count, doneSubtasks: children.filter(\.isDone).count,
            attachments: attachments.count)
        return .init(target: target, record: todo.persistentModelID, title: todo.title, source: source,
                     fingerprint: .todo(todo.snapshot), subtasks: Set(children.map(\.persistentModelID)),
                     attachments: attachments, checks: [], losses: .todoToRoutine(losses))
    }

    private func routineImpact(_ target: CommandObjectReference,
                               source: CommandTaskTitleEligibility) throws -> CommandConvertImpact {
        let routine = try live(SwiftDataRoutineRepository(context: environment.context).fetchRoutines(withID: target.id),
                               deleted: \.deletedAt)
        guard TaskCopyContent.notes(routine.notes) == nil else { throw CommandConvertIssue.invalidTarget(.notes) }
        let attachments = try liveAttachments(routine.id, kind: .routine)
        let checks = Set(routine.checks.map(\.persistentModelID))
        let losses = CommandConvertLosses.FromRoutine(today: clock.today(), weekdayMask: routine.resolvedWeekdayMask,
            isEnabled: routine.isEnabled, paused: routine.pausedOnDayKey != nil, checks: checks.count,
            templates: ItemConversionService.orderedTemplates(of: routine).count, attachments: attachments.count)
        return .init(target: target, record: routine.persistentModelID, title: routine.title, source: source,
                     fingerprint: .routine(routine.snapshot), subtasks: [], attachments: attachments, checks: checks,
                     losses: .routineToTodo(losses))
    }

    private func live<T: PersistentModel>(_ rows: [T], deleted: KeyPath<T, Date?>) throws -> T {
        guard rows.count == 1 else { throw CommandConvertIssue.invalidTarget(rows.isEmpty ? .missing : .duplicate) }
        guard rows[0].modelContext === environment.context else { throw CommandConvertIssue.invalidRepository }
        guard rows[0][keyPath: deleted] == nil else { throw CommandConvertIssue.invalidTarget(.deleted) }
        return rows[0]
    }

    func liveAttachments(_ owner: UUID, kind: AttachmentOwner, in context: ModelContext? = nil) throws -> Set<PersistentIdentifier> {
        Set(try OwnedAttachments.matching(ownerID: owner, kind: kind, in: context ?? environment.context)
            .filter { $0.deletedAt == nil }.map(\.persistentModelID))
    }
}
