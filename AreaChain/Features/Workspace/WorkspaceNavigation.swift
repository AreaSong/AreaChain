import SwiftUI

enum WorkspaceTab: String, CaseIterable, Identifiable {
    case today
    case residents
    case calendar
    case quadrant
    case gantt
    case diary
    case attachments
    case search
    case trash
    case settings

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .today: return "tab.tasks"
        case .residents: return "tab.residents"
        case .calendar: return "window.calendar"
        case .quadrant: return "window.quadrant"
        case .gantt: return "window.gantt"
        case .diary: return "window.diary"
        case .attachments: return "window.attachments"
        case .search: return "window.search"
        case .trash: return "window.trash"
        case .settings: return "window.settings"
        }
    }

    var iconName: String {
        switch self {
        case .today: return "checklist"
        case .residents: return "repeat"
        case .calendar: return "calendar"
        case .quadrant: return "square.grid.2x2"
        case .gantt: return "chart.bar.xaxis"
        case .diary: return "note.text"
        case .attachments: return "paperclip"
        case .search: return "magnifyingglass"
        case .trash: return "trash"
        case .settings: return "gearshape"
        }
    }
}

enum InspectDayPolicy {
    static func pinsTodayWhenInspecting(tab: WorkspaceTab, projectID: UUID?, tagID: UUID?) -> Bool {
        tab == .residents || projectID != nil || tagID != nil
    }

    static func pinsTodayWhenEntering(_ tab: WorkspaceTab) -> Bool {
        tab == .today || tab == .residents
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

    // MARK: - Tab & Filter Navigation
    var selectedTab: WorkspaceTab = .today {
        didSet {
            selectedProjectID = nil
            selectedTagID = nil
            clearSelection()
            if selectedTab != .diary {
                boardSelection.clearInspectedDiary()
            }
            pinTodayInspectDayIfEnteringTab()
        }
    }

    var selectedProjectID: UUID? = nil {
        didSet {
            if selectedProjectID != nil {
                selectedTagID = nil
                boardSelection.clearInspectedDiary()
                pinTodayInspectDay()
            }
            clearSelection()
        }
    }

    var selectedTagID: UUID? = nil {
        didSet {
            if selectedTagID != nil {
                selectedProjectID = nil
                boardSelection.clearInspectedDiary()
                pinTodayInspectDay()
            }
            clearSelection()
        }
    }

    // MARK: - Task Inspector & Multi-Selection
    var selectedTaskID: UUID? = nil
    var selectedTaskIDs: Set<UUID> = []
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
        if tab != .diary {
            boardSelection.clearInspectedDiary()
        }
        if selectedTab != tab {
            selectedTab = tab
        } else {
            selectedProjectID = nil
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
        if let dayKey {
            boardSelection.inspectBoard(dayKey)
        } else if InspectDayPolicy.pinsTodayWhenInspecting(
            tab: selectedTab,
            projectID: selectedProjectID,
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
    }

    func clearSelection() {
        selectedTaskIDs.removeAll()
    }

    private func pinTodayInspectDayIfEnteringTab() {
        guard InspectDayPolicy.pinsTodayWhenEntering(selectedTab) else { return }
        pinTodayInspectDay()
    }

    private func pinTodayInspectDay() {
        boardSelection.inspectBoard(DayClock.shared.todayKey)
    }
}
