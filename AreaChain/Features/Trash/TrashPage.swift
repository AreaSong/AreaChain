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
        let catalog = projects.compactMap { TrashRow.project($0, todos: todos, routines: routines, projects: projects) }
            + tags.compactMap { TrashRow.tag($0, todos: todos, routines: routines, diaries: diaries) }
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
                .buttonStyle(DaybookQuietButtonStyle(destructive: true))
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
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(items) { item in
                    trashCard(item)
                }
            }
        }
        .daybookScroll()
    }

    private func trashCard(_ item: TrashRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if item.isResident {
                    Image(systemName: "repeat")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DaybookTheme.stamp)
                }
                Text(item.kindLabel)
                    .font(DaybookType.badge.weight(.semibold))
                    .foregroundStyle(DaybookTheme.muted)
                Spacer()
                Text(ClockLabel.created(item.deletedAt, locale: locale))
                    .font(.system(size: 10))
                    .foregroundStyle(DaybookTheme.muted)
            }
                Text(item.displayTitle)
                .font(DaybookType.body)
                .foregroundStyle(DaybookTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Button("trash.restore") { restore(item) }
                    .buttonStyle(DaybookQuietButtonStyle(prominent: true))
                    .disabled(!item.canRestore)
                    .help(item.canRestore ? "trash.restore" : "trash.restore.blocked")
                Button("trash.purge", role: .destructive) {
                    pendingPurge = PendingTrash(title: "", titleProvider: { item.displayTitle }) { purge(item) }
                }
                .buttonStyle(DaybookQuietButtonStyle(destructive: true))
            }
            .font(DaybookType.caption)
        }
        .padding(.vertical, 4)
    }

    private func restore(_ item: TrashRow) {
        ModelChanges.perform(in: modelContext) { item.restore() }
    }

    private func purge(_ item: TrashRow) {
        guard ModelChanges.perform(in: modelContext, { item.removeFromStore(modelContext) }) else { return }
        if let owner = item.purgesOwner { EditDrafts.shared.discard(owner: owner) }
        ModelChanges.attempt { try AttachmentStore.removeFiles(item.filesToRemove) }
    }

    private func emptyTrash() {
        let rows = items
        let purgedOwners = Set(rows.compactMap(\.purgesOwner))
        guard ModelChanges.perform(in: modelContext, {
            for item in rows {
                if let owner = item.skipIfOwnerPurged, purgedOwners.contains(owner) { continue }
                item.removeFromStore(modelContext)
            }
        }) else { return }
        for owner in purgedOwners { EditDrafts.shared.discard(owner: owner) }
        ModelChanges.attempt { try AttachmentStore.removeFiles(Array(Set(rows.flatMap(\.filesToRemove)))) }
    }
}

struct TrashRow: Identifiable {
    var id: UUID
    var title: String
    var kindLabel: LocalizedStringKey
    var isResident: Bool
    var deletedAt: Date
    var restore: () -> Void
    var removeFromStore: (ModelContext) -> Void
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
            restore: {
                let stamp = item.deletedAt
                item.deletedAt = nil
                SoftDelete.restoreCascadedAttachments(
                    ownerID: item.id,
                    parentDeletedAt: stamp,
                    attachments: attachments
                )
            },
            removeFromStore: { context in
                for attachment in attachments where attachment.ownerKey == AttachmentOwnerKey(kind: .routine, id: item.id) {
                    context.delete(attachment)
                }
                context.delete(item)
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
            restore: {
                let stamp = item.deletedAt
                item.deletedAt = nil
                SoftDelete.restoreCascadedSubtasks(parentDeletedAt: stamp, subtasks: item.subtasks)
                SoftDelete.restoreCascadedAttachments(
                    ownerID: item.id,
                    parentDeletedAt: stamp,
                    attachments: attachments
                )
            },
            removeFromStore: { context in
                for attachment in attachments where attachment.ownerKey == AttachmentOwnerKey(kind: .todo, id: item.id) {
                    context.delete(attachment)
                }
                for sub in item.subtasks {
                    context.delete(sub)
                }
                context.delete(item)
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
            restore: {
                let stamp = item.deletedAt
                item.deletedAt = nil
                SoftDelete.restoreCascadedAttachments(
                    ownerID: item.id,
                    parentDeletedAt: stamp,
                    attachments: attachments
                )
            },
            removeFromStore: { context in
                for attachment in attachments where attachment.ownerKey == AttachmentOwnerKey(kind: .diary, id: item.id) {
                    context.delete(attachment)
                }
                context.delete(item)
            },
            purgesOwner: AttachmentOwnerKey(kind: .diary, id: item.id),
            titleProvider: { DiaryPrivacy.displayText(item.snapshot, tags: tags(), locale: locale) },
            filesToRemove: attachments.filter { $0.ownerKey == AttachmentOwnerKey(kind: .diary, id: item.id) }.map(\.id)
        )
    }

    static func project(
        _ item: ProjectItem,
        todos: [TodoItem],
        routines: [DailyRoutine],
        projects: [ProjectItem]
    ) -> TrashRow? {
        guard let deletedAt = item.deletedAt else { return nil }
        return TrashRow(
            id: item.id,
            title: item.name,
            kindLabel: "trash.kind.project",
            isResident: false,
            deletedAt: deletedAt,
            restore: { item.deletedAt = nil },
            removeFromStore: { context in
                Catalog.unlinkProject(item.id, todos: todos, routines: routines, projects: projects)
                context.delete(item)
            }
        )
    }

    static func tag(
        _ item: TagItem,
        todos: [TodoItem],
        routines: [DailyRoutine],
        diaries: [DiaryEntry]
    ) -> TrashRow? {
        guard let deletedAt = item.deletedAt else { return nil }
        return TrashRow(
            id: item.id,
            title: item.name,
            kindLabel: "trash.kind.tag",
            isResident: false,
            deletedAt: deletedAt,
            restore: { item.deletedAt = nil },
            removeFromStore: { context in
                Catalog.unlinkTag(item.id, todos: todos, routines: routines, diaries: diaries)
                context.delete(item)
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
                item.deletedAt = nil
            },
            removeFromStore: { context in
                context.delete(item)
            },
            skipIfOwnerPurged: item.ownerKey,
            canRestore: !ownerDeleted,
            titleProvider: titleProvider,
            filesToRemove: [item.id]
        )
    }
}
