import Foundation

struct MultiPlanTaskCreationPreview: Equatable {
    let lease: CommandHostLease
    let plan: CommandPlanStamp
    let item: CommandPlanItemStamp
    let evidence: CommandTaskCreateEvidence
}

extension MultiPlanCommandAdapter {
    func readTaskCreation(_ item: CommandPlanItem, lease: CommandHostLease,
                          plan: CommandPlanStamp) throws -> MultiPlanCommandMemberPreview {
        guard let adapter = taskCreate else { throw CommandMultiPlanIssue.unassembled }
        let environment = try adapter.assembled()
        let source = try adapter.readSource(environment)
        try adapter.validateSource(source)
        let evidence: CommandTaskCreateEvidence
        if adapter.capability == .ordinaryComposition {
            let preview = try CommandTaskCreatePreview.prepare(item: item, lease: lease, plan: plan,
                source: source, catalog: environment.tagCatalog.current())
            guard preview.canPrepareExecution else { throw TaskCreateCommandIssue.invalidInput }
            evidence = .init(environmentID: environment.id, contextID: ObjectIdentifier(environment.context),
                            storageID: ObjectIdentifier(environment.context.container), source: source, preview: preview)
        } else {
            try CommandHandoffCoordinator.validateTaskCreateItem(item, allowingDependencies: true)
            evidence = .init(environmentID: environment.id, contextID: ObjectIdentifier(environment.context),
                            storageID: ObjectIdentifier(environment.context.container), source: source,
                            input: try CommandTaskCreateInput(item.draft))
        }
        try environment.validateClean()
        return .taskCreate(.init(lease: lease, plan: plan, item: item.stamp, evidence: evidence))
    }

    func readTaskTitle(_ item: CommandPlanItem, lease: CommandHostLease,
                       plan: CommandPlanStamp, consumption: CommandCreationConsumption? = nil) throws -> MultiPlanCommandMemberPreview {
        guard let adapter = taskTitle else { throw CommandMultiPlanIssue.unassembled }
        let environment = try adapter.assembled()
        let targets = try consumption?.input(item).targets ?? item.draft.targets
        guard let target = targets.objects.first else { throw CommandMultiPlanIssue.incomplete }
        var preview = try environment.reading(target: target.id) {
            try environment.reader.prepareMember(item: item, targets: targets, lease: lease, plan: plan)
        }
        try environment.validateClean()
        preview.binding.multiOutput = consumption?.output
        if let consumption {
            let rows = try SwiftDataTaskRepository(context: environment.context).fetchTodos(withID: target.id)
            guard rows.count == 1 else { throw CommandMultiPlanIssue.stale }
            try consumption.output.validate(context: ObjectIdentifier(environment.context),
                                            storage: ObjectIdentifier(environment.context.container), record: rows[0].persistentModelID)
        }
        return .taskTitle(preview)
    }
}
