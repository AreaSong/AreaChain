import SwiftData
import SwiftUI

/// 筛选大类分类枚举
enum FilterCategory: String, CaseIterable, Identifiable {
    case date
    case priority
    case project
    case tag

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .date: return "calendar"
        case .priority: return "exclamationmark.3"
        case .project: return "folder"
        case .tag: return "tag"
        }
    }

    func title(locale: Locale) -> String {
        switch self {
        case .date: return L10n.string("filter.date", locale: locale)
        case .priority: return L10n.string("filter.priority", locale: locale)
        case .project: return L10n.string("filter.project", locale: locale)
        case .tag: return L10n.string("filter.tag", locale: locale)
        }
    }
}

/// 菜单栏小窗母子结构筛选抽屉：左侧目录大类 + 右侧精细选项/多级项目树，高度紧凑收敛，反选即取消。
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
    var externalCategory: Binding<FilterCategory>? = nil

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var internalCategory: FilterCategory = .date

    private var activeCategory: Binding<FilterCategory> {
        externalCategory ?? $internalCategory
    }

    private var activeFilter: BoardFilter {
        filter?.wrappedValue ?? BoardFilter()
    }

    private var selectedTagID: UUID? {
        tab == .tasks ? activeFilter.tagID : diaryFilterTagID?.wrappedValue
    }

    private var isAnyFilterActive: Bool {
        if tab == .tasks {
            return activeFilter.isActive
        }
        return diaryFilterTagID?.wrappedValue != nil
    }

    private var availableCategories: [FilterCategory] {
        tab == .tasks ? FilterCategory.allCases : [.tag]
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()
                .overlay(DaybookTheme.rule.opacity(0.35))
                .padding(.horizontal, 8)

            HStack(spacing: 0) {
                // 1. 左侧大类目录列表
                sidebarCategoryList
                    .frame(width: 104)

                Divider()
                    .overlay(DaybookTheme.rule.opacity(0.35))

                // 2. 右侧当前类别细项详情
                contentDetailArea
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(height: 140)
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
            Button(action: resetAllFilters) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 8.5, weight: .bold))
                    Text(L10n.string("filter.clear", locale: locale))
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(isAnyFilterActive ? DaybookTheme.stamp : DaybookTheme.muted.opacity(0.4))
                .padding(.horizontal, 5)
                .padding(.vertical, 2.5)
                .background(
                    Capsule().fill(isAnyFilterActive ? DaybookTheme.stamp.opacity(0.10) : Color.clear)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isAnyFilterActive)
            .help(L10n.string("filter.clear", locale: locale))

            Spacer(minLength: 0)

            Capsule()
                .fill(DaybookTheme.rule.opacity(0.5))
                .frame(width: 22, height: 3)

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(DaybookTheme.muted)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L10n.string("common.close", locale: locale))
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    // MARK: - 左侧分类侧边栏

    private var sidebarCategoryList: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(availableCategories) { cat in
                let isSelected = activeCategory.wrappedValue == cat
                let hasActiveFilter = isCategoryActive(cat)

                Button {
                    withAnimation(DaybookMotion.interactive(reduceMotion)) {
                        activeCategory.wrappedValue = cat
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 9.5, weight: isSelected ? .semibold : .regular))
                            .frame(width: 13)

                        Text(cat.title(locale: locale))
                            .font(.system(size: 10.5, weight: isSelected ? .semibold : .regular))
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        if hasActiveFilter {
                            Circle()
                                .fill(DaybookTheme.stamp)
                                .frame(width: 4.5, height: 4.5)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4.5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isSelected ? DaybookTheme.stamp.opacity(0.12) : Color.clear)
                    )
                    .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.ink)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(DaybookTheme.ink.opacity(0.015))
    }

    // MARK: - 右侧详情区

    @ViewBuilder
    private var contentDetailArea: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 6) {
                switch activeCategory.wrappedValue {
                case .date:
                    dateOptionsView
                case .priority:
                    priorityOptionsView
                case .project:
                    projectOptionsView
                case .tag:
                    tagOptionsView
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 1. 时间范围选项

    private var dateOptionsView: some View {
        FlowTagLayout(spacing: 5) {
            matrixPill(
                title: L10n.string("filter.date.today", locale: locale),
                icon: "calendar",
                isSelected: activeFilter.dateScope == .today
            ) {
                toggleDateScope(.today)
            }

            matrixPill(
                title: L10n.string("filter.date.recent", locale: locale),
                icon: "calendar.badge.clock",
                isSelected: activeFilter.dateScope == .recent
            ) {
                toggleDateScope(.recent)
            }

            matrixPill(
                title: L10n.string("filter.date.overdue", locale: locale),
                icon: "clock.badge.exclamationmark",
                isSelected: activeFilter.dateScope == .overdue
            ) {
                toggleDateScope(.overdue)
            }
        }
    }

    // MARK: - 2. 优先级选项

    private var priorityOptionsView: some View {
        VStack(alignment: .leading, spacing: 5) {
            matrixPill(
                title: L10n.string("filter.priority.high", locale: locale),
                icon: "exclamationmark.3",
                isSelected: activeFilter.priorityScope == .highPriorityOnly || (activeFilter.isHighPriorityOnly && activeFilter.priorityScope == .all)
            ) {
                togglePriorityScope(.highPriorityOnly)
            }

            FlowTagLayout(spacing: 5) {
                matrixPill(
                    title: L10n.string("filter.priority.p1", locale: locale),
                    dotColor: Color.red,
                    isSelected: activeFilter.priorityScope == .p1
                ) {
                    togglePriorityScope(.p1)
                }

                matrixPill(
                    title: L10n.string("filter.priority.p2", locale: locale),
                    dotColor: Color.orange,
                    isSelected: activeFilter.priorityScope == .p2
                ) {
                    togglePriorityScope(.p2)
                }

                matrixPill(
                    title: L10n.string("filter.priority.p3", locale: locale),
                    dotColor: Color.blue,
                    isSelected: activeFilter.priorityScope == .p3
                ) {
                    togglePriorityScope(.p3)
                }

                matrixPill(
                    title: L10n.string("filter.priority.p4", locale: locale),
                    dotColor: Color.gray,
                    isSelected: activeFilter.priorityScope == .p4
                ) {
                    togglePriorityScope(.p4)
                }
            }
        }
    }

    // MARK: - 3. 项目层级树选项

    private var projectOptionsView: some View {
        VStack(alignment: .leading, spacing: 3) {
            matrixPill(
                title: L10n.string("filter.project.none", locale: locale),
                icon: "folder",
                count: unclassifiedCount,
                isSelected: activeFilter.isNoProject
            ) {
                toggleProject(BoardFilter.noneID)
            }

            let outline = ProjectTree.outline(projects.filter { $0.deletedAt == nil })
            ForEach(outline) { row in
                matrixPill(
                    title: row.name,
                    icon: "folder",
                    count: projectCounts[row.id],
                    indent: CGFloat(row.depth) * 10,
                    isSelected: activeFilter.projectID == row.id
                ) {
                    toggleProject(row.id)
                }
            }
        }
    }

    // MARK: - 4. 标签选项

    private var tagOptionsView: some View {
        FlowTagLayout(spacing: 5) {
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
                    toggleTag(tag.id)
                }
            }
        }
    }

    // MARK: - 单个胶囊组件

    private func matrixPill(
        title: String,
        icon: String? = nil,
        dotColor: Color? = nil,
        count: Int? = nil,
        indent: CGFloat = 0,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                if indent > 0 {
                    Spacer().frame(width: indent)
                }

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7.5, weight: .bold))
                } else if let dotColor {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 5, height: 5)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 8, weight: .medium))
                }

                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)

                if let count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 7.5, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.muted)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(isSelected ? DaybookTheme.stamp.opacity(0.14) : DaybookTheme.hoverFill)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                    isSelected ? DaybookTheme.stamp.opacity(0.6) : DaybookTheme.rule.opacity(0.4),
                    lineWidth: 0.6
                )
            )
            .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.ink)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 状态与反选逻辑

    private func isCategoryActive(_ cat: FilterCategory) -> Bool {
        switch cat {
        case .date:
            return activeFilter.dateScope != .all
        case .priority:
            return activeFilter.priorityScope != .all || activeFilter.isHighPriorityOnly
        case .project:
            return activeFilter.projectID != nil
        case .tag:
            return selectedTagID != nil
        }
    }

    private func toggleDateScope(_ scope: DateFilterScope) {
        let next: DateFilterScope = activeFilter.dateScope == scope ? .all : scope
        filter?.wrappedValue = activeFilter.withDateScope(next)
    }

    private func togglePriorityScope(_ scope: PriorityFilterScope) {
        let next: PriorityFilterScope = activeFilter.priorityScope == scope ? .all : scope
        filter?.wrappedValue = activeFilter.withPriorityScope(next)
    }

    private func toggleProject(_ id: UUID) {
        let next: UUID? = activeFilter.projectID == id ? nil : id
        filter?.wrappedValue = activeFilter.withProject(next)
    }

    private func toggleTag(_ id: UUID) {
        let next: UUID? = selectedTagID == id ? nil : id
        selectTag(next)
    }

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
