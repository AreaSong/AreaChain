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
    var activePageIndex: Int = 0
    var isDebug: Bool = false
    var isPlaceholder: Bool = false

    static var empty: DiaryTimelineEntry {
        DiaryTimelineEntry(date: Date(), notes: [], totalWordCount: 0, activePageIndex: 0, isDebug: false, isPlaceholder: false)
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
            activePageIndex: 0,
            isDebug: false,
            isPlaceholder: true
        )
    }
}

// MARK: - Diary Timeline Provider

struct DiaryTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = DiaryTimelineEntry
    typealias Intent = DiaryConfigurationIntent

    func placeholder(in context: Context) -> DiaryTimelineEntry {
        DiaryTimelineEntry.placeholder
    }

    func snapshot(for configuration: DiaryConfigurationIntent, in context: Context) async -> DiaryTimelineEntry {
        let isDebug = configuration.environment == .debug
        if context.isPreview {
            var entry = DiaryTimelineEntry.placeholder
            entry.isDebug = isDebug
            return entry
        }
        return fetchDiaryEntry(isDebug: isDebug)
    }

    func timeline(for configuration: DiaryConfigurationIntent, in context: Context) async -> Timeline<DiaryTimelineEntry> {
        let isDebug = configuration.environment == .debug
        let entry = fetchDiaryEntry(isDebug: isDebug)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())
            ?? Date().addingTimeInterval(1800)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func fetchDiaryEntry(isDebug: Bool) -> DiaryTimelineEntry {
        guard let container = WidgetPersistence.makeContainer(isDebug: isDebug) else {
            var entry = DiaryTimelineEntry.empty
            entry.isDebug = isDebug
            return entry
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

        let defaults = UserDefaults(suiteName: "group.com.areachain.app")
        let pageKey = isDebug ? "widget_diary_page_index_debug" : "widget_diary_page_index"
        let rawIndex = defaults?.integer(forKey: pageKey) ?? 0
        let validIndex = items.isEmpty ? 0 : max(0, min(rawIndex, items.count - 1))

        return DiaryTimelineEntry(
            date: Date(),
            notes: items,
            totalWordCount: totalChars,
            activePageIndex: validIndex,
            isDebug: isDebug,
            isPlaceholder: false
        )
    }
}

// MARK: - Diary Widget Definition

struct DiaryWidget: Widget {
    let kind: String = "AreaChainDiaryWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: DiaryConfigurationIntent.self,
            provider: DiaryTimelineProvider()
        ) { entry in
            DiaryWidgetView(entry: entry)
        }
        .configurationDisplayName(WidgetL10n.diaryWidgetDisplayName)
        .description(WidgetL10n.diaryWidgetDescription)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

