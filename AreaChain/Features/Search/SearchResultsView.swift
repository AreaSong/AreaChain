import SwiftData
import SwiftUI

/// 工作台与菜单栏共用结果展示，私密正文仍由 BoardSearch 在生成命中项前遮罩。
struct SearchResultsView: View {
    var hits: [BoardSearchHit]
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(BoardSearch.grouped(hits), id: \.dayKey) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(DayKey.displayName(group.dayKey, locale: locale))
                            .font(DaybookType.caption.weight(.semibold))
                            .foregroundStyle(DaybookTheme.muted)
                        ForEach(group.items) { hit in
                            BoardSearchHitRow(hit: hit) { open(hit) }
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .daybookScroll()
    }

    private func open(_ hit: BoardSearchHit) {
        switch hit.kind {
        case .todo, .routine:
            AppWindows.openWorkspace(tab: .calendar, inspecting: hit.id, dayKey: hit.dayKey)
        case .diary:
            if let entry = ModelChanges.value({ try SwiftDataDiaryRepository(context: context).fetchDiary(id: hit.id) }) ?? nil,
               entry.deletedAt == nil {
                DiaryWindows.shared.open(entry: entry, context: context)
            }
        case .subtask:
            AppWindows.openWorkspace(tab: .calendar, inspecting: hit.parentID, dayKey: hit.dayKey)
        }
    }
}
