import SwiftData
import SwiftUI

struct DiaryStandaloneView: View {
    @Environment(\.workspaceEmbedded) private var embedded
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
        .frame(minWidth: embedded ? 0 : 360, maxWidth: .infinity, minHeight: embedded ? 0 : 420, maxHeight: .infinity, alignment: .topLeading)
        .background(DaybookPalette.fill.page)
    }
}
