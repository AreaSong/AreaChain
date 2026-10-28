import AppKit
import SwiftUI

/// 实时卡片预览头部：所见即所得展示清洗后的待办内容、提取的属性，并支持多标签溢出折叠与右侧浮层展开。
struct LiveComposerPreviewHeader: View {
    var text: String
    var knownTags: [String] = []
    var activeCandidate: SyntaxCandidate? = nil
    var showsSuggestions: Bool = false
    var onClose: () -> Void
    /// 展示宿主可接管复制反馈；既有消费者继续使用系统剪贴板。
    var onCopy: ((String) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @State private var isRowHovered = false
    @State private var isTitleHovered = false
    @State private var isNoteHovered = false
    @State private var isTitleBubbleHovered = false
    @State private var isNoteBubbleHovered = false
    @State private var hasCopied = false
    @State private var hasNoteCopied = false
    @State private var growsUpward = false
    @State private var bubbleShiftX: CGFloat = 0

    init(
        text: String,
        knownTags: [String] = [],
        activeCandidate: SyntaxCandidate? = nil,
        showsSuggestions: Bool = false,
        onClose: @escaping () -> Void,
        onCopy: ((String) -> Void)? = nil
    ) {
        self.text = text
        self.knownTags = knownTags
        self.activeCandidate = activeCandidate
        self.showsSuggestions = showsSuggestions
        self.onClose = onClose
        self.onCopy = onCopy
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

    private var prioritySlot: QuadrantSlot? {
        guard parsed.hasPriorityToken else { return nil }
        let slot = QuadrantSlot.of(important: parsed.isImportant, urgent: parsed.isUrgent)
        return slot == .rest ? nil : slot
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
            hasPriority: prioritySlot != nil,
            hasNotes: !parsed.notes.isEmpty
        )
    }

    /// 单行主卡片（固定 36pt 高度，布局 100% 镜像 TaskRow 待办项）
    private var mainRow: some View {
        let ringStroke = DaybookPalette.text.primary.opacity(0.24) // token-exempt: 与 ModernCheckbox 未完成圆环一致
        return HStack(alignment: .center, spacing: 8) {
            Circle()
                .strokeBorder(ringStroke, lineWidth: DaybookMetrics.Completion.task.border)
                .frame(width: DaybookMetrics.Completion.task.circle, height: DaybookMetrics.Completion.task.circle)
                .frame(width: DaybookMetrics.Completion.task.hit, height: DaybookMetrics.Completion.task.hit)

            HStack(alignment: .center, spacing: 5) {
                if !displayTitle.isEmpty {
                    titleView
                }
                if !parsed.notes.isEmpty {
                    noteIndicator
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailingAttributesCluster

            closeAccessibilityAnchor
                .padding(.leading, -10)
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background {
            Color.clear
                .daybookSurface(.row, isHovered: isRowHovered, isSelected: false)
                .daybookSurface(floating: .smallBackground, isPresented: !showsSuggestions)
        }
        .onHover { hovering in
            withAnimation(DaybookMotion.interactive(reduceMotion)) {
                isRowHovered = hovering
            }
        }
        .task(id: hasCopied) {
            guard hasCopied else { return }
            try? await Task.sleep(for: .milliseconds(1200))
            if !Task.isCancelled {
                withAnimation(DaybookMotion.interactive(reduceMotion)) { hasCopied = false }
            }
        }
        .task(id: hasNoteCopied) {
            guard hasNoteCopied else { return }
            try? await Task.sleep(for: .milliseconds(1200))
            if !Task.isCancelled {
                withAnimation(DaybookMotion.interactive(reduceMotion)) { hasNoteCopied = false }
            }
        }
    }

    private var closeAccessibilityAnchor: some View {
        Button(action: onClose) {
            Text("")
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain) // control: 无视觉占位的关闭锚点，保持与正式 TaskRow 一致的右侧视觉
        .frame(width: 18, height: 18)
        .help("common.close")
        .accessibilityLabel("common.close")
    }

    private var trailingAttributesCluster: some View {
        HStack(spacing: 4) {
            if let prioritySlot, prioritySlot != .rest {
                QuadrantBadge(slot: prioritySlot, isHighlighted: isRowHovered)
            }

            tagsBadgeCluster

            if let time = displayTime {
                DaybookChip(tint: DaybookPalette.accent.base, isSelected: isRowHovered) {
                    Text(time)
                }
                .help(time)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .opacity(isRowHovered ? 1.0 : 0.65)
        .animation(DaybookMotion.interactive(reduceMotion), value: isRowHovered)
    }

    @ViewBuilder
    private var tagsBadgeCluster: some View {
        if !previewTags.isEmpty {
            let displayTags = Array(previewTags.prefix(1))
            let overflow = previewTags.count - displayTags.count
            HStack(spacing: 2.5) {
                ForEach(displayTags, id: \.self) { tag in
                    DiaryTagPill(name: tag)
                }
                if overflow > 0 {
                    Text("+\(overflow)")
                        .font(.system(size: 9, weight: .bold, design: .rounded)) // token-exempt: 标签溢出计数用圆体
                        .foregroundStyle(DaybookPalette.Syntax.tag)
                        .padding(.horizontal, 3.5)
                        .frame(height: 18)
                        .background(
                            RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                                .fill(DaybookPalette.Syntax.tagBadgeFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                                .stroke(DaybookPalette.Syntax.tagStroke, lineWidth: 0.6)
                        )
                        .help(L10n.format("syntax.preview.tagCount", locale: locale, previewTags.count))
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    /// 紧跟标题的纯图标备注指示器（样式 100% 对齐 TaskRow noteIndicator）
    private var noteIndicator: some View {
        let iconColor = hasNoteCopied
            ? DaybookPalette.accent.base
            : (isNoteHovered ? DaybookPalette.accent.base : DaybookPalette.text.secondary.opacity(0.65)) // token-exempt: 65% 次要色没有对应令牌
        let fillColor = hasNoteCopied
            ? DaybookPalette.accent.base.opacity(0.16) // token-exempt: 16% 没有对应令牌
            : (isNoteHovered ? DaybookPalette.accent.fill : DaybookPalette.text.primary.opacity(0.04)) // token-exempt: 4% 墨色没有对应令牌
        return Image(systemName: "text.alignleft")
            .font(DaybookType.micro.weight(.medium))
            .foregroundStyle(iconColor)
            .padding(.horizontal, 3.5)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.xxs, style: .continuous)
                    .fill(fillColor)
            )
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { updateBubblePlacement(proxy) }
                        .onChange(of: proxy.frame(in: .global).minX) { _, _ in updateBubblePlacement(proxy) }
                        .onChange(of: proxy.frame(in: .global).minY) { _, _ in updateBubblePlacement(proxy) }
                }
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    isNoteHovered = hovering
                }
            }
            .onTapGesture {
                copyPreview(parsed.notes, isNote: true)
            }
            .overlay(alignment: growsUpward ? .bottomLeading : .topLeading) {
                noteBubbleOverlay
            }
    }

    @ViewBuilder
    private var noteBubbleOverlay: some View {
        if shouldShowNoteBubble {
            let arrowPadding = max(8, min(194, 8 - bubbleShiftX))
            let transformAnchor = UnitPoint(
                x: max(0.06, min(0.94, (arrowPadding + 3.5) / 210.0)),
                y: growsUpward ? 1.0 : 0.0
            )
            RowNoteBubble(
                note: parsed.notes,
                growsUpward: growsUpward,
                bubbleShiftX: bubbleShiftX,
                isExternallyCopied: hasNoteCopied,
                onCopy: { copyPreview(parsed.notes, isNote: true) },
                onHover: { isNoteBubbleHovered = $0 }
            )
            .offset(x: -2.5 + bubbleShiftX, y: growsUpward ? -18 : 16)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: transformAnchor)),
                removal: .opacity
            ))
        }
    }

    private var shouldShowNoteBubble: Bool {
        (isNoteHovered || isNoteBubbleHovered) && !showsSuggestions && !parsed.notes.isEmpty && !isTitleHovered && !isTitleBubbleHovered
    }

    private func updateBubblePlacement(_ proxy: GeometryProxy) {
        let frame = proxy.frame(in: .global)
        let placement = RowBubblePlacement.calculate(
            globalPoint: CGPoint(x: frame.minX, y: frame.minY),
            wideHost: false
        )
        growsUpward = placement.growsUpward
        bubbleShiftX = placement.bubbleShiftX
    }

    private func copyPreview(_ text: String, isNote: Bool = false) {
        guard !text.isEmpty else { return }
        if let onCopy {
            onCopy(text)
        } else {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }
        DaybookStatusNoticeCenter.shared.show(.copied)
        withAnimation(DaybookMotion.interactive(reduceMotion)) {
            if isNote {
                hasNoteCopied = true
            } else {
                hasCopied = true
            }
        }
    }

    /// 浮动详细标签面板（大字号 11pt，查详细专用，输入时自动避让）
    private var tagDetailBubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            tagDetailHeader
            DaybookDivider(opacity: 0.3)
            tagScrollList
        }
        .padding(7)
        .frame(width: 140)
        .daybookSurface(floating: .tagDetail)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)),
            removal: .opacity
        ))
    }

    private var tagDetailHeader: some View {
        HStack {
            Text("syntax.preview.allTags")
                .font(DaybookType.badge.weight(.semibold))
                .foregroundStyle(DaybookPalette.text.secondary)
            Spacer()
            DaybookCount(count: previewTags.count)
        }
        .padding(.horizontal, 2)
        .padding(.top, 1)
    }

    private var tagScrollList: some View {
        ScrollView(.vertical, showsIndicators: previewTags.count > 5) {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(previewTags, id: \.self) { tag in
                    tagRowItem(tag)
                }
            }
        }
        .daybookScroll()
        .frame(maxHeight: min(120, CGFloat(previewTags.count) * 26 + 6))
    }

    private func tagRowItem(_ tag: String) -> some View {
        HStack(spacing: 3) {
            Text("#\(tag)")
                .font(DaybookType.caption.weight(.medium))
                .foregroundStyle(DaybookPalette.Syntax.tag)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                .fill(DaybookPalette.Syntax.tagSubtleFill)
        )
    }

    private var isTitleTruncated: Bool {
        RowTitleTruncation.isTruncated(displayTitle)
    }

    private var titleView: some View {
        Text(displayTitle)
            .font(DaybookType.body)
            .foregroundStyle(hasCopied ? DaybookPalette.accent.base : DaybookPalette.text.primary)
            .lineLimit(1)
            .truncationMode(AppPreferences.shared.contentTruncation.textTruncation)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .help(displayTitle)
            .onTapGesture {
                copyPreview(displayTitle, isNote: false)
            }
            .onHover { hovering in
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    isTitleHovered = hovering && isTitleTruncated
                }
            }
            .overlay(alignment: growsUpward ? .bottomLeading : .topLeading) {
                if (isTitleHovered || isTitleBubbleHovered) && !showsSuggestions && !isNoteHovered && !isNoteBubbleHovered {
                    RowTitleBubble(
                        title: displayTitle,
                        growsUpward: growsUpward,
                        isExternallyCopied: hasCopied,
                        onCopy: { copyPreview(displayTitle, isNote: false) },
                        onHover: { isTitleBubbleHovered = $0 }
                    )
                    .offset(y: growsUpward ? -6 : 22)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: growsUpward ? .bottomLeading : .topLeading)),
                        removal: .opacity
                    ))
                }
            }
    }

    // MARK: - 容量碰撞检测算法

    static func canFit(
        title: String,
        tags: [String],
        hasTime: Bool,
        hasPriority: Bool,
        hasNotes: Bool = false,
        cardWidth: CGFloat = DaybookMetrics.Window.popoverWidth - 24
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
