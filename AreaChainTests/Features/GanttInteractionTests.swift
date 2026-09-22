import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct GanttInteractionTests {
    private static var retainedContainers: [ModelContainer] = []

    @Test func commandClickSelectsMoreThanOneTodo() async throws {
        let host = try makeHost()
        defer { host.close() }
        try await host.settle()
        try await host.clickTitle(host.todos[0])
        try await host.clickTitle(host.todos[1], modifiers: .command)
        #expect(host.selectedIDs == Set(host.todos.prefix(2).map(\.id)))
        #expect(host.todos.map(\.dayKey) == ["2026-09-10", "2026-09-14", "2026-09-16"])
        try host.snapshot("command-selection")
        try await host.clickTitle(host.todos[0], modifiers: .command)
        #expect(host.selectedIDs == [host.todos[1].id])
    }

    @Test func barClicksSupportCommandAndShiftSelection() async throws {
        let host = try makeHost()
        defer { host.close() }
        try await host.settle()
        try await host.clickBar(host.todos[0])
        try await host.clickBar(host.todos[2], modifiers: .command)
        #expect(host.selectedIDs == [host.todos[0].id, host.todos[2].id])
        try await host.clickBar(host.todos[1])
        #expect(host.selectedIDs == [host.todos[1].id])
        try await host.clickBar(host.todos[2], modifiers: .shift)
        #expect(host.selectedIDs == [host.todos[1].id, host.todos[2].id])
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func dragShowsOneBarPerTaskAndCommitsTheWholeSelection(scheme: ColorScheme) async throws {
        let host = try makeHost(scheme: scheme)
        defer { host.close() }
        try await host.settle()
        try await host.clickBar(host.todos[0])
        try await host.clickBar(host.todos[1], modifiers: .command)
        let start = try host.barCenter(host.todos[1])
        let end = NSPoint(x: start.x + 44, y: start.y)
        try host.send(.leftMouseDown, at: start)
        try host.send(.leftMouseDragged, at: end)
        try await host.settle()
        #expect(host.selectedIDs == Set(host.todos.prefix(2).map(\.id)))
        #expect(host.todos.map(\.dayKey) == ["2026-09-10", "2026-09-14", "2026-09-16"])
        #expect(try host.filledDays(host.todos[0]) == [12])
        #expect(try host.filledDays(host.todos[1]) == [16])
        #expect(try host.filledDays(host.todos[2]) == [16])
        try host.snapshot(scheme == .light ? "drag-light" : "drag-dark")
        try host.send(.leftMouseUp, at: end)
        try await host.settle()
        #expect(host.todos.map(\.dayKey) == ["2026-09-12", "2026-09-16", "2026-09-16"])
        #expect(host.selectedIDs == Set(host.todos.prefix(2).map(\.id)))
        try host.snapshot(scheme == .light ? "drop-light" : "drop-dark")
    }

    @Test func draggingAnUnselectedTaskMovesOnlyThatTask() async throws {
        let host = try makeHost()
        defer { host.close() }
        try await host.settle()
        try await host.clickBar(host.todos[0])
        try await host.clickBar(host.todos[1], modifiers: .command)
        let start = try host.barCenter(host.todos[2])
        let end = NSPoint(x: start.x - 22, y: start.y)
        try host.send(.leftMouseDown, at: start)
        try host.send(.leftMouseDragged, at: end)
        try host.send(.leftMouseUp, at: end)
        try await host.settle()
        #expect(host.selectedIDs == [host.todos[2].id])
        #expect(host.todos.map(\.dayKey) == ["2026-09-10", "2026-09-14", "2026-09-15"])
    }

    @Test(arguments: ["escape", "outside", "return", "mouseup_return", "focus_loss"])
    func cancelledOrUnchangedDragRestoresTheOriginalBar(reason: String) async throws {
        let host = try makeHost()
        defer { host.close() }
        try await host.settle()
        let start = try host.barCenter(host.todos[0])
        var end = NSPoint(x: start.x + 44, y: start.y)
        try host.send(.leftMouseDown, at: start)
        try host.send(.leftMouseDragged, at: end)
        try await host.settle()
        if reason == "escape" { try host.key(53, characters: "\u{1B}") }
        if reason == "focus_loss" { host.window.resignKey() }
        if reason == "outside" { end = NSPoint(x: end.x, y: -20) }
        if reason == "mouseup_return" { end = start }
        if reason == "return" {
            end = start
            try host.send(.leftMouseDragged, at: end)
        }
        try host.send(.leftMouseUp, at: end)
        try await host.settle()
        #expect(host.todos[0].dayKey == "2026-09-10")
        #expect(try host.filledDays(host.todos[0]) == [10])
        #expect(!host.container.mainContext.hasChanges)
    }

    @Test func arrowKeysMoveTheSelectionWithoutDragging() async throws {
        let host = try makeHost()
        defer { host.close() }
        try await host.settle()
        try await host.clickBar(host.todos[0])
        try await host.clickBar(host.todos[1], modifiers: .command)
        try host.key(124, characters: "\u{F703}")
        try await host.settle()
        #expect(host.todos.map(\.dayKey) == ["2026-09-11", "2026-09-15", "2026-09-16"])
        try host.key(123, characters: "\u{F702}")
        try await host.settle()
        #expect(host.todos.map(\.dayKey) == ["2026-09-10", "2026-09-14", "2026-09-16"])
    }

    @Test func titleStillOpensTheInspectorForTheCorrectDate() async throws {
        let host = try makeHost()
        defer { host.close() }
        try await host.settle()
        WorkspaceNavigation.shared.isInspectorPresented = false
        try await host.clickTitle(host.todos[0])
        #expect(WorkspaceNavigation.shared.isInspectorPresented)
        #expect(WorkspaceNavigation.shared.selectedTaskID == host.todos[0].id)
        #expect(BoardSelection.shared.inspectingDayKey == host.todos[0].dayKey)
    }

    @Test func changingATaskDuringTheDragCancelsWithoutRestartingIt() async throws {
        let host = try makeHost()
        defer { host.close() }
        try await host.settle()
        try await host.clickBar(host.todos[0])
        try await host.clickBar(host.todos[1], modifiers: .command)
        let start = try host.barCenter(host.todos[0])
        try host.send(.leftMouseDown, at: start)
        try host.send(.leftMouseDragged, at: NSPoint(x: start.x + 44, y: start.y))
        try await host.settle()
        host.todos[1].dayKey = "2026-09-18"
        try host.container.mainContext.save()
        try await host.settle()
        let end = NSPoint(x: start.x + 66, y: start.y)
        try host.send(.leftMouseDragged, at: end)
        try host.send(.leftMouseUp, at: end)
        try await host.settle()
        #expect(host.todos.map(\.dayKey) == ["2026-09-10", "2026-09-18", "2026-09-16"])
        #expect(try host.filledDays(host.todos[0]) == [10])
    }

    @Test func smallPointerMovementIsStillAClick() async throws {
        let host = try makeHost()
        defer { host.close() }
        try await host.settle()
        let start = try host.barCenter(host.todos[0])
        let end = NSPoint(x: start.x + 2, y: start.y)
        try host.send(.leftMouseDown, at: start)
        try host.send(.leftMouseDragged, at: end)
        try host.send(.leftMouseUp, at: end)
        try await host.settle()
        #expect(host.selectedIDs == [host.todos[0].id])
        #expect(host.todos[0].dayKey == "2026-09-10")
        #expect(!host.container.mainContext.hasChanges)
    }

    @Test func narrowTimelineScrollsWhileDraggingNearTheEdge() async throws {
        let host = try makeHost(width: 640)
        defer { host.close() }
        try await host.settle()
        let start = try host.barCenter(host.todos[2])
        let end = NSPoint(x: 612, y: start.y)
        try host.send(.leftMouseDown, at: start)
        try host.send(.leftMouseDragged, at: end)
        try await host.settle()
        #expect(host.horizontalScrollOffset > 0)
        #expect(host.todos[2].dayKey == "2026-09-16")
        try host.snapshot("drag-narrow")
        try host.send(.leftMouseUp, at: end)
        try await host.settle()
        #expect(host.todos[2].dayKey > "2026-09-16")
        #expect(try host.filledDays(host.todos[2]).count == 1)
    }

    private func makeHost(scheme: ColorScheme = .dark, width: CGFloat = 880) throws -> GanttTestHost {
        let container = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        Self.retainedContainers.append(container)
        let todos = zip(["整理资料", "准备评审", "归档记录"], ["2026-09-10", "2026-09-14", "2026-09-16"])
            .map { TodoItem(title: $0.0, dayKey: $0.1) }
        todos.forEach { container.mainContext.insert($0) }
        try container.mainContext.save()
        return GanttTestHost(container: container, todos: todos, scheme: scheme, width: width)
    }
}

@MainActor
private final class GanttTestHost {
    let window: NSWindow
    let todos: [TodoItem]
    let container: ModelContainer
    private let previousTaskID = WorkspaceNavigation.shared.selectedTaskID
    private let previousInspector = WorkspaceNavigation.shared.isInspectorPresented
    private let previousDay = BoardSelection.shared.inspectingDayKey
    private let previousAccessibility = NSApp.accessibilityAttributeValue(NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))

    init(container: ModelContainer, todos: [TodoItem], scheme: ColorScheme, width: CGFloat) {
        self.container = container
        self.todos = todos
        NSApp.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
        let size = NSSize(width: width, height: 460)
        let content = GanttPage(todayKey: "2026-09-14")
            .modelContainer(container)
            .environment(\.locale, Locale(identifier: "zh-Hans"))
            .environment(\.calendar, Calendar(identifier: .gregorian))
            .environment(\.workspaceEmbedded, true)
            .preferredColorScheme(scheme)
            .frame(width: size.width, height: size.height)
        let hosting = NSHostingView(rootView: content)
        hosting.safeAreaRegions = []
        window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "AreaChain 安排交互测试"
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: scheme == .light ? .aqua : .darkAqua)
        window.contentView = hosting
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    var selectedIDs: Set<UUID> {
        Set(todos.compactMap { todo in
            elements.first { $0.accessibilityIdentifier() == "gantt.todo.\(todo.id)" }?
                .isAccessibilitySelected() == true ? todo.id : nil
        })
    }

    var horizontalScrollOffset: CGFloat {
        elements.compactMap { $0 as? NSScrollView }.map { $0.contentView.bounds.minX }.max() ?? 0
    }

    private var elements: [any NSAccessibilityProtocol] {
        guard let root = window.contentView else { return [] }
        var queue: [NSObject] = [root]
        var visited: Set<ObjectIdentifier> = []
        var result: [any NSAccessibilityProtocol] = []
        while let element = queue.popLast() {
            guard visited.insert(ObjectIdentifier(element)).inserted else { continue }
            if let view = element as? NSView { queue.append(contentsOf: view.subviews) }
            if let accessible = element as? NSAccessibilityProtocol {
                result.append(accessible)
                queue.append(contentsOf: (accessible.accessibilityChildren() ?? []).compactMap { $0 as? NSObject })
            }
        }
        return result
    }

    func clickTitle(_ todo: TodoItem, modifiers: NSEvent.ModifierFlags = []) async throws {
        let frame = try NativeSyntaxUI.frame("gantt.todo.\(todo.id)", in: window)
        let point = NSPoint(x: frame.minX + 30, y: frame.midY)
        try send(.leftMouseDown, at: point, modifiers: modifiers)
        try send(.leftMouseUp, at: point, modifiers: modifiers)
        try await settle()
    }

    func clickBar(_ todo: TodoItem, modifiers: NSEvent.ModifierFlags = []) async throws {
        let point = try barCenter(todo)
        try send(.leftMouseDown, at: point, modifiers: modifiers)
        try send(.leftMouseUp, at: point, modifiers: modifiers)
        try await settle()
    }

    func barCenter(_ todo: TodoItem) throws -> NSPoint {
        let frame = try NativeSyntaxUI.frame("gantt.todo.\(todo.id)", in: window)
        let day = try #require(Int(todo.dayKey.suffix(2)))
        return NSPoint(x: frame.minX + GanttRowMetrics.titleWidth + (CGFloat(day) - 0.5) * GanttRowMetrics.dayWidth, y: frame.midY)
    }

    func key(_ keyCode: UInt16, characters: String) throws {
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, characters: characters, charactersIgnoringModifiers: characters,
            isARepeat: false, keyCode: keyCode
        ))
        window.sendEvent(event)
    }

    /// 从真实渲染像素核对色块位置，不能只验证预览状态而漏掉重复绘制。
    func filledDays(_ todo: TodoItem) throws -> [Int] {
        let view = try #require(window.contentView)
        let frame = try NativeSyntaxUI.frame("gantt.todo.\(todo.id)", in: window)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return (1...30).filter { day in
            let point = view.convert(NSPoint(
                x: frame.minX + GanttRowMetrics.titleWidth + (CGFloat(day) - 0.5) * GanttRowMetrics.dayWidth,
                y: frame.midY
            ), from: nil)
            let y = view.isFlipped ? point.y : view.bounds.height - point.y
            let xPixel = Int(point.x * CGFloat(bitmap.pixelsWide) / view.bounds.width)
            let yPixel = Int(y * CGFloat(bitmap.pixelsHigh) / view.bounds.height)
            guard (0..<bitmap.pixelsWide).contains(xPixel), (0..<bitmap.pixelsHigh).contains(yPixel) else { return false }
            guard let color = bitmap.colorAt(x: xPixel, y: yPixel)?.usingColorSpace(.sRGB) else { return false }
            return color.blueComponent - color.redComponent > 0.25 && color.blueComponent > 0.5
        }
    }

    func send(_ type: NSEvent.EventType, at point: NSPoint, modifiers: NSEvent.ModifierFlags = []) throws {
        let event = try #require(NSEvent.mouseEvent(
            with: type, location: point, modifierFlags: modifiers, timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
        ))
        window.sendEvent(event)
    }

    func settle() async throws {
        window.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(150))
        window.contentView?.layoutSubtreeIfNeeded()
    }

    func snapshot(_ name: String) throws {
        let view = try #require(window.contentView)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AreaChain-Gantt-QA")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name + ".png")
        try png.write(to: url, options: .atomic)
        print("GANTT_QA \(url.path)")
    }

    func close() {
        window.contentView = nil
        window.orderOut(nil)
        WorkspaceNavigation.shared.selectedTaskID = previousTaskID
        WorkspaceNavigation.shared.isInspectorPresented = previousInspector
        BoardSelection.shared.inspectingDayKey = previousDay
        NSApp.accessibilitySetValue(previousAccessibility ?? false, forAttribute: NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
    }
}
