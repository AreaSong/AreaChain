import Foundation
import SwiftData

@MainActor final class RoutineCommandReader {
    unowned let environment: RoutineCommandEnvironment
    let catalogReader: TaskCreateTagCatalogReader
    init(environment: RoutineCommandEnvironment) {
        self.environment = environment
        catalogReader = .init(context: environment.context, invalidation: .catalogFacts)
    }

    func identity(_ target: CommandObjectReference) throws -> DailyRoutine {
        guard (target.type == .routine && target.dayKey == nil)
            || (target.type == .routineOccurrence && target.dayKey.map(CommandArgumentValidation.isCanonicalDay) == true) else {
            throw RoutineCommandIssue.invalidArguments
        }
        let rows = try SwiftDataRoutineRepository(context: environment.context).fetchRoutines(withID: target.id)
        guard !rows.isEmpty else { throw CommandTaskTitlePreviewIssue.missingTarget }
        guard rows.count == 1 else { throw CommandTaskTitlePreviewIssue.duplicateTarget }
        guard rows[0].modelContext === environment.context else { throw RoutineCommandIssue.invalidRepository }
        guard rows[0].deletedAt == nil else { throw CommandTaskTitlePreviewIssue.deletedTarget }
        return rows[0]
    }

    func prepare(in host: CommandOwnedHost) throws -> CommandRoutinePreview {
        let item = try CommandRoutinePreview.input(in: host)
        return try read(item, lease: host.lease, plan: host.session.plan.stamp, catalog: catalogReader.prepare())
    }

    func validate(_ preview: CommandRoutinePreview, item: CommandPlanItem) throws -> DailyRoutine {
        guard preview.semanticsVersion == 1, item.stamp == preview.item, item.draft.stamp == preview.draft,
              item.draft.arguments == preview.arguments else { throw RoutineCommandIssue.stale }
        let current = try read(item, lease: preview.lease, plan: preview.plan, catalog: catalogReader.current(), consumption: preview.consumption)
        guard current.source == preview.source, current.catalog == preview.catalog,
              current.target == preview.target, current.record == preview.record else { throw RoutineCommandIssue.stale }
        guard current == preview else { throw RoutineCommandIssue.fieldsChanged }
        return try identity(preview.target)
    }

    func read(_ item: CommandPlanItem, lease: CommandHostLease, plan: CommandPlanStamp,
                      catalog: CommandTaskTagCatalog, consumption: CommandCreationConsumption? = nil) throws -> CommandRoutinePreview {
        let resolved = try consumption?.input(item)
        try CommandRoutinePreview.validate(item, allowingDependencies: true, resolved: resolved)
        let draft = item.draft
        let target = (resolved?.targets ?? draft.targets).objects[0]
        let source = try environment.qualification(.init(command: draft.commandID, target: target, arguments: draft.arguments))
        guard try catalogReader.current().evidence() == catalog.evidence() else { throw TaskTitleCommandIssue.catalogChanged }
        let routine = try identity(target)
        try consumption?.output.validate(context: ObjectIdentifier(environment.context),
                                         storage: ObjectIdentifier(environment.context.container), record: routine.persistentModelID)
        _ = try CommandTaskTitleTags.merge(rawIDs: routine.tagIDs, title: "", catalog: catalog)
        let edit = try CommandRoutineEdit(command: draft.commandID, arguments: draft.arguments)
        let tags: CommandTaskTagMutation?
        if let argument = draft.arguments.first { tags = try self.tags(routine, edit: edit, argument: argument, catalog: catalog) }
        else { tags = nil }
        let impact = try stateImpact(routine, edit: edit, target: target)
        let original = Self.values(routine, edit: edit)
        let final = Self.final(edit, original: original, tags: tags)
        return .init(lease: lease, plan: plan, item: item.stamp, draft: draft.stamp, arguments: draft.arguments,
                     target: target, record: routine.persistentModelID, targetTitle: routine.title, isEnabled: routine.isEnabled,
                     original: original, final: final, edit: edit, source: source, catalog: try catalog.evidence(),
                     tagIDs: routine.tagIDs, tags: tags, stateImpact: impact, consumption: consumption)
    }

    private func tags(_ routine: DailyRoutine, edit: CommandRoutineEdit, argument: CommandArgument,
                      catalog: CommandTaskTagCatalog) throws -> CommandTaskTagMutation? {
        switch edit {
        case .title:
            guard case .shortText(let raw) = argument.value else { throw RoutineCommandIssue.invalidArguments }
            let tags = try CommandTaskTitleTags.merge(rawIDs: routine.tagIDs, title: raw, catalog: catalog)
            return .init(original: tags.original, final: tags.final, actions: tags.syntax)
        case .tags: return try CommandTaskTagMutation.prepare(rawIDs: routine.tagIDs, argument: argument, catalog: catalog)
        default: return nil
        }
    }

    static func values(_ routine: DailyRoutine, edit: CommandRoutineEdit) -> [RoutineField: RoutineFieldValue] {
        switch edit {
        case .title(let title):
            var values: [RoutineField: RoutineFieldValue] = [.title: .text(routine.title), .tagIDs: .text(routine.tagIDs)]
            if title.priority != nil {
                values[.isImportant] = .flag(routine.isImportant)
                values[.isUrgent] = .flag(routine.isUrgent)
            }
            if title.remindMinutes != nil { values[.remindMinutes] = .number(routine.remindMinutes) }
            return values
        case .weekdays: return [.weekdayMask: .number(routine.weekdayMask), .weekdaysOnly: .flag(routine.weekdaysOnly)]
        case .reminder: return [.remindMinutes: .number(routine.remindMinutes)]
        case .priority: return [.isImportant: .flag(routine.isImportant), .isUrgent: .flag(routine.isUrgent)]
        case .enabled, .occurrence: return [:]
        case .tags: return [.tagIDs: .text(routine.tagIDs)]
        }
    }

    private static func final(_ edit: CommandRoutineEdit, original: [RoutineField: RoutineFieldValue],
                              tags: CommandTaskTagMutation?) -> [RoutineField: RoutineFieldValue] {
        var result = original
        switch edit {
        case .title(let title):
            result[.title] = .text(title.title)
            if let priority = title.priority {
                result[.isImportant] = .flag(priority.isImportant)
                result[.isUrgent] = .flag(priority.isUrgent)
            }
            if let minutes = title.remindMinutes { result[.remindMinutes] = .number(minutes) }
        case .weekdays(let mask): result = [.weekdayMask: .number(mask), .weekdaysOnly: .flag(WeekdayMask.isWorkdays(mask))]
        case .reminder(let minutes): result = [.remindMinutes: .number(minutes)]
        case .priority(let important, let urgent): result = [.isImportant: .flag(important), .isUrgent: .flag(urgent)]
        case .tags, .enabled, .occurrence: break
        }
        if let tags { result[.tagIDs] = tags.finalEncodedIDs.map(RoutineFieldValue.text) }
        return result
    }
}
