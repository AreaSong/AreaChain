import SwiftData
import SwiftUI

struct WorkspacePendingView: View {
    @Environment(\.locale) private var locale
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query private var checks: [RoutineCheck]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]

    @Bindable private var navigation = WorkspaceNavigation.shared
    @State private var laneSession: PendingLaneSession?
    @State private var filter = BoardFilter()

    private var todayKey: String { DayClock.shared.todayKey }

    private var projection: PendingProjection {
        AgendaProjection.pending(
            routines: routines.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            todos: todos.map(\.snapshot),
            todayKey: todayKey
        )
    }

    private var lane: PendingLane {
        laneSession?.lane ?? PendingLanePolicy.initial(overdueCount: projection.overdueCount)
    }

    var body: some View {
        DaybookPage(title: "tab.pending", systemImage: "clock", minWidth: 480, minHeight: 480) {
            Button("items.goToday") { openTodayComposer() }
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
        } content: {
            controls
            WorkspaceItemsList(
                groups: [WorkspaceItemGroup(id: "pending", title: nil, entries: visibleEntries)],
                todayKey: todayKey,
                checks: checks,
                filterActive: filter.isActive,
                emptyTitle: filter.isActive ? "empty.filter" : emptyCopy.title,
                emptySubtitle: filter.isActive ? "empty.filter.hint" : emptyCopy.hint
            )
        }
        .onAppear {
            if laneSession == nil {
                laneSession = PendingLaneSession(overdueCount: projection.overdueCount)
            }
        }
        .onChange(of: projection.overdueCount) { _, count in
            laneSession?.refreshDefault(overdueCount: count)
        }
        .onChange(of: visibleIDs) { _, ids in
            navigation.reconcileTaskSelection(with: ids)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            HStack(spacing: DaybookSpacing.sm) {
                laneChip(.overdue, count: projection.overdueCount)
                laneChip(.upcoming, count: projection.upcomingCount)
            }
            BoardFilterBar(
                filter: filter,
                tags: CatalogChoices.tags(tags),
                bundleIDs: bundleIDs,
                showsPriority: true,
                onChange: { filter = $0 }
            )
        }
    }

    private var emptyCopy: (title: LocalizedStringKey, hint: LocalizedStringKey) {
        switch lane {
        case .overdue:
            return ("items.empty.overdue", "items.empty.overdue.hint")
        case .upcoming:
            return ("items.empty.upcoming", "items.empty.upcoming.hint")
        }
    }

    private func laneChip(_ next: PendingLane, count: Int) -> some View {
        DaybookChip(isSelected: lane == next, action: {
            var session = laneSession ?? PendingLaneSession(overdueCount: projection.overdueCount)
            session.choose(next)
            laneSession = session
        }) {
            Text("\(laneTitle(next)) \(count)")
                .font(DaybookType.caption)
        }
        .accessibilityLabel(laneTitle(next))
    }

    private func laneTitle(_ lane: PendingLane) -> String {
        switch lane {
        case .overdue: L10n.string("items.pending.overdue", locale: locale)
        case .upcoming: L10n.string("items.pending.upcoming", locale: locale)
        }
    }

    private var visibleEntries: [WorkspaceItemEntry] {
        let filtered = AgendaProjection.filtered(
            projection.entries(for: lane),
            filter: filter,
            routines: routines.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            todayKey: todayKey
        )
        return filtered.compactMap(entry)
    }

    private var visibleIDs: [UUID] { visibleEntries.map(\.modelID) }

    private var bundleIDs: [String] {
        let ids = projection.entries(for: lane).compactMap { entry -> String? in
            switch entry {
            case .todo(let todo): return todo.sourceBundleID
            case .routine(let row):
                return routines.first { $0.id == row.routineID }?.sourceBundleID
            }
        }
        return Array(Set(ids.filter { !$0.isEmpty })).sorted()
    }

    private func entry(_ item: AgendaEntry) -> WorkspaceItemEntry? {
        switch item {
        case .todo(let snapshot):
            guard let todo = todos.first(where: { $0.id == snapshot.id }) else { return nil }
            let listed = ItemsListing.todos([snapshot], query: ItemsListingQuery(filter: filter, todayKey: todayKey))
            let ids = listed.first.map { Set($0.subtasks.map(\.id)) }
            return .todo(todo, checkDayKey: snapshot.dayKey, subtaskIDs: ids)
        case .routine(let row):
            guard let routine = routines.first(where: { $0.id == row.routineID }) else { return nil }
            return .routine(
                routine,
                checkDayKey: row.displayDayKey,
                allowsCompletion: lane == .overdue,
                overdueCount: row.openCount,
                noteDayKey: lane == .upcoming ? row.displayDayKey : nil
            )
        }
    }

    private func openTodayComposer() {
        navigation.revealTab(.today)
        navigation.wantsTodayComposerFocus = true
    }
}
