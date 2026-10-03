import Foundation

extension ContentQueryProviderRead {
    /// 同步入口不存在“响应重投递”。一份响应内重复业务键即来源冲突，连相同值也不能 first-wins。
    /// 原提供者已隔离的重复输入仍保留诊断；此处不靠再次去重消掉它们的不完整状态。
    var conflictingIdentities: [CommandObjectReference] {
        let counts = Dictionary(grouping: matches, by: \.id).mapValues(\.count)
        var identities = matches.filter { counts[$0.id, default: 0] > 1 }.map(\.id)
        switch self {
        case .todo(let value): identities += value.diagnostics.filter { $0.issue == .duplicateTodoID }.compactMap(\.object)
        case .subtask(let value): identities += value.diagnostics.filter {
            $0.issue == .duplicateSubtaskID || $0.issue == .duplicateTodoID
        }.compactMap(\.object)
        case .routine(let value): identities += value.diagnostics.filter { $0.issue == .duplicateRoutineID }.compactMap(\.object)
        case .diary(let value): identities += value.diagnostics.filter { $0.issue == .duplicateDiaryID }.compactMap(\.object)
        case .tag(let value): identities += value.diagnostics.filter { $0.issue == .duplicateTagID }.compactMap(\.object)
        case .clipboard(let value): identities += value.diagnostics.filter { $0.issue == .duplicateRecordID }.compactMap(\.object)
        case .trash(let value): identities += value.readingDiagnostics.filter { $0.issue == .duplicateIdentity }.compactMap(\.object)
        case .routineOccurrence(let value):
            identities += value.diagnostics.filter { $0.issue == .duplicateRoutineID }.compactMap(\.object)
        case .image: break // 关联层故意不披露隐藏图片 ID；不能回查输入来补齐。
        }
        var seen: Set<CommandObjectReference> = []
        return identities.filter { seen.insert($0).inserted }
    }

    func removingConflicts(_ identities: [CommandObjectReference]) -> Self {
        guard !identities.isEmpty else { return self }
        let conflicts = Set(identities)
        switch self {
        case .todo(var value): value.matches.removeAll { conflicts.contains($0.id) }; return .todo(value)
        case .subtask(var value): value.matches.removeAll { conflicts.contains($0.id) }; return .subtask(value)
        case .routine(var value): value.matches.removeAll { conflicts.contains($0.id) }; return .routine(value)
        case .diary(var value): value.matches.removeAll { conflicts.contains($0.id) }; return .diary(value)
        case .image(var value): value.matches.removeAll { conflicts.contains($0.id) }; return .image(value)
        case .tag(var value): value.matches.removeAll { conflicts.contains($0.id) }; return .tag(value)
        case .clipboard(var value): value.matches.removeAll { conflicts.contains($0.id) }; return .clipboard(value)
        case .routineOccurrence(var value): value.matches.removeAll { conflicts.contains($0.id) }; return .routineOccurrence(value)
        case .trash(var value):
            value.matches.removeAll { conflicts.contains($0.id) }
            // 一个展示组引用冲突身份时整体隔离该组，绝不把冲突命中降格成非命中上下文。
            value.groups.removeAll { group in
                !conflicts.isDisjoint(with: [group.source.id] + group.source.members + group.matches + group.context.map(\.id))
            }
            return .trash(value)
        }
    }
}
