import Foundation

enum CommandDependencyIssue: Equatable {
    case duplicateItem
    case unknown(item: UUID, predecessor: UUID), selfDependency(UUID), cycle
    case order(item: UUID, predecessor: UUID), staleReference(UUID, CommandParameterID)
    case invalidReference(UUID, CommandParameterID), invalidGroup(UUID)
}

enum CommandOperationState: Equatable {
    case needsInput, needsValidation, blocked, ready, running, waitingAuthorization, conflict
    case succeeded, failed, notExecuted, verificationRequired
}

struct CommandPlanItemCheck: Equatable {
    let item: CommandPlanItemStamp
    let arguments: [CommandArgumentIssue]
    let targets: [CommandDraftTargetIssue]
    var status: CommandOperationState {
        if arguments.contains(where: { if case .missing = $0 { return true }; return false }) { return .needsInput }
        return arguments.isEmpty && targets.isEmpty ? .needsValidation : .blocked
    }
}

struct CommandPlanCheck: Equatable {
    let items: [CommandPlanItemCheck]
    let dependencies: [CommandDependencyIssue]
    var canSealProtocol: Bool {
        !items.isEmpty && dependencies.isEmpty && items.allSatisfy { $0.arguments.isEmpty && $0.targets.isEmpty }
    }
    var isExecutable: Bool { false }
}

/// 静态检查只证明计划形状；真实存活、权限、冲突及接线仍由后续适配负责。
enum CommandPlanValidation {
    /// 仅四类普通偏好的完整单 unit；不放宽通用原子组的外部效果规则。
    static func isPreferenceUnit(_ items: [CommandPlanItem], allowingDependencies: Bool = false) -> Bool {
        guard (1...4).contains(items.count), Set(items.map { $0.draft.commandID }).count == items.count,
              allowingDependencies || structure(items).isEmpty, items.allSatisfy({
                  CommandPlanSemantics.isAtomicSetting($0.draft.commandID)
                      && (allowingDependencies || $0.links.dependencies.isEmpty) && $0.links.results.isEmpty
                      && $0.links.dependencies.isDisjoint(with: Set(items.map(\.id))) && $0.draft.targets == .none
                      && $0.draft.arguments.count == 1 && $0.draft.arguments[0].operation == .assign
                      && !$0.draft.blocksUnprotectedExport && $0.draft.check().staticallyValid
              }) else { return false }
        if items.count == 1 { return items[0].atomicGroup == nil }
        return items[0].atomicGroup != nil && items.allSatisfy { $0.atomicGroup == items[0].atomicGroup }
    }

    static func check(_ items: [CommandPlanItem]) -> CommandPlanCheck {
        .init(items: items.map(checkItem), dependencies: structure(items))
    }

    private static func checkItem(_ item: CommandPlanItem) -> CommandPlanItemCheck {
        if item.draft.blocksUnprotectedExport {
            return .init(item: item.stamp, arguments: [.protectedContent], targets: [])
        }
        let draftCheck = item.draft.check()
        let arguments = draftCheck.argumentIssues.filter { issue in
            if case .missing(let parameter) = issue, item.links.results[parameter] != nil { return false }
            return true
        }
        let targets = draftCheck.targetIssues.filter { issue in
            !(issue == .missingTargets && item.links.results[.target] != nil)
        }
        return .init(item: item.stamp, arguments: arguments, targets: targets)
    }

    static func structure(_ items: [CommandPlanItem]) -> [CommandDependencyIssue] {
        guard Set(items.map(\.id)).count == items.count else { return [.duplicateItem] }
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let positions = Dictionary(uniqueKeysWithValues: items.enumerated().map { ($0.element.id, $0.offset) })
        var issues: [CommandDependencyIssue] = []
        for item in items {
            for (id, completion) in item.links.completedPredecessors {
                if id != completion.item.id || byID[id] != nil || item.executionOrigin == nil {
                    issues.append(.unknown(item: item.id, predecessor: id))
                }
            }
            for predecessor in item.links.dependencies.sorted(by: { $0.uuidString < $1.uuidString }) {
                if predecessor == item.id { issues.append(.selfDependency(item.id)) }
                guard let position = positions[predecessor] else {
                    issues.append(.unknown(item: item.id, predecessor: predecessor))
                    continue
                }
                if position >= positions[item.id, default: 0] { issues.append(.order(item: item.id, predecessor: predecessor)) }
            }
            issues += referenceIssues(item, byID: byID)
        }
        if hasCycle(items) { issues.append(.cycle) }
        issues += groupIssues(items)
        return issues
    }

    private static func hasCycle(_ items: [CommandPlanItem]) -> Bool {
        let known = Set(items.map(\.id))
        var remaining = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.links.dependencies.intersection(known)) })
        while !remaining.isEmpty {
            let ready = Set(remaining.filter { $0.value.isEmpty }.map(\.key))
            if ready.isEmpty { return true }
            for id in ready { remaining.removeValue(forKey: id) }
            for id in Array(remaining.keys) { remaining[id]?.subtract(ready) }
        }
        return false
    }

    private static func referenceIssues(
        _ item: CommandPlanItem, byID: [UUID: CommandPlanItem]
    ) -> [CommandDependencyIssue] {
        var issues: [CommandDependencyIssue] = []
        for parameter in item.links.results.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let reference = item.links.results[parameter] else { continue }
            if let output = reference.history {
                if item.executionOrigin == nil || byID[reference.producer.id] != nil || output.producer != reference.producer
                    || output.object.type != reference.outputType || !acceptsReference(reference, parameter: parameter, item: item) {
                    issues.append(.invalidReference(item.id, parameter))
                }
                continue
            }
            guard let producer = byID[reference.producer.id] else { continue }
            if producer.stamp != reference.producer { issues.append(.staleReference(item.id, parameter)) }
            let output = CommandCatalog.standard.command(id: producer.draft.commandID)?.createdObjectType
            if output != reference.outputType || !acceptsReference(reference, parameter: parameter, item: item) {
                issues.append(.invalidReference(item.id, parameter))
            }
        }
        return issues
    }

    static func acceptsReference(
        _ reference: CommandCreationReference, parameter: CommandParameterID, item: CommandPlanItem
    ) -> Bool {
        guard !item.draft.blocksUnprotectedExport else { return false }
        guard let definition = CommandCatalog.standard.command(id: item.draft.commandID)?.parameters.first(where: { $0.id == parameter }),
              definition.operations.contains(.assign) else { return false }
        if parameter == .target && item.draft.targets != .none { return false }
        if item.draft.arguments.contains(where: { $0.parameter == parameter && ($0.operation != .unspecified || $0.value != nil) }) {
            return false
        }
        switch definition.type {
        case .object(let types), .objects(let types): return types.contains(reference.outputType)
        default: return false
        }
    }

    private static func groupIssues(_ items: [CommandPlanItem]) -> [CommandDependencyIssue] {
        let ids = Set(items.compactMap(\.atomicGroup))
        return ids.sorted { $0.uuidString < $1.uuidString }.compactMap { id in
            let indexes = items.indices.filter { items[$0].atomicGroup == id }
            let members = Set(indexes.map { items[$0].id })
            guard let first = indexes.first, let last = indexes.last else { return .invalidGroup(id) }
            let invalid = indexes.count < 2 || last - first + 1 != indexes.count || indexes.contains { index in
                !CommandPlanSemantics.isAtomicSetting(items[index].draft.commandID)
                    || !items[index].links.dependencies.isDisjoint(with: members)
            }
            return invalid ? .invalidGroup(id) : nil
        }
    }
}
