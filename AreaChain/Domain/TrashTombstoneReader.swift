import Foundation

/// 墓碑专用纯值读取，不调用活图片浏览器、不查询仓储、不执行恢复/删除/文件访问。
enum TrashTombstoneReader {
    static func read(_ input: TrashTombstoneInput) -> TrashTombstoneResponse {
        let index = TrashTombstoneIndex(input)
        let projection = TrashTombstoneProjection(index)
        var objects: [TrashTombstone] = []
        var diagnostics: [TrashTombstoneDiagnostic] = []
        for id in index.rows.keys.sorted(by: TrashTombstoneIndex.precedes) {
            let rows = index.rows[id, default: []]
            // 安全边界先于重复、日期与位置诊断，私密行的异常也不能暴露图片数量。
            if rows.contains(where: projection.hides) { continue }
            if let issue = index.identityIssue(id) {
                diagnostics.append(.init(issue: issue, object: id))
                continue
            }
            guard let value = rows.first, let date = value.deletedAt else { continue }
            let relation = index.relation(for: value)
            if case .unresolved(_, let issue) = relation { diagnostics.append(.init(issue: issue, object: id)) }
            if id.type == .diary && projection.incompleteDiaries.contains(id.id) {
                diagnostics.append(.init(issue: .privacyMetadataIncomplete, object: id))
            }
            objects.append(.init(id: id, deletedAt: date, fields: projection.fields(value), relation: relation,
                                 restoration: TrashTombstoneProjection.restoration(for: id.type, relation: relation),
                                 parentAttributes: projection.parentAttributes(for: value, relation: relation)))
        }
        // 非法类型只留无位置的诊断；不回显未知归属字符串、图片身份或数量。
        if (input.images ?? []).contains(where: { $0.ownerKey == nil && $0.protection == .unprotected }) {
            diagnostics.append(.init(issue: .unknownOwnerKind, object: nil))
        }
        let coverage = Dictionary(uniqueKeysWithValues: TrashTombstoneIndex.types.map { type in
            (type, input.isProvided(type) ? input.coverage.types[type] ?? .notProvided : .notProvided)
        })
        return .init(objects: objects, groups: groups(objects, index: index, diagnostics: diagnostics),
                     diagnostics: diagnostics, typeCoverage: coverage)
    }

    private static func groups(
        _ objects: [TrashTombstone], index: TrashTombstoneIndex, diagnostics: [TrashTombstoneDiagnostic]
    ) -> [TrashTombstoneGroup] {
        let visible = Set(objects.map(\.id))
        let uncertainParents = uncertainSubtaskParents(index, diagnostics: diagnostics)
        var children: [CommandObjectReference: [CommandObjectReference]] = [:]
        var roots: [CommandObjectReference] = []
        for object in objects {
            if case .cascaded(let parent) = object.relation, visible.contains(parent) {
                children[parent, default: []].append(object.id)
            } else {
                roots.append(object.id)
            }
        }
        return roots.map { id in
            .init(id: id, members: children[id] ?? [],
                  subtaskRead: subtaskRead(id, index: index, hasUnknown: uncertainParents.contains(id)),
                  imageInputRead: imageInputRead(id, index: index),
                  imageRead: [.todo, .routine, .diary].contains(id.type) ? .displayLimited : .notApplicable)
        }
    }

    private static func subtaskRead(
        _ parent: CommandObjectReference, index: TrashTombstoneIndex, hasUnknown: Bool
    ) -> TrashMemberReadState {
        guard parent.type == .todo else { return .notApplicable }
        guard index.input.isProvided(.subtask) else { return .notProvided }
        let state = index.input.coverage.children(of: parent, type: .subtask)
        switch state {
        case .notProvided: return .notProvided
        case .partial: return .partial
        case .invalid: return .invalid
        case .completeIncludingDeleted:
            // 已声明读全但行被隔离时，不能用展开成员数宣称完整。
            return hasUnknown ? .partial : .completeIncludingDeleted
        }
    }

    private static func imageInputRead(_ parent: CommandObjectReference, index: TrashTombstoneIndex) -> TrashReadCompleteness? {
        guard [.todo, .routine, .diary].contains(parent.type) else { return nil }
        guard index.input.images != nil else { return .notProvided }
        return index.input.coverage.children(of: parent, type: .image)
    }

    private static func uncertainSubtaskParents(
        _ index: TrashTombstoneIndex, diagnostics: [TrashTombstoneDiagnostic]
    ) -> Set<CommandObjectReference> {
        var parents: Set<CommandObjectReference> = []
        for diagnostic in diagnostics {
            guard let id = diagnostic.object, id.type == .subtask else { continue }
            parents.formUnion(index.rows[id, default: []].compactMap(\.parent))
        }
        for todo in index.input.todos ?? [] where todo.subtasks.contains(where: { $0.todoId != todo.id }) {
            parents.insert(.init(type: .todo, id: todo.id))
        }
        return parents
    }
}
