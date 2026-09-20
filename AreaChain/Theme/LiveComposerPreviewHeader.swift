import SwiftUI

/// 实时卡片预览头部：所见即所得展示清洗后的待办内容、提取的属性，并支持多标签溢出折叠与右侧浮层展开。
struct LiveComposerPreviewHeader: View {
    var text: String
    var knownTags: [String] = []
    var activeCandidate: SyntaxCandidate? = nil
    var showsSuggestions: Bool = false
    var onClose: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isTitleHovered = false
    @State private var isNoteHovered = false
    @State private var noteBubbleShiftX: CGFloat = 0

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

    private var previewTags: [String] {
        parsed.tagNames
    }

    private var displayTime: String? {
        parsed.timeLabel
    }

    private var displayPriority: (badge: String, tooltip: String, color: Color, fill: Color)? {
        guard let label = parsed.priorityLabel else { return nil }
        let badge: String
        switch label {
        case "quadrant.iu": badge = "P1"
        case "quadrant.i": badge = "P2"
        case "quadrant.u": badge = "P3"
        case "quadrant.rest": badge = "P4"
        default: badge = label
        }
        return (
            badge: badge,
            tooltip: label,
            color: DaybookTheme.Syntax.priorityColor(for: label),
            fill: DaybookTheme.Syntax.priorityFill(for: label)
        )
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            mainRow
            if !canFitAllTagsInline && previewTags.count > 1 && !showsSuggestions && !isTitleHovered {
                tagDetailBubble
                    .padding(.trailing, 4)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)),
                        removal: .opacity
                    ))
            }
        }
    }

    /// 计算单行内是否能平铺完整放下所有标签（无需折叠与浮窗）
    private var canFitAllTagsInline: Bool {
        Self.canFit(
            title: displayTitle,
            tags: previewTags,
            hasTime: displayTime != nil,
            hasPriority: displayPriority != nil,
            hasNotes: !parsed.notes.isEmpty
        )
    }

    /// 单行主卡片（固定 36pt 高度，布局 100% 镜像 TaskRow 待办项）
    private var mainRow: some View {
        HStack(alignment: .center, spacing: 6) {
            Circle()
                .strokeBorder(DaybookTheme.rule.opacity(0.8), style: StrokeStyle(lineWidth: 1.2, dash: [2.5, 2]))
                .frame(width: 14, height: 14)
                .foregroundStyle(DaybookTheme.muted)

            HStack(alignment: .center, spacing: 5) {
                if !displayTitle.isEmpty {
                    titleView
                }
                if !parsed.notes.isEmpty {
                    noteIndicator
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 右侧属性集群（严格镜像 TaskRow: 优先级 -> 标签 -> 时间）
            HStack(spacing: 5) {
                // 1. 优先级徽标（最前）
                if let priority = displayPriority {
                    HStack(spacing: 2.5) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 9.5, weight: .bold))
                        Text(priority.badge)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(priority.fill))
                    .foregroundStyle(priority.color)
                    .help(LocalizedStringKey(priority.tooltip))
                }

                // 2. 标签集群
                if canFitAllTagsInline {
                    ForEach(previewTags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                            .padding(.horizontal, 5.5)
                            .padding(.vertical, 2.5)
                            .background(Capsule().fill(DaybookTheme.Syntax.tagFill))
                            .foregroundStyle(DaybookTheme.Syntax.tag)
                            .help("#\(tag)")
                    }
                } else if previewTags.count == 1, let singleTag = previewTags.first {
                    Text("#\(singleTag)")
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 96, alignment: .leading)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(DaybookTheme.Syntax.tagFill))
                        .foregroundStyle(DaybookTheme.Syntax.tag)
                        .help("#\(singleTag)")
                } else if previewTags.count > 1 {
                    HStack(spacing: 2.5) {
                        Image(systemName: "number")
                            .font(.system(size: 8.5, weight: .bold))
                        Text("\(previewTags.count)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(DaybookTheme.Syntax.tagBadgeFill))
                    .foregroundStyle(DaybookTheme.Syntax.tag)
                    .help("共 \(previewTags.count) 个标签")
                }

                // 3. 提醒时间徽标（最后）
                if let time = displayTime {
                    HStack(spacing: 2.5) {
                        Image(systemName: "clock")
                            .font(.system(size: 9.5))
                        Text(time)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(DaybookTheme.Syntax.timeFill))
                    .foregroundStyle(DaybookTheme.Syntax.time)
                    .help(time)
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

    /// 紧跟标题的纯图标备注指示器（样式 100% 对齐 TaskRow noteIndicator）
    private var noteIndicator: some View {
        Image(systemName: "text.alignleft")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(isNoteHovered ? DaybookTheme.stamp : DaybookTheme.muted.opacity(0.75))
            .padding(.horizontal, 3.5)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(isNoteHovered ? DaybookTheme.stamp.opacity(0.12) : DaybookTheme.ink.opacity(0.04))
            )
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            updateNoteBubblePlacement(proxy)
                        }
                        .onChange(of: proxy.frame(in: .global).minX) { _, _ in
                            updateNoteBubblePlacement(proxy)
                        }
                }
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    isNoteHovered = hovering
                }
            }
            .overlay(alignment: .topLeading) {
                if isNoteHovered && !showsSuggestions && !parsed.notes.isEmpty {
                    let arrowPadding = max(8, min(186, 8 - noteBubbleShiftX))
                    let transformAnchor = UnitPoint(
                        x: max(0.06, min(0.94, (arrowPadding + 3.5) / 210.0)),
                        y: 0.0
                    )
                    noteFloatingBubble(bubbleShiftX: noteBubbleShiftX)
                        .offset(x: -8 + noteBubbleShiftX, y: 20)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: transformAnchor)),
                            removal: .opacity
                        ))
                }
            }
    }

    private func updateNoteBubblePlacement(_ proxy: GeometryProxy) {
        let globalX = proxy.frame(in: .global).minX
        let safeMaxX: CGFloat = 356
        let safeMinX: CGFloat = 12
        let bubbleRight = globalX + 202
        if bubbleRight > safeMaxX {
            let overflow = bubbleRight - safeMaxX
            let maxShift = max(0, (globalX - 8) - safeMinX)
            noteBubbleShiftX = -min(overflow, maxShift)
        } else {
            noteBubbleShiftX = 0
        }
    }

    private func noteFloatingBubble(bubbleShiftX: CGFloat) -> some View {
        let arrowPadding = max(8, min(186, 8 - bubbleShiftX))
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer().frame(width: arrowPadding)
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(DaybookTheme.paper)
                    .offset(y: 1)
                Spacer()
            }
            .frame(height: 5)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(DaybookTheme.stamp)
                    Text(L10n.string("drawer.notes.title", locale: locale))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DaybookTheme.muted)
                    Spacer(minLength: 0)
                }

                Text(parsed.notes)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(DaybookTheme.ink)
                    .lineSpacing(2.5)
                    .lineLimit(8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(width: 210, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(DaybookTheme.paper)
                    .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(DaybookTheme.rule.opacity(0.8), lineWidth: 0.8)
            )
        }
        .frame(width: 210, alignment: .leading)
        .fixedSize()
        .allowsHitTesting(false)
        .zIndex(999)
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
                                .foregroundStyle(DaybookTheme.Syntax.tag)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(DaybookTheme.Syntax.tagSubtleFill)
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

    private var isTitleTruncated: Bool {
        displayTitle.count > 12
    }

    private var titleView: some View {
        Text(displayTitle)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(DaybookTheme.ink)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .help(displayTitle)
            .onHover { hovering in
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    isTitleHovered = hovering && isTitleTruncated
                }
            }
            .overlay(alignment: .topLeading) {
                if isTitleHovered && !showsSuggestions && !isNoteHovered {
                    titleTooltipBubble
                        .offset(y: 28)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .topLeading)),
                            removal: .opacity
                        ))
                }
            }
    }

    private var titleTooltipBubble: some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 9.5))
                .foregroundStyle(DaybookTheme.muted)
                .padding(.top, 2)

            Text(displayTitle)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(DaybookTheme.ink)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5.5)
        .frame(maxWidth: 260, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(DaybookTheme.paper)
                .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(DaybookTheme.rule.opacity(0.8), lineWidth: 0.8)
        )
        .zIndex(999)
    }

    // MARK: - 容量碰撞检测算法

    static func canFit(
        title: String,
        tags: [String],
        hasTime: Bool,
        hasPriority: Bool,
        hasNotes: Bool = false,
        cardWidth: CGFloat = DaybookTheme.popoverWidth - 24
    ) -> Bool {
        guard !tags.isEmpty else { return true }
        let horizontalPadding: CGFloat = 20
        let circleAndGap: CGFloat = 20
        let closeButtonAndGap: CGFloat = 24
        let timeWidth: CGFloat = hasTime ? 48 : 0
        let priorityWidth: CGFloat = hasPriority ? 38 : 0
        let notesWidth: CGFloat = hasNotes ? 20 : 0

        let availableForContent = cardWidth - horizontalPadding - circleAndGap - closeButtonAndGap - timeWidth - priorityWidth - notesWidth

        let titleWidth = estimatedWidth(for: title, fontSize: 13)
        let tagsWidth = tags.reduce(0) { sum, tag in
            sum + estimatedWidth(for: "#" + tag, fontSize: 11) + 11 + 5
        }

        return (titleWidth + tagsWidth) <= availableForContent
    }

    static func estimatedWidth(for str: String, fontSize: CGFloat) -> CGFloat {
        guard !str.isEmpty else { return 0 }
        var w: CGFloat = 0
        for ch in str {
            if ch.isASCII {
                switch ch {
                case "1", "l", "i", "I", "!", "|", ":", ";", " ", ".", "'", "`":
                    w += fontSize * 0.32
                case "j", "r", "t", "f":
                    w += fontSize * 0.42
                case "w", "W", "M", "m", "@", "%", "#":
                    w += fontSize * 0.68
                default:
                    w += fontSize * 0.52
                }
            } else {
                w += fontSize * 1.0
            }
        }
        return w
    }
}
