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
        VStack(alignment: .leading, spacing: 12) {
            TextField("search.placeholder", text: $query)
                .textFieldStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(DaybookTheme.rule, lineWidth: 1)
                )
                .daybookHideInputChrome()
            if BoardSearch.normalized(query).isEmpty {
                Text("search.hint")
                    .font(.system(size: 12))
                    .foregroundStyle(DaybookTheme.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if groups.isEmpty {
                Text("search.empty")
                    .font(.system(size: 12))
                    .foregroundStyle(DaybookTheme.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                results
            }
        }
        .padding(16)
        .frame(minWidth: 420, minHeight: 480)
        .background(DaybookTheme.paper.opacity(0.94))
    }

    private var groups: [(dayKey: String, items: [BoardSearchHit])] {
        BoardSearch.grouped(
            BoardSearch.hits(
                query: query,
                todos: todos.map(\.snapshot),
                diaries: diaries.map(\.snapshot),
                routines: routines.map(\.snapshot)
            )
        )
    }

    private var results: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(groups, id: \.dayKey) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(DayKey.displayName(group.dayKey, locale: locale))
                            .font(.system(size: 11, weight: .semibold))
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
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DaybookTheme.stamp)
                    .frame(width: 36, alignment: .leading)
                Text(hit.title)
                    .font(.system(size: 13))
                    .foregroundStyle(DaybookTheme.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        case .todo:
            selection.inspectBoard(hit.dayKey)
            AppWindows.openCalendar()
        case .routine:
            selection.inspectBoard(DayClock.shared.todayKey)
            AppWindows.openCalendar()
        case .diary:
            selection.inspectDiary(hit.dayKey)
            AppWindows.openDiary()
        }
    }
}
