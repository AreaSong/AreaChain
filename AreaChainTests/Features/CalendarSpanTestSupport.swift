import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 直接挂载生产日历；仅观察页头 preference，不镜像或注入 span、draft、keyboardFocus。
@MainActor
final class CalendarSpanTestSupport {
    typealias Native = SettingsButtonTestSupport
    let fixture: Native
    let window: NSWindow
    let locale: String
    let todos: [TodoItem]
    let originalTodos: [TodoSnapshot]
    let probe = CalendarHeaderProbe()
    let restore: () -> Void
    var context: ModelContext { fixture.container.mainContext }
    var selectedKey: String { BoardSelection.shared.inspectingDayKey }

    init(width: CGFloat = 1000, locale: String = "en", scheme: ColorScheme = .light,
         embedded: Bool = false, day: String = "2026-09-30", height: CGFloat = 760) throws {
        fixture = try Native()
        self.locale = locale
        restore = Self.preserveState()
        WorkspaceNavigation.shared.revealTab(.calendar)
        WorkspaceNavigation.shared.clearSearch()
        BoardSelection.shared.inspectingDayKey = day
        let tag = TagItem(name: "QA", sortOrder: 0)
        fixture.container.mainContext.insert(tag)
        todos = [
            TodoItem(title: "Synthetic selected first", dayKey: day),
            TodoItem(title: "Synthetic selected second", dayKey: day),
            TodoItem(title: "Synthetic adjacent", dayKey: DayKey.shifted(day, by: 1)),
            TodoItem(title: "Synthetic outside week", dayKey: DayKey.shifted(day, by: 14))
        ]
        for todo in todos {
            todo.tagIDs = tag.id.uuidString
            fixture.container.mainContext.insert(todo)
        }
        try fixture.container.mainContext.save()
        originalTodos = todos.map(\.snapshot)
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let root = CalendarSpanHost(page: CalendarPage(todayKey: day, routines: [], checks: [], todos: todos),
                                    probe: probe, embedded: embedded, width: width)
            .environment(\.calendar, calendar)
        window = SystemPageHost.window(root, container: fixture.container, scheme: scheme, locale: locale,
                                       size: NSSize(width: width, height: height), embedded: embedded, prefs: fixture.prefs)
    }

    func close() {
        SystemPageHost.release(window)
        restore()
        fixture.cleanup()
    }

    func prepare() async throws {
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
    }

    func text(_ key: String) -> String { MenuButtonTestSupport.localized(key, locale) }

    /// ViewThatFits 的未采用候选仍可存在于 NSView 树；须同时检查祖先可见性和实际命中。
    func visible(_ node: NSObject) -> Bool {
        guard let rect = try? Native.frame(node, in: window), !rect.isEmpty,
              let content = window.contentView, content.bounds.contains(rect) else { return false }
        if let view = node as? NSView, view.isHiddenOrHasHiddenAncestor { return false }
        var ancestor: NSObject? = node
        var ancestors = Set<ObjectIdentifier>()
        while let current = ancestor, ancestors.insert(ObjectIdentifier(current)).inserted {
            // SwiftUI 按钮没有对应 NSControl。其当前 AX 父链必须抵达可见 hosting view。
            if current === content { return true }
            if let view = current as? NSView, view !== content {
                guard view.window === window, !view.isHiddenOrHasHiddenAncestor else { return false }
                let point = content.convert(NSPoint(x: rect.midX, y: rect.midY), from: nil)
                if let hit = content.hitTest(point), hit === view || hit.isDescendant(of: view) { return true }
            }
            ancestor = Native.value(current, "accessibilityParent") as? NSObject
        }
        let screen = window.convertPoint(toScreen: NSPoint(x: rect.midX, y: rect.midY))
        var hit = content.accessibilityHitTest(screen) as? NSObject
        var visited = Set<ObjectIdentifier>()
        while let current = hit, visited.insert(ObjectIdentifier(current)).inserted {
            if current === node { return true }
            if let frame = try? Native.frame(current, in: window), frame == rect,
               MenuButtonTestSupport.title(current) == MenuButtonTestSupport.title(node) { return true }
            hit = Native.value(current, "accessibilityParent") as? NSObject
        }
        return false
    }

    func nodes() -> [NSObject] { Native.elements(window.contentView).filter(visible) }

    func node(_ key: String) throws -> NSObject {
        let candidates = Native.elements(window.contentView).filter {
            Native.value($0, "accessibilityIdentifier") as? String == key
                || MenuButtonTestSupport.title($0) == text(key)
        }
        let matches = candidates.filter(visible)
        try #require(matches.count == 1, "可见入口必须唯一：\(key)，实际 \(matches.count)")
        return try #require(matches.first)
    }

    func switchSpan(_ span: CalendarSpan) async throws {
        let target = try node("calendar.span." + span.rawValue)
        try Native.assertBounds([target], in: window)
        try #require(window.isKeyWindow)
        let rect = try Native.frame(target, in: window)
        let point = NSPoint(x: rect.midX, y: rect.midY)
        // 原生对照的 mouseDown 同步进入追踪循环，释放事件必须预先进入队列。
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            NSApp.postEvent(try MenuButtonTestSupport.mouse(type, at: point, in: window), atStart: false)
        }
        try await SystemPageHost.settle(window)
    }

    func key(_ code: UInt16, chars: String = "") async throws {
        try #require(window.isKeyWindow)
        NSApp.postEvent(try PickerNativeTestSupport.key(code: code, chars: chars, in: window), atStart: false)
        try await SystemPageHost.settle(window)
    }

    func assertSpan(_ span: CalendarSpan) throws {
        let action = try #require(probe.content.actions.first { $0.id == "calendar.span" })
        #expect(action.children.map(\.id) == ["calendar.month", "calendar.week"])
        #expect(action.children.filter(\.isActive).map(\.id) == ["calendar." + span.rawValue])
        for item in CalendarSpan.allCases {
            let target = try node("calendar.span." + item.rawValue)
            if Native.value(target, "accessibilityRole") as? String == "AXRadioButton" {
                #expect((Native.value(target, "accessibilityValue") as? NSNumber)?.boolValue == (item == span))
            } else {
                #expect((target.value(forKey: "accessibilitySelected") as? NSNumber)?.boolValue == (item == span))
            }
        }
    }

    func assertWeekProjection() {
        let identifiers = Set(Native.elements(window.contentView).compactMap {
            Native.value($0, "accessibilityIdentifier") as? String
        }.filter { $0.hasPrefix("calendar.week.20") })
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        #expect(identifiers == Set(DayKey.weekKeys(containing: selectedKey, calendar: calendar).map {
            "calendar.week." + $0
        }))
    }

    func field() throws -> DaybookAppKitTextField {
        try #require(Native.elements(window.contentView).compactMap { $0 as? DaybookAppKitTextField }.first {
            $0.placeholderString == text("calendar.add") && !$0.isHiddenOrHasHiddenAncestor
                && $0.visibleRect.width > 0
        })
    }

    func assertUnchanged() throws {
        #expect(try context.fetchCount(FetchDescriptor<TodoItem>()) == 4)
        #expect(try context.fetchCount(FetchDescriptor<TagItem>()) == 1)
        #expect(todos.allSatisfy { !$0.isDone && !$0.tagIDs.isEmpty })
        #expect(todos.map(\.snapshot) == originalTodos)
        #expect(!context.hasChanges)
    }

    static func preserveState() -> () -> Void {
        let selection = BoardSelection.shared
        let day = selection.inspectingDayKey, diaryDay = selection.diaryDayKey
        let diaryID = selection.inspectingDiaryID, discard = selection.discardEditsOnBlur
        let nav = WorkspaceNavigation.shared
        let listing = MenuButtonTestSupport.preserveListingNavigation()
        let targets = nav.inspectorTargetIDs
        let tab = nav.selectedTab, tag = nav.selectedTagID, inlineTitle = nav.isInlineTitleVisible
        let pending = nav.pendingLaneSession, filter = nav.pendingFilter, trash = nav.focusedTrashID
        let search = nav.searchQuery, searchFocused = nav.isSearchFocused, searchIndex = nav.searchResultIndex
        return {
            nav.selectedTab = tab
            nav.selectedTagID = tag
            nav.isInlineTitleVisible = inlineTitle
            nav.pendingLaneSession = pending
            nav.pendingFilter = filter
            nav.focusedTrashID = trash
            nav.searchQuery = search
            nav.isSearchFocused = searchFocused
            nav.searchResultIndex = searchIndex
            nav.updateInspectorTargets(targets)
            listing()
            selection.inspectingDayKey = day
            selection.diaryDayKey = diaryDay
            selection.inspectingDiaryID = diaryID
            selection.discardEditsOnBlur = discard
        }
    }
}

@MainActor
final class CalendarHeaderProbe {
    var content = WorkspaceHeaderContent()
}

private struct CalendarSpanHost: View {
    let page: CalendarPage
    let probe: CalendarHeaderProbe
    let embedded: Bool
    let width: CGFloat

    var body: some View {
        page
            .padding(.top, embedded ? WorkspaceHeaderGeometry(width: width).height : 0)
            .overlayPreferenceValue(WorkspaceHeaderContentKey.self, alignment: .top) { content in
                if embedded {
                    WorkspaceHeaderBar(navigation: .shared, tags: [], content: content)
                        .frame(height: WorkspaceHeaderGeometry(width: width).height)
                }
            }
            .backgroundPreferenceValue(WorkspaceHeaderContentKey.self) { content in
                observe(content)
            }
    }

    private func observe(_ content: WorkspaceHeaderContent) -> some View {
        probe.content = content
        return Color.clear.frame(width: 0, height: 0)
    }
}
