import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct WorkspaceInspectorSizingTests {
    @Test func unattachedMeasurementCannotReplaceWindowMarker() throws {
        let owner = WorkspaceInspectorFocus()
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 300, height: 200),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let live = NSView()
        window.contentView = live
        defer { window.contentView = nil; window.orderOut(nil) }
        owner.attach(live)
        try #require(owner.marker === live)
        owner.attach(NSView())
        #expect(owner.marker === live)
    }

    @Test(arguments: [false, true])
    func markedDetailDraftSurvivesActualCollapse(title: Bool) async throws {
        let fixture = try SettingsButtonTestSupport(isolatedPreferences: true)
        let restore = CalendarSpanTestSupport.preserveState()
        let nav = WorkspaceNavigation.shared
        let todo = TodoItem(title: "Synthetic title", dayKey: DayClock.shared.todayKey)
        todo.notes = "Synthetic notes"
        fixture.container.mainContext.insert(todo)
        try fixture.container.mainContext.save()
        let key = "todo-\(todo.id)"
        defer {
            restore(); fixture.cleanup(); nav.updateInspectorSpace(available: true)
            EditDrafts.shared.titles.removeValue(forKey: key)
            EditDrafts.shared.notes.removeValue(forKey: key)
        }
        nav.clearSearch()
        nav.revealTab(.today)
        let window = makeWindow(fixture)
        defer { release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await settle(window)
        if title { EditDrafts.shared.titles[key] = todo.title }
        nav.inspectTask(todo.id, dayKey: todo.dayKey)
        try await settle(window)
        let editor = try detailEditor(window, title: title)
        try #require(window.makeFirstResponder(editor))
        editor.setMarkedText("合成组合草稿", selectedRange: .init(location: 6, length: 0),
                             replacementRange: .init(location: 0, length: editor.string.utf16.count))
        try await settle(window)
        try #require(editor.hasMarkedText())
        let draft = editor.string
        window.setContentSize(.init(width: 780, height: 600))
        try await settle(window)
        #expect(!nav.isInspectorPresented && nav.selectedTaskID == todo.id && nav.inspectingDayKey == todo.dayKey)
        #expect(window.firstResponder !== editor)
        let search = try #require(fields(window).first {
            $0.placeholderString == L10n.string("workspace.search.placeholder", locale: Locale(identifier: "en"))
        })
        #expect(window.firstResponder === search.currentEditor() && nav.isSearchFocused && nav.searchQuery.isEmpty)
        #expect(todo.title == "Synthetic title" && todo.notes == "Synthetic notes")
        #expect((title ? EditDrafts.shared.titles[key] : EditDrafts.shared.notes[key]) == draft)
        window.setContentSize(.init(width: 1400, height: 700))
        try await settle(window)
        #expect(!nav.isInspectorPresented)
        nav.isInspectorPresented = true
        try await settle(window)
        let restored = try detailEditor(window, title: title)
        #expect(restored.string == draft)
        try #require(window.makeFirstResponder(restored))
        restored.insertText(" confirmed", replacementRange: .init(location: restored.string.utf16.count, length: 0))
        try await settle(window)
        let expected = restored.string
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: title ? [] : [.command], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, characters: "\r", charactersIgnoringModifiers: "\r",
            isARepeat: false, keyCode: 36))
        if title { window.sendEvent(event) } else { #expect(window.performKeyEquivalent(with: event)) }
        try await settle(window)
        #expect((title ? todo.title : todo.notes) == expected)
        #expect((title ? EditDrafts.shared.titles[key] : EditDrafts.shared.notes[key]) == nil)
    }

    private func detailEditor(_ window: NSWindow, title: Bool) throws -> NSTextView {
        if title {
            let input = try #require(fields(window).first { $0.placeholderString == L10n.string("drawer.title.placeholder", locale: Locale(identifier: "en")) })
            try #require(window.makeFirstResponder(input))
            return try #require(input.currentEditor() as? NSTextView)
        }
        let editors = ScrollNativeEvidence.views(window).compactMap { $0 as? NSTextView }
            .filter { $0.isEditable && !$0.isFieldEditor && !$0.isHiddenOrHasHiddenAncestor && !$0.visibleRect.isEmpty }
        try #require(editors.count == 1)
        return try #require(editors.first)
    }

    @Test func searchKeepsFocusAcrossSidebarResizeInspectorCollapseAndBodyReplacement() async throws {
        let fixture = try SettingsButtonTestSupport(isolatedPreferences: true)
        let restore = CalendarSpanTestSupport.preserveState()
        let nav = WorkspaceNavigation.shared
        let oldDraft = nav.todayDraft
        defer { restore(); fixture.cleanup(); nav.todayDraft = oldDraft; nav.updateInspectorSpace(available: true) }
        let todo = TodoItem(title: "Synthetic focus target", dayKey: DayClock.shared.todayKey)
        fixture.container.mainContext.insert(todo)
        try fixture.container.mainContext.save()
        nav.clearSearch()
        nav.revealTab(.today)
        nav.todayDraft = "Synthetic retained composer"
        let window = makeWindow(fixture)
        defer { release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await settle(window)
        nav.inspectTask(todo.id)
        try await settle(window)
        #expect(nav.isInspectorPresented)
        let sidebar = try #require(ScrollNativeEvidence.views(window).first {
            $0.identifier?.rawValue == "syntax.workspace.sidebar.bounds"
        })
        var ancestor = sidebar.superview
        while ancestor != nil && !(ancestor is NSSplitView) { ancestor = ancestor?.superview }
        let split = try #require(ancestor as? NSSplitView)
        split.setPosition(260, ofDividerAt: 0)
        try await settle(window)
        let search = try #require(fields(window).first {
            $0.placeholderString == L10n.string("workspace.search.placeholder", locale: Locale(identifier: "en"))
        })
        try #require(window.makeFirstResponder(search))
        let editor = try #require(search.currentEditor() as? NSTextView)
        nav.isSearchFocused = true
        window.setContentSize(.init(width: 780, height: 600))
        try await settle(window)
        #expect(!nav.isInspectorPresented && window.firstResponder === editor)
        #expect(fields(window).contains { $0 === search })
        editor.insertText("Synthetic", replacementRange: editor.selectedRange())
        try await settle(window)
        #expect(nav.isSearching && window.firstResponder === editor)
        #expect(fields(window).contains { $0 === search })
        #expect(nav.todayDraft == "Synthetic retained composer")
        nav.clearSearch()
        try await settle(window)
        #expect(nav.todayDraft == "Synthetic retained composer" && nav.selectedTaskID == nil)
        #expect(todo.title == "Synthetic focus target" && !fixture.container.mainContext.hasChanges)
    }

    @Test func eachWorkspaceScrollOwnsOneFeatherAndLeavesHeaderFixed() async throws {
        let fixture = try SettingsButtonTestSupport(isolatedPreferences: true)
        let restore = CalendarSpanTestSupport.preserveState()
        let nav = WorkspaceNavigation.shared
        defer { restore(); fixture.cleanup(); nav.updateInspectorSpace(available: true) }
        let today = DayClock.shared.todayKey
        for index in 0..<35 {
            fixture.container.mainContext.insert(TodoItem(title: "Synthetic task \(index)", dayKey: today))
            fixture.container.mainContext.insert(DiaryEntry(text: "Synthetic note \(index)", dayKey: today))
            fixture.container.mainContext.insert(TagItem(name: "Synthetic tag \(index)", sortOrder: index))
        }
        try fixture.container.mainContext.save()
        nav.clearSearch()
        let window = makeWindow(fixture)
        defer { release(window) }
        var oldEdges: [DaybookScrollEdgeObserverNSView] = []
        for tab in [WorkspaceTab.today, .allItems, .pending, .diary, .tags, .settings, .calendar, .quadrant, .gantt] {
            print("WORKSPACE_SHELL scroll route \(tab.rawValue)")
            nav.revealTab(tab)
            try await settle(window)
            let edges = ScrollNativeEvidence.views(window).compactMap { $0 as? DaybookScrollEdgeObserverNSView }
            let targets = edges.compactMap(\.currentScrollView)
            #expect(!targets.isEmpty && Set(targets.map(ObjectIdentifier.init)).count == targets.count)
            if tab == .tags { #expect(targets.count == 2, "侧栏和标签清单各有一个滚动羽化宿主") }
            for edge in oldEdges where !edges.contains(where: { $0 === edge }) {
                #expect(edge.currentScrollView == nil)
            }
            let header = try NativeSyntaxUI.frame("syntax.workspace.header.bounds", in: window)
            for (index, target) in targets.enumerated() {
                let otherOrigins = targets.enumerated().filter { $0.offset != index }.map { $0.element.contentView.bounds.origin }
                let maximum = max(0, (target.documentView?.bounds.height ?? 0) - target.documentVisibleRect.height)
                target.contentView.scroll(to: .init(x: 0, y: min(maximum, 100)))
                try await settle(window)
                #expect(try NativeSyntaxUI.frame("syntax.workspace.header.bounds", in: window) == header)
                #expect(targets.enumerated().filter { $0.offset != index }.map { $0.element.contentView.bounds.origin } == otherOrigins)
            }
            oldEdges = edges
        }
        nav.searchQuery = "Synthetic"
        try await settle(window)
        nav.clearSearch()
        try await settle(window)
        #expect(!fixture.container.mainContext.hasChanges)
    }

    @Test func nativeColumnsCloseKeepSelectionAndRequireManualReopen() async throws {
        let fixture = try SettingsButtonTestSupport(isolatedPreferences: true)
        let restore = CalendarSpanTestSupport.preserveState()
        let navigation = WorkspaceNavigation.shared
        defer { restore(); fixture.cleanup(); navigation.updateInspectorSpace(available: true) }
        let day = DayClock.shared.todayKey
        let todo = TodoItem(title: "Synthetic inspection", dayKey: day)
        fixture.container.mainContext.insert(todo)
        try fixture.container.mainContext.save()
        navigation.clearSearch()
        navigation.revealTab(.today)
        let window = makeWindow(fixture)
        defer { release(window) }
        try await settle(window)
        print("WORKSPACE_SHELL initial wide ready")
        #expect(navigation.isInspectorSpaceAvailable)
        navigation.inspectTask(todo.id, dayKey: day)
        try await settle(window)
        print("WORKSPACE_SHELL inspector presented=\(navigation.isInspectorPresented)")
        #expect(navigation.isInspectorPresented && navigation.canInspectSelectedTask)
        let placeholder = L10n.string("workspace.search.placeholder", locale: Locale(identifier: "en"))
        let search = try #require(fields(window).first { $0.placeholderString == placeholder })
        let before = try NativeSyntaxUI.frame("syntax.workspace.header.bounds", in: window)
        #expect(before.width < window.frame.width - 400)
        window.setContentSize(.init(width: 780, height: 600))
        try await settle(window)
        print("WORKSPACE_SHELL narrow ready")
        #expect(!navigation.isInspectorPresented && !navigation.isInspectorSpaceAvailable)
        #expect(navigation.selectedTaskID == todo.id && navigation.inspectingDayKey == day)
        #expect(fields(window).contains { $0 === search })
        for width in [779.0, 780, 781, 800] {
            window.setContentSize(.init(width: width, height: 600))
            try await settle(window)
            navigation.inspectTask(todo.id, dayKey: day)
            #expect(!navigation.isInspectorPresented)
        }
        window.setContentSize(.init(width: 1400, height: 700))
        try await settle(window)
        #expect(!navigation.isInspectorPresented && navigation.canPresentInspector)
        navigation.isInspectorPresented = true
        try await settle(window)
        #expect(navigation.isInspectorPresented)
        navigation.updateInspectorTargets([])
        try await settle(window)
        #expect(!navigation.isInspectorPresented && navigation.selectedTaskID == nil)
        #expect(todo.title == "Synthetic inspection" && !fixture.container.mainContext.hasChanges)
    }

    private func makeWindow(_ fixture: SettingsButtonTestSupport) -> NSWindow {
        let content = MainSplitWorkspaceView().modelContainer(fixture.container).environment(fixture.prefs)
            .environment(\.locale, Locale(identifier: "en"))
            .preferredColorScheme(.light)
            .transaction { $0.disablesAnimations = true }
        let window = NSWindow(contentViewController: NSHostingController(rootView: content))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.setContentSize(.init(width: 1400, height: 700))
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return window
    }

    private func release(_ window: NSWindow) {
        window.makeFirstResponder(nil)
        window.orderOut(nil)
        window.toolbar = nil
        // 与原 WorkspaceRenderingTests 相同：先退出 fullSizeContentView，再注销系统侧栏分隔条。
        window.styleMask.remove(.fullSizeContentView)
        window.contentViewController = nil
    }

    private func fields(_ window: NSWindow) -> [DaybookAppKitTextField] {
        ScrollNativeEvidence.views(window).compactMap { $0 as? DaybookAppKitTextField }
    }

    private func settle(_ window: NSWindow) async throws {
        try await SystemPageHost.settle(window)
        try await Task.sleep(for: .milliseconds(250))
        window.contentView?.layoutSubtreeIfNeeded()
    }
}
