import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct WorkspaceHeaderInteractionTests {
    @Test func failedNotesBlurThenUnmountMakesOnlyOneSaveAttempt() async throws {
        let host = try HeaderTestHost()
        let key = "todo-" + UUID().uuidString
        defer { host.close(); EditDrafts.shared.notes.removeValue(forKey: key) }
        var attempts = 0
        host.show(TaskDetailNotesView(draftKey: key, notes: "Original") { _ in attempts += 1; return false })
        try await host.prepare()
        let editor = try #require(ScrollNativeEvidence.views(host.window)
            .compactMap { $0 as? NSTextView }.first { $0.isEditable && !$0.isFieldEditor })
        try #require(host.window.makeFirstResponder(editor))
        editor.setSelectedRange(NSRange(location: 0, length: editor.string.utf16.count))
        editor.insertText("Synthetic unsaved notes", replacementRange: editor.selectedRange())
        try await host.settle()
        host.window.makeFirstResponder(nil)
        try await host.settle()
        #expect(attempts == 1)
        host.show(Text("Collapsed"))
        try await host.settle()
        #expect(attempts == 1)
        #expect(EditDrafts.shared.notes[key] == "Synthetic unsaved notes")
        host.show(TaskDetailNotesView(draftKey: key, notes: "Original") { _ in attempts += 1; return true })
        try await host.settle()
        let restored = try #require(ScrollNativeEvidence.views(host.window)
            .compactMap { $0 as? NSTextView }.first { $0.isEditable && !$0.isFieldEditor })
        #expect(restored.string == "Synthetic unsaved notes" && attempts == 1)
    }

    @Test func tagCreationExpandsSubmitsRejectsDuplicatesAndCancels() async throws {
        let host = try HeaderTestHost()
        defer { host.close() }
        WorkspaceNavigation.shared.revealTab(.tags)
        host.show(TagManagementPage())
        try await host.prepare()
        #expect(host.createField == nil)
        try await host.click("workspace.header.action.tags.create")
        let editor = try host.focusCreate()
        editor.insertText("顶栏标签", replacementRange: editor.selectedRange())
        try await host.settle()
        try host.key("\r", code: 36)
        try await host.settle()
        #expect(host.createField == nil)
        #expect(host.tags.filter { $0.name == "顶栏标签" }.count == 1)

        try await host.click("workspace.header.action.tags.create")
        let duplicate = try host.focusCreate()
        duplicate.insertText("顶栏标签", replacementRange: duplicate.selectedRange())
        try await host.settle()
        try host.key("\r", code: 36)
        try await host.settle()
        #expect(host.createField?.stringValue == "顶栏标签")
        #expect(host.tags.filter { $0.name == "顶栏标签" }.count == 1)
        try host.key("\u{1b}", code: 53)
        try await host.settle()
        #expect(host.createField == nil)
        try await host.click("workspace.header.action.tags.create")
        #expect(host.createField?.stringValue == "")
    }

    @Test func failedTagCreationRetainsDraftAndMarkedTextDoesNotSubmitOrCancel() async throws {
        let host = try HeaderTestHost()
        defer { host.close() }
        var saves = 0
        WorkspaceNavigation.shared.revealTab(.tags)
        host.show(TagManagementPage(saveTag: { _, _ in saves += 1; return nil }))
        try await host.prepare()
        try await host.click("workspace.header.action.tags.create")
        let editor = try host.focusCreate()
        editor.insertText("保存失败草稿", replacementRange: editor.selectedRange())
        try await host.settle()
        try host.key("\r", code: 36)
        try await host.settle()
        #expect(saves == 1 && host.createField?.stringValue == "保存失败草稿")
        #expect(host.tags.isEmpty)
        editor.setMarkedText("拼", selectedRange: NSRange(location: 1, length: 0), replacementRange: editor.selectedRange())
        let field = try #require(host.createField)
        let delegate = try #require(field.delegate as? DaybookTextField.Coordinator)
        #expect(!delegate.control(field, textView: editor, doCommandBy: #selector(NSResponder.insertNewline(_:))))
        #expect(!delegate.control(field, textView: editor, doCommandBy: #selector(NSResponder.cancelOperation(_:))))
        #expect(saves == 1 && host.createField != nil)
        editor.unmarkText()
        try host.key("\u{1b}", code: 53)
        try await host.settle()
        #expect(host.createField == nil)
    }

    @Test func globalShortcutWinsOverDiaryLocalSearchAndClearingRestoresSource() async throws {
        let host = try HeaderTestHost()
        defer { host.close() }
        let navigation = WorkspaceNavigation.shared
        navigation.revealTab(.diary)
        host.show(DiaryPage(todayKey: DayKey.today(), entries: []))
        try await host.prepare()
        let local = try #require(host.fields.first { $0.placeholderString == L10n.string("diary.search.placeholder", locale: host.locale) })
        host.window.makeFirstResponder(local)
        try host.key("f", code: 3, modifiers: .command)
        try await host.settle()
        let global = try #require(host.fields.first { $0.placeholderString == L10n.string("workspace.search.placeholder", locale: host.locale) })
        #expect(host.window.firstResponder === global.currentEditor())
        let editor = try #require(global.currentEditor() as? NSTextView)
        editor.insertText("#未知标签", replacementRange: editor.selectedRange())
        try await host.settle()
        #expect(navigation.isSearching)
        #expect(!host.tags.contains { $0.name == "未知标签" })
        navigation.clearSearch()
        #expect(navigation.selectedTab == .diary)
    }

    @Test func titleDraftSurvivesFailedSaveAndUnmountWithoutExtraSubmission() async throws {
        let host = try HeaderTestHost()
        let key = "todo-" + UUID().uuidString
        defer { host.close(); EditDrafts.shared.titles.removeValue(forKey: key) }
        EditDrafts.shared.titles[key] = "未保存标题"
        var submissions = 0
        host.show(TaskDetailTitleEditor(draftKey: key, title: "原题") { _ in submissions += 1; return false })
        try await host.prepare()
        let field = try #require(host.fields.first { $0.placeholderString == L10n.string("drawer.title.placeholder", locale: host.locale) })
        host.window.makeFirstResponder(field)
        try host.key("\r", code: 36)
        try await host.settle()
        #expect(submissions == 1)
        #expect(EditDrafts.shared.titles[key] == "未保存标题")
        host.show(Text("其他页面"))
        try await host.settle()
        #expect(EditDrafts.shared.titles[key] == "未保存标题")
        let afterClose = submissions
        host.show(TaskDetailTitleEditor(draftKey: key, title: "原题") { _ in submissions += 1; return false })
        try await host.settle()
        let restored = try #require(host.fields.first { $0.placeholderString == L10n.string("drawer.title.placeholder", locale: host.locale) })
        #expect(restored.stringValue == "未保存标题" && submissions == afterClose)
        host.window.makeFirstResponder(restored)
        try host.key("\u{1b}", code: 53)
        try await host.settle()
        #expect(EditDrafts.shared.titles[key] == nil)
    }
}

@MainActor
private final class HeaderTestHost {
    private static var retained: [ModelContainer] = []
    let container: ModelContainer
    let window: NSWindow
    let locale = Locale(identifier: "zh-Hans")
    private let previousAccessibility = NSApp.accessibilityAttributeValue(NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
    private let oldTab = WorkspaceNavigation.shared.selectedTab

    init() throws {
        container = try ModelContainer(for: Schema(AreaChainSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        Self.retained.append(container)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 600), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        NSApp.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
        WorkspaceNavigation.shared.clearSearch()
    }

    func show<V: View>(_ page: V) {
        let root = page.padding(.top, 50)
            .overlayPreferenceValue(WorkspaceHeaderContentKey.self, alignment: .top) { content in
                WorkspaceHeaderBar(navigation: WorkspaceNavigation.shared, tags: [], content: content).frame(height: 50)
            }
            .modelContainer(container)
            .environment(AppPreferences.shared)
            .environment(\.locale, locale)
            .environment(\.workspaceEmbedded, true)
            .transaction { $0.disablesAnimations = true }
            .syntaxOverlayHost()
        window.contentView = NSHostingView(rootView: root)
        window.setContentSize(NSSize(width: 980, height: 600))
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    var fields: [DaybookAppKitTextField] { descendants(window.contentView).compactMap { $0 as? DaybookAppKitTextField } }
    var createField: DaybookAppKitTextField? { fields.first { $0.placeholderString == L10n.string("tags.create.name", locale: locale) } }
    var tags: [TagItem] { (try? container.mainContext.fetch(FetchDescriptor<TagItem>())) ?? [] }

    func prepare() async throws { try await NativeSyntaxUI.prepareFocus(in: window); try await settle() }
    func settle() async throws {
        window.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(180))
        window.contentView?.layoutSubtreeIfNeeded()
    }

    func focusCreate() throws -> NSTextView {
        let field = try #require(createField)
        #expect(window.firstResponder === field.currentEditor(), "新建标签展开后应主动聚焦")
        return try #require(field.currentEditor() as? NSTextView)
    }

    func click(_ identifier: String) async throws {
        let point = try NativeSyntaxUI.center(identifier, in: window)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            window.sendEvent(try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)))
        }
        try await settle()
    }

    func key(_ text: String, code: UInt16, modifiers: NSEvent.ModifierFlags = []) throws {
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: code))
        if modifiers.contains(.command) { #expect(window.performKeyEquivalent(with: event)) }
        else { window.sendEvent(event) }
    }

    func close() {
        window.makeFirstResponder(nil)
        window.contentView = nil
        window.orderOut(nil)
        WorkspaceNavigation.shared.clearSearch()
        WorkspaceNavigation.shared.revealTab(oldTab)
        NSApp.accessibilitySetValue(previousAccessibility ?? false, forAttribute: NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
    }

    private func descendants(_ view: NSView?) -> [NSView] {
        guard let view else { return [] }
        return [view] + view.subviews.flatMap { descendants($0) }
    }
}
