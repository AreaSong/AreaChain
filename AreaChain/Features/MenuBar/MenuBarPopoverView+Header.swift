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

            Spacer(minLength: 8)

            DaybookSegmentedBar(
                selection: $tab,
                tasksCount: todayRemaining,
                diariesCount: todayDiariesCount
            )
            .padding(.top, 1)
        }
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
                    Circle() // token-exempt: 头部状态圆点
                        .fill(DaybookPalette.status.pending)
                        .frame(width: 5, height: 5)
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
                    Circle() // token-exempt: 头部状态圆点
                        .fill(DaybookPalette.accent.base)
                        .frame(width: 5, height: 5)
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
