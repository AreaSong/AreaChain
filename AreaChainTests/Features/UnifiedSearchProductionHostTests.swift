import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 合并批 M-6 检查点 E：两个宿主按开关显示新／旧搜索，并能在运行中切换。后台窗口、只程序化输入，不发键鼠事件。
/// 截图作为结果包附件，供人工逐张查看中英文、浅深色、正常与最小窗口。
@Suite(.serialized, .tags(.backgroundWindow)) @MainActor struct UnifiedSearchProductionHostTests {
    @MainActor final class Host {
        let fixture: UnifiedSearchProductionFixture
        let production = UnifiedSearchProduction()
        var window: NSWindow?
        init() throws {
            fixture = try UnifiedSearchProductionFixture()
            production.start(preferences: fixture.preferences, center: fixture.center, makeServices: { [fixture] in fixture.services() })
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
        func toggle(_ enabled: Bool) async throws {
            fixture.preferences.unifiedSearchEnabled = enabled
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

    @Test(arguments: [0, 1, 2, 3]) func workspaceShowsNewSearchAndSwitchesBack(style: Int) async throws {
        let host = try Host()
        defer { host.close() }
        try host.fixture.insert(TodoItem(title: "needle 合成正式版任务", dayKey: UnifiedSearchProductionFixture.today))
        try await host.show(UnifiedSearchWorkspaceRoot(production: host.production), style: style,
                            size: NSSize(width: 1200, height: 800), minSize: DaybookMetrics.Window.workspaceMinSize)
        // 开（默认）：顶栏是新搜索框，打开工作台仍落在原页面，不是空的搜索页。
        #expect(host.unifiedFields == 1 && !host.identifiers().contains("workspace.header.search.shell"))
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
        // 关：立即回到原搜索框与原页面；新搜索的读取会话已撤销。
        try await host.toggle(false)
        #expect(host.unifiedFields == 0 && host.identifiers().contains("workspace.header.search.shell"))
        #expect(controller.session.diagnostic == .detached && !host.fixture.navigation.isSearching)
        try host.snapshot("m6-workspace-off-\(style)")
        // 再开：未提交的查询仍在（协调者保留），新控制器接上同一查询。
        try await host.toggle(true)
        #expect(host.unifiedFields == 1 && host.production.assembly?.workspace.buffer.text == "needle")
    }

    @Test(arguments: [0, 3]) func menuBarShowsNewSearchAndSwitchesBack(style: Int) async throws {
        let host = try Host()
        defer { host.close() }
        try host.fixture.insert(TodoItem(title: "needle 合成浮层任务", dayKey: UnifiedSearchProductionFixture.today))
        let toolbar = MenuBarToolbarState()
        try await host.show(MenuBarPopoverView(toolbar: toolbar, composer: BoardComposerSession(), filterSession: BoardFilterSession(),
                                               production: host.production),
                            style: style, size: DaybookMetrics.Window.popoverSize, minSize: nil)
        #expect(host.identifiers().contains("menubar.unified.input") && !host.identifiers().contains("menubar.search.input"))
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
        try await host.toggle(false)
        #expect(host.identifiers().contains("menubar.search.input") && !host.identifiers().contains("menubar.unified.input"))
        #expect(!toolbar.unifiedActive && !toolbar.isSearching)
        try host.snapshot("m6-menubar-off-\(style)")
    }
}
