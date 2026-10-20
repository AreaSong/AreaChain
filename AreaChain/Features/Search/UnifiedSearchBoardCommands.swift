import Foundation

/// 合并批 M-2 A：看板导航沿 N-M1 的导航执行（路径参数、不建草稿），页面状态只写页面那一份；
/// 看板修改指令转交给已有指令：把参数与目标搬到那条指令的新草稿，再由它自己的面板准备、确认与保存。
extension UnifiedSearchController {
    /// 先核对页面（不对就说明，不切页），再沿 N-M1 显示当前页；页面显示后才写状态，检查器才核对投影。
    func executeBoardNavigation(_ command: CommandID, parsed: CommandPathResult, source: UnifiedSearchBuffer,
                                pages: WorkspacePageCommands) {
        // 检查器两条同 inspector.open：目标不在路径里，只允许“待选目标”这一种未完成。
        let inspects = ["quadrant.inspect", "gantt.inspect"].contains(command.rawValue)
        let complete = inspects
            ? parsed.state != .invalid && parsed.diagnostics.allSatisfy { $0.issue == .chooseParameter && $0.range.length == 0 }
            : parsed.state == .command
        guard complete else { navigationMessage = "unified.page.invalidArguments"; return }
        let action: CommandBoardNavigation
        var target: CommandObjectReference?
        do {
            action = try CommandBoardNavigation(command: command, arguments: parsed.arguments)
            if action == .quadrantInspect || action == .ganttInspect {
                // 同 inspector.open：目标取当前结果的焦点项。
                guard let active = try? session.presentation().pagination.browse.active else {
                    navigationMessage = "unified.navigation.chooseObject"; return
                }
                target = active
            }
            let page = try pages.requireBoardPage(action.page)
            navigate(.page(page), source: source) { [weak self, pages] _ in
                guard let self else { return }
                do {
                    _ = try pages.applyBoardNavigation(action, inspecting: target)
                    if case .calendarDayList = action { pages.requestCalendarDayList() }
                    self.navigationMessage = "unified.board.done"
                } catch { self.navigationMessage = Self.boardMessage(error) }
            }
        } catch { navigationMessage = Self.boardMessage(error) }
    }

    static func boardMessage(_ error: Error) -> String {
        let issue = error as? CommandPageIssue ?? .stale
        if case .wrongPage(let page) = issue { return "unified.board.wrongPage." + page }
        return UnifiedSearchPageCopy.key(issue)
    }

    /// 转交：新草稿只带转交给出的参数与目标；原看板草稿的内容已全部搬过去，按“放弃”结束，不留第二份。
    func transferOperation(_ transfer: CommandBoardTransfer, from draft: CommandDraft, source: UnifiedSearchBuffer) throws {
        guard let state = operations, state.active?.stamp == draft.stamp,
              let command = CommandCatalog.standard.command(id: transfer.command) else { throw CommandPageIssue.stale }
        let seed = CommandDraft(id: UUID(), hostID: source.lease.ownership.hostID, commandID: transfer.command,
                                baseline: initialBaseline(for: transfer.command), arguments: transfer.arguments)
        // 每次事件都推进租约修订：第一次用调用方核对过的租约，之后只接同一宿主刚推进的那一份。
        let hostID = source.lease.ownership.hostID
        var effect = try coordinator.send(.operation(.start(expectedRevision: state.revision, seed)), expecting: source.lease)
        if case .operation(let intents) = effect, let decision = intents.compactMap({ intent -> CommandDraftDecision? in
            if case .requiresDecision(let decision) = intent { return decision }
            return nil
        }).first {
            effect = try coordinator.send(.operation(.resolve(decision, .discard)), expecting: coordinator.host(hostID).lease)
        }
        guard case .operation(let intents) = effect, !intents.contains(.rejectedEvent),
              let started = operations?.active, started.id == seed.id else { throw CommandPageIssue.stale }
        if !transfer.targets.objects.isEmpty {
            effect = try coordinator.send(.operation(.selectTargets(started.stamp, transfer.targets,
                                                                     baseline: targetBaseline(for: transfer.command))),
                                          expecting: coordinator.host(hostID).lease)
            guard case .operation(let intents) = effect, !intents.contains(.rejectedEvent) else { throw CommandPageIssue.stale }
        }
        revokePage()
        _ = publishOperation(text: command.path)
        operationMessage = "unified.operation.notExecuted"
        operationExpanded = true
        prepareSettingDraft()
    }
}
