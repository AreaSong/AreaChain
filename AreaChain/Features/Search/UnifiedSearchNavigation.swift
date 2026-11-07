import Foundation

/// 返回票据只有定位及版本。查询/正文仍留在各自唯一所有者中。
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
    var isNavigationPresented: Bool { navigationRouter?.navigation.searchPresentation == false }

    func navigationInput(_ text: String) -> UnifiedSearchBuffer? {
        publishOperation(text: text)
    }

    func openResult(_ open: ContentQueryBrowseOpen, source: UnifiedSearchBuffer,
                    then completion: ((WorkspaceNavigationOutcome) -> Void)? = nil) {
        guard validates(source), let router = navigationRouter else {
            navigationMessage = "unified.navigation.unassembled"
            return
        }
        do {
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

    func navigate(_ destination: WorkspaceNavigationDestination, source: UnifiedSearchBuffer,
                  content: ContentQueryBrowseOpen? = nil, origin: CommandObjectReference? = nil,
                  then completion: ((WorkspaceNavigationOutcome) -> Void)? = nil) {
        guard validates(source), let router = navigationRouter else {
            navigationMessage = "unified.navigation.unassembled"
            return
        }
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

    func openDiaryOriginalPage(_ source: UnifiedSearchBuffer) {
        guard validates(source), navigationRouter != nil else { return }
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
        if !isCommandInput { restoreQueryInput() }
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

    private func restoreQueryInput() {
        guard let query = try? coordinator.host(buffer.lease.ownership.hostID).session.query,
              case .content(let content) = query.input else { return }
        _ = navigationInput(content.source)
    }

    func navigationFailure(_ failure: WorkspaceOpenFailure) -> String {
        "unified.navigation." + failure.rawValue
    }
}
