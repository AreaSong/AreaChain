import SwiftData
import SwiftUI

struct DiaryPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale

    var todayKey: String
    var entries: [DiaryEntry]
    var showsComposer: Bool = false
    var usesSharedDiaryDay: Bool = false

    @Query private var attachments: [AttachmentItem]
    @Bindable private var selection = BoardSelection.shared

    @State private var localViewingKey: String
    @State private var draft = ""
    @FocusState private var composerFocused: Bool

    init(todayKey: String, entries: [DiaryEntry], showsComposer: Bool = false, usesSharedDiaryDay: Bool = false) {
        self.todayKey = todayKey
        self.entries = entries
        self.showsComposer = showsComposer
        self.usesSharedDiaryDay = usesSharedDiaryDay
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
        viewingKey == todayKey
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
            if !isViewingToday {
                Text("diary.hint")
                    .font(.system(size: 10))
                    .foregroundStyle(DaybookTheme.muted)
            }
            if showsComposer {
                composer
            }
            entryList
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
                TextField("diary.composer", text: $draft)
                    .textFieldStyle(.plain)
                    .focused($composerFocused)
                    .onSubmit(addTodayDiary)
                    .daybookHideInputChrome()
                ComposerAddButton(enabled: canSubmit, action: addTodayDiary)
            }
        }
    }

    private var dayChrome: some View {
        HStack(spacing: 4) {
            DaybookNavButton(systemName: "chevron.left", label: "diary.prev") {
                viewingKey = DayKey.shifted(viewingKey, by: -1)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(isViewingToday ? L10n.string("diary.today.title", locale: locale) : DayKey.displayName(viewingKey, locale: locale))
                Text(DayKey.shortStamp(viewingKey, locale: locale))
            }
            .font(.system(size: 11))
            .foregroundStyle(DaybookTheme.muted)
            DaybookNavButton(
                systemName: "chevron.right",
                label: "diary.next",
                enabled: !isViewingToday
            ) {
                viewingKey = DayKey.shifted(viewingKey, by: 1)
            }
            Spacer()
            if !isViewingToday {
                Button("diary.back") { viewingKey = todayKey }
                    .font(.system(size: 11, weight: .semibold))
                    .buttonStyle(DaybookQuietButtonStyle(prominent: true))
            }
        }
    }

    private var entryList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if visibleEntries.isEmpty {
                    DaybookEmptyState(title: emptyCopy)
                } else {
                    ForEach(visibleEntries, id: \.id) { entry in
                        DiaryLine(entry: entry, attachments: attachments)
                    }
                }
            }
        }
        .daybookScroll()
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
    var entry: DiaryEntry
    var attachments: [AttachmentItem]
    @State private var editing = false
    @State private var hovering = false
    @State private var draft = ""
    @State private var pendingTrash: PendingTrash?
    @FocusState private var rowFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(timeLabel(entry.createdAt))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(DaybookTheme.stamp.opacity(0.9))
                if editing {
                    TextField("diary.rename", text: $draft, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .onSubmit(save)
                        .onExitCommand(perform: cancel)
                } else {
                    Text(entry.text)
                        .font(.system(size: 13))
                        .foregroundStyle(DaybookTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .onTapGesture(perform: beginEdit)
                    if !diaryAttachments.isEmpty {
                        AttachmentThumbnails(items: diaryAttachments)
                    }
                }
            }
            Spacer(minLength: 4)
            if editing {
                RowIconButton(systemName: "checkmark", label: "row.save", action: save)
                RowIconButton(systemName: "xmark", label: "row.cancel", action: cancel)
            } else {
                if showsHoverActions {
                    RowIconButton(systemName: "pencil", label: "diary.edit", action: beginEdit)
                    RowIconButton(
                        systemName: "photo",
                        label: "row.attach",
                        action: {
                            AttachmentActions.pickImage(ownerKind: .diary, ownerID: entry.id, context: modelContext)
                        }
                    )
                    RowIconButton(systemName: "trash", label: "diary.delete", role: .destructive, action: requestTrash)
                }
                diaryMoreMenu
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .focusable()
        .focused($rowFocused)
        .onHover { hovering = $0 }
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
