import Foundation

struct CommandPlanStamp: Equatable, Hashable {
    let hostID: String
    let planID: UUID
    let revision: UInt64
}

struct CommandPlanItemStamp: Equatable, Hashable {
    let id: UUID
    let version: UInt64
}

/// 只引用声明的创建输出，不以占位 UUID 或字符串表达式充当业务对象。
struct CommandCreationReference: Equatable {
    let producer: CommandPlanItemStamp
    let outputType: CommandObjectType
}

struct CommandPlanLinks: Equatable {
    var predecessors: Set<UUID> = []
    var results: [CommandParameterID: CommandCreationReference] = [:]
    var dependencies: Set<UUID> { predecessors.union(results.values.map { $0.producer.id }) }
}

struct CommandPlanItem: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let id: UUID
    var version: UInt64 = 0
    var draft: CommandDraft
    var links = CommandPlanLinks()
    var atomicGroup: UUID?
    var mergedOrigins: [CommandDraftStamp] = []
    var returnedAttempts: [CommandAttemptStamp] = []

    var stamp: CommandPlanItemStamp { .init(id: id, version: version) }
    var description: String { "CommandPlanItem(id: \(id), version: \(version))" }
    var debugDescription: String { description }
}

enum CommandPlanEditEnd { case finish, cancelKeepingChanges }

enum CommandPlanEvent {
    case beginEditing(CommandPlanItemStamp)
    case edit(CommandPlanItemStamp, CommandArgument)
    case selectTargets(CommandPlanItemStamp, CommandDraftTargets)
    case endEditing(CommandPlanItemStamp, CommandPlanEditEnd)
    case link(CommandPlanItemStamp, CommandPlanLinks)
    case reorder([UUID])
    case atomicGroup(UUID, members: [UUID])
    case dissolveGroup(UUID)
    case merge(earlier: CommandPlanItemStamp, later: CommandPlanItemStamp)
}

enum CommandPlanError: Error, Equatable {
    case stale, duplicate, busy, excluded, invalidInput, protectedContent
    case dependents([UUID]), grouped, graph([CommandDependencyIssue])
    case mergeConflict(CommandMergeConflict), incomplete
}

/// 计划拥有唯一可编辑草稿。提交后内容移入不可编辑快照，新计划不能改写该快照。
struct CommandPlan: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let id: UUID
    let hostID: String
    private(set) var revision: UInt64 = 0
    private(set) var items: [CommandPlanItem] = []
    private(set) var editing: UUID?
    private var usedIDs: Set<UUID> = []

    init(id: UUID = UUID(), hostID: String) { self.id = id; self.hostID = hostID }
    var stamp: CommandPlanStamp { .init(hostID: hostID, planID: id, revision: revision) }
    var requiresUnsavedContentHandling: Bool { !items.isEmpty }
    var description: String { "CommandPlan(revision: \(revision), items: \(items.count))" }
    var debugDescription: String { description }

    mutating func add(_ draft: CommandDraft, id: UUID, expecting stamp: CommandPlanStamp) throws {
        guard self.stamp == stamp, draft.hostID == hostID else { throw CommandPlanError.stale }
        guard draft.protectionRequirement == .ordinary || draft.protectedReference != nil else {
            throw CommandPlanError.protectedContent
        }
        guard !usedIDs.contains(id), !items.contains(where: { $0.draft.id == draft.id }),
              !items.contains(where: { $0.atomicGroup == id }) else { throw CommandPlanError.duplicate }
        guard let command = CommandCatalog.standard.command(id: draft.commandID),
              command.queue == .eligibleAfterWiring, command.availability == .declared,
              command.category == .modification else { throw CommandPlanError.excluded }
        items.append(.init(id: id, draft: draft))
        usedIDs.insert(id)
        revision += 1
    }

    mutating func remove(_ item: CommandPlanItemStamp, expecting stamp: CommandPlanStamp) throws -> CommandDraft {
        guard self.stamp == stamp else { throw CommandPlanError.stale }
        let index = try index(of: item)
        let dependents = items.filter { $0.links.dependencies.contains(item.id) }.map(\.id)
        guard dependents.isEmpty else { throw CommandPlanError.dependents(dependents) }
        guard items[index].atomicGroup == nil else { throw CommandPlanError.grouped }
        guard editing != item.id else { throw CommandPlanError.busy }
        let removed = items.remove(at: index)
        revision += 1
        return removed.draft
    }

    mutating func apply(_ event: CommandPlanEvent, expecting stamp: CommandPlanStamp) throws {
        guard self.stamp == stamp else { throw CommandPlanError.stale }
        var next = self
        try next.change(event)
        next.revision += 1
        self = next
    }

    private mutating func change(_ event: CommandPlanEvent) throws {
        switch event {
        case .beginEditing(let stamp):
            _ = try index(of: stamp)
            guard editing == nil else { throw CommandPlanError.busy }
            editing = stamp.id
        case .edit(let stamp, let argument):
            let index = try editingIndex(stamp)
            guard items[index].draft.protectedReference == nil else { throw CommandPlanError.protectedContent }
            guard argument.parameter != .target, items[index].links.results[argument.parameter] == nil else {
                throw CommandPlanError.invalidInput
            }
            items[index].draft.edit(argument, expecting: items[index].draft.stamp)
            items[index].version += 1
        case .selectTargets(let stamp, let targets):
            let index = try editingIndex(stamp)
            guard items[index].draft.protectedReference == nil else { throw CommandPlanError.protectedContent }
            guard items[index].links.results[.target] == nil else { throw CommandPlanError.invalidInput }
            items[index].draft.select(targets, expecting: items[index].draft.stamp)
            items[index].version += 1
        case .endEditing(let stamp, _):
            _ = try editingIndex(stamp)
            editing = nil
        case .link(let stamp, let links): try link(stamp, links)
        case .reorder(let ids): try reorder(ids)
        case .atomicGroup(let id, let members): try group(id, members: members)
        case .dissolveGroup(let id):
            guard items.contains(where: { $0.atomicGroup == id }) else { throw CommandPlanError.stale }
            for index in items.indices where items[index].atomicGroup == id {
                items[index].atomicGroup = nil
                items[index].version += 1
            }
        case .merge(let earlier, let later): try merge(earlier, later)
        }
    }

    private func index(of stamp: CommandPlanItemStamp) throws -> Int {
        guard let index = items.firstIndex(where: { $0.stamp == stamp }) else { throw CommandPlanError.stale }
        return index
    }

    private func editingIndex(_ stamp: CommandPlanItemStamp) throws -> Int {
        guard editing == stamp.id else { throw CommandPlanError.busy }
        return try index(of: stamp)
    }

    private mutating func link(_ stamp: CommandPlanItemStamp, _ links: CommandPlanLinks) throws {
        let index = try index(of: stamp)
        guard !items[index].draft.blocksUnprotectedExport else { throw CommandPlanError.protectedContent }
        // 生产者编辑可同时使多个消费者过期；逐项显式修复不能被其他旧引用锁死。
        // 只暂留其他项原已存在的过期诊断，当前项及新增结构错误仍拒绝；封存/转交仍检查整图。
        let remaining = CommandPlanValidation.structure(items).filter { issue in
            if case .staleReference(let id, _) = issue { return id != stamp.id }
            return false
        }
        items[index].links = links
        items[index].version += 1
        let issues = CommandPlanValidation.structure(items).filter { !remaining.contains($0) }
        guard issues.isEmpty else { throw CommandPlanError.graph(issues) }
    }

    private mutating func reorder(_ ids: [UUID]) throws {
        guard ids.count == items.count, Set(ids) == Set(items.map(\.id)) else { throw CommandPlanError.invalidInput }
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        items = ids.compactMap { byID[$0] }
        try requireValidStructure()
    }

    private mutating func group(_ id: UUID, members: [UUID]) throws {
        guard editing == nil else { throw CommandPlanError.busy }
        guard members.count > 1, Set(members).count == members.count, !usedIDs.contains(id),
              !items.contains(where: { $0.atomicGroup == id }) else { throw CommandPlanError.invalidInput }
        for member in members {
            guard let index = items.firstIndex(where: { $0.id == member }), items[index].atomicGroup == nil,
                  CommandPlanSemantics.isAtomicSetting(items[index].draft.commandID) else { throw CommandPlanError.invalidInput }
            items[index].atomicGroup = id
            items[index].version += 1
        }
        try requireValidStructure()
        usedIDs.insert(id)
    }

    private func requireValidStructure() throws {
        let issues = CommandPlanValidation.structure(items)
        guard issues.isEmpty else { throw CommandPlanError.graph(issues) }
    }

    private mutating func merge(_ earlier: CommandPlanItemStamp, _ later: CommandPlanItemStamp) throws {
        guard editing == nil else { throw CommandPlanError.busy }
        let first = try index(of: earlier), last = try index(of: later)
        if let conflict = CommandPlanSemantics.mergeConflict(items, earlier: first, later: last) {
            throw CommandPlanError.mergeConflict(conflict)
        }
        let incoming = items[last]
        items[first].draft.edit(incoming.draft.arguments[0], expecting: items[first].draft.stamp)
        items[first].version += 1
        items[first].mergedOrigins += [incoming.draft.stamp] + incoming.mergedOrigins
        items.remove(at: last)
    }

    mutating func seal(expecting stamp: CommandPlanStamp) throws -> CommandPlanSnapshot {
        guard self.stamp == stamp else { throw CommandPlanError.stale }
        guard editing == nil else { throw CommandPlanError.busy }
        guard !items.contains(where: { $0.draft.blocksUnprotectedExport }) else { throw CommandPlanError.protectedContent }
        guard check().canSealProtocol else { throw CommandPlanError.incomplete }
        let snapshot = CommandPlanSnapshot(stamp: stamp, items: items)
        items = []
        revision += 1
        return snapshot
    }

    mutating func acceptProtection(_ reference: CommandProtectedReference, expecting stamp: CommandDraftStamp) throws {
        guard let index = items.firstIndex(where: { $0.draft.stamp == stamp }),
              items[index].links.results.isEmpty else { throw CommandPlanError.stale }
        items[index].draft.acceptProtection(reference)
        items[index].version += 1
        revision += 1
    }

    func check() -> CommandPlanCheck { CommandPlanValidation.check(items) }

    mutating func replacePreferenceBaseline(_ baseline: CommandDraftBaseline, arguments: [CommandArgument],
                                           expecting stamp: CommandDraftStamp) throws {
        guard let index = items.firstIndex(where: { $0.draft.stamp == stamp }),
              !items[index].draft.blocksUnprotectedExport else { throw CommandPlanError.stale }
        items[index].draft.reload(baseline, arguments: arguments, expecting: stamp)
        items[index].version += 1
        revision += 1
    }

    /// 唯一例外：从原运行退回已证明未提交的单项，保留项身份和旧尝试出处。
    mutating func restoreUnsubmittedPreference(_ run: CommandExecutionRun, attempt: CommandAttemptStamp) throws {
        guard items.isEmpty, editing == nil, run.stamp.plan.planID == id,
              run.snapshot.stamp.hostID == hostID, run.snapshot.items.count == 1,
              let unit = run.units.first, run.attempt(unit.id) == attempt,
              unit.local == .notSubmitted, unit.effects.isEmpty,
              [.conflict, .failed, .notExecuted].contains(unit.state), !unit.atomic,
              run.outputs.isEmpty else { throw CommandExecutionError.notRetryable }
        var item = run.snapshot.items[0]
        guard CommandPlanSemantics.isAtomicSetting(item.draft.commandID), item.links.dependencies.isEmpty,
              !item.draft.blocksUnprotectedExport else { throw CommandExecutionError.notRetryable }
        item.returnedAttempts.append(attempt)
        item.version += 1
        item.draft.activate()
        items = [item]
        revision += 1
    }

    /// 先拒绝原本失效的引用，再一次更新所有项与输出引用；不借迁移修复旧计划。
    func handedOff(to target: Self) throws -> Self {
        guard !items.contains(where: { $0.draft.blocksUnprotectedTransfer }) else { throw CommandPlanError.protectedContent }
        try requireValidStructure()
        var next = Self(id: id, hostID: target.hostID)
        next.revision = max(revision, target.revision) + 1
        next.usedIDs = usedIDs.union(target.usedIDs)
        next.editing = editing
        let stamps = Dictionary(uniqueKeysWithValues: items.map {
            ($0.stamp, CommandPlanItemStamp(id: $0.id, version: $0.version + 1))
        })
        next.items = items.map { item in
            var moved = item
            moved.version += 1
            moved.draft = item.draft.handedOff(to: target.hostID)
            moved.links.results = item.links.results.mapValues {
                .init(producer: stamps[$0.producer]!, outputType: $0.outputType)
            }
            return moved
        }
        try next.requireValidStructure()
        return next
    }

    func emptiedAfterHandoff() -> Self {
        var next = self
        next.items = []
        next.editing = nil
        next.revision += 1
        return next
    }
}

struct CommandPlanSnapshot: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let stamp: CommandPlanStamp
    let items: [CommandPlanItem]
    fileprivate init(stamp: CommandPlanStamp, items: [CommandPlanItem]) {
        self.stamp = stamp
        self.items = items
    }
    var description: String { "CommandPlanSnapshot(revision: \(stamp.revision), items: \(items.count))" }
    var debugDescription: String { description }
}

extension CommandPlanEvent: CustomStringConvertible, CustomDebugStringConvertible {
    var description: String { "CommandPlanEvent(redacted)" }
    var debugDescription: String { description }
}
