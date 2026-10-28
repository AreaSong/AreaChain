import AppKit
import SwiftData
import SwiftUI

extension MenuBarPopoverView {
    var todayKey: String {
        _ = dayTick
        return dayClock.todayKey
    }

    var todayDiariesCount: Int {
        DayBoardLogic.diaries(for: todayKey, in: diaries.map(\.snapshot)).count
    }

    var todayRemaining: Int {
        DayBoardLogic.todayBadgeCount(
            routines: routines.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            todos: todos.map(\.snapshot),
            dayKey: todayKey
        )
    }

    var todayCompleted: Int {
        DayBoardLogic.completedRoutines(
            routines: routines.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            dayKey: todayKey
        ).count
            + DayBoardLogic.completedTodos(todos: todos.map(\.snapshot), dayKey: todayKey).count
    }

    var headerSubtitle: LocalizedStringKey {
        if toolbar.isSearching { return "search.scope.all" }
        switch tab {
        case .tasks:
            if todayRemaining > 0 { return "header.today.remaining \(todayRemaining)" }
            return todayCompleted > 0 ? "header.today.done" : "header.today.empty"
        case .diary:
            let count = todayDiariesCount
            if count == 0 {
                return "header.diary.empty"
            }
            return "header.diary.count \(count)"
        }
    }

    var integratedHeader: some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 3) {
                Text(DayKey.displayName(todayKey, locale: locale))
                    .font(DaybookType.title)
                    .foregroundStyle(DaybookPalette.text.primary)
                HStack(spacing: 4) {
                    headerIndicator
                        .animation(DaybookMotion.interactive(reduceMotion), value: tab)
                        .animation(DaybookMotion.interactive(reduceMotion), value: todayRemaining)
                        .animation(DaybookMotion.interactive(reduceMotion), value: todayDiariesCount)

                    Text(headerSubtitle)
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.secondary)
                        .contentTransition(.numericText())
                        .animation(DaybookMotion.interactive(reduceMotion), value: tab)
                        .animation(DaybookMotion.interactive(reduceMotion), value: todayRemaining)
                        .animation(DaybookMotion.interactive(reduceMotion), value: todayDiariesCount)
                }
            }

            Spacer(minLength: 4)

            headerCenterStatusBar
                .zIndex(2)

            Spacer(minLength: 4)

            DaybookSegmentedBar(
                selection: $tab,
                tasksCount: todayRemaining,
                diariesCount: todayDiariesCount
            )
            .padding(.top, 1)
        }
        .overlay(alignment: .topLeading) {
            #if DEBUG
            MenuBarHeaderDebugBadgeOverlay()
            #endif
        }
    }

    var headerCenterStatusBar: some View {
        MenuBarCenterStatusBar()
    }

    @ViewBuilder
    var headerIndicator: some View {
        if toolbar.isSearching {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 7, weight: .bold)) // token-exempt: 头部状态图标小于 9pt
                .foregroundStyle(DaybookPalette.text.secondary)
                .transition(.scale.combined(with: .opacity))
        } else {
            switch tab {
            case .tasks:
                if todayRemaining > 0 {
                    DaybookStatusDot(color: DaybookPalette.status.pending, size: 5)
                        .transition(.scale.combined(with: .opacity))
                } else if todayCompleted > 0 {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .bold)) // token-exempt: 头部状态图标小于 9pt
                        .foregroundStyle(DaybookPalette.accent.base)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .bold)) // token-exempt: 头部状态图标小于 9pt
                        .foregroundStyle(DaybookPalette.text.tertiary)
                        .transition(.scale.combined(with: .opacity))
                }
            case .diary:
                if todayDiariesCount > 0 {
                    DaybookStatusDot(color: DaybookPalette.accent.base, size: 5)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "feather")
                        .font(.system(size: 8, weight: .semibold)) // token-exempt: 头部状态图标小于 9pt
                        .foregroundStyle(DaybookPalette.text.tertiary)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
}

private struct MenuBarCenterStatusBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var noticeCenter: DaybookStatusNoticeCenter = .shared
    @Bindable var vault: PrivacyVault = .shared
    @State private var activeNotice: DaybookStatusNoticeCenter.Kind? = DaybookStatusNoticeCenter.shared.current

    private var effectiveNotice: DaybookStatusNoticeCenter.Kind? {
        _ = noticeCenter.revision
        return activeNotice ?? noticeCenter.current
    }

    var body: some View {
        Group {
            if let notice = effectiveNotice {
                DaybookStatusNoticePill(kind: notice)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
            } else if vault.isUnlocked {
                WorkspacePrivacyUnlockedButton(vault: vault)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
        }
        .animation(DaybookMotion.interactive(reduceMotion), value: effectiveNotice)
        .animation(DaybookMotion.interactive(reduceMotion), value: vault.isUnlocked)
        .onAppear {
            activeNotice = noticeCenter.current
        }
        .onChange(of: noticeCenter.revision) { _, _ in
            withAnimation(DaybookMotion.interactive(reduceMotion)) {
                activeNotice = noticeCenter.current
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .daybookStatusNoticeDidChange)) { _ in
            withAnimation(DaybookMotion.interactive(reduceMotion)) {
                activeNotice = noticeCenter.current
            }
        }
    }
}

#if DEBUG
private struct MenuBarHeaderDebugBadgeOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var noticeCenter: DaybookStatusNoticeCenter = .shared
    @Bindable var vault: PrivacyVault = .shared
    @State private var hasNotice: Bool = DaybookStatusNoticeCenter.shared.current != nil

    private var isHidden: Bool {
        _ = noticeCenter.revision
        return hasNotice || noticeCenter.current != nil || vault.isUnlocked
    }

    var body: some View {
        DaybookDebugBadge()
            .scaleEffect(0.78, anchor: .topLeading)
            .offset(x: 92, y: -4)
            .opacity(isHidden ? 0 : 1)
            .allowsHitTesting(false)
            .animation(DaybookMotion.interactive(reduceMotion), value: isHidden)
            .onAppear {
                hasNotice = noticeCenter.current != nil
            }
            .onChange(of: noticeCenter.revision) { _, _ in
                hasNotice = noticeCenter.current != nil
            }
            .onReceive(NotificationCenter.default.publisher(for: .daybookStatusNoticeDidChange)) { _ in
                hasNotice = noticeCenter.current != nil
            }
    }
}
#endif
