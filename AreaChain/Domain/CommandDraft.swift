import Foundation

struct CommandDraftStamp: Equatable {
    let hostID: String
    let draftID: UUID
    let version: UInt64
}

enum CommandDraftModification: Equatable { case unchanged, modified }

/// 这是静态形状报告；未来的业务校验、授权和执行接线必须另行完成。
struct CommandDraftCheck: Equatable {
    let argumentIssues: [CommandArgumentIssue]
    let targetIssues: [CommandDraftTargetIssue]
    let execution: CommandExecutionBinding
    var parametersComplete: Bool { !argumentIssues.contains { if case .missing = $0 { return true }; return false } }
    var staticallyValid: Bool { argumentIssues.isEmpty && targetIssues.isEmpty }
    var isExecutable: Bool { false }
}

/// 每份值由宿主持有，正文仅在 arguments 中编辑；基线是不可编辑的原值证据。
struct CommandDraft: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let id: UUID
    private(set) var hostID: String
    let commandID: CommandID
    private(set) var version: UInt64 = 0
    private(set) var targets: CommandDraftTargets
    private(set) var arguments: [CommandArgument]
    private(set) var baseline: CommandDraftBaseline
    private var initialTargets: CommandDraftTargets

    init(id: UUID, hostID: String, commandID: CommandID, targets: CommandDraftTargets = .none,
         baseline: CommandDraftBaseline = .init(), arguments: [CommandArgument] = []) {
        self.id = id
        self.hostID = hostID
        self.commandID = commandID
        self.targets = targets
        self.initialTargets = targets
        self.baseline = baseline
        self.arguments = arguments
    }

    var stamp: CommandDraftStamp { .init(hostID: hostID, draftID: id, version: version) }
    var modification: CommandDraftModification {
        targets != initialTargets || arguments.contains(where: changesOriginal) ? .modified : .unchanged
    }
    var description: String { "CommandDraft(id: \(id), version: \(version))" }
    var debugDescription: String { description }

    func check() -> CommandDraftCheck {
        guard let command = CommandCatalog.standard.command(id: commandID) else {
            return .init(argumentIssues: [.unavailable], targetIssues: [], execution: .unwired)
        }
        let projected = arguments + (targets.argument(for: command).map { [$0] } ?? [])
        return .init(argumentIssues: CommandArgumentValidation.issues(for: projected, command: command),
                     targetIssues: targets.issues(for: command), execution: command.execution)
    }

    private func changesOriginal(_ argument: CommandArgument) -> Bool {
        if argument.operation == .unspecified { return argument.value != nil }
        let original = baseline.original(argument.parameter, targets: targets)
        switch argument.operation {
        case .assign, .replace, .replaceAll, .setReminder:
            guard let value = argument.value else { return true }
            return original != .uniform(value)
        case .clear, .cancelReminder: return original != .absent || argument.value != nil
        default: return true
        }
    }

    // 写入入口由 reducer 校验身份；每次接受编辑都推进版本，即使内容相同也使旧确认失效。
    mutating func edit(_ argument: CommandArgument, expecting stamp: CommandDraftStamp) {
        guard self.stamp == stamp, argument.parameter != .target else { return }
        arguments.removeAll { $0.parameter == argument.parameter }
        arguments.append(argument)
        version += 1
    }

    mutating func select(_ targets: CommandDraftTargets, expecting stamp: CommandDraftStamp) {
        guard self.stamp == stamp else { return }
        self.targets = targets
        version += 1
    }

    mutating func reload(_ baseline: CommandDraftBaseline, arguments: [CommandArgument], expecting stamp: CommandDraftStamp) {
        guard self.stamp == stamp else { return }
        self.baseline = baseline
        self.arguments = arguments
        initialTargets = targets
        version += 1
    }

    mutating func activate() { version += 1 }

    /// 仅迁移运行内归属，业务身份、参数与原始选择不重建、不重新解析。
    func handedOff(to hostID: String) -> Self {
        var next = self
        next.hostID = hostID
        next.version += 1
        return next
    }
}
