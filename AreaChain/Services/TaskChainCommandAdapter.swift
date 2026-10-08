import Foundation

/// 显式两步装配；所有业务写入继续通过既有创建/标题适配器，绝不重建第一步。
@MainActor final class TaskChainCommandAdapter {
    let create: TaskCreateCommandAdapter
    let title: TaskTitleCommandAdapter
    var coordinator: CommandHandoffCoordinator { create.coordinator }

    init(create: TaskCreateCommandAdapter, title: TaskTitleCommandAdapter) {
        self.create = create
        self.title = title
    }

    func validateEnvironment() throws {
        let creation = try create.assembled()
        let modification = try title.assembled()
        guard create.coordinator === title.coordinator, creation.context === modification.context else {
            throw TaskCreateCommandIssue.ineligibleEnvironment
        }
    }

    func prepareCreation(plan: CommandPlanStamp, expecting lease: CommandHostLease,
                         displaySession: ContentQueryReadSession? = nil) throws -> CommandTaskCreatePreparation {
        try displaySession?.validateDisplayHost(expecting: lease)
        try validateEnvironment()
        let environment = try create.assembled()
        return try coordinator.withTaskCreatePreparation(expecting: lease) {
            let identity = try coordinator.taskChainPlan(plan, expecting: lease)
            let item = try coordinator.host(lease.ownership.hostID).session.plan.items[0]
            let input = try CommandTaskCreateInput(item.draft)
            let source = try create.readSource(environment)
            try create.validateSource(source)
            guard try coordinator.taskChainPlan(plan, expecting: lease) == identity else { throw TaskCreateCommandIssue.stale }
            try environment.validateClean()
            try displaySession?.validateDisplayHost(expecting: lease)
            let prepared = try coordinator.taskCreations.reserve(item: item, plan: plan, lease: lease,
                evidence: .init(environmentID: environment.id, contextID: ObjectIdentifier(environment.context),
                                storageID: ObjectIdentifier(environment.context.container), source: source, input: input, chain: identity))
            try create.requireAbsent(prepared.creationID, environment: environment)
            return prepared
        }
    }

    func submitCreation(_ prepared: CommandTaskCreatePreparation, expecting lease: CommandHostLease,
                        displaySession: ContentQueryReadSession? = nil) throws -> CommandTaskCreateFacts {
        try displaySession?.validateDisplayHost(expecting: lease)
        try validateEnvironment()
        guard prepared.lease == lease, prepared.chain == (try coordinator.taskChainPlan(prepared.plan, expecting: lease)),
              coordinator.taskCreations.preparations[prepared.draft.draftID] == prepared,
              !coordinator.taskCreations.wasInvoked(prepared.id) else { throw TaskCreateCommandIssue.stale }
        try create.revalidate(prepared, environment: create.assembled())
        try displaySession?.validateDisplayHost(expecting: lease)
        return try create.submitPrepared(prepared, expecting: lease, displaySession: displaySession)
    }

    /// 原 Run 上开始消费者一次；后续重准备沿同一尝试，不重新创建也不更换输出。
    func prepareTitle(expecting lease: CommandHostLease,
                      displaySession: ContentQueryReadSession? = nil) throws -> CommandTaskTitlePreview {
        try displaySession?.validateDisplayHost(expecting: lease)
        try validateEnvironment()
        try coordinator.validate(lease)
        var host = try coordinator.host(lease.ownership.hostID)
        guard let run = host.session.execution else { throw TaskTitleCommandIssue.stale }
        _ = try coordinator.taskChainOutput(in: run)
        let consumer = run.snapshot.items[1]
        if run.units.first(where: { $0.id == consumer.id })?.state == .ready {
            _ = try coordinator.send(.beginStep(run.stamp), expecting: lease)
            host = try coordinator.host(lease.ownership.hostID)
        }
        let current = host
        return try coordinator.withTaskTitlePreparation(expecting: current.lease) {
            let binding = try coordinator.taskChainBinding(expecting: current.lease)
            let environment = try title.assembled()
            let preview = try environment.reading(target: binding.output.object.id) {
                try environment.reader.prepareChain(in: current, binding: binding)
            }
            guard try coordinator.taskChainBinding(expecting: current.lease) == binding else { throw TaskTitleCommandIssue.stale }
            try displaySession?.validateDisplayHost(expecting: current.lease)
            try environment.validateClean()
            return preview
        }
    }

    func acceptTitle(_ preview: CommandTaskTitlePreview, expecting lease: CommandHostLease,
                     displaySession: ContentQueryReadSession? = nil) throws -> CommandTaskTitleAcceptance {
        guard preview.binding.chain != nil else { throw TaskTitleCommandIssue.stale }
        try validateEnvironment()
        try title.validatePreview(preview, expecting: lease, displaySession: displaySession)
        return try coordinator.taskTitles.accept(preview)
    }

    func submitTitle(_ accepted: CommandTaskTitleAcceptance, expecting lease: CommandHostLease,
                     displaySession: ContentQueryReadSession? = nil) throws -> CommandTaskTitleFacts {
        try validateEnvironment()
        guard let binding = accepted.preview.binding.chain else { throw TaskTitleCommandIssue.stale }
        try title.validatePreview(accepted.preview, expecting: lease, displaySession: displaySession)
        guard let run = try coordinator.host(lease.ownership.hostID).session.execution,
              let operation = run.operation(binding.identity.consumer.id) else { throw TaskTitleCommandIssue.stale }
        return try title.execute(.init(lease: lease, operation: operation, attempt: binding.attempt), displaySession: displaySession)
    }
}
