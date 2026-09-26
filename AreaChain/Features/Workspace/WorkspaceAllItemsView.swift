import SwiftData
import SwiftUI

struct WorkspaceAllItemsView: View {
    @Environment(\.locale) private var locale
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query private var checks: [RoutineCheck]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]

    @Bindable private var navigation = WorkspaceNavigation.shared

    private var todayKey: String { DayClock.shared.todayKey }

    var body: some View {
        DaybookPage(title: "tab.allItems", systemImage: "list.bullet", minWidth: 480, minHeight: 480) {
            if liveQuery.isNarrowed {
                Button("items.filter.clear") { navigation.allItemsQuery = liveQuery.cleared() }
                    .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
            }
        } content: {
            controls
            WorkspaceItemsList(
                groups: itemGroups,
                todayKey: todayKey,
                checks: checks,
                filterActive: liveQuery.isNarrowed,
                emptyTitle: liveQuery.isNarrowed ? "empty.filter" : "items.empty",
                emptySubtitle: liveQuery.isNarrowed ? "empty.filter.hint" : "items.empty.hint"
            )
        }
        .onAppear { navigation.allItemsQuery.todayKey = todayKey }
        .onChange(of: visibleIDs) { _, ids in
            navigation.reconcileTaskSelection(with: ids)
        }
    }

    private var controls: some View {
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
                bundleIDs: bundleIDs,
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
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var itemGroups: [WorkspaceItemGroup] {
        var groups: [WorkspaceItemGroup] = []
        if liveQuery.kind != .recurring, !todoEntries.isEmpty {
            groups.append(WorkspaceItemGroup(id: "todos", title: "items.section.todos", entries: todoEntries))
        }
        if liveQuery.kind != .oneOff, !routineEntries.isEmpty {
            groups.append(WorkspaceItemGroup(id: "routines", title: "items.section.routines", entries: routineEntries))
        }
        return groups
    }

    private var listedTodos: [ListedTodo] {
        ItemsListing.todos(todos.map(\.snapshot), query: liveQuery)
    }

    private var listedRoutines: [RoutineSnapshot] {
        ItemsListing.routines(routines.map(\.snapshot), checks: checks.compactMap(\.snapshot), query: liveQuery)
    }

    private var liveQuery: ItemsListingQuery {
        var next = navigation.allItemsQuery
        next.todayKey = todayKey
        return next
    }

    private var todoEntries: [WorkspaceItemEntry] {
        listedTodos.compactMap { listed in
            guard let todo = todos.first(where: { $0.id == listed.id }) else { return nil }
            return .todo(todo, checkDayKey: listed.todo.dayKey, subtaskIDs: Set(listed.subtasks.map(\.id)))
        }
    }

    private var routineEntries: [WorkspaceItemEntry] {
        listedRoutines.compactMap { snapshot in
            guard let routine = routines.first(where: { $0.id == snapshot.id }) else { return nil }
            let dueToday = DayBoardLogic.isRoutineDue(snapshot, on: todayKey)
            let next = AgendaProjection.nextDay(after: todayKey, routine: snapshot)
            return .routine(
                routine,
                checkDayKey: AgendaProjection.inspectionDay(for: snapshot, todayKey: todayKey),
                allowsCompletion: dueToday,
                overdueCount: 0,
                noteDayKey: dueToday ? nil : next
            )
        }
    }

    private var visibleIDs: [UUID] {
        (todoEntries + routineEntries).map(\.modelID)
    }

    private var bundleIDs: [String] {
        let values = todos.map(\.sourceBundleID) + routines.map(\.sourceBundleID)
        return Array(Set(values.filter { !$0.isEmpty })).sorted()
    }
}
