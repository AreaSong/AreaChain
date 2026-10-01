import Foundation

enum CommandDraftSwitchChoice { case retain, discard, cancel }

enum CommandDraftDestination: Equatable {
    case start(CommandDraft)
    case restore(CommandDraftStamp)
}

struct CommandDraftDecision: Equatable {
    let revision: UInt64
    let current: CommandDraftStamp
    let destination: CommandDraftDestination
}

enum CommandDraftEvent {
    case start(expectedRevision: UInt64, CommandDraft)
    case restore(expectedRevision: UInt64, CommandDraftStamp)
    case resolve(CommandDraftDecision, CommandDraftSwitchChoice)
    case edit(CommandDraftStamp, CommandArgument)
    case selectTargets(CommandDraftStamp, CommandDraftTargets)
    /// 仅告知有新外部值；不把它写成新基线，也不保留第二份可编辑正文。
    case externalValuesArrived(CommandDraftStamp)
    /// 显式放弃该版本的修改并采用调用方提供的快照，不代表保存。
    case reloadDiscardingChanges(CommandDraftStamp, CommandDraftBaseline, [CommandArgument])
    case discardRetained(CommandDraftStamp)
}

enum CommandDraftIntent: Equatable {
    case requiresDecision(CommandDraftDecision)
    case externalValuesRequireExplicitReload(CommandDraftStamp)
    case rejectedEvent
}

struct CommandDraftTransition: Equatable {
    var state: CommandDraftSession
    var intents: [CommandDraftIntent] = []
}

/// 保留集合可枚举、可恢复，但不是待执行队列；不存在提交、完成或保存成功状态。
struct CommandDraftSession: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let hostID: String
    fileprivate(set) var revision: UInt64 = 0
    fileprivate(set) var active: CommandDraft?
    fileprivate(set) var retained: [CommandDraft] = []
    fileprivate(set) var pending: CommandDraftDecision?
    fileprivate(set) var usedIDs: Set<UUID> = []

    init(hostID: String) { self.hostID = hostID }

    /// 关闭和退出共用纯判断，包含参数有误的草稿；不发起窗口或应用动作。
    var unsavedDrafts: [CommandDraftStamp] {
        ((active.map { [$0] } ?? []) + retained).filter { $0.modification == .modified }.map(\.stamp)
    }
    var requiresUnsavedContentHandling: Bool { !unsavedDrafts.isEmpty }
    var description: String { "CommandDraftSession(revision: \(revision), retained: \(retained.count))" }
    var debugDescription: String { description }

    /// 宿主以值事务把草稿移交计划；待决切换含有内容，必须先解决，不能顺带清除。
    mutating func takeForPlan(_ stamp: CommandDraftStamp) -> CommandDraft? {
        guard pending == nil else { return nil }
        let draft: CommandDraft
        if active?.stamp == stamp, let current = active {
            draft = current
            active = nil
        } else if let index = retained.firstIndex(where: { $0.stamp == stamp }) {
            draft = retained.remove(at: index)
        } else { return nil }
        revision += 1
        return draft
    }

    mutating func retainFromPlan(_ draft: CommandDraft) -> Bool {
        guard draft.hostID == hostID, usedIDs.contains(draft.id), pending == nil,
              active?.id != draft.id, !retained.contains(where: { $0.id == draft.id }) else { return false }
        var returned = draft
        returned.activate()
        retained.append(returned)
        revision += 1
        return true
    }

    /// 调用者必须先拒绝 pending；迁移和清空都保留已消费身份，防止旧种子重放。
    func handedOff(to target: Self) -> Self {
        var next = Self(hostID: target.hostID)
        next.revision = max(revision, target.revision) + 1
        next.active = active?.handedOff(to: target.hostID)
        next.retained = retained.map { $0.handedOff(to: target.hostID) }
        next.usedIDs = usedIDs.union(target.usedIDs)
        return next
    }

    func emptiedAfterHandoff() -> Self {
        var next = self
        next.active = nil
        next.retained = []
        next.pending = nil
        next.revision += 1
        return next
    }
}

/// 只接受宿主当前版本的显式事件；没有系统 IO、自动清稿或通用事件总线。
enum CommandDraftReducer {
    static func reduce(_ state: CommandDraftSession, _ event: CommandDraftEvent) -> CommandDraftTransition {
        var next = state
        let intents = apply(event, to: &next)
        if intents.contains(.rejectedEvent) { return .init(state: state, intents: intents) }
        return .init(state: next, intents: intents)
    }

    private static func apply(_ event: CommandDraftEvent, to state: inout CommandDraftSession) -> [CommandDraftIntent] {
        switch event {
        case .start(let revision, let draft):
            guard revision == state.revision, validSeed(draft, state: state) else { return [.rejectedEvent] }
            state.usedIDs.insert(draft.id)
            return request(.start(draft), state: &state)
        case .restore(let revision, let stamp):
            guard revision == state.revision, state.retained.contains(where: { $0.stamp == stamp }) else {
                return [.rejectedEvent]
            }
            return request(.restore(stamp), state: &state)
        case .resolve(let decision, let choice): return resolve(decision, choice: choice, state: &state)
        case .discardRetained(let stamp):
            guard state.retained.contains(where: { $0.stamp == stamp }) else { return [.rejectedEvent] }
            state.retained.removeAll { $0.stamp == stamp }
            advance(&state)
        case .externalValuesArrived(let stamp):
            guard state.active?.stamp == stamp else { return [.rejectedEvent] }
            return [.externalValuesRequireExplicitReload(stamp)]
        default: return edit(event, state: &state)
        }
        return []
    }

    private static func validSeed(_ draft: CommandDraft, state: CommandDraftSession) -> Bool {
        draft.hostID == state.hostID && draft.version == 0 && !state.usedIDs.contains(draft.id)
            && CommandCatalog.standard.command(id: draft.commandID) != nil
            && validArguments(draft.arguments)
    }

    private static func validArguments(_ arguments: [CommandArgument]) -> Bool {
        !arguments.contains { $0.parameter == .target }
            && Set(arguments.map(\.parameter)).count == arguments.count
    }

    private static func request(
        _ destination: CommandDraftDestination, state: inout CommandDraftSession
    ) -> [CommandDraftIntent] {
        guard state.pending == nil else { return [.rejectedEvent] }
        if let current = state.active, current.modification == .modified {
            state.revision += 1
            let decision = CommandDraftDecision(revision: state.revision, current: current.stamp, destination: destination)
            state.pending = decision
            return [.requiresDecision(decision)]
        }
        return switchTo(destination, retain: false, state: &state)
    }

    private static func resolve(
        _ decision: CommandDraftDecision, choice: CommandDraftSwitchChoice, state: inout CommandDraftSession
    ) -> [CommandDraftIntent] {
        guard state.pending == decision, state.revision == decision.revision,
              state.active?.stamp == decision.current else { return [.rejectedEvent] }
        if choice == .cancel { advance(&state); return [] }
        return switchTo(decision.destination, retain: choice == .retain, state: &state)
    }

    private static func switchTo(
        _ destination: CommandDraftDestination, retain: Bool, state: inout CommandDraftSession
    ) -> [CommandDraftIntent] {
        var incoming: CommandDraft
        switch destination {
        case .start(let draft): incoming = draft
        case .restore(let stamp):
            guard let index = state.retained.firstIndex(where: { $0.stamp == stamp }) else { return [.rejectedEvent] }
            incoming = state.retained.remove(at: index)
        }
        if retain, let current = state.active { state.retained.append(current) }
        incoming.activate()
        state.active = incoming
        advance(&state)
        return []
    }

    private static func edit(_ event: CommandDraftEvent, state: inout CommandDraftSession) -> [CommandDraftIntent] {
        guard var draft = state.active else { return [.rejectedEvent] }
        switch event {
        case .edit(let stamp, let argument):
            guard draft.stamp == stamp, argument.parameter != .target else { return [.rejectedEvent] }
            draft.edit(argument, expecting: stamp)
        case .selectTargets(let stamp, let targets):
            guard draft.stamp == stamp else { return [.rejectedEvent] }
            draft.select(targets, expecting: stamp)
        case .reloadDiscardingChanges(let stamp, let baseline, let arguments):
            guard draft.stamp == stamp, validArguments(arguments) else { return [.rejectedEvent] }
            draft.reload(baseline, arguments: arguments, expecting: stamp)
        default: return [.rejectedEvent]
        }
        state.active = draft
        advance(&state)
        return []
    }

    private static func advance(_ state: inout CommandDraftSession) {
        state.revision += 1
        state.pending = nil
    }
}

extension CommandDraftEvent: CustomStringConvertible, CustomDebugStringConvertible {
    var description: String { "CommandDraftEvent(redacted)" }
    var debugDescription: String { description }
}
