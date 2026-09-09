import SwiftData
import SwiftUI

struct SearchPage: View {
    @Environment(\.locale) private var locale
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query(sort: \DiaryEntry.createdAt, order: .reverse) private var diaries: [DiaryEntry]
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Bindable private var selection = BoardSelection.shared
    @State private var query = ""

    var body: some View {
        DaybookPage(title: "window.search", minWidth: 420, minHeight: 480) {
            DaybookField {
                TextField("search.placeholder", text: $query)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("search.placeholder")
                    .daybookHideInputChrome()
            }
            if BoardSearch.normalized(query).isEmpty {
                DaybookEmptyState(title: "search.hint", systemImage: "magnifyingglass")
            } else if groups.isEmpty {
                DaybookEmptyState(title: "search.empty", systemImage: "magnifyingglass")
            } else {
                results
            }
        }
    }

    private var groups: [(dayKey: String, items: [BoardSearchHit])] {
        BoardSearch.grouped(
            BoardSearch.hits(
                query: query,
                todos: todos.map(\.snapshot),
                diaries: diaries.map(\.snapshot),
                routines: routines.map(\.snapshot),
                todayKey: DayClock.shared.todayKey
            )
        )
    }

    private var results: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(groups, id: \.dayKey) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(DayKey.displayName(group.dayKey, locale: locale))
                            .font(DaybookType.caption.weight(.semibold))
                            .foregroundStyle(DaybookTheme.muted)
                        ForEach(group.items) { hit in
                            hitRow(hit)
                        }
                    }
                }
            }
        }
        .daybookScroll()
    }

    private func hitRow(_ hit: BoardSearchHit) -> some View {
        Button {
            open(hit)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Text(kindLabel(hit.kind))
                    .font(DaybookType.badge.weight(.semibold))
                    .foregroundStyle(DaybookTheme.stamp)
                    .frame(width: 36, alignment: .leading)
                Text(hit.title)
                    .font(DaybookType.body)
                    .foregroundStyle(DaybookTheme.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(DaybookQuietButtonStyle())
        .help(hit.title)
    }

    private func kindLabel(_ kind: BoardSearchHit.Kind) -> LocalizedStringKey {
        switch kind {
        case .todo: "search.kind.todo"
        case .diary: "search.kind.diary"
        case .routine: "search.kind.routine"
        }
    }

    private func open(_ hit: BoardSearchHit) {
        switch hit.kind {
        case .todo, .routine:
            selection.inspectBoard(hit.dayKey)
            WorkspaceNavigation.shared.inspectTask(hit.id)
            AppWindows.openCalendar()
        case .diary:
            selection.inspectDiary(id: hit.id, dayKey: hit.dayKey)
            AppWindows.openDiary()
        }
    }
}
