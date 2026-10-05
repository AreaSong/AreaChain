import Foundation

struct CommandExecutionStamp: Equatable, Hashable {
    let runID: UUID
    let plan: CommandPlanStamp
}

enum CommandExecutionPhase: Equatable, Hashable { case local, external }

struct CommandAttemptStamp: Equatable, Hashable {
    let execution: CommandExecutionStamp
    let unitID: UUID
    let number: UInt64
    let phase: CommandExecutionPhase
}

struct CommandOperationIdentity: Equatable {
    let execution: CommandExecutionStamp
    let item: CommandPlanItemStamp
    let operationID: UUID
}

enum CommandLocalCommit: Equatable { case notSubmitted, committed, unknown }
enum CommandExternalEffect: String, Hashable { case notification, calendar, preferencePresentation }
enum CommandExternalResult: Equatable { case pending, running, succeeded, failed, unknown }

/// 诊断指向快照已有基线，不复制真实当前正文或接收任意错误字符串。
struct CommandFieldConflict: Equatable {
    enum Reason: Equatable { case valueChanged, baselineUnavailable, objectUnavailable }
    let item: CommandPlanItemStamp
    let field: CommandDraftBaseline.Field
    let reason: Reason
}

enum CommandExecutionResult: Equatable {
    case noChange
    case preferenceWrite(CommandPreferenceWriteFacts)
    case preferencePresentation(CommandPreferencePresentation)
    case committed(outputs: [UUID: CommandObjectReference], external: Set<CommandExternalEffect>)
    case failedWithoutCommit, commitUnknown, notExecuted, waitingAuthorization
    case conflict([CommandFieldConflict])
    case external([CommandExternalEffect: CommandExternalResult])
}

struct CommandExecutionReceipt: Equatable {
    let attempt: CommandAttemptStamp
    let result: CommandExecutionResult
}

enum CommandExecutionBlock: Equatable {
    case predecessor(UUID), missingOutput(UUID), invalidResolvedInput(UUID)
}

/// 设置组共用一个提交结果；没有逐成员“半成功”入口，不因此宣称底层具有事务能力。
struct CommandExecutionUnit: Equatable {
    let id: UUID
    let members: [UUID]
    let atomic: Bool
    var state: CommandOperationState = .ready
    var local: CommandLocalCommit = .notSubmitted
    var effects: [CommandExternalEffect: CommandExternalResult] = [:]
    var block: CommandExecutionBlock?
    var attempt: UInt64 = 0
    var currentPhase: CommandExecutionPhase = .local
    var receipt: CommandExecutionReceipt?
    var conflicts: [CommandFieldConflict] = []
    var preferenceWrite: CommandPreferenceWriteFacts?
    var preferencePresentation: CommandPreferencePresentation?
}

enum CommandExecutionError: Error, Equatable {
    case stale, busy, noReadyUnit, invalidResult, requiresVerification, requiresAdapterConfirmation, notRetryable
}

/// 确认只能由未来适配在核验真实能力后提供；该值在纯协议中不授予调用权限。
enum CommandRetryAssurance: Equatable {
    case unverified, safeLocalReplay, idempotentExternal(Set<CommandExternalEffect>)
}

enum CommandRetryAssessment: Equatable {
    case notRetryable, requiresVerification, requiresAdapterConfirmation
    case local, external(Set<CommandExternalEffect>)
}

enum CommandCancellationAssessment: Equatable {
    case canMarkNotStarted, requiresAdapterConfirmation, cannotCancelCommitted
}

/// 仅是后续校验适配的结果形状，不是认证票据，也不能让 unwired 目录变为可执行。
enum CommandValidationResolution { case readyForProtocol, notExecuted }

struct CommandResolvedInput: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let arguments: [CommandArgument]
    let targets: CommandDraftTargets
    var description: String { "CommandResolvedInput(redacted)" }
    var debugDescription: String { description }
}

extension CommandExecutionResult: CustomStringConvertible, CustomDebugStringConvertible {
    var description: String { "CommandExecutionResult(redacted)" }
    var debugDescription: String { description }
}
