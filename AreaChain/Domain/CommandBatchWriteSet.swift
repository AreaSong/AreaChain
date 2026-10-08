import Foundation
import SwiftData

/// 仅批量状态命令使用的实体预算；物理身份与类型化创建身份不能互相替代。
struct CommandBatchWriteSet: Equatable {
    enum Kind: String, CaseIterable { case todo, subtask, routine, check }
    enum Identity: Hashable {
        case stored(Kind, PersistentIdentifier)
        case creation(CommandObjectReference)
    }
    enum Value: Equatable {
        case completion(UUID, Bool)
        case definition(UUID, enabled: Bool, pause: String?)
        case check(parent: PersistentIdentifier, day: String, done: Bool, skipped: Bool)
    }
    struct Entry: Equatable {
        let identity: Identity
        let value: Value
        var kind: Kind {
            switch identity {
            case .stored(let kind, _): return kind
            case .creation: return .check
            }
        }
        var inserted: Bool { if case .creation = identity { return true }; return false }
    }
    struct Counts: Equatable {
        let selected: Int
        let changed: Int
        let inserted: [Kind: Int]
        let modified: [Kind: Int]
        let total: Int
        let limit = 4000
        var exceedsLimit: Bool { total > limit }
    }
    let entries: [Entry]
    let counts: Counts
    let limitVersion = 1
    var creationTargets: [CommandObjectReference] {
        entries.compactMap { if case .creation(let target) = $0.identity { return target }; return nil }
    }

    init(impacts: [CommandBatchTargetImpact]) throws {
        try self.init(entries: impacts.flatMap(Self.entries), selected: impacts.count,
                      changed: impacts.filter { !$0.noChange }.count)
    }

    /// 合并相同效果，拒绝互相冲突的效果；累加不依赖不受控的 Int 求和。
    init(entries candidates: [Entry], selected: Int, changed: Int) throws {
        var positions: [Identity: Int] = [:]
        var entries: [Entry] = []
        var inserted: [Kind: Int] = [:], modified: [Kind: Int] = [:]
        var total = 0
        for entry in candidates {
            if let index = positions[entry.identity] {
                guard entries[index].value == entry.value else { throw CommandBatchIssue.writeConflict }
                continue
            }
            let next = total.addingReportingOverflow(1)
            guard !next.overflow else { throw CommandBatchIssue.writeConflict }
            positions[entry.identity] = total
            entries.append(entry)
            total = next.partialValue
            // 各类型计数不超过已检查过的 total。
            if entry.inserted { inserted[entry.kind, default: 0] += 1 }
            else { modified[entry.kind, default: 0] += 1 }
        }
        self.entries = entries
        counts = .init(selected: selected, changed: changed, inserted: inserted, modified: modified, total: total)
    }

    func validateLimit() throws {
        guard limitVersion == 1 else { throw CommandBatchIssue.stale }
        guard !counts.exceedsLimit else { throw CommandBatchIssue.writeLimit(counts) }
    }

    private static func entries(_ impact: CommandBatchTargetImpact) throws -> [Entry] {
        guard let identity = impact.identity else { throw CommandBatchIssue.stale }
        if let completion = impact.completion {
            guard !impact.noChange else { return [] }
            var entries = [Entry(identity: .stored(.todo, identity), value: .completion(impact.target.id, completion.final))]
            for child in completion.affected {
                guard let physical = impact.children[child.id] else { throw CommandBatchIssue.stale }
                entries.append(.init(identity: .stored(.subtask, physical), value: .completion(child.id, true)))
            }
            return entries
        }
        guard let state = impact.state else { throw CommandBatchIssue.stale }
        var entries: [Entry] = []
        if state.finalEnabled != state.definition.isEnabled || state.finalPause != state.definition.pausedOnDayKey {
            entries.append(.init(identity: .stored(.routine, identity),
                value: .definition(impact.target.id, enabled: state.finalEnabled, pause: state.finalPause)))
        }
        for effect in state.effects where effect.action != .preserve {
            let value = Value.check(parent: identity, day: effect.day, done: effect.done, skipped: effect.skipped)
            if effect.action == .insert {
                entries.append(.init(identity: .creation(.init(type: .routineOccurrence, id: impact.target.id, dayKey: effect.day)), value: value))
            } else {
                entries += effect.original.map { .init(identity: .stored(.check, $0.identity), value: value) }
            }
        }
        return entries
    }
}
