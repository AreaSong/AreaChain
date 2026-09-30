import SwiftData
import SwiftUI

private struct BoardReorderEntriesKey: EnvironmentKey {
    static let defaultValue: [ManualOrderEntry] = []
}

extension EnvironmentValues {
    var boardReorderEntries: [ManualOrderEntry] {
        get { self[BoardReorderEntriesKey.self] }
        set { self[BoardReorderEntriesKey.self] = newValue }
    }
}

struct BoardReorderDrop: ViewModifier {
    var targetID: UUID
    @Environment(\.boardReorderEntries) private var entries
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        // 日历改期使用另一套拖放令牌。空顺序不能装一个会拒绝放下的目的地，否则周列收不到改期。
        if entries.isEmpty {
            content
        } else {
            content.dropDestination(for: String.self) { items, _ in
                guard let raw = items.first, let moving = BoardReorderToken.decode(raw),
                      let next = ManualOrder.reordered(entries, moving: moving, before: targetID) else {
                    return false
                }
                let day = next.first { $0.id == moving }?.dayKey
                let changed = next.filter { $0.dayKey == day }
                return DayBoardMutations.applyManualOrder(changed, context: modelContext)
            }
        }
    }
}
