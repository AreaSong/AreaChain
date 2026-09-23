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
                            .font(DaybookType.micro.weight(isSelected ? .semibold : .regular))
                            .frame(width: 12)

                        Text(cat.title(locale: locale))
                            .font(DaybookType.badge.weight(isSelected ? .semibold : .regular))
                            .lineLimit(1)

                        Spacer(minLength: 2)

                        if hasActive {
                            DaybookStatusDot(color: DaybookPalette.accent.base, size: 4)
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 7.5, weight: .bold)) // token-exempt: 小于 9pt 的筛选图标
                            .foregroundStyle(isSelected ? DaybookPalette.accent.base : DaybookPalette.text.tertiary)
                    }
                }
                .buttonStyle(DaybookButtonStyle(isSelected ? .active : .quiet, size: .compact))
                .onHover { hovering in
                    if hovering {
                        activeCategory.wrappedValue = cat
                    }
                }
            }

            if activeCount > 0 {
                DaybookDivider(opacity: 0.4)
                    .padding(.vertical, 1)

                Button(action: clearAllAndDismiss) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 8.5, weight: .semibold)) // token-exempt: 小于 9pt 的筛选图标
                        Text(L10n.string("filter.clear", locale: locale))
                            .font(DaybookType.micro)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(DaybookButtonStyle(.prominent, size: .inline))
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous)
                .fill(DaybookPalette.fill.page)
                .daybookElevation(.floating)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous)
                .strokeBorder(DaybookPalette.border.default.opacity(0.65), lineWidth: 0.8) // token-exempt: 65% 分隔线没有对应令牌
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
                    DaybookDivider(opacity: 0.4)
                        .padding(.vertical, 1)

                    Button(action: clearAllAndDismiss) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 8.5, weight: .semibold)) // token-exempt: 小于 9pt 的筛选图标
                            Text(L10n.string("filter.clear", locale: locale))
                                .font(DaybookType.micro)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(DaybookButtonStyle(.prominent, size: .inline))
                }
            }
            .padding(4)
        }
        .frame(maxHeight: 165)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous)
                .fill(DaybookPalette.fill.page)
                .daybookElevation(.floating)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous)
                .strokeBorder(DaybookPalette.border.default.opacity(0.65), lineWidth: 0.8) // token-exempt: 65% 分隔线没有对应令牌
        )
    }

    // MARK: - 1. 时间选项

    private var dateOptionsView: some View {
        choiceRows(BoardFilterChoices.dates(filter: activeFilter, locale: locale))
    }

    private var priorityOptionsView: some View {
        choiceRows(BoardFilterChoices.priorities(filter: activeFilter, locale: locale))
    }

    private var projectOptionsView: some View {
        let outline = ProjectTree.outline(projects.filter { $0.deletedAt == nil })
        return choiceRows(
            BoardFilterChoices.projects(
                filter: activeFilter,
                rows: outline.map { BoardFilterChoices.NamedRow(id: $0.id, name: $0.name, depth: $0.depth) },
                counts: projectCounts,
                unclassifiedCount: unclassifiedCount,
                locale: locale
            ),
            icon: { $0.id == "all" ? "circle" : "folder" }
        )
    }

    private var tagOptionsView: some View {
        choiceRows(
            BoardFilterChoices.tags(
                filter: activeFilter,
                rows: tags.map { BoardFilterChoices.NamedRow(id: $0.id, name: $0.name) },
                counts: tagCounts,
                untaggedCount: nil,
                includeNone: false,
                locale: locale
            ),
            icon: { $0.id == "all" ? "circle" : nil },
            title: BoardFilterChoices.markedTagTitle
        )
    }

    private func choiceRows(
        _ choices: [BoardFilterChoice],
        icon: @escaping (BoardFilterChoice) -> String? = { $0.systemImage },
        title: @escaping (BoardFilterChoice) -> String = { $0.title }
    ) -> some View {
        VStack(spacing: 2) {
            ForEach(choices) { choice in
                flyoutItem(
                    title: title(choice),
                    icon: icon(choice),
                    dotColor: choice.dotColor,
                    count: choice.count,
                    indent: choice.indent,
                    isSelected: choice.isSelected
                ) {
                    writeFilter(choice.isSelected ? choice.cleared : choice.applied)
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
                    DaybookStatusDot(color: dotColor, size: 5)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 8.5, weight: .medium)) // token-exempt: 小于 9pt 的筛选图标
                        .frame(width: 12)
                }

                Text(title)
                    .font(DaybookType.badge.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)

                Spacer(minLength: 2)

                if let count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 8, weight: .bold, design: .rounded)) // token-exempt: 小于 9pt 的筛选图标
                        .foregroundStyle(isSelected ? DaybookPalette.accent.base : DaybookPalette.text.secondary)
                }

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold)) // token-exempt: 小于 9pt 的筛选图标
                        .foregroundStyle(DaybookPalette.accent.base)
                }
            }
        }
        .buttonStyle(DaybookButtonStyle(isSelected ? .active : .quiet, size: .compact))
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

    private func clearAllAndDismiss() {
        filters.wrappedValue.clear(tab)
        onDismiss()
    }
}
