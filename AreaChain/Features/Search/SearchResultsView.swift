import SwiftData
import SwiftUI

/// 工作台与菜单栏共用结果展示，私密正文仍由 BoardSearch 在生成命中项前遮罩。
struct SearchResultsView: View {
    var hits: [BoardSearchHit]
    @Environment(\.modelContext) private var context

    var body: some View {
        ScrollView {
            BoardSearchHitGroups(hits: hits, open: open)
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
