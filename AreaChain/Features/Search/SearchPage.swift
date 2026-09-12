import SwiftData
import SwiftUI

struct SearchPage: View {
    @Environment(\.locale) private var locale
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query(sort: \DiaryEntry.createdAt, order: .reverse) private var diaries: [DiaryEntry]
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @Bindable private var selection = BoardSelection.shared
    @State private var query = ""
    @State private var autocomplete = SyntaxAutocompleteState()
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
                        onSubmit: {}
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
                todayKey: DayClock.shared.todayKey,
                tagMap: tagMap,
                privacy: BoardSearchPrivacy(
                    sensitiveDiaryIDs: Set(diaries.filter { DiaryPrivacy.isSensitive($0.snapshot, tags: tags) }.map(\.id)),
                    placeholder: L10n.string("diary.private.title", locale: locale)
                )
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
            AppWindows.openWorkspace(tab: .calendar, inspecting: hit.id, dayKey: hit.dayKey)
        case .diary:
            selection.inspectDiary(id: hit.id, dayKey: hit.dayKey)
            AppWindows.openDiary()
        }
    }
}
