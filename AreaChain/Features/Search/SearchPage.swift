import SwiftData
import SwiftUI

struct SearchPage: View {
    @Environment(\.locale) private var locale
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query(sort: \DiaryEntry.createdAt, order: .reverse) private var diaries: [DiaryEntry]
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @State private var query = ""
    @State private var autocomplete = SyntaxAutocompleteState(context: .search)
    @FocusState private var searchFocus: Bool

    private var tagMap: [UUID: String] {
        Dictionary(uniqueKeysWithValues: tags.filter { $0.deletedAt == nil }.map { ($0.id, $0.name) })
    }

    var body: some View {
        DaybookPage(title: "window.search", minWidth: 420, minHeight: 480) {
            DaybookField {
                ZStack(alignment: .topLeading) {
                    DaybookTextField(
                        text: $query,
                        placeholder: L10n.string("search.placeholder", locale: locale),
                        focus: $searchFocus,
                        autocomplete: autocomplete,
                        availableTags: tags.filter { $0.deletedAt == nil }.map(\.name),
                        onSubmit: {},
                        onCommandReturn: {},
                        allowsShiftNewline: false
                    )
                    .accessibilityLabel("search.placeholder")
                    .daybookHideInputChrome()

                    if autocomplete.isActive {
                        SyntaxAutocompletePopup(state: autocomplete) { candidate in
                            if let trigger = autocomplete.trigger {
                                let (newText, _) = SyntaxAutocompleteEngine.applyCandidate(
                                    candidate,
                                    to: query,
                                    range: trigger.range
                                )
                                query = newText
                                autocomplete.dismiss()
                            }
                        }
                        .padding(.top, 24)
                        .zIndex(100)
                    }
                }
            }
            if BoardSearch.normalized(query).isEmpty {
                DaybookEmptyState(title: "search.hint", systemImage: "magnifyingglass")
            } else if hits.isEmpty {
                DaybookEmptyState(title: "search.empty", systemImage: "magnifyingglass")
            } else {
                SearchResultsView(hits: hits)
            }
        }
    }

    private var hits: [BoardSearchHit] {
        BoardSearch.hits(
            query: query,
            todos: todos.map(\.snapshot),
            diaries: diaries.map(\.snapshot),
            routines: routines.map(\.snapshot),
            todayKey: DayClock.shared.todayKey,
            tagMap: tagMap,
            privacy: BoardSearchPrivacy(
                sensitiveDiaryIDs: Set(diaries.filter { DiaryPrivacy.isSensitive($0.snapshot, tags: tags) }.map(\.id)),
                placeholder: L10n.string("diary.private.title", locale: locale)
            )
        )
    }
}
