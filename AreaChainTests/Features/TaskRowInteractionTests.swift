import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct TaskRowInteractionTests {
    private static var retainedContainers: [ModelContainer] = []

    @Test(arguments: [false, true])
    func checkboxRespondsImmediatelyWithoutSelectingOrEditing(isDone: Bool) async throws {
        let probe = RowActionProbe()
        let window = host(row(isDone: isDone, probe: probe))
        defer { close(window) }
        try await settle(window)
        let start = ProcessInfo.processInfo.systemUptime
        try click(NSPoint(x: 18, y: 30), in: window, modifiers: .shift)
        let milliseconds = (ProcessInfo.processInfo.systemUptime - start) * 1_000
        #expect(probe.toggleCount == 1)
        #expect(probe.selections.isEmpty)
        #expect(editor(in: window.contentView) == nil)
        #expect(milliseconds < 100, "完成按钮不能等待双击超时")
        print("ROW_LATENCY checkbox done=\(isDone) ms=\(milliseconds)")
    }

    @Test func middleTitleAndWhitespaceSelectImmediatelyAndCarryEventModifiers() async throws {
        let probe = RowActionProbe()
        let window = host(row(probe: probe))
        defer { close(window) }
        try await settle(window)
        for point in [NSPoint(x: 60, y: 30), NSPoint(x: 240, y: 42)] {
            let count = probe.selections.count
            let start = ProcessInfo.processInfo.systemUptime
            try click(point, in: window, modifiers: [.shift, .command])
            let milliseconds = (ProcessInfo.processInfo.systemUptime - start) * 1_000
            #expect(probe.selections.count == count + 1)
            #expect(probe.selections.last == [.shift, .command])
            #expect(milliseconds < 100, "选中反馈不能等待双击超时")
            print("ROW_LATENCY selection ms=\(milliseconds)")
        }
        #expect(probe.toggleCount == 0)
        #expect(editor(in: window.contentView) == nil)
    }

    @Test func middleDoubleClickSelectsFirstThenFocusesEditor() async throws {
        let probe = RowActionProbe()
        let window = host(row(probe: probe))
        defer { close(window) }
        try await settle(window)
        try click(NSPoint(x: 220, y: 30), in: window)
        #expect(probe.selections.count == 1)
        #expect(editor(in: window.contentView) == nil)
        try click(NSPoint(x: 220, y: 30), in: window, clickCount: 2)
        try await settle(window)
        let field = try #require(editor(in: window.contentView))
        #expect(field.currentEditor() != nil)
        #expect(field.stringValue == "测试任务")
        #expect(field.bounds.width > 150)
        try snapshot(window, name: "row-editing")
        #expect(probe.toggleCount == 0)
        let count = probe.selections.count
        try await Task.sleep(for: .milliseconds(400))
        #expect(probe.selections.count == count, "不能留下延迟触发的单击动作")
    }

    @Test func shiftDoubleClickOnlyExtendsSelection() async throws {
        let probe = RowActionProbe()
        let window = host(row(probe: probe))
        defer { close(window) }
        try await settle(window)
        try click(NSPoint(x: 120, y: 30), in: window, modifiers: .shift)
        try click(NSPoint(x: 120, y: 30), in: window, modifiers: .shift, clickCount: 2)
        try await settle(window)
        #expect(probe.selections == [.shift, .shift])
        #expect(probe.toggleCount == 0)
        #expect(editor(in: window.contentView) == nil)
    }

    @Test(arguments: [false, true])
    func editingCanCancelOrSaveWithoutChangingCompletion(save: Bool) async throws {
        let probe = RowActionProbe()
        let window = host(row(probe: probe))
        defer { close(window) }
        try await settle(window)
        try click(NSPoint(x: 140, y: 30), in: window)
        try click(NSPoint(x: 140, y: 30), in: window, clickCount: 2)
        try await settle(window)
        let textView = try #require(editor(in: window.contentView)?.currentEditor() as? NSTextView)
        textView.selectAll(nil)
        textView.insertText("修改后的任务", replacementRange: textView.selectedRange())
        let character = save ? "\r" : "\u{1B}"
        let key = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, characters: character, charactersIgnoringModifiers: character,
            isARepeat: false, keyCode: save ? 36 : 53
        ))
        let board = DayBoardList(dayKey: "2026-09-12", routines: [], checks: [], todos: [])
        #expect(board.handleTextViewEditingKey(event: key, firstResponder: textView) === key)
        window.sendEvent(key)
        try await settle(window)
        #expect(probe.editedTitles == (save ? ["修改后的任务"] : []))
        #expect(probe.toggleCount == 0)
        #expect(editor(in: window.contentView) == nil)
    }

    @Test func selectedRowRendersInBothAppearances() async throws {
        for scheme in [ColorScheme.light, .dark] {
            let window = host(row(isSelected: true, probe: RowActionProbe()), scheme: scheme)
            try await settle(window)
            try snapshot(window, name: scheme == .light ? "selected-row-light" : "selected-row-dark")
            close(window)
        }
    }

    @Test func allRowFactoriesForwardSelectionModifiers() throws {
        let container = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let todo = TodoItem(title: "待办", dayKey: "2026-09-12")
        let routine = DailyRoutine(title: "习惯", sortOrder: 0, createdDayKey: "2026-09-12")
        context.insert(todo)
        context.insert(routine)
        try context.save()
        let catalogs = TaskCatalogContext(projects: [], tags: [], attachments: [], context: context)
        var received: [TaskSelectionModifiers] = []
        let todoRow = TaskRowFactory.todo(TodoRowContext(
            todo: todo, todayKey: "2026-09-12", catalogs: catalogs, display: TodoRowDisplayOptions(isDone: false),
            actions: TodoRowActions(onSelect: { received.append($0) }, onDelete: {})
        ))
        let routineRow = TaskRowFactory.routine(RoutineRowContext(
            routine: routine, schedule: RoutineScheduleContext(todayKey: "2026-09-12", checkDayKey: "2026-09-12", checks: []),
            catalogs: catalogs, display: RoutineRowDisplayOptions(isDone: false),
            actions: RoutineRowActions(onSelect: { received.append($0) }, onDelete: {})
        ))
        let leftoverRow = TaskRowFactory.leftoverFallback(LeftoverRowContext(
            item: UnfinishedItem(id: todo.id, title: todo.title, kind: .todo), todayKey: "2026-09-12",
            yesterdayKey: "2026-09-11", isSelected: false,
            actions: LeftoverRowActions(onToggle: {}, onSelect: { received.append($0) })
        ))
        [todoRow, routineRow, leftoverRow].forEach { $0.dispatch(.select([.shift, .command])) }
        #expect(received == Array(repeating: [.shift, .command], count: 3))
    }

    @Test func draggingBackToStartDoesNotBecomeDoubleClickEditing() async throws {
        let probe = RowActionProbe()
        let window = host(row(probe: probe))
        defer { close(window) }
        try await settle(window)
        try send(.leftMouseDown, at: NSPoint(x: 120, y: 30), in: window, clickCount: 2)
        try send(.leftMouseDragged, at: NSPoint(x: 145, y: 30), in: window, clickCount: 2)
        try send(.leftMouseUp, at: NSPoint(x: 120, y: 30), in: window, clickCount: 2)
        try await settle(window)
        #expect(probe.toggleCount == 0)
        #expect(editor(in: window.contentView) == nil)
    }

    @Test func openingMoreMenuDoesNotSelectCompleteOrEdit() async throws {
        let probe = RowActionProbe()
        let window = host(row(isSelected: true, probe: probe))
        defer { close(window) }
        try await settle(window)
        let observer = NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification, object: nil, queue: nil
        ) { notification in
            MainActor.assumeIsolated {
                probe.menuOpened = true
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        // 原生菜单在 mouseDown 内进入追踪循环，先排入 mouseUp 和 Escape，不能等返回后才发送。
        let point = NSPoint(x: 361, y: 30)
        let mouseUp = try #require(NSEvent.mouseEvent(
            with: .leftMouseUp, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 0
        ))
        let escape = try #require(NSEvent.keyEvent(
            with: .keyDown, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, characters: "\u{1B}", charactersIgnoringModifiers: "\u{1B}",
            isARepeat: false, keyCode: 53
        ))
        NSApp.postEvent(mouseUp, atStart: false)
        NSApp.postEvent(escape, atStart: false)
        try send(.leftMouseDown, at: point, in: window)
        try await settle(window)
        #expect(probe.menuOpened)
        #expect(probe.selections.isEmpty)
        #expect(probe.toggleCount == 0)
        #expect(editor(in: window.contentView) == nil)
    }

    @Test func dayBoardShiftSelectionAndCheckboxAreIndependent() async throws {
        let container = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        Self.retainedContainers.append(container)
        let context = container.mainContext
        let titles = ["整理资料", "核对清单", "准备评审", "记录进展", "归档结果"]
        let todos = titles.map { TodoItem(title: $0, dayKey: "2026-09-12") }
        todos.forEach { context.insert($0) }
        try context.save()
        let probe = RowActionProbe()
        let board = DayBoardList(
            dayKey: "2026-09-12", routines: [], checks: [], todos: todos,
            config: DayBoardListConfig(interaction: DayBoardInteraction(
                focusedTaskID: Binding(get: { probe.focusedID }, set: { probe.focusedID = $0 })
            ))
        )
        let content = VStack(alignment: .leading, spacing: 6) { board; Spacer() }
            .padding(12).modelContainer(container)
            .environment(\.locale, Locale(identifier: "zh-Hans"))
        let window = host(content, size: NSSize(width: 380, height: 400))
        defer { close(window) }
        try await settle(window)
        try click(center(of: todos[1].id, in: window), in: window)
        try click(center(of: todos[3].id, in: window), in: window, modifiers: .shift)
        try await settle(window)
        #expect(probe.focusedID == todos[3].id)
        try snapshot(window, name: "dayboard-shift-selection")
        let target = try center(of: todos[2].id, in: window)
        try click(NSPoint(x: 30, y: target.y), in: window)
        try await settle(window)
        #expect(todos[2].isDone)
        #expect(todos.enumerated().allSatisfy { $0.offset == 2 || !$0.element.isDone })
        #expect(editor(in: window.contentView) == nil)
    }

    private func row(isDone: Bool = false, isSelected: Bool = false, probe: RowActionProbe) -> some View {
        TaskRow(state: TaskRowState(
            identity: TaskRowIdentityState(title: "测试任务", isDone: isDone),
            interaction: TaskRowInteractionState(selection: TaskRowSelectionState(isSelected: isSelected))
        ), dispatch: probe.record)
    }

    private func host<Content: View>(_ content: Content, size: NSSize = NSSize(width: 380, height: 60),
                                    scheme: ColorScheme = .light) -> NSWindow {
        NSApp.setActivationPolicy(.regular)
        let hosting = NSHostingView(rootView: content
            .frame(width: size.width, height: size.height)
            .background(DaybookTheme.paper)
            .environment(\.locale, Locale(identifier: "zh-Hans"))
            .preferredColorScheme(scheme))
        hosting.safeAreaRegions = []
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "AreaChain 任务交互测试"
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: scheme == .light ? .aqua : .darkAqua)
        window.contentView = hosting
        window.setContentSize(size)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return window
    }

    private func close(_ window: NSWindow) {
        window.contentView = nil
        window.orderOut(nil)
    }

    private func settle(_ window: NSWindow) async throws {
        window.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(180))
        window.contentView?.layoutSubtreeIfNeeded()
    }

    private func click(_ point: NSPoint, in window: NSWindow, modifiers: NSEvent.ModifierFlags = [], clickCount: Int = 1) throws {
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            try send(type, at: point, in: window, modifiers: modifiers, clickCount: clickCount)
        }
    }

    private func send(_ type: NSEvent.EventType, at point: NSPoint, in window: NSWindow,
                      modifiers: NSEvent.ModifierFlags = [], clickCount: Int = 1) throws {
        let event = try #require(NSEvent.mouseEvent(
            with: type, location: point, modifierFlags: modifiers, timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: clickCount, pressure: 1
        ))
        window.sendEvent(event)
    }

    private func editor(in view: NSView?) -> NSTextField? {
        guard let view else { return nil }
        if let field = view as? DaybookAppKitTextField { return field }
        return view.subviews.lazy.compactMap { editor(in: $0) }.first
    }

    private func center(of id: UUID, in window: NSWindow) throws -> NSPoint {
        let region = try #require(findRegion(id, in: window.contentView))
        let bounds = region.convert(region.bounds, to: nil)
        return NSPoint(x: bounds.midX, y: bounds.midY)
    }

    private func findRegion(_ id: UUID, in view: NSView?) -> TaskRowPointerView? {
        guard let view else { return nil }
        if let region = view as? TaskRowPointerView, region.identifier?.rawValue == id.uuidString { return region }
        return view.subviews.lazy.compactMap { findRegion(id, in: $0) }.first
    }

    private func snapshot(_ window: NSWindow, name: String) throws {
        let view = try #require(window.contentView)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AreaChain-Row-Interaction-QA")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name + ".png")
        try png.write(to: url, options: .atomic)
        print("ROW_QA \(url.path)")
    }
}

@MainActor
private final class RowActionProbe {
    var toggleCount = 0
    var selections: [TaskSelectionModifiers] = []
    var menuOpened = false
    var focusedID: UUID?
    var editedTitles: [String] = []

    func record(_ action: TaskRowAction) {
        switch action {
        case .toggleDone: toggleCount += 1
        case .select(let modifiers): selections.append(modifiers)
        case .editTitle(let title): editedTitles.append(title)
        default: break
        }
    }
}
