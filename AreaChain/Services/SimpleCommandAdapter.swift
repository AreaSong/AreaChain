import Foundation
import SwiftData

/// X-1 简单修改指令的唯一适配器：流程固定为 prepare → accept → submit，可选只读核对未知结果。
/// 能力默认关闭；只接普通、无确认、无认证的指令。需要独立确认或认证的指令不能借此绕过，必须另行接入。
@MainActor final class SimpleCommandAdapter {
    enum Capability { case closed, open }
    let coordinator: CommandHandoffCoordinator
    let environment: SimpleCommandEnvironment?
    let capability: Capability
    private let specs: [String: any SimpleCommandSpec]

    init(coordinator: CommandHandoffCoordinator, environment: SimpleCommandEnvironment? = nil,
         specs: [any SimpleCommandSpec] = [], capability: Capability = .closed) {
        self.coordinator = coordinator
        self.environment = environment
        self.capability = capability
        self.specs = Dictionary(specs.map { ($0.command.rawValue, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func supports(_ command: CommandID) -> Bool {
        guard capability == .open, environment != nil, specs[command.rawValue] != nil,
              let descriptor = CommandCatalog.standard.command(id: command) else { return false }
        return descriptor.category == .modification && descriptor.interactions.isEmpty
    }

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
            let item = try CommandSimplePreview.input(in: host, shape: spec.shape)
            let input = try item.checkedInput()
            let before = try spec.observe(input, in: environment.context)
            let after = try spec.expect(input, from: before, in: environment.context)
            let preview = CommandSimplePreview(lease: lease, plan: plan, item: item.stamp, draft: item.draft.stamp,
                command: item.draft.commandID, input: input, environmentID: environment.id, copy: spec.copy,
                before: before, after: after)
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
            let item = try CommandSimplePreview.input(in: host, shape: spec.shape)
            guard item.stamp == preview.item, item.draft.stamp == preview.draft, try item.checkedInput() == preview.input else {
                throw CommandSimpleIssue.stale
            }
            try verifyUnchanged(preview, spec: spec, context: environment.context)
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
        try coordinator.send(.sealPlan(accepted.preview.plan, runID: UUID()), expecting: lease)
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
            try coordinator.finishTaskMutation(invocation, external: [:])
            return facts
        }
        let facts = SimpleCommandTransaction.apply(accepted, spec: spec, environment: environment) { [coordinator] facts in
            try coordinator.recordSimple(invocation, facts: facts)
        }
        if facts.state == .unknown { coordinator.simples.markUnknown(accepted.preview, acceptanceID: accepted.id) }
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
        let current = try? spec.observe(facts.input, in: reader)
        try displaySession?.validateDisplayHost(expecting: lease)
        let outcome: CommandSimpleVerification.Outcome = current == facts.after ? .applied
            : current == facts.before ? .notApplied : .inconsistent
        let verification = CommandSimpleVerification(acceptanceID: accepted.id, outcome: outcome)
        coordinator.simples.resolve(verification)
        return verification
    }

    private func revalidate(_ preview: CommandSimplePreview, spec: any SimpleCommandSpec,
                            invocation: CommandRuntimeInvocation, environment: SimpleCommandEnvironment) throws {
        try coordinator.validateRuntimeInvocation(invocation)
        guard let run = try coordinator.host(invocation.lease.ownership.hostID).session.execution else {
            throw CommandSimpleIssue.stale
        }
        _ = try preview.frozenItem(in: run, lease: invocation.lease, shape: spec.shape)
        try verifyUnchanged(preview, spec: spec, context: environment.context)
        try coordinator.validateRuntimeInvocation(invocation)
        try environment.validateClean()
    }

    private func verifyUnchanged(_ preview: CommandSimplePreview, spec: any SimpleCommandSpec, context: ModelContext) throws {
        let before = try spec.observe(preview.input, in: context)
        guard before == preview.before, try spec.expect(preview.input, from: before, in: context) == preview.after else {
            throw CommandSimpleIssue.invalidTarget(.changed)
        }
    }
}
