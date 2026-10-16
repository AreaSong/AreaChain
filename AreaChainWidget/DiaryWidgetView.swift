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

// MARK: - Small Diary View

struct SmallDiaryView: View {
    var entry: DiaryTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(WidgetL10n.titleDiary, systemImage: "text.book.closed.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(WidgetDaybookTheme.inkText)
                    .lineLimit(1)
                Spacer()
                Text(Date(), style: .date)
                    .font(.system(size: 10))
                    .foregroundStyle(WidgetDaybookTheme.mutedText)
            }

            Rectangle()
                .fill(WidgetDaybookTheme.ruleLine)
                .frame(height: 1)

            if let note = entry.notes.first {
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
                        Text(WidgetL10n.formatWordsCount(note.charCount))
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(WidgetDaybookTheme.stampAccent)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 页头
            HStack(spacing: 6) {
                Label(WidgetL10n.titleDiary, systemImage: "text.book.closed.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(WidgetDaybookTheme.inkText)
                    .lineLimit(1)

                Spacer()

                Link(destination: URL(string: "areachain://diary")!) {
                    Image(systemName: "square.and.pencil")
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
            } else if entry.notes.count == 1, let note = entry.notes.first {
                VStack(alignment: .leading, spacing: 4) {
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
                    }

                    Text(note.text)
                        .font(.system(size: 12))
                        .foregroundStyle(WidgetDaybookTheme.inkText)
                        .lineLimit(3)
                        .lineSpacing(3)

                    Spacer(minLength: 0)
                }
            } else {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(entry.notes.prefix(2)) { note in
                        VStack(alignment: .leading, spacing: 3) {
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
                            }

                            Text(note.text)
                                .font(.system(size: 11))
                                .foregroundStyle(WidgetDaybookTheme.inkText)
                                .lineLimit(3)
                                .lineSpacing(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Large Diary View

struct LargeDiaryView: View {
    var entry: DiaryTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 页头
            HStack(spacing: 8) {
                Label(WidgetL10n.titleDiary, systemImage: "text.book.closed.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(WidgetDaybookTheme.inkText)
                    .lineLimit(1)

                Spacer()

                Link(destination: URL(string: "areachain://diary")!) {
                    Image(systemName: "square.and.pencil")
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
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                if note.isPinned {
                                    Image(systemName: "pin.fill")
                                        .font(.system(size: 10))
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
                                .lineLimit(3)
                                .lineSpacing(3)
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
        }
    }
}
