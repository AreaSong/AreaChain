import Foundation
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Widget Diary Item

struct WidgetDiaryItem: Identifiable, Hashable {
    var id: UUID
    var text: String
    var timeText: String
    var isPinned: Bool
    var isPrivate: Bool
    var charCount: Int
}

// MARK: - Diary Timeline Entry

struct DiaryTimelineEntry: TimelineEntry {
    var date: Date
    var notes: [WidgetDiaryItem]
    var totalWordCount: Int
    var isPlaceholder: Bool = false

    static var empty: DiaryTimelineEntry {
        DiaryTimelineEntry(date: Date(), notes: [], totalWordCount: 0, isPlaceholder: false)
    }

    static var placeholder: DiaryTimelineEntry {
        DiaryTimelineEntry(
            date: Date(),
            notes: [
                WidgetDiaryItem(
                    id: UUID(),
                    text: "思考了新版本的桌面交互架构，轻量与心流至关重要。下午重点推进手记模块的视觉优化。",
                    timeText: "14:30",
                    isPinned: true,
                    isPrivate: false,
                    charCount: 42
                ),
                WidgetDiaryItem(
                    id: UUID(),
                    text: "晨间阅读笔记：保持代码的清晰与纯粹，没有变化需求就不抽象。",
                    timeText: "09:15",
                    isPinned: false,
                    isPrivate: false,
                    charCount: 30
                )
            ],
            totalWordCount: 72,
            isPlaceholder: true
        )
    }
}

// MARK: - Diary Timeline Provider

struct DiaryTimelineProvider: TimelineProvider {
    typealias Entry = DiaryTimelineEntry

    func placeholder(in context: Context) -> DiaryTimelineEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (DiaryTimelineEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            completion(fetchDiaryEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DiaryTimelineEntry>) -> Void) {
        let entry = fetchDiaryEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())
            ?? Date().addingTimeInterval(1800)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func fetchDiaryEntry() -> DiaryTimelineEntry {
        guard let container = WidgetPersistence.makeContainer() else {
            return .empty
        }

        let context = ModelContext(container)
        let todayKey = WidgetDateHelper.todayDayKey()
        let descriptor = FetchDescriptor<DiaryEntry>(
            predicate: #Predicate<DiaryEntry> { $0.deletedAt == nil && $0.dayKey == todayKey },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        let allNotes = (try? context.fetch(descriptor)) ?? []

        // 置顶排前面，其次创建时间倒序
        let sortedNotes = allNotes.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.createdAt > b.createdAt
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        var totalChars = 0
        let items: [WidgetDiaryItem] = sortedNotes.map { note in
            let isProtected = note.hasProtectedContent
            let displayText: String
            let count: Int

            if isProtected {
                displayText = WidgetL10n.privateDiaryLocked
                count = 0
            } else {
                displayText = note.text.trimmingCharacters(in: .whitespacesAndNewlines)
                count = displayText.count
                totalChars += count
            }

            return WidgetDiaryItem(
                id: note.id,
                text: displayText,
                timeText: formatter.string(from: note.createdAt),
                isPinned: note.isPinned,
                isPrivate: isProtected,
                charCount: count
            )
        }

        return DiaryTimelineEntry(
            date: Date(),
            notes: items,
            totalWordCount: totalChars,
            isPlaceholder: false
        )
    }
}

// MARK: - Diary Widget Definition

struct DiaryWidget: Widget {
    let kind: String = "AreaChainDiaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DiaryTimelineProvider()) { entry in
            DiaryWidgetView(entry: entry)
        }
        .configurationDisplayName(WidgetL10n.diaryWidgetDisplayName)
        .description(WidgetL10n.diaryWidgetDescription)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
