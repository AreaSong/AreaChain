import Foundation

/// 原 Plan/Run 独占输入；这里只持有不可编辑的准备、接受与核验投影。
extension UnifiedSearchController {
    var showsRoutineState: Bool {
        let drafts = (operations?.allDrafts ?? []) + (plan?.items.map(\.draft) ?? [])
            + (settingExecution?.snapshot.items.map(\.draft) ?? [])
        return drafts.contains { CommandRoutineEdit.stateCommands.contains($0.commandID.rawValue) }
    }

    var showsRoutine: Bool {
        let drafts = (operations?.allDrafts ?? []) + (plan?.items.map(\.draft) ?? [])
            + (settingExecution?.snapshot.items.map(\.draft) ?? [])
        return drafts.contains { routesRoutine($0.commandID) }
    }

    func routesRoutine(_ command: CommandID) -> Bool {
        routine?.supports(command) == true || command.rawValue == "routine.create" && routine?.supportsCreation == true
    }

    var hasRoutine: Bool {
        let drafts = (operations?.allDrafts ?? []) + (plan?.items.map(\.draft) ?? [])
        return !drafts.isEmpty && drafts.allSatisfy { routine?.supports($0.commandID) == true }
    }

    var currentRoutinePreview: CommandRoutinePreview? {
        guard operationVisible, let preview = routinePreview, let routine,
              (try? routine.validatePreview(preview, expecting: buffer.lease, displaySession: session)) != nil else { return nil }
        return preview
    }

    var currentRoutineAcceptance: CommandRoutineAcceptance? {
        guard let accepted = routineAcceptance, accepted.preview == currentRoutinePreview else { return nil }
        return accepted
    }

    var routineUnit: CommandExecutionUnit? {
        guard operationVisible, let run = settingExecution, run.snapshot.items.count == 1,
              run.snapshot.items.first.map({ CommandRoutineEdit.allCommands.contains($0.draft.commandID.rawValue) }) == true else { return nil }
        return run.units.first
    }

    func revokeRoutine() {
        routineCreatePreview = nil
        routineCreateAcceptance = nil
        routineCreateVerification = nil
        routinePreview = nil
        routineAcceptance = nil
        routineVerification = nil
    }

    private func checkRoutine(_ source: UnifiedSearchBuffer) throws {
        guard validates(source), operationVisible else { throw RoutineCommandIssue.stale }
        guard hasRoutine else { throw RoutineCommandIssue.unassembled }
        guard editingParameter == nil, tagSelection == nil, objectSelectionLocation == nil, !objectSelectionLoading,
              settingExecution == nil, let operations, operations.pending == nil, operations.retained.isEmpty,
              let plan, plan.editing == nil, plan.stamp == source.plan else {
            throw RoutineCommandIssue.unsupportedPlan
        }
        if let draft = operations.active {
            guard plan.items.isEmpty, draft.stamp == source.operation, CommandRoutineEdit.allCommands.contains(draft.commandID.rawValue) else {
                throw RoutineCommandIssue.unsupportedPlan
            }
            // 无效 shortText 的原文仍在原生拼写缓冲；不能入列后让“未填”掩盖换行等输入。
            guard draft.check().staticallyValid else { throw RoutineCommandIssue.invalidArguments }
        }
        try session.validateDisplayHost(expecting: source.lease)
    }

    func prepareRoutine(_ source: UnifiedSearchBuffer) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkRoutine(source)
            revokeRoutine()
            if let draft = operations?.active, let plan {
                try coordinator.send(.enqueue(draft.stamp, itemID: UUID(), plan: plan.stamp), expecting: source.lease)
                _ = publishOperation(text: buffer.text)
            }
            guard let plan, let routine else { throw RoutineCommandIssue.stale }
            routinePreview = try routine.prepare(plan: plan.stamp, expecting: buffer.lease, displaySession: session)
            routineFailure = nil
        } catch {
            revokeRoutine()
            routineFailure = UnifiedSearchRoutineCopy.error(error)
        }
    }

    func acceptRoutine(_ preview: CommandRoutinePreview, source: UnifiedSearchBuffer) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkRoutine(source)
            guard routinePreview == preview, let routine else { throw RoutineCommandIssue.stale }
            routineAcceptance = try routine.accept(preview, expecting: source.lease, displaySession: session)
            routineFailure = nil
        } catch {
            routineAcceptance = nil
            routineFailure = UnifiedSearchRoutineCopy.error(error)
        }
    }

    func submitRoutine(_ source: UnifiedSearchBuffer) {
        // 没有接受时快捷键保持原拒绝原因；不能用通用过期提示覆盖超限或完整性诊断。
        guard routineAcceptance != nil else { return }
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible, settingExecution == nil else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkRoutine(source)
            // 交原接受给适配器，保留最后检查的具体拒绝原因；不重准备或更换原 lease。
            guard let accepted = routineAcceptance, let routine else { throw RoutineCommandIssue.stale }
            _ = try routine.submit(accepted: accepted, expecting: source.lease, displaySession: session)
            _ = publishOperation(text: buffer.text)
            planMessage = "unified.plan.notExecutable"
        } catch {
            routineAcceptance = nil
            if settingExecution != nil {
                _ = publishOperation(text: buffer.text)
                planMessage = "unified.plan.notExecutable"
            }
            routineFailure = UnifiedSearchRoutineCopy.error(error)
        }
    }

    func verifyRoutine(_ source: UnifiedSearchBuffer) {
        guard !settingSubmitting, validates(source), operationVisible, routineUnit?.routine?.state == .unknown,
              let run = settingExecution, let item = run.snapshot.items.first,
              let operation = run.operation(item.id), let routine else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            let verification = try routine.verifyUnknown(operation, expecting: source.lease, displaySession: session)
            guard validates(source), operationVisible else { return }
            routineVerification = verification
        } catch { routineFailure = UnifiedSearchRoutineCopy.error(error) }
    }
}
