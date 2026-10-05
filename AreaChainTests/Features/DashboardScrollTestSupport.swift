import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 只挂生产 Dashboard；按图表日期按钮归属和原生父链识别三个滚动对象。
@MainActor
final class DashboardScrollTestSupport {
    let fixture: SettingsButtonTestSupport
    let window: NSWindow
    let locale: String
    let today = DayClock.shared.todayKey
    let restore = CalendarSpanTestSupport.preserveState()
    var todos: [TodoItem] = []
    var isBaseline: Bool { ProcessInfo.processInfo.environment["AREACHAIN_DASHBOARD_BASELINE"] == "1" }

    init(locale: String = "en", scheme: ColorScheme = .light,
         size: NSSize = NSSize(width: 960, height: 640), populated: Bool = true,
         embedded: Bool = true) throws {
        self.locale = locale
        fixture = try SettingsButtonTestSupport(isolatedPreferences: true)
        if populated {
            for index in 0..<24 {
                // 同日完成活动按稳定身份排序；固定合成身份，避免前后位图被随机顺序污染。
                let id = try #require(UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1)))
                let item = TodoItem(id: id, title: "Synthetic dashboard \(index)", isDone: index.isMultiple(of: 2),
                    dayKey: today, createdAt: Date().addingTimeInterval(Double(-index * 60)))
                todos.append(item)
                fixture.container.mainContext.insert(item)
            }
            try fixture.container.mainContext.save()
        }
        // 此宿主不固定 SwiftUI 根尺寸，使原生 resize 真正传入生产页面。
        NSApp.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
        let host = NSHostingView(rootView: DashboardView().modelContainer(fixture.container)
            .environment(fixture.prefs).environment(\.locale, Locale(identifier: locale))
            .environment(\.colorScheme, scheme).environment(\.workspaceEmbedded, embedded)
            .transaction { $0.disablesAnimations = true })
        host.safeAreaRegions = []
        window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentView = host
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        SystemPageHost.release(window)
        restore()
        fixture.cleanup()
    }

    struct Targets {
        let outer: NSScrollView
        let trend: NSScrollView
        let heat: NSScrollView
        var all: [NSScrollView] { [outer, trend, heat] }
    }

    func targets() throws -> Targets {
        let scrolls = ScrollNativeEvidence.views(window).compactMap { $0 as? NSScrollView }
        try #require(scrolls.count == 3)
        let nodes = SettingsButtonTestSupport.elements(window.contentView)
        func belongs(_ scroll: NSScrollView, prefix: String) -> Bool {
            let frames = nodes.filter {
                (SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String)?
                    .hasPrefix(prefix) == true
            }.compactMap { try? SettingsButtonTestSupport.frame($0, in: window) }.filter { !$0.isEmpty }
            let viewport = scroll.convert(scroll.bounds, to: nil)
            return !frames.isEmpty && frames.allSatisfy { viewport.minY <= $0.midY && $0.midY <= viewport.maxY }
        }
        let nested = scrolls.filter { $0.enclosingScrollView != nil }
        let trends = nested.filter { belongs($0, prefix: "dashboard.trend.") }
        let heats = nested.filter { belongs($0, prefix: "dashboard.heat.") }
        try #require(trends.count == 1 && heats.count == 1)
        let trend = try #require(trends.first)
        let heat = try #require(heats.first)
        let outer = try #require(trend.enclosingScrollView)
        #expect(heat.enclosingScrollView === outer)
        #expect(outer.enclosingScrollView == nil)
        #expect(nodes.contains {
            (SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String) == "dashboard.activity"
        })
        return Targets(outer: outer, trend: trend, heat: heat)
    }

    static func overlays(_ scroll: NSScrollView) -> [DaybookFloatingScrollerOverlay] {
        scroll.subviews.compactMap { $0 as? DaybookFloatingScrollerOverlay }
    }

    func requireOwnership(_ targets: Targets) throws {
        let current = ScrollNativeEvidence.views(window).compactMap { $0 as? NSScrollView }
        try #require(Set(current.map(ObjectIdentifier.init)) == Set(targets.all.map(ObjectIdentifier.init)))
        try #require(targets.trend !== targets.heat && targets.outer.enclosingScrollView == nil)
        try #require(targets.trend.enclosingScrollView === targets.outer)
        try #require(targets.heat.enclosingScrollView === targets.outer)
        try #require(Self.overlays(targets.outer).count == (isBaseline ? 0 : 1))
        try #require(Self.overlays(targets.trend).isEmpty && Self.overlays(targets.heat).isEmpty)
        try #require(targets.outer.hasVerticalScroller == isBaseline)
        try #require(!targets.outer.hasHorizontalScroller && !targets.trend.hasHorizontalScroller
                     && !targets.heat.hasHorizontalScroller)
        try #require(ScrollNativeEvidence.views(window).filter { $0 is DaybookScrollEdgeObserverNSView }.isEmpty)
    }

    func record(_ targets: Targets, label: String) {
        for (name, scroll) in zip(["outer", "trend", "heat"], targets.all) {
            print("DASHBOARD_SCROLL \(label) \(name) id=\(ObjectIdentifier(scroll)) "
                + "parent=\(String(describing: scroll.enclosingScrollView.map(ObjectIdentifier.init))) "
                + "viewport=\(scroll.contentView.bounds) document=\(scroll.documentView?.bounds ?? .zero) "
                + "frame=\(scroll.convert(scroll.bounds, to: window.contentView)) "
                + "system=\(scroll.hasVerticalScroller)/\(scroll.hasHorizontalScroller) "
                + "overlays=\(Self.overlays(scroll).count)")
        }
    }

    func capturePositions(_ targets: Targets, name: String) async throws {
        let scroll = targets.outer
        let maximum = max(0, try #require(scroll.documentView).bounds.height - scroll.contentSize.height)
        for progress in [0.0, 0.5, 1.0] {
            scroll.contentView.scroll(to: NSPoint(x: 0, y: maximum * progress))
            scroll.reflectScrolledClipView(scroll.contentView)
            try await SystemPageHost.settle(window)
            #expect(abs(scroll.contentView.bounds.minY - maximum * progress) < 1)
            record(targets, label: "\(name)-programmatic-\(progress)")
            try capture(name: "\(name)-\(progress)")
            if progress == 1 { try requireLastActivityVisible() }
        }
        scroll.contentView.scroll(to: .zero)
        scroll.reflectScrolledClipView(scroll.contentView)
        try await SystemPageHost.settle(window)
    }

    func capture(name: String) throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "Dashboard10C")
            .appending(path: isBaseline ? "before" : "after")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let content = try #require(window.contentView)
        for (suffix, view) in [("content", content), ("window", try #require(content.superview))] {
            let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try #require(bitmap.representation(using: .png, properties: [:]))
                .write(to: directory.appending(path: "\(name)-\(suffix).png"))
        }
        print("DASHBOARD_CAPTURE \(directory.path)/\(name) window=\(window.frame) content=\(content.bounds)")
    }

    private func requireLastActivityVisible() throws {
        let snapshot = DashboardProjection.project(todos: todos.map(\.snapshot),
            routines: [], checks: [], diaries: [], todayKey: today)
        // SwiftUI 将分区标识传播到活动行；通过最后一项的合成标题核对内容，不能依赖被覆盖的行标识。
        let title = snapshot.activities.last?.title
            ?? L10n.string("dashboard.activity.empty", locale: Locale(identifier: locale))
        let nodes = SettingsButtonTestSupport.elements(window.contentView).filter {
            let identifier = SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String ?? ""
            let text = (SettingsButtonTestSupport.value($0, "accessibilityLabel") as? String)
                ?? (SettingsButtonTestSupport.value($0, "accessibilityValue") as? String) ?? ""
            return identifier.hasPrefix("dashboard.activity") && text.contains(title)
        }
        try #require(!nodes.isEmpty, "最后活动内容未出现在辅助树：\(title)")
        let scroll = try #require(ScrollNativeEvidence.views(window).compactMap { $0 as? NSScrollView }
            .first { $0.enclosingScrollView == nil })
        let viewport = scroll.convert(scroll.bounds, to: nil)
        let frames = try nodes.map { try SettingsButtonTestSupport.frame($0, in: window) }
        #expect(frames.contains { viewport.contains(NSPoint(x: $0.midX, y: $0.midY)) })
    }

    func verifyUpdates(_ targets: Targets) async throws {
        let overlay = try #require(Self.overlays(targets.outer).first)
        for _ in 0..<3 {
            window.contentView?.layoutSubtreeIfNeeded()
            try await SystemPageHost.settle(window)
            try requireOwnership(targets)
            #expect(Self.overlays(targets.outer).first === overlay)
        }
        let added = TodoItem(title: "Synthetic update", dayKey: today)
        fixture.container.mainContext.insert(added)
        try fixture.container.mainContext.save()
        try await SystemPageHost.settle(window)
        try requireOwnership(targets)
        #expect(Self.overlays(targets.outer).first === overlay)
        fixture.container.mainContext.delete(added)
        try fixture.container.mainContext.save()
        for size in [NSSize(width: 300, height: 360), NSSize(width: 1200, height: 900),
                     NSSize(width: 960, height: 640)] {
            window.setContentSize(size)
            try await SystemPageHost.settle(window)
            try requireOwnership(targets)
            #expect(Self.overlays(targets.outer).first === overlay)
            #expect(overlay.frame == DaybookFloatingScrollerOverlay.calculateFrame(for: targets.outer))
            record(targets, label: "resize")
        }
    }

    func verifyPointerAndNavigation(_ targets: Targets) async throws {
        let original = todos.map(\.snapshot)
        let overlay = try #require(Self.overlays(targets.outer).first)
        targets.outer.contentView.scroll(to: .zero)
        targets.outer.reflectScrolledClipView(targets.outer.contentView)
        try await SystemPageHost.settle(window)
        overlay.flash()
        let knob = try #require(Mirror(reflecting: overlay).children
            .first { $0.label == "currentKnobRect" }?.value as? NSRect)
        try #require(!knob.isEmpty && overlay.alphaValue >= 0.05)
        let horizontal = [targets.trend, targets.heat].map { $0.contentView.bounds.origin }
        let start = overlay.convert(NSPoint(x: knob.midX, y: knob.midY), to: nil)
        try await SurfaceEventTestSupport.click(start, in: window)
        #expect(targets.outer.contentView.bounds.minY == 0)
        for (type, delta) in [(NSEvent.EventType.leftMouseDown, 0.0), (.leftMouseDragged, 35.0), (.leftMouseUp, 35.0)] {
            let point = overlay.convert(NSPoint(x: knob.midX, y: knob.midY + delta), to: nil)
            let event = try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            window.sendEvent(event)
        }
        try await SystemPageHost.settle(window)
        #expect(targets.outer.contentView.bounds.minY > 0)
        #expect([targets.trend, targets.heat].map { $0.contentView.bounds.origin } == horizontal)
        record(targets, label: "window-pointer-drag")
        try await verifyDateNavigation(targets)
        #expect(todos.map(\.snapshot) == original && !fixture.container.mainContext.hasChanges)
    }

    private func verifyDateNavigation(_ targets: Targets) async throws {
        for (scroll, prefix) in [(targets.trend, "dashboard.trend."), (targets.heat, "dashboard.heat.")] {
            targets.outer.contentView.scroll(to: .zero)
            targets.outer.reflectScrolledClipView(targets.outer.contentView)
            try await SystemPageHost.settle(window)
            let candidates = SettingsButtonTestSupport.buttons(in: window).filter {
                let identifier = SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String ?? ""
                return identifier.hasPrefix(prefix) && identifier != "dashboard.heat.pad"
            }
            let viewport = scroll.convert(scroll.bounds, to: nil)
            let node = try #require(candidates.first {
                guard let rect = try? SettingsButtonTestSupport.frame($0, in: window) else { return false }
                return viewport.contains(NSPoint(x: rect.midX, y: rect.midY))
            })
            let identifier = try #require(SettingsButtonTestSupport.value(node, "accessibilityIdentifier") as? String)
            let frame = try SettingsButtonTestSupport.frame(node, in: window)
            let point = NSPoint(x: frame.midX, y: frame.midY)
            let root = try #require(window.contentView)
            #expect(!(root.hitTest(root.superview?.convert(point, from: nil) ?? point) is DaybookFloatingScrollerOverlay))
            WorkspaceNavigation.shared.revealTab(.dashboard)
            try await SurfaceEventTestSupport.click(point, in: window)
            #expect(WorkspaceNavigation.shared.selectedTab == .calendar)
            #expect(WorkspaceNavigation.shared.inspectingDayKey == String(identifier.dropFirst(prefix.count)))
            print("DASHBOARD_NAVIGATION \(identifier)")
        }
    }

    func wheel(_ scroll: NSScrollView, horizontal: Bool) async throws {
        let cg = try #require(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
            wheel1: horizontal ? 0 : -80, wheel2: horizontal ? -80 : 0, wheel3: 0))
        scroll.scrollWheel(with: try #require(NSEvent(cgEvent: cg)))
        try await SystemPageHost.settle(window)
    }
}
