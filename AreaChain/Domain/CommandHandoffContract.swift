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

    var description: String { "CommandHostEvent(redacted)" }
    var debugDescription: String { description }
}

enum CommandHostEffect: CustomStringConvertible, CustomDebugStringConvertible {
    case none
    case query([ContentQueryIntent])

    var description: String { "CommandHostEffect(redacted)" }
    var debugDescription: String { description }
}

extension CommandHostSession {
    mutating func applyOwnedEvent(_ event: CommandHostEvent) throws -> CommandHostEffect {
        switch event {
        case .query(let event): return .query(queryEvent(event))
        }
    }
}
