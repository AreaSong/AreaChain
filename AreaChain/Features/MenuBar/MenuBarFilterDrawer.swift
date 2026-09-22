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

/// 菜单栏小窗母子结构筛选吸附托盘：左侧目录大类 + 右侧整齐通栏选项行，高度紧凑，与底栏浑然一体。
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

    private var availableCategories: [FilterCategory] {
        tab == .tasks ? FilterCategory.allCases : [.tag]
    }

    var body: some View {
        HStack(spacing: 0) {
            // 1. 左侧大类侧边栏
            sidebarCategoryList
                .frame(width: 96)

            Divider()
                .overlay(DaybookTheme.rule.opacity(0.35))

            // 2. 右侧通栏选项详情区
            contentDetailArea
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(height: 126)
        .frame(width: DaybookTheme.popoverWidth - 24)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(DaybookTheme.paper)
                .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: -4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(DaybookTheme.rule.opacity(0.55), lineWidth: 0.8)
        )
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
                            .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
                            .frame(width: 12)

                        Text(cat.title(locale: locale))
                            .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        if hasActiveFilter {
                            Circle()
                                .fill(DaybookTheme.stamp)
                                .frame(width: 4, height: 4)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
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
        .background(DaybookTheme.ink.opacity(0.02))
    }

    // MARK: - 右侧详情区 (通栏条目整洁排布)

    @ViewBuilder
    private var contentDetailArea: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 2) {
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
            .padding(5)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 1. 时间范围 (通栏行)

    private var dateOptionsView: some View {
        VStack(spacing: 2) {
            filterRowItem(
                title: L10n.string("filter.date.today", locale: locale),
                icon: "calendar",
                isSelected: activeFilter.dateScope == .today
            ) {
                toggleDateScope(.today)
            }

            filterRowItem(
                title: L10n.string("filter.date.recent", locale: locale),
                icon: "calendar.badge.clock",
                isSelected: activeFilter.dateScope == .recent
            ) {
                toggleDateScope(.recent)
            }

            filterRowItem(
                title: L10n.string("filter.date.overdue", locale: locale),
                icon: "clock.badge.exclamationmark",
                isSelected: activeFilter.dateScope == .overdue
            ) {
                toggleDateScope(.overdue)
            }
        }
    }

    // MARK: - 2. 优先级 (通栏行)

    private var priorityOptionsView: some View {
        VStack(spacing: 2) {
            filterRowItem(
                title: L10n.string("filter.priority.high", locale: locale),
                icon: "exclamationmark.3",
                isSelected: activeFilter.priorityScope == .highPriorityOnly || (activeFilter.isHighPriorityOnly && activeFilter.priorityScope == .all)
            ) {
                togglePriorityScope(.highPriorityOnly)
            }

            filterRowItem(
                title: L10n.string("filter.priority.p1", locale: locale),
                dotColor: Color.red,
                isSelected: activeFilter.priorityScope == .p1
            ) {
                togglePriorityScope(.p1)
            }

            filterRowItem(
                title: L10n.string("filter.priority.p2", locale: locale),
                dotColor: Color.orange,
                isSelected: activeFilter.priorityScope == .p2
            ) {
                togglePriorityScope(.p2)
            }

            filterRowItem(
                title: L10n.string("filter.priority.p3", locale: locale),
                dotColor: Color.blue,
                isSelected: activeFilter.priorityScope == .p3
            ) {
                togglePriorityScope(.p3)
            }

            filterRowItem(
                title: L10n.string("filter.priority.p4", locale: locale),
                dotColor: Color.gray,
                isSelected: activeFilter.priorityScope == .p4
            ) {
                togglePriorityScope(.p4)
            }
        }
    }

    // MARK: - 3. 项目层级树 (通栏行 + 缩进)

    private var projectOptionsView: some View {
        VStack(spacing: 2) {
            filterRowItem(
                title: L10n.string("filter.project.none", locale: locale),
                icon: "folder",
                count: unclassifiedCount,
                isSelected: activeFilter.isNoProject
            ) {
                toggleProject(BoardFilter.noneID)
            }

            let outline = ProjectTree.outline(projects.filter { $0.deletedAt == nil })
            ForEach(outline) { row in
                filterRowItem(
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

    // MARK: - 4. 标签分类 (通栏行)

    private var tagOptionsView: some View {
        VStack(spacing: 2) {
            ForEach(tags) { tag in
                let isSelected = selectedTagID == tag.id
                let color = DiaryTagChrome.color(for: tag.name)
                let count = tagCounts[tag.id]

                filterRowItem(
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

    // MARK: - 通栏条目组件 (撑满整行，信息饱满层次分明)

    private func filterRowItem(
        title: String,
        icon: String? = nil,
        dotColor: Color? = nil,
        count: Int? = nil,
        indent: CGFloat = 0,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
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

                Spacer(minLength: 4)

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

    private func selectTag(_ id: UUID?) {
        if tab == .tasks {
            filter?.wrappedValue = activeFilter.withTag(id)
        } else {
            diaryFilterTagID?.wrappedValue = id
        }
    }
}
