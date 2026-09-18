import SwiftUI

/// 实时卡片预览头部：所见即所得展示清洗后的待办内容、提取的属性，并支持联动试戴当前候选词。
struct LiveComposerPreviewHeader: View {
    var text: String
    var knownTags: [String] = []
    var activeCandidate: SyntaxCandidate? = nil
    var onClose: () -> Void

    @Environment(\.locale) private var locale

    private var parsed: ParsedCapture {
        NaturalLanguageParser.parseTaskCapture(text)
    }

    private var displayTitle: String {
        guard parsed.hasContentTitle else { return "" }
        let title = parsed.cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty, !isSyntaxPrefixOnly(title) { return title }
        return ""
    }

    private func isSyntaxPrefixOnly(_ str: String) -> Bool {
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "#" || trimmed == "＃" || trimmed == "@" || trimmed == "＠" || trimmed == "!" || trimmed == "！"
    }

    private var previewTags: [String] {
        var list = parsed.tagNames
        if let candidate = activeCandidate, candidate.kind == .tag {
            let candidateTag = candidate.title.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            if !candidateTag.isEmpty && candidateTag != "..." && !list.contains(where: { TagSyntax.normalizedName($0) == TagSyntax.normalizedName(candidateTag) }) {
                list.append(candidateTag)
            }
        }
        return list
    }

    private var displayTime: String? {
        if let candidate = activeCandidate, candidate.kind == .time {
            return candidate.title.trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        }
        return parsed.timeLabel
    }

    private var displayPriority: (label: String, color: Color)? {
        if let candidate = activeCandidate, candidate.kind == .priority {
            return (candidate.title, priorityColor(candidate.title))
        }
        if let label = parsed.priorityLabel {
            return (label, priorityColor(label))
        }
        return nil
    }

    private func priorityColor(_ title: String) -> Color {
        switch title {
        case "!p1", "quadrant.iu": return DaybookTheme.destructive
        case "!p2", "quadrant.i": return Color.orange
        case "!p3", "quadrant.u": return Color.blue
        default: return DaybookTheme.muted
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Circle()
                .strokeBorder(DaybookTheme.rule.opacity(0.8), style: StrokeStyle(lineWidth: 1.2, dash: [2.5, 2]))
                .frame(width: 13, height: 13)
                .foregroundStyle(DaybookTheme.muted)

            Text(displayTitle.isEmpty ? L10n.string("capture.preview.untitled", locale: locale) : displayTitle)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(displayTitle.isEmpty ? DaybookTheme.muted.opacity(0.6) : DaybookTheme.ink)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                ForEach(previewTags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.system(size: 9.5, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(DaybookTheme.stamp.opacity(0.12)))
                        .foregroundStyle(DaybookTheme.stamp)
                }

                if let time = displayTime {
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.system(size: 8))
                        Text(time)
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    }
                    .padding(.horizontal, 4.5)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(DaybookTheme.ink.opacity(0.06)))
                    .foregroundStyle(DaybookTheme.ink)
                }

                if let priority = displayPriority {
                    HStack(spacing: 2) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 8, weight: .bold))
                        Text(LocalizedStringKey(priority.label))
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .padding(.horizontal, 4.5)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(priority.color.opacity(0.15)))
                    .foregroundStyle(priority.color)
                }
            }
            .fixedSize(horizontal: true, vertical: false)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(DaybookTheme.muted.opacity(0.8))
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("common.close")
            .accessibilityLabel("common.close")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(height: 32)
        .background(DaybookTheme.ink.opacity(0.03))
        .contentShape(Rectangle())
    }
}
