import Foundation

/// 记录范围只供显式调用方选择，不擅自给 1A 目录增加另一条路径。
enum ContentQueryScopeSelection: Equatable {
    case global
    case catalog(CommandContentScope)
    case routineOccurrences
}

enum ContentQueryRoutineInclusion: Equatable { case enabledOnly, enabledAndDisabled }
enum ContentQueryDeletionPolicy: Equatable { case liveOnly, deletedOnly }

struct ContentQueryComposition: Equatable {
    let types: Set<CommandObjectType>
    let routines: ContentQueryRoutineInclusion
    let deletion: ContentQueryDeletionPolicy
    let includesCompletedTasks = true
    let restrictsCommandDiscovery = false
    let requiresRoutineEnabledPresentation = true
}

enum ContentQueryScopeContract {
    static func composition(
        _ scope: ContentQueryScopeSelection, includeInactiveRoutines: Bool = false
    ) -> ContentQueryComposition {
        let types: Set<CommandObjectType>
        var routines: ContentQueryRoutineInclusion = includeInactiveRoutines ? .enabledAndDisabled : .enabledOnly
        var deletion: ContentQueryDeletionPolicy = .liveOnly
        switch scope {
        case .global: types = [.todo, .subtask, .routine, .diary, .tag, .image]
        case .routineOccurrences: types = [.routineOccurrence]; routines = .enabledAndDisabled
        case .catalog(let scope):
            switch scope {
            case .tasks: types = [.todo, .subtask, .routine]
            case .subtasks: types = [.subtask]
            case .routines: types = [.routine]; routines = .enabledAndDisabled
            case .diaries: types = [.diary]
            case .tags: types = [.tag]
            case .images: types = [.image]
            case .clipboard: types = [.clipboardEntry]
            case .trash:
                types = [.todo, .subtask, .routine, .diary, .tag, .image]
                routines = .enabledAndDisabled
                deletion = .deletedOnly
            }
        }
        return .init(types: types, routines: routines, deletion: deletion)
    }
}

/// 映射告诉提供者应取哪个真实字段/投影；绝不通过填假字段让类型通过条件。
enum ContentQueryFieldBinding: Hashable {
    case parentCompletion, parentPriority, parentReminder, sourceApplication, parentSourceApplication
    case objectType, routineEnabled, taskOrSubtaskTags, typeNeutral
    case ownText, ownTags, ownPriority, ownReminder, ownCompletion, occurrenceCompletion
    case scheduledDay, parentScheduledDay, diaryDay, occurrenceDay, ownerBusinessDay, capturedDay
    case scheduledDayExistenceReturningOneDefinition
    case createdAt, attachedImage, clipboardImage
    case routineCompletionOnDay(String)
    case requiresOccurrenceDay
    case notApplicable
}

struct ContentQueryFieldRequirement: Equatable {
    let dimension: ContentQueryDimension
    let range: NSRange
    let binding: ContentQueryFieldBinding

    /// 提供者不得忽略不适用条件；日期缺失须由调用方显式选择后重新检查。
    var isApplicable: Bool { binding != .notApplicable && binding != .requiresOccurrenceDay }
}

enum ContentQueryApplicability {
    static func requirements(
        for query: ContentQuery, type: CommandObjectType, occurrenceDay: String? = nil
    ) -> [ContentQueryFieldRequirement] {
        query.clauses.flatMap(\.alternatives).map {
            .init(dimension: $0.atom.dimension, range: $0.range,
                  binding: binding($0.atom.dimension, to: type, occurrenceDay: occurrenceDay))
        }
    }

    static func binding(
        _ dimension: ContentQueryDimension, to type: CommandObjectType, occurrenceDay: String? = nil
    ) -> ContentQueryFieldBinding {
        switch dimension {
        case .text:
            return [.todo, .subtask, .routine, .diary, .tag, .image, .clipboardEntry].contains(type) ? .ownText : .notApplicable
        case .tag:
            return [.todo, .subtask, .routine, .diary].contains(type) ? .ownTags : .notApplicable
        case .priority: return [.todo, .routine].contains(type) ? .ownPriority : .notApplicable
        case .reminder: return [.todo, .routine].contains(type) ? .ownReminder : .notApplicable
        case .status: return status(type, occurrenceDay: occurrenceDay)
        case .date: return businessDate(type)
        case .created:
            return [.todo, .subtask, .routine, .diary, .image].contains(type) ? .createdAt : .notApplicable
        case .image:
            if type == .clipboardEntry { return .clipboardImage }
            return [.todo, .routine, .diary].contains(type) ? .attachedImage : .notApplicable
        }
    }

    private static func status(_ type: CommandObjectType, occurrenceDay: String?) -> ContentQueryFieldBinding {
        switch type {
        case .todo, .subtask: return .ownCompletion
        case .routineOccurrence: return .occurrenceCompletion
        case .routine:
            guard let day = occurrenceDay, CommandArgumentValidation.isCanonicalDay(day) else { return .requiresOccurrenceDay }
            return .routineCompletionOnDay(day)
        default: return .notApplicable
        }
    }

    private static func businessDate(_ type: CommandObjectType) -> ContentQueryFieldBinding {
        switch type {
        case .todo: .scheduledDay
        case .subtask: .parentScheduledDay
        case .diary: .diaryDay
        case .routineOccurrence: .occurrenceDay
        case .routine: .scheduledDayExistenceReturningOneDefinition
        case .image: .ownerBusinessDay
        case .clipboardEntry: .capturedDay
        default: .notApplicable
        }
    }
}

extension ContentQueryApplicability {
    static func pageBinding(_ predicate: ContentQueryPagePredicate, to type: CommandObjectType) -> ContentQueryFieldBinding {
        switch predicate {
        case .tagID(_, let matching):
            if type == .todo && matching == .taskOrSubtask { return .taskOrSubtaskTags }
            return binding(.tag, to: type)
        case .noTags: return binding(.tag, to: type)
        case .contentTypes: return .objectType
        default: break
        }
        guard [.todo, .subtask, .routine].contains(type) else { return .notApplicable }
        switch predicate {
        case .taskPriority: return type == .subtask ? .parentPriority : .ownPriority
        case .boardDate: return binding(.date, to: type)
        case .sourceApplication: return type == .subtask ? .parentSourceApplication : .sourceApplication
        case .reminderPresence: return type == .subtask ? .parentReminder : .ownReminder
        case .todoStatus: return type == .routine ? .typeNeutral : (type == .subtask ? .parentCompletion : .ownCompletion)
        case .routineStatus: return type == .routine ? .routineEnabled : .typeNeutral
        case .itemKind: return .objectType
        case .tagID, .noTags, .contentTypes: return .notApplicable
        }
    }
}
