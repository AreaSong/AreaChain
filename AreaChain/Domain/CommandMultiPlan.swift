import Foundation

/// 能力清单来自显式适配装配；目录声明和纯协议 ready 均不构成执行许可。
enum CommandMultiPlanFamily: Equatable, Hashable {
    case taskCreate, taskTitle, taskField, subtask, routine, routineCreate, batch
    case localSetting, fileSettings
}

enum CommandMultiPlanIssue: Error, Equatable {
    case unassembled, unsupported, incomplete, stale, confirmationRequired, recoveryUnavailable
}

struct CommandMultiPlanIdentity: Equatable {
    let plan: CommandPlanStamp
    let members: [CommandPlanItemStamp]
    let families: [UUID: CommandMultiPlanFamily]
    let units: [[UUID]]
    let references: [UUID: CommandCreationReference]
    let outputCapability: CommandMultiPlanOutputCapability

    init(plan: CommandPlanStamp, items: [CommandPlanItem], families: [UUID: CommandMultiPlanFamily],
         outputCapability: CommandMultiPlanOutputCapability = .taskTitle) throws {
        guard items.count > 1, CommandPlanValidation.check(items).canSealProtocol else {
            throw CommandMultiPlanIssue.incomplete
        }
        guard Set(families.keys) == Set(items.map(\.id)), items.allSatisfy({
            $0.draft.hostID == plan.hostID && !$0.draft.blocksUnprotectedExport
                && $0.draft.protectionRequirement == .ordinary && $0.returnedAttempts.isEmpty
                && $0.mergedOrigins.isEmpty
        }) else { throw CommandMultiPlanIssue.unsupported }
        var units: [[UUID]] = []
        for item in items where !units.contains(where: { $0.contains(item.id) }) {
            let group = item.atomicGroup.map { id in items.filter { $0.atomicGroup == id } } ?? [item]
            if item.atomicGroup != nil {
                guard group.allSatisfy({ families[$0.id] == .fileSettings }),
                      Set(group.map { $0.draft.commandID }).count == group.count,
                      group.count <= 4 else { throw CommandMultiPlanIssue.unsupported }
            }
            units.append(group.map(\.id))
        }
        var references: [UUID: CommandCreationReference] = [:]
        var producers: Set<UUID> = []
        for item in items where !item.links.results.isEmpty {
            guard item.links.results.count == 1, let (parameter, reference) = item.links.results.first,
                  outputCapability.accepts(item.draft.commandID, parameter: parameter, type: reference.outputType),
                  let producer = items.first(where: { $0.stamp == reference.producer }),
                  CommandCatalog.standard.command(id: producer.draft.commandID)?.createdObjectType == reference.outputType else {
                throw CommandMultiPlanIssue.unsupported
            }
            if outputCapability == .taskTitle {
                guard families[item.id] == .taskTitle, families[producer.id] == .taskCreate,
                      producers.insert(producer.id).inserted, producer.links.results.isEmpty else { throw CommandMultiPlanIssue.unsupported }
                try CommandHandoffCoordinator.validateTaskCreateItem(producer, allowingDependencies: true)
            }
            references[item.id] = reference
        }
        self.plan = plan
        members = items.map(\.stamp)
        self.families = families
        self.units = units
        self.references = references
        self.outputCapability = outputCapability
    }

    func contains(_ item: CommandPlanItem) -> Bool {
        members.contains(item.stamp) && item.draft.hostID == plan.hostID
    }
}

/// 仅绑定原预览和本次真实调用的身份，不持有可编辑参数或复制 Run。
struct CommandMultiPlanAuthorization: Equatable {
    let assemblyID: UUID
    let attempt: CommandAttemptStamp
    let lease: CommandHostLease
    let previewLease: CommandHostLease
    let acceptanceID: UUID
    let itemID: UUID
}

@MainActor final class CommandMultiPlanRegistry {
    var preparing: [String: CommandHostOwnership] = [:]
    var assemblies: [CommandExecutionStamp: UUID] = [:]
    var authorizations: [CommandAttemptStamp: CommandMultiPlanAuthorization] = [:]
}

extension CommandExecutionRun {
    func permitsMember(_ id: UUID) -> Bool {
        if let multiPlan { return multiPlan.members.contains { $0.id == id } }
        return snapshot.items.count == 1 && snapshot.items[0].id == id
    }

    func previewLeaseMatches(_ preview: CommandHostLease, current: CommandHostLease, itemID: UUID) -> Bool {
        guard preview.ownership == current.ownership else { return false }
        if multiPlan != nil {
            // 实际许可还必须由协调者核对本 attempt 的显式接受登记。
            return permitsMember(itemID) && current.revision >= preview.revision
        }
        return current.revision == preview.revision + 2
    }
}
