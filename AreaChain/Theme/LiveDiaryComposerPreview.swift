import SwiftUI

/// 手记实时镜像预览卡片：在单行输入框打字时，100% 镜像呈现手记落入列表后的卡片版式。
/// 单行 36pt 紧凑实线卡片，与任务卡片视觉规范完全统一（无虚线，实线圆角，左右 10pt 对齐，14pt 状态图标对齐）。
struct LiveDiaryComposerPreview: View {
    var text: String
    var allTags: [TagItem] = []
    var availableTags: [String] = []
    var isSensitiveExternal: Bool = false
    var showsSuggestions: Bool = false
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
        if !allTags.isEmpty {
            return allTags.contains { tag in
                tag.isPrivateDiary && names.contains(TagSyntax.normalizedName(tag.name))
            }
        }
        return names.contains("密码") || names.contains("password")
    }

    private var timeOnlyString: String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: Date())
    }

    private var todayTimeString: String {
        let time = timeOnlyString
        return L10n.format("diary.date.today", locale: locale, time)
    }

    private var displayTitle: String {
        if isSensitive {
            return L10n.string("diary.private.title", locale: locale)
        }
        let title = parsed.cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        let body = parsed.body.trimmingCharacters(in: .whitespacesAndNewlines)
        return body.isEmpty ? "" : body
    }

    private var noteText: String {
        if isSensitive { return "" }
        let title = parsed.cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "" : parsed.body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canFitAllTagsInline: Bool {
        Self.canFit(
            title: displayTitle,
            tags: parsed.tagNames,
            hasNotes: !noteText.isEmpty
        )
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            mainRow
            if !canFitAllTagsInline && parsed.tagNames.count > 1 && !showsSuggestions && !isNoteHovered {
                tagDetailBubble
                    .padding(.trailing, 4)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)),
                        removal: .opacity
                    ))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("diary.preview.card")
    }

    private var mainRow: some View {
        HStack(alignment: .center, spacing: 6) {
            leadingIcon

            titleArea

            trailingCluster
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(
            Group {
                if !showsSuggestions {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(DaybookTheme.paper)
                        .shadow(color: DaybookTheme.ink.opacity(0.10), radius: 6, x: 0, y: 3)
                }
            }
        )
        .overlay(
            Group {
                if !showsSuggestions {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(DaybookTheme.rule.opacity(0.7), lineWidth: 0.7)
                }
            }
        )
    }

    private var leadingIcon: some View {
        Group {
            if isSensitive {
                Image(systemName: "lock.shield")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DaybookTheme.stamp)
            } else {
                Image(systemName: "note.text")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DaybookTheme.muted.opacity(0.8))
            }
        }
        .frame(width: 14, height: 14)
    }

    private var titleArea: some View {
        HStack(alignment: .center, spacing: 5) {
            Text(displayTitle.isEmpty ? " " : displayTitle)
                .font(DaybookType.body)
                .foregroundStyle(isSensitive ? DaybookTheme.muted : DaybookTheme.ink)
                .lineLimit(1)
                .truncationMode(.tail)

            if !noteText.isEmpty {
                noteIndicator(fullText: noteText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var trailingCluster: some View {
        HStack(spacing: 5) {
            tagsView

            timeBadge

            if let onClose, !showsSuggestions {
                closeButton(onClose)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var tagsView: some View {
        let tags = parsed.tagNames
        if canFitAllTagsInline {
            ForEach(tags, id: \.self) { tag in
                tagBadge(tag)
            }
        } else if tags.count == 1, let singleTag = tags.first {
            tagBadge(singleTag)
                .frame(maxWidth: 96, alignment: .leading)
        } else if tags.count > 1 {
            HStack(spacing: 2.5) {
                Image(systemName: "number")
                    .font(.system(size: 8.5, weight: .bold))
                Text("\(tags.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(Capsule().fill(DaybookTheme.Syntax.tagBadgeFill))
            .overlay(Capsule().stroke(DaybookTheme.Syntax.tagStroke, lineWidth: 0.6))
            .foregroundStyle(DaybookTheme.Syntax.tag)
            .help(L10n.format("syntax.tags.count", locale: locale, tags.count))
        }
    }

    private func tagBadge(_ name: String) -> some View {
        let color = DiaryTagChrome.color(for: name)
        return Text("#\(name)")
            .font(.system(size: 11, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 5.5)
            .padding(.vertical, 2.5)
            .background(Capsule().fill(color.opacity(0.12)))
            .overlay(Capsule().stroke(color.opacity(0.28), lineWidth: 0.6))
            .foregroundStyle(color)
            .help("#\(name)")
    }

    private var timeBadge: some View {
        HStack(spacing: 2.5) {
            Image(systemName: "clock")
                .font(.system(size: 9.5))
            Text(timeOnlyString)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(Capsule().fill(DaybookTheme.Syntax.timeFill))
        .foregroundStyle(DaybookTheme.Syntax.time)
        .help(todayTimeString)
    }

    private func closeButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
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

    private var tagDetailBubble: some View {
        HStack(spacing: 4) {
            ForEach(parsed.tagNames, id: \.self) { tag in
                tagBadge(tag)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
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

    // MARK: - 容量碰撞检测算法

    static func canFit(
        title: String,
        tags: [String],
        hasNotes: Bool = false,
        cardWidth: CGFloat = DaybookTheme.popoverWidth - 24
    ) -> Bool {
        guard !tags.isEmpty else { return true }
        let horizontalPadding: CGFloat = 20
        let iconAndGap: CGFloat = 20
        let closeButtonAndGap: CGFloat = 24
        let timeWidth: CGFloat = 52
        let notesWidth: CGFloat = hasNotes ? 20 : 0

        let availableForContent = cardWidth - horizontalPadding - iconAndGap - closeButtonAndGap - timeWidth - notesWidth

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
                    w += fontSize * 0.55
                }
            } else {
                w += fontSize * 1.05
            }
        }
        return w
    }
}
