import SwiftData
import SwiftUI

struct WorkspacePendingView: View {
    @Environment(\.locale) private var locale
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query private var checks: [RoutineCheck]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]

    @WorkspaceNavigationContext private var navigation

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var laneIndicatorNamespace

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
        .onKeyPress(KeyEquivalent("[")) {
            cycleLane(model: model)
            return .handled
        }
        .onKeyPress(KeyEquivalent("]")) {
            cycleLane(model: model)
            return .handled
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
        HStack(spacing: 8) {
            laneSegmentBar(model)

            Spacer(minLength: 8)

            BoardFilterBar(
                filter: navigation.pendingFilter,
                tags: CatalogChoices.tags(tags),
                bundleIDs: model.bundleIDs,
                showsPriority: true,
                showsReminder: true,
                onChange: { navigation.pendingFilter = $0 }
            )
        }
        .padding(.horizontal, 1)
        .padding(.top, 1)
    }

    private func laneSegmentBar(_ model: WorkspacePendingPageModel) -> some View {
        HStack(spacing: 2) {
            laneSegmentItem(.overdue, count: model.projection.overdueCount, model: model)
            laneSegmentItem(.upcoming, count: model.projection.upcomingCount, model: model)
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .fill(DaybookPalette.fill.subtle)
        )
    }

    private func laneSegmentItem(_ next: PendingLane, count: Int, model: WorkspacePendingPageModel) -> some View {
        let isSelected = model.lane == next
        let isOverdueAlert = next == .overdue && count > 0
        return Button(action: { chooseLane(next, overdueCount: model.projection.overdueCount)() }) {
            HStack(spacing: 5) {
                Text(laneTitle(next))
                    .font(DaybookType.caption.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? (isOverdueAlert ? DaybookPalette.accent.base : DaybookPalette.text.primary) : DaybookPalette.text.secondary)
                Text("\(count)")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded)) // token-exempt: 赛道计数用圆体
                    .foregroundStyle(isSelected ? (isOverdueAlert ? DaybookPalette.accent.base : DaybookPalette.text.primary) : DaybookPalette.text.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        Capsule() // token-exempt: 赛道数量标签底槽胶囊
                            .fill(isSelected ? (isOverdueAlert ? DaybookPalette.accent.base.opacity(0.14) : DaybookPalette.fill.subtle) : Color.clear) // token-exempt: 14% 强调色胶囊底
                    )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: DaybookRadius.small - 1, style: .continuous)
                        .fill(DaybookPalette.cardSurface)
                        .matchedGeometryEffect(id: "pendingLaneActivePill", in: laneIndicatorNamespace)
                        .overlay {
                            RoundedRectangle(cornerRadius: DaybookRadius.small - 1, style: .continuous)
                                .strokeBorder(DaybookPalette.border.default.opacity(0.6), lineWidth: 0.5) // token-exempt: 60% 边框微弱描边
                        }
                        .daybookElevation(.raised)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain) // control: 分段选择器按钮
        .animation(DaybookMotion.snappy(reduceMotion), value: model.lane)
        .accessibilityLabel(Text("\(laneTitle(next)) \(count)"))
    }

    private func emptyCopy(_ lane: PendingLane) -> (title: LocalizedStringKey, hint: LocalizedStringKey) {
        switch lane {
        case .overdue:
            return ("items.empty.overdue", "items.empty.overdue.hint")
        case .upcoming:
            return ("items.empty.upcoming", "items.empty.upcoming.hint")
        }
    }

    private func cycleLane(model: WorkspacePendingPageModel) {
        let next: PendingLane = model.lane == .overdue ? .upcoming : .overdue
        chooseLane(next, overdueCount: model.projection.overdueCount)()
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
