import SwiftData
import SwiftUI

struct WorkspacePendingView: View {
    @Environment(\.locale) private var locale
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query private var checks: [RoutineCheck]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]

    @WorkspaceNavigationContext private var navigation

    private var todayKey: String { DayClock.shared.todayKey }

    var body: some View {
        let model = makePageModel()
        DaybookPage(title: "tab.pending", systemImage: "clock", minWidth: 480, minHeight: 480) {
            Button("items.goToday") { openTodayComposer() }
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
        } content: {
            controls(model)
            WorkspaceItemsList(
                groups: [WorkspaceItemGroup(id: "pending", title: nil, entries: model.visibleEntries)],
                todayKey: model.todayKey,
                checks: checks,
                filterActive: navigation.pendingFilter.isActive,
                emptyTitle: navigation.pendingFilter.isActive ? "empty.filter" : emptyCopy(model.lane).title,
                emptySubtitle: navigation.pendingFilter.isActive ? "empty.filter.hint" : emptyCopy(model.lane).hint
            )
        }
        .workspaceHeader(actions: [WorkspaceHeaderAction(id: "today.add", title: "items.goToday", systemImage: "plus", perform: openTodayComposer)])
        .workspaceInspectorTargets(model.visibleIDs)
        .refreshBoardOnDayChange()
        .onAppear {
            if navigation.pendingLaneSession == nil {
                navigation.pendingLaneSession = PendingLaneSession(overdueCount: model.projection.overdueCount)
            }
        }
        .onChange(of: model.projection.overdueCount) { _, count in
            guard var session = navigation.pendingLaneSession else { return }
            session.refreshDefault(overdueCount: count)
            navigation.pendingLaneSession = session
        }
        .onChange(of: model.visibleIDs) { _, ids in
            navigation.reconcileTaskSelection(with: ids)
        }
    }

    private func makePageModel() -> WorkspacePendingPageModel {
        WorkspacePendingPageModel.make(
            routines: routines,
            todos: todos,
            checks: checks,
            todayKey: todayKey,
            navigation: navigation
        )
    }

    private func controls(_ model: WorkspacePendingPageModel) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            HStack(spacing: DaybookSpacing.sm) {
                laneChip(.overdue, count: model.projection.overdueCount, model: model)
                laneChip(.upcoming, count: model.projection.upcomingCount, model: model)
            }
            BoardFilterBar(
                filter: navigation.pendingFilter,
                tags: CatalogChoices.tags(tags),
                bundleIDs: model.bundleIDs,
                showsPriority: true,
                onChange: { navigation.pendingFilter = $0 }
            )
        }
        .padding(DaybookSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.card, style: .continuous)
                .fill(DaybookPalette.fill.page)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.card, style: .continuous)
                .strokeBorder(DaybookPalette.border.subtle, lineWidth: 0.5)
        )
    }

    private func emptyCopy(_ lane: PendingLane) -> (title: LocalizedStringKey, hint: LocalizedStringKey) {
        switch lane {
        case .overdue:
            return ("items.empty.overdue", "items.empty.overdue.hint")
        case .upcoming:
            return ("items.empty.upcoming", "items.empty.upcoming.hint")
        }
    }

    private func laneChip(_ next: PendingLane, count: Int, model: WorkspacePendingPageModel) -> some View {
        DaybookChip(isSelected: model.lane == next, action: chooseLane(next, overdueCount: model.projection.overdueCount), label: {
            Text("\(laneTitle(next)) \(count)")
                .font(DaybookType.caption)
        })
        .accessibilityLabel(laneTitle(next))
    }

    private func chooseLane(_ next: PendingLane, overdueCount: Int) -> () -> Void {
        {
            var session = navigation.pendingLaneSession
                ?? PendingLaneSession(overdueCount: overdueCount)
            session.choose(next)
            navigation.pendingLaneSession = session
        }
    }

    private func laneTitle(_ lane: PendingLane) -> String {
        switch lane {
        case .overdue: L10n.string("items.pending.overdue", locale: locale)
        case .upcoming: L10n.string("items.pending.upcoming", locale: locale)
        }
    }

    private func openTodayComposer() {
        navigation.revealTab(.today)
        navigation.wantsTodayComposerFocus = true
    }
}
