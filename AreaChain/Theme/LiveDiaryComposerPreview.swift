import SwiftUI

/// 手记实时镜像预览卡片：在单行输入框打字时，100% 镜像呈现手记落入列表后的正式数据条版式。
/// 像素级镜像 DiarySummaryRow：
/// - 双行紧凑卡片：首行纯文本标题（超长 hover 展开 RowTitleBubble）、多行备注指示器、右侧悬停操作区（复制与更多操作）；
/// - 次行时间文本与真实彩色标签小方块群（tagPill）；
/// - 内边距 8/4pt、高度 57pt（minHeight: 46）、圆角 DaybookRadius.small(6pt)，悬停呈现 daybookSurface(.row) 浅灰高亮。
struct LiveDiaryComposerPreview: View {
    var text: String
    var allTags: [TagItem] = []
    var availableTags: [String] = []
    var isSensitiveExternal: Bool = false
    var showsSuggestions: Bool = false
    var onCopy: ((String, Bool) -> Bool)? = nil
    var onClose: (() -> Void)? = nil

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isRowHovered = false
    @State private var isTitleTextHovered = false
    @State private var isTitleBubbleHovered = false
    @State private var isNoteHovered = false
    @State private var isNoteBubbleHovered = false
    @State private var hasCopied = false
    @State private var hasNoteCopied = false
    @State private var growsUpward = false
    @State private var bubbleShiftX: CGFloat = 0
    @State private var rowMaxX: CGFloat = 0
    @State private var noteMinX: CGFloat = 0
    @State private var noteMinY: CGFloat = 0

    @MainActor
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private var parsed: ParsedDiaryCapture {
        NaturalLanguageParser.parseDiaryCapture(text)
    }

    private var isSensitive: Bool {
        isSensitiveExternal || DiaryPrivacy.requiresProtection(text: text, tagIDs: [], tags: allTags)
    }

    /// 实时输入预览态（未显式要求遮罩）直接展示正在输入的解析正文，仅在底栏展示隐私盾牌标识。
    private var masksContent: Bool {
        isSensitiveExternal || (!allTags.isEmpty && DiaryPrivacy.requiresProtection(text: text, tagIDs: [], tags: allTags))
    }

    private var todayTimeString: String {
        let formatter = Self.timeFormatter
        if formatter.locale != locale { formatter.locale = locale }
        let time = formatter.string(from: Date())
        return L10n.format("diary.date.today", locale: locale, time)
    }

    private var capturedPresentation: (mainText: String, note: String?) {
        let current = parsed
        let title = current.cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = current.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            return (title, body.isEmpty ? nil : body)
        }
        return DiaryCopyContent.split(body)
    }

    private var displayTitle: String {
        if masksContent {
            return L10n.string("diary.private.title", locale: locale)
        }
        return capturedPresentation.mainText
    }

    private var noteText: String {
        if masksContent { return "" }
        return capturedPresentation.note ?? ""
    }

    private var shouldShowTitleBubble: Bool {
        !masksContent && (isTitleTextHovered || isTitleBubbleHovered) && RowTitleTruncation.isTruncated(displayTitle)
    }

    private var rowGeometryObserver: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { updateRowPlacement(proxy) }
                .onChange(of: proxy.frame(in: .global).minY) { _, _ in updateRowPlacement(proxy) }
                .onChange(of: proxy.frame(in: .global).maxX) { _, _ in updateRowPlacement(proxy) }
        }
    }

    private var noteGeometryObserver: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { updateBubblePlacement(proxy) }
                .onChange(of: proxy.frame(in: .global).minY) { _, _ in updateBubblePlacement(proxy) }
                .onChange(of: proxy.frame(in: .global).minX) { _, _ in updateBubblePlacement(proxy) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            headerRow
                .zIndex(10)

            footerRow
                .zIndex(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 46)
        .background {
            Color.clear
                .daybookSurface(.row, isHovered: isRowHovered, isSelected: false)
                .daybookSurface(floating: .smallBackground, isPresented: !showsSuggestions)
        }
        .contentShape(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous))
        .onHover { hovering in
            withAnimation(DaybookMotion.interactive(reduceMotion)) {
                isRowHovered = hovering
                if !hovering {
                    isTitleTextHovered = false
                    isNoteHovered = false
                }
            }
        }
        .background(rowGeometryObserver)
        .task(id: hasCopied) {
            guard hasCopied else { return }
            try? await Task.sleep(for: .milliseconds(1200))
            if !Task.isCancelled {
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    hasCopied = false
                }
            }
        }
        .task(id: hasNoteCopied) {
            guard hasNoteCopied else { return }
            try? await Task.sleep(for: .milliseconds(1200))
            if !Task.isCancelled {
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    hasNoteCopied = false
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("diary.preview.card")
    }

    // MARK: - 第 1 行：主视觉行 (标题/正文首行 + 无视觉占位的无障碍锚点)

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 4) {
            noteContentHeader
                .frame(maxWidth: .infinity, alignment: .leading)

            actionCluster
                .frame(width: 14, height: 22)
                .padding(.leading, -4)
        }
    }

    private var noteContentHeader: some View {
        HStack(alignment: .center, spacing: 4) {
            Text(displayTitle.isEmpty ? " " : displayTitle)
                .font(DaybookType.body)
                .foregroundStyle(hasCopied ? DaybookPalette.accent.base : (masksContent ? DaybookPalette.text.secondary : DaybookPalette.text.primary))
                .lineLimit(1)
                .truncationMode(AppPreferences.shared.contentTruncation.textTruncation)
                .multilineTextAlignment(.leading)
                .layoutPriority(1)
                .animation(DaybookMotion.interactive(reduceMotion), value: hasCopied)
                .contentShape(Rectangle())
                .onTapGesture(perform: copyTitle)
                .onHover { hovering in
                    withAnimation(DaybookMotion.interactive(reduceMotion)) {
                        isTitleTextHovered = hovering
                    }
                }
                .overlay(alignment: growsUpward ? .bottomLeading : .topLeading) {
                    titleBubbleOverlay
                }

            if !noteText.isEmpty {
                noteIndicator(fullText: noteText)
                    .fixedSize()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var titleBubbleOverlay: some View {
        if shouldShowTitleBubble {
            RowTitleBubble(
                title: displayTitle,
                growsUpward: growsUpward,
                isExternallyCopied: hasCopied,
                onCopy: copyTitle,
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

    // MARK: - 右侧快捷操作区（无视觉像素的无障碍锚点）

    private var actionCluster: some View {
        HStack(spacing: 0) {
            copyButton
            moreMenu
        }
        .frame(width: 14, height: 22)
        .opacity(isRowHovered ? 1.0 : 0.0)
        .animation(DaybookMotion.interactive(reduceMotion), value: isRowHovered)
    }

    private var copyButton: some View {
        Button(action: copyTitle) {
            Text("")
                .frame(width: 4, height: 22)
        }
        .buttonStyle(.plain) // token-exempt: 无视觉像素的无障碍锚点
        .help("diary.copy")
        .accessibilityLabel("diary.copy")
    }

    private var moreMenu: some View {
        Menu {
            if let onClose {
                Button(action: onClose) {
                    Label("common.close", systemImage: "xmark")
                }
            }
            Button(action: copyTitle) {
                Label(hasCopied ? "diary.copied" : "diary.copy", systemImage: "doc.on.doc")
            }
        } label: {
            Text("")
                .frame(width: 10, height: 22)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("footer.more")
        .accessibilityLabel("footer.more")
        .fixedSize()
    }

    private func performCopy(_ text: String, isNote: Bool = false) {
        guard !text.isEmpty else { return }
        let success: Bool
        if let onCopy {
            success = onCopy(text, isSensitive)
        } else {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            success = true
        }
        guard success else { return }
        DaybookStatusNoticeCenter.shared.show(.copied)
        withAnimation(DaybookMotion.interactive(reduceMotion)) {
            if isNote {
                hasNoteCopied = true
            } else {
                hasCopied = true
            }
        }
    }

    private func copyTitle() {
        performCopy(displayTitle, isNote: false)
    }

    // MARK: - 第 2 行：时间戳 + 真实彩色标签群（100% 镜像 DiarySummaryRow）

    private var footerRow: some View {
        HStack(spacing: 5) {
            if isSensitive {
                Image(systemName: "lock.shield")
                    .font(.system(size: 8.5)) // token-exempt: 小于 9pt
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .accessibilityLabel("diary.privacy")
            }

            Text(todayTimeString)
                .lineLimit(1)
                .font(DaybookType.badge)
                .foregroundStyle(DaybookPalette.text.secondary)

            if !parsed.tagNames.isEmpty {
                let displayTags = Array(parsed.tagNames.prefix(1))
                let overflow = parsed.tagNames.count - displayTags.count
                HStack(spacing: 3) {
                    ForEach(displayTags, id: \.self) { tagName in
                        tagPill(tagName)
                    }
                    if overflow > 0 {
                        tagOverflowBadge(overflow)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            if hasCopied, onCopy != nil {
                Label("diary.copied", systemImage: "checkmark")
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookPalette.accent.base)
            }

            Spacer(minLength: 0)
        }
        .font(DaybookType.badge)
        .frame(height: 24, alignment: .leading)
    }

    private func tagPill(_ name: String) -> some View {
        let key = TagSyntax.normalizedName(name)
        let matched = allTags.first { TagSyntax.normalizedName($0.name) == key }
        return DiaryTagPill(name: name, colorToken: matched?.colorToken ?? TagColorToken.default.rawValue)
    }

    private func tagOverflowBadge(_ overflow: Int) -> some View {
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
    }

    // MARK: - 备注指示器与悬浮正文气泡

    private func noteIndicator(fullText: String) -> some View {
        let iconColor = hasNoteCopied
            ? DaybookPalette.accent.base
            : (isNoteHovered ? DaybookPalette.accent.base : DaybookPalette.text.secondary.opacity(0.65)) // token-exempt: 65% 次要色没有对应令牌
        let fillColor = hasNoteCopied
            ? DaybookPalette.accent.base.opacity(0.16) // token-exempt: 16% 没有对应令牌
            : (isNoteHovered ? DaybookPalette.accent.fill : DaybookPalette.text.primary.opacity(0.04)) // token-exempt: 4% 墨色没有对应令牌
        return Image(systemName: "text.alignleft")
            .font(DaybookType.micro.weight(.medium))
            .foregroundStyle(iconColor)
            .frame(width: 11, height: 11)
            .padding(.horizontal, 3.5)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.xxs, style: .continuous)
                    .fill(fillColor)
            )
            .background(noteGeometryObserver)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    isNoteHovered = hovering
                }
            }
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
        if isNoteHovered || isNoteBubbleHovered {
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

    private func copyNote(_ note: String) {
        performCopy(note, isNote: true)
    }

    private func updateRowPlacement(_ proxy: GeometryProxy) {
        let frame = proxy.frame(in: .global)
        if rowMaxX != frame.maxX {
            rowMaxX = frame.maxX
            if noteMinX > 0 {
                recalculateBubblePlacement()
            }
        }
        let newGrowsUpward = frame.minY > 260
        if growsUpward != newGrowsUpward {
            growsUpward = newGrowsUpward
        }
    }

    private func updateBubblePlacement(_ proxy: GeometryProxy) {
        let frame = proxy.frame(in: .global)
        noteMinX = frame.minX
        noteMinY = frame.minY
        recalculateBubblePlacement()
    }

    private func recalculateBubblePlacement() {
        let placement = RowBubblePlacement.calculate(
            globalPoint: CGPoint(x: noteMinX, y: noteMinY),
            wideHost: false,
            hostMaxX: rowMaxX > 0 ? (rowMaxX - 8) : nil
        )
        growsUpward = placement.growsUpward
        bubbleShiftX = placement.bubbleShiftX
    }
}
