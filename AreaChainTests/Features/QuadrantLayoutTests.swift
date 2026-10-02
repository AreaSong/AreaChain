import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct QuadrantLayoutTests {
    @Test func completionKeepsQuadrantMutationSeparateFromInspection() async throws {
        let host = try QuadrantLayoutHost(scheme: .light, counts: [2, 0, 0, 0])
        defer { host.close() }
        try await NativeSyntaxUI.prepareFocus(in: host.window)
        try await host.settle()
        let selected = WorkspaceNavigation.shared.selectedTaskID
        let todo = try #require(host.items[.importantUrgent]?.first)
        let other = try #require(host.items[.importantUrgent]?.last)
        let native = SettingsButtonTestSupport.self
        // 当前行标识传播到标题按钮，不能把其 15pt AX 框当成整行或完成控件的框。
        let titleFrame = try NativeSyntaxUI.frame("quadrant.task.\(todo.id)", in: host.window)
        let buttons = try native.buttons(in: host.window).filter {
            let frame = try native.frame($0, in: host.window)
            return abs(frame.midY - titleFrame.midY) <= 1 && frame.minX <= titleFrame.maxX
        }
        let completion = try #require(buttons.first {
            native.value($0, "accessibilityLabel") as? String ==
                L10n.string("checkbox.open", locale: Locale(identifier: "zh-Hans"))
        })
        try native.assertBounds(buttons, in: host.window)
        #expect(try native.frame(completion, in: host.window).size == CGSize(width: 20, height: 20))
        try await native.click(completion, in: host.window)
        #expect(todo.isDone && !other.isDone)
        #expect(WorkspaceNavigation.shared.selectedTaskID == selected)
        #expect(try ModelContext(host.container).fetch(FetchDescriptor<TodoItem>()).first { $0.id == todo.id }?.isDone == true)
        #expect(PendingCompletionManager.shared.pendingDoneIDs.isEmpty)
    }

    @Test(arguments: [ColorScheme.light, .dark], [false, true])
    func quadrantsFillWorkspaceEquallyWhenResized(scheme: ColorScheme, populated: Bool) async throws {
        let host = try QuadrantLayoutHost(scheme: scheme, counts: populated ? [45, 1, 0, 34] : [0, 0, 0, 0])
        defer { host.close() }
        let sizes = [NSSize(width: 720, height: 540), NSSize(width: 1000, height: 820), NSSize(width: 300, height: 470)]
        for size in sizes {
            host.window.setContentSize(size)
            try await host.settle()
            let name = "\(populated ? "populated" : "empty")-\(scheme == .dark ? "dark" : "light")-\(Int(size.width))"
            try host.snapshot(name)
            try assertEqualGrid(host)
            #expect(host.scrollViews.count == (populated ? 3 : 0), "页面不应增加整页滚动容器")
        }
    }

    @Test func titleOverflowUsesRenderedWidth() {
        #expect(!QuadrantTitleOverflow.isOverflowing(idealWidth: 40, visibleWidth: 80))
        #expect(!QuadrantTitleOverflow.isOverflowing(idealWidth: 80, visibleWidth: 80))
        #expect(QuadrantTitleOverflow.isOverflowing(idealWidth: 120, visibleWidth: 80))
        #expect(!QuadrantTitleOverflow.isOverflowing(idealWidth: 200, visibleWidth: 0))
        let short = QuadrantTitleOverflow.preview("买牛奶")
        #expect(short == QuadrantTitleOverflow.Preview(excerpt: "买牛奶", isPartial: false))
        let wall = String(repeating: "1", count: 20_000)
        let long = QuadrantTitleOverflow.preview(wall)
        #expect(long.isPartial)
        #expect(long.excerpt.count < QuadrantTitleOverflow.previewProbeLimit)
        #expect(long.excerpt.count > 8)
    }

    @Test func previewOverlayTracksTheTitleAnchor() async throws {
        let id = UUID()
        let anchor = CGRect(x: 210, y: 180, width: 80, height: 20)
        let previous = NSApp.accessibilityAttributeValue(NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
        NSApp.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
        let window = NSWindow(
            contentRect: NSRect(x: 40, y: 40, width: 480, height: 320),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: QuadrantPreviewProbe(id: id, anchor: anchor))
        defer {
            window.orderOut(nil)
            window.contentView = nil
            NSApp.accessibilitySetValue(previous ?? false, forAttribute: NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(180))
        window.contentView?.layoutSubtreeIfNeeded()

        let bubble = try NativeSyntaxUI.frame("quadrant.titleBubble.\(id.uuidString)", in: window)
        let host = try #require(window.contentView).convert(window.contentView?.bounds ?? .zero, to: nil)
        #expect(bubble.minX > host.minX + 120, "预览应跟在标题旁，而不是停在左上角")
        #expect(abs(bubble.minX - (host.minX + anchor.minX)) < 30)
    }

    @Test func longTitlesStayOnOneLineAndOnlyThoseOverflow() async throws {
        let host = try QuadrantLayoutHost(scheme: .light, counts: [1, 0, 0, 1])
        defer { host.close() }
        let longItem = try #require(host.items[.importantUrgent]?.first)
        let shortItem = try #require(host.items[.rest]?.first)
        longItem.title = String(repeating: "1", count: 800)
        shortItem.title = "买牛奶"
        try host.container.mainContext.save()
        try await host.settle()

        let longChip = try NativeSyntaxUI.frame("quadrant.task.\(longItem.id)", in: host.window)
        let shortChip = try NativeSyntaxUI.frame("quadrant.task.\(shortItem.id)", in: host.window)
        let scroll = try host.scrollView(in: .importantUrgent)
        #expect(abs(longChip.height - shortChip.height) < 2, "长短标题都应占同一行高")
        #expect(longChip.height < 36, "超长标题不应撑开卡片")
        #expect(!scroll.hasHorizontalScroller, "超长标题不应把宫格撑出横向滚动")
        #expect(longChip.width <= shortChip.width + 1)
    }

    @Test func overflowingListsScrollIndependentlyAndKeepHeadersFixed() async throws {
        let host = try QuadrantLayoutHost(scheme: .dark, counts: [45, 1, 3, 34])
        defer { host.close() }
        try await host.settle()
        let cells = try host.frames("cell")
        let headers = try host.frames("header")
        let scrolls = try QuadrantSlot.allCases.map { try host.scrollView(in: $0) }
        let origins = scrolls.map { $0.contentView.bounds.origin }
        let target = scrolls[0]
        let document = try #require(target.documentView)
        #expect(document.bounds.height > target.contentSize.height)
        #expect(!target.hasHorizontalScroller)
        #expect(target.subviews.contains { $0 is DaybookFloatingScrollerOverlay } || target.hasVerticalScroller)
        let shortDocument = try #require(scrolls[1].documentView)
        #expect(shortDocument.bounds.height <= scrolls[1].contentSize.height + 1)

        target.contentView.scroll(to: NSPoint(x: 0, y: 140))
        target.reflectScrolledClipView(target.contentView)
        try await host.settle()
        #expect(target.contentView.bounds.origin.y > origins[0].y)
        #expect(Array(scrolls.dropFirst().map { $0.contentView.bounds.origin }) == Array(origins.dropFirst()))
        #expect(try host.frames("cell") == cells)
        #expect(try host.frames("header") == headers)
        try assertEqualGrid(host)
        try host.snapshot("independent-scroll-dark")

        target.contentView.scroll(to: NSPoint(x: 0, y: document.bounds.maxY - target.contentSize.height))
        target.reflectScrolledClipView(target.contentView)
        try await host.settle()
        let lastID = try #require(host.items[.importantUrgent]?.last?.id)
        let lastFrame = try NativeSyntaxUI.frame("quadrant.task.\(lastID)", in: host.window)
        let viewport = target.contentView.convert(target.contentView.bounds, to: nil)
        #expect(viewport.insetBy(dx: -1, dy: -1).contains(lastFrame), "清单末项应可完整滚动到可视区域")
        #expect(try host.frames("header") == headers)
    }

    private func assertEqualGrid(_ host: QuadrantLayoutHost) throws {
        let cells = try host.frames("cell")
        let content = try #require(host.window.contentView)
        let bounds = content.convert(content.bounds, to: nil)
        let period = try host.periodFrame()
        let bottom = bounds.minY + DaybookSpacing.page
        let top = period.minY - DaybookSpacing.md
        let width = (bounds.width - 2 * DaybookSpacing.page - DaybookSpacing.sm) / 2
        let height = (top - bottom - DaybookSpacing.sm) / 2
        for cell in cells {
            #expect(abs(cell.width - width) < 1, "四格必须等宽且铺满页面宽度")
            #expect(abs(cell.height - height) < 1, "四格必须等高且均分页头下方的剩余高度")
            #expect(bounds.insetBy(dx: -1, dy: -1).contains(cell))
        }
        #expect(abs(cells[0].maxY - top) < 1)
        #expect(abs(cells[2].minY - bottom) < 1, "底行应延伸到页面底部内边距")
        #expect(abs(cells[0].minX - bounds.minX - DaybookSpacing.page) < 1)
        #expect(abs(cells[1].maxX - bounds.maxX + DaybookSpacing.page) < 1)
        #expect(abs(cells[1].minX - cells[0].maxX - DaybookSpacing.sm) < 1)
        #expect(abs(cells[0].minY - cells[2].maxY - DaybookSpacing.sm) < 1)
        #expect(cells[0].minY == cells[1].minY && cells[2].minY == cells[3].minY)
    }
}

private struct QuadrantPreviewProbe: View {
    var id: UUID
    var anchor: CGRect

    var body: some View {
        Color.clear
            .frame(width: 480, height: 320)
            .overlay(alignment: .topLeading) {
                QuadrantPreviewOverlay(
                    preview: QuadrantFloatingPreview(
                        id: id,
                        title: "1111",
                        excerpt: "1111111111",
                        showsHint: true
                    ),
                    anchor: anchor,
                    containerSize: CGSize(width: 480, height: 320),
                    onCopy: { _ in },
                    onHover: { _ in }
                )
            }
    }
}

@MainActor
private final class QuadrantLayoutHost {
    private static var retainedContainers: [ModelContainer] = []
    private let previousDay = BoardSelection.shared.inspectingDayKey
    private let previousAccessibility = NSApp.accessibilityAttributeValue(NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
    let container: ModelContainer
    let window: NSWindow
    private(set) var items: [QuadrantSlot: [TodoItem]] = [:]

    init(scheme: ColorScheme, counts: [Int]) throws {
        container = try ModelContainer(
            for: Schema(AreaChainSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        Self.retainedContainers.append(container)
        let day = DayClock.shared.todayKey
        BoardSelection.shared.inspectingDayKey = day
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 540),
            styleMask: [.titled, .resizable], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        try addItems(counts: counts, day: day)
        // SwiftUI 按需生成无障碍树，仅为当前测试宿主启用完整控件信息。
        NSApp.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
        let host = NSHostingView(rootView: QuadrantPage(todayKey: day)
            .modelContainer(container)
            .environment(\.workspaceEmbedded, true)
            .environment(\.locale, Locale(identifier: "zh-Hans"))
            .preferredColorScheme(scheme)
            .transaction { $0.disablesAnimations = true })
        host.safeAreaRegions = []
        window.contentView = host
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func addItems(counts: [Int], day: String) throws {
        for slot in QuadrantSlot.allCases {
            items[slot] = (0..<counts[slot.rawValue]).map { index in
                let item = TodoItem(
                    title: "任务 \(index + 1)：核对四象限布局与独立滚动，长标题仍留在当前宫格中",
                    dayKey: day, createdAt: Date(timeIntervalSince1970: Double(index)),
                    isImportant: slot.isImportant, isUrgent: slot.isUrgent
                )
                container.mainContext.insert(item)
                return item
            }
        }
        try container.mainContext.save()
    }

    func close() {
        window.orderOut(nil)
        window.contentView = nil
        BoardSelection.shared.inspectingDayKey = previousDay
        NSApp.accessibilitySetValue(previousAccessibility ?? false, forAttribute: NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
    }

    func settle() async throws {
        window.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(180))
        window.contentView?.layoutSubtreeIfNeeded()
    }

    func frames(_ kind: String) throws -> [CGRect] {
        try QuadrantSlot.allCases.map { try NativeSyntaxUI.frame("quadrant.\(kind).\($0.rawValue)", in: window) }
    }

    func periodFrame() throws -> CGRect {
        let anchor = try #require(descendants(window.contentView).first { $0.identifier?.rawValue == "period.bar" })
        return anchor.convert(anchor.bounds, to: nil)
    }

    var scrollViews: [NSScrollView] {
        descendants(window.contentView).compactMap { $0 as? NSScrollView }
    }

    func scrollView(in slot: QuadrantSlot) throws -> NSScrollView {
        let cell = try NativeSyntaxUI.frame("quadrant.cell.\(slot.rawValue)", in: window)
        return try #require(scrollViews.first {
            let frame = $0.convert($0.bounds, to: nil)
            return !frame.isEmpty && cell.contains(NSPoint(x: frame.midX, y: frame.midY))
        })
    }

    func snapshot(_ name: String) throws {
        let view = try #require(window.contentView)
        window.displayIfNeeded()
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AreaChain-Quadrant-QA")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent(name + ".png")
        try #require(bitmap.representation(using: .png, properties: [:])).write(to: file, options: .atomic)
        print("QUADRANT_QA: \(file.path)")
    }

    private func descendants(_ view: NSView?) -> [NSView] {
        guard let view else { return [] }
        return [view] + view.subviews.flatMap { descendants($0) }
    }
}
