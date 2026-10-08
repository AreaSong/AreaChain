import Foundation

/// 临时选择绑定原草稿/计划位置及完整候选证据；只有确认才发出原参数编辑事件。
struct UnifiedSearchTagSelection {
    let id = UUID()
    let source: UnifiedSearchBuffer
    let candidates: CommandTaskTagCandidates
    var selected: [UUID]
    var query = ""
    var active: UUID?
}

extension UnifiedSearchController {
    var hasTaskComposition: Bool {
        taskCreate?.capability == .ordinaryComposition && taskCreate?.supports(.init(rawValue: "todo.create")) == true
    }

    func supportsTagField(_ parameter: CommandParameter, command: CommandDescriptor) -> Bool {
        parameter.id == .tags && parameter.type == .tags
            && (hasTaskComposition && command.id.rawValue == "todo.create"
                || command.id.rawValue == "batch.tags" && batch?.supports(command.id) == true
                || command.id.rawValue == "todo.tags" && taskField?.supports(command.id) == true
                || ["routine.tags", "routine.create"].contains(command.id.rawValue) && routesRoutine(command.id)
                || ["subtask.create", "subtask.tags"].contains(command.id.rawValue) && subtask?.supports(command.id) == true)
    }

    func beginTagSelection(source: UnifiedSearchBuffer) {
        guard validates(source), operationVisible, !settingSubmitting, tagSelection == nil,
              objectSelectionLocation == nil, let draft = editingDraft, draft.stamp == source.operation,
              let command = CommandCatalog.standard.command(id: draft.commandID),
              let parameter = command.parameters.first(where: { $0.id == .tags }),
              supportsTagField(parameter, command: command), fieldOperation(parameter, draft: draft).requiresValue else { return }
        do {
            let candidates = try tagCandidates(draft: draft, source: source)
            guard validates(source) else { return }
            let argument = draft.arguments.first { $0.parameter == .tags }
            let selected: [UUID]
            if case .tags(let ids) = argument?.value { selected = ids } else { selected = [] }
            // 复用原生候选键盘模式；这个显示能力不改变操作 targets。
            setObjectInputMode(true)
            tagSelection = .init(source: buffer, candidates: candidates, selected: selected)
            inputFocused = true
        } catch { compositionFailure = UnifiedSearchTaskCompositionCopy.error(error) }
    }

    func validatesTagSelection(_ picker: UnifiedSearchTagSelection) -> Bool {
        guard tagSelection?.id == picker.id, validates(picker.source), operationVisible,
              let draft = editingDraft, draft.stamp == picker.source.operation else { return false }
        return (try? tagCandidates(draft: draft, source: picker.source, evidence: picker.candidates.evidence)) == picker.candidates
    }

    private func tagCandidates(draft: CommandDraft, source: UnifiedSearchBuffer,
                               evidence: CommandTaskTagCatalog.Evidence? = nil) throws -> CommandTaskTagCandidates {
        if draft.commandID.rawValue == "batch.tags", let batch {
            return try batch.tagCandidates(draft: draft.stamp, expecting: source.lease,
                                           displaySession: session, evidence: evidence)
        }
        if routesRoutine(draft.commandID), let routine {
            if draft.commandID.rawValue == "routine.create" {
                return try routine.creationTagCandidates(draft: draft.stamp, expecting: source.lease,
                                                         displaySession: session, evidence: evidence)
            }
            return try routine.tagCandidates(draft: draft.stamp, expecting: source.lease,
                                             displaySession: session, evidence: evidence)
        }
        if routesSubtask(draft.commandID), let subtask {
            return try subtask.tagCandidates(draft: draft.stamp, expecting: source.lease,
                                            displaySession: session, evidence: evidence)
        }
        if draft.commandID.rawValue == "todo.tags", let taskField {
            return try taskField.tagCandidates(draft: draft.stamp, expecting: source.lease,
                                               displaySession: session, evidence: evidence)
        }
        guard let taskCreate else { throw TaskFieldCommandIssue.unassembled }
        return try taskCreate.tagCandidates(draft: draft.stamp, expecting: source.lease,
                                            displaySession: session, evidence: evidence)
    }

    func updateTagQuery(_ query: String, picker: UnifiedSearchTagSelection) {
        guard validatesTagSelection(picker) else { return }
        tagSelection?.query = query
        tagSelection?.active = nil
    }

    func toggleTag(_ id: UUID, picker: UnifiedSearchTagSelection) {
        guard validatesTagSelection(picker), picker.candidates.records.contains(where: { $0.id == id }) else { return }
        if tagSelection?.selected.contains(id) == true { tagSelection?.selected.removeAll { $0 == id } }
        else { tagSelection?.selected.append(id) }
    }

    func moveTag(_ offset: Int, picker: UnifiedSearchTagSelection) {
        guard validatesTagSelection(picker) else { return }
        let rows = picker.candidates.matching(picker.query).compactMap(\.id)
        guard !rows.isEmpty else { return }
        let index = picker.active.flatMap(rows.firstIndex) ?? (offset > 0 ? -1 : rows.count)
        tagSelection?.active = rows[min(max(index + offset, 0), rows.count - 1)]
    }

    func acceptTags(_ picker: UnifiedSearchTagSelection) {
        guard taskNativeInputReady, validatesTagSelection(picker), let current = tagSelection,
              let draft = editingDraft, let command = CommandCatalog.standard.command(id: draft.commandID),
              let parameter = command.parameters.first(where: { $0.id == .tags }),
              current.selected.allSatisfy({ id in current.candidates.records.contains { $0.id == id } }) else {
            compositionFailure = "unified.composition.stale"; return
        }
        let argument = CommandArgument(parameter: .tags, operation: fieldOperation(parameter, draft: draft),
                                       value: .tags(current.selected))
        tagSelection = nil
        _ = sendOperation(.edit(draft.stamp, argument), source: picker.source)
        setObjectInputMode(false)
        inputFocused = false
        tagReturnDraftID = draft.id
        tagReturnRevision &+= 1
    }

    func cancelTags(_ id: UUID) {
        guard tagSelection?.id == id else { return }
        let draftID = tagSelection?.source.operation?.draftID
        tagSelection = nil
        setObjectInputMode(false)
        inputFocused = false
        tagReturnDraftID = draftID
        tagReturnRevision &+= 1
    }
}
