import Foundation
import SwiftData

extension BatchCommandReader {
    func readStateImpacts(_ targets: [CommandObjectReference], edit: CommandBatchEdit,
                          sources: [CommandTaskTitleEligibility], lookup: CommandTaskTagLookup) throws -> [CommandBatchTargetImpact] {
        guard let configuration = environment.stateOperations else { throw CommandBatchIssue.unassembled }
        let dates = ContentQueryDateContext(todayKey: DayKey.from(configuration.now(), calendar: configuration.calendar),
                                           calendar: configuration.calendar)
        let context = environment.context
        let ids = targets.filter { $0.type == .todo }.map(\.id)
        let todos = try context.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { ids.contains($0.id) }))
        let children = ids.isEmpty ? [] : try context.fetch(FetchDescriptor<SubtaskItem>())
        let todoIndex = Dictionary(grouping: todos, by: \.id)
        let routines = targets.contains { $0.type != .todo } ? try RoutineCommandStateSnapshot(context: context, dates: dates) : nil
        let routineIndex = Dictionary(grouping: routines?.definitions ?? [], by: \.id)
        var history: [UUID: [RoutineScheduleEvidence]] = [:]
        // 回调全部发生在任何模型变化前，同一定义的多个日期复用同一份历史证据。
        for id in Set(targets.filter { $0.type == .routineOccurrence }.map(\.id)) {
            do { history[id] = try configuration.history(id) }
            catch {
                throw CommandBatchIssue.invalidTargets(targets.filter { $0.id == id && $0.type == .routineOccurrence }
                    .map { .init(target: $0, reason: .state(.historyUnknown)) })
            }
        }
        var impacts: [CommandBatchTargetImpact] = [], problems: [CommandBatchTargetProblem] = []
        for (target, source) in zip(targets, sources) {
            do {
                if target.type == .todo {
                    let todo = try unique(todoIndex[target.id] ?? [], target: target)
                    impacts.append(try completionImpact(todo, target: target, source: source,
                                                       edit: edit, children: children, lookup: lookup))
                } else {
                    let routine = try unique(routineIndex[target.id] ?? [], target: target)
                    guard let routines else { throw CommandBatchIssue.stale }
                    impacts.append(try routineImpact(routine, target: target, source: source, edit: edit,
                        snapshot: routines, history: history[target.id] ?? [], lookup: lookup))
                }
            } catch let issue as RoutineStateIssue { problems.append(.init(target: target, reason: .state(issue))) }
            catch let issue as CommandBatchIssue {
                if case .invalidTargets(let entries) = issue { problems += entries } else { throw issue }
            } catch is SubtaskCommandIssue { problems.append(.init(target: target, reason: .family)) }
            catch { problems.append(.init(target: target, reason: .tags)) }
        }
        guard problems.isEmpty else { throw CommandBatchIssue.invalidTargets(problems) }
        guard DayKey.from(configuration.now(), calendar: configuration.calendar) == dates.todayKey else { throw CommandBatchIssue.stale }
        return impacts
    }

    private func completionImpact(_ todo: TodoItem, target: CommandObjectReference, source: CommandTaskTitleEligibility,
                                  edit: CommandBatchEdit, children rows: [SubtaskItem],
                                  lookup: CommandTaskTagLookup) throws -> CommandBatchTargetImpact {
        guard case .completion(let done) = edit else { throw CommandBatchIssue.invalidArguments }
        guard todo.deletedAt == nil else { throw CommandBatchIssue.invalidTargets([.init(target: target, reason: .deleted)]) }
        _ = try CommandTaskTitleTags.associations(rawIDs: todo.tagIDs, lookup: lookup)
        let children = try TaskFamilyCommandIdentity.children(of: todo, in: environment.context, rows: rows)
        let completion = try TaskFamilyCommandIdentity.completion(of: todo, done: done, children: children, lookup: lookup)
        return .init(target: target, record: ObjectIdentifier(todo), title: todo.title, source: source,
            rawTagIDs: todo.tagIDs, original: .boolean(todo.isDone), final: .boolean(done), tags: nil,
            identity: todo.persistentModelID, taskDay: todo.dayKey, completion: completion,
            children: Dictionary(uniqueKeysWithValues: children.map { ($0.id, $0.persistentModelID) }))
    }

    private func routineImpact(_ routine: DailyRoutine, target: CommandObjectReference, source: CommandTaskTitleEligibility,
                               edit: CommandBatchEdit, snapshot: RoutineCommandStateSnapshot,
                               history: [RoutineScheduleEvidence], lookup: CommandTaskTagLookup) throws -> CommandBatchTargetImpact {
        guard routine.deletedAt == nil else { throw CommandBatchIssue.invalidTargets([.init(target: target, reason: .deleted)]) }
        _ = try CommandTaskTitleTags.associations(rawIDs: routine.tagIDs, lookup: lookup)
        let operation: CommandRoutineEdit
        switch edit {
        case .completion(let done): operation = .occurrence(done ? .complete : .reopen)
        case .enabled(let enabled): operation = .enabled(enabled)
        default: throw CommandBatchIssue.invalidArguments
        }
        let state = try snapshot.impact(routine, edit: operation, target: target, history: history)
        let original: Bool, final: Bool
        if case .enabled(let enabled) = edit { original = routine.isEnabled; final = enabled }
        else { original = state.effects.first?.original.first?.done ?? false; final = state.effects.first?.done ?? false }
        return .init(target: target, record: ObjectIdentifier(routine), title: routine.title, source: source,
            rawTagIDs: routine.tagIDs, original: .boolean(original), final: .boolean(final), tags: nil,
            identity: routine.persistentModelID, state: state)
    }
}
