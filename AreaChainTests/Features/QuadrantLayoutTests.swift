import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct QuadrantLayoutTests {
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
        let hint = try NativeSyntaxUI.frame("quadrant.hint", in: host.window)
        let bottom = bounds.minY + DaybookSpacing.page
        let top = hint.minY - DaybookSpacing.md
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
