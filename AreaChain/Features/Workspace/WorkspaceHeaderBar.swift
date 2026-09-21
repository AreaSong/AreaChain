import SwiftData
import SwiftUI

/// 工作台内容区置顶虚化顶栏（兼容组件与原生 Toolbar 两用）：
/// 左侧跟随当前视图标题，右侧常驻胶囊搜索框与抽屉切换按钮。
struct WorkspaceHeaderBar: View {
    @Environment(\.locale) private var locale
    @Bindable var navigation: WorkspaceNavigation
    var projects: [ProjectItem]
    var tags: [TagItem]

    var body: some View {
        HStack(spacing: 12) {
            WorkspaceHeaderLeadingTitle(navigation: navigation, projects: projects, tags: tags)

            Spacer(minLength: 16)

            WorkspaceHeaderSearchCapsule(navigation: navigation)

            WorkspaceHeaderInspectorToggle(navigation: navigation)
        }
        .padding(.horizontal, DaybookSpacing.page)
        .frame(height: WorkspaceStyle.headerHeight)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
                .background(DaybookTheme.rule.opacity(0.65))
        }
        .accessibilityIdentifier("workspace.header.bar")
    }
}

// MARK: - Subcomponents for Header & Native Toolbar

struct WorkspaceHeaderLeadingTitle: View {
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @Bindable var navigation: WorkspaceNavigation
    var projects: [ProjectItem]
    var tags: [TagItem]
    private var selection: BoardSelection { BoardSelection.shared }

    var body: some View {
        HStack(spacing: 8) {
            if let pid = navigation.selectedProjectID, let project = projects.first(where: { $0.id == pid && $0.deletedAt == nil }) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(DaybookTheme.stamp)
                Text(project.name)
                    .font(DaybookType.body.weight(.bold))
                    .foregroundStyle(DaybookTheme.ink)
                    .lineLimit(1)
            } else if let tid = navigation.selectedTagID, let tag = tags.first(where: { $0.id == tid && $0.deletedAt == nil }) {
                Image(systemName: "number")
                    .foregroundStyle(DaybookTheme.stamp)
                Text("#\(tag.name)")
                    .font(DaybookType.body.weight(.bold))
                    .foregroundStyle(DaybookTheme.ink)
                    .lineLimit(1)
            } else {
                switch navigation.selectedTab {
                case .today:
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("workspace.today.title")
                            .font(DaybookType.body.weight(.bold))
                            .foregroundStyle(DaybookTheme.ink)
                        Text(DayKey.displayName(DayClock.shared.todayKey, locale: locale))
                            .font(DaybookType.caption)
                            .foregroundStyle(DaybookTheme.muted)
                    }
                case .quadrant:
                    HStack(spacing: 6) {
                        Text("sidebar.quadrant")
                            .font(DaybookType.body.weight(.bold))
                            .foregroundStyle(DaybookTheme.ink)
                        DaybookPeriodMiniCapsule(
                            title: DayKey.displayName(selection.inspectingDayKey, calendar: calendar, locale: locale),
                            onPrev: { selection.inspectingDayKey = DayKey.shifted(selection.inspectingDayKey, by: -1, calendar: calendar) },
                            onNext: { selection.inspectingDayKey = DayKey.shifted(selection.inspectingDayKey, by: 1, calendar: calendar) }
                        )
                    }
                case .calendar:
                    HStack(spacing: 6) {
                        Text("sidebar.calendar")
                            .font(DaybookType.body.weight(.bold))
                            .foregroundStyle(DaybookTheme.ink)
                        DaybookPeriodMiniCapsule(
                            title: DayKey.monthTitle(selection.inspectingDayKey, calendar: calendar, locale: locale),
                            onPrev: { selection.inspectingDayKey = DayKey.shiftedMonth(selection.inspectingDayKey, by: -1, calendar: calendar) },
                            onNext: { selection.inspectingDayKey = DayKey.shiftedMonth(selection.inspectingDayKey, by: 1, calendar: calendar) }
                        )
                    }
                default:
                    HStack(spacing: 6) {
                        Image(systemName: navigation.selectedTab.iconName)
                            .foregroundStyle(DaybookTheme.stamp)
                        Text(navigation.selectedTab.titleKey)
                            .font(DaybookType.body.weight(.bold))
                            .foregroundStyle(DaybookTheme.ink)
                            .lineLimit(1)
                    }
                }
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// 顶栏微型日期/周期切换胶囊
struct DaybookPeriodMiniCapsule: View {
    var title: String
    var onPrev: () -> Void
    var onNext: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Button(action: onPrev) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 8.5, weight: .bold))
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DaybookTheme.ink)
                .padding(.horizontal, 4)

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8.5, weight: .bold))
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(DaybookTheme.surface.opacity(0.85))
        )
        .overlay(
            Capsule()
                .strokeBorder(DaybookTheme.rule.opacity(0.4), lineWidth: 0.5)
        )
    }
}

/// 今日待办微型达成进度胶囊
struct TodayProgressMiniBadge: View {
    var todos: [TodoItem]
    var dayKey: String

    private var openTodosCount: Int {
        todos.filter { $0.dayKey == dayKey && $0.deletedAt == nil && !$0.isDone }.count
    }

    private var completedTodosCount: Int {
        todos.filter { $0.dayKey == dayKey && $0.deletedAt == nil && $0.isDone }.count
    }

    private var totalTodosCount: Int {
        openTodosCount + completedTodosCount
    }

    private var progressRatio: Double {
        guard totalTodosCount > 0 else { return completedTodosCount > 0 ? 1.0 : 0.0 }
        return Double(completedTodosCount) / Double(totalTodosCount)
    }

    var body: some View {
        HStack(spacing: 6) {
            Text("\(completedTodosCount)/\(totalTodosCount)")
                .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(completedTodosCount > 0 && completedTodosCount >= totalTodosCount ? DaybookTheme.stamp : DaybookTheme.ink)

            DaybookProgressRing(progress: progressRatio, lineWidth: 2.6, size: 22)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(
            Capsule()
                .fill(DaybookTheme.surface.opacity(0.85))
        )
        .overlay(
            Capsule()
                .strokeBorder(DaybookTheme.rule.opacity(0.4), lineWidth: 0.5)
        )
        .help("达成进度: \(completedTodosCount)/\(totalTodosCount)")
    }
}

struct WorkspaceHeaderSearchCapsule: View {
    @Environment(\.locale) private var locale
    @Bindable var navigation: WorkspaceNavigation

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(navigation.isSearchFocused ? DaybookTheme.ink : DaybookTheme.muted)

            DaybookTextField(
                text: $navigation.searchQuery,
                placeholder: L10n.string("search.placeholder", locale: locale),
                fontSize: 12,
                focus: $navigation.isSearchFocused,
                onSubmit: {},
                allowsShiftNewline: false,
                onEscape: {
                    navigation.clearSearch()
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
            )
            .accessibilityIdentifier("workspace.header.search")

            if !navigation.searchQuery.isEmpty {
                Button {
                    navigation.clearSearch()
                    navigation.isSearchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(DaybookTheme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("footer.search.clear")
            } else {
                Text("⌘F")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(DaybookTheme.muted.opacity(0.7))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DaybookTheme.rule.opacity(0.2))
                    )
            }
        }
        .padding(.horizontal, 10)
        .frame(width: 280, height: 28)
        .background(
            Capsule()
                .fill(navigation.isSearchFocused ? DaybookTheme.surface : WorkspaceStyle.input.opacity(0.85))
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    navigation.isSearchFocused ? DaybookTheme.stamp.opacity(0.65) : DaybookTheme.rule.opacity(0.65),
                    lineWidth: 0.8
                )
        )
        // ⌘F 全局快捷键聚焦
        .background {
            Button("") {
                navigation.isSearchFocused = true
            }
            .keyboardShortcut("f", modifiers: .command)
            .opacity(0)
            .accessibilityHidden(true)
        }
    }
}

struct WorkspaceHeaderInspectorToggle: View {
    @Environment(\.locale) private var locale
    @Bindable var navigation: WorkspaceNavigation

    var body: some View {
        Button {
            navigation.isInspectorPresented.toggle()
        } label: {
            Image(systemName: "sidebar.trailing")
                .font(.system(size: 13.5))
                .foregroundStyle(navigation.isInspectorPresented ? DaybookTheme.stamp : DaybookTheme.ink)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(navigation.isInspectorPresented ? DaybookTheme.hoverFill : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(L10n.string("drawer.inspector.toggle", locale: locale))
        .accessibilityIdentifier("workspace.header.inspector.toggle")
    }
}

// MARK: - Native Toolbar Integration

struct WorkspaceToolbarModifier: ViewModifier {
    @Bindable var navigation: WorkspaceNavigation
    var projects: [ProjectItem]
    var tags: [TagItem]
    var todos: [TodoItem]

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    WorkspaceHeaderLeadingTitle(
                        navigation: navigation,
                        projects: projects,
                        tags: tags
                    )
                }

                ToolbarItem(placement: .principal) {
                    WorkspaceHeaderSearchCapsule(navigation: navigation)
                }

                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 10) {
                        if navigation.selectedTab == .today && navigation.selectedProjectID == nil && navigation.selectedTagID == nil {
                            TodayProgressMiniBadge(todos: todos, dayKey: DayClock.shared.todayKey)
                        }
                        WorkspaceHeaderInspectorToggle(navigation: navigation)
                    }
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .windowToolbar)
            .toolbarBackground(.visible, for: .windowToolbar)
    }
}

extension View {
    func workspaceToolbar(
        navigation: WorkspaceNavigation,
        projects: [ProjectItem],
        tags: [TagItem],
        todos: [TodoItem]
    ) -> some View {
        modifier(WorkspaceToolbarModifier(
            navigation: navigation,
            projects: projects,
            tags: tags,
            todos: todos
        ))
    }
}

