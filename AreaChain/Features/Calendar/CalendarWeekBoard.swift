import SwiftData
import SwiftUI

/// 周聚焦模式的顶部 7 天横排周历条：一屏展示整周日期与未完成数，支持点击切换与拖入待办改期。
struct CalendarWeekStrip: View {
    var days: [String]
    var todayKey: String
    var selectedKey: String
    var counts: [String: Int]
    var onSelect: (String) -> Void
    var onDropTodo: ((UUID, String) -> Void)? = nil

    @State private var dropKey: String?

    var body: some View {
        VStack(spacing: DaybookSpacing.xs) {
            DaybookWeekdayHeader()
            HStack(spacing: DaybookSpacing.xs) {
                ForEach(days, id: \.self) { key in
                    cell(key)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("calendar.week.strip")
    }

    private func cell(_ key: String) -> some View {
        let count = counts[key] ?? 0
        return DaybookDateCell(
            dayKey: key,
            isToday: key == todayKey,
            isSelected: key == selectedKey,
            presentation: .monthGrid(.regular),
            annotation: count > 0 ? Text("\(count)") : nil,
            isDropTarget: dropKey == key
        ) {
            onSelect(key)
        }
        .accessibilityIdentifier("calendar.week.\(key)")
        .dropDestination(for: String.self) { items, _ in
            guard let onDropTodo, let id = items.compactMap(TodoDragToken.decode).first else {
                return false
            }
            onDropTodo(id, key)
            return true
        } isTargeted: { hovering in
            withAnimation(DaybookMotion.snappy) {
                dropKey = hovering ? key : (dropKey == key ? nil : dropKey)
            }
        }
        .accessibilityHint(count > 0 ? Text("a11y.calendar.remaining \(count)") : Text(""))
    }
}

/// 日历的一周：七天按同一列宽排开。页面足够宽时一屏铺满，窄窗口横向滚动；待办可以拖到另一天改期。
struct CalendarWeekBoard: View {
    @Environment(\.locale) private var locale

    var days: [String]
    var selectedKey: String
    var todayKey: String
    var routines: [DailyRoutine]
    var checks: [RoutineCheck]
    var todos: [TodoItem]
    var listFocused: Bool
    var listFocusID: Binding<UUID?>
    var onSelect: (String) -> Void
    var onInspect: (UUID, String) -> Void
    var onReturnToGrid: () -> Void
    var onDropTodo: (UUID, String) -> Void

    var body: some View {
        GeometryReader { geometry in
            let spacing = DaybookMetrics.WeekBoard.columnSpacing
            let count = CGFloat(max(days.count, 1))
            let width = max(DaybookMetrics.WeekBoard.minimumColumnWidth,
                            (geometry.size.width - spacing * (count - 1)) / count)
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: spacing) {
                        ForEach(days, id: \.self) { day in
                            column(day, width: width, height: geometry.size.height)
                                .id(day)
                        }
                    }
                }
                // 横轴使用系统承载，公共 daybookScroll 仍只属于列内纵轴。
                .task(id: VisibilityRequest(days: days, selectedKey: selectedKey)) {
                    // 等待本轮列身份装配；选择/周变化和卸载会取消旧请求。
                    await Task.yield()
                    guard !Task.isCancelled, days.contains(selectedKey) else { return }
                    if let first = days.first, days.prefix(3).contains(selectedKey) {
                        proxy.scrollTo(first, anchor: .leading)
                    } else {
                        proxy.scrollTo(selectedKey, anchor: .center)
                    }
                }
            }
        }
    }

    private struct VisibilityRequest: Equatable {
        var days: [String]
        var selectedKey: String
    }

    private func column(_ day: String, width: CGFloat, height: CGFloat) -> some View {
        let selected = day == selectedKey
        return VStack(alignment: .leading, spacing: 6) {
            DaybookDateCell(dayKey: day, isToday: day == todayKey, isSelected: selected,
                            presentation: .weekHeader(shortStamp: DayKey.shortStamp(day, locale: locale))) {
                onSelect(day)
            }
            .accessibilityIdentifier("calendar.week.\(day)")
            ScrollView {
                DayBoardList(
                    dayKey: day,
                    routines: routines,
                    checks: checks,
                    todos: todos,
                    config: DayBoardListConfig(
                        todayKey: todayKey,
                        allowsTodoDrag: true,
                        interaction: DayBoardInteraction(
                            focusedTaskID: listFocused && selected ? listFocusID : nil,
                            highlightedTaskID: listFocused && selected ? listFocusID.wrappedValue : nil,
                            onInspect: { onInspect($0, day) },
                            onReturnToInput: onReturnToGrid
                        )
                    )
                )
            }
            .daybookScroll()
        }
        .padding(6)
        .frame(width: width, height: height, alignment: .topLeading)
        .clipped()
        .daybookSurface(.card, isSelected: selected)
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.compactMap(TodoDragToken.decode).first else { return false }
            onDropTodo(id, day)
            return true
        }
    }
}

enum CalendarDayFocus {
    static func firstOpenID(
        dayKey: String,
        routines: [DailyRoutine],
        checks: [RoutineCheck],
        todos: [TodoItem]
    ) -> UUID? {
        let routineSnaps = routines.map(\.snapshot)
        let checkSnaps = checks.compactMap(\.snapshot)
        let todoSnaps = todos.map(\.snapshot)
        let openRoutineIDs = Set(DayBoardLogic.openRoutines(
            routines: routineSnaps, checks: checkSnaps, dayKey: dayKey
        ).map(\.id))
        let openTodoIDs = Set(DayBoardLogic.openTodos(todos: todoSnaps, dayKey: dayKey).map(\.id))
        let rows = routines.filter { openRoutineIDs.contains($0.id) }.map(BoardRow.resident)
            + todos.filter { openTodoIDs.contains($0.id) }.map(BoardRow.todo)
        return rows.sorted {
            Classification.precedes($0.boardSortKey(listDay: dayKey), $1.boardSortKey(listDay: dayKey))
        }.first?.id
    }
}
