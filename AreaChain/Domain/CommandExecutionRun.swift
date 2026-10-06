import Foundation

/// 只消费显式生命周期事件和结果事实，不拥有 handler、时钟、仓储或系统服务。
/// snapshot 是本次运行唯一参数所有者；适配必须另查目录接线及业务资格。
struct CommandExecutionRun: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let stamp: CommandExecutionStamp
    let snapshot: CommandPlanSnapshot
    private(set) var units: [CommandExecutionUnit]
    private(set) var outputs: [UUID: CommandObjectReference] = [:]
    private(set) var bindings: [UUID: [CommandParameterID: CommandObjectReference]] = [:]

    init(id: UUID, snapshot: CommandPlanSnapshot) {
        self.stamp = .init(runID: id, plan: snapshot.stamp)
        self.snapshot = snapshot
        var units: [CommandExecutionUnit] = []
        for item in snapshot.items {
            let id = item.atomicGroup ?? item.id
            if units.contains(where: { $0.id == id }) { continue }
            let members = snapshot.items.filter { ($0.atomicGroup ?? $0.id) == id }.map(\.id)
            units.append(.init(id: id, members: members, atomic: item.atomicGroup != nil))
        }
        self.units = units
        refreshReadiness()
    }

    var isExecutable: Bool { false }
    var isBusy: Bool { units.contains { $0.state == .running || $0.state == .waitingAuthorization } }
    var requiresUnsavedContentHandling: Bool { units.contains { $0.state != .succeeded } }
    var description: String { "CommandExecutionRun(id: \(stamp.runID), units: \(units.count))" }
    var debugDescription: String { description }

    func operation(_ itemID: UUID) -> CommandOperationIdentity? {
        snapshot.items.first { $0.id == itemID }.map { .init(execution: stamp, item: $0.stamp, operationID: $0.id) }
    }

    func attempt(_ unitID: UUID) -> CommandAttemptStamp? {
        units.first { $0.id == unitID }.map {
            .init(execution: stamp, unitID: $0.id, number: $0.attempt, phase: $0.currentPhase)
        }
    }

    /// 返回协议尝试身份，不返回可调用的执行闭包，也不产生真实副作用。
    mutating func beginNext(expecting stamp: CommandExecutionStamp) throws -> CommandAttemptStamp {
        guard self.stamp == stamp else { throw CommandExecutionError.stale }
        guard !isBusy else { throw CommandExecutionError.busy }
        refreshReadiness()
        guard let index = units.firstIndex(where: { $0.state == .ready }) else { throw CommandExecutionError.noReadyUnit }
        let phase: CommandExecutionPhase = units[index].local == .committed ? .external : .local
        if phase == .local { try resolveInputs(index) }
        units[index].attempt += 1
        units[index].currentPhase = phase
        units[index].state = .running
        if phase == .external {
            for effect in units[index].effects.keys where units[index].effects[effect] == .pending {
                units[index].effects[effect] = .running
            }
        }
        return .init(execution: stamp, unitID: units[index].id, number: units[index].attempt, phase: phase)
    }

    @discardableResult mutating func receive(_ receipt: CommandExecutionReceipt) throws -> Bool {
        let index = try currentIndex(receipt.attempt)
        if units[index].receipt == receipt { return false }
        guard units[index].state == .running else { throw CommandExecutionError.stale }
        var unit = units[index]
        if receipt.attempt.phase == .external {
            try applyExternal(receipt.result, to: &unit)
        } else {
            try applyLocal(receipt.result, to: &unit)
        }
        unit.receipt = receipt
        units[index] = unit
        if case .committed(let created, _) = receipt.result { outputs.merge(created) { old, _ in old } }
        refreshReadiness()
        return true
    }

    private func currentIndex(_ attempt: CommandAttemptStamp) throws -> Int {
        guard attempt.execution == stamp, let index = units.firstIndex(where: { $0.id == attempt.unitID }),
              units[index].attempt == attempt.number, units[index].currentPhase == attempt.phase else {
            throw CommandExecutionError.stale
        }
        return index
    }

    private func applyLocal(_ result: CommandExecutionResult, to unit: inout CommandExecutionUnit) throws {
        guard unit.local == .notSubmitted else { throw CommandExecutionError.invalidResult }
        switch result {
        case .preferenceGroupCommit(let commit):
            try applyPreferenceGroupCommit(commit, to: &unit)
        case .noChange:
            guard isSinglePreference(unit) else { throw CommandExecutionError.invalidResult }
            unit.state = .succeeded
        case .preferenceWrite(let facts):
            guard isSinglePreference(unit), facts.isValid else { throw CommandExecutionError.invalidResult }
            unit.preferenceWrite = facts
            if facts.readback == .matches {
                unit.effects[.preferencePresentation] = facts.presentationFailed ? .failed : .succeeded
            }
            if facts.write == .notCalled { unit.state = .failed }
            else if facts.write == .returned && facts.readback == .matches {
                unit.local = .committed
                unit.state = facts.presentationFailed ? .failed : .succeeded
            } else { unit.local = .unknown; unit.state = .verificationRequired }
        case .committed(let created, let external):
            guard !unit.atomic || external.isEmpty else { throw CommandExecutionError.invalidResult }
            for (id, output) in created {
                guard unit.members.contains(id), outputs[id] == nil,
                      let item = snapshot.items.first(where: { $0.id == id }),
                      let type = CommandCatalog.standard.command(id: item.draft.commandID)?.createdObjectType,
                      CommandArgumentValidation.accepts(.object(output), type: .object([type])) else {
                    throw CommandExecutionError.invalidResult
                }
            }
            unit.local = .committed
            unit.effects = Dictionary(uniqueKeysWithValues: external.map { ($0, .pending) })
            unit.state = external.isEmpty ? .succeeded : .ready
        case .failedWithoutCommit: unit.state = .failed
        case .commitUnknown: unit.local = .unknown; unit.state = .verificationRequired
        case .notExecuted: unit.state = .notExecuted
        case .waitingAuthorization: unit.state = .waitingAuthorization
        case .conflict(let diagnostics):
            guard !diagnostics.isEmpty, diagnostics.allSatisfy({ validConflict($0, unit: unit) }) else {
                throw CommandExecutionError.invalidResult
            }
            unit.conflicts = diagnostics
            unit.state = .conflict
        case .external, .preferencePresentation, .preferenceGroupPresentation: throw CommandExecutionError.invalidResult
        }
    }

    private func isSinglePreference(_ unit: CommandExecutionUnit) -> Bool {
        !unit.atomic && snapshot.items.count == 1 && unit.members.count == 1
            && CommandPlanSemantics.isAtomicSetting(snapshot.items[0].draft.commandID)
    }

    private func validConflict(_ diagnostic: CommandFieldConflict, with item: CommandPlanItem) -> Bool {
        guard let command = CommandCatalog.standard.command(id: item.draft.commandID),
              command.parameters.contains(where: { $0.id == diagnostic.field.parameter }) else { return false }
        let targets = input(item, bindings: bindings[item.id, default: [:]])?.targets ?? item.draft.targets
        let subjects: [CommandDraftBaseline.Subject] = targets.objects.isEmpty ? [.ambient] : targets.objects.map { .object($0) }
        guard subjects.contains(diagnostic.field.subject) else { return false }
        return diagnostic.reason != .valueChanged || item.draft.baseline.values[diagnostic.field] != nil
    }

    private func validConflict(_ diagnostic: CommandFieldConflict, unit: CommandExecutionUnit) -> Bool {
        guard unit.members.contains(diagnostic.item.id), let item = snapshot.items.first(where: { $0.stamp == diagnostic.item }) else { return false }
        return validConflict(diagnostic, with: item)
    }

    private func applyExternal(_ result: CommandExecutionResult, to unit: inout CommandExecutionUnit) throws {
        if case .preferenceGroupPresentation(let presentation) = result {
            guard CommandPlanValidation.isPreferenceUnit(snapshot.items), unit.local == .committed,
                  unit.preferenceGroupCommit != nil, unit.effects == [.preferencePresentation: .running] else {
                throw CommandExecutionError.invalidResult
            }
            unit.preferenceGroupPresentation = presentation
            unit.effects[.preferencePresentation] = presentation.incomplete ? .failed : .succeeded
            unit.state = presentation.incomplete ? .failed : presentation.superseded ? .notExecuted : .succeeded
            return
        }
        if case .preferencePresentation(let presentation) = result {
            guard isSinglePreference(unit), unit.local == .committed, unit.preferenceWrite != nil,
                  unit.effects[.preferencePresentation] == .running else { throw CommandExecutionError.invalidResult }
            unit.preferencePresentation = presentation
            switch presentation {
            case .superseded:
                unit.effects[.preferencePresentation] = .failed
                unit.state = .notExecuted
            case .applied(let appearance, let event):
                let failed = appearance == .threw || event == .threw
                unit.effects[.preferencePresentation] = failed ? .failed : .succeeded
                unit.state = failed ? .failed : .succeeded
            }
            return
        }
        guard unit.local == .committed, case .external(let results) = result else { throw CommandExecutionError.invalidResult }
        let running = Set(unit.effects.filter { $0.value == .running }.map(\.key))
        guard Set(results.keys) == running, !running.isEmpty,
              results.values.allSatisfy({ [.succeeded, .failed, .unknown].contains($0) }) else {
            throw CommandExecutionError.invalidResult
        }
        unit.effects.merge(results) { _, new in new }
        if unit.effects.values.contains(.unknown) { unit.state = .verificationRequired }
        else if unit.effects.values.contains(.failed) { unit.state = .failed }
        else { unit.state = .succeeded }
    }

    private mutating func refreshReadiness() {
        for index in units.indices where [.ready, .blocked].contains(units[index].state) && units[index].local == .notSubmitted {
            if case .invalidResolvedInput = units[index].block { continue }
            let members = snapshot.items.filter { units[index].members.contains($0.id) }
            let dependencies = Set(members.flatMap { $0.links.dependencies })
            let predecessor = snapshot.items.first { item in
                dependencies.contains(item.id) && units.first { $0.members.contains(item.id) }?.state != .succeeded
            }
            let missing = members.flatMap { $0.links.results.values }.first { outputs[$0.producer.id] == nil }
            units[index].block = predecessor.map { .predecessor($0.id) } ?? missing.map { .missingOutput($0.producer.id) }
            units[index].state = units[index].block == nil ? .ready : .blocked
        }
    }

    private mutating func resolveInputs(_ index: Int) throws {
        var resolved = bindings
        for id in units[index].members {
            guard let item = snapshot.items.first(where: { $0.id == id }) else { throw CommandExecutionError.invalidResult }
            if resolved[id] == nil {
                var references: [CommandParameterID: CommandObjectReference] = [:]
                for (parameter, reference) in item.links.results {
                    guard let output = creationOutput(for: reference) else {
                        throw CommandExecutionError.invalidResult
                    }
                    references[parameter] = output
                }
                resolved[id] = references
            }
            guard let input = input(item, bindings: resolved[id, default: [:]]),
                  let command = CommandCatalog.standard.command(id: item.draft.commandID),
                  CommandArgumentValidation.issues(for: input.arguments, command: command).isEmpty,
                  input.targets.issues(for: command).isEmpty else {
                units[index].state = .blocked
                units[index].block = .invalidResolvedInput(id)
                throw CommandExecutionError.invalidResult
            }
        }
        bindings = resolved
    }

    func resolvedInput(_ itemID: UUID) -> CommandResolvedInput? {
        guard let item = snapshot.items.first(where: { $0.id == itemID }), let references = bindings[itemID] else { return nil }
        return input(item, bindings: references)
    }

    /// 单项真实创建与后续计划依赖共用相同解析，不执行消费者，也不放宽外部步骤门禁。
    func creationOutput(for reference: CommandCreationReference) -> CommandObjectReference? {
        guard snapshot.items.contains(where: { $0.stamp == reference.producer }),
              units.first(where: { $0.members.contains(reference.producer.id) })?.state == .succeeded,
              let output = outputs[reference.producer.id], output.type == reference.outputType else { return nil }
        return output
    }

    private func input(_ item: CommandPlanItem, bindings: [CommandParameterID: CommandObjectReference]) -> CommandResolvedInput? {
        guard !item.draft.blocksUnprotectedExport,
              let command = CommandCatalog.standard.command(id: item.draft.commandID) else { return nil }
        var targets = item.draft.targets
        var arguments = item.draft.arguments.filter { bindings[$0.parameter] == nil }
        for (parameter, object) in bindings {
            if parameter == .target { targets = .init(.single, objects: [object]); continue }
            guard let definition = command.parameters.first(where: { $0.id == parameter }) else { return nil }
            let value: CommandValue
            switch definition.type {
            case .object: value = .object(object)
            case .objects: value = .objects([object])
            default: return nil
            }
            arguments.append(.init(parameter: parameter, operation: .assign, value: value))
        }
        arguments += targets.argument(for: command).map { [$0] } ?? []
        return .init(arguments: arguments, targets: targets)
    }

    func retryAssessment(_ attempt: CommandAttemptStamp, assurance: CommandRetryAssurance) -> CommandRetryAssessment {
        guard let index = try? currentIndex(attempt) else { return .notRetryable }
        let unit = units[index]
        if unit.preferencePresentation == .superseded { return .notRetryable }
        if unit.preferenceGroupPresentation?.superseded == true && unit.preferenceGroupPresentation?.incomplete == false {
            return .notRetryable
        }
        if unit.local == .unknown || unit.state == .verificationRequired { return .requiresVerification }
        guard [.failed, .notExecuted].contains(unit.state) else { return .notRetryable }
        if unit.local == .notSubmitted {
            return assurance == .safeLocalReplay ? .local : .requiresAdapterConfirmation
        }
        let failed = Set(unit.effects.filter { $0.value == .failed }.map(\.key))
        guard !failed.isEmpty else { return .notRetryable }
        guard case .idempotentExternal(let confirmed) = assurance, !confirmed.isEmpty,
              confirmed.isSubset(of: failed) else { return .requiresAdapterConfirmation }
        return .external(confirmed)
    }

    mutating func retry(_ attempt: CommandAttemptStamp, assurance: CommandRetryAssurance) throws {
        let index = try currentIndex(attempt)
        switch retryAssessment(attempt, assurance: assurance) {
        case .local: break
        case .external(let effects):
            for effect in effects { units[index].effects[effect] = .pending }
        case .requiresVerification: throw CommandExecutionError.requiresVerification
        case .requiresAdapterConfirmation: throw CommandExecutionError.requiresAdapterConfirmation
        case .notRetryable: throw CommandExecutionError.notRetryable
        }
        units[index].state = .ready
        // 清除旧结果令重试前的迟到回调也被拒绝；尝试号在开始时递增。
        units[index].receipt = nil
        refreshReadiness()
    }

    func cancellationAssessment(_ unitID: UUID) -> CommandCancellationAssessment {
        guard let unit = units.first(where: { $0.id == unitID }) else { return .requiresAdapterConfirmation }
        if unit.local == .committed { return .cannotCancelCommitted }
        return unit.attempt == 0 && [.ready, .blocked].contains(unit.state) ? .canMarkNotStarted : .requiresAdapterConfirmation
    }

    mutating func resolveValidation(_ attempt: CommandAttemptStamp, resolution: CommandValidationResolution) throws {
        let index = try currentIndex(attempt)
        guard [.waitingAuthorization, .conflict].contains(units[index].state), units[index].local == .notSubmitted else {
            throw CommandExecutionError.stale
        }
        if resolution == .readyForProtocol && units[index].conflicts.contains(where: { $0.reason == .objectUnavailable }) {
            throw CommandExecutionError.requiresVerification
        }
        units[index].state = resolution == .readyForProtocol ? .ready : .notExecuted
        units[index].receipt = nil
        refreshReadiness()
    }

    mutating func cancelNotStarted(_ unitID: UUID, expecting stamp: CommandExecutionStamp) throws {
        guard self.stamp == stamp else { throw CommandExecutionError.stale }
        guard cancellationAssessment(unitID) == .canMarkNotStarted,
              let index = units.firstIndex(where: { $0.id == unitID }) else { throw CommandExecutionError.requiresAdapterConfirmation }
        units[index].state = .notExecuted
        refreshReadiness()
    }
}

extension CommandExecutionRun {
    private func applyPreferenceGroupCommit(_ commit: CommandPreferenceGroupCommit,
                                           to unit: inout CommandExecutionUnit) throws {
        guard CommandPlanValidation.isPreferenceUnit(snapshot.items) else { throw CommandExecutionError.invalidResult }
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
        guard attempt.execution == stamp, attempt.phase == .local, snapshot.items.count == 1,
              let item = snapshot.items.first, item.id == attempt.unitID,
              let index = units.firstIndex(where: { $0.id == attempt.unitID }),
              units[index].attempt == attempt.number else { throw CommandExecutionError.stale }
        try CommandHandoffCoordinator.validateTaskCreateItem(item)
        if let previous = units[index].taskCreation {
            guard previous.creationID == facts.creationID,
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
