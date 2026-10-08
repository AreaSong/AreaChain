import Foundation

extension UnifiedSearchController {
    var showsRoutineCreation: Bool {
        let drafts = (operations?.allDrafts ?? []) + (plan?.items.map(\.draft) ?? [])
            + (settingExecution?.snapshot.items.map(\.draft) ?? [])
        return drafts.contains { $0.commandID.rawValue == "routine.create" && routine?.supportsCreation == true }
    }
    var currentRoutineCreatePreview: CommandRoutineCreatePreview? {
        guard operationVisible, let preview = routineCreatePreview, let routine,
              (try? routine.validateCreationPreview(preview, expecting: buffer.lease, displaySession: session)) != nil else { return nil }
        return preview
    }
    var currentRoutineCreateAcceptance: CommandRoutineCreateAcceptance? {
        guard let accepted = routineCreateAcceptance, accepted.preview == currentRoutineCreatePreview else { return nil }
        return accepted
    }
    var routineCreationUnit: CommandExecutionUnit? {
        guard operationVisible, let run = settingExecution, run.snapshot.items.count == 1,
              run.snapshot.items.first?.draft.commandID.rawValue == "routine.create" else { return nil }
        return run.units.first
    }

    private func checkRoutineCreation(_ source: UnifiedSearchBuffer) throws {
        guard validates(source), operationVisible, routine?.supportsCreation == true else { throw RoutineCreateIssue.stale }
        guard editingParameter == nil, tagSelection == nil, objectSelectionLocation == nil, !objectSelectionLoading,
              settingExecution == nil, let operations, operations.pending == nil, operations.retained.isEmpty,
              let plan, plan.editing == nil, plan.stamp == source.plan else { throw RoutineCreateIssue.invalidInput }
        if let draft = operations.active {
            guard plan.items.isEmpty, draft.stamp == source.operation else { throw RoutineCreateIssue.invalidInput }
            _ = try CommandRoutineCreatePreview.input(draft)
        }
        try session.validateDisplayHost(expecting: source.lease)
    }

    func prepareRoutineCreation(_ source: UnifiedSearchBuffer) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkRoutineCreation(source)
            revokeRoutine()
            if let draft = operations?.active, let plan {
                try coordinator.send(.enqueue(draft.stamp, itemID: UUID(), plan: plan.stamp), expecting: source.lease)
                _ = publishOperation(text: buffer.text)
            }
            guard let plan, let routine else { throw RoutineCreateIssue.stale }
            routineCreatePreview = try routine.prepareCreation(plan: plan.stamp, expecting: buffer.lease, displaySession: session)
            routineCreateFailure = nil
        } catch {
            revokeRoutine()
            routineCreateFailure = UnifiedSearchRoutineCreateCopy.error(error)
        }
    }

    func acceptRoutineCreation(_ preview: CommandRoutineCreatePreview, source: UnifiedSearchBuffer) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkRoutineCreation(source)
            guard routineCreatePreview == preview, let routine else { throw RoutineCreateIssue.stale }
            routineCreateAcceptance = try routine.acceptCreation(preview, expecting: source.lease, displaySession: session)
            routineCreateFailure = nil
        } catch {
            routineCreateAcceptance = nil
            routineCreateFailure = UnifiedSearchRoutineCreateCopy.error(error)
        }
    }

    func submitRoutineCreation(_ source: UnifiedSearchBuffer) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible, settingExecution == nil else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkRoutineCreation(source)
            guard let accepted = routineCreateAcceptance, let routine else { throw RoutineCreateIssue.stale }
            _ = try routine.submitCreation(accepted: accepted, expecting: source.lease, displaySession: session)
            _ = publishOperation(text: buffer.text)
            routineCreateFailure = nil
        } catch {
            routineCreateAcceptance = nil
            if settingExecution != nil { _ = publishOperation(text: buffer.text) }
            routineCreateFailure = UnifiedSearchRoutineCreateCopy.error(error)
        }
    }

    func verifyRoutineCreation(_ source: UnifiedSearchBuffer) {
        guard !settingSubmitting, validates(source), operationVisible, routineCreationUnit?.routineCreation?.state == .unknown,
              let run = settingExecution, let item = run.snapshot.items.first,
              let operation = run.operation(item.id), let routine else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do { routineCreateVerification = try routine.verifyCreation(operation, expecting: source.lease, displaySession: session) }
        catch { routineCreateFailure = UnifiedSearchRoutineCreateCopy.error(error) }
    }
}

enum UnifiedSearchRoutineCreateCopy {
    static func error(_ error: Error) -> String {
        guard let issue = error as? RoutineCreateIssue else { return UnifiedSearchRoutineCopy.error(error) }
        switch issue {
        case .invalidWeekdays: return "unified.routineCreate.weekdays"
        case .dateChanged: return "unified.routineCreate.dateChanged"
        case .sortChanged, .unreliableSort: return "unified.routineCreate.sortChanged"
        case .notesNotSupported: return "unified.composition.notes"
        case .protectedContent: return "unified.composition.protectedContent"
        case .invalidInput: return "unified.routineCreate.input"
        case .unassembled: return "unified.routineCreate.unassembled"
        case .identityCollision: return "unified.task.storageIssue"
        case .sourceUnavailable, .stale: return "unified.routineCreate.stale"
        }
    }
}
