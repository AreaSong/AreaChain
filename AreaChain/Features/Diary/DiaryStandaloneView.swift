import SwiftData
import SwiftUI

struct DiaryStandaloneView: View {
    private var dayClock: DayClock { DayClock.shared }
    @Query(sort: \DiaryEntry.createdAt, order: .reverse) private var diaries: [DiaryEntry]

    var body: some View {
        DiaryPage(
            todayKey: dayClock.todayKey,
            entries: diaries,
            showsComposer: true
        )
        .padding(16)
        .frame(minWidth: 360, minHeight: 420)
        .background(DaybookTheme.paper.opacity(0.94))
    }
}
