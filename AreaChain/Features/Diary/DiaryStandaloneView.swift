import SwiftData
import SwiftUI

struct DiaryStandaloneView: View {
    @Environment(\.daybookViewStyle) private var style
    private var dayClock: DayClock { DayClock.shared }
    @Query(sort: \DiaryEntry.createdAt, order: .reverse) private var diaries: [DiaryEntry]

    var body: some View {
        DiaryPage(
            todayKey: dayClock.todayKey,
            entries: diaries,
            showsComposer: true,
            usesSharedDiaryDay: true
        )
        .padding(DaybookSpacing.page)
        .frame(minWidth: style.isWorkspace ? 0 : 360, maxWidth: .infinity, minHeight: style.isWorkspace ? 0 : 420, maxHeight: .infinity, alignment: .topLeading)
        .background(style.pageBackground)
    }
}
