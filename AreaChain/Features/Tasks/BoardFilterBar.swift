import SwiftData
import SwiftUI

struct BoardFilterBar: View {
    var filter: BoardFilter
    var projects: [CatalogChoice]
    var tags: [CatalogChoice]
    var bundleIDs: [String]
    var onChange: (BoardFilter) -> Void

    var isVisible: Bool {
        !projects.isEmpty || !tags.isEmpty || !bundleIDs.isEmpty
    }

    var body: some View {
        if isVisible {
            HStack(spacing: 6) {
                if !projects.isEmpty {
                    filterMenu(
                        icon: "folder",
                        title: projectTitle,
                        active: filter.projectID != nil,
                        reset: { onChange(filter.withProject(nil)) }
                    ) {
                        ForEach(projects) { project in
                            Button(project.name) {
                                onChange(filter.withProject(project.id))
                            }
                        }
                    }
                }
                if !tags.isEmpty {
                    filterMenu(
                        icon: "tag",
                        title: tagTitle,
                        active: filter.tagID != nil,
                        reset: { onChange(filter.withTag(nil)) }
                    ) {
                        ForEach(tags) { tag in
                            Button(tag.name) {
                                onChange(filter.withTag(tag.id))
                            }
                        }
                    }
                }
                if !bundleIDs.isEmpty {
                    filterMenu(
                        icon: "app",
                        title: appTitle,
                        active: filter.bundleID != nil,
                        reset: { onChange(filter.withBundle(nil)) }
                    ) {
                        ForEach(bundleIDs, id: \.self) { bundleID in
                            Button(BundleDisplay.name(for: bundleID)) {
                                onChange(filter.withBundle(bundleID))
                            }
                        }
                    }
                }
            }
            .font(.system(size: 11))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var projectTitle: LocalizedStringKey {
        if let id = filter.projectID, let name = projects.first(where: { $0.id == id })?.name {
            return LocalizedStringKey(name)
        }
        return "filter.project"
    }

    private var tagTitle: LocalizedStringKey {
        if let id = filter.tagID, let name = tags.first(where: { $0.id == id })?.name {
            return LocalizedStringKey(name)
        }
        return "filter.tag"
    }

    private var appTitle: LocalizedStringKey {
        if let bundleID = filter.bundleID {
            return LocalizedStringKey(BundleDisplay.name(for: bundleID))
        }
        return "filter.app"
    }

    private func filterMenu<Content: View>(
        icon: String,
        title: LocalizedStringKey,
        active: Bool,
        reset: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            Button("filter.all", action: reset)
            content()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(active ? DaybookTheme.stamp : DaybookTheme.muted)

                Text(title)
                    .font(.system(size: 11, weight: active ? .semibold : .regular))
                    .foregroundStyle(active ? DaybookTheme.stamp : DaybookTheme.ink)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(active ? DaybookTheme.stamp.opacity(0.8) : DaybookTheme.muted.opacity(0.6))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(active ? DaybookTheme.stamp.opacity(0.12) : DaybookTheme.ink.opacity(0.05))
            )
            .overlay(
                Capsule()
                    .stroke(
                        active ? DaybookTheme.stamp.opacity(0.35) : DaybookTheme.rule.opacity(0.5),
                        lineWidth: 0.8
                    )
            )
            .contentShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .accessibilityLabel(title)
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }
}