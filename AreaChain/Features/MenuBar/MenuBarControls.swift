//
//  MenuBarControls.swift
//  AreaChain
//
//  Created by Antigravity on 2026-09-10.
//

import SwiftUI
import SwiftData

/// 状态栏弹窗标签栏组件
struct DaybookQuietTabBar: View {
    @Binding var selection: BoardTab
    var tasksCount: Int = 0
    var diariesCount: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var sliderAnimation

    var body: some View {
        HStack(spacing: 2) {
            ForEach(BoardTab.allCases) { item in
                tabButton(item)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DaybookTheme.ink.opacity(0.06))
        )
    }

    private func tabButton(_ item: BoardTab) -> some View {
        let isSelected = selection == item
        let ink = isSelected ? DaybookTheme.ink : DaybookTheme.muted
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                selection = item
            }
        } label: {
            Text(item.title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .frame(minWidth: 36)
                .padding(.horizontal, 12)
                .padding(.vertical, 4.5)
                .background(
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(DaybookTheme.paper)
                                .shadow(color: Color.black.opacity(0.08), radius: 1.5, x: 0, y: 0.5)
                                .matchedGeometryEffect(id: "SliderBackground", in: sliderAnimation)
                        }
                    }
                )
                .foregroundStyle(ink)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .help(item == .tasks ? "任务 (⌘←)" : "日记 (⌘→)")
    }
}

/// 状态栏弹窗底部信息栏
struct FooterBar: View {
    var tab: BoardTab = .tasks
    var filter: Binding<BoardFilter>? = nil
    var tags: [TagItem] = []
    var diaryCount: Int = 0
    var completedCount: Int = 0
    var totalCount: Int = 0

    @Environment(\.locale) private var locale
    @State private var hotKeyName = HotKeyCenter.shared.displayName()

    var body: some View {
        HStack(spacing: 8) {
            hotKeyBadge

            Spacer(minLength: 4)

            centerContent

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                if tab == .tasks && totalCount > 0 {
                    todayProgressBadge
                }
                workspaceMenuButton
            }
        }
        .onAppear { refreshHotKey() }
        .onChange(of: locale.identifier) { _, _ in refreshHotKey() }
        .onReceive(NotificationCenter.default.publisher(for: .hotKeyDidChange)) { _ in
            refreshHotKey()
        }
        .onReceive(NotificationCenter.default.publisher(for: .appPreferencesDidChange)) { _ in
            refreshHotKey()
        }
    }

    private var hotKeyBadge: some View {
        Text(hotKeyName)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(DaybookTheme.muted)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(DaybookTheme.ink.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(DaybookTheme.rule.opacity(0.4), lineWidth: 0.7)
                    )
            )
            .help("footer.hotkey \(hotKeyName)")
    }

    @ViewBuilder
    private var centerContent: some View {
        switch tab {
        case .tasks:
            unifiedFilterControl
        case .diary:
            diaryCounterBadge
        }
    }

    private var diaryCounterBadge: some View {
        Group {
            if diaryCount > 0 {
                Text(L10n.format("header.diary.count", locale: locale, diaryCount))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(DaybookTheme.muted)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
            }
        }
    }

    @ViewBuilder
    private var unifiedFilterControl: some View {
        if let filterBinding = filter {
            let activeTags = tags.filter { $0.deletedAt == nil }
            let currentTagID = filterBinding.wrappedValue.tagID
            let isHighPriority = filterBinding.wrappedValue.isHighPriorityOnly
            let selectedTag = activeTags.first(where: { $0.id == currentTagID })

            if isHighPriority {
                HStack(spacing: 3.5) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9.5, weight: .semibold))
                    Text("高优")
                        .font(.system(size: 10.5, weight: .semibold))
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            filterBinding.wrappedValue = filterBinding.wrappedValue.withHighPriority(false)
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .padding(2)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("filter.all")
                }
                .foregroundStyle(Color.orange)
                .padding(.leading, 7)
                .padding(.trailing, 5)
                .padding(.vertical, 2.5)
                .background(
                    Capsule().fill(Color.orange.opacity(0.12))
                )
                .overlay(
                    Capsule().strokeBorder(Color.orange.opacity(0.4), lineWidth: 0.6)
                )
            } else if let tag = selectedTag {
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 9.5, weight: .semibold))
                    Text("#\(tag.name)")
                        .font(.system(size: 10.5, weight: .semibold))
                        .lineLimit(1)
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            filterBinding.wrappedValue = filterBinding.wrappedValue.withTag(nil)
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .padding(2)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("filter.all")
                }
                .foregroundStyle(Color.white)
                .padding(.leading, 7)
                .padding(.trailing, 5)
                .padding(.vertical, 2.5)
                .background(
                    Capsule().fill(DaybookTheme.stamp)
                )
                .shadow(color: DaybookTheme.stamp.opacity(0.25), radius: 2, y: 1)
            } else {
                Menu {
                    filterMenuContent(filterBinding: filterBinding, activeTags: activeTags)
                } label: {
                    filterCapsuleLabel
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .buttonStyle(DaybookQuietButtonStyle())
                .help("filter.tag")
            }
        }
    }

    @ViewBuilder
    private func filterMenuContent(filterBinding: Binding<BoardFilter>, activeTags: [TagItem]) -> some View {
        let currentTagID = filterBinding.wrappedValue.tagID
        let isHighPriority = filterBinding.wrappedValue.isHighPriorityOnly

        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                filterBinding.wrappedValue = BoardFilter()
            }
        } label: {
            HStack {
                Text(L10n.string("filter.all", locale: locale))
                if !filterBinding.wrappedValue.isActive {
                    Image(systemName: "checkmark")
                }
            }
        }

        Divider()

        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                filterBinding.wrappedValue = filterBinding.wrappedValue.withHighPriority(!isHighPriority)
            }
        } label: {
            HStack {
                Text("★ 仅看高优")
                if isHighPriority {
                    Image(systemName: "checkmark")
                }
            }
        }

        if !activeTags.isEmpty {
            Divider()
            ForEach(activeTags) { tag in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        let nextTag = currentTagID == tag.id ? nil : tag.id
                        filterBinding.wrappedValue = filterBinding.wrappedValue.withTag(nextTag)
                    }
                } label: {
                    HStack {
                        Text("#\(tag.name)")
                        if currentTagID == tag.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }

    private var filterCapsuleLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 9, weight: .medium))
            Text("筛选")
                .font(.system(size: 10.5, weight: .medium))
            Image(systemName: "chevron.down")
                .font(.system(size: 7, weight: .bold))
                .opacity(0.6)
        }
        .foregroundStyle(DaybookTheme.muted)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(DaybookTheme.ink.opacity(0.04))
        )
        .overlay(
            Capsule().strokeBorder(DaybookTheme.rule.opacity(0.4), lineWidth: 0.6)
        )
        .contentShape(Capsule())
    }

    private var todayProgressBadge: some View {
        let progress = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0.0
        let percentage = Int((progress * 100).rounded())

        return HStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(DaybookTheme.rule.opacity(0.4), lineWidth: 1.8)
                    .frame(width: 11, height: 11)
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                    .stroke(
                        percentage == 100 ? DaybookTheme.stamp : Color.orange.opacity(0.85),
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 11, height: 11)
            }

            Text("\(percentage)%")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(DaybookTheme.muted)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(DaybookTheme.ink.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(DaybookTheme.rule.opacity(0.3), lineWidth: 0.6)
        )
        .help("今日进度：已完成 \(completedCount) / \(totalCount) (\(percentage)%)")
    }

    private var workspaceMenuButton: some View {
        Menu {
            Button {
                AppWindows.openWorkspace(tab: .settings)
            } label: {
                Label("window.settings", systemImage: "gearshape")
            }
            Divider()
            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("footer.quit", systemImage: "power")
            }
        } label: {
            Image(systemName: "macwindow")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(DaybookTheme.muted)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(DaybookTheme.ink.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(DaybookTheme.rule.opacity(0.35), lineWidth: 0.6)
                )
                .contentShape(Rectangle())
        } primaryAction: {
            AppWindows.openWorkspace(tab: .today)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(DaybookQuietButtonStyle())
        .help("window.workspace")
        .accessibilityLabel("window.workspace")
    }

    private func refreshHotKey() {
        hotKeyName = HotKeyCenter.shared.displayName(locale: locale)
    }
}

/// 状态栏图标与角标组件
struct MenuBarLabel: View {
    private var dayClock: DayClock { DayClock.shared }
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query private var todos: [TodoItem]
    @Query private var checks: [RoutineCheck]
    @State private var dayTick = Date()

    var body: some View {
        let todayKey: String = {
            _ = dayTick
            return dayClock.todayKey
        }()
        let count = DayBoardLogic.todayBadgeCount(
            routines: routines.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            todos: todos.map(\.snapshot),
            dayKey: todayKey
        )
        return HStack(spacing: 2) {
            Image(systemName: "book.closed.fill")
                .accessibilityHidden(true)
            Text("menubar.today.mark")
                .font(.system(size: 11, weight: .bold, design: .serif))
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
        }
        .accessibilityLabel(count > 0 ? "a11y.app.remaining \(count)" : "a11y.app")
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            DayClock.shared.refresh()
            dayTick = Date()
        }
    }
}
