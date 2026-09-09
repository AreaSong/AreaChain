import SwiftData
import SwiftUI

struct AttachmentBrowserPage: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var attachments: [AttachmentItem]
    @Query private var todos: [TodoItem]
    @Query private var diaries: [DiaryEntry]
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @State private var preview: AttachmentRef?
    @State private var pendingTrash: PendingTrash?

    var body: some View {
        DaybookPage(
            title: "window.attachments",
            subtitle: "attachments.hint",
            minWidth: 440,
            minHeight: 480
        ) {
            if clusters.isEmpty {
                DaybookEmptyState(title: "attachments.empty", systemImage: "photo")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(clusters) { cluster in
                            clusterBlock(cluster)
                        }
                    }
                }
                .daybookScroll()
            }
        }
        .confirmMoveToTrash($pendingTrash)
        .popover(item: $preview) { item in
            previewBody(item)
        }
    }

    private var clusters: [AttachmentCluster] {
        let liveOwners = Set(todos.compactMap { $0.deletedAt == nil ? $0.id : nil })
            .union(routines.compactMap { $0.deletedAt == nil ? $0.id : nil })
            .union(diaries.compactMap { $0.deletedAt == nil ? $0.id : nil })
        return AttachmentClusters.grouped(attachments, liveOwnerIDs: liveOwners)
    }

    private func clusterBlock(_ cluster: AttachmentCluster) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ownerTitle(cluster))
                .font(DaybookType.subtitle.weight(.semibold))
                .foregroundStyle(DaybookTheme.ink)
            Text(kindLabel(cluster.kind))
                .font(.system(size: 10))
                .foregroundStyle(DaybookTheme.muted)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                ForEach(cluster.items) { item in
                    thumb(item)
                }
            }
        }
    }

    private func thumb(_ item: AttachmentRef) -> some View {
        Button {
            preview = item
        } label: {
            VStack(spacing: 4) {
                thumbImage(item)
                Text(item.filename)
                    .font(.system(size: 10))
                    .foregroundStyle(DaybookTheme.muted)
                    .lineLimit(1)
            }
        }
        .buttonStyle(DaybookQuietButtonStyle())
        .accessibilityLabel(item.filename)
        .help(item.filename)
        .contextMenu {
            Button("attachments.delete", role: .destructive) {
                pendingTrash = PendingTrash(title: item.filename) {
                    trash(item.id)
                }
            }
        }
    }

    @ViewBuilder
    private func thumbImage(_ item: AttachmentRef) -> some View {
        if let image = AttachmentStore.image(id: item.id) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            Image(systemName: "photo")
                .font(.system(size: 18))
                .foregroundStyle(DaybookTheme.muted)
                .frame(width: 72, height: 72)
        }
    }

    @ViewBuilder
    private func previewBody(_ item: AttachmentRef) -> some View {
        if let image = AttachmentStore.image(id: item.id) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 420, maxHeight: 420)
                .padding(8)
        } else {
            Text(item.filename)
                .font(.system(size: 12))
                .foregroundStyle(DaybookTheme.muted)
                .padding(12)
        }
    }

    private func ownerTitle(_ cluster: AttachmentCluster) -> String {
        switch cluster.kind {
        case .todo:
            return todos.first { $0.id == cluster.ownerID }?.title ?? cluster.items.first?.filename ?? ""
        case .diary:
            return diaries.first { $0.id == cluster.ownerID }?.text ?? cluster.items.first?.filename ?? ""
        case .routine:
            return routines.first { $0.id == cluster.ownerID }?.title ?? cluster.items.first?.filename ?? ""
        }
    }

    private func kindLabel(_ kind: AttachmentOwner) -> LocalizedStringKey {
        switch kind {
        case .todo: "attachments.owner.todo"
        case .diary: "attachments.owner.diary"
        case .routine: "attachments.owner.routine"
        }
    }

    private func trash(_ id: UUID) {
        guard let item = attachments.first(where: { $0.id == id }) else { return }
        AttachmentActions.trash(item)
    }
}
