import Foundation

extension TaskCreateCommandAdapter {
    func tagCandidates(draft: CommandDraftStamp, expecting lease: CommandHostLease,
                       displaySession: ContentQueryReadSession,
                       evidence: CommandTaskTagCatalog.Evidence? = nil) throws -> CommandTaskTagCandidates {
        try displaySession.validateDisplayHost(expecting: lease)
        let environment = try assembledComposition()
        try coordinator.validate(lease)
        let host = try coordinator.host(lease.ownership.hostID)
        let current = host.session.plan.items.first(where: { $0.id == host.session.plan.editing })?.draft
            ?? host.session.operations.active
        guard host.session.execution == nil, host.session.operations.pending == nil,
              let current, current.stamp == draft, current.commandID.rawValue == "todo.create",
              current.targets == .none, !current.blocksUnprotectedExport,
              current.protectionRequirement == .ordinary,
              !current.arguments.contains(where: { $0.parameter == .notes }) else {
            throw TaskCreateCommandIssue.protectedContent
        }
        try validateSource(readSource(environment))
        let catalog = try evidence.map(environment.tagCatalog.validate) ?? environment.tagCatalog.current()
        try coordinator.validate(lease)
        try environment.validateClean()
        try displaySession.validateDisplayHost(expecting: lease)
        return try CommandTaskTagCandidates(catalog: catalog)
    }
}
