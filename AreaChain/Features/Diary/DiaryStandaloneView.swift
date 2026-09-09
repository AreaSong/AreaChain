import SwiftData
import SwiftUI

struct DiaryStandaloneView: View {
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
        .frame(minWidth: 360, maxWidth: .infinity, minHeight: 420, maxHeight: .infinity, alignment: .topLeading)
        .background(DaybookTheme.paper.opacity(0.94))
    }
}
