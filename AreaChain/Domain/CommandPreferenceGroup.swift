import Foundation

/// 完整普通标量证据；实际签发登记属于文件适配器，手工构造不授予调用权。
struct CommandPreferenceGroupBaseline: Equatable {
    let captureID: UUID
    let issuerID: UUID
    let instanceID: UUID
    let storageID: ObjectIdentifier
    let record: CommandPreferenceRecordIdentity
    let migrationID: UUID?
    let fieldRevisions: [CommandID: UInt64]
    let values: [CommandID: CommandValue]
    let groupID: UUID?
    let members: [CommandPlanItemStamp]
    let drafts: [CommandDraftStamp]
    let commands: [CommandID]
}

struct CommandPreferenceRecordIdentity: Equatable {
    let storeID: UUID
    let epoch: UUID
    let revision: UInt64
    let commitID: UUID
    let digest: String
}

/// unitID 对多项必须是 groupID，绝不以第一成员代替组身份。
struct CommandPreferenceGroupIdentity: Equatable, Hashable {
    let execution: CommandExecutionStamp
    let unitID: UUID
    let groupID: UUID?
    let members: [CommandPlanItemStamp]
}

struct CommandPreferenceBaselineUpdate {
    let draft: CommandDraftStamp
    let baseline: CommandDraftBaseline
    let arguments: [CommandArgument]
}

enum CommandPreferenceGroupCommit: Equatable {
    case noChange
    case notCommitted
    case committed(CommandPreferenceRecordIdentity, cleanupPending: Bool)
    case unknown(CommandPreferenceRecordIdentity)
    case conflict([CommandFieldConflict])
    case recoveryRequired
}

enum CommandPreferencePresentationStep: Equatable, Sendable {
    case notCalled, pending, returned, threw, superseded
}

struct CommandPreferenceGroupPresentation: Equatable {
    let appearance: CommandPreferencePresentationStep
    let event: CommandPreferencePresentationStep
    let supersededCommands: Set<CommandID>

    var incomplete: Bool { [appearance, event].contains { $0 == .threw || $0 == .pending } }
    var superseded: Bool { !supersededCommands.isEmpty || appearance == .superseded || event == .superseded }
}

extension CommandExecutionRun {
    func preferenceGroupIdentity(unitID: UUID? = nil) -> CommandPreferenceGroupIdentity? {
        guard units.count == 1 || multiPlan != nil && unitID != nil,
              let unit = units.first(where: { unitID == nil || $0.id == unitID }) else { return nil }
        let items = snapshot.items.filter { unit.members.contains($0.id) }
        guard CommandPlanValidation.isPreferenceUnit(items, allowingDependencies: multiPlan != nil) else { return nil }
        return .init(execution: stamp, unitID: unit.id, groupID: unit.atomic ? unit.id : nil, members: items.map(\.stamp))
    }
}
