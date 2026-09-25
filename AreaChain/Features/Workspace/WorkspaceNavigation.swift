import SwiftUI

enum WorkspaceTab: String, CaseIterable, Identifiable {
    case dashboard
    case today
    case pending
    case allItems
    case calendar
    case quadrant
    case gantt
    case diary
    case attachments
    case tags
    case privacy
    case dataBackup
    case trash
    case settings
    /// 内部全局搜索路由，不出现在侧栏。
    case search

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .dashboard: return "tab.dashboard"
        case .today: return "tab.today"
        case .pending: return "tab.pending"
        case .allItems: return "tab.allItems"
        case .calendar: return "window.calendar"
        case .quadrant: return "window.quadrant"
        case .gantt: return "window.gantt"
        case .diary: return "window.diary"
        case .attachments: return "window.attachments"
        case .tags: return "tab.tags"
        case .privacy: return "tab.privacy"
        case .dataBackup: return "tab.dataBackup"
        case .trash: return "window.trash"
        case .settings: return "window.settings"
        case .search: return "window.search"
        }
    }

    var iconName: String {
        switch self {
        case .dashboard: return "rectangle.grid.1x2"
        case .today: return "checklist"
        case .pending: return "clock"
        case .allItems: return "list.bullet"
        case .calendar: return "calendar"
        case .quadrant: return "square.grid.2x2"
        case .gantt: return "chart.bar.xaxis"
        case .diary: return "note.text"
        case .attachments: return "paperclip"
        case .tags: return "tag"
        case .privacy: return "lock"
        case .dataBackup: return "externaldrive"
        case .trash: return "trash"
        case .settings: return "gearshape"
        case .search: return "magnifyingglass"
        }
    }
}

enum InspectDayPolicy {
    static func pinsTodayWhenInspecting(tab: WorkspaceTab, tagID: UUID?) -> Bool {
        _ = tab
        return tagID != nil
    }

    static func pinsTodayWhenEntering(_ tab: WorkspaceTab) -> Bool {
        tab == .today
    }
}

@Observable
@MainActor
final class WorkspaceNavigation {
    static let shared = WorkspaceNavigation()

    let boardSelection: BoardSelection

    init(boardSelection: BoardSelection) {
        self.boardSelection = boardSelection
    }

    convenience init() {
        self.init(boardSelection: .shared)
    }

    // MARK: - Forwarding Board Inspection Properties
    var inspectingDayKey: String {
        get { boardSelection.inspectingDayKey }
        set { boardSelection.inspectingDayKey = newValue }
    }

    var diaryDayKey: String {
        get { boardSelection.diaryDayKey }
        set { boardSelection.diaryDayKey = newValue }
    }

    var inspectingDiaryID: UUID? {
        get { boardSelection.inspectingDiaryID }
        set { boardSelection.inspectingDiaryID = newValue }
    }

    var discardEditsOnBlur: Bool {
        get { boardSelection.discardEditsOnBlur }
        set { boardSelection.discardEditsOnBlur = newValue }
    }

    // MARK: - Header Bar Title Visibility
    var isInlineTitleVisible: Bool = false

    // MARK: - Tab & Filter Navigation
    var selectedTab: WorkspaceTab = .dashboard {
        didSet {
            selectedTagID = nil
            isInlineTitleVisible = (selectedTab == .settings || selectedTab == .trash || selectedTab == .search)
            clearSelection()
            if selectedTab != .diary {
                boardSelection.clearInspectedDiary()
            }
            pinTodayInspectDayIfEnteringTab()
        }
    }

    var selectedTagID: UUID? = nil {
        didSet {
            if selectedTagID != nil {
                isInlineTitleVisible = false
                boardSelection.clearInspectedDiary()
                pinTodayInspectDay()
            }
            clearSelection()
        }
    }

    // MARK: - Global Search
    var searchQuery: String = ""
    var isSearchFocused: Bool = false
    var wantsTodayComposerFocus: Bool = false

    var isSearching: Bool {
        !BoardSearch.normalized(searchQuery).isEmpty
    }

    func focusSearch() {
        isSearchFocused = true
    }

    func clearSearch() {
        searchQuery = ""
        isSearchFocused = false
    }

    // MARK: - Task Inspector & Multi-Selection
    var selectedTaskID: UUID? = nil
    var inspectedReference: BoardItemReference?
    var selectedTaskIDs: Set<UUID> = []
    private(set) var selectionAnchorID: UUID?
    var isInspectorPresented: Bool = false

    // MARK: - Navigation & Inspection Actions
    func inspectBoard(_ key: String) {
        boardSelection.inspectBoard(key)
    }

    func inspectDiary(id: UUID, dayKey: String) {
        boardSelection.inspectDiary(id: id, dayKey: dayKey)
    }

    func clearInspectedDiary() {
        boardSelection.clearInspectedDiary()
    }

    func markEscapeCancelsEdits() {
        boardSelection.markEscapeCancelsEdits()
    }

    func consumeEscapeCancelsEdits() -> Bool {
        boardSelection.consumeEscapeCancelsEdits()
    }

    func revealTab(_ tab: WorkspaceTab, inspecting taskID: UUID? = nil, dayKey: String? = nil) {
        if tab == .search {
            focusSearch()
            return
        }
        if tab != .diary {
            boardSelection.clearInspectedDiary()
        }
        if selectedTab != tab {
            selectedTab = tab
        } else {
            selectedTagID = nil
            if InspectDayPolicy.pinsTodayWhenEntering(tab) {
                pinTodayInspectDay()
            }
        }
        // 普通导航可以归位今天；带检查目标的导航必须在归位后恢复调用方的日期。
        if let taskID {
            inspectTask(taskID, dayKey: dayKey)
        }
    }

    /// Inspects a task, optionally synchronizing the inspecting board day in a single call.
    func inspectTask(_ id: UUID, dayKey: String? = nil) {
        inspectedReference = nil
        if let dayKey {
            boardSelection.inspectBoard(dayKey)
        } else if InspectDayPolicy.pinsTodayWhenInspecting(
            tab: selectedTab,
            tagID: selectedTagID
        ) {
            pinTodayInspectDay()
        }
        selectedTaskID = id
        isInspectorPresented = true
    }

    func closeInspector() {
        isInspectorPresented = false
    }

    func toggleSelection(_ id: UUID) {
        if selectedTaskIDs.contains(id) {
            selectedTaskIDs.remove(id)
        } else {
            selectedTaskIDs.insert(id)
        }
        selectionAnchorID = id
    }

    func selectTask(_ id: UUID, in visibleIDs: [UUID], modifiers: TaskSelectionModifiers = []) {
        guard visibleIDs.contains(id) else { return }
        let current = selectedTaskIDs.isEmpty ? Set(selectedTaskID.map { [$0] } ?? []) : selectedTaskIDs
        let anchor = selectionAnchorID ?? (selectedTaskIDs.isEmpty ? selectedTaskID : nil)
        var selection = TaskSelection(ids: current, anchorID: anchor)
        selection.select(id, in: visibleIDs, modifiers: modifiers)
        if modifiers.isEmpty {
            clearSelection()
            inspectTask(id)
        } else {
            selectedTaskIDs = selection.ids
            selectedTaskID = selection.ids.contains(id) ? id : visibleIDs.first { selection.ids.contains($0) }
        }
        selectionAnchorID = selection.anchorID
    }

    func selectAllTasks(in visibleIDs: [UUID]) {
        selectedTaskIDs = Set(visibleIDs)
        selectionAnchorID = visibleIDs.first
    }

    func reconcileTaskSelection(with visibleIDs: [UUID]) {
        selectedTaskIDs.formIntersection(visibleIDs)
        if let selectionAnchorID, !visibleIDs.contains(selectionAnchorID) { self.selectionAnchorID = nil }
    }

    func clearSelection() {
        selectedTaskIDs.removeAll()
        selectionAnchorID = nil
    }

    private func pinTodayInspectDayIfEnteringTab() {
        guard InspectDayPolicy.pinsTodayWhenEntering(selectedTab) else { return }
        pinTodayInspectDay()
    }

    private func pinTodayInspectDay() {
        boardSelection.inspectBoard(DayClock.shared.todayKey)
    }
}
