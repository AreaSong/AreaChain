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

    @ViewBuilder
    func titleBubbleOverlay(for titleText: String) -> some View {
        if shouldShowTitleBubble {
            RowTitleBubble(
                title: titleText,
                growsUpward: growsUpward,
                onCopy: { copyTitle(titleText) },
                onHover: { hovering in
                    isTitleBubbleHovered = hovering
                    if !hovering && !isTitleTextHovered {
                        withAnimation(DaybookMotion.interactive(reduceMotion)) {
                            isTitleTextHovered = false
                        }
                    }
                }
            )
            .offset(y: growsUpward ? -6 : 22)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: growsUpward ? .bottomLeading : .topLeading)),
                removal: .opacity
            ))
        }
    }

    func noteIndicator(fullText: String) -> some View {
        Image(systemName: hasNoteCopied ? "checkmark" : "text.alignleft")
            .font(DaybookType.micro.weight(.medium))
            .foregroundStyle(hasNoteCopied ? DaybookPalette.accent.base : (isNoteHovered ? DaybookPalette.accent.base : DaybookPalette.text.secondary.opacity(0.65))) // token-exempt: 65% 次要色没有对应令牌
            .padding(.horizontal, 3.5)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.xxs, style: .continuous)
                    .fill(hasNoteCopied ? DaybookPalette.accent.base.opacity(0.16) : (isNoteHovered ? DaybookPalette.accent.fill : DaybookPalette.text.primary.opacity(0.04))) // token-exempt: 16% 与 4% 没有对应令牌
            )
            .contentShape(Rectangle())
            .onHover { chrome.handleNoteHover($0, reduceMotion: reduceMotion) }
            .onTapGesture {
                copyNote(fullText)
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    hasNoteCopied = true
                }
            }
            .overlay(alignment: growsUpward ? .bottomLeading : .topLeading) {
                noteBubbleOverlay(fullText: fullText)
            }
    }

    @ViewBuilder
    private func noteBubbleOverlay(fullText: String) -> some View {
        if shouldShowNoteBubble {
            let arrowPadding = max(8, min(186, 8 - bubbleShiftX))
            let transformAnchor = UnitPoint(
                x: max(0.06, min(0.94, (arrowPadding + 3.5) / 210.0)),
                y: growsUpward ? 1.0 : 0.0
            )
            RowNoteBubble(
                note: fullText,
                growsUpward: growsUpward,
                bubbleShiftX: bubbleShiftX,
                headerTitleKey: "drawer.notes.title",
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
            .offset(x: -8 + bubbleShiftX, y: growsUpward ? -18 : 16)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: transformAnchor)),
                removal: .opacity
            ))
        }
    }

    func updateBubblePlacement(_ proxy: GeometryProxy) {
        let frame = proxy.frame(in: .global)
        let placement = RowBubblePlacement.calculate(globalPoint: CGPoint(x: frame.minX, y: frame.minY), wideHost: false)
        growsUpward = placement.growsUpward
        bubbleShiftX = placement.bubbleShiftX
    }

    func pointerRegion(isTitle: Bool) -> some View {
        BoardRowPointerRegion(
            id: entry.id,
            onSelect: { _, _ in
                chrome.revealRow(reduceMotion: reduceMotion)
                onSelect?()
            },
            onDoubleClick: openWindow,
            onHover: { hovering in
                guard isTitle else { return }
                chrome.handleTitleHover(hovering, reduceMotion: reduceMotion)
            }
        )
    }
}
