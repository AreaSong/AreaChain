import SwiftData
import SwiftUI

struct WorkspaceAllItemsView: View {
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query private var checks: [RoutineCheck]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]

    @Environment(\.locale) private var locale
    @WorkspaceNavigationContext private var navigation

    private var todayKey: String { DayClock.shared.todayKey }

    var body: some View {
        let model = makePageModel()
        DaybookPage(title: "tab.allItems", systemImage: "list.bullet", minWidth: 480, minHeight: 480) {
            controls(model)
            if model.liveQuery.isNarrowed {
                Button("items.filter.clear") { navigation.allItemsQuery = model.liveQuery.cleared() }
                    .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
            }
            WorkspaceItemsList(
                groups: model.groups,
                todayKey: todayKey,
                checks: checks,
                filterActive: model.liveQuery.isNarrowed,
                emptyTitle: model.liveQuery.isNarrowed ? "empty.filter" : "items.empty",
                emptySubtitle: model.liveQuery.isNarrowed ? "empty.filter.hint" : "items.empty.hint"
            )
        }
        .workspaceInspectorTargets(model.visibleIDs)
        .refreshBoardOnDayChange()
        .onAppear { navigation.allItemsQuery.todayKey = todayKey }
        .onChange(of: model.visibleIDs) { _, ids in
            navigation.reconcileTaskSelection(with: ids)
        }
    }

    private func makePageModel() -> WorkspaceAllItemsPageModel {
        WorkspaceAllItemsPageModel.make(
            routines: routines,
            todos: todos,
            checks: checks,
            todayKey: todayKey,
            navigation: navigation,
            locale: locale
        )
    }

    @State private var activeDropdown: ActiveScopeDropdown? = nil

    private enum ActiveScopeDropdown: Hashable {
        case kind, todoStatus, routineStatus
    }

    private func controls(_ model: WorkspaceAllItemsPageModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                scopeControls

                Spacer(minLength: 8)

                BoardFilterBar(
                    filter: navigation.allItemsQuery.filter,
                    tags: CatalogChoices.tags(tags),
                    bundleIDs: model.bundleIDs,
                    showsPriority: true,
                    showsReminder: true,
                    showsDate: true,
                    onChange: { navigation.allItemsQuery.filter = $0 }
                )
            }
            .padding(.horizontal, 1)
            .padding(.top, 1)

            if navigation.allItemsQuery.filter.dateScope != .all && navigation.allItemsQuery.kind != .oneOff {
                Text("items.routine.dateHint")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 1)
            }
        }
    }

    private var scopeControls: some View {
        HStack(spacing: 6) {
            kindDropdown
            if navigation.allItemsQuery.kind != .recurring {
                todoStatusDropdown
            }
            if navigation.allItemsQuery.kind != .oneOff {
                routineStatusDropdown
            }
        }
    }

    private var kindDropdown: some View {
        let isExpanded = Binding(
            get: { activeDropdown == .kind },
            set: { activeDropdown = $0 ? .kind : nil }
        )
        let active = navigation.allItemsQuery.kind != .all
        let title: String = {
            if active {
                return L10n.string(String.LocalizationValue(navigation.allItemsQuery.kind.titleKey), locale: locale)
            }
            return L10n.string("items.scope.kind", locale: locale)
        }()
        let allOption = FilterDropdownOption(
            id: "all",
            title: L10n.string("items.kind.all", locale: locale),
            isSelected: navigation.allItemsQuery.kind == .all,
            action: { navigation.allItemsQuery.kind = .all }
        )
        let items: [FilterDropdownOption] = [
            FilterDropdownOption(
                id: "oneOff",
                title: L10n.string("items.kind.oneOff", locale: locale),
                icon: "checkmark.circle",
                isSelected: navigation.allItemsQuery.kind == .oneOff,
                action: { navigation.allItemsQuery.kind = .oneOff }
            ),
            FilterDropdownOption(
                id: "recurring",
                title: L10n.string("items.kind.recurring", locale: locale),
                icon: "repeat",
                isSelected: navigation.allItemsQuery.kind == .recurring,
                action: { navigation.allItemsQuery.kind = .recurring }
            )
        ]
        return BoardFilterDropdownButton(
            icon: "square.grid.2x2",
            title: title,
            active: active,
            isExpanded: isExpanded,
            reset: { navigation.allItemsQuery.kind = .all },
            allOption: allOption,
            items: items
        )
    }

    private var todoStatusDropdown: some View {
        let isExpanded = Binding(
            get: { activeDropdown == .todoStatus },
            set: { activeDropdown = $0 ? .todoStatus : nil }
        )
        let active = navigation.allItemsQuery.todoStatus != .all
        let title: String = {
            if active {
                return L10n.string(String.LocalizationValue(navigation.allItemsQuery.todoStatus.titleKey), locale: locale)
            }
            return L10n.string("items.scope.todoStatus", locale: locale)
        }()
        let allOption = FilterDropdownOption(
            id: "all",
            title: L10n.string("items.scope.todoStatus.all", locale: locale),
            isSelected: navigation.allItemsQuery.todoStatus == .all,
            action: { navigation.allItemsQuery.todoStatus = .all }
        )
        let items: [FilterDropdownOption] = [
            FilterDropdownOption(
                id: "open",
                title: L10n.string("items.status.open", locale: locale),
                icon: "circle",
                isSelected: navigation.allItemsQuery.todoStatus == .open,
                action: { navigation.allItemsQuery.todoStatus = .open }
            ),
            FilterDropdownOption(
                id: "done",
                title: L10n.string("items.status.done", locale: locale),
                icon: "checkmark.circle.fill",
                isSelected: navigation.allItemsQuery.todoStatus == .done,
                action: { navigation.allItemsQuery.todoStatus = .done }
            )
        ]
        return BoardFilterDropdownButton(
            icon: "checkmark.circle",
            title: title,
            active: active,
            isExpanded: isExpanded,
            reset: { navigation.allItemsQuery.todoStatus = .all },
            allOption: allOption,
            items: items
        )
    }

    private var routineStatusDropdown: some View {
        let isExpanded = Binding(
            get: { activeDropdown == .routineStatus },
            set: { activeDropdown = $0 ? .routineStatus : nil }
        )
        let active = navigation.allItemsQuery.routineStatus != .all
        let title: String = {
            if active {
                return L10n.string(String.LocalizationValue(navigation.allItemsQuery.routineStatus.titleKey), locale: locale)
            }
            return L10n.string("items.scope.routineStatus", locale: locale)
        }()
        let allOption = FilterDropdownOption(
            id: "all",
            title: L10n.string("items.scope.routineStatus.all", locale: locale),
            isSelected: navigation.allItemsQuery.routineStatus == .all,
            action: { navigation.allItemsQuery.routineStatus = .all }
        )
        let items: [FilterDropdownOption] = [
            FilterDropdownOption(
                id: "enabled",
                title: L10n.string("items.status.enabled", locale: locale),
                icon: "play.circle",
                isSelected: navigation.allItemsQuery.routineStatus == .enabled,
                action: { navigation.allItemsQuery.routineStatus = .enabled }
            ),
            FilterDropdownOption(
                id: "disabled",
                title: L10n.string("items.status.disabled", locale: locale),
                icon: "pause.circle",
                isSelected: navigation.allItemsQuery.routineStatus == .disabled,
                action: { navigation.allItemsQuery.routineStatus = .disabled }
            )
        ]
        return BoardFilterDropdownButton(
            icon: "repeat",
            title: title,
            active: active,
            isExpanded: isExpanded,
            reset: { navigation.allItemsQuery.routineStatus = .all },
            allOption: allOption,
            items: items
        )
    }
}
