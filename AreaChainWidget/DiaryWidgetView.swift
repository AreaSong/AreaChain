import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Root View

struct DiaryWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: DiaryTimelineEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallDiaryView(entry: entry)
            case .systemLarge:
                LargeDiaryView(entry: entry)
            default:
                MediumDiaryView(entry: entry)
            }
        }
        .containerBackground(for: .widget) {
            WidgetDaybookTheme.paperBackground
        }
        .widgetURL(URL(string: "areachain://diary"))
    }
}

// MARK: - Safe Array Subscript Helper

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Small Diary View

struct SmallDiaryView: View {
    var entry: DiaryTimelineEntry

    var activeNote: WidgetDiaryItem? {
        entry.notes[safe: entry.activePageIndex] ?? entry.notes.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 页头
            HStack {
                Label(WidgetL10n.titleDiary, systemImage: "text.book.closed.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(WidgetDaybookTheme.inkText)
                    .lineLimit(1)
                Spacer()
                Link(destination: URL(string: "areachain://quick-diary")!) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(WidgetDaybookTheme.stampAccent)
                }
                .buttonStyle(.plain)
            }

            Rectangle()
                .fill(WidgetDaybookTheme.ruleLine)
                .frame(height: 1)

            if let note = activeNote {
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.text)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(WidgetDaybookTheme.inkText)
                        .lineLimit(4)
                        .lineSpacing(2)

                    Spacer(minLength: 0)

                    HStack {
                        if note.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(WidgetDaybookTheme.streakOrange)
                        }
                        Text(note.timeText)
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(WidgetDaybookTheme.mutedText)

                        Spacer()

                        if entry.notes.count > 1 {
                            HStack(spacing: 3) {
                                Button(intent: DiaryPageIntent(direction: "prev")) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(WidgetDaybookTheme.stampAccent)
                                }
                                .buttonStyle(.plain)

                                Text("\(entry.activePageIndex + 1)/\(entry.notes.count)")
                                    .font(.system(size: 8, weight: .medium, design: .rounded))
                                    .foregroundStyle(WidgetDaybookTheme.mutedText)

                                Button(intent: DiaryPageIntent(direction: "next")) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(WidgetDaybookTheme.stampAccent)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            Text(WidgetL10n.formatWordsCount(note.charCount))
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(WidgetDaybookTheme.stampAccent)
                        }
                    }
                }
            } else {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 18))
                        .foregroundStyle(WidgetDaybookTheme.stampAccent)
                    Text(WidgetL10n.emptyDiary)
                        .font(.system(size: 10))
                        .foregroundStyle(WidgetDaybookTheme.mutedText)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Medium Diary View

struct MediumDiaryView: View {
    var entry: DiaryTimelineEntry

    var activeNote: WidgetDiaryItem? {
        entry.notes[safe: entry.activePageIndex] ?? entry.notes.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 页头
            HStack(spacing: 6) {
                Label(WidgetL10n.titleDiary, systemImage: "text.book.closed.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(WidgetDaybookTheme.inkText)
                    .lineLimit(1)

                Spacer()

                Link(destination: URL(string: "areachain://quick-diary")!) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WidgetDaybookTheme.stampAccent)
                }
                .buttonStyle(.plain)

                if entry.totalWordCount > 0 {
                    Text(WidgetL10n.formatWordsCount(entry.totalWordCount))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(WidgetDaybookTheme.capsuleBackground)
                        .foregroundStyle(WidgetDaybookTheme.stampAccent)
                        .clipShape(Capsule())
                }

                Text(Date(), style: .date)
                    .font(.system(size: 11))
                    .foregroundStyle(WidgetDaybookTheme.mutedText)
                    .lineLimit(1)
            }

            Rectangle()
                .fill(WidgetDaybookTheme.ruleLine)
                .frame(height: 1)

            // 正文区域
            if entry.notes.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 20))
                        .foregroundStyle(WidgetDaybookTheme.stampAccent)
                    Text(WidgetL10n.emptyDiary)
                        .font(.system(size: 12))
                        .foregroundStyle(WidgetDaybookTheme.mutedText)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if let note = activeNote {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        if note.isPinned {
                            Label("置顶", systemImage: "pin.fill")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(WidgetDaybookTheme.streakOrange)
                        }
                        Text(note.timeText)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(WidgetDaybookTheme.mutedText)

                        Spacer()

                        if entry.notes.count > 1 {
                            HStack(spacing: 4) {
                                Button(intent: DiaryPageIntent(direction: "prev")) {
                                    Image(systemName: "chevron.left.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(WidgetDaybookTheme.stampAccent)
                                }
                                .buttonStyle(.plain)

                                Text("\(entry.activePageIndex + 1)/\(entry.notes.count)")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(WidgetDaybookTheme.mutedText)

                                Button(intent: DiaryPageIntent(direction: "next")) {
                                    Image(systemName: "chevron.right.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(WidgetDaybookTheme.stampAccent)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Text(note.text)
                        .font(.system(size: 12))
                        .foregroundStyle(WidgetDaybookTheme.inkText)
                        .lineLimit(4)
                        .lineSpacing(3)

                    Spacer(minLength: 0)
                }
            }
        }
    }
}

// MARK: - Large Diary View

struct LargeDiaryView: View {
    var entry: DiaryTimelineEntry

    var activeNote: WidgetDiaryItem? {
        entry.notes[safe: entry.activePageIndex] ?? entry.notes.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 页头
            HStack(spacing: 8) {
                Label(WidgetL10n.titleDiary, systemImage: "text.book.closed.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(WidgetDaybookTheme.inkText)
                    .lineLimit(1)

                Spacer()

                Link(destination: URL(string: "areachain://quick-diary")!) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(WidgetDaybookTheme.stampAccent)
                }
                .buttonStyle(.plain)

                if entry.totalWordCount > 0 {
                    Text(WidgetL10n.formatWordsCount(entry.totalWordCount))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(WidgetDaybookTheme.stampAccent)
                }

                Text(Date(), style: .date)
                    .font(.system(size: 11))
                    .foregroundStyle(WidgetDaybookTheme.mutedText)
            }

            Rectangle()
                .fill(WidgetDaybookTheme.ruleLine)
                .frame(height: 1)

            // 正文或多篇列表
            if entry.notes.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 24))
                        .foregroundStyle(WidgetDaybookTheme.stampAccent)
                    Text(WidgetL10n.emptyDiary)
                        .font(.system(size: 12))
                        .foregroundStyle(WidgetDaybookTheme.mutedText)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(entry.notes.prefix(3).enumerated()), id: \.element.id) { index, note in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                if note.isPinned {
                                    Image(systemName: "pin.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(WidgetDaybookTheme.streakOrange)
                                }
                                Text(note.timeText)
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(WidgetDaybookTheme.mutedText)
                                Spacer()
                                Text(WidgetL10n.formatWordsCount(note.charCount))
                                    .font(.system(size: 9, design: .rounded))
                                    .foregroundStyle(WidgetDaybookTheme.mutedText.opacity(0.8))
                            }

                            Text(note.text)
                                .font(.system(size: 12))
                                .foregroundStyle(WidgetDaybookTheme.inkText)
                                .lineLimit(2)
                                .lineSpacing(2)
                        }

                        if index < min(entry.notes.count, 3) - 1 {
                            Rectangle()
                                .fill(WidgetDaybookTheme.ruleLine.opacity(0.6))
                                .frame(height: 0.5)
                        }
                    }
                }
                Spacer(minLength: 0)
            }

            Rectangle()
                .fill(WidgetDaybookTheme.ruleLine.opacity(0.7))
                .frame(height: 0.5)

            // 底栏：一键微状态 / 心情打卡区
            HStack(spacing: 6) {
                Text("速记:")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(WidgetDaybookTheme.mutedText)

                MoodPillButton(title: "🌿 灵感")
                MoodPillButton(title: "☕️ 摸鱼")
                MoodPillButton(title: "💪 专注")
                MoodPillButton(title: "✨ 感恩")

                Spacer()

                if entry.notes.count > 1 {
                    HStack(spacing: 3) {
                        Button(intent: DiaryPageIntent(direction: "prev")) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(WidgetDaybookTheme.stampAccent)
                        }
                        .buttonStyle(.plain)

                        Text("\(entry.activePageIndex + 1)/\(entry.notes.count)")
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(WidgetDaybookTheme.mutedText)

                        Button(intent: DiaryPageIntent(direction: "next")) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(WidgetDaybookTheme.stampAccent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Mood Pill Button

private struct MoodPillButton: View {
    let title: String

    var body: some View {
        Button(intent: DiaryQuickMoodIntent(moodText: title)) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(WidgetDaybookTheme.capsuleBackground)
                .foregroundStyle(WidgetDaybookTheme.inkText)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
