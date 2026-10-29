import Foundation

/// 原生拼写缓冲只保留编辑文字与产生版本；没有独立提交入口。
struct UnifiedSearchParameterBuffer {
    let text: String
    let stamp: CommandDraftStamp
}

extension UnifiedSearchController {
    var operations: CommandDraftSession? {
        _ = revision
        guard let owned = try? coordinator.host(buffer.lease.ownership.hostID),
              owned.lease.ownership == buffer.lease.ownership else { return nil }
        return owned.session.operations
    }

    var operationVisible: Bool {
        !isNavigationPresented && (try? session.validateDisplayHost(expecting: buffer.lease)) != nil
    }

    var queryInputText: String {
        guard let query = try? coordinator.host(buffer.lease.ownership.hostID).session.query,
              case .content(let content) = query.input else { return "" }
        return content.source
    }

    var isCommandInput: Bool {
        if editingParameter != nil { return true }
        let state = CommandPathParser().parse(.init(text: buffer.text, cursorLocation: buffer.text.utf16.count)).state
        return state != .ordinaryText && state != .scope
    }

    func validates(_ source: UnifiedSearchBuffer) -> Bool {
        source == buffer && (try? coordinator.validate(source.lease)) != nil
    }

    var browsedCommand: CommandDescriptor? {
        let result = CommandPathParser().parse(.init(text: buffer.text))
        guard let command = result.command, command.category != .group, command.category != .scope else { return nil }
        return command
    }

    var inputParameterContext: UnifiedSearchParameterContext? {
        guard let id = editingParameter, let draft = editingDraft,
              let command = CommandCatalog.standard.command(id: draft.commandID),
              let parameter = command.parameters.first(where: { $0.id == id }) else { return nil }
        return .init(command: command, parameter: parameter, operation: fieldOperation(parameter, draft: draft))
    }

    func fieldOperation(_ parameter: CommandParameter, draft: CommandDraft) -> CommandFieldOperation {
        draft.arguments.first { $0.parameter == parameter.id }?.operation ?? parameter.defaultOperation
    }

    func parameterBuffer(_ parameter: CommandParameter, draft: CommandDraft) -> UnifiedSearchBuffer {
        let argument = draft.arguments.first { $0.parameter == parameter.id }
        let context = UnifiedSearchParameterContext(command: CommandCatalog.standard.command(id: draft.commandID)!,
            parameter: parameter, operation: fieldOperation(parameter, draft: draft))
        let spelling = parameterText[draft.id]?[parameter.id]
        // 新挂载可显示保留的未完成拼写；其旧事件身份绝不续租。外部改值后不复活旧拼写。
        let retained = spelling.flatMap { saved -> String? in
            guard saved.stamp.draftID == draft.id, saved.stamp.version <= draft.version,
                  context.value(saved.text) == argument?.value else { return nil }
            return saved.text
        }
        return .init(lease: buffer.lease, version: buffer.version,
            text: retained ?? UnifiedSearchOperationCopy.raw(argument?.value),
            privacyRevision: buffer.privacyRevision, operation: draft.stamp, plan: buffer.plan, planItem: buffer.planItem)
    }

    func accept(_ request: UnifiedSearchEdit) -> UnifiedSearchBuffer? {
        guard validates(request.source), let acceptance = request.acceptance else { return nil }
        // 接受候选是显式动作：遮罩时先恢复（同一入口），再按原路径开始操作。
        guard let request = resumedRequest(request) else { return nil }
        if let command = CommandPathParser().parse(.init(text: request.text)).command, Self.routesAsNavigation(command) {
            return navigationInput(request.text)
        }
        if case .expand = acceptance.intent {} else if isNavigationPresented, returnSearch != nil,
           let published = navigationInput(request.text) {
            // 目的地上接受修改类候选：先显示接受后的文字，回到搜索页后在同一文字上重新接受（参数值不丢）。
            _ = returnThenContinue { [weak self] source in
                _ = self?.accept(.init(source: source, text: request.text, selection: request.selection,
                                       acceptance: request.acceptance))
            }
            return published
        }
        switch acceptance.intent {
        case .expand: return edit(request)
        case .complete(let id), .chooseParameter(let id, _):
            return beginOperation(id, source: request.source, text: request.text)
        case .setArgument(let id, let argument):
            guard acceptsTypedArgument(argument, for: id) else { return nil }
            if editingDraft?.commandID != id {
                return beginOperation(id, source: request.source, text: request.text, argument: argument)
            }
            guard let stamp = request.source.operation else { return nil }
            return sendOperation(.edit(stamp, argument), source: request.source, text: request.text)
        }
    }

    /// 参数值候选与转交来的路径参数共用的校验：参数属于这条指令、可在面板里编辑、值与操作合法。
    func acceptsTypedArgument(_ argument: CommandArgument, for id: CommandID) -> Bool {
        guard let command = CommandCatalog.standard.command(id: id),
              let parameter = command.parameters.first(where: { $0.id == argument.parameter }),
              UnifiedSearchParameterContext.supports(parameter, command: command),
              let value = argument.value, CommandArgumentValidation.accepts(value, type: parameter.type),
              parameter.operations.contains(argument.operation) else { return false }
        return true
    }

    @discardableResult
    func beginOperation(_ id: CommandID, source: UnifiedSearchBuffer, text: String? = nil,
                        argument: CommandArgument? = nil) -> UnifiedSearchBuffer? {
        // 交给工作台完成的指令不在本宿主建草稿：接受候选只写文字，Return 再转交（handOffToWorkspace）。
        if validates(source), CommandCatalog.standard.command(id: id)?.category == .navigation
            || disposition(for: id) == .workspaceHandoff {
            return navigationInput(text ?? CommandCatalog.standard.command(id: id)!.path)
        }
        guard validates(source), operationVisible, let state = operations,
              let command = CommandCatalog.standard.command(id: id),
              command.category != .group, command.category != .scope, state.pending == nil, plan?.editing == nil,
              !settingSubmitting, settingExecution == nil else {
            // 不再静默：门禁拒绝时给出一句原因；分组与范围本就不开始操作，不提示。
            if CommandCatalog.standard.command(id: id).map({ $0.category != .group && $0.category != .scope }) == true {
                reportGate()
            }
            return nil
        }
        if let active = state.active, active.commandID == id {
            operationExpanded = true
            _ = publishOperation(text: text ?? buffer.text)
            prepareSettingDraft()
            return buffer
        }
        editingParameter = nil
        if let retained = state.retained.first(where: { $0.commandID == id }) {
            // 继续已保留的同一操作；参数候选须在恢复成功后重新接受，不能跨确认补发。
            return sendOperation(.restore(expectedRevision: state.revision, retained.stamp), source: source,
                                 text: text ?? command.path)
        }
        let draft = CommandDraft(id: UUID(), hostID: source.lease.ownership.hostID, commandID: id,
            baseline: initialBaseline(for: id), arguments: argument.map { [$0] } ?? [])
        return sendOperation(.start(expectedRevision: state.revision, draft), source: source, text: text ?? command.path)
    }

    /// 新草稿的初始基线：已装配适配器的指令一律空基线，其余沿合成基线（看板转交也用这一处）。
    func initialBaseline(for id: CommandID) -> CommandDraftBaseline {
        routesAdapter(id) ? .init() : syntheticBaselines[id] ?? .init()
    }

    @discardableResult
    func sendOperation(_ event: CommandDraftEvent, source: UnifiedSearchBuffer, text: String? = nil) -> UnifiedSearchBuffer? {
        guard validates(source), operationVisible, !settingSubmitting, settingExecution == nil else { return nil }
        if source.planItem != nil { return sendPlanDraft(event, source: source) }
        do {
            let effect = try coordinator.send(.operation(event), expecting: source.lease)
            _ = publishOperation(text: text ?? buffer.text)
            if case .operation(let intents) = effect, intents.contains(.rejectedEvent) {
                operationMessage = "unified.operation.stale"
                return nil
            }
            operationMessage = "unified.operation.notExecuted"
            operationExpanded = true
            prepareSettingDraft()
            return buffer
        } catch { return nil }
    }

    func editParameter(_ argument: CommandArgument, source: UnifiedSearchBuffer) -> UnifiedSearchBuffer? {
        guard validatesParameterSource(source, parameter: argument.parameter), let stamp = source.operation,
              let command = editingDraft.flatMap({ CommandCatalog.standard.command(id: $0.commandID) }),
              let parameter = command.parameters.first(where: { $0.id == argument.parameter }),
              UnifiedSearchParameterContext.supports(parameter, command: command)
                || supportsTagField(parameter, command: command),
              argument.operation == .unspecified || parameter.operations.contains(argument.operation) else { return nil }
        // ID 集合只能由真实候选确认写入；普通字段入口仅允许切换标签操作。
        if parameter.type == .tags, let value = argument.value,
           value != editingDraft?.arguments.first(where: { $0.parameter == .tags })?.value { return nil }
        if let value = argument.value, !CommandArgumentValidation.accepts(value, type: parameter.type) { return nil }
        let mainSource = buffer // 同步核验后的同一个 lease/stamp；不跨 await，不接收旧事件续租。
        let updated = sendOperation(.edit(stamp, argument), source: mainSource)
        if updated != nil, let draft = editingDraft,
           !draft.targets.objects.isEmpty || draft.arguments.contains(where: {
               switch $0.value {
               case .object, .objects: return true
               default: return false
               }
           }) { refreshObjectPresentation() }
        return updated
    }

    func validatesParameterSource(_ source: UnifiedSearchBuffer, parameter: CommandParameterID) -> Bool {
        guard operationVisible, source.lease == buffer.lease, source.version == buffer.version,
              source.privacyRevision == buffer.privacyRevision, let draft = editingDraft,
              source.operation == draft.stamp, source.plan == buffer.plan, source.planItem == buffer.planItem,
              (try? coordinator.validate(source.lease)) != nil else { return false }
        return source == buffer || CommandCatalog.standard.command(id: draft.commandID)?.parameters
            .first(where: { $0.id == parameter }).map { parameterBuffer($0, draft: draft) == source } == true
    }

    func editParameterText(_ request: UnifiedSearchEdit, context: UnifiedSearchParameterContext,
                           mainInput: Bool = false) -> UnifiedSearchBuffer? {
        guard validatesParameterSource(request.source, parameter: context.parameter.id),
              let draft = editingDraft, draft.commandID == context.command.id,
              context.operation == fieldOperation(context.parameter, draft: draft), context.operation.requiresValue else { return nil }
        let argument = CommandArgument(parameter: context.parameter.id, operation: context.operation,
                                       value: context.value(request.text))
        guard editParameter(argument, source: request.source) != nil, let updated = editingDraft else { return nil }
        parameterText[updated.id, default: [:]][context.parameter.id] = .init(text: request.text, stamp: updated.stamp)
        if mainInput {
            replaceOperationInputText(request.text)
            return buffer
        }
        return parameterBuffer(context.parameter, draft: updated)
    }

    func chooseParameter(_ id: CommandParameterID, source: UnifiedSearchBuffer) {
        guard validates(source), operationVisible, let draft = editingDraft,
              let command = CommandCatalog.standard.command(id: draft.commandID),
              let parameter = command.parameters.first(where: { $0.id == id }),
              UnifiedSearchParameterContext.supports(parameter, command: command),
              fieldOperation(parameter, draft: draft).requiresValue else { return }
        editingParameter = id
        let text = parameterBuffer(parameter, draft: draft).text
        _ = publishOperation(text: text)
        inputFocused = true
    }

    func finishParameter(_ source: UnifiedSearchBuffer) {
        guard validates(source), let draft = editingDraft,
              let command = CommandCatalog.standard.command(id: draft.commandID) else { return }
        editingParameter = nil
        _ = publishOperation(text: command.path)
    }

    func resolveOperation(_ decision: CommandDraftDecision, choice: CommandDraftSwitchChoice, source: UnifiedSearchBuffer) {
        guard sendOperation(.resolve(decision, choice), source: source) != nil else { return }
        editingParameter = nil
        let live = Set((operations?.retained.map(\.id) ?? []) + (operations?.active.map { [$0.id] } ?? [])
            + (plan?.items.map { $0.draft.id } ?? []))
        parameterText = parameterText.filter { live.contains($0.key) }
        if let draft = editingDraft, let command = CommandCatalog.standard.command(id: draft.commandID) {
            _ = publishOperation(text: command.path)
        }
    }

    /// 关闭工作台／退出被未完成草稿挡住时的放弃入口；只丢弃活动草稿，待执行列表仍须回到列表逐项处理。
    func discardActiveOperation(source: UnifiedSearchBuffer) {
        guard source.planItem == nil, let draft = operations?.active,
              sendOperation(.discardActive(draft.stamp), source: source) != nil else { return }
        editingParameter = nil
        parameterText[draft.id] = nil
    }

    func restoreOperation(_ stamp: CommandDraftStamp, source: UnifiedSearchBuffer) {
        guard validates(source), let state = operations, plan?.editing == nil,
              let draft = state.retained.first(where: { $0.stamp == stamp }),
              let command = CommandCatalog.standard.command(id: draft.commandID) else { return }
        editingParameter = nil
        _ = sendOperation(.restore(expectedRevision: state.revision, stamp), source: source, text: command.path)
    }

}
