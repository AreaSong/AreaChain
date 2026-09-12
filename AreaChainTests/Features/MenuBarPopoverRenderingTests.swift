import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct MenuBarPopoverRenderingTests {
    // SwiftUI 的查询/销毁回调可能晚于测试方法返回；与真实应用一样，让容器覆盖整个宿主生命周期。
    private static var retainedContainers: [ModelContainer] = []

    @Test func emptySearchDoesNotSubmitTheCaptureDraftOnCommandReturn() async throws {
        let previousDraft = CaptureSession.shared.draft
        CaptureSession.shared.draft = "这条草稿不应被搜索快捷键提交"
        defer { CaptureSession.shared.draft = previousDraft }
        let container = try fixture()
        let toolbar = MenuBarToolbarState()
        let window = host(toolbar: toolbar, container: container)
        defer { window.contentView = nil; window.orderOut(nil) }
        let view = try #require(window.contentView)
        try await settle(view)
        toolbar.focusSearch()
        try await settle(view)
        #expect(searchField(in: view)?.currentEditor() != nil)
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
            windowNumber: window.windowNumber, context: nil, characters: "\r", charactersIgnoringModifiers: "\r",
            isARepeat: false, keyCode: 36
        ))
        #expect(window.performKeyEquivalent(with: event))
        #expect(CaptureSession.shared.draft == "这条草稿不应被搜索快捷键提交")
        #expect(try container.mainContext.fetchCount(FetchDescriptor<TodoItem>()) == 4)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<DiaryEntry>()) == 2)
    }

    @Test func diaryComposerDraftSurvivesSearchingAndReturning() async throws {
        let container = try fixture()
        let toolbar = MenuBarToolbarState()
        let window = host(toolbar: toolbar, container: container)
        defer { window.contentView = nil; window.orderOut(nil) }
        let view = try #require(window.contentView)
        try await settle(view)
        try click(at: NSPoint(x: 332, y: 459), in: window)
        try await settle(view)
        let editor = try #require(diaryEditor(in: view))
        window.makeFirstResponder(editor)
        editor.insertText("查资料前留下的手记草稿", replacementRange: NSRange(location: 0, length: 0))
        try await settle(view)
        toolbar.focusSearch()
        toolbar.searchText = "会议"
        try await settle(view)
        #expect(diaryEditor(in: view) == nil)
        toolbar.clearSearch()
        try await settle(view)
        #expect(diaryEditor(in: view)?.string == "查资料前留下的手记草稿")
    }

    @Test func nativeToolbarReplacementPreservesSearchAndRendersBothAppearances() async throws {
        let container = try fixture()
        let toolbar = MenuBarToolbarState()
        let window = host(toolbar: toolbar, container: container)
        defer { window.contentView = nil; window.orderOut(nil) }
        let view = try #require(window.contentView)
        try await settle(view)
        let initialField = try #require(searchField(in: view))
        let initialFrame = initialField.convert(initialField.bounds, to: view)
        #expect(initialFrame.width > 100)
        try snapshot(view, name: "menubar-normal-zh")

        toolbar.searchText = "会议 #工作"
        try await settle(view)
        try snapshot(view, name: "menubar-search-zh")
        try click(at: NSPoint(x: 28, y: 27), in: window)
        try await settle(view)
        #expect(toolbar.isFiltering)
        #expect(searchField(in: view) == nil)
        #expect(toolbar.searchText == "会议 #工作")
        try snapshot(view, name: "menubar-filters-zh")

        try click(at: NSPoint(x: view.bounds.width - 26, y: 27), in: window)
        try await settle(view)
        #expect(!toolbar.isFiltering)
        let restoredField = try #require(searchField(in: view))
        #expect(restoredField.stringValue == "会议 #工作")
        #expect(abs(restoredField.convert(restoredField.bounds, to: view).midY - initialFrame.midY) < 1)
        toolbar.clearSearch()
        try await settle(view)
        #expect(searchField(in: view)?.stringValue == "")
        #expect(try container.mainContext.fetchCount(FetchDescriptor<TodoItem>()) == 4)

        let dark = host(toolbar: MenuBarToolbarState(), container: container, locale: "en", scheme: .dark)
        defer { dark.contentView = nil; dark.orderOut(nil) }
        let darkView = try #require(dark.contentView)
        try await settle(darkView)
        try snapshot(darkView, name: "menubar-normal-en-dark")
    }

    @Test func clickingAnUpwardSyntaxCandidateCompletesTheFocusedSearchOnly() async throws {
        let container = try fixture()
        let toolbar = MenuBarToolbarState()
        let window = host(toolbar: toolbar, container: container)
        defer { window.contentView = nil; window.orderOut(nil) }
        let view = try #require(window.contentView)
        try await settle(view)
        toolbar.focusSearch()
        try await settle(view)
        let field = try #require(searchField(in: view))
        #expect(field.currentEditor() != nil, "聚焦搜索应进入原生编辑器")
        window.makeFirstResponder(field)
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.insertText("#工", replacementRange: NSRange(location: 0, length: 0))
        try await settle(view)
        #expect(toolbar.searchText == "#工")
        #expect(searchField(in: view) === field, "切换结果区不应重建底部输入框")
        #expect(toolbar.autocomplete.isActive)
        #expect(toolbar.searchIsFocused, "key=\(window.isKeyWindow), active=\(NSApp.isActive), editing=\(field.currentEditor() != nil)")
        try snapshot(view, name: "menubar-search-completion-zh")
        let fieldFrame = field.convert(field.bounds, to: nil)
        // 固定浮层布局中上方第二个候选的行中心；发送真实鼠标事件，不直接调用补全回调。
        let candidatePoint = NSPoint(x: fieldFrame.minX + 30, y: fieldFrame.midY + 64)
        #expect(candidatePoint.y > fieldFrame.maxY)
        try click(at: candidatePoint, in: window)
        try await settle(view)
        #expect(toolbar.searchText == "#工作 ")
        #expect(searchField(in: view)?.stringValue == "#工作 ")
        #expect(searchField(in: view)?.currentEditor() != nil)
        #expect(!toolbar.autocomplete.isActive)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<TagItem>()) == 5)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<TodoItem>()) == 4)
    }

    private func fixture() throws -> ModelContainer {
        let container = try ModelContainer(for: Schema(AreaChainSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let tags = ["工作", "生活", "学习", "设计方案与长期规划", "密码"].enumerated().map { TagItem(name: $0.element, sortOrder: $0.offset) }
        tags.forEach { context.insert($0) }
        let today = DayClock.shared.todayKey
        context.insert(TodoItem(title: "整理会议纪要", dayKey: today, remindMinutes: 15 * 60, tagIDs: tags[0].id.uuidString, isImportant: true, isUrgent: true))
        context.insert(TodoItem(title: "准备项目评审", dayKey: today, tagIDs: tags[0].id.uuidString, isImportant: true))
        context.insert(TodoItem(title: "归档上周会议资料", isDone: true, dayKey: DayKey.shifted(today, by: -7), tagIDs: tags[0].id.uuidString))
        context.insert(TodoItem(title: "确认下周排期", isDone: true, dayKey: today))
        for (index, title) in ["阅读 20 分钟", "晚间复盘"].enumerated() {
            let routine = DailyRoutine(title: title, sortOrder: index, createdDayKey: DayKey.shifted(today, by: -1))
            context.insert(routine)
            context.insert(RoutineCheck(dayKey: DayKey.shifted(today, by: -1), isDone: true, routine: routine))
        }
        let note = DiaryEntry(text: "会议之后想到的新点子", dayKey: today)
        note.tagIDs = tags[0].id.uuidString
        context.insert(note)
        let privateNote = DiaryEntry(text: "QA_PRIVATE_SENTINEL", dayKey: today)
        privateNote.tagIDs = tags[4].id.uuidString
        context.insert(privateNote)
        try context.save()
        Self.retainedContainers.append(container)
        return container
    }

    private func host(
        toolbar: MenuBarToolbarState, container: ModelContainer,
        locale: String = "zh-Hans", scheme: ColorScheme = .light
    ) -> NSWindow {
        let content = MenuBarPopoverView(toolbar: toolbar)
            .modelContainer(container)
            .environment(AppPreferences.shared)
            .environment(\.locale, Locale(identifier: locale))
            .transaction { $0.disablesAnimations = true }
            .preferredColorScheme(scheme)
        let hosting = NSHostingView(rootView: content)
        hosting.safeAreaRegions = []
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: DaybookTheme.popoverSize), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentView = hosting
        window.setContentSize(DaybookTheme.popoverSize)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return window
    }

    private func settle(_ view: NSView) async throws {
        view.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(180))
        view.layoutSubtreeIfNeeded()
    }

    private func searchField(in view: NSView) -> NSTextField? {
        if let field = view as? DaybookAppKitTextField,
           field.placeholderString?.contains("#") == true { return field }
        return view.subviews.lazy.compactMap { searchField(in: $0) }.first
    }

    private func diaryEditor(in view: NSView) -> NSTextView? {
        if let editor = view as? NSTextView, editor.isEditable, !editor.isFieldEditor { return editor }
        return view.subviews.lazy.compactMap { diaryEditor(in: $0) }.first
    }

    private func click(at point: NSPoint, in window: NSWindow) throws {
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
            ))
            window.sendEvent(event)
        }
    }

    private func snapshot(_ view: NSView, name: String) throws {
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AreaChain-UI-QA")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try png.write(to: directory.appendingPathComponent(name + ".png"), options: .atomic)
    }
}
