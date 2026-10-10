import SwiftData
import SwiftUI

/// 菜单栏搜索结果：打开任务走日历检查器。工作台顶栏用 `BoardSearchHitGroups` 就地打开，不走这条路由。
struct SearchResultsView: View {
    var hits: [BoardSearchHit]
    @Binding var resultIndex: Int?
    var onLeaveToField: () -> Void
    var workspaceOpening: AppWindows.WorkspaceOpening? = nil
    @Environment(\.modelContext) private var context

    var body: some View {
        let ordered = SearchResultOrder.flat(hits)
        ScrollView {
            BoardSearchHitGroups(
                hits: hits,
                isHighlighted: { hit in
                    guard let resultIndex, ordered.indices.contains(resultIndex) else { return false }
                    let current = ordered[resultIndex]
                    return current.id == hit.id && current.kind == hit.kind && current.dayKey == hit.dayKey
                },
                open: open
            )
            .padding(.vertical, 2)
        }
        .daybookScroll()
        .modifier(SearchResultKeys(
            hits: hits,
            index: $resultIndex,
            onOpen: open,
            onComplete: { SearchHitCommands.complete($0, context: context) },
            onLeaveToField: onLeaveToField
        ))
    }

    private func open(_ hit: BoardSearchHit) {
        switch hit.kind {
        case .todo, .routine:
            AppWindows.openWorkspace(tab: .calendar, inspecting: hit.id, dayKey: hit.dayKey, opening: workspaceOpening)
        case .diary:
            if let entry = ModelChanges.value({ try SwiftDataDiaryRepository(context: context).fetchDiary(id: hit.id) }) ?? nil,
               entry.deletedAt == nil {
                DiaryWindows.shared.open(entry: entry, context: context)
            }
        case .subtask:
            AppWindows.openWorkspace(tab: .calendar, inspecting: hit.parentID, dayKey: hit.dayKey, opening: workspaceOpening)
        }
    }
}
