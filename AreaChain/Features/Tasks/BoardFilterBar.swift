import SwiftData
import SwiftUI

struct BoardFilterBar: View {
    @Environment(\.locale) private var locale

    var filter: BoardFilter
    var tags: [CatalogChoice]
    var bundleIDs: [String]
    var tagCounts: [UUID: Int] = [:]
    var untaggedCount: Int? = nil
    var totalOpenCount: Int? = nil
    var showsPriority: Bool = false
    var showsReminder: Bool = false
    var showsDate: Bool = false
    var onChange: (BoardFilter) -> Void

    @State private var activeDropdown: ActiveDropdown? = nil

    private enum ActiveDropdown: Hashable {
        case tag, bundle, priority, reminder, date
    }

    var isVisible: Bool {
        filter.isActive || !tags.isEmpty || !bundleIDs.isEmpty || showsPriority || showsReminder || showsDate
    }

    var body: some View {
        if isVisible {
            HStack(spacing: 6) {
                if filter.isActive {
                    Button("filter.all") { onChange(BoardFilter()) }
                        .buttonStyle(DaybookButtonStyle(.quiet))
                }
                if !tags.isEmpty {
                    tagDropdown
                }
                if !bundleIDs.isEmpty {
                    bundleDropdown
                }
                if showsPriority {
                    priorityDropdown
                }
                if showsReminder {
                    reminderDropdown
                }
                if showsDate {
                    dateDropdown
                }
            }
            .font(DaybookType.caption)
            .fixedSize(horizontal: true, vertical: false)
        }
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
            items: options.filter { $0.id != "all" }
        )
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

    private var priorityDropdown: some View {
        choiceDropdown(
            BoardFilterChoices.priorities(filter: filter, locale: locale),
            icon: "exclamationmark.3",
            title: filter.priorityScope == .all ? L10n.string("filter.priority", locale: locale) : filter.priorityTitle(locale: locale),
            active: filter.priorityScope != .all || filter.isHighPriorityOnly,
            kind: .priority,
            reset: { onChange(filter.withPriorityScope(.all)) }
        )
    }

    private var reminderDropdown: some View {
        choiceDropdown(
            BoardFilterChoices.reminders(filter: filter, locale: locale),
            icon: "bell",
            title: filter.reminderScope == .all
                ? L10n.string("filter.reminder", locale: locale)
                : filter.reminderScope.title(locale: locale),
            active: filter.reminderScope != .all,
            kind: .reminder,
            reset: { onChange(filter.withReminderScope(.all)) }
        )
    }

    private var dateDropdown: some View {
        choiceDropdown(
            BoardFilterChoices.dates(filter: filter, locale: locale),
            icon: "calendar",
            title: filter.dateScope == .all ? L10n.string("filter.date", locale: locale) : filter.dateScope.title(locale: locale),
            active: filter.dateScope != .all,
            kind: .date,
            reset: { onChange(filter.withDateScope(.all)) }
        )
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        standardCapsule
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
                        .font(DaybookType.micro.weight(.medium))
                        .foregroundStyle(active ? DaybookPalette.accent.base : DaybookPalette.text.secondary)
                    Text(title)
                        .font(DaybookType.caption.weight(active ? .semibold : .regular))
                        .foregroundStyle(active ? DaybookPalette.accent.base : DaybookPalette.text.primary)
                        .lineLimit(1)
                }
            }
            .buttonStyle(DaybookButtonStyle(.quiet, size: .inline))

            if active, let reset {
                Button(action: reset) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold)) // token-exempt: 小于 9pt 的筛选图标
                }
                .buttonStyle(DaybookButtonStyle(.iconActive, size: .inline))
                .help("footer.filter.clear")
                .accessibilityLabel("footer.filter.clear")
            } else {
                Button {
                    isExpanded.wrappedValue.toggle()
                } label: {
                    Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                        .font(.system(size: 7.5, weight: .bold)) // token-exempt: 小于 9pt 的筛选图标
                }
                .buttonStyle(DaybookButtonStyle(.icon, size: .inline))
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Capsule().fill(active ? DaybookPalette.accent.fill : DaybookPalette.text.primary.opacity(0.05))) // token-exempt: 5% 墨色底没有对应令牌
        .overlay(
            Capsule().stroke( // token-exempt: 筛选胶囊描边
                active ? DaybookPalette.accent.border : DaybookPalette.border.default.opacity(0.5), // token-exempt: 50% 分隔线没有对应令牌
                lineWidth: 0.8
            )
        )
        .contentShape(Capsule()) // token-exempt: 筛选胶囊点击区
    }

    // MARK: - 手账风下拉气泡内容

    private var dropdownPopoverContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let allOption {
                FilterDropdownItemRow(item: allOption) {
                    allOption.action()
                    isExpanded.wrappedValue = false
                }
                DaybookDivider(opacity: 0.35)
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
        .background(DaybookPalette.fill.page)
    }
}

// MARK: - 单个条目行

struct FilterDropdownItemRow: View {
    var item: FilterDropdownOption
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 5) {
                if item.isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8.5, weight: .bold)) // token-exempt: 小于 9pt 的筛选图标
                        .foregroundStyle(DaybookPalette.accent.base)
                        .frame(width: 10)
                } else {
                    Spacer()
                        .frame(width: 10)
                }

                if let icon = item.icon {
                    Image(systemName: icon)
                        .font(DaybookType.micro.weight(.medium))
                        .foregroundStyle(item.isSelected ? DaybookPalette.accent.base : DaybookPalette.text.secondary)
                }

                Text(item.title)
                    .font(DaybookType.caption)
                    .foregroundStyle(item.isSelected ? DaybookPalette.accent.base : DaybookPalette.text.primary)
                    .lineLimit(1)

                Spacer(minLength: 6)

                if let count = item.count, count > 0 {
                    DaybookCount(count: count, emphasis: item.isSelected)
                }
            }
        }
        .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
