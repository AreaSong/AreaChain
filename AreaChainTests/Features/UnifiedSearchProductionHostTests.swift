import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 合并批 M-6 检查点 E：两个宿主显示统一搜索；收尾批 M-7 删除旧搜索后，装配失败时搜索框显示不阻塞的说明。
/// 后台窗口、只程序化输入，不发键鼠事件。
/// 截图作为结果包附件，供人工逐张查看中英文、浅深色、正常与最小窗口。
@Suite(.serialized, .tags(.backgroundWindow)) @MainActor struct UnifiedSearchProductionHostTests {
    @MainActor final class Host {
        let fixture: UnifiedSearchProductionFixture
        let production = UnifiedSearchProduction()
        var window: NSWindow?
        var fails = false
        init(failing: Bool = false, productionPages: Bool = false) throws {
            fixture = try UnifiedSearchProductionFixture()
            fails = failing
            production.assemble = { [unowned self] services, coordinator in
                fails ? .failure(CommandHandoffError.stale) : UnifiedSearchProductionAssembly.attempt(services: services, coordinator: coordinator)
            }
            production.start(center: fixture.center, makeServices: { [fixture] in fixture.services(productionAttachments: productionPages) })
        }
        func show<Content: View>(_ root: Content, style: Int, size: NSSize, minSize: NSSize?) async throws {
            let content = root.modelContainer(fixture.container).environment(\.modelContext, fixture.context)
                .environment(fixture.preferences)
                .environment(\.locale, Locale(identifier: style < 2 ? "en" : "zh-Hans"))
                .preferredColorScheme(style % 2 == 1 ? .dark : .light)
                .transaction { $0.disablesAnimations = true }
            let window = NSWindow(contentViewController: NSHostingController(rootView: content))
            window.isReleasedWhenClosed = false
            window.isRestorable = false
            window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            if let minSize { window.minSize = minSize }
            window.setContentSize(size)
            window.appearance = NSAppearance(named: style % 2 == 1 ? .darkAqua : .aqua)
            self.window = window
            NSApp.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
            try await NativeSyntaxUI.prepareBackground(in: window)
            try await settle()
        }
        func settle() async throws { if let window { try await SystemPageHost.settle(window) } }
        func identifiers() -> Set<String> {
            Set(SettingsButtonTestSupport.elements(window?.contentView).compactMap {
                SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String
            })
        }
        var unifiedFields: Int {
            SettingsButtonTestSupport.elements(window?.contentView).compactMap { $0 as? NSTextField }
                .filter { $0.cell is UnifiedSearchFieldCell }.count
        }
        /// 任一偏好变化都会让失败的装配重试一次。
        func retry(failing: Bool) async throws {
            fails = failing
            fixture.center.post(name: .appPreferencesDidChange, object: nil)
            try await settle()
        }
        func snapshot(_ name: String) throws {
            let view = try #require(window?.contentView)
            let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            Attachment.record(try #require(bitmap.representation(using: .png, properties: [:])), named: name + ".png")
        }
        func close() {
            if let window { SystemPageHost.release(window) }
            production.stop(center: fixture.center)
            fixture.cleanup()
        }
    }

    @Test(arguments: [0, 1, 2, 3]) func workspaceShowsUnifiedSearch(style: Int) async throws {
        let host = try Host()
        defer { host.close() }
        try host.fixture.insert(TodoItem(title: "needle 合成正式版任务", dayKey: UnifiedSearchProductionFixture.today))
        try await host.show(UnifiedSearchWorkspaceRoot(production: host.production), style: style,
                            size: NSSize(width: 1200, height: 800), minSize: DaybookMetrics.Window.workspaceMinSize)
        // 顶栏是统一搜索框，打开工作台仍落在原页面，不是空的搜索页。
        #expect(host.unifiedFields == 1 && !host.identifiers().contains("workspace.header.search.unavailable"))
        #expect(!host.fixture.navigation.isSearching)
        let controller = try #require(host.production.assembly?.workspace)
        _ = controller.edit(.init(source: controller.buffer, text: "needle", selection: .init(location: 6, length: 0)))
        for _ in 0..<100 where (try? controller.session.presentation()) == nil { try await Task.sleep(for: .milliseconds(20)) }
        try await host.settle()
        #expect(host.fixture.navigation.isSearching)
        try host.snapshot("m6-workspace-on-\(style)")
        if style >= 2 {
            host.window?.setFrame(NSRect(origin: .zero, size: DaybookMetrics.Window.workspaceMinSize), display: true)
            try await host.settle()
            #expect(host.unifiedFields == 1)
            // 最小窗口：新搜索框不越过顶栏布局给的宽度上限，不盖住标题区。
            let field = try #require(SettingsButtonTestSupport.elements(host.window?.contentView).compactMap { $0 as? NSTextField }
                .first { $0.cell is UnifiedSearchFieldCell })
            #expect(field.superview.map { $0.convert($0.bounds, to: nil).width } ?? 0 <= WorkspaceLayout.searchMaxWidth + 1)
            try host.snapshot("m6-workspace-min-\(style)")
        }
        // 偏好变化不重建已有装配：同一控制器、查询仍在。
        try await host.retry(failing: false)
        #expect(host.unifiedFields == 1 && host.production.assembly?.workspace === controller && controller.buffer.text == "needle")
    }

    @Test(arguments: [0, 3]) func menuBarShowsUnifiedSearch(style: Int) async throws {
        let host = try Host()
        defer { host.close() }
        try host.fixture.insert(TodoItem(title: "needle 合成浮层任务", dayKey: UnifiedSearchProductionFixture.today))
        let toolbar = MenuBarToolbarState()
        try await host.show(MenuBarPopoverView(toolbar: toolbar, composer: BoardComposerSession(), filterSession: BoardFilterSession(),
                                               production: host.production),
                            style: style, size: DaybookMetrics.Window.popoverSize, minSize: nil)
        #expect(host.identifiers().contains("menubar.unified.input") && !host.identifiers().contains("menubar.search.unavailable"))
        #expect(!toolbar.isSearching)
        // 底栏不被新搜索框撑宽：输入框右缘留出右侧动作区（56pt），整行不越出浮层。
        let field = try #require(SettingsButtonTestSupport.elements(host.window?.contentView).compactMap { $0 as? NSTextField }
            .first { $0.cell is UnifiedSearchFieldCell })
        #expect(field.convert(field.bounds, to: nil).maxX <= DaybookMetrics.Window.popoverWidth - 56)
        let controller = try #require(host.production.assembly?.menubar)
        _ = controller.edit(.init(source: controller.buffer, text: "needle", selection: .init(location: 6, length: 0)))
        for _ in 0..<100 where (try? controller.session.presentation()) == nil { try await Task.sleep(for: .milliseconds(20)) }
        try await host.settle()
        #expect(toolbar.isSearching && toolbar.unifiedActive && host.identifiers().contains("menubar.unified.content"))
        // 浮层焦点与新搜索框双向同步：原有的 ⌘F 等入口只调 toolbar.focusSearch()。
        toolbar.searchIsFocused = false
        try await host.settle()
        #expect(!controller.inputFocused)
        toolbar.focusSearch()
        try await host.settle()
        #expect(controller.inputFocused)
        try host.snapshot("m6-menubar-on-\(style)")
    }

    /// 收尾批 M-7：装配失败没有旧搜索可退，两个宿主的搜索框位置显示一句不阻塞的说明（中英文），
    /// 工作台与浮层其余部分照常；⌘F 等入口不会把浮层卡在“搜索焦点”上；偏好变化重试成功后换回统一搜索框。
    @Test(arguments: [0, 1, 2, 3]) func assemblyFailureIsExplainedInBothSearchBoxes(style: Int) async throws {
        let host = try Host(failing: true)
        defer { host.close() }
        #expect(host.production.assembly == nil && host.production.assemblyFailed)
        try await host.show(UnifiedSearchWorkspaceRoot(production: host.production), style: style,
                            size: NSSize(width: 1200, height: 800), minSize: DaybookMetrics.Window.workspaceMinSize)
        #expect(host.unifiedFields == 0)
        #expect(host.identifiers().isSuperset(of: ["workspace.header.search.unavailable", "workspace.header.bar", "workspace.header.title"]))
        try host.snapshot("m7-workspace-unavailable-\(style)")
        if style >= 2 {
            host.window?.setFrame(NSRect(origin: .zero, size: DaybookMetrics.Window.workspaceMinSize), display: true)
            try await host.settle()
            #expect(host.identifiers().contains("workspace.header.search.unavailable"))
            try host.snapshot("m7-workspace-unavailable-min-\(style)")
        }
        try await host.retry(failing: false)
        #expect(host.unifiedFields == 1 && !host.identifiers().contains("workspace.header.search.unavailable"))

        let menu = try Host(failing: true)
        defer { menu.close() }
        let toolbar = MenuBarToolbarState()
        try await menu.show(MenuBarPopoverView(toolbar: toolbar, composer: BoardComposerSession(), filterSession: BoardFilterSession(),
                                               production: menu.production),
                            style: style, size: DaybookMetrics.Window.popoverSize, minSize: nil)
        #expect(menu.unifiedFields == 0 && menu.identifiers().contains("menubar.search.unavailable"))
        #expect(menu.identifiers().contains("menubar.filter.open") && menu.identifiers().contains("menubar.workspace.open"))
        toolbar.focusSearch()
        try await menu.settle()
        #expect(!toolbar.searchIsFocused && !toolbar.isSearching)
        try menu.snapshot("m7-menubar-unavailable-\(style)")
        try await menu.retry(failing: false)
        #expect(menu.unifiedFields == 1 && !menu.identifiers().contains("menubar.search.unavailable"))
        let expected: [(String, String, String)] = [
            ("search.unavailable", "暂不可用", "unavailable"), ("search.unavailable.short", "暂不可用", "unavailable"),
            ("search.unavailable.help", "未能启动", "couldn't start")]
        for (key, chinese, english) in expected {
            #expect(L10n.string(String.LocalizationValue(key), locale: Locale(identifier: "zh-Hans")).contains(chinese))
            #expect(L10n.string(String.LocalizationValue(key), locale: Locale(identifier: "en")).contains(english))
        }
    }

    /// 收尾批 M-7：正式版宿主（共享存储）下工作台的系统类页面照常可操作；隔离宿主仍只读呈现。
    /// 删除开关前正式版也带宿主，这些页被整页禁用，只能靠关开关退回；删除开关后必须由宿主类型区分。
    @Test func productionHostKeepsSystemPagesOperable() async throws {
        for production in [true, false] {
            let host = try Host(productionPages: production)
            defer { host.close() }
            host.fixture.navigation.revealTab(.shortcuts)
            try await host.show(UnifiedSearchWorkspaceRoot(production: host.production), style: 0,
                                size: NSSize(width: 1200, height: 800), minSize: DaybookMetrics.Window.workspaceMinSize)
            #expect(host.production.assembly?.hostContext.isIsolated == !production)
            let label = L10n.string("shortcut.resetAll", locale: Locale(identifier: "en"))
            let node = try #require(SettingsButtonTestSupport.elements(host.window?.contentView).first {
                SettingsButtonTestSupport.value($0, "accessibilityRole") as? String == "AXButton"
                    && String(describing: SettingsButtonTestSupport.value($0, "accessibilityLabel") ?? "") == label
            })
            #expect((node.value(forKey: "accessibilityEnabled") as? NSNumber)?.boolValue == production)
            #expect(host.fixture.probe.total == 0 && host.fixture.saves == 0)
        }
    }
}
