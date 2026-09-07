import SwiftData
import SwiftUI

struct DiaryPage: View {
    @Environment(\.modelContext) private var modelContext

    var todayKey: String
    var entries: [DiaryEntry]
    var showsComposer: Bool = false

    @State private var viewingKey: String
    @State private var draft = ""
    @FocusState private var composerFocused: Bool

    init(todayKey: String, entries: [DiaryEntry], showsComposer: Bool = false) {
        self.todayKey = todayKey
        self.entries = entries
        self.showsComposer = showsComposer
        _viewingKey = State(initialValue: todayKey)
    }

    private var isViewingToday: Bool {
        viewingKey == todayKey
    }

    private var visibleEntries: [DiaryEntry] {
        let ids = Set(DayBoardLogic.diaries(for: viewingKey, in: entries.map(\.snapshot)).map(\.id))
        return entries
            .filter { ids.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            dayChrome
            if !isViewingToday {
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
        .onChange(of: todayKey) { _, newValue in
            if viewingKey > newValue {
                viewingKey = newValue
            }
        }
    }

    private var dayChrome: some View {
        HStack(spacing: 8) {
            Button {
                viewingKey = DayKey.shifted(viewingKey, by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("前一天")

            VStack(alignment: .leading, spacing: 1) {
                Text(isViewingToday ? "今天的句子" : DayKey.displayName(viewingKey))
                Text(DayKey.shortStamp(viewingKey))
            }
            .font(.system(size: 11))
            .foregroundStyle(DaybookTheme.muted)

            Button {
                viewingKey = DayKey.shifted(viewingKey, by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .disabled(isViewingToday)
            .accessibilityLabel("后一天")

            Spacer()
            if !isViewingToday {
                Button("回今天") { viewingKey = todayKey }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundStyle(DaybookTheme.stamp)
            }
        }
    }

    private var entryList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if visibleEntries.isEmpty {
                    Text(emptyCopy)
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

    private var emptyCopy: String {
        isViewingToday ? "还没有今天的日记。⌘回车写下第一句。" : "这一天没有留下句子。"
    }

    private func addTodayDiary() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        modelContext.insert(DiaryEntry(text: text, dayKey: todayKey))
        draft = ""
        viewingKey = todayKey
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
