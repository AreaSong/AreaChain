import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 通过生产 FooterBar 的原生菜单动作打开帮助；不复制 showSyntaxHelp 或业务动作。
@Suite(.serialized) @MainActor
struct MenuBarHelpSurfaceTests {
    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func productionHelpActionsAndClipping(locale: String, scheme: ColorScheme) async throws {
        try await exerciseHelpActions(locale: locale, scheme: scheme, accessibility: false)
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func productionHelpAccessibilityActions(locale: String, scheme: ColorScheme) async throws {
        try await exerciseHelpActions(locale: locale, scheme: scheme, accessibility: true)
    }

    private func exerciseHelpActions(locale: String, scheme: ColorScheme, accessibility: Bool) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        support.prefs.appearance = scheme == .dark ? .dark : .light
        for width: CGFloat in [356, 380] {
            let composer = BoardComposerSession()
            composer.tasks.text = "Synthetic draft #one #two"
            let toolbar = MenuBarToolbarState()
            let filters = BoardFilterSession()
            let initialFilters = filters.filters
            let window = SystemPageHost.preferenceWindow(
                MenuBarPopoverView(toolbar: toolbar, composer: composer, filterSession: filters)
                    .environment(\.locale, Locale(identifier: locale)).preferredColorScheme(scheme),
                container: support.container, prefs: support.prefs, size: NSSize(width: width, height: 490))
            defer { SystemPageHost.release(window) }
            try await NativeSyntaxUI.prepareFocus(in: window)
            try await SystemPageHost.settle(window)
            #expect(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == (scheme == .dark ? .darkAqua : .aqua))
            try await openHelp(in: window, locale: locale)
            let captureTitle = L10n.string("syntax.guide.title", locale: Locale(identifier: locale))
            #expect(SurfaceConsumerUI.strings(window).contains(captureTitle))
            #expect(!NativeSyntaxUI.identifiers(in: window).contains("syntax.overlay.candidates"))
            try OverlaySurfaceTestSupport.record(window, name: "e-help-capture-\(locale)-\(scheme)-\(Int(width))")
            let mutations = MenuBarHelpMutationProbe(context: support.container.mainContext) {
                _ = composer.tasks
                _ = toolbar.searchText
            }
            let row = try helpButton("syntax.guide.tag", context: .capture, locale: locale, in: window)
            try await activate(row, in: window, accessibility: accessibility)
            let snippet = L10n.string("syntax.example.tag.snippet", locale: Locale(identifier: locale))
            #expect(composer.tasks.text == snippet && mutations.writes == 1)
            mutations.writes = 0
            #expect(!SurfaceConsumerUI.strings(window).contains(captureTitle))
            #expect(captureField(window)?.currentEditor() != nil)
            try await openHelp(in: window, locale: locale)
            let complex = try helpButton("syntax.guide.example", context: .capture, locale: locale, in: window)
            try await activate(complex, in: window, accessibility: accessibility)
            #expect(composer.tasks.text == L10n.string("syntax.example.complex.snippet", locale: Locale(identifier: locale)))
            #expect(mutations.writes == 1)
            let draft = composer.tasks.text
            for prefix in ["", "query", "query "] {
                toolbar.searchText = prefix
                toolbar.focusSearch()
                try await SystemPageHost.settle(window)
                try await openHelp(in: window, locale: locale)
                let searchTitle = L10n.string("syntax.search.title", locale: Locale(identifier: locale))
                #expect(SurfaceConsumerUI.strings(window).contains(searchTitle))
                #expect(!toolbar.autocomplete.isActive)
                try OverlaySurfaceTestSupport.record(window, name: "e-help-search-\(prefix.count)-\(locale)-\(scheme)-\(Int(width))")
                mutations.writes = 0
                // nil 综合回调继续无动作，不收起、不改搜索或捕获草稿。
                let example = try helpButton("syntax.guide.example", context: .search, locale: locale, in: window)
                try await activate(example, in: window, accessibility: accessibility)
                #expect(toolbar.searchText == prefix && composer.tasks.text == draft && mutations.writes == 0)
                #expect(SurfaceConsumerUI.strings(window).contains(searchTitle))
                if !SurfaceConsumerUI.strings(window).contains(searchTitle) {
                    SurfaceEventTestSupport.note("nil example unexpectedly dismissed help; restore search context for independent token assertion")
                    toolbar.focusSearch()
                    try await SystemPageHost.settle(window)
                    try await openHelp(in: window, locale: locale)
                }
                let token = try helpButton("syntax.guide.tag", context: .search, locale: locale, in: window)
                try await activate(token, in: window, accessibility: accessibility)
                #expect(toolbar.searchText == prefix + (prefix.isEmpty || prefix.hasSuffix(" ") ? "" : " ") + "#")
                #expect(toolbar.searchIsFocused && composer.tasks.text == draft && mutations.writes == 1)
                #expect(!SurfaceConsumerUI.strings(window).contains(searchTitle))
                #expect(MenuBarPopoverRenderingTests().searchField(in: try #require(window.contentView))?.currentEditor() != nil)
            }
            #expect(mutations.saves == 0)
            #expect(filters.filters == initialFilters)
            #expect(try support.container.mainContext.fetchCount(FetchDescriptor<TodoItem>()) == 0)
            #expect(try support.container.mainContext.fetchCount(FetchDescriptor<TagItem>()) == 0)
            #expect(!support.container.mainContext.hasChanges)
        }
    }

    @Test(arguments: ["send", "queue", "accessibility"])
    func productionCaptureSingleEventOwnership(delivery: String) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let composer = BoardComposerSession()
        composer.tasks.text = "Synthetic original"
        let toolbar = MenuBarToolbarState()
        let window = helpWindow(support, composer: composer, toolbar: toolbar)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await openHelp(in: window)
        let text = L10n.string("syntax.guide.tag", locale: Locale(identifier: "en"))
        let row = try helpButton("syntax.guide.tag", context: .capture, locale: "en", in: window)
        let candidates = SettingsButtonTestSupport.buttons(in: window).filter {
            (SettingsButtonTestSupport.value($0, "accessibilityLabel") as? String)?.contains(text) == true
        }
        for node in candidates {
            SurfaceEventTestSupport.note("capture candidate \(type(of: node)) frame=\(try SettingsButtonTestSupport.frame(node, in: window))")
        }
        SurfaceEventTestSupport.note("capture candidates=\(candidates.count) delivery=\(delivery)")
        if delivery == "accessibility" {
            try await activate(row, in: window, accessibility: true)
        } else {
            let rect = try SettingsButtonTestSupport.frame(row, in: window)
            try await SurfaceEventTestSupport.click(NSPoint(x: rect.midX, y: rect.midY), in: window, delivery: delivery)
        }
        try await settledHelp(window)
        SurfaceEventTestSupport.describe(window)
        SurfaceEventTestSupport.note("capture help=\(helpVisible(window)) replaced=\(composer.tasks.text != "Synthetic original")")
        #expect(composer.tasks.text == L10n.string("syntax.example.tag.snippet", locale: Locale(identifier: "en")))
        #expect(!helpVisible(window))
        #expect(captureField(window)?.currentEditor() != nil)
        #expect(!support.container.mainContext.hasChanges)
    }

    @Test func productionSearchSingleEventOwnership() async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let composer = BoardComposerSession()
        composer.tasks.text = "Synthetic capture"
        let toolbar = MenuBarToolbarState()
        toolbar.searchText = "query"
        toolbar.focusSearch()
        let window = helpWindow(support, composer: composer, toolbar: toolbar)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await openHelp(in: window)
        let row = try helpButton("syntax.guide.tag", context: .search, locale: "en", in: window)
        let rect = try SettingsButtonTestSupport.frame(row, in: window)
        try await SurfaceEventTestSupport.click(NSPoint(x: rect.midX, y: rect.midY), in: window)
        try await settledHelp(window)
        #expect(toolbar.searchText == "query #")
        #expect(composer.tasks.text == "Synthetic capture")
        #expect(!SurfaceConsumerUI.strings(window).contains(L10n.string("syntax.search.title", locale: Locale(identifier: "en"))))
        #expect(MenuBarPopoverRenderingTests().searchField(in: try #require(window.contentView))?.currentEditor() != nil)
        #expect(!support.container.mainContext.hasChanges)
    }

    @Test(arguments: ["close", "outside"])
    func productionHelpPointerDismissal(method: String) async throws {
        try await exerciseDismissal(method: method)
    }

    @Test func productionHelpEscapeEventOwnership() async throws {
        try await exerciseDismissal(method: "escape")
    }

    private func exerciseDismissal(method: String) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let composer = BoardComposerSession()
        composer.tasks.text = "Synthetic original"
        let toolbar = MenuBarToolbarState()
        let window = helpWindow(support, composer: composer, toolbar: toolbar)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await openHelp(in: window)
        try #require(helpVisible(window))
        SurfaceEventTestSupport.note("dismiss \(method) captureEditor=\(captureField(window)?.currentEditor() != nil)")
        describeInput(window)
        if method == "close" {
            try await SettingsButtonTestSupport.click(SettingsButtonTestSupport.button("common.close", in: window), in: window)
        } else if method == "outside" {
            try await SurfaceEventTestSupport.click(NSPoint(x: 6, y: 6), in: window)
        } else {
            let escape = try PickerNativeTestSupport.key(code: 53, chars: "\u{1B}", in: window)
            let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                MainActor.assumeIsolated {
                    SurfaceEventTestSupport.note("observed key=\(event.keyCode) window=\(event.windowNumber)")
                }
                return event
            }
            defer { if let monitor { NSEvent.removeMonitor(monitor) } }
            SurfaceEventTestSupport.note("queue escape code=\(escape.keyCode) chars=\(escape.characters?.utf16.map { $0 } ?? []) "
                + "modifiers=\(escape.modifierFlags.rawValue) window=\(escape.windowNumber)")
            NSApp.postEvent(escape, atStart: false)
            try await SystemPageHost.settle(window)
        }
        try await settledHelp(window)
        SurfaceEventTestSupport.describe(window)
        describeInput(window)
        SurfaceEventTestSupport.note("after \(method) help=\(helpVisible(window)) captureEditor=\(captureField(window)?.currentEditor() != nil)")
        #expect(!helpVisible(window), "关闭路径：\(method)")
        if method == "escape" {
            // 第二次仅定位后续消费分支；不会替代第一次应关闭帮助的断言。
            let second = try PickerNativeTestSupport.key(code: 53, chars: "\u{1B}", in: window)
            NSApp.postEvent(second, atStart: false)
            try await settledHelp(window)
            SurfaceEventTestSupport.note("second escape help=\(helpVisible(window))")
            describeInput(window)
        }
        #expect(composer.tasks.text == "Synthetic original" && toolbar.searchText.isEmpty)
        #expect(!support.container.mainContext.hasChanges)
    }

    // 悬停沿用原断言，独立于本轮三个目标；本轮不重跑或修补。
    @Test func productionHelpNativeHover() async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        let composer = BoardComposerSession()
        composer.tasks.text = "Synthetic original"
        let toolbar = MenuBarToolbarState()
        let window = helpWindow(support, composer: composer, toolbar: toolbar)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await openHelp(in: window)
        let row = try SurfaceConsumerUI.button(containing: L10n.string("syntax.guide.tag", locale: Locale(identifier: "en")), in: window)
        try await SurfaceConsumerUI.hover(row, in: window) {
            #expect(SurfaceConsumerUI.strings(window).contains { $0.contains("#life") })
            #expect(composer.tasks.text == "Synthetic original" && toolbar.searchText.isEmpty)
            #expect(!support.container.mainContext.hasChanges)
            try OverlaySurfaceTestSupport.record(window, name: "e-help-native-hover")
        }
    }

    func helpButton(_ key: String, context: SyntaxInputContext, locale: String, in window: NSWindow) throws -> NSObject {
        let locale = Locale(identifier: locale)
        let title = L10n.string(context == .search ? "syntax.search.title" : "syntax.guide.title", locale: locale)
        try #require(SurfaceConsumerUI.strings(window).contains(title), "当前上下文的帮助必须可见")
        let text = L10n.string(String.LocalizationValue(key), locale: locale)
        let root = try #require(window.contentView)
        let bounds = root.convert(root.bounds, to: nil)
        let candidates = try SettingsButtonTestSupport.buttons(in: window).filter { node in
            let matches = ["accessibilityLabel", "accessibilityTitle", "accessibilityValue"].contains {
                (SettingsButtonTestSupport.value(node, $0) as? String)?.contains(text) == true
            }
            guard matches else { return false }
            return bounds.contains(try SettingsButtonTestSupport.frame(node, in: window))
        }
        try #require(candidates.count == 1, "当前帮助应只有一个可见目标，不能选择第一个过渡或嵌套节点")
        return try #require(candidates.first)
    }

    func describeInput(_ window: NSWindow) {
        SurfaceEventTestSupport.describe(window)
        guard let field = captureField(window),
              let coordinator = field.delegate as? DaybookTextField.Coordinator,
              let state = coordinator.parent.autocomplete else { return }
        SurfaceEventTestSupport.note("capture input editor=\(field.currentEditor() != nil) "
            + "presentation=\(state.hasPresentation) preview=\(state.showsPreview) "
            + "active=\(state.isActive) attributes=\(state.showsAttributes) candidates=\(state.candidates.count) "
            + "onEscape=\(coordinator.parent.onEscape != nil) "
            + "overlayMonitor=\(NativeSyntaxUI.identifiers(in: window).contains("syntax.overlay.event-monitor"))")
    }

    func helpWindow(_ support: SettingsButtonTestSupport, composer: BoardComposerSession,
                            toolbar: MenuBarToolbarState,
                    configuration: (String, ColorScheme, CGFloat) = ("en", .light, 380)) -> NSWindow {
        // 外层 AppChrome 读取随机测试偏好；只给子视图 preferredColorScheme 不足以切换宿主。
        support.prefs.appearance = configuration.1 == .dark ? .dark : .light
        return SystemPageHost.preferenceWindow(
            MenuBarPopoverView(toolbar: toolbar, composer: composer, filterSession: BoardFilterSession())
                .environment(\.locale, Locale(identifier: configuration.0)).preferredColorScheme(configuration.1),
            container: support.container, prefs: support.prefs, size: NSSize(width: configuration.2, height: 490))
    }

    func helpVisible(_ window: NSWindow) -> Bool {
        SurfaceConsumerUI.strings(window).contains(L10n.string("syntax.guide.title", locale: Locale(identifier: "en")))
    }

    func settledHelp(_ window: NSWindow) async throws {
        // 生产帮助有显式 transition，沿原 450ms 观察窗；不按失败次数延长。
        try await Task.sleep(for: .milliseconds(450))
        window.contentView?.layoutSubtreeIfNeeded()
    }

    func openHelp(in window: NSWindow, locale: String = "en") async throws {
        let node = try MenuButtonTestSupport.menu("footer.more", locale: locale, in: window)
        let cell = try #require(node as? NSPopUpButtonCell)
        let label = MenuButtonTestSupport.localized("footer.syntax.guide", locale)
        if let menu = cell.menu, menu.items.contains(where: { $0.title == label && $0.action != nil }) {
            try MenuButtonTestSupport.dispatch(label, in: menu)
            try await settledHelp(window)
            SurfaceEventTestSupport.note("menu cached action returned")
            SurfaceEventTestSupport.describe(window)
            return
        }
        let control = try #require(cell.controlView)
        var tracked: NSMenu?
        var ended = false
        let endObserver = NotificationCenter.default.addObserver(forName: NSMenu.didEndTrackingNotification,
            object: nil, queue: .main) { _ in MainActor.assumeIsolated { ended = true } }
        defer { NotificationCenter.default.removeObserver(endObserver) }
        let observer = NotificationCenter.default.addObserver(forName: NSMenu.didBeginTrackingNotification,
            object: nil, queue: .main) { note in
                MainActor.assumeIsolated { tracked = note.object as? NSMenu }
            }
        defer { NotificationCenter.default.removeObserver(observer) }
        // SwiftUI 菜单在原生 cell 点击时才装配；只派发原控件动作，不伪造菜单或帮助状态。
        let timer = Timer(timeInterval: 0.2, repeats: true) { _ in
            MainActor.assumeIsolated { tracked?.cancelTracking() }
        }
        RunLoop.main.add(timer, forMode: .common)
        defer { timer.invalidate() }
        cell.performClick(withFrame: control.bounds, in: control)
        try await SystemPageHost.settle(window)
        let menu = try #require(tracked, "生产菜单未开始追踪")
        try #require(menu.items.contains { $0.title == label && $0.action != nil },
            "生产菜单项：\(menu.items.map { $0.title + ":" + String(describing: $0.action) })")
        // 派发生产 NSMenuItem 的真实 action；不设置 showingSyntaxHelp，不复制 FooterBar 回调。
        try MenuButtonTestSupport.dispatch(label, in: menu)
        try await settledHelp(window)
        SurfaceEventTestSupport.note("menu began=\(tracked != nil) ended=\(ended)")
        try #require(ended, "菜单追踪尚未结束")
        SurfaceEventTestSupport.describe(window)
    }

    private func activate(_ node: NSObject, in window: NSWindow, accessibility: Bool) async throws {
        if accessibility {
            let action = NSSelectorFromString("accessibilityPerformPress")
            try #require(node.responds(to: action))
            _ = node.perform(action)
            try await SystemPageHost.settle(window)
        } else {
            try await SettingsButtonTestSupport.click(node, in: window)
        }
    }

    func captureField(_ window: NSWindow) -> DaybookAppKitTextField? {
        OverlaySurfaceTestSupport.descendants(window.contentView).compactMap { $0 as? DaybookAppKitTextField }.first {
            ($0.delegate as? DaybookTextField.Coordinator)?.parent.autocomplete?.context == .capture
        }
    }
}
