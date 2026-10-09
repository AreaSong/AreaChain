import Foundation

extension CommandExecutionRun {
    mutating func recordRoutineCreation(_ facts: CommandRoutineCreateFacts, attempt: CommandAttemptStamp) throws {
        let (index, result) = try facts.receipt(in: self, attempt: attempt)
        try recordMutationResult(index, result: result, conflict: false, attempt: attempt)
        units[index].routineCreation = facts
    }
    mutating func recordSubtask(_ facts: CommandSubtaskFacts, attempt: CommandAttemptStamp) throws {
        let (index, result) = try facts.receipt(in: self, attempt: attempt)
        try recordMutationResult(index, result: result, conflict: facts.conflict, attempt: attempt)
        units[index].subtask = facts
    }
    mutating func recordRoutine(_ facts: CommandRoutineFacts, attempt: CommandAttemptStamp) throws {
        let (index, result) = try facts.receipt(in: self, attempt: attempt)
        try recordMutationResult(index, result: result, conflict: facts.conflict, attempt: attempt)
        units[index].routine = facts
    }
    mutating func recordBatch(_ facts: CommandBatchFacts, attempt: CommandAttemptStamp) throws {
        let (index, result) = try facts.receipt(in: self, attempt: attempt)
        try recordMutationResult(index, result: result, conflict: facts.conflict, attempt: attempt)
        units[index].batch = facts
    }
    private mutating func recordMutationResult(_ index: Int, result: CommandExecutionResult?,
                                               conflict: Bool, attempt: CommandAttemptStamp) throws {
        guard units[index].receipt == nil, let result else { return }
        if result == .noChange {
            units[index].state = .succeeded
            units[index].receipt = .init(attempt: attempt, result: result)
        } else { try receive(.init(attempt: attempt, result: result)) }
        if conflict { units[index].state = .conflict }
        refreshReadiness()
    }

    mutating func recordTaskField(_ facts: CommandTaskFieldFacts, attempt: CommandAttemptStamp) throws {
        let (index, result) = try facts.receipt(in: self, attempt: attempt)
        try recordMutationResult(index, result: result, conflict: facts.state == .noChange ? false : facts.conflict, attempt: attempt)
        units[index].taskField = facts
    }

    func applyPreferenceGroupCommit(_ commit: CommandPreferenceGroupCommit,
                                           to unit: inout CommandExecutionUnit) throws {
        guard CommandPlanValidation.isPreferenceUnit(snapshot.items.filter { unit.members.contains($0.id) },
                                                      allowingDependencies: multiPlan != nil) else { throw CommandExecutionError.invalidResult }
        unit.preferenceGroupCommit = commit
        switch commit {
        case .noChange: unit.state = .succeeded
        case .notCommitted: unit.state = .failed
        case .committed:
            unit.local = .committed
            unit.effects = [.preferencePresentation: .pending]
            unit.state = .ready
        case .unknown:
            unit.local = .unknown
            unit.state = .verificationRequired
        case .recoveryRequired: unit.state = .failed
        case .conflict(let conflicts):
            guard !conflicts.isEmpty, conflicts.allSatisfy({ validConflict($0, unit: unit) }) else {
                throw CommandExecutionError.invalidResult
            }
            unit.conflicts = conflicts
            unit.state = .conflict
        }
    }

    /// 原未知回执不变；独立核验仅能确认同一目标的精确身份，不能转换成可重放失败。
    mutating func verifyPreferenceGroup(_ receipt: CommandExecutionReceipt) throws {
        let index = try currentIndex(receipt.attempt)
        guard units[index].local == .unknown,
              case .unknown(let expected) = units[index].preferenceGroupCommit,
              case .preferenceGroupCommit(.committed(let actual, let cleanup)) = receipt.result,
              actual == expected else { throw CommandExecutionError.requiresVerification }
        var unit = units[index]
        try applyPreferenceGroupCommit(.committed(actual, cleanupPending: cleanup), to: &unit)
        unit.preferenceVerification = receipt
        units[index] = unit
    }
}

extension CommandExecutionRun {
    /// 候选与 pending 不能发布输出；确定保存后仅允许补充发布事实，永不降级本地结果。
    mutating func recordTaskCreation(_ facts: CommandTaskCreateFacts, attempt: CommandAttemptStamp) throws {
        guard attempt.execution == stamp, attempt.phase == .local,
              let item = try taskMutationMember(attempt.unitID), item.id == attempt.unitID,
              let index = units.firstIndex(where: { $0.id == attempt.unitID }),
              units[index].attempt == attempt.number else { throw CommandExecutionError.stale }
        guard canRecordLocalFacts(attempt, unit: units[index], hasPrevious: units[index].taskCreation != nil) else {
            throw CommandExecutionError.stale
        }
        try CommandHandoffCoordinator.validateTaskCreateItem(item, composed: true, allowingDependencies: multiPlan != nil)
        if let previous = units[index].taskCreation {
            guard previous.creationID == facts.creationID,
                  previous.savedRecord == nil || previous.savedRecord == facts.savedRecord,
                  previous.savedID == nil || previous.savedID == facts.savedID,
                  previous.state != .saved || facts.state == .saved,
                  previous.state != .unknown || facts.state == .unknown else { throw CommandExecutionError.invalidResult }
        }
        guard facts.candidateID == nil || facts.candidateID == facts.creationID,
              facts.savedID == nil || facts.savedID == facts.creationID else { throw CommandExecutionError.invalidResult }
        if units[index].receipt == nil {
            let result: CommandExecutionResult
            switch facts.state {
            case .pending:
                guard facts.savedID == nil else { throw CommandExecutionError.invalidResult }
                units[index].taskCreation = facts
                return
            case .saved:
                guard facts.savedID == facts.creationID, facts.save == .returned else { throw CommandExecutionError.invalidResult }
                result = .committed(outputs: [item.id: .init(type: .todo, id: facts.creationID)],
                                    external: [.taskPublication, .notification, .calendar])
            case .unknown: result = .commitUnknown
            case .notSubmitted:
                guard facts.save == .notCalled, facts.candidateID == nil || facts.rollback == .returned else {
                    throw CommandExecutionError.invalidResult
                }
                result = .failedWithoutCommit
            }
            try receive(.init(attempt: attempt, result: result))
        }
        units[index].taskCreation = facts
    }
}

extension CommandExecutionRun {
    mutating func recordTaskTitle(_ facts: CommandTaskTitleFacts, attempt: CommandAttemptStamp) throws {
        guard attempt.execution == stamp, attempt.phase == .local,
              let item = try taskMutationMember(attempt.unitID), item.id == attempt.unitID,
              let index = units.firstIndex(where: { $0.id == attempt.unitID }),
              units[index].attempt == attempt.number, units[index].currentPhase == .local else {
            throw CommandExecutionError.stale
        }
        guard canRecordLocalFacts(attempt, unit: units[index], hasPrevious: units[index].taskTitle != nil) else {
            throw CommandExecutionError.stale
        }
        let target = snapshot.items.count == 1 && multiPlan == nil ? try CommandTaskTitlePreview.input(item: item, hostID: snapshot.stamp.hostID).target
            : resolvedInput(item.id)?.targets.objects.first
        guard target?.id == facts.targetID, snapshot.items.count == 2 || multiPlan != nil || outputs.isEmpty else { throw CommandExecutionError.invalidResult }
        if let previous = units[index].taskTitle {
            guard previous.targetID == facts.targetID,
                  previous.state == .pending || previous.state == facts.state else { throw CommandExecutionError.invalidResult }
        }
        if units[index].receipt == nil {
            let result: CommandExecutionResult
            switch facts.state {
            case .pending:
                units[index].taskTitle = facts
                refreshReadiness()
                return
            case .noChange:
                guard facts.save == .notCalled, facts.rollback == .notCalled, facts.publication == .notCalled,
                      facts.savedTagEffects == nil, !facts.registrationFailed, !facts.publicationFailed,
                      facts.conflict == nil, !facts.refreshRequested, facts.authorizationRequest == .notCalled else {
                    throw CommandExecutionError.invalidResult
                }
                units[index].state = .succeeded
                units[index].receipt = .init(attempt: attempt, result: .noChange)
                units[index].taskTitle = facts
                refreshReadiness()
                return
            case .saved:
                guard facts.save == .returned else { throw CommandExecutionError.invalidResult }
                result = .committed(outputs: [:], external: [.taskPublication, .notification, .calendar])
            case .unknown: result = .commitUnknown
            case .notSubmitted:
                guard facts.save == .notCalled else { throw CommandExecutionError.invalidResult }
                result = .failedWithoutCommit
            }
            try receive(.init(attempt: attempt, result: result))
            if facts.conflict != nil { units[index].state = .conflict }
        }
        units[index].taskTitle = facts
    }
}
