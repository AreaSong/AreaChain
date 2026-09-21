import SwiftData
import SwiftUI

extension FooterBar {
    var footerProjectDropdown: some View {
        FooterProjectDropdownView(
            filter: filter,
            projects: projects,
            projectCounts: projectCounts,
            unclassifiedCount: unclassifiedCount
        )
    }
}

struct FooterProjectDropdownView: View {
    var filter: Binding<BoardFilter>?
    var projects: [ProjectItem]
    var projectCounts: [UUID: Int]
    var unclassifiedCount: Int?

    @Environment(\.locale) private var locale
    @State private var isExpanded = false

    private var selectedProjectID: UUID? {
        filter?.wrappedValue.projectID
    }

    private var isProjectSelected: Bool {
        selectedProjectID != nil
    }

    private var projectTitle: String {
        if let pid = selectedProjectID {
            if pid == BoardFilter.noneID {
                return L10n.string("filter.project.none", locale: locale)
            }
            return projects.first(where: { $0.id == pid })?.name ?? L10n.string("filter.project", locale: locale)
        }
        return L10n.string("filter.project", locale: locale)
    }

    var body: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: 3.5) {
                Image(systemName: "folder")
                    .font(.system(size: 9.5, weight: .medium))
                Text(projectTitle)
                    .font(DaybookType.caption)
                    .lineLimit(1)
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(isProjectSelected ? DaybookTheme.stamp.opacity(0.8) : DaybookTheme.muted.opacity(0.6))
            }
            .fixedSize()
            .padding(.horizontal, 8)
            .frame(height: 26)
            .foregroundStyle(isProjectSelected ? DaybookTheme.stamp : DaybookTheme.ink)
            .background(Capsule().fill(isProjectSelected ? DaybookTheme.stamp.opacity(0.12) : DaybookTheme.hoverFill))
            .overlay(Capsule().strokeBorder(
                isProjectSelected ? DaybookTheme.stamp.opacity(0.45) : DaybookTheme.rule.opacity(0.6),
                lineWidth: 0.7
            ))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isExpanded, arrowEdge: .top) {
            popoverContent
        }
    }

    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            let allOption = FilterDropdownOption(
                id: "all",
                title: L10n.string("filter.all", locale: locale),
                icon: "folder",
                count: nil,
                isSelected: selectedProjectID == nil,
                action: {
                    filter?.wrappedValue = (filter?.wrappedValue ?? BoardFilter()).withProject(nil)
                    isExpanded = false
                }
            )
            FilterDropdownItemRow(item: allOption) {
                allOption.action()
            }

            Divider()
                .background(DaybookTheme.rule.opacity(0.35))
                .padding(.vertical, 2)
                .padding(.horizontal, 2)

            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    let noneOption = FilterDropdownOption(
                        id: BoardFilter.noneID.uuidString,
                        title: L10n.string("filter.project.none", locale: locale),
                        icon: "folder",
                        count: unclassifiedCount,
                        isSelected: selectedProjectID == BoardFilter.noneID,
                        action: {
                            filter?.wrappedValue = (filter?.wrappedValue ?? BoardFilter()).withProject(BoardFilter.noneID)
                            isExpanded = false
                        }
                    )
                    FilterDropdownItemRow(item: noneOption) {
                        noneOption.action()
                    }

                    ForEach(projects.filter { $0.deletedAt == nil }) { proj in
                        let item = FilterDropdownOption(
                            id: proj.id.uuidString,
                            title: proj.name,
                            icon: "folder",
                            count: projectCounts[proj.id],
                            isSelected: selectedProjectID == proj.id,
                            action: {
                                filter?.wrappedValue = (filter?.wrappedValue ?? BoardFilter()).withProject(proj.id)
                                isExpanded = false
                            }
                        )
                        FilterDropdownItemRow(item: item) {
                            item.action()
                        }
                    }
                }
            }
            .frame(maxHeight: 180)
        }
        .padding(6)
        .frame(minWidth: 140)
        .background(DaybookTheme.paper)
    }
}
