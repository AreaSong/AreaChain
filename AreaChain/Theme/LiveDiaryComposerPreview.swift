import SwiftUI

/// 手记实时镜像预览卡片：在单行输入框打字时，100% 镜像呈现手记落入列表后的卡片版式。
/// 支持单行 `//` 拆分的首行粗体标题、次行灰色摘要、底栏时间戳、动态彩色标签群及隐私锁标记。
struct LiveDiaryComposerPreview: View {
    var text: String
    var allTags: [TagItem] = []
    var isSensitiveExternal: Bool = false
    var onClose: (() -> Void)? = nil

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isNoteHovered = false
    @State private var growsUpward = false
    @State private var bubbleShiftX: CGFloat = 0

    private var parsed: ParsedDiaryCapture {
        NaturalLanguageParser.parseDiaryCapture(text)
    }

    private var isSensitive: Bool {
        if isSensitiveExternal { return true }
        let names = Set(parsed.tagNames.map(TagSyntax.normalizedName))
        return allTags.contains { tag in
            tag.isPrivateDiary && names.contains(TagSyntax.normalizedName(tag.name))
        }
    }

    private var todayTimeString: String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let time = formatter.string(from: Date())
        return L10n.format("diary.date.today", locale: locale, time)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            contentArea
            metadataLine
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 46)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .fill(DaybookTheme.paper)
                .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 0.9, dash: [3.5, 3]),
                    antialiased: true
                )
                .foregroundStyle(DaybookTheme.stamp.opacity(0.48))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("diary.preview.card")
    }

    @ViewBuilder
    private var contentArea: some View {
        let title = parsed.cleanTitle
        let displayMainText = title.isEmpty ? parsed.body : title
        let noteText = title.isEmpty ? "" : parsed.body

        HStack(alignment: .center, spacing: 4) {
            Text(displayMainText.isEmpty ? " " : displayMainText)
                .font(DaybookType.body)
                .lineSpacing(2)
                .foregroundStyle(isSensitive ? DaybookTheme.muted : DaybookTheme.ink)
                .lineLimit(1)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)

            if !isSensitive && !noteText.isEmpty {
                noteIndicator(fullText: noteText)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func noteIndicator(fullText: String) -> some View {
        Image(systemName: "text.alignleft")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(isNoteHovered ? DaybookTheme.stamp : DaybookTheme.muted.opacity(0.65))
            .padding(.horizontal, 3.5)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(isNoteHovered ? DaybookTheme.stamp.opacity(0.12) : DaybookTheme.ink.opacity(0.04))
            )
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { updateBubblePlacement(proxy) }
                        .onChange(of: proxy.frame(in: .global).minY) { _, _ in updateBubblePlacement(proxy) }
                        .onChange(of: proxy.frame(in: .global).minX) { _, _ in updateBubblePlacement(proxy) }
                }
            )
            .contentShape(Rectangle())
            .onHover { isNoteHovered = $0 }
            .overlay(alignment: growsUpward ? .bottomLeading : .topLeading) {
                if isNoteHovered {
                    let arrowPadding = max(8, min(186, 8 - bubbleShiftX))
                    let transformAnchor = UnitPoint(
                        x: max(0.06, min(0.94, (arrowPadding + 3.5) / 210.0)),
                        y: growsUpward ? 1.0 : 0.0
                    )
                    noteFloatingBubble(fullText: fullText, arrowPadding: arrowPadding)
                        .offset(x: -8 + bubbleShiftX, y: growsUpward ? -18 : 16)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: transformAnchor)),
                            removal: .opacity
                        ))
                }
            }
    }

    private func updateBubblePlacement(_ proxy: GeometryProxy) {
        let frame = proxy.frame(in: .global)
        let globalY = frame.minY
        let globalX = frame.minX

        growsUpward = globalY > 260

        let safeMaxX: CGFloat = 356
        let safeMinX: CGFloat = 12
        let bubbleRight = globalX + 202
        if bubbleRight > safeMaxX {
            let overflow = bubbleRight - safeMaxX
            let maxShift = max(0, (globalX - 8) - safeMinX)
            bubbleShiftX = -min(overflow, maxShift)
        } else {
            bubbleShiftX = 0
        }
    }

    private func noteFloatingBubble(fullText: String, arrowPadding: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !growsUpward {
                HStack {
                    Spacer().frame(width: arrowPadding)
                    Image(systemName: "arrowtriangle.up.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(DaybookTheme.paper)
                        .offset(y: 1)
                    Spacer()
                }
                .frame(height: 5)
            }

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

                Text(fullText)
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

            if growsUpward {
                HStack {
                    Spacer().frame(width: arrowPadding)
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(DaybookTheme.paper)
                        .offset(y: -1)
                    Spacer()
                }
                .frame(height: 5)
            }
        }
        .frame(width: 210, alignment: .leading)
        .fixedSize()
        .allowsHitTesting(false)
        .zIndex(999)
    }

    private var metadataLine: some View {
        HStack(spacing: 5) {
            if isSensitive {
                Image(systemName: "lock.shield")
                    .font(.system(size: 9.5))
                    .foregroundStyle(DaybookTheme.stamp)
                    .accessibilityLabel("diary.privacy")
            }

            Text(todayTimeString)
                .lineLimit(1)
                .font(DaybookType.badge)
                .foregroundStyle(DaybookTheme.muted)

            if !parsed.tagNames.isEmpty {
                HStack(spacing: 3) {
                    ForEach(parsed.tagNames, id: \.self) { tagName in
                        tagPill(tagName)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(height: 22)
    }

    private func tagPill(_ name: String) -> some View {
        let color = DiaryTagChrome.color(for: name)
        return Text("#" + name)
            .font(.system(size: 9.5, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 4.5)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(color.opacity(0.12))
            )
            .foregroundStyle(color)
            .overlay(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .strokeBorder(color.opacity(0.25), lineWidth: 0.5)
            )
    }
}
