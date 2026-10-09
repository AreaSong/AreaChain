import Foundation
import SwiftData

enum RoutineCreateIssue: Error, Equatable {
    case unassembled, invalidInput, invalidWeekdays, notesNotSupported, stale, dateChanged, sortChanged
    case unreliableSort, identityCollision, sourceUnavailable, protectedContent
}

/// 新建没有目标证据；当前输入与创建环境各自提供普通来源修订。
struct CommandRoutineCreateEligibility: Equatable {
    let input: CommandSubtaskEligibility.Proof
    let environment: CommandSubtaskEligibility.Proof
}

struct CommandRoutineCreateSource: Equatable {
    let environmentID: UUID
    let contextID: ObjectIdentifier
    let storageID: ObjectIdentifier
    let eligibility: CommandRoutineCreateEligibility
}

struct CommandRoutineCreateSortRow: Equatable {
    let id: UUID
    let record: PersistentIdentifier
    let order: Int
}

/// 仅冻结新定义的参数和创建环境，不构造既存 routine 的基线或目标。
struct CommandRoutineCreatePreview: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let lease: CommandHostLease
    let plan: CommandPlanStamp
    let item: CommandPlanItemStamp
    let draft: CommandDraftStamp
    let arguments: [CommandArgument]
    let source: CommandRoutineCreateSource
    let catalog: CommandTaskTagCatalog.Evidence
    let sortBasis: [CommandRoutineCreateSortRow]
    let sortOrder: Int
    let weekdayMask: Int
    // day 仅为共享合成值的创建日，不是可输入的任务日期参数。
    let composition: CommandTaskCreateComposition
    var semanticsVersion = 1
    var createdDayKey: String { composition.day }
    var canAccept: Bool {
        composition.hasEffectiveContent && !composition.priority.hasConflict
            && !composition.reminder.hasConflict && composition.tags.problems.isEmpty
    }
    var description: String { "CommandRoutineCreatePreview(redacted)" }
    var debugDescription: String { description }

    static func validate(_ item: CommandPlanItem, allowingDependencies: Bool = false) throws {
        guard item.atomicGroup == nil, allowingDependencies || item.links.predecessors.isEmpty, item.links.results.isEmpty,
              item.hasSupportedOrigins, allowingDependencies || item.executionOrigin == nil else { throw RoutineCreateIssue.invalidInput }
        _ = try input(item.draft)
    }

    static func input(_ draft: CommandDraft) throws -> (title: String, mask: Int) {
        guard draft.commandID.rawValue == "routine.create", draft.targets == .none,
              draft.baseline == CommandDraftBaseline(), !draft.blocksUnprotectedExport,
              draft.protectionRequirement == .ordinary else { throw RoutineCreateIssue.invalidInput }
        guard !draft.arguments.contains(where: { $0.parameter == .notes }) else { throw RoutineCreateIssue.notesNotSupported }
        guard case .weekdays(let mask) = draft.arguments.first(where: { $0.parameter == .weekdays })?.value,
              mask > 0, mask & ~WeekdayMask.all == 0 else { throw RoutineCreateIssue.invalidWeekdays }
        guard let command = CommandCatalog.standard.command(id: draft.commandID),
              CommandArgumentValidation.issues(for: draft.arguments, command: command).isEmpty,
              case .shortText(let title) = draft.arguments.first(where: { $0.parameter == .title })?.value else {
            throw RoutineCreateIssue.invalidInput
        }
        guard !title.contains(where: \.isNewline), !NaturalLanguageParser.hasTaskNoteSeparator(title),
              NaturalLanguageParser.parseTaskCapture(title).notes.isEmpty else { throw RoutineCreateIssue.notesNotSupported }
        return (title, mask)
    }

    static func item(in host: CommandOwnedHost) throws -> CommandPlanItem {
        let session = host.session
        guard session.execution == nil, session.operations.allDrafts.isEmpty, session.operations.pending == nil,
              session.plan.editing == nil, session.plan.items.count == 1,
              let item = session.plan.items.first, item.draft.hostID == session.hostID else { throw RoutineCreateIssue.invalidInput }
        try validate(item)
        return item
    }

    func frozenItem(in run: CommandExecutionRun, lease: CommandHostLease) throws -> CommandPlanItem {
        guard run.previewLeaseMatches(self.lease, current: lease, itemID: self.item.id),
              run.snapshot.stamp == plan, run.permitsMember(self.item.id),
              let item = run.snapshot.items.first(where: { $0.id == self.item.id }), item.stamp == self.item, item.draft.stamp == draft,
              item.draft.arguments == arguments,
              run.resolvedInput(item.id) == .init(arguments: arguments, targets: .none) else { throw RoutineCreateIssue.stale }
        try Self.validate(item, allowingDependencies: run.multiPlan != nil)
        return item
    }
}

struct CommandRoutineCreateAcceptance: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let id: UUID
    let creationID: UUID
    let preview: CommandRoutineCreatePreview
    let tagCreationIDs: [String: UUID]
    fileprivate init(_ preview: CommandRoutineCreatePreview, preserving old: Self?) {
        id = UUID()
        creationID = old?.creationID ?? UUID()
        self.preview = preview
        tagCreationIDs = Dictionary(uniqueKeysWithValues: preview.composition.tags.final.compactMap {
            guard case .newName(_, let key) = $0.target else { return nil }
            return (key, old?.tagCreationIDs[key] ?? UUID())
        })
    }
    var object: CommandObjectReference { .init(type: .routine, id: creationID) }
    var description: String { "CommandRoutineCreateAcceptance(redacted)" }
    var debugDescription: String { description }
}

extension CommandTaskCreateRegistry {
    /// 同一创建登记拥有新定义及标签身份；重新接受过期预览保留身份，已调用永远不重新分配。
    func acceptRoutineCreation(_ preview: CommandRoutineCreatePreview, retry: CommandMultiPlanRetryPermit? = nil) throws -> CommandRoutineCreateAcceptance {
        guard preview.canAccept else { throw RoutineCreateIssue.invalidInput }
        let old = routinePreparations[preview.draft.draftID]
        if let old {
            guard !wasInvoked(old.id) || retry?.matches(item: preview.item, acceptance: old.id) == true else { throw RoutineCreateIssue.stale }
            if old.preview == preview && !wasInvoked(old.id) { return old }
        }
        let accepted = CommandRoutineCreateAcceptance(preview, preserving: old)
        routinePreparations[preview.draft.draftID] = accepted
        return accepted
    }
}
