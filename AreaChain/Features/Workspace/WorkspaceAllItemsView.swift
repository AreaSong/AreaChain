import SwiftData
import SwiftUI

struct WorkspaceAllItemsView: View {
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query private var checks: [RoutineCheck]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]

    @Environment(\.locale) private var locale
    @Bindable private var navigation = WorkspaceNavigation.shared

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

    private func controls(_ model: WorkspaceAllItemsPageModel) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            HStack(spacing: DaybookSpacing.sm) {
                scopeMenu(
                    ItemKindScope.allCases.map(\.titleKey),
                    selected: navigation.allItemsQuery.kind.titleKey
                ) { key in
                    guard let next = ItemKindScope.allCases.first(where: { $0.titleKey == key }) else { return }
                    navigation.allItemsQuery.kind = next
                }
                scopeMenu(
                    TodoStatusScope.allCases.map(\.titleKey),
                    selected: navigation.allItemsQuery.todoStatus.titleKey
                ) { key in
                    guard let next = TodoStatusScope.allCases.first(where: { $0.titleKey == key }) else { return }
                    navigation.allItemsQuery.todoStatus = next
                }
                scopeMenu(
                    RoutineStatusScope.allCases.map(\.titleKey),
                    selected: navigation.allItemsQuery.routineStatus.titleKey
                ) { key in
                    guard let next = RoutineStatusScope.allCases.first(where: { $0.titleKey == key }) else { return }
                    navigation.allItemsQuery.routineStatus = next
                }
            }
            BoardFilterBar(
                filter: navigation.allItemsQuery.filter,
                tags: CatalogChoices.tags(tags),
                bundleIDs: model.bundleIDs,
                showsPriority: true,
                showsDate: true,
                onChange: { navigation.allItemsQuery.filter = $0 }
            )
            if navigation.allItemsQuery.filter.dateScope != .all && navigation.allItemsQuery.kind != .oneOff {
                Text("items.routine.dateHint")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func scopeMenu(_ keys: [String], selected: String, choose: @escaping (String) -> Void) -> some View {
        Menu {
            ForEach(keys, id: \.self) { key in
                Button(LocalizedStringKey(key)) { choose(key) }
            }
        } label: {
            Text(LocalizedStringKey(selected))
                .font(DaybookType.caption)
                .daybookMenuLabel(size: .compact, fitsLabel: true)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
