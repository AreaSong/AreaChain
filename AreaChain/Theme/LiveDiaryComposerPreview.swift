import SwiftUI

/// 手记实时镜像预览卡片：在单行输入框打字时，100% 镜像呈现手记落入列表后的正式数据条版式。
/// 像素级镜像 DiarySummaryRow：
/// - 双行紧凑卡片：首行纯文本标题（超长 hover 展开 RowTitleBubble）、多行备注指示器、右侧悬停操作区（复制与更多操作）；
/// - 次行时间文本与真实彩色标签小方块群（tagPill）；
/// - 内边距 8/4pt、高度 57pt（minHeight: 46）、圆角 DaybookRadius.small(6pt)，悬停呈现 modernRow 浅灰高亮。
struct LiveDiaryComposerPreview: View {
    var text: String
    var allTags: [TagItem] = []
    var availableTags: [String] = []
    var isSensitiveExternal: Bool = false
    var showsSuggestions: Bool = false
    var onClose: (() -> Void)? = nil

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isHovered = false
    @State private var hasCopied = false
    @State private var isTitleTextHovered = false
    @State private var isTitleBubbleHovered = false
    @State private var titleHoverTask: Task<Void, Never>? = nil
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

    private var todayTimeString: String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let time = formatter.string(from: Date())
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

    private var shouldShowTitleBubble: Bool {
        !isSensitive && (isTitleTextHovered || isTitleBubbleHovered) && RowTitleTruncation.isTruncated(displayTitle)
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
        .modernRow(
            cornerRadius: DaybookRadius.small,
            isHovered: isHovered,
            isSelected: false
        )
        .background(
            Group {
                if !showsSuggestions {
                    RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                        .fill(DaybookTheme.paper)
                        .shadow(color: DaybookTheme.ink.opacity(0.10), radius: 6, x: 0, y: 3)
                }
            }
        )
        .overlay(
            Group {
                if !showsSuggestions {
                    RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                        .stroke(DaybookTheme.rule.opacity(0.7), lineWidth: 0.7)
                }
            }
        )
        .contentShape(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous))
        .onHover { hovering in
            isHovered = hovering
            if !hovering {
                titleHoverTask?.cancel()
                titleHoverTask = nil
                if !isTitleBubbleHovered {
                    withAnimation(DaybookMotion.interactive(reduceMotion)) {
                        isTitleTextHovered = false
                    }
                }
                if !isNoteHovered {
                    withAnimation(DaybookMotion.interactive(reduceMotion)) {
                        isNoteHovered = false
                    }
                }
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { updateBubblePlacement(proxy) }
                    .onChange(of: proxy.frame(in: .global).minY) { _, _ in updateBubblePlacement(proxy) }
                    .onChange(of: proxy.frame(in: .global).minX) { _, _ in updateBubblePlacement(proxy) }
            }
        )
        .task(id: hasCopied) {
            guard hasCopied else { return }
            try? await Task.sleep(for: .milliseconds(1200))
            if !Task.isCancelled {
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    hasCopied = false
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("diary.preview.card")
    }

    // MARK: - 第 1 行：主视觉行 (标题/正文首行 + 恒定 48x22 占位的悬停操作按钮)

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 4) {
            noteContentHeader
                .frame(maxWidth: .infinity, alignment: .leading)

            actionCluster
                .frame(width: 48, height: 22)
        }
    }

    private var noteContentHeader: some View {
        HStack(alignment: .center, spacing: 4) {
            Text(displayTitle.isEmpty ? " " : displayTitle)
                .font(DaybookType.body)
                .foregroundStyle(isSensitive ? DaybookTheme.muted : DaybookTheme.ink)
                .lineLimit(1)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .layoutPriority(1)
                .contentShape(Rectangle())
                .onHover { hovering in
                    handleTitleHover(hovering)
                }
                .overlay(alignment: growsUpward ? .bottomLeading : .topLeading) {
                    if shouldShowTitleBubble {
                        RowTitleBubble(
                            title: displayTitle,
                            growsUpward: growsUpward,
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

            if !noteText.isEmpty {
                noteIndicator(fullText: noteText)
                    .fixedSize()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func handleTitleHover(_ hovering: Bool) {
        titleHoverTask?.cancel()
        if hovering {
            titleHoverTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    isTitleTextHovered = true
                }
            }
        } else {
            titleHoverTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                if !isTitleBubbleHovered {
                    withAnimation(DaybookMotion.interactive(reduceMotion)) {
                        isTitleTextHovered = false
                    }
                }
            }
        }
    }

    // MARK: - 右侧快捷操作区 (恒定 48x22 占位：📋 复制 + ··· 更多/关闭菜单，纯透明度渐变，零抖动)

    private var actionCluster: some View {
        HStack(spacing: 4) {
            copyButton
            moreMenu
        }
        .frame(width: 48, height: 22)
        .opacity(isHovered ? 1.0 : 0.0)
        .animation(DaybookMotion.interactive(reduceMotion), value: isHovered)
    }

    private var copyButton: some View {
        Button(action: copyTitle) {
            Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(hasCopied ? DaybookTheme.stamp : DaybookTheme.muted)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                        .fill(hasCopied ? DaybookTheme.stamp.opacity(0.15) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DaybookTheme.muted)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                        .fill(Color.clear)
                )
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .help("footer.more")
        .accessibilityLabel("footer.more")
        .fixedSize()
    }

    private func copyTitle() {
        guard !displayTitle.isEmpty else { return }
        guard PrivateClipboard.copy(displayTitle, sensitive: isSensitive) else { return }
        withAnimation(DaybookMotion.interactive(reduceMotion)) {
            hasCopied = true
        }
    }

    // MARK: - 第 2 行：时间戳 + 真实彩色标签群（100% 镜像 DiarySummaryRow）

    private var footerRow: some View {
        HStack(spacing: 5) {
            if isSensitive {
                Image(systemName: "lock.shield")
                    .font(.system(size: 8.5))
                    .foregroundStyle(DaybookTheme.muted)
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

            if hasCopied {
                Label("diary.copied", systemImage: "checkmark")
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookTheme.stamp)
            }

            Spacer(minLength: 0)
        }
        .font(DaybookType.badge)
        .frame(height: 24, alignment: .leading)
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
            .help("#" + name)
    }

    // MARK: - 备注指示器与悬浮正文气泡

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
        let placement = RowBubblePlacement.calculate(globalPoint: CGPoint(x: frame.minX, y: frame.minY), isWorkspace: false)
        growsUpward = placement.growsUpward
        bubbleShiftX = placement.bubbleShiftX
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
}
