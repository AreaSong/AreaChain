import SwiftData
import SwiftUI

struct DiaryPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale

    var todayKey: String
    var entries: [DiaryEntry]
    var showsComposer: Bool = false
    var usesSharedDiaryDay: Bool = false
    var maxScrollHeight: CGFloat? = nil

    @Query private var attachments: [AttachmentItem]
    @Bindable private var selection = BoardSelection.shared

    @State private var localViewingKey: String
    @State private var draft = ""
    @FocusState private var composerFocused: Bool

    init(
        todayKey: String,
        entries: [DiaryEntry],
        showsComposer: Bool = false,
        usesSharedDiaryDay: Bool = false,
        maxScrollHeight: CGFloat? = nil
    ) {
        self.todayKey = todayKey
        self.entries = entries
        self.showsComposer = showsComposer
        self.usesSharedDiaryDay = usesSharedDiaryDay
        self.maxScrollHeight = maxScrollHeight
        _localViewingKey = State(initialValue: todayKey)
    }

    private var viewingKey: String {
        get { usesSharedDiaryDay ? selection.diaryDayKey : localViewingKey }
        nonmutating set {
            if usesSharedDiaryDay {
                selection.diaryDayKey = newValue
            } else {
                localViewingKey = newValue
            }
        }
    }

    private var isViewingToday: Bool {
        viewingKey >= todayKey
    }

    private var visibleEntries: [DiaryEntry] {
        let ids = Set(DayBoardLogic.diaries(for: viewingKey, in: entries.map(\.snapshot)).map(\.id))
        return entries
            .filter { ids.contains($0.id) && $0.deletedAt == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var canSubmit: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            dayChrome
            if isViewingToday {
                if showsComposer {
                    composer
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 11))
                        .foregroundStyle(DaybookTheme.stamp)
                    Text("diary.hint")
                        .font(.system(size: 11))
                        .foregroundStyle(DaybookTheme.muted)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            entryList
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if isViewingToday && showsComposer {
                composerFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusCapture)) { _ in
            if isViewingToday && showsComposer {
                composerFocused = true
            }
        }
        .onChange(of: todayKey) { _, newValue in
            if viewingKey > newValue {
                viewingKey = newValue
            }
        }
    }

    private var composer: some View {
        DaybookField(focused: composerFocused) {
            HStack(spacing: 8) {
                DaybookTextField(
                    text: $draft,
                    placeholder: L10n.string("diary.composer", locale: locale),
                    focus: $composerFocused,
                    onSubmit: addTodayDiary
                )
                .accessibilityLabel("diary.composer")
                ComposerAddButton(title: "diary.record", enabled: canSubmit, action: addTodayDiary)
            }
        }
        .daybookHideInputChrome()
    }

    private var dayChrome: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                DaybookNavButton(systemName: "chevron.left", label: "diary.prev") {
                    viewingKey = DayKey.shifted(viewingKey, by: -1)
                }
                DaybookNavButton(
                    systemName: "chevron.right",
                    label: "diary.next",
                    enabled: viewingKey < todayKey
                ) {
                    if viewingKey < todayKey {
                        viewingKey = DayKey.shifted(viewingKey, by: 1)
                    }
                }
            }

            HStack(spacing: 6) {
                Text(isViewingToday ? L10n.string("diary.today.title", locale: locale) : DayKey.displayName(viewingKey, locale: locale))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DaybookTheme.ink)
                Text(DayKey.shortStamp(viewingKey, locale: locale))
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(DaybookTheme.muted)
            }

            Spacer()

            if !isViewingToday {
                Button("diary.back") { viewingKey = todayKey }
                    .font(.system(size: 11, weight: .semibold))
                    .buttonStyle(DaybookQuietButtonStyle(prominent: true))
            } else if !visibleEntries.isEmpty {
                Text(L10n.format("diary.count_format", locale: locale, visibleEntries.count))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DaybookTheme.muted)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(DaybookTheme.ink.opacity(0.04))
        )
    }

    private var entryList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if visibleEntries.isEmpty {
                    DaybookEmptyState(title: emptyCopy, systemImage: "square.and.pencil")
                        .padding(.vertical, 16)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(DaybookTheme.rule.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        )
                } else {
                    ForEach(Array(visibleEntries.enumerated()), id: \.element.id) { index, entry in
                        DiaryTimelineRow(
                            entry: entry,
                            attachments: attachments,
                            isFirst: index == 0,
                            isLast: index == visibleEntries.count - 1
                        )
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .daybookScroll()
        .frame(maxWidth: .infinity, maxHeight: maxScrollHeight ?? .infinity)
    }

    private var emptyCopy: LocalizedStringKey {
        isViewingToday ? "diary.empty.today" : "diary.empty.past"
    }

    private func addTodayDiary() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        modelContext.insert(DiaryEntry(text: text, dayKey: todayKey))
        draft = ""
        viewingKey = todayKey
        BoardEvents.changed()
    }
}

struct DiaryLine: View {
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var entry: DiaryEntry
    var attachments: [AttachmentItem]
    @State private var editing = false
    @State private var hovering = false
    @State private var draft = ""
    @State private var pendingTrash: PendingTrash?
    @FocusState private var rowFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 9, weight: .medium))
                    Text(timeLabel(entry.createdAt))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(DaybookTheme.stamp)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(DaybookTheme.stamp.opacity(0.12))
                )

                Spacer()

                if editing {
                    RowIconButton(systemName: "checkmark", label: "row.save", action: save)
                    RowIconButton(systemName: "xmark", label: "row.cancel", action: cancel)
                } else {
                    HStack(spacing: 2) {
                        RowIconButton(systemName: "pencil", label: "diary.edit", action: beginEdit)
                        RowIconButton(
                            systemName: "photo",
                            label: "row.attach",
                            action: {
                                AttachmentActions.pickImage(ownerKind: .diary, ownerID: entry.id, context: modelContext)
                            }
                        )
                        RowIconButton(systemName: "trash", label: "diary.delete", role: .destructive, action: requestTrash)
                        diaryMoreMenu
                    }
                    .opacity(showsHoverActions ? 1 : 0)
                    .animation(DaybookMotion.animation(reduceMotion), value: showsHoverActions)
                }
            }

            if editing {
                TextField("diary.rename", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(DaybookTheme.paper)
                            .stroke(DaybookTheme.focusRing, lineWidth: 1.2)
                    )
                    .onSubmit(save)
                    .onExitCommand(perform: cancel)
            } else {
                Text(entry.text)
                    .font(.system(size: 13))
                    .lineSpacing(3)
                    .foregroundStyle(DaybookTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: beginEdit)

                if !diaryAttachments.isEmpty {
                    AttachmentThumbnails(items: diaryAttachments)
                        .padding(.top, 2)
                }
            }
        }
        .padding(10)
        .modernCard(cornerRadius: DaybookRadius.medium, isHovered: hovering, isSelected: rowFocused)
        .contentShape(RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous))
        .focusable()
        .focusEffectDisabled()
        .focused($rowFocused)
        .onHover { hovering = $0 }
        .animation(ModernMotion.interactive(reduceMotion), value: hovering)
        .animation(ModernMotion.interactive(reduceMotion), value: rowFocused)
        .contextMenu {
            Button("diary.edit", action: beginEdit)
            Button("row.attach") {
                AttachmentActions.pickImage(ownerKind: .diary, ownerID: entry.id, context: modelContext)
            }
            Button("row.attach.paste") {
                _ = AttachmentActions.pasteImage(ownerKind: .diary, ownerID: entry.id, context: modelContext)
            }
            Button("row.attach.screen") {
                AttachmentActions.captureScreen(ownerKind: .diary, ownerID: entry.id, context: modelContext)
            }
            Button("diary.delete", role: .destructive, action: requestTrash)
        }
        .confirmMoveToTrash($pendingTrash)
        .onAppear { draft = entry.text }
    }

    private var cardBackground: Color {
        if rowFocused {
            return DaybookTheme.cardSelectionFill
        }
        if hovering {
            return DaybookTheme.cardSurfaceHover
        }
        return DaybookTheme.cardSurface
    }

    private var cardStroke: Color {
        if rowFocused {
            return DaybookTheme.cardSelectionStroke
        }
        if hovering {
            return DaybookTheme.rule.opacity(0.45)
        }
        return DaybookTheme.rule.opacity(0.25)
    }

    private var showsHoverActions: Bool {
        hovering || rowFocused
    }

    private var diaryMoreMenu: some View {
        Menu {
            Button("diary.edit", action: beginEdit)
            Button("row.attach") {
                AttachmentActions.pickImage(ownerKind: .diary, ownerID: entry.id, context: modelContext)
            }
            Button("row.attach.paste") {
                _ = AttachmentActions.pasteImage(ownerKind: .diary, ownerID: entry.id, context: modelContext)
            }
            Button("row.attach.screen") {
                AttachmentActions.captureScreen(ownerKind: .diary, ownerID: entry.id, context: modelContext)
            }
            Button("diary.delete", role: .destructive, action: requestTrash)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: DaybookTheme.hit, height: DaybookTheme.hit)
                .contentShape(Rectangle())
        }
        .buttonStyle(DaybookQuietButtonStyle())
        .menuIndicator(.hidden)
        .help("row.more")
        .accessibilityLabel("row.more")
    }

    private var diaryAttachments: [AttachmentRef] {
        CatalogChoices.attachments(entry.id, in: attachments)
    }

    private func beginEdit() {
        draft = entry.text
        editing = true
    }

    private func cancel() {
        draft = entry.text
        editing = false
    }

    private func save() {
        let next = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !next.isEmpty {
            entry.text = next
            BoardEvents.changed()
        }
        editing = false
    }

    private func requestTrash() {
        pendingTrash = PendingTrash(title: entry.text) {
            entry.deletedAt = .now
            BoardEvents.changed()
        }
    }

    private func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct DiaryTimelineRow: View {
    var entry: DiaryEntry
    var attachments: [AttachmentItem]
    var isFirst: Bool
    var isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            timelineBar
            DiaryLine(entry: entry, attachments: attachments)
        }
    }

    private var timelineBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isFirst ? Color.clear : DaybookTheme.rule.opacity(0.45))
                .frame(width: 1.5, height: 8)

            Circle()
                .fill(DaybookTheme.stamp)
                .frame(width: 6, height: 6)
                .overlay(
                    Circle()
                        .stroke(DaybookTheme.stamp.opacity(0.25), lineWidth: 2)
                )

            Rectangle()
                .fill(isLast ? Color.clear : DaybookTheme.rule.opacity(0.45))
                .frame(width: 1.5)
                .frame(maxHeight: .infinity)
        }
        .frame(width: 8)
        .padding(.top, 4)
    }
}
