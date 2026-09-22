import SwiftData
import SwiftUI

struct MenuBarSearchResults: View {
    var query: String
    var filter: BoardFilter
    var onClearSearch: () -> Void
    var onClearFilter: () -> Void

    @Environment(\.locale) private var locale
    @Query private var todos: [TodoItem]
    @Query private var routines: [DailyRoutine]
    @Query private var diaries: [DiaryEntry]
    @Query private var tags: [TagItem]
    @Query private var projects: [ProjectItem]

    var body: some View {
        let results = hits
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("search.results.count \(results.count)")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookTheme.muted)
                Spacer()
                Button("footer.search.clear", action: onClearSearch)
                    .font(DaybookType.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(DaybookTheme.stamp)
            }
            Text(query)
                .font(DaybookType.body.weight(.medium))
                .foregroundStyle(DaybookTheme.ink)
                .lineLimit(2)
                .help(query)

            if results.isEmpty {
                DaybookEmptyState(title: "search.empty", systemImage: "magnifyingglass")
                if filter.isActive {
                    Button("footer.filter.clear", action: onClearFilter)
                        .buttonStyle(DaybookQuietButtonStyle())
                }
                Spacer(minLength: 0)
            } else {
                SearchResultsView(hits: results)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("menubar.search.results")
    }

    private var hits: [BoardSearchHit] {
        let projectIDs = filter.projectID.map { ProjectTree.subtreeIDs(root: $0, in: projects) }
        return BoardSearch.hits(
            query: query,
            todos: todos.map(\.snapshot),
            diaries: diaries.map { DiaryContent.snapshot($0) },
            routines: routines.map(\.snapshot),
            todayKey: DayClock.shared.todayKey,
            tagMap: Dictionary(uniqueKeysWithValues: tags.filter { $0.deletedAt == nil }.map { ($0.id, $0.name) }),
            privacy: BoardSearchPrivacy.protected(diaries: Array(diaries), tags: Array(tags), locale: locale),
            scope: BoardSearchScope(filter: filter, projectIDs: projectIDs)
        )
    }
}
