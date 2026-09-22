import SwiftUI

/// 手记上下文菜单和 ⌘ 命令条共用的标签勾选。
struct DiaryTagToggleButtons: View {
    var tags: [TagItem]
    var assignedIDs: Set<UUID>
    var onToggle: (UUID) -> Void

    var body: some View {
        ForEach(tags) { tag in
            Button {
                onToggle(tag.id)
            } label: {
                HStack {
                    Text("#" + tag.name)
                    if assignedIDs.contains(tag.id) {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }
}

/// 手记上下文菜单和 ⌘ 命令条共用的改期项。
struct DiaryDayMoveButtons: View {
    var onMove: (String) -> Void
    var onPickCustom: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        Button(L10n.string("diary.schedule.today", locale: locale)) {
            onMove(DayKey.today())
        }
        Button(L10n.string("diary.schedule.yesterday", locale: locale)) {
            onMove(DayKey.yesterday())
        }
        Button(L10n.string("diary.schedule.tomorrow", locale: locale)) {
            onMove(DayKey.tomorrow())
        }
        Divider()
        Button(L10n.string("diary.schedule.custom", locale: locale)) {
            onPickCustom()
        }
    }
}
