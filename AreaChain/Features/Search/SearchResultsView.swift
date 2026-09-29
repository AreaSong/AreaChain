import SwiftData
import SwiftUI

/// 菜单栏搜索结果：打开任务走日历检查器。工作台顶栏用 `BoardSearchHitGroups` 就地打开，不走这条路由。
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
