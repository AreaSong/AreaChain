import SwiftData
import SwiftUI

struct DiaryPage: View {
    @Environment(\.modelContext) private var modelContext

    var todayKey: String
    var yesterdayKey: String
    var entries: [DiaryEntry]
    var showsComposer: Bool = false

    @State private var viewingYesterday = false
    @State private var draft = ""
    @FocusState private var composerFocused: Bool

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
            dayToggle
            if viewingYesterday {
                Text("写下仍会记到今天")
                    .font(.system(size: 10))
                    .foregroundStyle(DaybookTheme.muted)
            }
            if showsComposer {
                TextField("回车写一句今天的日记", text: $draft)
                    .textFieldStyle(.plain)
                    .focused($composerFocused)
                    .onSubmit(addTodayDiary)
            }
            entryList
        }
    }

    private var dayToggle: some View {
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
    }

    private var entryList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if visibleEntries.isEmpty {
                    Text(viewingYesterday ? "昨天没有留下句子。" : "还没有今天的日记。⌘回车写下第一句。")
                        .font(.system(size: 12))
                        .foregroundStyle(DaybookTheme.muted)
                        .padding(.top, 8)
                } else {
                    ForEach(visibleEntries, id: \.id) { entry in
                        DiaryLine(entry: entry)
                    }
                }
            }
        }
    }

    private func addTodayDiary() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        modelContext.insert(DiaryEntry(text: text, dayKey: todayKey))
        draft = ""
    }
}

struct DiaryLine: View {
    @Environment(\.modelContext) private var modelContext
    var entry: DiaryEntry
    @State private var editing = false
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(timeLabel(entry.createdAt))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(DaybookTheme.stamp.opacity(0.9))
            if editing {
                TextField("改这句", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit(save)
            } else {
                Text(entry.text)
                    .font(.system(size: 13))
                    .foregroundStyle(DaybookTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .onTapGesture {
                        draft = entry.text
                        editing = true
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            Button("改字") {
                draft = entry.text
                editing = true
            }
            Button("删除", role: .destructive) {
                modelContext.delete(entry)
            }
        }
        .onAppear { draft = entry.text }
    }

    private func save() {
        let next = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !next.isEmpty {
            entry.text = next
        }
        editing = false
    }

    private func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
