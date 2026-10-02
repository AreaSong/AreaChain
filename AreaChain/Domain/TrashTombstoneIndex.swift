import Foundation

/// 先保留所有同类型行，再判断唯一性；索引不能 first-wins，也不按 UUID 跨类型补父项。
struct TrashTombstoneIndex: CustomStringConvertible, CustomDebugStringConvertible {
    static let types: [CommandObjectType] = [.todo, .subtask, .routine, .diary, .tag, .image]
    let input: TrashTombstoneInput
    let rows: [CommandObjectReference: [TrashInputValue]]
    let invalidContainers: Set<CommandObjectReference>

    init(_ input: TrashTombstoneInput) {
        self.input = input
        var values = (input.todos ?? []).map(TrashInputValue.todo)
            + (input.subtasks ?? []).map(TrashInputValue.subtask)
            + (input.routines ?? []).map(TrashInputValue.routine)
            + (input.diaries ?? []).map(TrashInputValue.diary)
            + (input.tags ?? []).map(TrashInputValue.tag)
            + (input.images ?? []).map(TrashInputValue.image)
        var invalid: Set<CommandObjectReference> = []
        for todo in input.todos ?? [] {
            for child in todo.subtasks {
                let value = TrashInputValue.subtask(child)
                values.append(value)
                if child.todoId != todo.id { invalid.insert(value.id) }
            }
        }
        rows = Dictionary(grouping: values, by: \.id)
        invalidContainers = invalid
    }

    func identityIssue(_ id: CommandObjectReference) -> TrashTombstoneIssue? {
        if rows[id, default: []].count > 1 { return .duplicateIdentity }
        if invalidContainers.contains(id) { return .invalidSubtaskContainer }
        guard input.isProvided(id.type) else { return .identityNotProvided }
        switch input.coverage.identity(id) {
        case .notProvided: return .identityNotProvided
        case .partial: return .identityPartial
        case .invalid: return .invalidCoverage
        case .completeIncludingDeleted: break
        }
        if let date = rows[id]?.first?.deletedAt, !date.timeIntervalSince1970.isFinite {
            return .invalidDeletedAt
        }
        return nil
    }

    func relation(for child: TrashInputValue) -> TrashDeletionRelation {
        guard let parent = child.parent else {
            return child.id.type == .image ? .unresolved(parent: nil, issue: .unknownOwnerKind) : .root
        }
        // 局部枚举可以保留已知关系；显式无效的关联范围则不能用于级联推断。
        if input.coverage.children(of: parent, type: child.id.type) == .invalid {
            return .unresolved(parent: parent, issue: .invalidCoverage)
        }
        if let issue = parentIssue(parent) { return .unresolved(parent: parent, issue: issue) }
        guard let value = rows[parent]?.first else { return .unresolved(parent: parent, issue: .parentMissing) }
        guard value.deletedAt != nil else { return .independent(parent: parent, reason: .parentIsLive) }
        if SoftDelete.shouldRestoreChild(parentDeletedAt: value.deletedAt, childDeletedAt: child.deletedAt) {
            return .cascaded(parent: parent)
        }
        return .independent(parent: parent, reason: .timestampsDiffer)
    }

    private func parentIssue(_ parent: CommandObjectReference) -> TrashTombstoneIssue? {
        if rows[parent, default: []].count > 1 { return .parentAmbiguous }
        guard input.isProvided(parent.type) else { return .parentNotProvided }
        switch input.coverage.identity(parent) {
        case .notProvided: return .parentNotProvided
        case .partial: return .parentPartial
        case .invalid: return .parentInvalid
        case .completeIncludingDeleted: break
        }
        guard let value = rows[parent]?.first else { return .parentMissing }
        if let date = value.deletedAt, !date.timeIntervalSince1970.isFinite { return .parentInvalid }
        return nil
    }

    static func precedes(_ lhs: CommandObjectReference, _ rhs: CommandObjectReference) -> Bool {
        let left = types.firstIndex(of: lhs.type) ?? types.count
        let right = types.firstIndex(of: rhs.type) ?? types.count
        return (left, lhs.id.uuidString) < (right, rhs.id.uuidString)
    }

    var description: String { "TrashTombstoneIndex(redacted)" }
    var debugDescription: String { description }
}
