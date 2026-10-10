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
    var isNavigationInput: Bool { browsedCommand?.category == .navigation }
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
        if let page = WorkspaceNavigationDestination.page(command: command.id), parsed.arguments.isEmpty,
           parsed.state == .command {
            navigate(.page(page), source: source)
        } else if command.id.rawValue == "inspector.day" {
            guard parsed.state == .command,
                  case .day(let day)? = parsed.arguments.first(where: { $0.parameter == .day })?.value,
                  let date = DayKey.date(from: day, calendar: router.objects.calendar),
                  DayKey.from(date, calendar: router.objects.calendar) == day else {
                navigationMessage = "unified.navigation.chooseDay"; return
            }
            navigate(.day(day), source: source)
        } else if command.id.rawValue == "inspector.open" {
            guard parsed.state != .invalid, parsed.arguments.isEmpty,
                  parsed.diagnostics.allSatisfy({ $0.issue == .chooseParameter && $0.range.length == 0 }) else {
                navigationMessage = "unified.navigation.invalidTarget"; return
            }
            guard let page = try? session.presentation().pagination, page.browse.active != nil else {
                navigationMessage = "unified.navigation.chooseObject"; return
            }
            browse(.init(version: page.snapshot.version, action: .open(inputEditing: false)), source: source)
        } else { navigationMessage = "unified.navigation.unsupported" }
    }

    func openResult(_ open: ContentQueryBrowseOpen, source: UnifiedSearchBuffer) {
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
            let location = try router.objects.resolve(open)
            guard validates(source), (try? session.presentation().pagination.snapshot.version) == page.snapshot.version else {
                throw WorkspaceOpenFailure.stale
            }
            navigate(.object(location), source: source)
        } catch { navigationMessage = navigationFailure(error as? WorkspaceOpenFailure ?? .invalidTarget) }
    }

    private func navigate(_ destination: WorkspaceNavigationDestination, source: UnifiedSearchBuffer) {
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
            case .displayed: self.navigationMessage = "unified.navigation.displayed"
            case .locatedWithoutInspector: self.navigationMessage = "unified.navigation.needsSpace"
            case .rejected(let reason):
                self.navigationMessage = self.navigationFailure(reason)
                if self.validReturn(ticket) { await self.returnToSearch(ticket.id) }
            }
        }
    }

    func validReturn(_ ticket: UnifiedSearchReturnContext) -> Bool {
        ticket.id == returnSearch?.id && ticket.queryRevision == navigationQueryRevision
            && ticket.privacyRevision == buffer.privacyRevision && ticket.ownership == buffer.lease.ownership
            && (try? coordinator.validate(buffer.lease)) != nil
    }

    func returnToSearch(_ id: UUID) async {
        guard let ticket = returnSearch, ticket.id == id, validReturn(ticket), let router = navigationRouter else { return }
        do { try router.validateHost() } catch { navigationMessage = "unified.navigation.composing"; return }
        router.inspectorFocus.retainForNavigation()
        router.clearDestination()
        router.navigation.restoreSearchPage(ticket.tab, tag: ticket.tag)
        restoreQueryInput()
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
        chainCreationPreparation = nil
    }

    private func restoreQueryInput() {
        guard let query = try? coordinator.host(buffer.lease.ownership.hostID).session.query,
              case .content(let content) = query.input else { return }
        _ = navigationInput(content.source)
    }

    private func navigationFailure(_ failure: WorkspaceOpenFailure) -> String {
        "unified.navigation." + failure.rawValue
    }
}
