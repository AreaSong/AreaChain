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
            HStack(spacing: 8) {
                if !projects.isEmpty {
                    filterMenu(
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
        title: LocalizedStringKey,
        active: Bool,
        reset: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            Button("filter.all", action: reset)
            content()
        } label: {
            Text(title)
                .fontWeight(active ? .semibold : .regular)
                .foregroundStyle(active ? DaybookTheme.stamp : DaybookTheme.muted)
                .lineLimit(1)
                .help(title)
        }
        .menuIndicator(.hidden)
        .buttonStyle(DaybookQuietButtonStyle(prominent: active))
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }
}