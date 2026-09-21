import SwiftData
import SwiftUI

/// 菜单栏小窗内部手账风筛选抽屉：停靠在底栏上方，结构化展示全部、高优、项目与流式标签，支持即选即走。
struct MenuBarFilterDrawer: View {
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        VStack(spacing: 0) {
            // 1. 顶部手账胶囊拉手
            grabHandle

            // 2. 快捷操作栏（全部 / 仅高优）
            quickActionBar
                .padding(.horizontal, 10)
                .padding(.bottom, 6)

            Divider()
                .overlay(DaybookTheme.rule.opacity(0.35))
                .padding(.horizontal, 6)

            // 3. 滚动内容区（项目列表与流式标签）
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if tab == .tasks {
                        projectSection
                    }

                    if !tags.isEmpty {
                        tagSection
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 210)
        }
        .frame(width: DaybookTheme.popoverWidth - 20)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DaybookTheme.paper)
                .shadow(color: Color.black.opacity(0.14), radius: 12, x: 0, y: -3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(DaybookTheme.rule.opacity(0.65), lineWidth: 0.8)
        )
    }

    // MARK: - 顶部手柄

    private var grabHandle: some View {
        Capsule()
            .fill(DaybookTheme.rule.opacity(0.6))
            .frame(width: 28, height: 3.5)
            .padding(.top, 6)
            .padding(.bottom, 4)
    }

    // MARK: - 快捷操作栏

    private var quickActionBar: some View {
        HStack(spacing: 8) {
            // 全部待办按钮
            quickPill(
                title: L10n.string("filter.all", locale: locale),
                icon: "line.3.horizontal.decrease.circle",
                isSelected: isAllSelected
            ) {
                resetAllFilters()
                onDismiss()
            }

            if tab == .tasks {
                // 仅高优切换按钮
                quickPill(
                    title: L10n.string("filter.highPriority", locale: locale),
                    icon: "exclamationmark.3",
                    isSelected: isHighPriority
                ) {
                    filter?.wrappedValue = activeFilter.withHighPriority(!isHighPriority)
                    onDismiss()
                }
            }

            Spacer(minLength: 0)

            // 关闭按钮
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(DaybookTheme.muted)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L10n.string("common.close", locale: locale))
        }
    }

    private func quickPill(
        title: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(
                Capsule()
                    .fill(isSelected ? DaybookTheme.stamp.opacity(0.12) : DaybookTheme.hoverFill)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? DaybookTheme.stamp.opacity(0.5) : DaybookTheme.rule.opacity(0.5),
                        lineWidth: 0.6
                    )
            )
            .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.ink)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 项目分组

    private var projectSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(L10n.string("filter.project", locale: locale))
                .font(DaybookType.badge)
                .foregroundStyle(DaybookTheme.muted)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 1) {
                // 无项目
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
        }
    }

    // MARK: - 标签分组（流式排布）

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.string("filter.tag", locale: locale))
                .font(DaybookType.badge)
                .foregroundStyle(DaybookTheme.muted)
                .padding(.leading, 4)

            FlowTagLayout(spacing: 5) {
                ForEach(tags) { tag in
                    tagPill(tag)
                }
            }
        }
    }

    private func tagPill(_ tag: TagItem) -> some View {
        let isSelected = selectedTagID == tag.id
        let color = DiaryTagChrome.color(for: tag.name)
        let count = tagCounts[tag.id] ?? 0

        return Button {
            selectTag(tag.id)
            onDismiss()
        } label: {
            HStack(spacing: 3.5) {
                Circle()
                    .fill(color)
                    .frame(width: 5.5, height: 5.5)

                Text("#" + tag.name)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? color : DaybookTheme.ink)

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? color : DaybookTheme.muted)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                    .fill(isSelected ? color.opacity(0.14) : DaybookTheme.hoverFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                    .strokeBorder(
                        isSelected ? color.opacity(0.6) : DaybookTheme.rule.opacity(0.5),
                        lineWidth: 0.6
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 动作逻辑

    private func resetAllFilters() {
        if tab == .tasks {
            filter?.wrappedValue = BoardFilter()
        } else {
            diaryFilterTagID?.wrappedValue = nil
        }
    }

    private func selectTag(_ id: UUID) {
        let next = selectedTagID == id ? nil : id
        if tab == .tasks {
            filter?.wrappedValue = activeFilter.withTag(next)
        } else {
            diaryFilterTagID?.wrappedValue = next
        }
    }
}

// MARK: - 流式标签排版布局

private struct FlowTagLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width, currentX > 0 {
                currentX = 0
                currentY += currentRowHeight + spacing
                currentRowHeight = 0
            }
            currentRowHeight = max(currentRowHeight, size.height)
            currentX += size.width + spacing
        }
        height = currentY + currentRowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += currentRowHeight + spacing
                currentRowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentRowHeight = max(currentRowHeight, size.height)
            currentX += size.width + spacing
        }
    }
}
