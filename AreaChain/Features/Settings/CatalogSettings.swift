import SwiftData
import SwiftUI

struct CatalogSettings: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProjectItem.sortOrder) private var projects: [ProjectItem]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @State private var projectDraft = ""
    @State private var tagDraft = ""

    var body: some View {
        Section {
            catalogBlock(
                title: "settings.catalog.projects",
                items: Catalog.liveProjects(projects).map { ($0.id, $0.name) },
                draft: $projectDraft,
                placeholder: "settings.catalog.add.project",
                onAdd: addProject,
                onRename: renameProject,
                onDelete: deleteProject
            )
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
                    onDelete: { onDelete(item.id) }
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
        modelContext.insert(
            TagItem(name: name, sortOrder: Catalog.nextSortOrder(tags.map(\.sortOrder)))
        )
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
        projects.first { $0.id == id }?.deletedAt = .now
        BoardEvents.changed()
    }

    private func deleteTag(_ id: UUID) {
        tags.first { $0.id == id }?.deletedAt = .now
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
