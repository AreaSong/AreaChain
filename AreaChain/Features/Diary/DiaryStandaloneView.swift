import SwiftData
import SwiftUI

struct DiaryStandaloneView: View {
    @Environment(\.workspaceEmbedded) private var embedded
    private var dayClock: DayClock { DayClock.shared }
    @Query(sort: \DiaryEntry.createdAt, order: .reverse) private var diaries: [DiaryEntry]
    @Bindable private var filterSession = BoardFilterSession.shared

    var body: some View {
        DiaryPage(
            todayKey: dayClock.todayKey,
            entries: diaries,
            showsComposer: true,
            usesSharedDiaryDay: true,
            externalFilter: Binding(
                get: { filterSession.filters.diary },
                set: { writeDiaryFilter($0) }
            )
        )
        .padding(DaybookSpacing.page)
        .frame(minWidth: embedded ? 0 : 360, maxWidth: .infinity, minHeight: embedded ? 0 : 420, maxHeight: .infinity, alignment: .topLeading)
        .background(DaybookPalette.fill.page)
    }

    private func writeDiaryFilter(_ filter: BoardFilter) {
        var next = filterSession.filters
        next.write(filter, for: .diary)
        filterSession.filters = next
    }
}
