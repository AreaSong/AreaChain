import SwiftUI

/// 工作台与菜单栏共用结果展示，私密正文仍由 BoardSearch 在生成命中项前遮罩。
struct SearchResultsView: View {
    var hits: [BoardSearchHit]
    @Environment(\.locale) private var locale

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(BoardSearch.grouped(hits), id: \.dayKey) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(DayKey.displayName(group.dayKey, locale: locale))
                            .font(DaybookType.caption.weight(.semibold))
                            .foregroundStyle(DaybookTheme.muted)
                        ForEach(group.items) { hit in
                            resultButton(hit)
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .daybookScroll()
    }

    private func resultButton(_ hit: BoardSearchHit) -> some View {
        Button { open(hit) } label: {
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
        case .routine: "search.kind.routine"
        case .diary: "search.kind.diary"
        }
    }

    private func open(_ hit: BoardSearchHit) {
        switch hit.kind {
        case .todo, .routine:
            AppWindows.openWorkspace(tab: .calendar, inspecting: hit.id, dayKey: hit.dayKey)
        case .diary:
            BoardSelection.shared.inspectDiary(id: hit.id, dayKey: hit.dayKey)
            AppWindows.openDiary()
        }
    }
}
