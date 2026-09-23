import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct MenuBarPopoverRenderingTests {
    // SwiftUI 的查询/销毁回调可能晚于测试方法返回；与真实应用一样，让容器覆盖整个宿主生命周期。
    static var retainedContainers: [ModelContainer] = []

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
        let composer = BoardComposerSession()
        composer.tasks.text = "这条草稿不应被搜索快捷键提交"
        let container = try fixture()
        let toolbar = MenuBarToolbarState()
        let window = host(toolbar: toolbar, container: container, composer: composer)
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
        #expect(composer.tasks.text == "这条草稿不应被搜索快捷键提交")
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

        try await clickAndSettle(at: try filterTriggerPoint(in: window), in: window)
        #expect(toolbar.isFiltering)
        #expect(searchInputCount(in: view) == 1)
        #expect(diaryEditor(in: view) != nil)
        try snapshot(view, name: "menubar-notes-filters-\(locale)-\(appearance)")

        try await clickAndSettle(at: try filterTriggerPoint(in: window), in: window)
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
        let field = try #require(diaryField(in: view))
        let editor = try #require(diaryEditor(in: view))
        let initialSize = view.bounds.size
        let inputHeight = field.bounds.height
        #expect(inputHeight <= 36)
        try snapshot(view, name: "menubar-notes-dense-zh")
        window.makeFirstResponder(editor)
        editor.insertText(String(repeating: "固定输入区中的长段内容\n", count: 80), replacementRange: NSRange(location: 0, length: 0))
        try await settle(view)
        #expect(view.bounds.size == initialSize)
        #expect(abs(field.bounds.height - inputHeight) < 1)
        try snapshot(view, name: "menubar-notes-long-draft-zh")
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
            windowNumber: window.windowNumber, context: nil, characters: "\r", charactersIgnoringModifiers: "\r",
            isARepeat: false, keyCode: 36))
        #expect(window.performKeyEquivalent(with: event))
        try await settle(view)
        #expect(diaryEditor(in: view)?.string == "" || field.stringValue == "")
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
        try click(at: try filterTriggerPoint(in: window), in: window)
        try await settle(view)
        #expect(toolbar.isFiltering)
        #expect(searchField(in: view) != nil)
        #expect(toolbar.searchText == "会议 #工作")
        try snapshot(view, name: "menubar-filters-zh")

        try click(at: try filterTriggerPoint(in: window), in: window)
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

    @Test func commandArrowTabChangesDoNotRepublishUnchangedPresetTags() async throws {
        let container = try fixture()
        try SwiftDataCatalogRepository(container: container).ensurePresetTags()
        let window = host(toolbar: MenuBarToolbarState(), container: container)
        defer { window.contentView = nil; window.orderOut(nil) }
        let view = try #require(window.contentView)
        try await settle(view)
        var notifications = 0
        let observer = NotificationCenter.default.addObserver(forName: .boardDidChange, object: nil, queue: .main) { _ in notifications += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }

        let keyCodes: [UInt16] = [124, 124, 123, 123, 124, 123]
        for (index, keyCode) in keyCodes.enumerated() {
            let characters = keyCode == 124 ? "\u{F703}" : "\u{F702}"
            let event = try #require(NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [.command, .numericPad, .function],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
                characters: characters, charactersIgnoringModifiers: characters,
                isARepeat: index > 0 && keyCodes[index - 1] == keyCode, keyCode: keyCode
            ))
            NSApp.postEvent(event, atStart: false)
            try await Task.sleep(for: .milliseconds(350))
            try await settle(view)
            #expect((diaryEditor(in: view) != nil) == (keyCode == 124))
        }
        #expect(notifications == 0)
    }

    @Test func filterChipsRemainExpandedUntilExplicitlyClosed() async throws {
        let container = try fixture()
        let toolbar = MenuBarToolbarState()
        let window = host(toolbar: toolbar, container: container)
        defer { window.contentView = nil; window.orderOut(nil) }
        let view = try #require(window.contentView)
        try await settle(view)

        // 展开筛选
        try await clickAndSettle(at: try filterTriggerPoint(in: window), in: window)
        #expect(toolbar.isFiltering)

        // 再次点击筛选按钮收起
        try await clickAndSettle(at: try filterTriggerPoint(in: window), in: window)
        #expect(!toolbar.isFiltering)
    }
}
