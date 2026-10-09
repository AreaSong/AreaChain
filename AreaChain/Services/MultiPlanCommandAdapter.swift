import Foundation

/// 组合已装配的普通适配器；唯一执行参数与事实仍由原 Coordinator / Run 持有。
@MainActor final class MultiPlanCommandAdapter {
    let coordinator: CommandHandoffCoordinator
    let taskCreate: TaskCreateCommandAdapter?
    let taskTitle: TaskTitleCommandAdapter?
    let taskField: TaskFieldCommandAdapter?
    let subtask: SubtaskCommandAdapter?
    let routine: RoutineCommandAdapter?
    let batch: BatchCommandAdapter?
    let localSettings: LocalSettingCommandAdapter?
    let fileSettings: FileLocalSettingCommandAdapter?
    let id = UUID()
    let outputCapability: CommandMultiPlanOutputCapability
    let supportsRevisions: Bool
    var mergeProposal: MultiPlanMergeProposal?
    private(set) var preview: MultiPlanCommandPreview?
    private(set) var pending: MultiPlanCommandMemberPreview?
    private(set) var pendingItemID: UUID?
    private(set) var requiresDisplayReview = false
    private var operating = false
    private var pendingRetry: CommandAttemptStamp?

    struct Adapters {
        var taskCreate: TaskCreateCommandAdapter?
        var taskTitle: TaskTitleCommandAdapter?
        var taskField: TaskFieldCommandAdapter?
        var subtask: SubtaskCommandAdapter?
        var routine: RoutineCommandAdapter?
        var batch: BatchCommandAdapter?
        var localSettings: LocalSettingCommandAdapter?
        var fileSettings: FileLocalSettingCommandAdapter?
    }

    init(coordinator: CommandHandoffCoordinator, adapters: Adapters,
         outputCapability: CommandMultiPlanOutputCapability = .taskTitle, supportsRevisions: Bool = false) {
        self.supportsRevisions = supportsRevisions
        self.outputCapability = outputCapability
        self.coordinator = coordinator
        taskCreate = adapters.taskCreate
        taskTitle = adapters.taskTitle
        taskField = adapters.taskField
        subtask = adapters.subtask
        routine = adapters.routine
        batch = adapters.batch
        fileSettings = adapters.fileSettings
        localSettings = adapters.localSettings
    }

    func family(for command: CommandID) throws -> CommandMultiPlanFamily {
        if CommandPlanSemantics.isAtomicSetting(command), localSettings != nil, fileSettings != nil {
            throw CommandMultiPlanIssue.unsupported
        }
        if CommandPlanSemantics.isAtomicSetting(command), let localSettings,
           localSettings.isAssembled(for: coordinator) { return .localSetting }
        if CommandPlanSemantics.isAtomicSetting(command), let fileSettings,
           fileSettings.isAssembled(for: coordinator) { return .fileSettings }
        if command.rawValue == "todo.create", let taskCreate, taskCreate.coordinator === coordinator,
           taskCreate.supports(command) { return .taskCreate }
        if command.rawValue == "todo.title", let taskTitle, taskTitle.coordinator === coordinator,
           taskTitle.supports(command) { return .taskTitle }
        if TaskFieldEdit.commands.contains(command.rawValue), let taskField,
           taskField.coordinator === coordinator, taskField.supports(command) { return .taskField }
        if CommandSubtaskEdit.commands.contains(command.rawValue), let subtask,
           subtask.coordinator === coordinator, subtask.environment != nil { return .subtask }
        if CommandRoutineEdit.allCommands.contains(command.rawValue), let routine,
           routine.coordinator === coordinator, routine.supports(command) { return .routine }
        if command.rawValue == "routine.create", let routine, routine.coordinator === coordinator,
           routine.environment?.creation != nil { return .routineCreate }
        if CommandBatchEdit.commands.contains(command.rawValue), let batch,
           batch.coordinator === coordinator, batch.supports(command) { return .batch }
        throw CommandMultiPlanIssue.unassembled
    }

    func prepare(plan: CommandPlanStamp, expecting lease: CommandHostLease,
                 displaySession: ContentQueryReadSession? = nil) throws -> MultiPlanCommandPreview {
        try enter()
        defer { operating = false }
        try coordinator.validate(lease)
        try displaySession?.validateDisplayHost(expecting: lease)
        let host = try coordinator.host(lease.ownership.hostID)
        guard host.session.execution == nil, host.session.plan.stamp == plan, host.session.plan.editing == nil,
              host.session.operations.allDrafts.isEmpty, host.session.operations.pending == nil else {
            throw CommandMultiPlanIssue.stale
        }
        let items = host.session.plan.items
        guard supportsRevisions || items.allSatisfy({ $0.executionOrigin == nil }) else { throw CommandMultiPlanIssue.unsupported }
        try coordinator.validatePlanOrigins(items, plan: plan, assemblyID: id, owner: lease.ownership)
        let families = try Dictionary(uniqueKeysWithValues: items.map { ($0.id, try family(for: $0.draft.commandID)) })
        let identity = try CommandMultiPlanIdentity(plan: plan, items: items, families: families, outputCapability: outputCapability)
        try validateReferenceEnvironments(identity, items: items)
        var members: [UUID: MultiPlanCommandMemberPreview] = [:]
        for item in items {
            members[item.id] = try read(item, family: families[item.id]!, lease: lease, plan: plan)
        }
        try coordinator.validate(lease)
        try displaySession?.validateDisplayHost(expecting: lease)
        let prepared = MultiPlanCommandPreview(id: UUID(), lease: lease, identity: identity, members: members)
        preview = prepared
        requiresDisplayReview = false
        pending = nil
        pendingItemID = nil
        return prepared
    }

    func submit(_ accepted: MultiPlanCommandPreview, expecting lease: CommandHostLease,
                displaySession: ContentQueryReadSession? = nil, maximumUnits: Int = .max) throws {
        try enter()
        defer { operating = false }
        try coordinator.validate(lease)
        try displaySession?.validateDisplayHost(expecting: lease)
        guard !requiresDisplayReview, preview == accepted, accepted.lease == lease else { throw CommandMultiPlanIssue.stale }
        let host = try coordinator.host(lease.ownership.hostID)
        guard host.session.plan.stamp == accepted.identity.plan else { throw CommandMultiPlanIssue.stale }
        // 全体成员预检先于第一次写入，不能执行一部分后才发现未装配或未完成输入。
        for item in host.session.plan.items {
            guard let original = accepted.members[item.id],
                  try read(item, family: family(for: item.draft.commandID), lease: lease,
                           plan: accepted.identity.plan).isCovered(by: original) else {
                throw CommandMultiPlanIssue.confirmationRequired
            }
        }
        try accepted.validateExecutable()
        for members in accepted.identity.units {
            guard let first = members.first, let member = accepted.members[first] else { throw CommandMultiPlanIssue.incomplete }
            if case .output = member { continue }
            _ = try accept(member)
        }
        try validateEnvironments(Set(accepted.identity.families.values))
        try coordinator.validate(lease)
        _ = try coordinator.startMultiPlan(accepted.identity, assemblyID: id, expecting: lease)
        try advance(hostID: lease.ownership.hostID, displaySession: displaySession, maximumUnits: maximumUnits)
    }

    func resume(expecting lease: CommandHostLease, displaySession: ContentQueryReadSession? = nil, maximumUnits: Int = .max) throws {
        try enter()
        defer { operating = false }
        try coordinator.validate(lease)
        try displaySession?.validateDisplayHost(expecting: lease)
        guard pending == nil, !requiresDisplayReview else { throw CommandMultiPlanIssue.confirmationRequired }
        try advance(hostID: lease.ownership.hostID, displaySession: displaySession, maximumUnits: maximumUnits)
    }

    func confirmPending(expecting lease: CommandHostLease, displaySession: ContentQueryReadSession? = nil, maximumUnits: Int = .max) throws {
        try enter()
        defer { operating = false }
        try coordinator.validate(lease)
        try displaySession?.validateDisplayHost(expecting: lease)
        guard !requiresDisplayReview, let pending, let itemID = pendingItemID, var accepted = preview,
              let run = try coordinator.host(lease.ownership.hostID).session.execution,
              !run.hasUnknownCommit, coordinator.multiPlans.assemblies[run.stamp] == id,
              let item = run.snapshot.items.first(where: { $0.id == itemID }) else {
            throw CommandMultiPlanIssue.stale
        }
        let current = try read(item, family: family(for: item.draft.commandID), lease: pending.lease, plan: run.snapshot.stamp)
        guard current == pending else {
            // 当前事件只请求接受旧影响；显示新事实后必须等待另一次真实用户事件。
            self.pending = current
            throw CommandMultiPlanIssue.confirmationRequired
        }
        if let attempt = pendingRetry {
            let permit = try coordinator.multiPlanRetryPermit(attempt, assemblyID: id, expecting: lease)
            _ = try accept(pending, retry: permit)
            try coordinator.send(.retry(attempt, .safeLocalReplay), expecting: lease)
            pendingRetry = nil
        }
        let members = run.units.first(where: { $0.members.contains(itemID) })?.members ?? [itemID]
        for member in members { accepted.members[member] = pending }
        preview = accepted
        self.pending = nil
        pendingItemID = nil
        try advance(hostID: lease.ownership.hostID, displaySession: displaySession, maximumUnits: maximumUnits)
    }

    func retryLocal(_ attempt: CommandAttemptStamp, expecting lease: CommandHostLease,
                    displaySession: ContentQueryReadSession? = nil, maximumUnits: Int = .max) throws {
        try enter()
        defer { operating = false }
        try displaySession?.validateDisplayHost(expecting: lease)
        let permit = try coordinator.multiPlanRetryPermit(attempt, assemblyID: id, expecting: lease)
        guard let run = try coordinator.host(lease.ownership.hostID).session.execution,
              let item = run.snapshot.items.first(where: { $0.stamp == permit.item }),
              var accepted = preview, let old = accepted.members[item.id] else { throw CommandMultiPlanIssue.stale }
        let current = try read(item, family: family(for: item.draft.commandID),
                               lease: requiresDisplayReview ? lease : old.lease, plan: run.snapshot.stamp)
        if requiresDisplayReview || !current.isCovered(by: old) {
            requiresDisplayReview = false
            pending = current
            pendingItemID = item.id
            pendingRetry = attempt
            return
        }
        _ = try accept(current, retry: permit)
        try coordinator.send(.retry(attempt, .safeLocalReplay), expecting: lease)
        accepted.members[item.id] = current
        preview = accepted
        try advance(hostID: lease.ownership.hostID, displaySession: displaySession, maximumUnits: maximumUnits)
    }

    private func advance(hostID: String, displaySession: ContentQueryReadSession?, maximumUnits: Int) throws {
        guard maximumUnits > 0 else { throw CommandMultiPlanIssue.unsupported }
        var remaining = maximumUnits
        while remaining > 0 {
            let host = try coordinator.host(hostID)
            guard let run = host.session.execution, coordinator.multiPlans.assemblies[run.stamp] == id,
                  let accepted = preview, run.multiPlan == accepted.identity else { throw CommandMultiPlanIssue.stale }
            guard !run.hasUnknownCommit else { throw CommandExecutionError.requiresVerification }
            guard !run.isBusy, !coordinator.hasInvocation(host.lease.ownership) else { throw CommandExecutionError.busy }
            guard let unit = run.units.first(where: { $0.state == .ready }) else { return }
            guard let item = run.snapshot.items.first(where: { $0.id == unit.members.first }),
                  let previous = accepted.members[item.id] else { throw CommandMultiPlanIssue.unsupported }
            try displaySession?.validateDisplayHost(expecting: host.lease)
            let current: MultiPlanCommandMemberPreview
            do { current = try read(item, family: family(for: item.draft.commandID), lease: previous.lease, plan: run.snapshot.stamp) }
            catch {
                try coordinator.failMultiPlanRead(unit.id, assemblyID: id, expecting: host.lease)
                remaining -= 1
                continue
            }
            if !current.isCovered(by: previous) {
                pending = current
                pendingItemID = item.id
                return
            }
            preview?.members[item.id] = current
            let acceptanceID = try accept(current)
            try coordinator.validate(host.lease)
            let effect = try coordinator.send(.beginStep(run.stamp), expecting: host.lease)
            guard case .attempt(let attempt) = effect, attempt.unitID == unit.id,
                  let operation = run.operation(item.id) else { throw CommandMultiPlanIssue.stale }
            let executing = try coordinator.host(hostID)
            try coordinator.authorizeMultiPlanMember(.init(assemblyID: id, attempt: attempt, lease: executing.lease,
                previewLease: current.lease, acceptanceID: acceptanceID, itemID: item.id))
            remaining -= 1
            do {
                try execute(current, operation: operation, attempt: attempt, lease: executing.lease, displaySession: displaySession)
            } catch {
                let latest = try coordinator.host(hostID).session.execution
                // 只有适配已经记录确定终态，才可继续独立项；未登记失败绝不猜成未提交。
                guard let failed = latest?.units.first(where: { $0.id == unit.id }),
                      failed.local != .unknown, [.failed, .conflict, .notExecuted].contains(failed.state) else { throw error }
            }
        }
    }

    private func validateEnvironments(_ families: Set<CommandMultiPlanFamily>) throws {
        for family in families { try validateEnvironment(family) }
    }

    func validateEnvironment(_ family: CommandMultiPlanFamily) throws {
        switch family {
        case .taskCreate: _ = try taskCreate?.assembled()
        case .taskTitle: _ = try taskTitle?.assembled()
        case .taskField: _ = try taskField?.assembled()
        case .subtask: _ = try subtask?.assembled()
        case .routine, .routineCreate: _ = try routine?.assembled()
        case .batch: _ = try batch?.assembled()
        case .localSetting, .fileSettings: break
        }
    }

    /// 撤显示不清运行；重新展示须实际读取后再由当前原生事件接受。
    func invalidatePresentation() { requiresDisplayReview = true }

    func reviewRemaining(expecting lease: CommandHostLease, displaySession: ContentQueryReadSession? = nil) throws {
        try enter()
        defer { operating = false }
        try coordinator.validate(lease)
        try displaySession?.validateDisplayHost(expecting: lease)
        guard let run = try coordinator.host(lease.ownership.hostID).session.execution, !run.hasUnknownCommit,
              multiPlansOwn(run), let unit = run.units.first(where: { $0.state == .ready }),
              let item = run.snapshot.items.first(where: { unit.members.contains($0.id) }) else { throw CommandMultiPlanIssue.stale }
        let current = try read(item, family: family(for: item.draft.commandID), lease: lease, plan: run.snapshot.stamp)
        try coordinator.validate(lease)
        try displaySession?.validateDisplayHost(expecting: lease)
        pending = current
        pendingItemID = item.id
        pendingRetry = nil
        requiresDisplayReview = false
    }

    private func multiPlansOwn(_ run: CommandExecutionRun) -> Bool { coordinator.multiPlans.assemblies[run.stamp] == id }

    func canRetryLocal(_ attempt: CommandAttemptStamp, expecting lease: CommandHostLease) -> Bool {
        guard let permit = try? coordinator.multiPlanRetryPermit(attempt, assemblyID: id, expecting: lease) else { return false }
        if preview?.identity.families[permit.item.id] == .fileSettings { return fileSettings?.multiBackendNeedsRecovery == false }
        return true
    }

    func canRetryExternal(_ attempt: CommandAttemptStamp, expecting lease: CommandHostLease) -> Bool {
        fileSettings?.canRetryMultiPresentation(attempt, expecting: lease) == true
            || localSettings?.canRetryPresentation(attempt, expecting: lease) == true
    }

    func cancel(_ unitID: UUID, expecting lease: CommandHostLease) throws {
        try enter()
        defer { operating = false }
        guard let run = try coordinator.host(lease.ownership.hostID).session.execution,
              coordinator.multiPlans.assemblies[run.stamp] == id else { throw CommandMultiPlanIssue.stale }
        try coordinator.send(.cancelStep(unitID, run.stamp), expecting: lease)
        if let pendingItemID, run.units.first(where: { $0.id == unitID })?.members.contains(pendingItemID) == true {
            pending = nil
            self.pendingItemID = nil
            pendingRetry = nil
        }
    }

    func enter() throws {
        guard !operating else { throw CommandExecutionError.busy }
        operating = true
    }

    func finishOperation() { operating = false }

    func returnRemaining(_ ticket: CommandPlanReturnTicket, expecting lease: CommandHostLease,
                         displaySession: ContentQueryReadSession? = nil) throws {
        try enter()
        defer { finishOperation() }
        guard supportsRevisions else { throw CommandMultiPlanIssue.unsupported }
        try displaySession?.validateDisplayHost(expecting: lease)
        try coordinator.returnPlan(ticket, assemblyID: id, expecting: lease)
        preview = nil
        pending = nil
        pendingItemID = nil
        pendingRetry = nil
        mergeProposal = nil
        requiresDisplayReview = true
    }

    func prepareReturn(expecting lease: CommandHostLease) throws -> CommandPlanReturnTicket {
        guard supportsRevisions, !operating else { throw CommandMultiPlanIssue.recoveryUnavailable }
        if fileSettings?.multiBackendNeedsRecovery == true { throw CommandMultiPlanIssue.recoveryUnavailable }
        return try coordinator.preparePlanReturn(assemblyID: id, expecting: lease)
    }
}

struct MultiPlanCommandPreview: Equatable {
    let id: UUID
    let lease: CommandHostLease
    let identity: CommandMultiPlanIdentity
    var members: [UUID: MultiPlanCommandMemberPreview]

    func validateExecutable() throws {
        for member in members.values {
            if case .batch(let preview) = member { try preview.writeSet?.validateLimit() }
            if case .routineCreate(let preview) = member, !preview.canAccept { throw RoutineCreateIssue.invalidInput }
        }
    }
}

enum MultiPlanCommandMemberPreview: Equatable {
    case localSetting(LocalMultiPlanPreview)
    case fileSettings(FileMultiPlanPreview)
    case taskCreate(MultiPlanTaskCreationPreview)
    case taskTitle(CommandTaskTitlePreview)
    case output(CommandHostLease, CommandCreationReference)
    case taskField(CommandTaskFieldPreview)
    case subtask(CommandSubtaskPreview)
    case routine(CommandRoutinePreview)
    case routineCreate(CommandRoutineCreatePreview)
    case batch(CommandBatchPreview)

    var lease: CommandHostLease {
        switch self {
        case .localSetting(let value): return value.lease
        case .fileSettings(let value): return value.lease
        case .taskCreate(let value): return value.lease
        case .taskTitle(let value): return value.binding.lease
        case .output(let lease, _): return lease
        case .taskField(let value): return value.lease
        case .subtask(let value): return value.lease
        case .routine(let value): return value.lease
        case .routineCreate(let value): return value.lease
        case .batch(let value): return value.lease
        }
    }
}
