import SwiftData
import SwiftUI

/// 菜单栏小窗纵向筛选气泡面板：结构化清晰展示全部、高优、项目与标签，支持即选即走。
struct MenuBarFilterPopover: View {
    var tab: BoardTab = .tasks
    var filter: Binding<BoardFilter>? = nil
    var diaryFilterTagID: Binding<UUID?>? = nil
    var projects: [ProjectItem] = []
    var projectCounts: [UUID: Int] = [:]
    var unclassifiedCount: Int? = nil
    var tags: [TagItem] = []
    var tagCounts: [UUID: Int] = [:]
    var onDismiss: () -> Void

    @Environment(\.locale) private var locale

    private var activeFilter: BoardFilter {
        filter?.wrappedValue ?? BoardFilter()
    }

    private var selectedTagID: UUID? {
        tab == .tasks ? activeFilter.tagID : diaryFilterTagID?.wrappedValue
    }

    private var isHighPriority: Bool {
        tab == .tasks && activeFilter.isHighPriorityOnly
    }

    private var isAllSelected: Bool {
        if tab == .tasks {
            return !activeFilter.isActive
        }
        return diaryFilterTagID?.wrappedValue == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            allResetRow

            Divider()
                .background(DaybookTheme.rule.opacity(0.35))
                .padding(.vertical, 2)
                .padding(.horizontal, 2)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if tab == .tasks {
                        prioritySection
                        if !projects.isEmpty {
                            projectSection
                        }
                    }

                    if !tags.isEmpty {
                        tagSection
                    }
                }
            }
            .frame(maxHeight: 280)
        }
        .padding(6)
        .frame(minWidth: 180, maxWidth: 220)
        .background(DaybookTheme.paper)
    }

    // MARK: - 全部重置项

    private var allResetRow: some View {
        FilterDropdownItemRow(
            item: FilterDropdownOption(
                id: "all",
                title: L10n.string("filter.all", locale: locale),
                icon: "line.3.horizontal.decrease.circle",
                count: nil,
                isSelected: isAllSelected,
                action: {
                    if tab == .tasks {
                        filter?.wrappedValue = BoardFilter()
                    } else {
                        diaryFilterTagID?.wrappedValue = nil
                    }
                    onDismiss()
                }
            )
        ) {
            if tab == .tasks {
                filter?.wrappedValue = BoardFilter()
            } else {
                diaryFilterTagID?.wrappedValue = nil
            }
            onDismiss()
        }
    }

    // MARK: - 优先级区块

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 1) {
            FilterDropdownItemRow(
                item: FilterDropdownOption(
                    id: "priority",
                    title: L10n.string("filter.highPriority", locale: locale),
                    icon: "exclamationmark.3",
                    count: nil,
                    isSelected: isHighPriority,
                    action: {
                        filter?.wrappedValue = activeFilter.withHighPriority(!isHighPriority)
                        onDismiss()
                    }
                )
            ) {
                filter?.wrappedValue = activeFilter.withHighPriority(!isHighPriority)
                onDismiss()
            }
        }
    }

    // MARK: - 项目分组

    private var projectSection: some View {
        VStack(alignment: .leading, spacing: 1) {
            sectionHeader(L10n.string("filter.project", locale: locale))

            // 无项目选项
            FilterDropdownItemRow(
                item: FilterDropdownOption(
                    id: BoardFilter.noneID.uuidString,
                    title: L10n.string("filter.project.none", locale: locale),
                    icon: "folder",
                    count: unclassifiedCount,
                    isSelected: activeFilter.isNoProject,
                    action: {
                        filter?.wrappedValue = activeFilter.withProject(BoardFilter.noneID)
                        onDismiss()
                    }
                )
            ) {
                filter?.wrappedValue = activeFilter.withProject(BoardFilter.noneID)
                onDismiss()
            }

            // 各具体项目
            ForEach(projects.filter { $0.deletedAt == nil }) { proj in
                FilterDropdownItemRow(
                    item: FilterDropdownOption(
                        id: proj.id.uuidString,
                        title: proj.name,
                        icon: "folder",
                        count: projectCounts[proj.id],
                        isSelected: activeFilter.projectID == proj.id,
                        action: {
                            filter?.wrappedValue = activeFilter.withProject(proj.id)
                            onDismiss()
                        }
                    )
                ) {
                    filter?.wrappedValue = activeFilter.withProject(proj.id)
                    onDismiss()
                }
            }
        }
        .padding(.top, 3)
    }

    // MARK: - 标签分组

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 1) {
            sectionHeader(L10n.string("filter.tag", locale: locale))

            ForEach(tags.filter { $0.deletedAt == nil }) { tag in
                FilterDropdownItemRow(
                    item: FilterDropdownOption(
                        id: tag.id.uuidString,
                        title: tag.name,
                        icon: "tag",
                        count: tagCounts[tag.id],
                        isSelected: selectedTagID == tag.id,
                        action: {
                            if tab == .tasks {
                                filter?.wrappedValue = activeFilter.withTag(tag.id)
                            } else {
                                diaryFilterTagID?.wrappedValue = tag.id
                            }
                            onDismiss()
                        }
                    )
                ) {
                    if tab == .tasks {
                        filter?.wrappedValue = activeFilter.withTag(tag.id)
                    } else {
                        diaryFilterTagID?.wrappedValue = tag.id
                    }
                    onDismiss()
                }
            }
        }
        .padding(.top, 3)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9.5, weight: .bold))
            .foregroundStyle(DaybookTheme.muted.opacity(0.8))
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .padding(.bottom, 1)
    }
}
