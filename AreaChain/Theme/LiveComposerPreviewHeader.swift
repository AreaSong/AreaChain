import SwiftUI

/// 实时卡片预览头部：所见即所得展示清洗后的待办内容、提取的属性，并支持多标签溢出折叠与右侧浮层展开。
struct LiveComposerPreviewHeader: View {
    var text: String
    var knownTags: [String] = []
    var activeCandidate: SyntaxCandidate? = nil
    var showsSuggestions: Bool = false
    var onClose: () -> Void

    @Environment(\.locale) private var locale

    init(
        text: String,
        knownTags: [String] = [],
        activeCandidate: SyntaxCandidate? = nil,
        showsSuggestions: Bool = false,
        onClose: @escaping () -> Void
    ) {
        self.text = text
        self.knownTags = knownTags
        self.activeCandidate = activeCandidate
        self.showsSuggestions = showsSuggestions
        self.onClose = onClose
    }

    private var parsed: ParsedCapture {
        NaturalLanguageParser.parseTaskCapture(text)
    }

    private var displayTitle: String {
        let title = parsed.cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty, !isSyntaxPrefixOnly(title) { return title }
        return ""
    }

    private func isSyntaxPrefixOnly(_ str: String) -> Bool {
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "#" || trimmed == "＃" || trimmed == "@" || trimmed == "＠" || trimmed == "!" || trimmed == "！"
    }

    private var formattedTitle: String {
        let title = displayTitle
        guard title.count > 16 else { return title }
        let head = title.prefix(9)
        let tail = title.suffix(6)
        return "\(head)...\(tail)"
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
        VStack(alignment: .trailing, spacing: 4) {
            mainRow
            if previewTags.count > 1 && !showsSuggestions {
                tagDetailBubble
                    .padding(.trailing, 4)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)),
                        removal: .opacity
                    ))
            }
        }
    }

    /// 单行主卡片（固定 36pt 高度，大字号 13pt/11pt）
    private var mainRow: some View {
        HStack(alignment: .center, spacing: 6) {
            Circle()
                .strokeBorder(DaybookTheme.rule.opacity(0.8), style: StrokeStyle(lineWidth: 1.2, dash: [2.5, 2]))
                .frame(width: 14, height: 14)
                .foregroundStyle(DaybookTheme.muted)

            if !displayTitle.isEmpty {
                Text(formattedTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DaybookTheme.ink)
                    .lineLimit(1)
                    .help(displayTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer(minLength: 4)
            }

            // 右侧属性集群（首个标签 + 标签数量徽标、时间、优先级）
            HStack(spacing: 5) {
                if previewTags.count == 1, let singleTag = previewTags.first {
                    Text("#\(singleTag)")
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 96, alignment: .leading)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(DaybookTheme.stamp.opacity(0.12)))
                        .foregroundStyle(DaybookTheme.stamp)
                        .help("#\(singleTag)")
                } else if previewTags.count > 1, let firstTag = previewTags.first {
                    // 展示首个标签，一眼看清当前输入的标签内容
                    Text("#\(firstTag)")
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 86, alignment: .leading)
                        .padding(.horizontal, 5.5)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(DaybookTheme.stamp.opacity(0.12)))
                        .foregroundStyle(DaybookTheme.stamp)
                        .help("#\(firstTag)")

                    // 标签数量徽标（免点击，直观提示）
                    HStack(spacing: 2) {
                        Image(systemName: "number")
                            .font(.system(size: 8, weight: .bold))
                        Text("\(previewTags.count)")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(DaybookTheme.stamp.opacity(0.16)))
                    .foregroundStyle(DaybookTheme.stamp)
                    .help("共 \(previewTags.count) 个标签")
                }

                if let time = displayTime {
                    HStack(spacing: 2.5) {
                        Image(systemName: "clock")
                            .font(.system(size: 9.5))
                        Text(time)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(DaybookTheme.ink.opacity(0.06)))
                    .foregroundStyle(DaybookTheme.ink)
                    .help(time)
                }

                if let priority = displayPriority {
                    HStack(spacing: 2.5) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 9.5, weight: .bold))
                        Text(LocalizedStringKey(priority.label))
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(priority.color.opacity(0.15)))
                    .foregroundStyle(priority.color)
                    .help(priority.label)
                }
            }
            .fixedSize(horizontal: true, vertical: false)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DaybookTheme.muted.opacity(0.8))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("common.close")
            .accessibilityLabel("common.close")
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DaybookTheme.paper)
                .shadow(color: DaybookTheme.ink.opacity(0.10), radius: 6, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DaybookTheme.rule.opacity(0.7), lineWidth: 0.7)
        )
    }

    /// 浮动详细标签面板（大字号 11pt，查详细专用，输入时自动避让）
    private var tagDetailBubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("全部标签")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(DaybookTheme.muted)
                Spacer()
                Text("\(previewTags.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 4.5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(DaybookTheme.rule.opacity(0.4)))
                    .foregroundStyle(DaybookTheme.muted)
            }
            .padding(.horizontal, 2)
            .padding(.top, 1)

            Divider()
                .overlay(DaybookTheme.rule.opacity(0.3))

            ScrollView(.vertical, showsIndicators: previewTags.count > 5) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(previewTags, id: \.self) { tag in
                        HStack(spacing: 3) {
                            Text("#\(tag)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(DaybookTheme.stamp)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(DaybookTheme.stamp.opacity(0.08))
                        )
                    }
                }
            }
            .frame(maxHeight: min(120, CGFloat(previewTags.count) * 26 + 6))
        }
        .padding(7)
        .frame(width: 140)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DaybookTheme.paper)
                .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DaybookTheme.rule.opacity(0.6), lineWidth: 0.8)
        )
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)),
            removal: .opacity
        ))
    }
}
