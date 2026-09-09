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

    var selectedTab: WorkspaceTab = .today {
        didSet {
            selectedProjectID = nil
            selectedTagID = nil
            clearSelection()
            if selectedTab != .diary {
                BoardSelection.shared.clearInspectedDiary()
            }
            pinTodayInspectDayIfEnteringTab()
        }
    }

    var selectedProjectID: UUID? = nil {
        didSet {
            if selectedProjectID != nil {
                selectedTagID = nil
                BoardSelection.shared.clearInspectedDiary()
                pinTodayInspectDay()
            }
            clearSelection()
        }
    }

    var selectedTagID: UUID? = nil {
        didSet {
            if selectedTagID != nil {
                selectedProjectID = nil
                BoardSelection.shared.clearInspectedDiary()
                pinTodayInspectDay()
            }
            clearSelection()
        }
    }

    var selectedTaskID: UUID? = nil
    var selectedTaskIDs: Set<UUID> = []
    var isInspectorPresented: Bool = false

    func revealTab(_ tab: WorkspaceTab) {
        if tab != .diary {
            BoardSelection.shared.clearInspectedDiary()
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
    }

    func inspectTask(_ id: UUID) {
        if InspectDayPolicy.pinsTodayWhenInspecting(
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
        BoardSelection.shared.inspectBoard(DayClock.shared.todayKey)
    }
}
