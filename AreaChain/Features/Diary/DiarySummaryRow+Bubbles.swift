import AppKit
import SwiftUI

// MARK: - DiarySummaryRow 标题与备注气泡扩展

extension DiarySummaryRow {
    var shouldShowTitleBubble: Bool {
        !isSensitive && !isCommandPressed && (isTitleTextHovered || isTitleBubbleHovered) && RowTitleTruncation.isTruncated(contentPresentation.mainText)
    }

    var shouldShowNoteBubble: Bool {
        !isSensitive && !isCommandPressed && (isNoteHovered || isNoteBubbleHovered) && contentPresentation.note != nil
    }

    var canShowTagBubble: Bool {
        let tags = assignedTags
        let hasLongTag = (tags.first?.name.count ?? 0) > 4
        return tags.count > 1 || hasLongTag
    }

    var shouldShowTagBubble: Bool {
        !isSensitive && !isCommandPressed && isTagHovered && canShowTagBubble
    }

    @ViewBuilder
    var diaryTagChips: some View {
        let tags = assignedTags
        let displayTags = Array(tags.prefix(1))
        let overflow = tags.count - displayTags.count

        HStack(spacing: 3) {
            ForEach(displayTags) { tag in
                DiaryTagPill(name: tag.name, colorToken: tag.colorToken)
            }
            if overflow > 0 {
                diaryTagOverflowBadge(overflow: overflow, tags: tags)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(DaybookMotion.interactive(reduceMotion)) {
                isTagHovered = hovering
            }
        }
        .overlay(alignment: growsUpward ? .bottomLeading : .topLeading) {
            if shouldShowTagBubble {
                diaryTagDetailBubble(tags)
                    .offset(y: growsUpward ? -20 : 20)
            }
        }
    }

    private func diaryTagOverflowBadge(overflow: Int, tags: [TagItem]) -> some View {
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
            .help(L10n.format("row.tag.overflow.help", locale: locale, overflow, tags.dropFirst(1).map(\.name).joined(separator: ", ")))
    }

    private func diaryTagDetailBubble(_ tags: [TagItem]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("syntax.preview.allTags")
                    .font(DaybookType.badge.weight(.semibold))
                    .foregroundStyle(DaybookPalette.text.secondary)
                Spacer()
                DaybookCount(count: tags.count)
            }
            .padding(.horizontal, 2)
            DaybookDivider(opacity: 0.3)
            VStack(alignment: .leading, spacing: 3) {
                ForEach(tags) { tag in
                    let color = DiaryTagChrome.color(for: tag.name, token: tag.colorToken)
                    Text(tag.name)
                        .font(DaybookType.caption.weight(.medium))
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(
                            RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                                .fill(color.opacity(0.12)) // token-exempt: 标签色 12% 底不是印章色
                        )
                }
            }
        }
        .padding(7)
        .frame(width: 136)
        .daybookSurface(floating: .tagDetail)
        .allowsHitTesting(false)
        .zIndex(999)
    }

    @ViewBuilder
    func titleBubbleOverlay(for titleText: String) -> some View {
        if shouldShowTitleBubble {
            RowTitleBubble(
                title: titleText,
                growsUpward: growsUpward,
                isExternallyCopied: hasCopied,
                onCopy: { copyTitle(titleText) },
                onHover: { hovering in
                    isTitleBubbleHovered = hovering
                    if !hovering && !chrome.isTitlePointerInside {
                        chrome.handleTitleHover(false, reduceMotion: reduceMotion)
                    }
                }
            )
            .observingWindowHover(onInvalidate: resetTitleTracking)
            .offset(y: growsUpward ? -6 : 22)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: growsUpward ? .bottomLeading : .topLeading)),
                removal: .opacity
            ))
        }
    }

    func noteIndicator(fullText: String) -> some View {
        let iconColor = hasNoteCopied
            ? DaybookPalette.accent.base
            : (isNoteHovered ? DaybookPalette.accent.base : DaybookPalette.text.secondary.opacity(0.65)) // token-exempt: 65% 次要色没有对应令牌
        let fillColor = hasNoteCopied
            ? DaybookPalette.accent.base.opacity(0.16) // token-exempt: 16% 没有对应令牌
            : (isNoteHovered ? DaybookPalette.accent.fill : DaybookPalette.text.primary.opacity(0.04)) // token-exempt: 4% 没有对应令牌
        return Image(systemName: "text.alignleft")
            .font(DaybookType.micro.weight(.medium))
            .foregroundStyle(iconColor) // token-exempt: 65% 次要色没有对应令牌
            .frame(width: 11, height: 11)
            .padding(.horizontal, 3.5)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.xxs, style: .continuous)
                    .fill(fillColor) // token-exempt: 16% 与 4% 没有对应令牌
            )
            .background(notePlacementReader)
            .background {
                RowBubbleClickShield(
                    lifetime: noteIndicatorShield,
                    isRounded: false,
                    managesHover: true,
                    onHover: { chrome.handleNoteHover($0, reduceMotion: reduceMotion) },
                    onTap: { copyNote(fullText) }
                )
                .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .onHover { chrome.handleNoteHover($0, reduceMotion: reduceMotion) }
            .onTapGesture {
                copyNote(fullText)
            }
            .overlay(alignment: growsUpward ? .bottomLeading : .topLeading) {
                noteBubbleOverlay(fullText: fullText)
            }
    }

    @ViewBuilder
    private func noteBubbleOverlay(fullText: String) -> some View {
        if shouldShowNoteBubble {
            let arrowPadding = max(8, min(194, 8 - bubbleShiftX))
            let transformAnchor = UnitPoint(
                x: max(0.06, min(0.94, (arrowPadding + 3.5) / 210.0)),
                y: growsUpward ? 1.0 : 0.0
            )
            RowNoteBubble(
                note: fullText,
                growsUpward: growsUpward,
                bubbleShiftX: bubbleShiftX,
                headerTitleKey: "drawer.notes.title",
                isExternallyCopied: hasNoteCopied,
                onCopy: { copyNote(fullText) },
                onHover: { hovering in
                    isNoteBubbleHovered = hovering
                    if !hovering && !isNoteHovered {
                        withAnimation(DaybookMotion.interactive(reduceMotion)) {
                            isNoteHovered = false
                        }
                    }
                }
            )
            .offset(x: -2.5 + bubbleShiftX, y: growsUpward ? -18 : 16)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: transformAnchor)),
                removal: .opacity
            ))
        }
    }

    private var notePlacementReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { updateBubblePlacement(proxy) }
                .onChange(of: proxy.frame(in: .global).minY) { _, _ in updateBubblePlacement(proxy) }
                .onChange(of: proxy.frame(in: .global).minX) { _, _ in updateBubblePlacement(proxy) }
        }
    }

    func updateVerticalPlacement(_ proxy: GeometryProxy) {
        let frame = proxy.frame(in: .global)
        let newGrowsUpward = frame.minY > 260
        if growsUpward != newGrowsUpward {
            growsUpward = newGrowsUpward
        }
        if rowMaxX != frame.maxX {
            rowMaxX = frame.maxX
            if noteGlobalPoint.x > 0 {
                recalculateBubblePlacement()
            }
        }
    }

    func updateBubblePlacement(_ proxy: GeometryProxy) {
        let frame = proxy.frame(in: .global)
        noteGlobalPoint = CGPoint(x: frame.minX, y: frame.minY)
        recalculateBubblePlacement()
    }

    private func recalculateBubblePlacement() {
        let placement = RowBubblePlacement.calculate(
            globalPoint: noteGlobalPoint,
            wideHost: false,
            hostMaxX: rowMaxX > 0 ? (rowMaxX - 8) : nil
        )
        if growsUpward != placement.growsUpward {
            growsUpward = placement.growsUpward
        }
        if bubbleShiftX != placement.bubbleShiftX {
            bubbleShiftX = placement.bubbleShiftX
        }
    }

    func resetTitleTracking() {
        chrome.isTitlePointerInside = false
        chrome.resetTitleHover()
    }

    func pointerRegion(isTitle: Bool) -> some View {
        BoardRowPointerRegion(
            id: entry.id,
            onSelect: { command, shift in
                chrome.revealRow(reduceMotion: reduceMotion)
                onSelect?()
                if isTitle && !command && !shift && !isSensitive {
                    copyTitle(contentPresentation.mainText)
                }
            },
            onDoubleClick: openWindow,
            onHover: { hovering in
                guard isTitle else { return }
                chrome.isTitlePointerInside = hovering
                chrome.handleTitleHover(hovering, reduceMotion: reduceMotion)
            }
        )
    }
}
