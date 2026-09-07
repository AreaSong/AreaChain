import SwiftData
import SwiftUI

struct TrashPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query(sort: \DiaryEntry.createdAt, order: .reverse) private var diaries: [DiaryEntry]

    @State private var pendingPurge: PendingTrash?
    @State private var confirmEmpty = false

    private var items: [TrashRow] {
        let standing = routines.compactMap(TrashRow.resident)
        let tasks = todos.compactMap(TrashRow.todo)
        let notes = diaries.compactMap(TrashRow.diary)
        return (standing + tasks + notes).sorted { $0.deletedAt > $1.deletedAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if items.isEmpty {
                Text("trash.empty")
                    .font(.system(size: 12))
                    .foregroundStyle(DaybookTheme.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                list
            }
        }
        .padding(16)
        .frame(minWidth: 360, minHeight: 420)
        .background(DaybookTheme.paper.opacity(0.94))
        .confirmPurge($pendingPurge)
    }

    private var header: some View {
        HStack {
            Text("trash.hint")
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.muted)
            Spacer()
            Button("trash.empty.action") { confirmEmpty = true }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(items.isEmpty ? DaybookTheme.muted : .red.opacity(0.8))
                .disabled(items.isEmpty)
                .confirmationDialog("alert.purge.all.title", isPresented: $confirmEmpty, titleVisibility: .visible) {
                    Button("alert.purge.all", role: .destructive, action: emptyTrash)
                    Button("alert.cancel", role: .cancel) {}
                } message: {
                    Text("alert.purge.all.message")
                }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(items) { item in
                    trashCard(item)
                }
            }
        }
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
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DaybookTheme.muted)
                Spacer()
                Text(ClockLabel.created(item.deletedAt, locale: locale))
                    .font(.system(size: 10))
                    .foregroundStyle(DaybookTheme.muted)
            }
            Text(item.title)
                .font(.system(size: 13))
                .foregroundStyle(DaybookTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Button("trash.restore") { restore(item) }
                Button("trash.purge", role: .destructive) {
                    pendingPurge = PendingTrash(title: item.title) { purge(item) }
                }
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func restore(_ item: TrashRow) {
        item.restore()
        BoardEvents.changed()
    }

    private func purge(_ item: TrashRow) {
        item.removeFromStore(modelContext)
        BoardEvents.changed()
    }

    private func emptyTrash() {
        for item in items {
            item.removeFromStore(modelContext)
        }
        BoardEvents.changed()
    }
}

private struct TrashRow: Identifiable {
    var id: UUID
    var title: String
    var kindLabel: LocalizedStringKey
    var isResident: Bool
    var deletedAt: Date
    var restore: () -> Void
    var removeFromStore: (ModelContext) -> Void

    static func resident(_ item: DailyRoutine) -> TrashRow? {
        guard let deletedAt = item.deletedAt else { return nil }
        return TrashRow(
            id: item.id,
            title: item.title,
            kindLabel: "trash.kind.resident",
            isResident: true,
            deletedAt: deletedAt,
            restore: { item.deletedAt = nil },
            removeFromStore: { $0.delete(item) }
        )
    }

    static func todo(_ item: TodoItem) -> TrashRow? {
        guard let deletedAt = item.deletedAt else { return nil }
        return TrashRow(
            id: item.id,
            title: item.title,
            kindLabel: "trash.kind.todo",
            isResident: false,
            deletedAt: deletedAt,
            restore: { item.deletedAt = nil },
            removeFromStore: { $0.delete(item) }
        )
    }

    static func diary(_ item: DiaryEntry) -> TrashRow? {
        guard let deletedAt = item.deletedAt else { return nil }
        return TrashRow(
            id: item.id,
            title: item.text,
            kindLabel: "trash.kind.diary",
            isResident: false,
            deletedAt: deletedAt,
            restore: { item.deletedAt = nil },
            removeFromStore: { $0.delete(item) }
        )
    }
}
