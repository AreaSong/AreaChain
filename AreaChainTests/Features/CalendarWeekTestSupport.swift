import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 直接挂载生产周看板；选择只由测试宿主提供，模型和共享导航均隔离/恢复。
@MainActor @Observable
final class CalendarWeekTestSupport {
    typealias Native = SettingsButtonTestSupport
    let fixture: Native
    let restore: () -> Void
    var days: [String]
    var selected: String
    var today: String
    var disabled = false
    var acceptsSelection = true
    var selections: [String] = []
    var inspections: [(UUID, String)] = []
    var drops: [(UUID, String)] = []
    let todos: [TodoItem]
    let original: [TodoSnapshot]

    init(day: String = "2026-09-30", populated: Bool = false, calendar: Calendar = .current) throws {
        fixture = try Native()
        restore = CalendarSpanTestSupport.preserveState()
        days = DayKey.weekKeys(containing: day, calendar: calendar)
        selected = day
        today = day
        todos = populated ? [TodoItem(title: "Synthetic week item", dayKey: day)] : []
        for todo in todos { fixture.container.mainContext.insert(todo) }
        try fixture.container.mainContext.save()
        original = todos.map(\.snapshot)
    }

    func cleanup() { restore(); fixture.cleanup() }

    func board(_ id: String = "week.test") -> some View {
        CalendarWeekBoard(days: days, selectedKey: selected, todayKey: today,
            routines: [], checks: [], todos: todos, listFocused: false, listFocusID: .constant(nil),
            onSelect: { [self] day in
                selections.append(day)
                if acceptsSelection { selected = day }
            }, onInspect: { [self] in inspections.append(($0, $1)) }, onReturnToGrid: {},
            onDropTodo: { [self] in drops.append(($0, $1)) })
            .disabled(disabled)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(id)
    }

    func assertUnchanged() throws {
        #expect(todos.map(\.snapshot) == original)
        #expect(try fixture.container.mainContext.fetchCount(FetchDescriptor<TodoItem>()) == todos.count)
        #expect(!fixture.container.mainContext.hasChanges)
        #expect(drops.isEmpty)
    }

    static func header(_ day: String, host: String = "week.test", in window: NSWindow) throws -> NSObject {
        let nodes = Native.buttons(in: window).filter {
            Native.value($0, "accessibilityIdentifier") as? String == "calendar.week.\(day)"
                && HabitMonthTestSupport.belongs($0, to: host)
        }
        try #require(nodes.count == 1, "列头在指定宿主内必须唯一：\(host)/\(day)")
        return nodes[0]
    }

    /// 只移动包含该列头的横轴，不碰七列自己的纵向偏移。
    static func revealHeader(_ node: NSObject, in window: NSWindow) async throws {
        let frame = try Native.frame(node, in: window)
        let outer = try #require(ScrollNativeEvidence.views(window).compactMap { $0 as? NSScrollView }.first {
            let viewport = $0.convert($0.bounds, to: nil)
            return $0.enclosingScrollView == nil && viewport.minY <= frame.midY && frame.midY <= viewport.maxY
        })
        let document = try #require(outer.documentView)
        document.scrollToVisible(document.convert(frame, from: nil))
        outer.reflectScrolledClipView(outer.contentView)
        try await SystemPageHost.settle(window)
    }

    static func frames(_ days: [String], in window: NSWindow) throws -> [CGRect] {
        try days.map { try Native.frame(header($0, in: window), in: window) }
    }
}

/// 冻结阶段 E 之前的列头，仅供原生像素/命中对照；生产绘制始终只有公共入口。
struct CalendarWeekHeaderBaseline: View {
    var day: String
    var action: () -> Void = {}
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(DayKey.shortStamp(day, locale: locale))
                    .font(DaybookType.caption.weight(.semibold))
                Text(DayKey.dayNumber(day, calendar: calendar))
                    .font(DaybookType.title)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(DaybookButtonStyle(.quiet))
        .accessibilityIdentifier("calendar.week.\(day)")
    }
}
