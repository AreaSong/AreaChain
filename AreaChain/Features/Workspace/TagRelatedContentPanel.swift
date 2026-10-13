import SwiftData
import SwiftUI

/// 标签页右侧关联内容分栏：实时展示选中标签下的事项、灵感手记与附件。
struct TagRelatedContentPanel: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @WorkspaceNavigationContext private var navigation

    var selectedTags: [TagItem]
    var allTags: [TagItem]
    var todos: [TodoItem]
    var routines: [DailyRoutine]
    var diaries: [DiaryEntry]
    var attachments: [AttachmentItem]
    var vault: PrivacyVault = .shared

    @State private var pendingTrash: PendingTrash?
    @State private var diaryDrafts = DiaryCardDrafts()

    private var matchingTodos: [TodoItem] {
        let tagSet = Set(selectedTags.map(\.id))
        return todos.filter { todo in
            todo.deletedAt == nil && !Set(TagIDList.parse(todo.tagIDs)).isDisjoint(with: tagSet)
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    private var matchingRoutines: [DailyRoutine] {
        let tagSet = Set(selectedTags.map(\.id))
        return routines.filter { routine in
            routine.deletedAt == nil && !Set(TagIDList.parse(routine.tagIDs)).isDisjoint(with: tagSet)
        }
        .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var matchingDiaries: [DiaryEntry] {
        let tagSet = Set(selectedTags.map(\.id))
        return diaries.filter { entry in
            entry.deletedAt == nil && !Set(TagIDList.parse(entry.tagIDs)).isDisjoint(with: tagSet)
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    private var matchingAttachments: [AttachmentItem] {
        let unlocked = vault.isUnlocked
        let visibleDiaryIDs = Set(
            matchingDiaries
                .filter { unlocked || !DiaryPrivacy.isSensitive($0.snapshot, tags: allTags) }
                .map(\.id)
        )
        let ownerIDs = Set(matchingTodos.map(\.id))
            .union(matchingRoutines.map(\.id))
            .union(visibleDiaryIDs)
        var seenStorage = Set<UUID>()
        return attachments.filter { item in
            guard item.deletedAt == nil, ownerIDs.contains(item.ownerID) else { return false }
            if item.privacyVaultID != nil && !unlocked { return false }
            let key = item.storageID ?? item.id
            return seenStorage.insert(key).inserted
        }
    }

    private var totalTaskCount: Int {
        matchingTodos.count + matchingRoutines.count
    }

    private var isEmptyContent: Bool {
        matchingTodos.isEmpty && matchingRoutines.isEmpty && matchingDiaries.isEmpty && matchingAttachments.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.md) {
            if let primary = selectedTags.first {
                panelHeader(primary: primary)
                Divider()
                if isEmptyContent {
                    Spacer(minLength: DaybookSpacing.lg)
                    DaybookEmptyState(
                        title: "tags.related.emptyTag.title",
                        subtitle: "tags.related.emptyTag.subtitle \(primary.name)",
                        systemImage: "tray"
                    )
                    Spacer(minLength: DaybookSpacing.lg)
                } else {
                    GeometryReader { scrollGeo in
                        ScrollView {
                            VStack(alignment: .leading, spacing: DaybookSpacing.md) {
                                tasksSection
                                diariesSection
                                attachmentsSection
                            }
                            .frame(width: max(scrollGeo.size.width, 1), alignment: .leading)
                            .padding(.bottom, DaybookSpacing.md)
                        }
                        .daybookScroll()
                    }
                }
            } else {
                Spacer(minLength: DaybookSpacing.lg)
                DaybookEmptyState(
                    title: "tags.related.emptySelection.title",
                    subtitle: "tags.related.emptySelection.subtitle",
                    systemImage: "tag"
                )
                Spacer(minLength: DaybookSpacing.lg)
            }
        }
        .padding(DaybookSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .daybookSurface(.card)
        .confirmMoveToTrash($pendingTrash)
    }

    private func panelHeader(primary: TagItem) -> some View {
        HStack(spacing: DaybookSpacing.sm) {
            DaybookStatusDot(
                color: DaybookPalette.tagMark(name: primary.name, token: primary.colorToken),
                size: 10
            )
            Text(verbatim: "#\(primary.name)")
                .font(DaybookType.body.weight(.semibold))
                .foregroundStyle(DaybookPalette.text.primary)
                .lineLimit(1)

            if selectedTags.count > 1 {
                DaybookChip(tint: DaybookPalette.accent.base, isSelected: true) {
                    Text(verbatim: "+\(selectedTags.count - 1)")
                }
            }

            if primary.isPrivateDiary {
                HStack(spacing: 3) {
                    Image(systemName: "lock.fill")
                        .font(DaybookType.micro)
                        .frame(width: 10, height: 10)
                    Text("tags.privacy.badge")
                        .font(DaybookType.badge)
                }
                .foregroundStyle(DaybookPalette.text.secondary)
            }

            Spacer(minLength: DaybookSpacing.xs)

            HStack(spacing: DaybookSpacing.sm) {
                countPill(icon: "checklist", count: totalTaskCount)
                countPill(icon: "note.text", count: matchingDiaries.count)
                countPill(icon: "paperclip", count: matchingAttachments.count)
            }
        }
        .frame(height: 20)
    }

    private func countPill(icon: String, count: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(DaybookType.micro)
            Text("\(count)")
                .font(DaybookType.caption.monospacedDigit())
        }
        .foregroundStyle(DaybookPalette.text.secondary)
    }

    @ViewBuilder
    private var tasksSection: some View {
        if totalTaskCount > 0 {
            VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
                DaybookSectionHeader(
                    title: "tags.related.section.tasks",
                    icon: "checklist",
                    count: totalTaskCount
                )
                ForEach(matchingRoutines) { routine in
                    routineRow(routine)
                }
                ForEach(matchingTodos) { todo in
                    todoRow(todo)
                }
            }
        }
    }

    private func todoRow(_ todo: TodoItem) -> some View {
        HStack(spacing: DaybookSpacing.sm) {
            Button {
                _ = DayBoardMutations.toggleTodo(todo)
            } label: {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .font(DaybookType.body)
                    .foregroundStyle(todo.isDone ? DaybookPalette.accent.base : DaybookPalette.text.tertiary)
            }
            .buttonStyle(.plain) // control: 关联面板待办勾选框

            Button {
                navigation.inspectTask(todo.id)
            } label: {
                HStack(spacing: DaybookSpacing.xs) {
                    Text(verbatim: todo.title)
                        .font(DaybookType.body)
                        .strikethrough(todo.isDone)
                        .foregroundStyle(todo.isDone ? DaybookPalette.text.tertiary : DaybookPalette.text.primary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(verbatim: todo.dayKey)
                        .font(DaybookType.caption.monospacedDigit())
                        .foregroundStyle(DaybookPalette.text.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain) // control: 关联面板待办行点击打开详情
        }
        .padding(.horizontal, DaybookSpacing.sm)
        .padding(.vertical, 6)
        .daybookStaticCardSurface()
    }

    private func routineRow(_ routine: DailyRoutine) -> some View {
        Button {
            navigation.inspectTask(routine.id)
        } label: {
            HStack(spacing: DaybookSpacing.sm) {
                Image(systemName: "repeat")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.accent.base)
                Text(verbatim: routine.title)
                    .font(DaybookType.body)
                    .foregroundStyle(routine.isEnabled ? DaybookPalette.text.primary : DaybookPalette.text.tertiary)
                    .lineLimit(1)
                Spacer(minLength: 4)
            }
            .padding(.horizontal, DaybookSpacing.sm)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .daybookStaticCardSurface()
        }
        .buttonStyle(.plain) // control: 关联面板重复事项行点击打开详情
    }

    @ViewBuilder
    private var diariesSection: some View {
        if !matchingDiaries.isEmpty {
            VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
                DaybookSectionHeader(
                    title: "tags.related.section.diaries",
                    icon: "note.text",
                    count: matchingDiaries.count
                )
                ForEach(matchingDiaries) { entry in
                    DiaryNoteCard(
                        entry: entry,
                        activeTags: Catalog.liveTags(allTags),
                        attachments: attachments,
                        onDelete: {
                            pendingTrash = .diary(entry, tags: { allTags }, locale: locale) {
                                DayBoardMutations.deleteDiary(entry)
                            }
                        },
                        privacyTags: allTags,
                        draftStore: diaryDrafts
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var attachmentsSection: some View {
        if !matchingAttachments.isEmpty {
            VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
                DaybookSectionHeader(
                    title: "tags.related.section.attachments",
                    icon: "paperclip",
                    count: matchingAttachments.count
                )
                AttachmentThumbnails(
                    items: matchingAttachments.map(\.reference),
                    thumbnailSize: 44
                )
                .padding(.vertical, 4)
            }
        }
    }
}
