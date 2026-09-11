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
    }
}

/// 状态栏弹窗底部信息栏
struct FooterBar: View {
    @Environment(\.locale) private var locale
    @State private var hotKeyName = HotKeyCenter.shared.displayName()

    var body: some View {
        HStack(spacing: 8) {
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

            Spacer(minLength: 8)

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
        .onAppear { refreshHotKey() }
        .onChange(of: locale.identifier) { _, _ in refreshHotKey() }
        .onReceive(NotificationCenter.default.publisher(for: .hotKeyDidChange)) { _ in
            refreshHotKey()
        }
        .onReceive(NotificationCenter.default.publisher(for: .appPreferencesDidChange)) { _ in
            refreshHotKey()
        }
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
