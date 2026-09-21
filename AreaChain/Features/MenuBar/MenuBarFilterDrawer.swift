import SwiftData
import SwiftUI

/// 菜单栏小窗内部手账风多维度筛选矩阵：分行紧凑排布时间、优先级、项目与标签，高度自适应贴合，支持多选自由叠加。
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

    private var isAnyFilterActive: Bool {
        if tab == .tasks {
            return activeFilter.isActive
        }
        return diaryFilterTagID?.wrappedValue != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. 顶部操作栏（重置、手柄、关闭）
            headerBar

            Divider()
                .overlay(DaybookTheme.rule.opacity(0.35))
                .padding(.horizontal, 8)
                .padding(.bottom, 6)

            // 2. 自适应内容区（多维度分行胶囊矩阵）
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 9) {
                    if tab == .tasks {
                        // 维度 1：时间范围
                        dateSection

                        // 维度 2：优先级
                        prioritySection

                        // 维度 3：所属项目
                        projectSection
                    }

                    // 维度 4：标签分类
                    if !tags.isEmpty {
                        tagSection
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
            .frame(maxHeight: 280)
            .fixedSize(horizontal: false, vertical: true)
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

    // MARK: - 顶部操作栏

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 6) {
            // 左侧：重置按钮
            Button(action: resetAllFilters) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 8.5, weight: .bold))
                    Text(L10n.string("filter.all", locale: locale))
                        .font(.system(size: 10.5, weight: .medium))
                }
                .foregroundStyle(isAnyFilterActive ? DaybookTheme.stamp : DaybookTheme.muted.opacity(0.5))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(isAnyFilterActive ? DaybookTheme.stamp.opacity(0.10) : Color.clear)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isAnyFilterActive)
            .help(L10n.string("filter.clear", locale: locale))

            Spacer(minLength: 0)

            // 居中手柄
            Capsule()
                .fill(DaybookTheme.rule.opacity(0.6))
                .frame(width: 26, height: 3.5)

            Spacer(minLength: 0)

            // 右侧：完成/关闭按钮
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DaybookTheme.muted)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L10n.string("common.close", locale: locale))
        }
        .padding(.horizontal, 10)
        .padding(.top, 7)
        .padding(.bottom, 5)
    }

    // MARK: - 维度 1：时间范围

    private var dateSection: some View {
        matrixRow(title: L10n.string("filter.date", locale: locale)) {
            matrixPill(
                title: L10n.string("filter.all", locale: locale),
                isSelected: activeFilter.dateScope == .all
            ) {
                filter?.wrappedValue = activeFilter.withDateScope(.all)
            }

            matrixPill(
                title: L10n.string("filter.date.today", locale: locale),
                icon: "calendar",
                isSelected: activeFilter.dateScope == .today
            ) {
                let next: DateFilterScope = activeFilter.dateScope == .today ? .all : .today
                filter?.wrappedValue = activeFilter.withDateScope(next)
            }

            matrixPill(
                title: L10n.string("filter.date.recent", locale: locale),
                isSelected: activeFilter.dateScope == .recent
            ) {
                let next: DateFilterScope = activeFilter.dateScope == .recent ? .all : .recent
                filter?.wrappedValue = activeFilter.withDateScope(next)
            }

            matrixPill(
                title: L10n.string("filter.date.overdue", locale: locale),
                isSelected: activeFilter.dateScope == .overdue
            ) {
                let next: DateFilterScope = activeFilter.dateScope == .overdue ? .all : .overdue
                filter?.wrappedValue = activeFilter.withDateScope(next)
            }
        }
    }

    // MARK: - 维度 2：优先级

    private var prioritySection: some View {
        matrixRow(title: L10n.string("filter.priority", locale: locale)) {
            matrixPill(
                title: L10n.string("filter.all", locale: locale),
                isSelected: !isHighPriority
            ) {
                filter?.wrappedValue = activeFilter.withHighPriority(false)
            }

            matrixPill(
                title: L10n.string("filter.highPriority", locale: locale),
                icon: "exclamationmark.3",
                isSelected: isHighPriority
            ) {
                filter?.wrappedValue = activeFilter.withHighPriority(!isHighPriority)
            }
        }
    }

    // MARK: - 维度 3：所属项目

    private var projectSection: some View {
        matrixRow(title: L10n.string("filter.project", locale: locale)) {
            // 全部项目
            matrixPill(
                title: L10n.string("filter.all", locale: locale),
                isSelected: activeFilter.projectID == nil
            ) {
                filter?.wrappedValue = activeFilter.withProject(nil)
            }

            // 无项目
            matrixPill(
                title: L10n.string("filter.project.none", locale: locale),
                icon: "folder",
                count: unclassifiedCount,
                isSelected: activeFilter.isNoProject
            ) {
                let next: UUID? = activeFilter.isNoProject ? nil : BoardFilter.noneID
                filter?.wrappedValue = activeFilter.withProject(next)
            }

            // 各具体项目
            ForEach(projects.filter { $0.deletedAt == nil }) { proj in
                matrixPill(
                    title: proj.name,
                    icon: "folder",
                    count: projectCounts[proj.id],
                    isSelected: activeFilter.projectID == proj.id
                ) {
                    let next = activeFilter.projectID == proj.id ? nil : proj.id
                    filter?.wrappedValue = activeFilter.withProject(next)
                }
            }
        }
    }

    // MARK: - 维度 4：标签分类

    private var tagSection: some View {
        matrixRow(title: L10n.string("filter.tag", locale: locale)) {
            matrixPill(
                title: L10n.string("filter.all", locale: locale),
                isSelected: selectedTagID == nil
            ) {
                selectTag(nil)
            }

            ForEach(tags) { tag in
                let isSelected = selectedTagID == tag.id
                let color = DiaryTagChrome.color(for: tag.name)
                let count = tagCounts[tag.id]

                matrixPill(
                    title: "#" + tag.name,
                    dotColor: color,
                    count: count,
                    isSelected: isSelected
                ) {
                    selectTag(isSelected ? nil : tag.id)
                }
            }
        }
    }

    // MARK: - 胶囊矩阵行与单个胶囊组件

    private func matrixRow<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(DaybookType.badge)
                .foregroundStyle(DaybookTheme.muted)
                .padding(.leading, 2)

            FlowTagLayout(spacing: 5) {
                content()
            }
        }
    }

    private func matrixPill(
        title: String,
        icon: String? = nil,
        dotColor: Color? = nil,
        count: Int? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 3.5) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                } else if let dotColor {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 5, height: 5)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 8.5, weight: .medium))
                }

                Text(title)
                    .font(.system(size: 10.5, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)

                if let count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.muted)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(
                Capsule()
                    .fill(isSelected ? DaybookTheme.stamp.opacity(0.14) : DaybookTheme.hoverFill)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? DaybookTheme.stamp.opacity(0.6) : DaybookTheme.rule.opacity(0.45),
                        lineWidth: 0.6
                    )
            )
            .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.ink)
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

    private func selectTag(_ id: UUID?) {
        if tab == .tasks {
            filter?.wrappedValue = activeFilter.withTag(id)
        } else {
            diaryFilterTagID?.wrappedValue = id
        }
    }
}

// MARK: - 流式胶囊排版布局

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
