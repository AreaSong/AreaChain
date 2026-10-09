import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct WorkspaceHeaderSizingTests {
    private let previousAccessibility = NSApp.accessibilityAttributeValue(NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
    @Test func longTitleWithoutActionsKeepsInputAndHasNoEmptyMenu() async throws {
        let nav = WorkspaceNavigation(boardSelection: BoardSelection())
        let tag = TagItem(name: "Synthetic very long navigation title 合成的很长的标签名称", sortOrder: 0)
        nav.selectedTagID = tag.id
        let window = makeWindow(navigation: nav, tags: [tag])
        defer { release(window) }
        window.setContentSize(.init(width: 520, height: 180))
        try await SystemPageHost.settle(window)
        let title = try NativeSyntaxUI.frame("workspace.header.title", in: window)
        let search = try NativeSyntaxUI.frame("syntax.workspace.search.bounds", in: window)
        #expect(!title.intersects(search) && search.width >= 160)
        #expect(!NativeSyntaxUI.identifiers(in: window).contains("workspace.header.more"))
        #expect(fields(window).count == 1)
    }

    @Test func overflowKeepsNativeMenuStateHierarchyAndOneCallback() async throws {
        var calls: [String] = []
        let actions = [
            WorkspaceHeaderAction(id: "create", title: "tags.create", systemImage: "plus") { calls.append("create") },
            WorkspaceHeaderAction(id: "selected", title: "window.calendar", systemImage: "calendar", isActive: true) { calls.append("selected") },
            WorkspaceHeaderAction(id: "disabled", title: "tags.cleanup.unused", systemImage: "trash", isEnabled: false),
            WorkspaceHeaderAction(id: "nested", title: "workspace.recurring.menu", systemImage: "repeat", children: [
                WorkspaceHeaderAction(id: "child", title: "recurring.create.open", systemImage: "plus", isEnabled: false),
                WorkspaceHeaderAction(id: "group", title: "workspace.residents.open", systemImage: "repeat", children: [
                    WorkspaceHeaderAction(id: "leaf", title: "common.save", systemImage: "checkmark") { calls.append("leaf") }
                ])
            ]),
            WorkspaceHeaderAction(id: "danger", title: "trash.purge", systemImage: "trash", role: .destructive, overflowOnly: true) { calls.append("danger") }
        ]
        let nav = WorkspaceNavigation(boardSelection: BoardSelection())
        let window = makeWindow(navigation: nav, content: .init(actions: actions))
        defer { release(window) }
        window.setContentSize(.init(width: 360, height: 180))
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let node = try MenuButtonTestSupport.menu("workspace.toolbar.more", in: window)
        let menu = try await MenuButtonTestSupport.openAndEscape(node, in: window)
        let items = menu.items.filter { !$0.isSeparatorItem }
        #expect(items.map(\.title) == ["tags.create", "window.calendar", "tags.cleanup.unused", "workspace.recurring.menu", "trash.purge"]
            .map { MenuButtonTestSupport.localized($0, "en") })
        #expect(items[1].state == .on && items[1].image != nil)
        #expect(!items[2].isEnabled && items[3].isEnabled)
        let children = try #require(items[3].submenu).items
        #expect(!children[0].isEnabled)
        let nested = try #require(children[1].submenu)
        #expect(calls.isEmpty)
        try MenuButtonTestSupport.dispatch(MenuButtonTestSupport.localized("tags.create", "en"), in: menu)
        try MenuButtonTestSupport.dispatch(MenuButtonTestSupport.localized("common.save", "en"), in: nested)
        try MenuButtonTestSupport.dispatch(MenuButtonTestSupport.localized("trash.purge", "en"), in: menu)
        #expect(calls == ["create", "leaf", "danger"])
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func measuredActionsAndCenteredSearchShareOneBand(locale: String, scheme: ColorScheme) async throws {
        let navigation = WorkspaceNavigation(boardSelection: BoardSelection())
        navigation.revealTab(.today)
        let actions = [
            WorkspaceHeaderAction(id: "create", title: "recurring.create.open", systemImage: "plus"),
            WorkspaceHeaderAction(id: "manage", title: "workspace.residents.open", systemImage: "repeat"),
            WorkspaceHeaderAction(id: "disabled", title: "tags.cleanup.unused", systemImage: "trash", isEnabled: false),
            WorkspaceHeaderAction(id: "overflow", title: "trash.purge", systemImage: "trash", role: .destructive, overflowOnly: true)
        ]
        let content = WorkspaceHeaderContent(actions: actions, status: AnyView(Text("12/345").monospacedDigit()))
        let window = makeWindow(navigation: navigation, content: content, locale: locale, scheme: scheme)
        defer { release(window) }
        var counts: [Int] = []
        for width in [520.0, 640, 780, 980, 1400] {
            window.setContentSize(.init(width: width, height: 180))
            try await SystemPageHost.settle(window)
            let header = try NativeSyntaxUI.frame("syntax.workspace.header.bounds", in: window)
            let search = try NativeSyntaxUI.frame("syntax.workspace.search.bounds", in: window)
            let title = try NativeSyntaxUI.frame("workspace.header.title", in: window)
            let actionsFrame = try NativeSyntaxUI.frame("syntax.workspace.actions.bounds", in: window)
            #expect(abs(header.height - 50) < 1 && abs(header.midY - search.midY) < 1)
            #expect(abs(header.midX - search.midX) < 1 && search.width >= 160)
            #expect(!title.intersects(search) && !actionsFrame.intersects(search))
            #expect(actionsFrame.maxX <= header.maxX && title.minX >= header.minX)
            let ids = NativeSyntaxUI.identifiers(in: window)
            let visible = actions.filter { ids.contains("workspace.header.action." + $0.id) }.map(\.id)
            #expect(visible == Array(["create", "manage", "disabled"].prefix(visible.count)))
            #expect(ids.contains("workspace.header.more"))
            #expect(fields(window).count == 1)
            counts.append(visible.count)
        }
        #expect(counts == counts.sorted() && counts.first! < counts.last!)
    }

    @Test func resizingKeepsEditorSelectionMarkedTextAndUndo() async throws {
        let navigation = WorkspaceNavigation(boardSelection: BoardSelection())
        let window = makeWindow(navigation: navigation)
        defer { release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let field = try #require(fields(window).first)
        try #require(window.makeFirstResponder(field))
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.insertText("Synthetic query", replacementRange: editor.selectedRange())
        try await SystemPageHost.settle(window)
        editor.setSelectedRange(NSRange(location: 2, length: 4))
        for width in [520.0, 780, 1100, 519, 520, 521] {
            window.setContentSize(.init(width: width, height: 180))
            try await SystemPageHost.settle(window)
            #expect(fields(window).count == 1 && fields(window).first === field)
            #expect(window.firstResponder === editor)
            #expect(editor.selectedRange() == NSRange(location: 2, length: 4))
            #expect(navigation.searchQuery == "Synthetic query")
        }
        editor.setMarkedText("拼音", selectedRange: NSRange(location: 2, length: 0), replacementRange: editor.selectedRange())
        let marked = editor.markedRange()
        window.setContentSize(.init(width: 600, height: 180))
        try await SystemPageHost.settle(window)
        #expect(editor.hasMarkedText() && editor.markedRange() == marked && window.firstResponder === editor)
        editor.unmarkText()
        editor.insertText(" committed", replacementRange: editor.selectedRange())
        try await SystemPageHost.settle(window)
        let committed = navigation.searchQuery
        let undo = try #require(editor.undoManager)
        #expect(undo.canUndo)
        undo.undo()
        try await SystemPageHost.settle(window)
        #expect(navigation.searchQuery != committed)
        undo.redo()
        try await SystemPageHost.settle(window)
        #expect(navigation.searchQuery == committed)
    }

    private func makeWindow(navigation: WorkspaceNavigation, content: WorkspaceHeaderContent = .init(),
                            locale: String = "en", scheme: ColorScheme = .light, tags: [TagItem] = []) -> NSWindow {
        let root = WorkspaceHeaderBar(navigation: navigation, tags: tags, content: content)
            .frame(maxHeight: .infinity, alignment: .top)
            .environment(\.locale, Locale(identifier: locale)).preferredColorScheme(scheme)
            .syntaxOverlayHost()
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 980, height: 180),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: root)
        NSApp.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return window
    }

    private func fields(_ window: NSWindow) -> [DaybookAppKitTextField] {
        ScrollNativeEvidence.views(window).compactMap { $0 as? DaybookAppKitTextField }
    }

    private func release(_ window: NSWindow) {
        window.makeFirstResponder(nil)
        window.contentView = nil
        window.orderOut(nil)
        NSApp.accessibilitySetValue(previousAccessibility ?? false, forAttribute: NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
    }
}
