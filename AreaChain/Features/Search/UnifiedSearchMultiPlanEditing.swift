import Foundation

extension UnifiedSearchController {
    var showsMultiPlan: Bool {
        multiPlan != nil && ((plan?.items.count ?? 0) > 1 || settingExecution?.multiPlan != nil
            || plan?.items.contains(where: { $0.executionOrigin != nil }) == true)
    }

    var currentMultiPlanPreview: MultiPlanCommandPreview? {
        guard operationVisible, multiPlan?.requiresDisplayReview == false, let preview = multiPlan?.preview else { return nil }
        if settingExecution?.multiPlan == preview.identity { return preview }
        return preview.identity.plan == plan?.stamp && preview.lease == buffer.lease ? preview : nil
    }

    @discardableResult
    private func multiPlanAction(_ source: UnifiedSearchBuffer, _ work: () throws -> Void) -> Bool {
        guard !settingSubmitting, multiPlanTask == nil, validates(source), operationVisible, taskNativeInputReady,
              editingParameter == nil, objectSelectionLocation == nil, tagSelection == nil,
              !objectSelectionLoading else { return false }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try session.validateDisplayHost(expecting: source.lease)
            try work()
            multiPlanFailure = nil
        } catch { multiPlanFailure = UnifiedSearchMultiPlanCopy.error(error) }
        _ = publishOperation(text: buffer.text)
        return multiPlanFailure == nil
    }

    func prepareMultiPlan(_ source: UnifiedSearchBuffer) {
        multiPlanAction(source) {
            guard let multiPlan, let plan else { throw CommandMultiPlanIssue.unassembled }
            _ = try multiPlan.prepare(plan: plan.stamp, expecting: source.lease, displaySession: session)
        }
    }

    func submitMultiPlan(_ source: UnifiedSearchBuffer) {
        let acceptedAction = multiPlanAction(source) {
            guard let multiPlan else { throw CommandMultiPlanIssue.unassembled }
            if settingExecution == nil {
                guard let preview = currentMultiPlanPreview else { throw CommandMultiPlanIssue.confirmationRequired }
                try multiPlan.submit(preview, expecting: source.lease, displaySession: session, maximumUnits: 1)
            } else if multiPlan.requiresDisplayReview {
                try multiPlan.reviewRemaining(expecting: source.lease, displaySession: session)
            } else if multiPlan.pending != nil {
                try multiPlan.confirmPending(expecting: source.lease, displaySession: session, maximumUnits: 1)
            } else {
                try multiPlan.resume(expecting: source.lease, displaySession: session, maximumUnits: 1)
            }
        }
        if acceptedAction { continueMultiPlan() }
    }

    /// 每次本地事务仍同步串行；单元间让出主线程，显示原 Run 的进度并复核当前宿主资格。
    private func continueMultiPlan() {
        guard multiPlanTask == nil, multiPlanFailure == nil, multiPlan?.pending == nil, multiPlan?.requiresDisplayReview == false,
              let run = settingExecution, run.multiPlan != nil, !run.hasUnknownCommit,
              run.units.contains(where: { $0.state == .ready }) else { return }
        let ownership = buffer.lease.ownership
        multiPlanTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { multiPlanTask = nil; refreshOperationPresentation() }
            while !Task.isCancelled {
                await Task.yield()
                guard operationVisible, taskNativeInputReady, buffer.lease.ownership == ownership,
                      let run = settingExecution, !run.hasUnknownCommit, multiPlan?.pending == nil, multiPlan?.requiresDisplayReview == false,
                      run.units.contains(where: { $0.state == .ready }) else { return }
                do {
                    try session.validateDisplayHost(expecting: buffer.lease)
                    try multiPlan?.resume(expecting: buffer.lease, displaySession: session, maximumUnits: 1)
                } catch { multiPlanFailure = UnifiedSearchMultiPlanCopy.error(error) }
                _ = publishOperation(text: buffer.text)
                refreshOperationPresentation()
                if multiPlanFailure != nil { return }
            }
        }
    }

    func retryMultiPlan(_ attempt: CommandAttemptStamp, source: UnifiedSearchBuffer) {
        let acceptedAction = multiPlanAction(source) {
            try multiPlan?.retryLocal(attempt, expecting: source.lease, displaySession: session, maximumUnits: 1)
        }
        if acceptedAction { continueMultiPlan() }
    }

    func recoverMultiPlanExternal(_ attempt: CommandAttemptStamp, source: UnifiedSearchBuffer, verify: Bool) {
        let acceptedAction = multiPlanAction(source) {
            guard let multiPlan, settingExecution?.stamp == attempt.execution else { throw CommandMultiPlanIssue.stale }
            if let file = multiPlan.fileSettings,
               settingExecution?.preferenceGroupIdentity(unitID: attempt.unitID) != nil {
                if verify { _ = try file.verifyCommit(attempt, expecting: source.lease) }
                else { _ = try file.retryPresentation(attempt, expecting: source.lease, displaySession: session) }
            } else if let local = multiPlan.localSettings, !verify {
                _ = try local.retryPresentation(attempt, expecting: source.lease, displaySession: session)
            } else { throw CommandMultiPlanIssue.recoveryUnavailable }
        }
        if acceptedAction { continueMultiPlan() }
    }

    func recoverMultiPlanBackend(_ attempt: CommandAttemptStamp, source: UnifiedSearchBuffer) {
        multiPlanAction(source) { try multiPlan?.fileSettings?.recoverMultiBackend(attempt, expecting: source.lease) }
    }

    func cancelMultiPlanUnit(_ unitID: UUID, source: UnifiedSearchBuffer) {
        multiPlanAction(source) {
            try multiPlan?.cancel(unitID, expecting: source.lease)
        }
    }

    func returnMultiPlan(_ source: UnifiedSearchBuffer) {
        multiPlanAction(source) {
            guard let multiPlan else { throw CommandMultiPlanIssue.unassembled }
            let ticket = try multiPlan.prepareReturn(expecting: source.lease)
            try multiPlan.returnRemaining(ticket, expecting: source.lease, displaySession: session)
            editingParameter = nil
            cancelObjectSelection(returnFocus: false)
            operationExpanded = true
        }
    }
}

enum UnifiedSearchMultiPlanCopy {
    static func error(_ error: Error) -> String {
        if error as? CommandExecutionError == .requiresVerification { return "unified.multi.unknown" }
        if error as? CommandMultiPlanIssue == .externalPending { return "unified.revision.externalPending" }
        if error as? CommandMultiPlanIssue == .recoveryUnavailable { return "unified.revision.unproven" }
        if error is CommandMultiPlanIssue { return "unified.multi.unavailable" }
        if let error = error as? TaskCreateCommandIssue { return UnifiedSearchTaskCreateCopy.issue(error) }
        if error is FileLocalSettingCommandIssue { return UnifiedSearchFileSettingCopy.issue(error) }
        if let error = error as? LocalSettingCommandIssue { return UnifiedSearchSettingCopy.issue(error) }
        if error is SubtaskCommandIssue { return UnifiedSearchSubtaskCopy.error(error) }
        if error is RoutineCommandIssue || error is RoutineCreateIssue { return UnifiedSearchRoutineCopy.error(error) }
        return UnifiedSearchTaskTitleCopy.error(error)
    }

    static func status(_ unit: CommandExecutionUnit) -> String {
        if unit.local == .unknown { return "unified.multi.unknown" }
        if unit.state == .notExecuted && unit.attempt == 0 { return "unified.multi.cancelled" }
        if unit.state == .succeeded { return unit.local == .committed ? "unified.multi.saved" : "unified.multi.noChange" }
        switch unit.state {
        case .failed, .conflict: return "unified.multi.failed"
        case .running: return "unified.multi.running"
        case .blocked: return "unified.multi.blocked"
        case .verificationRequired: return "unified.multi.externalUnknown"
        case .waitingAuthorization: return "unified.multi.confirm"
        default: return "unified.multi.notExecuted"
        }
    }
}
