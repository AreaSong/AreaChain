import SwiftData
import SwiftUI

struct CatalogSettings: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProjectItem.sortOrder) private var projects: [ProjectItem]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @State private var projectDraft = ""
    @State private var tagDraft = ""

    @State private var pendingTrash: PendingTrash?

    var body: some View {
        Section {
            projectTree
            catalogBlock(
                title: "settings.catalog.tags",
                items: Catalog.liveTags(tags).map { ($0.id, $0.name) },
                draft: $tagDraft,
                placeholder: "settings.catalog.add.tag",
                onAdd: addTag,
                onRename: renameTag,
                onDelete: deleteTag
            )
        } header: {
            Text("settings.catalog")
        } footer: {
            Text("settings.catalog.hint")
        }
        .confirmMoveToTrash($pendingTrash)
    }

    private func catalogBlock(
        title: LocalizedStringKey,
        items: [(id: UUID, name: String)],
        draft: Binding<String>,
        placeholder: LocalizedStringKey,
        onAdd: @escaping () -> Void,
        onRename: @escaping (UUID, String) -> Void,
        onDelete: @escaping (UUID) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.muted)
            if items.isEmpty {
                Text("settings.catalog.empty")
                    .font(.system(size: 12))
                    .foregroundStyle(DaybookTheme.muted)
            }
            ForEach(items, id: \.id) { item in
                CatalogNameRow(
                    name: item.name,
                    onRename: { onRename(item.id, $0) },
                    onDelete: {
                        pendingTrash = PendingTrash(title: item.name) { onDelete(item.id) }
                    }
                )
            }
            HStack {
                TextField(placeholder, text: draft)
                    .onSubmit(onAdd)
                ComposerAddButton(
                    enabled: !draft.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    action: onAdd
                )
            }
        }
        .padding(.vertical, 2)
    }

    private var projectTree: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("settings.catalog.projects")
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.muted)
            if ProjectTree.outline(projects).isEmpty {
                Text("settings.catalog.empty")
                    .font(.system(size: 12))
                    .foregroundStyle(DaybookTheme.muted)
            }
            ForEach(ProjectTree.outline(projects)) { row in
                HStack(spacing: 6) {
                    CatalogNameRow(
                        name: row.name,
                        onRename: { renameProject(row.id, $0) },
                        onDelete: {
                            pendingTrash = PendingTrash(title: row.name) { deleteProject(row.id) }
                        }
                    )
                    parentMenu(for: row)
                }
                .padding(.leading, CGFloat(row.depth) * 14)
            }
            HStack {
                TextField("settings.catalog.add.project", text: $projectDraft)
                    .onSubmit(addProject)
                ComposerAddButton(
                    enabled: !projectDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    action: addProject
                )
            }
        }
        .padding(.vertical, 2)
    }

    private func parentMenu(for row: ProjectOutlineRow) -> some View {
        Menu {
            Button("settings.catalog.parent.none") { setParent(row.id, nil) }
            ForEach(ProjectTree.allowedParents(for: row.id, in: projects)) { parent in
                Button(ProjectTree.pathLabel(parent.id, in: projects)) {
                    setParent(row.id, parent.id)
                }
            }
        } label: {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 10))
                .foregroundStyle(DaybookTheme.muted)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("settings.catalog.parent")
    }

    private func addProject() {
        let name = projectDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        modelContext.insert(
            ProjectItem(name: name, sortOrder: Catalog.nextSortOrder(projects.map(\.sortOrder)))
        )
        projectDraft = ""
        BoardEvents.changed()
    }

    private func addTag() {
        let name = tagDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        _ = DayBoardMutations.resolveTag(named: name, among: tags, context: modelContext)
        tagDraft = ""
        BoardEvents.changed()
    }

    private func renameProject(_ id: UUID, _ name: String) {
        projects.first { $0.id == id }?.name = name
        BoardEvents.changed()
    }

    private func renameTag(_ id: UUID, _ name: String) {
        tags.first { $0.id == id }?.name = name
        BoardEvents.changed()
    }

    private func deleteProject(_ id: UUID) {
        projects.first { $0.id == id }?.deletedAt = SoftDelete.stamp()
        BoardEvents.changed()
    }

    private func deleteTag(_ id: UUID) {
        tags.first { $0.id == id }?.deletedAt = SoftDelete.stamp()
        BoardEvents.changed()
    }

    private func setParent(_ id: UUID, _ parentID: UUID?) {
        guard let item = projects.first(where: { $0.id == id }) else { return }
        guard !ProjectTree.wouldCycle(moving: id, to: parentID, in: projects) else { return }
        item.parentID = parentID
        BoardEvents.changed()
    }
}

private struct CatalogNameRow: View {
    var name: String
    var onRename: (String) -> Void
    var onDelete: () -> Void
    @State private var draft = ""

    var body: some View {
        HStack {
            TextField("settings.catalog.rename", text: $draft)
                .onSubmit(save)
            RowIconButton(systemName: "trash", label: "row.delete", role: .destructive, action: onDelete)
        }
        .onAppear { draft = name }
        .onChange(of: name) { _, value in
            if draft != value { draft = value }
        }
    }

    private func save() {
        let next = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if next.isEmpty {
            draft = name
            return
        }
        onRename(next)
    }
}
