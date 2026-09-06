import SwiftUI
import SwiftData

struct DiaryPage: View {
    @Environment(\.modelContext) private var modelContext

    var todayKey: String
    var yesterdayKey: String
    var entries: [DiaryEntry]

    @State private var viewingYesterday = false

    private var visibleKey: String {
        viewingYesterday ? yesterdayKey : todayKey
    }

    private var visibleEntries: [DiaryEntry] {
        let ids = Set(DayBoardLogic.diaries(for: visibleKey, in: entries.map(\.snapshot)).map(\.id))
        return entries
            .filter { ids.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                viewingYesterday.toggle()
            } label: {
                HStack(spacing: 6) {
                    Text(viewingYesterday ? "昨天的句子" : "今天的句子")
                    Text(DayKey.shortStamp(visibleKey))
                    Spacer()
                    Text(viewingYesterday ? "回今天" : "看昨天")
                }
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.muted)
            }
            .buttonStyle(.plain)

            if viewingYesterday {
                Text("写下仍会记到今天")
                    .font(.system(size: 10))
                    .foregroundStyle(DaybookTheme.muted)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if visibleEntries.isEmpty {
                        Text(viewingYesterday ? "昨天没有留下句子。" : "还没有今天的日记。⌘回车写下第一句。")
                            .font(.system(size: 12))
                            .foregroundStyle(DaybookTheme.muted)
                            .padding(.top, 8)
                    } else {
                        ForEach(visibleEntries, id: \.id) { entry in
                            diaryLine(entry)
                        }
                    }
                }
            }
        }
    }

    private func diaryLine(_ entry: DiaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(timeLabel(entry.createdAt))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(DaybookTheme.stamp.opacity(0.9))
            Text(entry.text)
                .font(.system(size: 13))
                .foregroundStyle(DaybookTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            Button("删除", role: .destructive) {
                modelContext.delete(entry)
            }
        }
    }

    private func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
