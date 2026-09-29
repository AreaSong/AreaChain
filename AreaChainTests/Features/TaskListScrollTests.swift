import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct TaskListScrollTests {
    @Test func todayTaskListScrollsPastTheViewport() async throws {
        let day = DayClock.shared.todayKey
        let host = try ListScrollHost(size: NSSize(width: 480, height: 420))
        defer { host.close() }
        let todos = try host.insertTodos(count: 40, dayKey: day)
        host.mount {
            TasksPage(
                todayKey: day,
                routines: [],
                checks: [],
                todos: todos
            )
            .modelContainer(host.container)
        }
        try await host.settle()
        let scroll = try host.taskListScroll()
        let document = try #require(scroll.documentView)
        #expect(document.bounds.height > scroll.contentSize.height + 24)
        #expect(scroll.subviews.contains { $0 is DaybookFloatingScrollerOverlay })

        let bottom = max(0, document.bounds.maxY - scroll.contentSize.height)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: bottom))
        scroll.reflectScrolledClipView(scroll.contentView)
        try await host.settle()
        let last = try host.row(todos[todos.count - 1].id)
        let rowFrame = last.convert(last.bounds, to: nil)
        let viewport = scroll.contentView.convert(scroll.contentView.bounds, to: nil)
        #expect(viewport.insetBy(dx: -1, dy: -1).intersects(rowFrame))
    }

    @Test func allItemsListScrollsPastTheViewport() async throws {
        let previous = WorkspaceNavigation.shared.allItemsQuery
        defer {
            WorkspaceNavigation.shared.allItemsQuery = previous
            WorkspaceNavigation.shared.clearListedCheckDays()
        }
        let day = DayClock.shared.todayKey
        let host = try ListScrollHost(size: NSSize(width: 640, height: 420))
        defer { host.close() }
        _ = try host.insertTodos(count: 40, dayKey: day)
        host.mount {
            WorkspaceAllItemsView()
                .modelContainer(host.container)
                .environment(\.workspaceEmbedded, true)
        }
        try await host.settle()
        let scroll = try host.taskListScroll()
        let document = try #require(scroll.documentView)
        #expect(document.bounds.height > scroll.contentSize.height + 24)

        let bottom = max(0, document.bounds.maxY - scroll.contentSize.height)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: bottom))
        scroll.reflectScrolledClipView(scroll.contentView)
        try await host.settle()
        #expect(scroll.contentView.bounds.origin.y > 1)
    }

    @Test func rowPointerForwardsScrollWheelToTheList() throws {
        let scroll = RecordingScrollView(frame: NSRect(x: 0, y: 0, width: 200, height: 80))
        let document = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 400))
        let row = BoardRowPointerView(frame: NSRect(x: 10, y: 10, width: 160, height: 28))
        document.addSubview(row)
        scroll.documentView = document
        let cgEvent = try #require(CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: -40,
            wheel2: 0,
            wheel3: 0
        ))
        let event = try #require(NSEvent(cgEvent: cgEvent))
        row.scrollWheel(with: event)
        #expect(scroll.receivedScroll)
    }
}

private final class RecordingScrollView: NSScrollView {
    var receivedScroll = false

    override func scrollWheel(with event: NSEvent) {
        receivedScroll = true
        super.scrollWheel(with: event)
    }
}

@MainActor
private final class ListScrollHost {
    private static var retainedContainers: [ModelContainer] = []
    let container: ModelContainer
    let window: NSWindow

    init(size: NSSize) throws {
        container = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        Self.retainedContainers.append(container)
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.isRestorable = false
    }

    func insertTodos(count: Int, dayKey: String) throws -> [TodoItem] {
        let todos = (0..<count).map { index in
            TodoItem(
                title: "任务 \(index + 1)",
                dayKey: dayKey,
                createdAt: Date(timeIntervalSince1970: Double(index))
            )
        }
        todos.forEach { container.mainContext.insert($0) }
        try container.mainContext.save()
        return todos
    }

    func mount(@ViewBuilder content: () -> some View) {
        let host = NSHostingView(rootView: content()
            .environment(\.locale, Locale(identifier: "zh-Hans"))
            .transaction { $0.disablesAnimations = true })
        host.safeAreaRegions = []
        window.contentView = host
        window.orderFront(nil)
    }

    func close() {
        window.orderOut(nil)
        window.contentView = nil
        WorkspaceNavigation.shared.isInlineTitleVisible = false
    }

    func settle() async throws {
        window.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(220))
        window.contentView?.layoutSubtreeIfNeeded()
    }

    func taskListScroll() throws -> NSScrollView {
        try #require(firstRow().enclosingScrollView)
    }

    func firstRow() throws -> BoardRowPointerView {
        try #require(rows().first)
    }

    func row(_ id: UUID) throws -> BoardRowPointerView {
        try #require(rows().first { $0.identifier?.rawValue == id.uuidString })
    }

    private func rows() -> [BoardRowPointerView] {
        descendants(window.contentView).compactMap { $0 as? BoardRowPointerView }
    }

    private func descendants(_ view: NSView?) -> [NSView] {
        guard let view else { return [] }
        return view.subviews.flatMap { [$0] + descendants($0) }
    }
}
