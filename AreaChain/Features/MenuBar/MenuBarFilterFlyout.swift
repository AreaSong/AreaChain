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

/// 菜单栏两级树状级联悬停浮窗：轻量纯非模态卡片，一级目录分类 + 二级具体选项无缝级联展开。
struct MenuBarFilterFlyout: View {
    var tab: BoardTab = .tasks
    var filters: Binding<BoardFilters>
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
    @State private var dismissTask: Task<Void, Never>? = nil

    private var activeCategory: Binding<FilterCategory> {
        externalCategory ?? $internalCategory
    }

    private var activeFilter: BoardFilter {
        filters.wrappedValue.selection(for: tab)
    }

    private var selectedTagID: UUID? {
        activeFilter.tagID
    }

    private var activeCount: Int {
        filters.wrappedValue.activeCount(for: tab)
    }

    private func writeFilter(_ filter: BoardFilter) {
        filters.wrappedValue.write(filter, for: tab)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            if tab == .tasks {
                // 1. 一级分类目录卡片
                level1CategoryCard
                    .frame(width: 110)

                // 2. 二级具体选项级联卡片
                level2OptionCard
                    .frame(width: 175)
            } else {
                // 手记页只有标签维度：直接展示标签选项卡片，跳过冗余一级目录
                level2OptionCard
                    .frame(width: 175)
            }
        }
        .padding(3)
        .onHover { isHovered in
            handleHoverChange(isHovered)
        }
        .onDisappear {
            dismissTask?.cancel()
            dismissTask = nil
        }
    }

    // MARK: - 悬停离开保护与收起

    private func handleHoverChange(_ isHovered: Bool) {
        if isHovered {
            dismissTask?.cancel()
            dismissTask = nil
        } else {
            dismissTask?.cancel()
            dismissTask = Task {
                try? await Task.sleep(for: .milliseconds(220))
                if !Task.isCancelled {
                    onDismiss()
                }
            }
        }
    }

    // MARK: - 一级分类卡片

    private var level1CategoryCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(FilterCategory.allCases) { cat in
                let isSelected = activeCategory.wrappedValue == cat
                let hasActive = isCategoryActive(cat)

                Button {
                    activeCategory.wrappedValue = cat
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 9.5, weight: isSelected ? .semibold : .regular))
                            .frame(width: 12)

                        Text(cat.title(locale: locale))
                            .font(.system(size: 10.5, weight: isSelected ? .semibold : .regular))
                            .lineLimit(1)

                        Spacer(minLength: 2)

                        if hasActive {
                            Circle()
                                .fill(DaybookTheme.stamp)
                                .frame(width: 4, height: 4)
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.muted.opacity(0.7))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4.5)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(isSelected ? DaybookTheme.stamp.opacity(0.12) : Color.clear)
                    )
                    .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.ink)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        activeCategory.wrappedValue = cat
                    }
                }
            }

            if activeCount > 0 {
                Divider()
                    .overlay(DaybookTheme.rule.opacity(0.4))
                    .padding(.vertical, 1)

                Button(action: clearAllAndDismiss) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 8.5, weight: .semibold))
                        Text(L10n.string("filter.clear", locale: locale))
                            .font(.system(size: 9.5))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3.5)
                    .foregroundStyle(DaybookTheme.stamp.opacity(0.9))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DaybookTheme.paper)
                .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(DaybookTheme.rule.opacity(0.65), lineWidth: 0.8)
        )
    }

    // MARK: - 二级选项卡片

    private var level2OptionCard: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 2) {
                if tab == .tasks {
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
                } else {
                    tagOptionsView
                }

                if tab == .diary && selectedTagID != nil {
                    Divider()
                        .overlay(DaybookTheme.rule.opacity(0.4))
                        .padding(.vertical, 1)

                    Button(action: clearAllAndDismiss) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 8.5, weight: .semibold))
                            Text(L10n.string("filter.clear", locale: locale))
                                .font(.system(size: 9.5))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3.5)
                        .foregroundStyle(DaybookTheme.stamp.opacity(0.9))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
        }
        .frame(maxHeight: 165)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DaybookTheme.paper)
                .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(DaybookTheme.rule.opacity(0.65), lineWidth: 0.8)
        )
    }

    // MARK: - 1. 时间选项

    private var dateOptionsView: some View {
        VStack(spacing: 2) {
            flyoutItem(
                title: L10n.string("filter.all", locale: locale),
                icon: "circle",
                isSelected: activeFilter.dateScope == .all
            ) {
                toggleDateScope(.all)
            }

            flyoutItem(
                title: L10n.string("filter.date.today", locale: locale),
                icon: "calendar",
                isSelected: activeFilter.dateScope == .today
            ) {
                toggleDateScope(.today)
            }

            flyoutItem(
                title: L10n.string("filter.date.recent", locale: locale),
                icon: "calendar.badge.clock",
                isSelected: activeFilter.dateScope == .recent
            ) {
                toggleDateScope(.recent)
            }

            flyoutItem(
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
        VStack(spacing: 2) {
            flyoutItem(
                title: L10n.string("filter.all", locale: locale),
                icon: "circle",
                isSelected: activeFilter.priorityScope == .all && !activeFilter.isHighPriorityOnly
            ) {
                togglePriorityScope(.all)
            }

            flyoutItem(
                title: L10n.string("filter.priority.high", locale: locale),
                icon: "exclamationmark.3",
                isSelected: activeFilter.priorityScope == .highPriorityOnly || (activeFilter.isHighPriorityOnly && activeFilter.priorityScope == .all)
            ) {
                togglePriorityScope(.highPriorityOnly)
            }

            flyoutItem(
                title: L10n.string("filter.priority.p1", locale: locale),
                dotColor: Color.red,
                isSelected: activeFilter.priorityScope == .p1
            ) {
                togglePriorityScope(.p1)
            }

            flyoutItem(
                title: L10n.string("filter.priority.p2", locale: locale),
                dotColor: Color.orange,
                isSelected: activeFilter.priorityScope == .p2
            ) {
                togglePriorityScope(.p2)
            }

            flyoutItem(
                title: L10n.string("filter.priority.p3", locale: locale),
                dotColor: Color.blue,
                isSelected: activeFilter.priorityScope == .p3
            ) {
                togglePriorityScope(.p3)
            }

            flyoutItem(
                title: L10n.string("filter.priority.p4", locale: locale),
                dotColor: Color.gray,
                isSelected: activeFilter.priorityScope == .p4
            ) {
                togglePriorityScope(.p4)
            }
        }
    }

    // MARK: - 3. 项目层级缩进选项

    private var projectOptionsView: some View {
        VStack(spacing: 2) {
            flyoutItem(
                title: L10n.string("filter.all", locale: locale),
                icon: "circle",
                isSelected: activeFilter.projectID == nil
            ) {
                selectProject(nil)
            }

            flyoutItem(
                title: L10n.string("filter.project.none", locale: locale),
                icon: "folder",
                count: unclassifiedCount,
                isSelected: activeFilter.isNoProject
            ) {
                toggleProject(BoardFilter.noneID)
            }

            let outline = ProjectTree.outline(projects.filter { $0.deletedAt == nil })
            ForEach(outline) { row in
                flyoutItem(
                    title: row.name,
                    icon: "folder",
                    count: projectCounts[row.id],
                    indent: CGFloat(row.depth) * 8,
                    isSelected: activeFilter.projectID == row.id
                ) {
                    toggleProject(row.id)
                }
            }
        }
    }

    // MARK: - 4. 标签选项

    private var tagOptionsView: some View {
        VStack(spacing: 2) {
            flyoutItem(
                title: L10n.string("filter.all", locale: locale),
                icon: "circle",
                isSelected: selectedTagID == nil
            ) {
                selectTag(nil)
            }

            ForEach(tags) { tag in
                let isSelected = selectedTagID == tag.id
                let color = DiaryTagChrome.color(for: tag.name)
                let count = tagCounts[tag.id]

                flyoutItem(
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

    // MARK: - 选项行条目组件

    private func flyoutItem(
        title: String,
        icon: String? = nil,
        dotColor: Color? = nil,
        count: Int? = nil,
        indent: CGFloat = 0,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            onDismiss()
        } label: {
            HStack(spacing: 4) {
                if indent > 0 {
                    Spacer().frame(width: indent)
                }

                if let dotColor {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 5, height: 5)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 8.5, weight: .medium))
                        .frame(width: 12)
                }

                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)

                Spacer(minLength: 2)

                if let count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.muted)
                }

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(DaybookTheme.stamp)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isSelected ? DaybookTheme.stamp.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(isSelected ? DaybookTheme.stamp.opacity(0.35) : Color.clear, lineWidth: 0.6)
            )
            .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.ink)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 筛选交互与即反选

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
        writeFilter(activeFilter.withDateScope(next))
    }

    private func togglePriorityScope(_ scope: PriorityFilterScope) {
        let next: PriorityFilterScope = activeFilter.priorityScope == scope ? .all : scope
        writeFilter(activeFilter.withPriorityScope(next))
    }

    private func selectProject(_ id: UUID?) {
        writeFilter(activeFilter.withProject(id))
    }

    private func toggleProject(_ id: UUID) {
        let next: UUID? = activeFilter.projectID == id ? nil : id
        selectProject(next)
    }

    private func selectTag(_ id: UUID?) {
        writeFilter(activeFilter.withTag(id))
    }

    private func toggleTag(_ id: UUID) {
        let next: UUID? = selectedTagID == id ? nil : id
        selectTag(next)
    }

    private func clearAllAndDismiss() {
        filters.wrappedValue.clear(tab)
        onDismiss()
    }
}
