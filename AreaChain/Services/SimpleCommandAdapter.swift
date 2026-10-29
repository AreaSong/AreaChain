import Foundation
import SwiftData

/// 简单修改指令的唯一适配器：流程固定为 prepare → accept → submit，可选只读核对未知结果。
/// 能力默认关闭；只接普通指令。需要独立确认的只接声明了 `confirms` 的规格，提交前必须经共用确认面板
/// 确认，且只能单项执行；指令里从不认证——目录要求认证的，规格须对受保护目标一律拒绝（`refusesProtectedContent`）。
@MainActor final class SimpleCommandAdapter {
    enum Capability { case closed, open }
    let coordinator: CommandHandoffCoordinator
    let environment: SimpleCommandEnvironment?
    let capability: Capability
    /// 长文托管：随适配器与隔离环境存在；隐私事件取隔离环境的私有事件中心。
    let escrow: CommandLongTextEscrow?
    private let specs: [String: any SimpleCommandSpec]

    init(coordinator: CommandHandoffCoordinator, environment: SimpleCommandEnvironment? = nil,
         specs: [any SimpleCommandSpec] = [], capability: Capability = .closed) {
        self.coordinator = coordinator
        self.environment = environment
        self.capability = capability
        escrow = environment.map { CommandLongTextEscrow(coordinator: coordinator, privacy: $0.center) }
        self.specs = Dictionary(specs.map { ($0.command.rawValue, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func supports(_ command: CommandID) -> Bool {
        guard capability == .open, environment != nil, let spec = specs[command.rawValue],
              let descriptor = CommandCatalog.standard.command(id: command), descriptor.availability == .declared else { return false }
        // 目录未决或不可用的指令即使提供了规格也不装配；只接可入普通计划的修改。需要确认的只接“独立确认、无破坏性风险”的；
        // 目录要求的认证只为受保护内容，规格须对受保护目标一律拒绝（指令里从不认证）。
        guard descriptor.category == .modification, descriptor.queue == .eligibleAfterWiring else { return false }
        // 不需要确认、只要求认证的（diary.tags）同样要求规格对受保护目标一律拒绝。
        guard spec.confirms else {
            return descriptor.interactions.isEmpty
                || (spec.refusesProtectedContent && descriptor.interactions == [.authentication] && descriptor.hazards.isEmpty)
        }
        let allowed: Set<CommandInteractionRequirement> = spec.refusesProtectedContent
            ? [.independentConfirmation, .authentication] : [.independentConfirmation]
        return descriptor.interactions.contains(.independentConfirmation) && descriptor.interactions.isSubset(of: allowed)
            && descriptor.hazards.isEmpty
    }

    /// 为当前接受签发独立确认；确认前重新核对预览。
    func confirm(_ accepted: CommandSimpleAcceptance, expecting lease: CommandHostLease,
                 displaySession: ContentQueryReadSession? = nil) throws -> CommandSimpleConfirmation {
        guard try spec(accepted.preview.command).confirms else { throw CommandSimpleIssue.unsupportedPlan }
        try validatePreview(accepted.preview, expecting: lease, displaySession: displaySession)
        return try coordinator.simples.confirm(accepted)
    }

    func needsConfirmation(_ command: CommandID) -> Bool { specs[command.rawValue]?.confirms == true && supports(command) }

    func spec(_ command: CommandID) throws -> any SimpleCommandSpec {
        guard supports(command), let spec = specs[command.rawValue] else { throw CommandSimpleIssue.unassembled }
        return spec
    }

    func assembled() throws -> SimpleCommandEnvironment {
        guard capability == .open, let environment else { throw CommandSimpleIssue.unassembled }
        try environment.validateClean()
        return environment
    }

    func prepare(plan: CommandPlanStamp, expecting lease: CommandHostLease,
                 displaySession: ContentQueryReadSession? = nil) throws -> CommandSimplePreview {
        try displaySession?.validateDisplayHost(expecting: lease)
        let environment = try assembled()
        return try coordinator.withSimplePreparation(expecting: lease) {
            let host = try coordinator.host(lease.ownership.hostID)
            guard host.session.plan.stamp == plan, let draft = host.session.plan.items.first?.draft else {
                throw CommandSimpleIssue.stale
            }
            let spec = try spec(draft.commandID)
            let creation = spec.creates.map { CommandObjectReference(type: $0, id: UUID()) }
            let (item, input, before, after) = try states(host, spec: spec, creation: creation, context: environment.context)
            let preview = CommandSimplePreview(lease: lease, plan: plan, item: item.stamp, draft: item.draft.stamp,
                command: item.draft.commandID, input: input, environmentID: environment.id, copy: spec.copy,
                before: before, after: after, creation: creation)
            try coordinator.simples.requireResolved(preview.lockKeys)
            try coordinator.validate(lease)
            try environment.validateClean()
            try displaySession?.validateDisplayHost(expecting: lease)
            return preview
        }
    }

    /// 重新读取并要求与冻结预览逐字段一致；任何变化都要重新预览。
    func validatePreview(_ preview: CommandSimplePreview, expecting lease: CommandHostLease,
                         displaySession: ContentQueryReadSession? = nil) throws {
        try displaySession?.validateDisplayHost(expecting: lease)
        let environment = try assembled()
        try coordinator.withSimplePreparation(expecting: lease) {
            let host = try coordinator.host(lease.ownership.hostID)
            let spec = try spec(preview.command)
            guard preview.lease == lease, preview.environmentID == environment.id, host.session.plan.stamp == preview.plan else {
                throw CommandSimpleIssue.stale
            }
            let (_, _, before, after) = try states(host, spec: spec, creation: preview.creation, expected: preview,
                                                   context: environment.context)
            guard before == preview.before, after == preview.after else { throw CommandSimpleIssue.invalidTarget(.changed) }
            try coordinator.simples.requireResolved(preview.lockKeys)
            try coordinator.validate(lease)
            try environment.validateClean()
            try displaySession?.validateDisplayHost(expecting: lease)
        }
    }

    func accept(_ preview: CommandSimplePreview, expecting lease: CommandHostLease,
                displaySession: ContentQueryReadSession? = nil) throws -> CommandSimpleAcceptance {
        try validatePreview(preview, expecting: lease, displaySession: displaySession)
        return try coordinator.simples.accept(preview)
    }

    func submit(accepted: CommandSimpleAcceptance, expecting lease: CommandHostLease,
                displaySession: ContentQueryReadSession? = nil) throws -> CommandSimpleFacts {
        try validatePreview(accepted.preview, expecting: lease, displaySession: displaySession)
        guard coordinator.simples.acceptances[accepted.preview.draft.draftID] == accepted,
              !coordinator.simples.wasInvoked(accepted.id) else { throw CommandSimpleIssue.stale }
        if try spec(accepted.preview.command).confirms { _ = try coordinator.simples.confirmation(for: accepted) }
        if try spec(accepted.preview.command) is any SimpleLongTextCommandSpec {
            try longTextEscrow().seal(accepted, runID: UUID(), expecting: lease)
        } else {
            try coordinator.send(.sealPlan(accepted.preview.plan, runID: UUID()), expecting: lease)
        }
        var host = try coordinator.host(lease.ownership.hostID)
        guard let run = host.session.execution else { throw CommandSimpleIssue.stale }
        let effect = try coordinator.send(.beginStep(run.stamp), expecting: host.lease)
        guard case .attempt(let attempt) = effect, let operation = run.operation(accepted.preview.item.id) else {
            throw CommandSimpleIssue.stale
        }
        host = try coordinator.host(lease.ownership.hostID)
        return try execute(.init(lease: host.lease, operation: operation, attempt: attempt), displaySession: displaySession)
    }

    func execute(_ request: TaskTitleCommandRequest,
                 displaySession: ContentQueryReadSession? = nil) throws -> CommandSimpleFacts {
        let environment = try assembled()
        let accepted = try coordinator.simpleAcceptance(request)
        let spec = try spec(accepted.preview.command)
        let invocation = try coordinator.claimSimple(request)
        do {
            try revalidate(accepted.preview, spec: spec, invocation: invocation, environment: environment)
            try environment.dependencies.validateBeforeTransaction()
            try displaySession?.validateDisplayHost(expecting: invocation.lease)
        } catch {
            var facts = CommandSimpleFacts(accepted)
            facts.state = .notSubmitted
            facts.conflict = (error as? CommandSimpleIssue) == .invalidTarget(.changed)
            try coordinator.recordSimple(invocation, facts: facts)
            try coordinator.finishTaskMutation(invocation, external: [:])
            throw error
        }
        if accepted.preview.noChange {
            var facts = CommandSimpleFacts(accepted)
            facts.state = .noChange
            try coordinator.recordSimple(invocation, facts: facts)
            escrow?.settle(accepted.preview, .saved)
            try coordinator.finishTaskMutation(invocation, external: [:])
            return facts
        }
        let write = lentWrite(accepted.preview, spec: spec, invocation: invocation)
        var facts = SimpleCommandTransaction.apply(accepted, spec: spec, environment: environment, write: write) { [coordinator] facts in
            try coordinator.recordSimple(invocation, facts: facts)
        }
        if spec is any SimpleLongTextCommandSpec {
            escrow?.settle(accepted.preview, facts.state == .saved ? .saved : facts.state == .unknown ? .unknown : .notSubmitted)
        }
        if facts.state == .unknown { coordinator.simples.markUnknown(accepted.preview, acceptanceID: accepted.id) }
        // 与原界面一致：只有保存成功才发出系统后续请求。
        if facts.state == .saved { facts.followUpRequested = spec.afterSave(accepted.preview.frozenCall, in: environment.context) }
        try coordinator.recordSimple(invocation, facts: facts)
        try coordinator.finishTaskMutation(invocation, external: [
            .taskPublication: facts.publication == .returned && !facts.publicationFailed ? .succeeded : .unknown
        ])
        return facts
    }

    /// 只读核对未知结果：同容器的新 context 读当前值；不提升原回执、不恢复执行资格，只在结果确定时解除阻止。
    func verifyUnknown(_ operation: CommandOperationIdentity, expecting lease: CommandHostLease,
                       displaySession: ContentQueryReadSession? = nil) throws -> CommandSimpleVerification {
        try displaySession?.validateDisplayHost(expecting: lease)
        let environment = try assembled()
        try coordinator.validate(lease)
        guard let run = try coordinator.host(lease.ownership.hostID).session.execution,
              run.operation(operation.operationID) == operation,
              let facts = run.units.first(where: { $0.members.contains(operation.operationID) })?.simple, facts.state == .unknown,
              let item = run.snapshot.items.first(where: { $0.id == operation.operationID }),
              let accepted = coordinator.simples.acceptances[item.draft.id], accepted.id == facts.acceptanceID,
              coordinator.simples.wasInvoked(accepted.id) else { throw CommandSimpleIssue.stale }
        let spec = try spec(facts.command)
        let reader = ModelContext(environment.context.container)
        reader.autosaveEnabled = false
        let current = try? spec.observe(facts.frozenCall, in: reader)
        try displaySession?.validateDisplayHost(expecting: lease)
        let outcome: CommandSimpleVerification.Outcome = current == facts.after ? .applied
            : current == facts.before ? .notApplied : .inconsistent
        let verification = CommandSimpleVerification(acceptanceID: accepted.id, outcome: outcome)
        coordinator.simples.resolve(verification)
        // 核为已写入即销毁托管；核为未写入仍保留、不再签发，只能经 returnLongText 还回草稿。
        if outcome == .applied { escrow?.settle(accepted.preview, .saved) }
        return verification
    }

    private func revalidate(_ preview: CommandSimplePreview, spec: any SimpleCommandSpec,
                            invocation: CommandRuntimeInvocation, environment: SimpleCommandEnvironment) throws {
        try coordinator.validateRuntimeInvocation(invocation)
        guard let run = try coordinator.host(invocation.lease.ownership.hostID).session.execution else {
            throw CommandSimpleIssue.stale
        }
        _ = try preview.frozenItem(in: run, lease: invocation.lease, shape: spec.shape)
        if spec is any SimpleLongTextCommandSpec {
            // 封存后没有正文：冲突证明只比冻结行的当前值（含目标备注的带键摘要）；写后再按冻结行核对新值。
            guard try spec.observe(preview.frozenCall, in: environment.context) == preview.before else {
                throw CommandSimpleIssue.invalidTarget(.changed)
            }
            try longTextEscrow().checkLendable(invocation, preview: preview)
        } else {
            try verifyUnchanged(preview, spec: spec, context: environment.context)
        }
        try coordinator.validateRuntimeInvocation(invocation)
        try environment.validateClean()
    }

    private func verifyUnchanged(_ preview: CommandSimplePreview, spec: any SimpleCommandSpec, context: ModelContext) throws {
        let before = try spec.observe(preview.call, in: context)
        guard before == preview.before, try spec.expect(preview.call, from: before, in: context) == preview.after else {
            throw CommandSimpleIssue.invalidTarget(.changed)
        }
    }
}
