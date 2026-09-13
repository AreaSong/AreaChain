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

    @Test func searchRequestedBeforeMountWinsOverCaptureAutofocus() async throws {
        let container = try fixture()
        let toolbar = MenuBarToolbarState()
        toolbar.focusSearch()
        let window = host(toolbar: toolbar, container: container)
        defer { window.contentView = nil; window.orderOut(nil) }
        let view = try #require(window.contentView)
        let field = try await focusSearch(toolbar, in: view, requestFocus: false)
        #expect(toolbar.searchIsFocused)
        #expect(field.currentEditor() != nil)
    }

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
        _ = try await focusSearch(toolbar, in: view)
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
        try await selectTab(.diary, in: window)
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

    @Test func emptyFooterSearchCannotSubmitTheNoteDraft() async throws {
        let container = try fixture()
        let toolbar = MenuBarToolbarState()
        let window = host(toolbar: toolbar, container: container)
        defer { window.contentView = nil; window.orderOut(nil) }
        let view = try #require(window.contentView)
        try await settle(view)
        try await selectTab(.diary, in: window)
        let editor = try #require(diaryEditor(in: view))
        window.makeFirstResponder(editor)
        editor.insertText("搜索框不能提交这条手记", replacementRange: NSRange(location: 0, length: 0))
        try await settle(view)
        _ = try await focusSearch(toolbar, in: view)
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
            windowNumber: window.windowNumber, context: nil, characters: "\r", charactersIgnoringModifiers: "\r",
            isARepeat: false, keyCode: 36))
        #expect(window.performKeyEquivalent(with: event))
        #expect(diaryEditor(in: view)?.string == "搜索框不能提交这条手记")
        #expect(try container.mainContext.fetchCount(FetchDescriptor<DiaryEntry>()) == 2)
    }

    @Test(arguments: ["zh-Hans", "en"], [ColorScheme.light, .dark])
    func diaryUsesOnlyFooterSearchAndFilters(locale: String, scheme: ColorScheme) async throws {
        let container = try fixture()
        let toolbar = MenuBarToolbarState()
        let window = host(toolbar: toolbar, container: container, locale: locale, scheme: scheme)
        defer { window.contentView = nil; window.orderOut(nil) }
        let view = try #require(window.contentView)
        try await settle(view)
        try await selectTab(.diary, in: window)
        let field = try #require(searchField(in: view))
        let fieldFrame = field.convert(field.bounds, to: view)
        #expect(searchInputCount(in: view) == 1)
        #expect(diaryEditor(in: view) != nil)
        let appearance = scheme == .dark ? "dark" : "light"
        try snapshot(view, name: "menubar-notes-\(locale)-\(appearance)")

        try await clickAndSettle(at: NSPoint(x: 28, y: 27), in: window)
        #expect(toolbar.isFiltering)
        #expect(searchInputCount(in: view) == 0)
        #expect(diaryEditor(in: view) != nil)
        try snapshot(view, name: "menubar-notes-filters-\(locale)-\(appearance)")

        try await clickAndSettle(at: NSPoint(x: view.bounds.width - 26, y: 27), in: window)
        #expect(!toolbar.isFiltering)
        let restoredField = try #require(searchField(in: view))
        #expect(searchInputCount(in: view) == 1)
        #expect(abs(restoredField.convert(restoredField.bounds, to: view).midY - fieldFrame.midY) < 1)
    }

    @Test func diaryFooterFilteringAndSearchingPreserveDraft() async throws {
        let container = try fixture()
        let toolbar = MenuBarToolbarState()
        let window = host(toolbar: toolbar, container: container)
        defer { window.contentView = nil; window.orderOut(nil) }
        let view = try #require(window.contentView)
        try await settle(view)
        try await selectTab(.diary, in: window)
        let composer = try #require(diaryEditor(in: view))
        window.makeFirstResponder(composer)
        composer.insertText("筛选和搜索期间保留的草稿", replacementRange: NSRange(location: 0, length: 0))
        try await settle(view)
        try await selectFilter(at: 94, in: window)
        #expect(!toolbar.isFiltering)
        #expect(diaryEditor(in: view)?.string == "筛选和搜索期间保留的草稿")
        try snapshot(view, name: "menubar-notes-filtered-zh")

        try await selectTab(.tasks, in: window)
        try await selectFilter(at: 188, in: window)
        try await selectTab(.diary, in: window)
        #expect(diaryEditor(in: view)?.string == "筛选和搜索期间保留的草稿")
        try snapshot(view, name: "menubar-notes-filter-after-tabs-zh")

        let field = try await focusSearch(toolbar, in: view)
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.insertText("会议", replacementRange: NSRange(location: 0, length: 0))
        try await settle(view)
        #expect(toolbar.searchText == "会议")
        #expect(diaryEditor(in: view) == nil)
        try snapshot(view, name: "menubar-notes-search-zh")
        toolbar.clearSearch()
        try await settle(view)
        #expect(diaryEditor(in: view)?.string == "筛选和搜索期间保留的草稿")
        try snapshot(view, name: "menubar-notes-filter-after-search-zh")

        try await selectFilter(at: 94, in: window)
        #expect(!toolbar.isFiltering)
        try snapshot(view, name: "menubar-notes-filter-cleared-zh")
        #expect(try container.mainContext.fetchCount(FetchDescriptor<DiaryEntry>()) == 2)
    }

    @Test func workspaceNotesKeepTheirOwnSearchAndFilters() async throws {
        let container = try fixture()
        let window = host(DiaryStandaloneView(), container: container, size: NSSize(width: 760, height: 620))
        defer { window.contentView = nil; window.orderOut(nil) }
        let view = try #require(window.contentView)
        try await settle(view)
        #expect(searchInputCount(in: view) == 1)
        #expect(searchField(in: view) == nil)
        #expect(diaryEditor(in: view) != nil)
        try snapshot(view, name: "workspace-notes-zh")
    }

    @Test func longDraftKeepsFixedInputAndPopoverSizeAndSavesOnlyOnce() async throws {
        let container = try fixture()
        for index in 0..<5 {
            container.mainContext.insert(DiaryEntry(text: "简短手记 \(index + 1)：记录箱里的一个想法", dayKey: DayClock.shared.todayKey))
        }
        try container.mainContext.save()
        let window = host(toolbar: MenuBarToolbarState(), container: container)
        defer { window.contentView = nil; window.orderOut(nil) }
        let view = try #require(window.contentView)
        try await settle(view)
        try await selectTab(.diary, in: window)
        let editor = try #require(diaryEditor(in: view))
        let scroll = try #require(editor.enclosingScrollView)
        let initialSize = view.bounds.size
        let inputHeight = scroll.bounds.height
        #expect(inputHeight <= 48)
        try snapshot(view, name: "menubar-notes-dense-zh")
        window.makeFirstResponder(editor)
        editor.insertText(String(repeating: "固定输入区中的长段内容\n", count: 80), replacementRange: NSRange(location: 0, length: 0))
        try await settle(view)
        #expect(view.bounds.size == initialSize)
        #expect(abs(scroll.bounds.height - inputHeight) < 1)
        #expect(editor.bounds.height > scroll.contentView.bounds.height)
        try snapshot(view, name: "menubar-notes-long-draft-zh")
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
            windowNumber: window.windowNumber, context: nil, characters: "\r", charactersIgnoringModifiers: "\r",
            isARepeat: false, keyCode: 36))
        #expect(window.performKeyEquivalent(with: event))
        try await settle(view)
        #expect(diaryEditor(in: view)?.string == "")
        #expect(window.firstResponder === diaryEditor(in: view))
        #expect(try container.mainContext.fetchCount(FetchDescriptor<DiaryEntry>()) == 8)
        try snapshot(view, name: "menubar-notes-saved-zh")
    }

    @Test func popoutButtonTransfersDraftAndWindowPinIsOperable() async throws {
        let container = try fixture()
        let parent = host(toolbar: MenuBarToolbarState(), container: container)
        defer { parent.contentView = nil; parent.orderOut(nil) }
        let view = try #require(parent.contentView)
        try await settle(view)
        try await selectTab(.diary, in: parent)
        let editor = try #require(diaryEditor(in: view))
        parent.makeFirstResponder(editor)
        editor.insertText("把这条记录放在旁边，边工作边参照。", replacementRange: NSRange(location: 0, length: 0))
        try await settle(view)
        let before = Set(DiaryWindows.shared.hostedWindows.map(ObjectIdentifier.init))
        try await clickAndSettle(at: NativeSyntaxUI.center("syntax.diary.popout", in: parent), in: parent)
        let child = try #require(DiaryWindows.shared.hostedWindows.first { !before.contains(ObjectIdentifier($0)) })
        defer { child.close() }
        let controller = try #require(child.delegate as? DiaryWindowController)
        let childView = try #require(child.contentView)
        try await settle(childView)
        #expect(controller.session.text == "把这条记录放在旁边，边工作边参照。")
        #expect(diaryEditor(in: view)?.string == "")
        #expect(try container.mainContext.fetchCount(FetchDescriptor<DiaryEntry>()) == 2)
        try await clickAndSettle(at: NSPoint(x: childView.bounds.width - 60, y: childView.bounds.height - 28), in: child)
        #expect(child.level == .floating && controller.session.isWindowPinned)
        #expect(controller.session.save())
        #expect(controller.session.record?.isPinned == false)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<DiaryEntry>()) == 3)
        try snapshot(childView, name: "note-window-pinned-zh")
    }

    @Test(arguments: ["zh-Hans", "en"], [ColorScheme.light, .dark])
    func noteWindowRendersLongTextAndMasksPrivateEditor(locale: String, scheme: ColorScheme) async throws {
        let container = try fixture()
        let entry = DiaryEntry(text: "手记窗口 / Note window\n\n" + String(repeating: "一段需要完整阅读的记录。A longer note for focused reading.\n", count: 30),
                               dayKey: DayClock.shared.todayKey)
        container.mainContext.insert(entry)
        try container.mainContext.save()
        let session = DiaryEditorSession(source: .entry(entry), context: container.mainContext)
        let root = DiaryWindowView(session: session, onPin: { session.isWindowPinned.toggle() })
        let window = host(root, container: container, locale: locale, scheme: scheme, size: NSSize(width: 480, height: 440))
        defer { window.contentView = nil; window.orderOut(nil) }
        let view = try #require(window.contentView)
        try await settle(view)
        #expect(diaryEditor(in: view)?.string == entry.text)
        try snapshot(view, name: "note-window-\(locale)-\(scheme == .dark ? "dark" : "light")")
        window.setContentSize(NSSize(width: 360, height: 300))
        try await settle(view)
        try snapshot(view, name: "note-window-small-\(locale)-\(scheme == .dark ? "dark" : "light")")
        try SwiftDataDiaryRepository(context: container.mainContext).editDiary(id: entry.id, text: "#密码 QA_PRIVATE_WINDOW_SENTINEL")
        session.refresh()
        try await settle(view)
        #expect(diaryEditor(in: view) == nil)
        #expect(!session.canRevealContent)
        try snapshot(view, name: "note-window-masked-\(locale)-\(scheme == .dark ? "dark" : "light")")
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
        let field = try await focusSearch(toolbar, in: view)
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.insertText("#工", replacementRange: NSRange(location: 0, length: 0))
        try await settle(view)
        #expect(toolbar.searchText == "#工")
        #expect(searchField(in: view) === field, "切换结果区不应重建底部输入框")
        #expect(toolbar.autocomplete.isActive)
        #expect(toolbar.searchIsFocused, "key=\(window.isKeyWindow), active=\(NSApp.isActive), editing=\(field.currentEditor() != nil)")
        try snapshot(view, name: "menubar-search-completion-zh")
        let fieldFrame = field.convert(field.bounds, to: nil)
        let candidatePoint = try NativeSyntaxUI.center("syntax.candidate.tag_工作", in: window)
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
        host(MenuBarPopoverView(toolbar: toolbar, diaryCapture: DiaryCaptureSession()), container: container, locale: locale, scheme: scheme)
    }

    private func host<Content: View>(
        _ root: Content, container: ModelContainer,
        locale: String = "zh-Hans", scheme: ColorScheme = .light,
        size: NSSize = DaybookTheme.popoverSize
    ) -> NSWindow {
        let content = root
            .modelContainer(container)
            .environment(AppPreferences.shared)
            .environment(\.locale, Locale(identifier: locale))
            .transaction { $0.disablesAnimations = true }
            .preferredColorScheme(scheme)
        let hosting = NSHostingView(rootView: content)
        hosting.safeAreaRegions = []
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentView = hosting
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

    private func searchField(in view: NSView) -> NSTextField? {
        if let field = view as? DaybookAppKitTextField,
           let coordinator = field.delegate as? DaybookTextField.Coordinator,
           coordinator.parent.autocomplete?.context == .search { return field }
        return view.subviews.lazy.compactMap { searchField(in: $0) }.first
    }

    private func searchInputCount(in view: NSView) -> Int {
        let coordinator = (view as? DaybookAppKitTextField)?.delegate as? DaybookTextField.Coordinator
        // 页签过渡中可能暂留旧捕获框；只统计具备搜索语义的原生输入框。
        let current = coordinator?.parent.autocomplete?.context.isSearch == true ? 1 : 0
        return current + view.subviews.reduce(0) { $0 + searchInputCount(in: $1) }
    }

    private func clickAndSettle(at point: NSPoint, in window: NSWindow) async throws {
        try click(at: point, in: window)
        try await settle(#require(window.contentView))
    }

    private func selectTab(_ tab: BoardTab, in window: NSWindow) async throws {
        let view = try #require(window.contentView)
        // 单测宿主没有 SwiftUI 虚拟无障碍树；沿用固定尺寸浮层的真实鼠标事件。
        let point = NSPoint(x: view.bounds.width - (tab == .diary ? 48 : 108), y: view.bounds.height - 29)
        try await clickAndSettle(at: point, in: window)
        // 让旧页的退出动画完成后再抓图，避免把过渡帧当成稳定布局。
        try await Task.sleep(for: .milliseconds(350))
        view.layoutSubtreeIfNeeded()
    }

    private func selectFilter(at x: CGFloat, in window: NSWindow) async throws {
        try await clickAndSettle(at: NSPoint(x: 28, y: 27), in: window)
        try await clickAndSettle(at: NSPoint(x: x, y: 27), in: window)
    }

    private func focusSearch(
        _ toolbar: MenuBarToolbarState, in view: NSView, requestFocus: Bool = true
    ) async throws -> NSTextField {
        if requestFocus { toolbar.focusSearch() }
        // SwiftUI 到 AppKit 的焦点交接是异步的；等待状态，不依赖固定帧耗时。
        for _ in 0..<20 {
            view.layoutSubtreeIfNeeded()
            if let field = searchField(in: view), field.currentEditor() != nil { return field }
            try await Task.sleep(for: .milliseconds(50))
        }
        let field = try #require(searchField(in: view))
        let activeField = (field.window?.firstResponder as? NSTextView)?.delegate as? NSTextField
        try #require(field.currentEditor() != nil,
                     "搜索请求=\(toolbar.searchIsFocused)，当前输入=\(activeField?.placeholderString ?? "none")")
        return field
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
