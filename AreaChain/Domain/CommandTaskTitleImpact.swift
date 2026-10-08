import Foundation

enum CommandTaskTitlePreviewIssue: Error, Equatable {
    case unsupportedPlan, protectedContent, notesNotSupported, invalidArguments, emptyTitle, invalidBaseline
    case missingTarget, deletedTarget, duplicateTarget, invalidTarget, invalidTagEncoding
    case tags([CommandTaskTagProblem]), storageUnavailable, stale
}

/// 明确装配的来源身份；ordinary 由 owner 提供，不能从 todo 类型或无关键词推导。
struct CommandTaskTitleSource: Equatable {
    let environmentID: UUID
    let contextID: ObjectIdentifier
    let storageID: ObjectIdentifier
    let protection: CommandProtectionRequirement
    var revision: UUID?
}

/// 只给后续提醒/日历处理使用，不参与标题合成或冲突比较；执行时必须重新采样。
struct CommandTaskTitleContext: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let dayKey: String
    let isDone: Bool
    let calendarEventID: String
    var description: String { "CommandTaskTitleContext(redacted)" }
    var debugDescription: String { description }
}

/// 原始字段值是精确冲突证据；generic baseline 只是原 Draft 的可显示投影，不能独立授权写入。
struct CommandTaskTitleImpact: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let target: CommandObjectReference
    let edit: TaskTitleEdit
    let originalValues: [TaskTitleField: TaskTitleFieldValue]
    let tags: CommandTaskTitleTags

    var writeFields: Set<TaskTitleField> { edit.writeFields }
    var synthesisDependencies: Set<TaskTitleField> { edit.synthesisDependencies }

    /// 新标签还没有 UUID：这里只表示真实字段差异，不实现 handler 的 noChange 结果。
    var changedFields: Set<TaskTitleField> {
        var changed = Set(finalValues.compactMap { originalValues[$0.key] == $0.value ? nil : $0.key })
        if tags.finalEncodedIDs == nil { changed.insert(.tagIDs) }
        return changed
    }

    var finalValues: [TaskTitleField: TaskTitleFieldValue] {
        var values: [TaskTitleField: TaskTitleFieldValue] = [.title: .text(edit.title)]
        if let encoded = tags.finalEncodedIDs { values[.tagIDs] = .text(encoded) }
        if let priority = edit.priority {
            values[.isImportant] = .flag(priority.isImportant)
            values[.isUrgent] = .flag(priority.isUrgent)
        }
        if let minutes = edit.remindMinutes { values[.remindMinutes] = .minutes(minutes) }
        if let notes = edit.notes { values[.notes] = .text(notes) }
        return values
    }

    var baseline: CommandDraftBaseline {
        var values: [CommandDraftBaseline.Field: CommandOriginalValue] = [:]
        func put(_ parameter: CommandParameterID, _ value: CommandOriginalValue) {
            values[.init(subject: .object(target), parameter: parameter)] = value
        }
        if case .text(let title) = originalValues[.title] { put(.title, .uniform(.shortText(title))) }
        if case .text(let raw) = originalValues[.tagIDs] { put(.tags, .uniform(.tags(TagIDList.parse(raw)))) }
        if case .flag(let important) = originalValues[.isImportant], case .flag(let urgent) = originalValues[.isUrgent] {
            let priority = important ? (urgent ? "p1" : "p2") : (urgent ? "p3" : "p4")
            put(.priority, .uniform(.choice(priority)))
        }
        if case .minutes(let minutes) = originalValues[.remindMinutes] {
            put(.time, minutes.map { .uniform(.time($0)) } ?? .absent)
        }
        if case .text(let notes) = originalValues[.notes] { put(.notes, .uniform(.longText(notes))) }
        return CommandDraftBaseline(values)
    }

    var description: String { "CommandTaskTitleImpact(redacted)" }
    var debugDescription: String { description }
}

/// 标签编辑只合并。旧关联即使为普通墓碑也不自行恢复；只有输入语法命中的墓碑才有恢复效果。
struct CommandTaskTitleTags: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let syntax: CommandTaskTagPlan
    let original: [CommandTaskTagTarget]
    let final: [CommandTaskTagTarget]

    var sideEffects: [CommandTaskTagAssociation] { syntax.final.filter { $0.effect != .associateLive } }
    /// 展示实际新增关联，不把语法再次命中原关联算作新增。恢复仍是可见副作用。
    var associations: [CommandTaskTagAssociation] {
        syntax.final.filter { $0.effect != .associateLive || !original.contains($0.target) }
    }
    var finalEncodedIDs: String? {
        let ids = final.compactMap { target -> UUID? in
            guard case .existing(let row) = target else { return nil }
            return row.id
        }
        return ids.count == final.count ? TagIDList.encode(ids) : nil
    }

    static func merge(rawIDs: String, title: String, catalog: CommandTaskTagCatalog) throws -> Self {
        let lookup = CommandTaskTagLookup(catalog)
        guard lookup.catalogProblems.isEmpty else { throw CommandTaskTitlePreviewIssue.tags(lookup.catalogProblems) }
        // 非法片段可能隐藏未知关联；重复 UUID、大小写和顺序则保留原值证据后按旧算法规范化。
        let parts = rawIDs.isEmpty ? [] : rawIDs.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        guard parts.allSatisfy({ UUID(uuidString: $0) != nil }) else {
            throw CommandTaskTitlePreviewIssue.invalidTagEncoding
        }
        var final: [CommandTaskTagTarget] = []
        for id in TagIDList.normalized(TagIDList.parse(rawIDs)) {
            switch lookup.resolve(.id(id)) {
            case .success(let target): final.append(target)
            case .failure(let error): throw CommandTaskTitlePreviewIssue.tags([.init(selection: .id(id), kind: error.kind)])
            }
        }
        // 复用只读计划和 D3 资格，不调用有恢复/创建行为的 InputTagResolver。
        let original = final
        let syntax = CommandTaskTagPlanning.compose(title: title, argument: nil, catalog: catalog)
        guard syntax.problems.isEmpty else { throw CommandTaskTitlePreviewIssue.tags(syntax.problems) }
        for association in syntax.final where !final.contains(association.target) { final.append(association.target) }
        return Self(syntax: syntax, original: original, final: final)
    }

    var description: String { "CommandTaskTitleTags(redacted)" }
    var debugDescription: String { description }
}
