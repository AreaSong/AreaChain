import Foundation

/// T-M1 唯一多步形状；身份覆盖整个计划，两步仍有各自的调用与提交事实。
struct CommandTaskChainIdentity: Equatable {
    let plan: CommandPlanStamp
    let producer: CommandPlanItemStamp
    let consumer: CommandPlanItemStamp

    init(plan: CommandPlanStamp, items: [CommandPlanItem]) throws {
        guard items.count == 2, CommandPlanValidation.check(items).canSealProtocol,
              items.allSatisfy({ $0.draft.hostID == plan.hostID && $0.atomicGroup == nil
                  && $0.mergedOrigins.isEmpty && $0.returnedAttempts.isEmpty }) else {
            throw TaskFieldCommandIssue.unsupportedPlan
        }
        try CommandHandoffCoordinator.validateTaskCreateItem(items[0])
        let second = items[1]
        guard second.draft.commandID.rawValue == "todo.title", second.draft.targets == .none,
              second.draft.baseline == CommandDraftBaseline(), second.links.predecessors.isEmpty,
              second.links.results == [.target: .init(producer: items[0].stamp, outputType: .todo)],
              !second.draft.blocksUnprotectedExport, second.draft.protectionRequirement == .ordinary,
              second.draft.arguments.count == 1, second.draft.arguments[0].parameter == .title,
              second.draft.arguments[0].operation == .assign,
              case .shortText(let title) = second.draft.arguments[0].value,
              !title.contains(where: \.isNewline), !NaturalLanguageParser.hasTaskNoteSeparator(title),
              let edit = TaskTitleEdit(title), edit.notes == nil, !edit.title.isEmpty else {
            throw TaskFieldCommandIssue.invalidArguments
        }
        self.plan = plan
        producer = items[0].stamp
        consumer = items[1].stamp
    }

    func validate(_ run: CommandExecutionRun) throws {
        guard try Self(plan: run.snapshot.stamp, items: run.snapshot.items) == self,
              run.units.count == 2, run.units.allSatisfy({ !$0.atomic && $0.members == [$0.id] }) else {
            throw CommandExecutionError.stale
        }
    }
}

struct CommandTaskChainOutput: Equatable {
    let execution: CommandExecutionStamp
    let producer: CommandPlanItemStamp
    let creationAcceptanceID: UUID
    let localAttempt: CommandAttemptStamp
    let object: CommandObjectReference
}

struct CommandTaskChainBinding: Equatable {
    let identity: CommandTaskChainIdentity
    let output: CommandTaskChainOutput
    let attempt: CommandAttemptStamp
}

extension CommandExecutionRun {
    func taskMutationMember(_ id: UUID) throws -> CommandPlanItem? {
        if snapshot.items.count != 1 {
            try CommandTaskChainIdentity(plan: snapshot.stamp, items: snapshot.items).validate(self)
        }
        return snapshot.items.first { $0.id == id }
    }
}

extension CommandTaskTitlePreview {
    static func chainInput(in run: CommandExecutionRun, binding: CommandTaskChainBinding) throws -> Input {
        try binding.identity.validate(run)
        guard binding.output.execution == run.stamp, binding.output.producer == binding.identity.producer,
              run.creationOutput(for: .init(producer: binding.identity.producer, outputType: .todo)) == binding.output.object,
              let item = run.snapshot.items.first(where: { $0.stamp == binding.identity.consumer }),
              let resolved = run.resolvedInput(item.id), resolved.targets == .init(.single, objects: [binding.output.object]),
              let command = CommandCatalog.standard.command(id: item.draft.commandID),
              let target = resolved.targets.argument(for: command), resolved.arguments == item.draft.arguments + [target] else {
            throw CommandTaskTitlePreviewIssue.stale
        }
        return try resolvedInput(item: item, targets: resolved.targets)
    }
}

extension CommandHandoffCoordinator {
    func taskChainPlan(_ stamp: CommandPlanStamp, expecting lease: CommandHostLease) throws -> CommandTaskChainIdentity {
        try validate(lease)
        let session = try host(lease.ownership.hostID).session
        guard session.plan.stamp == stamp, session.execution == nil, session.plan.editing == nil,
              session.operations.allDrafts.isEmpty, session.operations.pending == nil else { throw CommandExecutionError.stale }
        return try .init(plan: stamp, items: session.plan.items)
    }

    /// 输出必须同时有真实保存事实、原生产者调用登记以及依赖协议的成功状态。
    func taskChainOutput(in run: CommandExecutionRun) throws -> CommandTaskChainOutput {
        let identity = try CommandTaskChainIdentity(plan: run.snapshot.stamp, items: run.snapshot.items)
        try identity.validate(run)
        let item = run.snapshot.items[0]
        guard let prepared = taskCreations.preparations[item.draft.id], prepared.chain == identity,
              prepared.item == item.stamp, prepared.plan == run.snapshot.stamp, taskCreations.wasInvoked(prepared.id),
              let unit = run.units.first(where: { $0.id == item.id }), let facts = unit.taskCreation,
              facts.state == .saved, facts.save == .returned, let savedID = facts.savedID,
              savedID == prepared.creationID, facts.creationID == savedID,
              let output = run.creationOutput(for: .init(producer: item.stamp, outputType: .todo)), output.id == savedID,
              run.outputs == [item.id: output] else { throw CommandExecutionError.requiresVerification }
        return .init(execution: run.stamp, producer: item.stamp, creationAcceptanceID: prepared.id,
                     localAttempt: .init(execution: run.stamp, unitID: item.id, number: 1, phase: .local), object: output)
    }

    func taskChainBinding(expecting lease: CommandHostLease) throws -> CommandTaskChainBinding {
        try validate(lease)
        let session = try host(lease.ownership.hostID).session
        guard session.plan.items.isEmpty, session.operations.allDrafts.isEmpty, session.operations.pending == nil,
              let run = session.execution else { throw CommandExecutionError.stale }
        let identity = try CommandTaskChainIdentity(plan: run.snapshot.stamp, items: run.snapshot.items)
        let output = try taskChainOutput(in: run)
        guard let unit = run.units.first(where: { $0.id == identity.consumer.id }), unit.state == .running,
              unit.local == .notSubmitted, unit.taskTitle == nil, unit.attempt == 1,
              let attempt = run.attempt(unit.id), attempt.phase == .local,
              run.resolvedInput(unit.id)?.targets == .init(.single, objects: [output.object]) else {
            throw CommandExecutionError.stale
        }
        return .init(identity: identity, output: output, attempt: attempt)
    }
}
