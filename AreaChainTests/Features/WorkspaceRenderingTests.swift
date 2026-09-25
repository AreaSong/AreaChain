import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct WorkspaceRenderingTests {
    private static var retainedContainers: [ModelContainer] = []

    private struct RouteAppearance: Sendable {
        var scheme: ColorScheme
        var minimumSize: Bool
        var language: String
    }

    private static let routeAppearances: [RouteAppearance] = [
        RouteAppearance(scheme: .light, minimumSize: false, language: "zh-Hans"),
        RouteAppearance(scheme: .light, minimumSize: true, language: "zh-Hans"),
        RouteAppearance(scheme: .dark, minimumSize: false, language: "zh-Hans"),
        RouteAppearance(scheme: .dark, minimumSize: true, language: "zh-Hans"),
        RouteAppearance(scheme: .light, minimumSize: false, language: "en"),
        RouteAppearance(scheme: .light, minimumSize: true, language: "en"),
        RouteAppearance(scheme: .dark, minimumSize: false, language: "en"),
        RouteAppearance(scheme: .dark, minimumSize: true, language: "en")
    ]

    @Test(arguments: routeAppearances)
    private func allWorkspaceRoutesRenderWithIsolatedData(_ appearance: RouteAppearance) async throws {
        let previous = NavigationSnapshot()
        let previousAppearance = NSApp.appearance
        defer { previous.restore(); NSApp.appearance = previousAppearance }
        let fixture = try makeFixture()
        let window = makeWindow(
            fixture,
            scheme: appearance.scheme,
            minimumSize: appearance.minimumSize,
            localeIdentifier: appearance.language
        )
        defer { release(window) }
        let view = try #require(window.contentView)
        for tab in WorkspaceTab.allCases {
            WorkspaceNavigation.shared.revealTab(tab)
            WorkspaceNavigation.shared.isInspectorPresented = false
            try await settle(view)
            try assertFits(view, in: window)
            try snapshot(
                view,
                name: imageName(
                    tab.rawValue,
                    scheme: appearance.scheme,
                    minimumSize: appearance.minimumSize,
                    localeIdentifier: appearance.language
                )
            )
        }
        WorkspaceNavigation.shared.selectedTagID = fixture.tag.id
        try await settle(view)
        try assertFits(view, in: window)
        try snapshot(
            view,
            name: imageName(
                "tag",
                scheme: appearance.scheme,
                minimumSize: appearance.minimumSize,
                localeIdentifier: appearance.language
            )
        )
    }

    @Test(arguments: [ColorScheme.light, .dark], [false, true])
    func taskAndRoutineInspectorsRenderWithoutChangingModels(scheme: ColorScheme, minimumSize: Bool) async throws {
        let previous = NavigationSnapshot()
        let previousAppearance = NSApp.appearance
        defer { previous.restore(); NSApp.appearance = previousAppearance }
        let fixture = try makeFixture()
        let window = makeWindow(fixture, scheme: scheme, minimumSize: minimumSize)
        defer { release(window) }
        let view = try #require(window.contentView)
        let nav = WorkspaceNavigation.shared
        nav.revealTab(.today)
        try await settle(view)
        let composerY = try taskComposerFrame(in: view).minY
        for (name, id) in [("todo", fixture.todo.id), ("routine", fixture.routine.id)] {
            nav.inspectTask(id)
            try await settle(view)
            try assertFits(view, in: window)
            #expect(abs(try taskComposerFrame(in: view).minY - composerY) < 1,
                    "展开检查器后，页头操作不应换行并推低输入区")
            try snapshot(view, name: imageName("inspector-" + name, scheme: scheme, minimumSize: minimumSize))
        }
        nav.selectedTaskID = nil
        nav.isInspectorPresented = true
        try await settle(view)
        try assertFits(view, in: window)
        try snapshot(view, name: imageName("inspector-empty", scheme: scheme, minimumSize: minimumSize))
        #expect(fixture.todo.title == "核对工作台的公共组件")
        #expect(!fixture.todo.isDone)
        #expect(fixture.routine.title == "阅读 20 分钟")
    }

    @Test func taskAndDiaryUseTheSameBodyFontWithoutMutatingModels() async throws {
        let previous = NavigationSnapshot()
        let previousAppearance = NSApp.appearance
        defer { previous.restore(); NSApp.appearance = previousAppearance }
        let fixture = try makeFixture()
        let window = makeWindow(fixture, scheme: .light)
        defer { release(window) }
        let view = try #require(window.contentView)
        WorkspaceNavigation.shared.revealTab(.today)
        try await settle(view)
        let taskField = try #require(nativeFields(in: view).first { field in
            (field.delegate as? DaybookTextField.Coordinator)?.parent.autocomplete?.context == .capture
        })
        #expect(taskField.font?.pointSize == DaybookType.bodySize)
        WorkspaceNavigation.shared.revealTab(.diary)
        try await settle(view)
        let editor = try #require(noteEditor(in: view))
        #expect(editor.font?.pointSize == DaybookType.bodySize)
        #expect(editor.font == taskField.font)
        let fields = nativeFields(in: view)
        let search = try #require(fields.first { field in
            (field.delegate as? DaybookTextField.Coordinator)?.parent.autocomplete?.context == .tagSearch
        })
        #expect(search.font?.pointSize == DaybookType.subtitleSize)
        #expect(try fixture.container.mainContext.fetchCount(FetchDescriptor<TodoItem>()) == 6)
        #expect(try fixture.container.mainContext.fetchCount(FetchDescriptor<DiaryEntry>()) == 3)
    }

    @Test func diaryComposerKeepsNewlinesAndSavesOnce() async throws {
        let previous = NavigationSnapshot()
        let previousAppearance = NSApp.appearance
        defer { previous.restore(); NSApp.appearance = previousAppearance }
        let fixture = try makeFixture()
        let window = makeWindow(fixture, scheme: .light)
        defer { release(window) }
        let view = try #require(window.contentView)
        WorkspaceNavigation.shared.revealTab(.diary)
        try await settle(view)
        let editor = try #require(noteEditor(in: view))
        try #require(window.makeFirstResponder(editor))
        try await settle(view)
        editor.insertText("工作台第一行", replacementRange: editor.selectedRange())
        try await settle(view)
        let returnEvent = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, characters: "\r", charactersIgnoringModifiers: "\r",
            isARepeat: false, keyCode: 36
        ))
        window.sendEvent(returnEvent)
        try await settle(view)
        editor.insertText("第二行", replacementRange: editor.selectedRange())
        try await settle(view)
        #expect(editor.string == "工作台第一行\n第二行")
        #expect(try fixture.container.mainContext.fetchCount(FetchDescriptor<DiaryEntry>()) == 3)
        let inputFrame = editor.enclosingScrollView?.frame
        try snapshot(view, name: imageName("diary-editing", scheme: .light))
        let saveEvent = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .command, timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, characters: "\r", charactersIgnoringModifiers: "\r",
            isARepeat: false, keyCode: 36
        ))
        try #require(window.performKeyEquivalent(with: saveEvent))
        try await settle(view)
        let notes = try fixture.container.mainContext.fetch(FetchDescriptor<DiaryEntry>())
        #expect(notes.count == 4 && notes.filter { $0.text == "工作台第一行\n第二行" }.count == 1)
        #expect(editor.string.isEmpty && window.firstResponder === editor)
        #expect(editor.enclosingScrollView?.frame == inputFrame)
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func sidebarAndInspectorContentRenderIndependentlyOfSystemMaterials(scheme: ColorScheme) async throws {
        let previous = NavigationSnapshot()
        let previousAppearance = NSApp.appearance
        defer { previous.restore(); NSApp.appearance = previousAppearance }
        let fixture = try makeFixture()
        let nav = WorkspaceNavigation.shared
        nav.revealTab(.today)
        let context = fixture.container.mainContext
        let sidebar = WorkspaceSidebarView(
            navigation: nav, tags: try context.fetch(FetchDescriptor<TagItem>()),
            todos: try context.fetch(FetchDescriptor<TodoItem>())
        )
        let sidebarWindow = makeContentWindow(sidebar, fixture: fixture, scheme: scheme, size: NSSize(width: 220, height: 640))
        defer { release(sidebarWindow) }
        let sidebarView = try #require(sidebarWindow.contentView)
        try await settle(sidebarView)
        try snapshot(sidebarView, name: imageName("sidebar-content", scheme: scheme))
        let drawer = TaskDetailDrawer(taskID: .constant(fixture.todo.id))
        let drawerWindow = makeContentWindow(drawer, fixture: fixture, scheme: scheme, size: NSSize(width: 320, height: 640))
        defer { release(drawerWindow) }
        let drawerView = try #require(drawerWindow.contentView)
        try await settle(drawerView)
        try snapshot(drawerView, name: imageName("inspector-content", scheme: scheme))
    }

    @Test func sixWeekCalendarKeepsItsInputVisibleAtMinimumSize() async throws {
        let previous = NavigationSnapshot()
        let previousAppearance = NSApp.appearance
        defer { previous.restore(); NSApp.appearance = previousAppearance }
        let fixture = try makeFixture()
        let window = makeWindow(fixture, scheme: .light, minimumSize: true)
        defer { release(window) }
        let view = try #require(window.contentView)
        WorkspaceNavigation.shared.revealTab(.calendar)
        WorkspaceNavigation.shared.inspectBoard("2026-08-15")
        try await settle(view)
        let field = try #require(nativeFields(in: view).first)
        let frame = field.convert(field.bounds, to: view)
        #expect(frame.minY >= view.bounds.minY - 1 && frame.maxY <= view.bounds.maxY + 1)
        try snapshot(view, name: "workspace-calendar-six-weeks-light-minimum")
    }

    private struct Fixture {
        let container: ModelContainer
        let preferences: AppPreferences
        let tag: TagItem
        let todo: TodoItem
        let routine: DailyRoutine
    }

    private func makeFixture() throws -> Fixture {
        let container = try ModelContainer(for: Schema(AreaChainSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let preferences = AppPreferences(defaults: try #require(UserDefaults(suiteName: "AreaChain.WorkspaceQA." + UUID().uuidString)))
        let names = ["工作", "生活", DiaryMemoTags.idea, DiaryMemoTags.journal, DiaryMemoTags.password]
        let tags = names.enumerated().map { TagItem(name: $0.element, sortOrder: $0.offset) }
        tags.forEach { context.insert($0) }
        let today = DayClock.shared.todayKey
        let todo = TodoItem(title: "核对工作台的公共组件", dayKey: today, remindMinutes: 10 * 60 + 30, tagIDs: tags[0].id.uuidString)
        todo.notes = "先统一页头与输入区，再检查各页面的文字层级。"
        context.insert(todo)
        addTodos(to: context, today: today, tag: tags[0])
        let routine = DailyRoutine(title: "阅读 20 分钟", sortOrder: 0, createdDayKey: DayKey.shifted(today, by: -1))
        context.insert(routine)
        context.insert(RoutineCheck(dayKey: DayKey.shifted(today, by: -1), isDone: true, routine: routine))
        context.insert(DailyRoutine(title: "晚间散步", sortOrder: 1, createdDayKey: today))
        addNotes(to: context, today: today, tags: tags)
        try context.save()
        Self.retainedContainers.append(container)
        return Fixture(container: container, preferences: preferences, tag: tags[0], todo: todo, routine: routine)
    }

    private func addTodos(to context: ModelContext, today: String, tag: TagItem) {
        context.insert(TodoItem(title: "整理这一周的工作安排", dayKey: today, remindMinutes: 9 * 60, tagIDs: tag.id.uuidString, isImportant: true, isUrgent: true))
        context.insert(TodoItem(title: "回复本周收到的反馈", dayKey: today, isImportant: true))
        context.insert(TodoItem(title: "回顾已经完成的事项", isDone: true, dayKey: today))
        context.insert(TodoItem(title: "补充上周会议纪要", dayKey: DayKey.shifted(today, by: -1)))
        let deleted = TodoItem(title: "回收站中的示例待办", dayKey: today)
        deleted.deletedAt = Date()
        context.insert(deleted)
    }

    private func addNotes(to context: ModelContext, today: String, tags: [TagItem]) {
        let idea = DiaryEntry(text: "关于工作台的一点想法\n任务和灵感放在同一个地方，每一页都应该有熟悉的标题、输入框和筛选栏。", dayKey: today)
        idea.tagIDs = tags[2].id.uuidString
        idea.isPinned = true
        context.insert(idea)
        let journal = DiaryEntry(text: "把事情写下来以后，脑子里安静了很多。", dayKey: today)
        journal.tagIDs = tags[3].id.uuidString
        context.insert(journal)
        let privateNote = DiaryEntry(text: "仅用于验证遮罩的示例内容", dayKey: today)
        privateNote.tagIDs = tags[4].id.uuidString
        context.insert(privateNote)
    }

    private func makeWindow(_ fixture: Fixture, scheme: ColorScheme, minimumSize: Bool = false, localeIdentifier: String = "zh-Hans") -> NSWindow {
        fixture.preferences.language = localeIdentifier == "en" ? .english : .chinese
        let content = MainSplitWorkspaceView()
            .modelContainer(fixture.container)
            .environment(fixture.preferences)
            .environment(\.locale, Locale(identifier: localeIdentifier))
            .transaction { $0.disablesAnimations = true }
            .preferredColorScheme(scheme)
        let window = NSWindow(contentViewController: NSHostingController(rootView: content))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.setContentSize(DaybookMetrics.Window.workspaceSize)
        window.minSize = DaybookMetrics.Window.workspaceMinSize
        if minimumSize { window.setFrame(NSRect(origin: window.frame.origin, size: DaybookMetrics.Window.workspaceMinSize), display: true) }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return window
    }

    private func makeContentWindow<Content: View>(_ content: Content, fixture: Fixture, scheme: ColorScheme, size: NSSize) -> NSWindow {
        let host = NSHostingView(rootView: content
            .modelContainer(fixture.container)
            .environment(fixture.preferences)
            .environment(\.workspaceEmbedded, true)
            .environment(\.locale, Locale(identifier: "zh-Hans"))
            .preferredColorScheme(scheme)
            .transaction { $0.disablesAnimations = true })
        host.safeAreaRegions = []
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentView = host
        window.setContentSize(size)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return window
    }

    private func settle(_ view: NSView) async throws {
        view.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(180))
        view.layoutSubtreeIfNeeded()
    }

    private func assertFits(_ view: NSView, in window: NSWindow) throws {
        let contentSize = window.contentRect(forFrameRect: window.frame).size
        #expect(view.bounds.width <= contentSize.width + 1)
        #expect(view.bounds.height <= window.frame.height + 1)
        #expect(view.bounds.width > 0 && view.bounds.height > 0)
        for field in nativeFields(in: view) where !field.isHiddenOrHasHiddenAncestor && !field.bounds.isEmpty {
            let frame = field.convert(field.bounds, to: view)
            #expect(frame.minX >= -1 && frame.maxX <= view.bounds.maxX + 1, "输入框不应横向越界：\(field.placeholderString ?? "")")
        }
    }

    private func nativeFields(in view: NSView) -> [DaybookAppKitTextField] {
        let current = (view as? DaybookAppKitTextField).map { [$0] } ?? []
        return current + view.subviews.flatMap { nativeFields(in: $0) }
    }

    private func taskComposerFrame(in view: NSView) throws -> CGRect {
        let placeholder = L10n.string("workspace.composer.placeholder", locale: Locale(identifier: "zh-Hans"))
        let field = try #require(nativeFields(in: view).first { $0.placeholderString == placeholder })
        return field.convert(field.bounds, to: view)
    }

    private func noteEditor(in view: NSView) -> NSTextView? {
        if let editor = view as? NSTextView, editor.isEditable, !editor.isFieldEditor { return editor }
        return view.subviews.lazy.compactMap { noteEditor(in: $0) }.first
    }

    private func imageName(_ route: String, scheme: ColorScheme, minimumSize: Bool = false, localeIdentifier: String = "zh-Hans") -> String {
        let language = localeIdentifier == "en" ? "en" : "zh"
        return "workspace-\(route)-\(scheme == .dark ? "dark" : "light")-\(minimumSize ? "minimum" : "default")-\(language)"
    }

    private func snapshot(_ view: NSView, name: String) throws {
        view.window?.displayIfNeeded()
        view.displayIfNeeded()
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AreaChain-Workspace-QA")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try png.write(to: directory.appendingPathComponent(name + ".png"), options: .atomic)
        print("WORKSPACE_QA: \(directory.appendingPathComponent(name + ".png").path)")
    }

    private func release(_ window: NSWindow) {
        window.makeFirstResponder(nil)
        window.orderOut(nil)
        window.toolbar = nil
        // fullSizeContentView 下侧栏分隔条没有完成注册。此时清空 contentViewController，
        // NSSplitView 离开窗口会走到 NSWindowSectionController.unregisterSeparator 并断言停住。
        // 先去掉该样式，分隔条才能按普通标题栏路径注销。
        if window.styleMask.contains(.fullSizeContentView) {
            window.styleMask.remove(.fullSizeContentView)
        }
        window.contentViewController = nil
    }

    @MainActor
    private struct NavigationSnapshot {
        let tab = WorkspaceNavigation.shared.selectedTab
        let tag = WorkspaceNavigation.shared.selectedTagID
        let task = WorkspaceNavigation.shared.selectedTaskID
        let tasks = WorkspaceNavigation.shared.selectedTaskIDs
        let inspector = WorkspaceNavigation.shared.isInspectorPresented
        let day = WorkspaceNavigation.shared.inspectingDayKey

        func restore() {
            let nav = WorkspaceNavigation.shared
            nav.revealTab(tab)
            nav.selectedTagID = tag
            nav.selectedTaskID = task
            nav.selectedTaskIDs = tasks
            nav.isInspectorPresented = inspector
            nav.inspectingDayKey = day
        }
    }
}
