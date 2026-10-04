import Foundation

/// 运行内协调身份，不是认证凭据。只有登记它的协调者能判断其是否仍有效。
struct CommandHostOwnership: Equatable {
    let coordinatorID: UUID
    let hostID: String
    let generation: UInt64
}

struct CommandHostLease: Equatable {
    let ownership: CommandHostOwnership
    let revision: UInt64
}

struct CommandOwnedHost: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let lease: CommandHostLease
    let session: CommandHostSession
    var description: String { "CommandOwnedHost(redacted)" }
    var debugDescription: String { description }
}

struct CommandHandoffRequirements: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let replacesQuery: Bool
    let nativeSelections: Set<UUID>
    var description: String { "CommandHandoffRequirements(replacesQuery: \(replacesQuery), resources: \(nativeSelections.count))" }
    var debugDescription: String { description }
}

struct CommandHandoffTicket: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let id: UUID
    let source: CommandHostLease
    let target: CommandHostLease
    let requirements: CommandHandoffRequirements
    var description: String { "CommandHandoffTicket(id: \(id))" }
    var debugDescription: String { description }
}

/// 宿主只能在实际准备成功后提供；UUID 本身从不证明资源访问或解锁能力。
struct CommandHandoffReadiness: Equatable {
    var acceptsQueryReplacement = false
    var confirmedNativeSelections: Set<UUID> = []
}

enum CommandHandoffFailure: Equatable { case receiverUnavailable, windowPreparationFailed, resourceUnavailable, commitFailed }
enum CommandHandoffStatus: Equatable { case preparing, confirmed, completed, cancelled, failed(CommandHandoffFailure) }
enum CommandHandoffError: Error, Equatable {
    case protectedContent, stale, sameHost, duplicate, transferInProgress, ineligible, targetOccupied
    case queryReplacementRequired, resourcesUnconfirmed, receiverUnconfirmed, invalidPlan
}

/// 所有未来入口必须携带 lease 走协调者；对脱离登记的值做转移不能成为执行授权。
enum CommandHostEvent: CustomStringConvertible, CustomDebugStringConvertible {
    case query(ContentQueryEvent)
    case operation(CommandDraftEvent)
    case enqueue(CommandDraftStamp, itemID: UUID, plan: CommandPlanStamp)
    case plan(CommandPlanEvent, CommandPlanStamp)
    case removeFromPlan(CommandPlanItemStamp, CommandPlanStamp)
    case sealPlan(CommandPlanStamp, runID: UUID)
    case beginStep(CommandExecutionStamp)
    case result(CommandExecutionReceipt)
    case retry(CommandAttemptStamp, CommandRetryAssurance)
    case cancelStep(UUID, CommandExecutionStamp)
    case resolveValidation(CommandAttemptStamp, CommandValidationResolution)
    case releaseExecution(CommandExecutionStamp)

    var description: String { "CommandHostEvent(redacted)" }
    var debugDescription: String { description }
}

enum CommandHostEffect: CustomStringConvertible, CustomDebugStringConvertible {
    case none
    case query([ContentQueryIntent])
    case operation([CommandDraftIntent])
    case attempt(CommandAttemptStamp)
    case receipt(accepted: Bool)

    var description: String { "CommandHostEffect(redacted)" }
    var debugDescription: String { description }
}

extension CommandHostSession {
    mutating func applyOwnedEvent(_ event: CommandHostEvent) throws -> CommandHostEffect {
        switch event {
        case .query(let event): return .query(queryEvent(event))
        case .operation(let event): return .operation(operationEvent(event))
        case .enqueue(let draft, let id, let plan): try enqueue(draft, itemID: id, expecting: plan)
        case .plan(let event, let stamp): try planEvent(event, expecting: stamp)
        case .removeFromPlan(let item, let plan): try removeFromPlan(item, expecting: plan)
        case .sealPlan(let plan, let runID): try sealPlanForProtocol(plan, runID: runID)
        case .beginStep(let stamp): return .attempt(try beginNextProtocolStep(expecting: stamp))
        case .result(let receipt): return .receipt(accepted: try receiveProtocolResult(receipt))
        case .retry(let attempt, let assurance): try retryProtocolStep(attempt, assurance: assurance)
        case .cancelStep(let id, let stamp): try cancelUnstartedProtocolStep(id, expecting: stamp)
        case .resolveValidation(let attempt, let resolution): try resolveProtocolValidation(attempt, resolution: resolution)
        case .releaseExecution(let stamp): try releaseSuccessfulExecution(expecting: stamp)
        }
        return .none
    }
}
