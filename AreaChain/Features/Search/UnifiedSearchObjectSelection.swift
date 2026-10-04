import Foundation

enum UnifiedSearchObjectLocation: Hashable {
    case targets, parameter(CommandParameterID)
}

/// 一次选择的 UI 身份，不是目标身份，也不拥有提交能力。
struct UnifiedSearchObjectSelectionStamp: Equatable {
    let id: UUID
    let source: UnifiedSearchBuffer
    let location: UnifiedSearchObjectLocation
    let candidateVersion: UUID
}

struct UnifiedSearchObjectSelection {
    let id = UUID()
    let source: UnifiedSearchBuffer
    let location: UnifiedSearchObjectLocation
    var browse: ContentQueryBrowseState
    var selection = CommandDraftTargets.Selection.selected
    var stamp: UnifiedSearchObjectSelectionStamp {
        .init(id: id, source: source, location: location, candidateVersion: browse.snapshot.version)
    }
    var objects: [CommandObjectReference] {
        browse.snapshot.units.flatMap(\.hits).filter { browse.selected.contains($0) }
    }
}

extension UnifiedSearchController {
    static var adaptedObjectTypes: Set<CommandObjectType> { [.todo, .subtask, .routine, .routineOccurrence] }

    func supportsObjectField(_ parameter: CommandParameter, command: CommandDescriptor) -> Bool {
        let location: UnifiedSearchObjectLocation = parameter.id == .target ? .targets : .parameter(parameter.id)
        return !objectTypes(location, command: command).isDisjoint(with: Self.adaptedObjectTypes)
            && command.interactions.isDisjoint(with: [.secureInput, .authentication, .freshAuthentication])
    }

    func objectTypes(_ location: UnifiedSearchObjectLocation, command: CommandDescriptor) -> Set<CommandObjectType> {
        if location == .targets { return command.targetTypes }
        guard case .parameter(let id) = location,
              let parameter = command.parameters.first(where: { $0.id == id }) else { return [] }
        switch parameter.type {
        case .object(let types), .objects(let types): return types
        default: return []
        }
    }

    func allowsMultipleObjects(_ location: UnifiedSearchObjectLocation, command: CommandDescriptor) -> Bool {
        if location == .targets { return command.batch == .explicitMultiple }
        guard case .parameter(let id) = location,
              let parameter = command.parameters.first(where: { $0.id == id }) else { return false }
        if case .objects = parameter.type { return true }
        return false
    }

    func selectedObjects(_ location: UnifiedSearchObjectLocation, draft: CommandDraft) -> [CommandObjectReference] {
        if location == .targets { return draft.targets.objects }
        guard case .parameter(let id) = location,
              let value = draft.arguments.first(where: { $0.parameter == id })?.value else { return [] }
        switch value {
        case .object(let object): return [object]
        case .objects(let objects): return objects
        default: return []
        }
    }

    func beginObjectSelection(_ location: UnifiedSearchObjectLocation, source: UnifiedSearchBuffer) {
        guard validates(source), operationVisible, objectSelection == nil, !objectSelectionLoading,
              let draft = editingDraft, draft.stamp == source.operation,
              let command = CommandCatalog.standard.command(id: draft.commandID),
              !objectTypes(location, command: command).isDisjoint(with: Self.adaptedObjectTypes),
              command.interactions.isDisjoint(with: [.secureInput, .authentication, .freshAuthentication]) else { return }
        objectSelectionLoading = true
        let requestID = UUID()
        objectRequestID = requestID
        objectSelectionLocation = location
        objectSelectionMessage = "unified.objects.loading"
        setObjectInputMode(true)
        let selectionSource = buffer
        // 仍读取外层的完整查询；操作路径不覆盖查询，也不产生另一个查询/目标真值。
        objectSelectionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { if self.objectRequestID == requestID { self.objectSelectionLoading = false } }
            guard !Task.isCancelled, self.objectRequestID == requestID, self.validates(selectionSource) else { return }
            do {
                _ = try await self.readObjectSource()
                guard !Task.isCancelled, self.objectRequestID == requestID else { return }
                guard self.validates(selectionSource), let page = try? self.session.presentation().pagination else {
                    self.objectSelectionMessage = "unified.objects.stale"
                    return
                }
                self.objectSelection = .init(source: self.buffer, location: location,
                                              browse: .init(snapshot: page.snapshot))
                self.objectSelectionMessage = "unified.objects.hint"
            } catch {
                if self.objectRequestID == requestID { self.objectSelectionMessage = "unified.objects.unavailable" }
            }
        }
    }

    func validatesObjectSelection(_ stamp: UnifiedSearchObjectSelectionStamp) -> Bool {
        guard objectSelection?.stamp == stamp, validates(stamp.source), operationVisible,
              editingDraft?.stamp == stamp.source.operation,
              let snapshot = try? session.presentation().pagination.snapshot else { return false }
        return snapshot.version == stamp.candidateVersion
            && snapshot.sourceID == objectSelection?.browse.snapshot.sourceID
    }

    func objectSelectionIssue(_ picker: UnifiedSearchObjectSelection) -> String? {
        guard validatesObjectSelection(picker.stamp), let draft = editingDraft,
              let command = CommandCatalog.standard.command(id: draft.commandID) else { return "unified.objects.stale" }
        let objects = picker.objects
        if objects.isEmpty { return "unified.objects.empty" }
        if objects.contains(where: { (try? session.objectCandidate($0, sourceID: picker.browse.snapshot.sourceID)) == nil }) {
            return "unified.objects.unsupported"
        }
        if objects.contains(where: { !objectTypes(picker.location, command: command).contains($0.type) }) {
            return "unified.objects.wrongType"
        }
        if !allowsMultipleObjects(picker.location, command: command), objects.count != 1 {
            return "unified.objects.singleOnly"
        }
        if picker.location == .targets {
            if !CommandDraftTargets(picker.selection, objects: objects).issues(for: command).isEmpty {
                return "unified.objects.wrongType"
            }
        } else if let argument = objectArgument(picker.location, objects: objects, command: command),
                  let parameter = command.parameters.first(where: { $0.id == argument.parameter }),
                  let value = argument.value, !CommandArgumentValidation.accepts(value, type: parameter.type) {
            return "unified.objects.wrongType"
        }
        return nil
    }

    func browseObjects(_ action: ContentQueryBrowseAction, stamp: UnifiedSearchObjectSelectionStamp) {
        guard validatesObjectSelection(stamp), var picker = objectSelection else {
            objectSelectionMessage = "unified.objects.stale"; return
        }
        let effect = picker.browse.apply(.init(version: stamp.candidateVersion, action: action))
        guard effect.rejection == nil else { return }
        switch action {
        case .selectAllKnown: picker.selection = .allResults
        case .select, .selectVisible: picker.selection = .selected
        default: break
        }
        objectSelection = picker
    }

    func toggleObject(_ object: CommandObjectReference, stamp: UnifiedSearchObjectSelectionStamp) {
        guard let picker = objectSelection else { return }
        browseObjects(.select(object, !picker.browse.selected.contains(object)), stamp: stamp)
    }

    @discardableResult
    func acceptObjects(_ stamp: UnifiedSearchObjectSelectionStamp) -> Bool {
        guard validatesObjectSelection(stamp), var picker = objectSelection else {
            objectSelectionMessage = "unified.objects.stale"; return false
        }
        if picker.objects.isEmpty, let active = picker.browse.active {
            _ = picker.browse.apply(.init(version: stamp.candidateVersion, action: .select(active, true)))
        }
        if let issue = objectSelectionIssue(picker) { objectSelectionMessage = issue; return false }
        guard let draft = editingDraft, let command = CommandCatalog.standard.command(id: draft.commandID) else { return false }
        let event: CommandDraftEvent
        if picker.location == .targets {
            let selection: CommandDraftTargets.Selection = picker.selection == .allResults ? .allResults
                : (picker.objects.count == 1 ? .single : .selected)
            event = .selectTargets(draft.stamp, .init(selection, objects: picker.objects),
                                   baseline: syntheticBaselines[command.id])
        } else {
            guard let argument = objectArgument(picker.location, objects: picker.objects, command: command) else { return false }
            event = .edit(draft.stamp, argument)
        }
        guard sendOperation(event, source: stamp.source) != nil else { return false }
        cancelObjectSelection()
        refreshObjectPresentation()
        return true
    }

    func objectArgument(_ location: UnifiedSearchObjectLocation, objects: [CommandObjectReference],
                        command: CommandDescriptor) -> CommandArgument? {
        guard case .parameter(let id) = location,
              let parameter = command.parameters.first(where: { $0.id == id }) else { return nil }
        let value: CommandValue?
        switch parameter.type {
        case .object: value = objects.count == 1 ? .object(objects[0]) : nil
        case .objects: value = .objects(objects)
        default: return nil
        }
        return .init(parameter: id, operation: parameter.defaultOperation, value: value)
    }

    func cancelObjectSelection(returnFocus: Bool = true) {
        objectRequestID = nil
        objectSelectionTask?.cancel()
        objectSelectionTask = nil
        if returnFocus { objectReturnLocation = objectSelectionLocation; objectReturnRevision &+= 1 }
        else { objectReturnLocation = nil }
        objectSelection = nil
        objectSelectionLoading = false
        objectSelectionLocation = nil
        setObjectInputMode(false)
    }

    func cancelObjectSelection(expecting id: UUID?) {
        guard let id, id == (objectSelection?.id ?? objectRequestID) else { return }
        cancelObjectSelection()
    }

    func refreshObjectPresentation() {
        objectSelectionTask?.cancel()
        let source = buffer
        objectSelectionTask = Task { @MainActor [weak self] in
            guard let self, !Task.isCancelled, self.validates(source) else { return }
            _ = try? await self.readObjectSource()
        }
    }

    func loadObjectCandidates(_ stamp: UnifiedSearchObjectSelectionStamp) {
        guard validatesObjectSelection(stamp), var picker = objectSelection,
              let page = try? session.presentation().pagination,
              (try? session.loadMore(.init(stamp: page.stamp, action: .loadMoreUnits)).didPublish) == true,
              let next = try? session.presentation().pagination.snapshot else { return }
        let effect = picker.browse.publish(next, replacing: stamp.candidateVersion)
        guard effect.rejection == nil else { return }
        objectSelection = picker
    }

    func objectPreview(_ object: CommandObjectReference) -> ContentQueryPresentationRow? {
        guard operationVisible, let snapshot = try? session.presentation().pagination.snapshot else { return nil }
        return try? session.objectCandidate(object, sourceID: snapshot.sourceID)
    }

    func removeObject(_ object: CommandObjectReference, location: UnifiedSearchObjectLocation, source: UnifiedSearchBuffer) {
        guard validates(source), operationVisible, let draft = editingDraft,
              draft.stamp == source.operation, let command = CommandCatalog.standard.command(id: draft.commandID) else { return }
        let objects = selectedObjects(location, draft: draft).filter { $0 != object }
        let event: CommandDraftEvent
        if location == .targets {
            event = .selectTargets(draft.stamp, objects.isEmpty ? .none : .init(.selected, objects: objects))
        } else {
            guard let argument = objectArgument(location, objects: objects, command: command) else { return }
            event = .edit(draft.stamp, argument)
        }
        guard sendOperation(event, source: source) != nil else { return }
        refreshObjectPresentation()
    }
}
