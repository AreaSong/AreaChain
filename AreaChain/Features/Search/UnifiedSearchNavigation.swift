import Foundation

/// 返回票据只有定位及版本。查询/正文/计划仍留在各自唯一所有者中。
struct UnifiedSearchReturnContext {
    let id = UUID()
    let ownership: CommandHostOwnership
    let queryRevision: UInt64
    let privacyRevision: UInt64
    let tab: WorkspaceTab
    let tag: UUID?
    let version: UUID?
    let scroll: CGPoint?
    let active: CommandObjectReference?
    let selected: Set<CommandObjectReference>
    let expanded: Set<ContentQueryDisplayControl>
}

extension UnifiedSearchController {
    var isNavigationInput: Bool { browsedCommand.map(Self.routesAsNavigation) == true }

    /// 走导航面板（不建草稿）的指令：导航类，合并批 M-3 的“在原页面完成”对照与窗口／统计／退出等直接动作。
    static func routesAsNavigation(_ command: CommandDescriptor) -> Bool {
        command.category == .navigation || CommandOriginalPage.route(for: command.id) != nil
            || CommandSystemAction.commands.contains(command.id.rawValue)
    }
    var isNavigationPresented: Bool { navigationRouter?.navigation.searchPresentation == false }

    func navigationInput(_ text: String) -> UnifiedSearchBuffer? {
        editingParameter = nil
        return publishOperation(text: text)
    }

    func executeNavigation(source: UnifiedSearchBuffer) {
        guard validates(source), isNavigationInput else { return }
        guard let router = navigationRouter else { navigationMessage = "unified.navigation.unassembled"; return }
        let parsed = CommandPathParser().parse(.init(text: source.text))
        guard let command = parsed.command else { return }
        // 分派与候选标签共用 navigationRoute（修复批 M-7G 唯一判断入口），不另写平行名单。
        let route = navigationRoute(for: command)
        if case .page(let page)? = route, parsed.arguments.isEmpty, parsed.state == .command {
            navigate(.page(page), source: source)
        } else if route == .day {
            guard parsed.state == .command,
                  case .day(let day)? = parsed.arguments.first(where: { $0.parameter == .day })?.value,
                  let date = DayKey.date(from: day, calendar: router.objects.calendar),
                  DayKey.from(date, calendar: router.objects.calendar) == day else {
                navigationMessage = "unified.navigation.chooseDay"; return
            }
            navigate(.day(day), source: source)
        } else if route == .focusedObject {
            guard parsed.state != .invalid, parsed.arguments.isEmpty,
                  parsed.diagnostics.allSatisfy({ $0.issue == .chooseParameter && $0.range.length == 0 }) else {
                navigationMessage = "unified.navigation.invalidTarget"; return
            }
            guard let page = try? session.presentation().pagination, page.browse.active != nil else {
                navigationMessage = "unified.navigation.chooseObject"; return
            }
            if command.id.rawValue == "go.tagList", page.browse.active?.type != .tag {
                navigationMessage = "unified.navigation.chooseObject"; return
            }
            if command.id.rawValue == "inspector.open",
               ![CommandObjectType.todo, .subtask, .routineOccurrence].contains(page.browse.active!.type) {
                navigationMessage = "unified.navigation.unsupported"; return
            }
            browse(.init(version: page.snapshot.version, action: .open(inputEditing: false)), source: source)
        } else if route == .board, let pages = pageCommands {
            executeBoardNavigation(command.id, parsed: parsed, source: source, pages: pages)
        } else if case .clipboardWindow(let window)? = route, let pages = pageCommands {
            executeClipboardWindow(window, parsed: parsed, source: source, pages: pages)
        } else if route == .system {
            executeSystemAction(command, parsed: parsed, source: source)
        } else if case .originalPage(let page)? = route {
            executeOriginalPage(page, command: command, parsed: parsed, source: source)
        } else { navigationMessage = "unified.navigation.unsupported" }
    }

    func openResult(_ open: ContentQueryBrowseOpen, source: UnifiedSearchBuffer,
                    then completion: ((WorkspaceNavigationOutcome) -> Void)? = nil) {
        guard validates(source), let router = navigationRouter else {
            navigationMessage = "unified.navigation.unassembled"
            return
        }
        do {
            // BrowseOpen 仅在原 Session 同步消费后进入此处，异步显示前仍核验原票据。
            let page = try session.presentation().pagination
            guard page.snapshot.visible.contains(open.object),
                  page.browse.active == open.object || page.browse.selected.contains(open.object) else {
                throw WorkspaceOpenFailure.stale
            }
            if [.tag, .diary, .image].contains(open.object.type) {
                guard router.contents != nil else { throw WorkspaceOpenFailure.unassembled }
                contentOwnerMessage = "unified.content.ownerHint"
                navigate(.content(open.object), source: source, content: open)
                return
            }
            let location = try router.objects.resolve(open)
            guard validates(source), (try? session.presentation().pagination.snapshot.version) == page.snapshot.version else {
                throw WorkspaceOpenFailure.stale
            }
            navigate(.object(location), source: source, then: completion)
        } catch { navigationMessage = navigationFailure(error as? WorkspaceOpenFailure ?? .invalidTarget) }
    }

    /// `then` 在页面实际显示后调用（合并批 M-1 C 的选择类指令据此在页面投影上执行）；被拒或过期不调用。
    func navigate(_ destination: WorkspaceNavigationDestination, source: UnifiedSearchBuffer,
                  content: ContentQueryBrowseOpen? = nil, origin: CommandObjectReference? = nil,
                  then completion: ((WorkspaceNavigationOutcome) -> Void)? = nil) {
        guard validates(source), let router = navigationRouter else { return }
        do { try router.validateHost(); try session.validateDisplayHost(expecting: source.lease) }
        catch { navigationMessage = navigationFailure(error as? WorkspaceOpenFailure ?? .stale); return }
        guard navigationTask == nil else { return }
        if returnSearch == nil {
            let browse = try? session.presentation().pagination.browse
            returnSearch = .init(ownership: source.lease.ownership, queryRevision: navigationQueryRevision,
                privacyRevision: source.privacyRevision, tab: router.navigation.selectedTab, tag: router.navigation.selectedTagID,
                version: browse?.snapshot.version, scroll: captureSearchScroll?(), active: browse?.active,
                selected: browse?.selected ?? [], expanded: browse?.expanded ?? [])
        }
        guard let ticket = returnSearch else { return }
        endLongText()
        inputFocused = false
        guard inputReset.state?.dismissForNavigation() != false else {
            navigationMessage = "unified.navigation.composing"
            return
        }
        revokeNavigationAcceptances()
        let requestID = UUID()
        navigationRequestID = requestID
        navigationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            if let content, let version = ticket.version, let contents = router.contents {
                await contents.open(content, session: self.session, lease: source.lease, version: version, origin: origin)
                guard self.navigationRequestID == requestID, self.validReturn(ticket), self.validates(source),
                      !Task.isCancelled else { return }
            }
            let result = await router.reveal(destination) { [weak self] in
                guard let self, self.validReturn(ticket), self.validates(source), !Task.isCancelled,
                      (try? self.session.validateDisplayHost(expecting: self.buffer.lease)) != nil else { return false }
                if case .object = destination {
                    return (try? self.session.presentation().pagination.snapshot.version) == ticket.version
                }
                return true
            }
            guard self.navigationRequestID == requestID else { return }
            self.navigationTask = nil
            self.navigationRequestID = nil
            guard self.validates(source) else { return }
            switch result {
            case .displayed:
                self.navigationMessage = router.contents?.failure.map { "unified.content." + $0.rawValue }
                    ?? "unified.navigation.displayed"
                completion?(result)
            case .locatedWithoutInspector: self.navigationMessage = "unified.navigation.needsSpace"
            case .rejected(let reason):
                self.navigationMessage = self.navigationFailure(reason)
                if self.validReturn(ticket) { await self.returnToSearch(ticket.id) }
            }
        }
    }

    func openContentOwner(_ owner: CommandObjectReference) {
        guard let router = navigationRouter, let contents = router.contents, contents.allowsOwner(owner),
              let origin = contents.target else { contentOwnerMessage = "unified.content.stale"; return }
        if owner.type == .routine {
            contentOwnerMessage = "unified.content.ownerNeedsDay"
            return
        }
        let open = ContentQueryBrowseOpen(object: owner, parent: nil, viewingTrash: false)
        if owner.type == .diary {
            navigate(.content(owner), source: buffer, content: open, origin: origin)
        } else {
            do {
                let location = try router.objects.resolve(open)
                guard contents.validate() else { throw WorkspaceOpenFailure.stale }
                navigate(.object(location), source: buffer)
            } catch { contentOwnerMessage = "unified.content.invalidTarget" }
        }
    }

    /// 超限长文回到原编辑入口：沿 openResult／openContentOwner 的同一解析与 navigate 核验，
    /// 手记仍须在当前结果中可见，任务仍经 objects.resolve 的隐私与存活检查，不另开导航或放宽资格。
    func openLongTextOwner(_ owner: CommandObjectReference, source: UnifiedSearchBuffer) {
        guard validates(source), let router = navigationRouter else { longTextMessage = "unified.navigation.unassembled"; return }
        let open = ContentQueryBrowseOpen(object: owner, parent: nil, viewingTrash: false)
        switch owner.type {
        case .diary:
            guard router.contents != nil else { longTextMessage = navigationFailure(.unassembled); return }
            navigate(.content(owner), source: source, content: open)
        case .todo:
            do { navigate(.object(try router.objects.resolve(open)), source: source) }
            catch { longTextMessage = navigationFailure(error as? WorkspaceOpenFailure ?? .invalidTarget) }
        default: longTextMessage = "unified.longText.ownerNeedsDay"
        }
    }

    /// 转换回执打开新对象：沿 openLongTextOwner 的同一解析与 navigate 核验，不另开导航。
    /// 新习惯按转换所用时钟的今天作为执行日打开；新待办直接打开。
    func openConvertedObject(_ facts: CommandConvertFacts, source: UnifiedSearchBuffer) {
        guard validates(source), facts.state == .saved else { return }
        guard let router = navigationRouter, let convert else { convertFailure = "unified.navigation.unassembled"; return }
        let created = facts.created
        let open = created.type == .routine
            ? ContentQueryBrowseOpen(object: .init(type: .routineOccurrence, id: created.id, dayKey: convert.conversion.clock.today()),
                                     parent: created, viewingTrash: false)
            : ContentQueryBrowseOpen(object: created, parent: nil, viewingTrash: false)
        do { navigate(.object(try router.objects.resolve(open)), source: source) }
        catch { convertFailure = navigationFailure(error as? WorkspaceOpenFailure ?? .invalidTarget) }
    }

    /// routine.capture 回执“打开新习惯”：位置由规格给出，与转换后打开习惯同一解析与导航。
    func openSimpleCreated(_ facts: CommandSimpleFacts, source: UnifiedSearchBuffer) {
        guard validates(source), let open = simple?.openTarget(facts) else { return }
        guard let router = navigationRouter else { simpleFailure = "unified.navigation.unassembled"; return }
        do { navigate(.object(try router.objects.resolve(open)), source: source) }
        catch { simpleFailure = navigationFailure(error as? WorkspaceOpenFailure ?? .invalidTarget) }
    }

    /// 合并批 M-4：受保护手记、加私密标签与超长正文改在原手记页完成；沿 M-3 打开原页面里手记的目的地（手记页）。
    func openDiaryOriginalPage(_ source: UnifiedSearchBuffer) {
        guard validates(source) else { return }
        guard navigationRouter != nil else { simpleFailure = "unified.navigation.unassembled"; return }
        navigate(.page(.diary), source: source) { [weak self] _ in self?.navigationMessage = "unified.originalPage.displayed" }
    }

    func validReturn(_ ticket: UnifiedSearchReturnContext) -> Bool {
        ticket.id == returnSearch?.id && ticket.queryRevision == navigationQueryRevision
            && ticket.privacyRevision == buffer.privacyRevision && ticket.ownership == buffer.lease.ownership
            && (try? coordinator.validate(buffer.lease)) != nil
    }

    func returnToSearch(_ id: UUID) async {
        guard let ticket = returnSearch, ticket.id == id, validReturn(ticket), let router = navigationRouter else { return }
        do { try router.validateHost() } catch { navigationMessage = "unified.navigation.composing"; return }
        navigationTask?.cancel()
        navigationTask = nil
        navigationRequestID = nil
        if await router.commitInspectorBeforeNavigation() {
            guard returnSearch?.id == id, validReturn(ticket) else { return }
        }
        router.clearDestination()
        router.navigation.restoreSearchPage(ticket.tab, tag: ticket.tag)
        // 目的地上新输入的修改类指令是用户当前的意图，不用保留查询覆盖；导航指令（含导航过来时留下的那条）
        // 照旧换回保留查询。保留查询仍决定回来后读取的结果。
        if !isCommandInput || isNavigationInput { restoreQueryInput() }
        if (try? session.presentation().pagination.snapshot.version) != ticket.version || ticket.version == nil {
            preservedSearchScrollVersion = nil
            do {
                try session.resumeDisplay(expecting: buffer.lease)
                _ = try await readObjectSource()
                guard validReturn(ticket) else { return }
                restoreBrowse(ticket)
                navigationMessage = "unified.navigation.refreshed"
                if let active = ticket.active,
                   (try? session.presentation().pagination.snapshot.known.contains(active)) != true {
                    navigationMessage = "unified.navigation.missing"
                }
            } catch {
                guard validReturn(ticket) else { return }
                navigationMessage = "unified.results.readFailed"
            }
        } else {
            if let version = ticket.version, let point = ticket.scroll {
                preservedSearchScrollVersion = version
                restoreSearchScroll = (version, point)
            }
            navigationMessage = "unified.navigation.returned"
        }
        returnSearch = nil
        inputFocused = true
    }

    /// 工作台停在原页面（searchPresentation 为 false、不是从搜索导航过去）时操作面板没有宿主：输入指令即显示搜索页。
    /// 从搜索导航到的目的地持有返回票据，输入时不切页，由 Return／⌘Return 经 returnForCommand 回到搜索页。
    func showSearchForCommandOnOriginalPage() {
        guard isNavigationPresented, returnSearch == nil else { return }
        navigationRouter?.navigation.searchPresentation = true
    }

    /// 停在从搜索导航到的目的地（持有返回票据）时，操作面板没有宿主：修改类指令的 Return／⌘Return
    /// 先回到搜索页（保留指令文字）再按 Return 继续；已有草稿时 ⌘Return 只回到面板，不在用户看到预览前直接提交。
    /// 导航类指令不经过这里，仍在目的地之间跳转并保留票据。
    func returnForCommand(_ intent: UnifiedSearchIntent) -> Bool {
        guard intent == .open || intent == .submit, isCommandInput, !isNavigationInput,
              browsedCommand != nil || editingDraft != nil else { return false }
        let continues = intent == .open || editingDraft == nil
        return returnThenContinue { [weak self] source in
            if continues { self?.intent(.open, source: source) }
        }
    }

    /// 回到搜索页后再继续；只认按键当时的缓冲，期间改字、锁定或换所有者都不再继续。
    /// 票据失效回不去时给出原因，不覆盖 returnToSearch 已写的更具体原因（例如正在组词）。
    func returnThenContinue(_ next: @escaping (UnifiedSearchBuffer) -> Void) -> Bool {
        guard isNavigationPresented, let ticket = returnSearch else { return false }
        guard !commandReturnPending else { return true }
        commandReturnPending = true
        let source = buffer, message = navigationMessage
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.commandReturnPending = false }
            await self.returnToSearch(ticket.id)
            guard self.validates(source) else { return }
            guard !self.isNavigationPresented else {
                if self.navigationMessage == message { self.reportGate() }
                return
            }
            next(source)
        }
        return true
    }

    private func restoreBrowse(_ ticket: UnifiedSearchReturnContext) {
        guard let page = try? session.presentation().pagination else { return }
        // 原分页加载负责可见性；不把过期快照或候选拼回结果。
        let wanted = ticket.selected.union(ticket.active.map { [$0] } ?? [])
        for id in wanted where page.snapshot.known.contains(id) {
            for _ in 0..<100 {
                guard let current = try? session.presentation().pagination, !current.snapshot.visible.contains(id),
                      current.snapshot.known.contains(id) else { break }
                let action: ContentQueryPaginationAction
                if current.status.hasMoreUnits { action = .loadMoreUnits }
                else if let unit = current.snapshot.units.first(where: { $0.hits.contains(id) }),
                        current.status.groups.contains(where: { $0.unit == unit.id && $0.hits.remaining > 0 }) {
                    action = .loadMoreMembers(unit.id)
                } else { break }
                _ = try? session.loadMore(.init(stamp: current.stamp, action: action))
            }
        }
        guard let current = try? session.presentation().pagination else { return }
        for id in ticket.selected.intersection(current.snapshot.known) {
            _ = try? session.browse(.init(version: current.snapshot.version, action: .select(id, true)))
        }
        for control in ticket.expanded.intersection(Set(current.browse.toggleControls)) {
            _ = try? session.browse(.init(version: current.snapshot.version, action: .expand(control)))
        }
        if let active = ticket.active, current.snapshot.visible.contains(active) {
            _ = try? session.browse(.init(version: current.snapshot.version, action: .activate(active)))
        }
    }

    func newNavigationQuery() {
        navigationTask?.cancel()
        navigationTask = nil
        navigationRequestID = nil
        if let ticket = returnSearch, let router = navigationRouter {
            router.clearDestination()
            router.navigation.restoreSearchPage(ticket.tab, tag: ticket.tag)
        }
        returnSearch = nil
        restoreSearchScroll = nil
        preservedSearchScrollVersion = nil
        navigationQueryRevision &+= 1
        navigationRouter?.navigation.searchPresentation = true
    }

    func invalidateNavigation(privacy: Bool) {
        navigationTask?.cancel()
        navigationTask = nil
        navigationRequestID = nil
        navigationRouter?.clearDestination()
        if privacy {
            navigationRouter?.contents?.invalidate()
            returnSearch = nil
            restoreSearchScroll = nil
            preservedSearchScrollVersion = nil
            navigationQueryRevision &+= 1
            navigationRouter?.navigation.searchPresentation = true
        }
    }

    private func revokeNavigationAcceptances() {
        multiPlan?.invalidatePresentation()
        revokeRoutine(); revokeSubtask(); revokeBatch(); revokeTaskField(); revokeTaskTitle(); revokeTaskComposition()
        revokeTrash(); revokeTaskCopy(); revokeConvert(); revokeSimple(); revokePage(); clipboardCapture.revoke()
        chainCreationPreparation = nil
    }

    private func restoreQueryInput() {
        guard let query = try? coordinator.host(buffer.lease.ownership.hostID).session.query,
              case .content(let content) = query.input else { return }
        _ = navigationInput(content.source)
    }

    func navigationFailure(_ failure: WorkspaceOpenFailure) -> String {
        "unified.navigation." + failure.rawValue
    }
}
