import Foundation

extension WorkspaceNavigation {
    /// 只有普通页签访问使用新 visit；明确导航暂挂不进入查询 reducer。
    func queryContext(hostID: String, filters: BoardFilters, calendar: Calendar, pendingLane: PendingLane) -> ContentQueryPageContext {
        let today = DayKey.today(calendar: calendar)
        let day = ContentQueryDateInterval(lowerBound: inspectingDayKey, upperBound: inspectingDayKey)
        let page: ContentQueryPage
        if let selectedTagID { page = .tagContents(tagID: selectedTagID, types: [.todo, .subtask, .routine]) }
        else {
            switch selectedTab {
            case .dashboard: page = .overview
            case .today: page = .today(filters.tasks)
            case .pending: page = .pending(lane: pendingLaneSession?.lane ?? pendingLane, filter: pendingFilter)
            case .allItems: page = .items(allItemsQuery)
            case .calendar: page = .calendar(day)
            case .gantt:
                let days = DayKey.daysInMonth(containing: today, calendar: calendar)
                page = .schedule(.init(lowerBound: days.first ?? today, upperBound: days.last ?? today))
            case .quadrant: page = .quadrants(dayKey: inspectingDayKey, selection: nil)
            case .diary: page = .diaries(tagID: filters.diary.tagID)
            case .attachments: page = .images
            case .clipboard: page = .clipboard
            case .tags: page = .tags
            case .privacy: page = .privacy
            case .dataBackup: page = .backup
            case .trash: page = .trash
            case .settings: page = .settings
            case .shortcuts: page = .shortcuts
            }
        }
        return .init(location: .init(hostID: hostID, visitID: UUID().uuidString, reference: contentIdentity),
                     page: page, todayKey: today, calendar: calendar)
    }
}

extension UnifiedSearchController {
    func ordinaryWorkspaceVisit(_ host: WorkspaceHostContext, pendingLane: PendingLane) {
        guard host.navigation.searchPresentation == nil, let router = navigationRouter else { return }
        navigationTask?.cancel()
        navigationTask = nil
        returnSearch = nil
        navigationQueryRevision &+= 1
        do {
            try session.modelDidChange(expecting: buffer.lease.ownership)
            let page = host.navigation.queryContext(hostID: buffer.lease.ownership.hostID,
                filters: host.filters.filters, calendar: router.objects.calendar, pendingLane: pendingLane)
            try coordinator.send(.query(.enterPage(page)), expecting: buffer.lease)
            _ = navigationInput(queryInputText)
            host.navigation.searchPresentation = try coordinator.host(buffer.lease.ownership.hostID).session.query.showsResults
            if host.navigation.isSearching { refresh() }
        } catch { navigationMessage = "unified.navigation.stale" }
    }
}
