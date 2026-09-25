import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

extension MenuBarPopoverRenderingTests {
    func fixture() throws -> ModelContainer {
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

    func host(
        toolbar: MenuBarToolbarState, container: ModelContainer,
        composer: BoardComposerSession? = nil,
        locale: String = "zh-Hans", scheme: ColorScheme = .light
    ) -> NSWindow {
        host(
            MenuBarPopoverView(
                toolbar: toolbar,
                composer: composer ?? BoardComposerSession(),
                filterSession: BoardFilterSession()
            ),
            container: container, locale: locale, scheme: scheme
        )
    }

    func host<Content: View>(
        _ root: Content, container: ModelContainer,
        locale: String = "zh-Hans", scheme: ColorScheme = .light,
        size: NSSize = DaybookMetrics.Window.popoverSize
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

    func settle(_ view: NSView) async throws {
        view.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(180))
        view.layoutSubtreeIfNeeded()
    }

    func searchField(in view: NSView) -> NSTextField? {
        if let field = view as? DaybookAppKitTextField,
           let coordinator = field.delegate as? DaybookTextField.Coordinator,
           coordinator.parent.autocomplete?.context == .search { return field }
        return view.subviews.lazy.compactMap { searchField(in: $0) }.first
    }

    func searchInputCount(in view: NSView) -> Int {
        let coordinator = (view as? DaybookAppKitTextField)?.delegate as? DaybookTextField.Coordinator
        let current = coordinator?.parent.autocomplete?.context.isSearch == true ? 1 : 0
        return current + view.subviews.reduce(0) { $0 + searchInputCount(in: $1) }
    }

    func clickAndSettle(at point: NSPoint, in window: NSWindow) async throws {
        try click(at: point, in: window)
        try await settle(#require(window.contentView))
    }

    func selectTab(_ tab: BoardTab, in window: NSWindow) async throws {
        let view = try #require(window.contentView)
        let point = NSPoint(x: view.bounds.width - (tab == .diary ? 48 : 108), y: view.bounds.height - 29)
        try await clickAndSettle(at: point, in: window)
        try await Task.sleep(for: .milliseconds(350))
        view.layoutSubtreeIfNeeded()
    }

    func filterTriggerPoint(in window: NSWindow) throws -> NSPoint {
        try NativeSyntaxUI.center("menubar.filter.open", in: window)
    }

    func selectFilter(at x: CGFloat, in window: NSWindow, closeAfter: Bool = true) async throws {
        try await clickAndSettle(at: try filterTriggerPoint(in: window), in: window)
        if closeAfter {
            try await clickAndSettle(at: try filterTriggerPoint(in: window), in: window)
        }
    }

    func focusSearch(
        _ toolbar: MenuBarToolbarState, in view: NSView, requestFocus: Bool = true
    ) async throws -> NSTextField {
        if requestFocus { toolbar.focusSearch() }
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

    func diaryField(in view: NSView) -> DaybookAppKitTextField? {
        if let field = view as? DaybookAppKitTextField,
           let coordinator = field.delegate as? DaybookTextField.Coordinator,
           coordinator.parent.autocomplete == nil || coordinator.parent.autocomplete?.context == .diaryCapture {
            return field
        }
        return view.subviews.lazy.compactMap { diaryField(in: $0) }.first
    }

    func diaryEditor(in view: NSView) -> NSTextView? {
        if let editor = view as? NSTextView, editor.isEditable, !editor.isFieldEditor { return editor }
        if let field = diaryField(in: view) {
            if let editor = field.currentEditor() as? NSTextView {
                return editor
            }
            if let window = field.window {
                window.makeFirstResponder(field)
                if let editor = field.currentEditor() as? NSTextView {
                    return editor
                }
            }
        }
        return view.subviews.lazy.compactMap { diaryEditor(in: $0) }.first
    }

    func click(at point: NSPoint, in window: NSWindow) throws {
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
            ))
            window.sendEvent(event)
        }
    }

    func snapshot(_ view: NSView, name: String) throws {
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AreaChain-UI-QA")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try png.write(to: directory.appendingPathComponent(name + ".png"), options: .atomic)
    }
}
