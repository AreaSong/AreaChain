import SwiftData
import SwiftUI

struct BoardFilterBar: View {
    @Environment(\.daybookViewStyle) private var style
    @Environment(\.locale) private var locale

    var filter: BoardFilter
    var projects: [CatalogChoice]
    var tags: [CatalogChoice]
    var bundleIDs: [String]
    var projectCounts: [UUID: Int] = [:]
    var tagCounts: [UUID: Int] = [:]
    var unclassifiedCount: Int? = nil
    var untaggedCount: Int? = nil
    var totalOpenCount: Int? = nil
    var onChange: (BoardFilter) -> Void

    @State private var activeDropdown: ActiveDropdown? = nil

    private enum ActiveDropdown: Hashable {
        case project, tag, bundle
    }

    var isVisible: Bool {
        filter.isActive || !projects.isEmpty || !tags.isEmpty || !bundleIDs.isEmpty
    }

    var body: some View {
        if isVisible {
            HStack(spacing: 6) {
                if filter.isActive {
                    Button("filter.all") { onChange(BoardFilter()) }
                        .buttonStyle(DaybookQuietButtonStyle())
                }
                if !projects.isEmpty {
                    projectDropdown
                }
                if !tags.isEmpty {
                    tagDropdown
                }
                if !bundleIDs.isEmpty {
                    bundleDropdown
                }
            }
            .font(.system(size: 11))
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    // MARK: - 项目筛选下拉

    private var projectDropdown: some View {
        choiceDropdown(
            BoardFilterChoices.projects(
                filter: filter,
                rows: projects.map { BoardFilterChoices.NamedRow(id: $0.id, name: $0.name) },
                counts: projectCounts,
                unclassifiedCount: unclassifiedCount,
                locale: locale
            ),
            icon: "folder",
            title: projectTitle,
            active: filter.projectID != nil,
            kind: .project,
            reset: { onChange(filter.withProject(nil)) }
        )
    }

    // MARK: - 标签筛选下拉

    private var tagDropdown: some View {
        choiceDropdown(
            BoardFilterChoices.tags(
                filter: filter,
                rows: tags.map { BoardFilterChoices.NamedRow(id: $0.id, name: $0.name) },
                counts: tagCounts,
                untaggedCount: untaggedCount,
                includeNone: true,
                locale: locale
            ),
            icon: "tag",
            title: tagTitle,
            active: filter.tagID != nil,
            kind: .tag,
            reset: { onChange(filter.withTag(nil)) }
        )
    }

    // MARK: - 来源应用筛选下拉

    private var bundleDropdown: some View {
        choiceDropdown(
            BoardFilterChoices.bundles(filter: filter, bundleIDs: bundleIDs, locale: locale),
            icon: "app",
            title: appTitle,
            active: filter.bundleID != nil,
            kind: .bundle,
            reset: { onChange(filter.withBundle(nil)) }
        )
    }

    private func choiceDropdown(
        _ choices: [BoardFilterChoice],
        icon: String,
        title: String,
        active: Bool,
        kind: ActiveDropdown,
        reset: @escaping () -> Void
    ) -> some View {
        let isExpanded = Binding(
            get: { activeDropdown == kind },
            set: { activeDropdown = $0 ? kind : nil }
        )
        let options = choices.map { choice in
            FilterDropdownOption(
                id: choice.id,
                title: choice.title,
                icon: icon,
                count: choice.count,
                isSelected: choice.isSelected,
                action: { onChange(choice.applied) }
            )
        }
        return BoardFilterDropdownButton(
            icon: icon,
            title: title,
            active: active,
            isExpanded: isExpanded,
            reset: reset,
            allOption: options.first { $0.id == "all" },
            items: options.filter { $0.id != "all" },
            style: style
        )
    }

    private var projectTitle: String {
        if filter.isNoProject {
            return L10n.string("filter.project.none", locale: locale)
        }
        if let id = filter.projectID, let name = projects.first(where: { $0.id == id })?.name {
            return name
        }
        return L10n.string("filter.project", locale: locale)
    }

    private var tagTitle: String {
        if filter.isNoTag {
            return L10n.string("filter.tag.none", locale: locale)
        }
        if let id = filter.tagID, let name = tags.first(where: { $0.id == id })?.name {
            return "#" + name
        }
        return L10n.string("filter.tag", locale: locale)
    }

    private var appTitle: String {
        if let bundleID = filter.bundleID {
            return BundleDisplay.name(for: bundleID)
        }
        return L10n.string("filter.app", locale: locale)
    }
}

// MARK: - 辅助模型与气泡条目视图

struct FilterDropdownOption: Identifiable {
    var id: String
    var title: String
    var icon: String? = nil
    var count: Int? = nil
    var isSelected: Bool
    var action: () -> Void
}

struct BoardFilterDropdownButton: View {
    var icon: String
    var title: String
    var active: Bool
    var isExpanded: Binding<Bool>
    var reset: (() -> Void)? = nil
    var allOption: FilterDropdownOption?
    var items: [FilterDropdownOption]
    var style: DaybookViewStyle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if style.isWorkspace {
                workspaceCapsule
            } else {
                standardCapsule
            }
        }
        .popover(isPresented: isExpanded, arrowEdge: .bottom) {
            dropdownPopoverContent
        }
    }

    // MARK: - 菜单栏小窗胶囊样式

    private var standardCapsule: some View {
        HStack(spacing: 3) {
            Button {
                isExpanded.wrappedValue.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(active ? DaybookTheme.stamp : DaybookTheme.muted)
                    Text(title)
                        .font(.system(size: 11, weight: active ? .semibold : .regular))
                        .foregroundStyle(active ? DaybookTheme.stamp : DaybookTheme.ink)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if active, let reset {
                Button(action: reset) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(DaybookTheme.stamp)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("footer.filter.clear")
                .accessibilityLabel("footer.filter.clear")
            } else {
                Button {
                    isExpanded.wrappedValue.toggle()
                } label: {
                    Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(active ? DaybookTheme.stamp.opacity(0.8) : DaybookTheme.muted.opacity(0.6))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Capsule().fill(active ? DaybookTheme.stamp.opacity(0.12) : DaybookTheme.ink.opacity(0.05)))
        .overlay(Capsule().stroke(active ? DaybookTheme.stamp.opacity(0.35) : DaybookTheme.rule.opacity(0.5), lineWidth: 0.8))
        .contentShape(Capsule())
    }

    // MARK: - 工作台窗口胶囊样式

    private var workspaceCapsule: some View {
        HStack(spacing: 4) {
            Button {
                isExpanded.wrappedValue.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                    Text(title).lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if active, let reset {
                Button(action: reset) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(DaybookTheme.stamp)
                        .padding(.horizontal, 2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("footer.filter.clear")
                .accessibilityLabel("footer.filter.clear")
            } else {
                Button {
                    isExpanded.wrappedValue.toggle()
                } label: {
                    Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .medium))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .workspaceFilterChrome(isSelected: active)
    }

    // MARK: - 手账风下拉气泡内容

    private var dropdownPopoverContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let allOption {
                FilterDropdownItemRow(item: allOption) {
                    allOption.action()
                    isExpanded.wrappedValue = false
                }
                Divider()
                    .background(DaybookTheme.rule.opacity(0.35))
                    .padding(.vertical, 2)
                    .padding(.horizontal, 2)
            }

            if !items.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(items) { item in
                            FilterDropdownItemRow(item: item) {
                                item.action()
                                isExpanded.wrappedValue = false
                            }
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
        .padding(6)
        .frame(minWidth: 140)
        .background(DaybookTheme.paper)
    }
}

// MARK: - 单个条目行

struct FilterDropdownItemRow: View {
    var item: FilterDropdownOption
    var onSelect: () -> Void

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 5) {
                if item.isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(DaybookTheme.stamp)
                        .frame(width: 10)
                } else {
                    Spacer()
                        .frame(width: 10)
                }

                if let icon = item.icon {
                    Image(systemName: icon)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(item.isSelected ? DaybookTheme.stamp : DaybookTheme.muted)
                }

                Text(item.title)
                    .font(DaybookType.caption)
                    .foregroundStyle(item.isSelected ? DaybookTheme.stamp : DaybookTheme.ink)
                    .lineLimit(1)

                Spacer(minLength: 6)

                if let count = item.count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 0.5)
                        .background(item.isSelected ? DaybookTheme.stamp.opacity(0.20) : DaybookTheme.ink.opacity(0.06))
                        .foregroundStyle(item.isSelected ? DaybookTheme.stamp : DaybookTheme.muted)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .fill(isHovered ? DaybookTheme.hoverFill : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(DaybookMotion.interactive(reduceMotion), value: isHovered)
    }
}
