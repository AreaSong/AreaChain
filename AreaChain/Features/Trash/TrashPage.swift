import SwiftData
import SwiftUI

struct TrashPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query(sort: \DiaryEntry.createdAt, order: .reverse) private var diaries: [DiaryEntry]
    @Query(sort: \ProjectItem.sortOrder) private var projects: [ProjectItem]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @Query private var attachments: [AttachmentItem]

    @State private var pendingPurge: PendingTrash?
    @State private var confirmEmpty = false

    private var deletedOwnerIDs: Set<UUID> {
        Set(routines.compactMap { $0.deletedAt == nil ? nil : $0.id })
            .union(todos.compactMap { $0.deletedAt == nil ? nil : $0.id })
            .union(diaries.compactMap { $0.deletedAt == nil ? nil : $0.id })
    }

    private var items: [TrashRow] {
        let standing = routines.compactMap { TrashRow.resident($0, attachments: attachments) }
        let tasks = todos.compactMap { TrashRow.todo($0, attachments: attachments) }
        let notes = diaries.compactMap { TrashRow.diary($0, attachments: attachments, tags: { tags }, locale: locale) }
        let files = attachments.compactMap { item in
            let live = item.ownerKey.map { AttachmentAccess.ownerIsLive($0, todos: todos, routines: routines, diaries: diaries) } ?? false
            return TrashRow.attachment(item, ownerDeleted: !live, titleProvider: {
                guard item.ownerKind == AttachmentOwner.diary.rawValue else { return item.filename }
                guard let entry = diaries.first(where: { $0.id == item.ownerID }),
                      !DiaryPrivacy.isSensitive(entry.snapshot, tags: tags) else {
                    return L10n.string("diary.private.attachment", locale: locale)
                }
                return item.filename
            })
        }
        let catalog = projects.compactMap { TrashRow.project($0) }
            + tags.compactMap { TrashRow.tag($0) }
        return (standing + tasks + notes + files + catalog).sorted { $0.deletedAt > $1.deletedAt }
    }

    var body: some View {
        DaybookPage(
            title: "window.trash",
            subtitle: "trash.hint",
            minWidth: 360,
            minHeight: 420
        ) {
            Button("trash.empty.action") { confirmEmpty = true }
                .font(DaybookType.caption.weight(.semibold))
                .buttonStyle(DaybookButtonStyle(.destructive))
                .disabled(items.isEmpty)
                .confirmationDialog("alert.purge.all.title", isPresented: $confirmEmpty, titleVisibility: .visible) {
                    Button("alert.purge.all", role: .destructive, action: emptyTrash)
                    Button("alert.cancel", role: .cancel) {}
                } message: {
                    Text("alert.purge.all.message")
                }
        } content: {
            if items.isEmpty {
                DaybookEmptyState(title: "trash.empty", systemImage: "trash")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                list
            }
        }
        .confirmPurge($pendingPurge)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(items) { item in
                    trashCard(item)
                }
            }
            .padding(.vertical, 2)
        }
        .daybookScroll()
    }

    private func trashCard(_ item: TrashRow) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                if item.isResident {
                    Image(systemName: "repeat")
                        .font(DaybookType.badge.weight(.bold))
                        .foregroundStyle(DaybookTheme.stamp)
                }
                Text(item.kindLabel)
                    .font(DaybookType.badge.weight(.medium))
                    .foregroundStyle(DaybookTheme.muted)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                            .fill(DaybookTheme.hoverFill)
                    )

                Text(item.displayTitle)
                    .font(DaybookType.body)
                    .foregroundStyle(DaybookTheme.ink)
                    .lineLimit(2)
            }

            Spacer(minLength: 16)

            HStack(spacing: 12) {
                Text(ClockLabel.created(item.deletedAt, locale: locale))
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookTheme.muted)

                HStack(spacing: 6) {
                    Button("trash.restore") { restore(item) }
                        .buttonStyle(DaybookButtonStyle(.prominent))
                        .disabled(!item.canRestore)
                        .help(item.canRestore ? "trash.restore" : "trash.restore.blocked")

                    Button("trash.purge", role: .destructive) {
                        pendingPurge = PendingTrash(title: "", titleProvider: { item.displayTitle }) { purge(item) }
                    }
                    .buttonStyle(DaybookButtonStyle(.destructive))
                }
                .font(DaybookType.caption)
            }
        }
        .daybookSurface(.card, configure: {
    $0.radius = DaybookRadius.small
    $0.padding = EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 12)
})
    }

    private func restore(_ item: TrashRow) {
        item.restore()
    }

    private func purge(_ item: TrashRow) {
        guard item.purge() else { return }
        if let owner = item.purgesOwner { EditDrafts.shared.discard(owner: owner) }
    }

    private func emptyTrash() {
        let rows = items
        let purgedOwners = Set(rows.compactMap(\.purgesOwner))
        guard ModelChanges.perform(in: modelContext, {
            for item in rows {
                if let owner = item.skipIfOwnerPurged, purgedOwners.contains(owner) { continue }
                try item.removeFromStore(modelContext)
            }
        }) else { return }
        for owner in purgedOwners { EditDrafts.shared.discard(owner: owner) }
        ModelChanges.attempt { try AttachmentCleanup.purge(ids: Set(rows.flatMap(\.filesToRemove)), context: modelContext) }
    }
}

@MainActor
struct TrashRow: Identifiable {
    var id: UUID
    var title: String
    var kindLabel: LocalizedStringKey
    var isResident: Bool
    var deletedAt: Date
    var restore: @MainActor () -> Void
    var purge: @MainActor () -> Bool
    var removeFromStore: @MainActor (ModelContext) throws -> Void
    var purgesOwner: AttachmentOwnerKey? = nil
    var skipIfOwnerPurged: AttachmentOwnerKey? = nil
    var canRestore: Bool = true
    var titleProvider: (() -> String)? = nil
    var filesToRemove: [UUID] = []

    var displayTitle: String { titleProvider?() ?? title }

    static func resident(_ item: DailyRoutine, attachments: [AttachmentItem]) -> TrashRow? {
        guard let deletedAt = item.deletedAt else { return nil }
        return TrashRow(
            id: item.id,
            title: item.title,
            kindLabel: "trash.kind.resident",
            isResident: true,
            deletedAt: deletedAt,
            restore: { _ = DayBoardMutations.restoreRoutine(item) },
            purge: { DayBoardMutations.purgeRoutine(item) },
            removeFromStore: { context in
                try DayBoardMutations.routineRepo(for: context).deleteRoutine(id: item.id, soft: false)
            },
            purgesOwner: AttachmentOwnerKey(kind: .routine, id: item.id),
            filesToRemove: attachments.filter { $0.ownerKey == AttachmentOwnerKey(kind: .routine, id: item.id) }.map(\.id)
        )
    }

    static func todo(_ item: TodoItem, attachments: [AttachmentItem]) -> TrashRow? {
        guard let deletedAt = item.deletedAt else { return nil }
        return TrashRow(
            id: item.id,
            title: item.title,
            kindLabel: "trash.kind.todo",
            isResident: false,
            deletedAt: deletedAt,
            restore: { _ = DayBoardMutations.restoreTodo(item) },
            purge: { DayBoardMutations.purgeTodo(item) },
            removeFromStore: { context in
                try DayBoardMutations.taskRepo(for: context).deleteTodo(id: item.id, soft: false)
            },
            purgesOwner: AttachmentOwnerKey(kind: .todo, id: item.id),
            filesToRemove: attachments.filter { $0.ownerKey == AttachmentOwnerKey(kind: .todo, id: item.id) }.map(\.id)
        )
    }

    static func diary(_ item: DiaryEntry, attachments: [AttachmentItem], tags: @escaping () -> [TagItem], locale: Locale) -> TrashRow? {
        guard let deletedAt = item.deletedAt else { return nil }
        return TrashRow(
            id: item.id,
            title: "",
            kindLabel: "trash.kind.diary",
            isResident: false,
            deletedAt: deletedAt,
            restore: { _ = DayBoardMutations.restoreDiary(item) },
            purge: { DayBoardMutations.purgeDiary(item) },
            removeFromStore: { context in
                try DayBoardMutations.diaryRepo(for: context).deleteDiary(id: item.id, soft: false)
            },
            purgesOwner: AttachmentOwnerKey(kind: .diary, id: item.id),
            titleProvider: { DiaryPrivacy.displayText(item.snapshot, tags: tags(), locale: locale) },
            filesToRemove: attachments.filter { $0.ownerKey == AttachmentOwnerKey(kind: .diary, id: item.id) }.map(\.id)
        )
    }

    static func project(_ item: ProjectItem) -> TrashRow? {
        guard let deletedAt = item.deletedAt else { return nil }
        return TrashRow(
            id: item.id,
            title: item.name,
            kindLabel: "trash.kind.project",
            isResident: false,
            deletedAt: deletedAt,
            restore: { _ = DayBoardMutations.restoreProject(item) },
            purge: { DayBoardMutations.purgeProject(item) },
            removeFromStore: { context in
                try DayBoardMutations.catalogRepo(for: context).deleteProject(id: item.id, soft: false)
            }
        )
    }

    static func tag(_ item: TagItem) -> TrashRow? {
        guard let deletedAt = item.deletedAt else { return nil }
        return TrashRow(
            id: item.id,
            title: item.name,
            kindLabel: "trash.kind.tag",
            isResident: false,
            deletedAt: deletedAt,
            restore: { _ = DayBoardMutations.restoreTag(item) },
            purge: { DayBoardMutations.purgeTag(item) },
            removeFromStore: { context in
                try DayBoardMutations.catalogRepo(for: context).deleteTag(id: item.id, soft: false)
            }
        )
    }

    static func attachment(_ item: AttachmentItem, ownerDeleted: Bool, titleProvider: (() -> String)? = nil) -> TrashRow? {
        guard let deletedAt = item.deletedAt else { return nil }
        return TrashRow(
            id: item.id,
            title: item.filename,
            kindLabel: "trash.kind.attachment",
            isResident: false,
            deletedAt: deletedAt,
            restore: {
                guard !ownerDeleted else { return }
                _ = DayBoardMutations.restoreAttachment(item)
            },
            purge: {
                guard let context = item.modelContext else { return false }
                return ModelChanges.attempt(in: context) {
                    try AttachmentCleanup.purge(ids: [item.id], context: context)
                }
            },
            removeFromStore: { _ in
                // 文件成功删除后由 AttachmentCleanup 移除元数据，失败则留在回收站供重试。
            },
            skipIfOwnerPurged: item.ownerKey,
            canRestore: !ownerDeleted,
            titleProvider: titleProvider,
            filesToRemove: [item.id]
        )
    }
}
