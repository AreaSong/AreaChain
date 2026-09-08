import SwiftData
import SwiftUI

enum WorkspaceTab: String, CaseIterable, Identifiable {
    case today
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
        case .calendar: return "calendar"
        case .quadrant: return "square.grid.2x2"
        case .gantt: return "chart.bar.xaxis"
        case .diary: return "book.closed"
        case .attachments: return "paperclip"
        case .search: return "magnifyingglass"
        case .trash: return "trash"
        case .settings: return "gearshape"
        }
    }
}

@Observable
@MainActor
final class WorkspaceNavigation {
    static let shared = WorkspaceNavigation()
    var selectedTab: WorkspaceTab = .today
}

struct MainSplitWorkspaceView: View {
    @Bindable private var navigation = WorkspaceNavigation.shared

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("AreaChain")
    }

    private var sidebar: some View {
        List(selection: $navigation.selectedTab) {
            Section("tab.tasks") {
                tabRow(.today)
                tabRow(.search)
            }
            Section("window.calendar") {
                tabRow(.calendar)
                tabRow(.quadrant)
                tabRow(.gantt)
            }
            Section("window.diary") {
                tabRow(.diary)
                tabRow(.attachments)
                tabRow(.trash)
            }
            Section("window.settings") {
                tabRow(.settings)
            }
        }
        .listStyle(.sidebar)
    }

    private func tabRow(_ tab: WorkspaceTab) -> some View {
        Label(tab.titleKey, systemImage: tab.iconName)
            .tag(tab)
            .font(.system(size: 12))
    }

    @ViewBuilder
    private var detailView: some View {
        switch navigation.selectedTab {
        case .today:
            WorkspaceTodayView()
        case .calendar:
            CalendarStandaloneView()
        case .quadrant:
            QuadrantStandaloneView()
        case .gantt:
            GanttStandaloneView()
        case .diary:
            DiaryStandaloneView()
        case .attachments:
            AttachmentBrowserPage()
        case .search:
            SearchPage()
        case .trash:
            TrashPage()
        case .settings:
            SettingsView()
        }
    }
}

struct WorkspaceTodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    private var dayClock: DayClock { DayClock.shared }

    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query private var checks: [RoutineCheck]

    @State private var dayTick = Date()
    @State private var capture = CaptureSession.shared
    @FocusState private var captureFocused: Bool

    var body: some View {
        let todayKey: String = {
            _ = dayTick
            return dayClock.todayKey
        }()

        VStack(alignment: .leading, spacing: 12) {
            Text(DayKey.displayName(todayKey, locale: locale))
                .font(.system(size: 22, weight: .regular, design: .serif).italic())
                .foregroundStyle(DaybookTheme.ink)

            CaptureField(
                text: $capture.draft,
                focus: $captureFocused,
                onTodo: addTodo,
                onDiary: addDiary
            )

            TasksPage(
                todayKey: todayKey,
                yesterdayKey: dayClock.yesterdayKey,
                routines: routines,
                checks: checks,
                todos: todos
            )
        }
        .daybookPanel(minWidth: 480, minHeight: 480)
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            DayClock.shared.refresh()
            dayTick = Date()
        }
    }

    private func addTodo() {
        let title = capture.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let todayKey = dayClock.todayKey
        modelContext.insert(
            TodoItem(
                title: title,
                dayKey: todayKey,
                sourceBundleID: CaptureStamp.current(enabled: AppPreferences.shared.stampCaptureApp)
            )
        )
        capture.draft = ""
        BoardEvents.changed()
    }

    private func addDiary() {
        let text = capture.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        modelContext.insert(DiaryEntry(text: text, dayKey: dayClock.todayKey))
        capture.draft = ""
        BoardEvents.changed()
    }
}
