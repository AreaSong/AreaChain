import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DiaryComposerInteractionTests {
    @Test func returnInsertsNewlineAndCommandReturnSavesOnceKeepingFocus() async throws {
        let host = try DiaryComposerHost()
        defer { host.close() }
        let editor = try await host.focus()
        try await host.enter("第一行")
        let initialFrame = try NativeSyntaxUI.frame("syntax.diary.composer", in: host.window)
        try await host.pressReturn()
        #expect(host.draft.text == "第一行\n")
        #expect(host.draft.submissions == 0)
        try await host.enter("第二行")
        try await host.pressReturn(modifiers: .command)
        #expect(host.draft.lastSaved == "第一行\n第二行")
        #expect(host.draft.submissions == 1 && host.draft.text.isEmpty)
        #expect(host.window.firstResponder === editor)
        #expect(try NativeSyntaxUI.frame("syntax.diary.composer", in: host.window) == initialFrame)
    }

    @Test func emptyOrWhitespaceCannotBeSavedByButtonOrShortcut() async throws {
        let host = try DiaryComposerHost()
        defer { host.close() }
        _ = try await host.focus()
        try await host.click("syntax.commandReturn.button")
        try await host.pressReturn(modifiers: .command)
        try await host.enter(" \n\t ")
        try await host.click("syntax.commandReturn.button")
        try await host.pressReturn(modifiers: .command)
        #expect(host.draft.submissions == 0)
        #expect(host.draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test func clickingTheInlineShortcutAndPopoutUseSeparateActions() async throws {
        let host = try DiaryComposerHost()
        defer { host.close() }
        _ = try await host.focus()
        try await host.enter("点击保存的手记")
        try await host.click("syntax.commandReturn.button")
        #expect(host.draft.submissions == 1 && host.draft.lastSaved == "点击保存的手记")
        try await host.enter("转到小窗的手记")
        try await host.click("syntax.diary.popout")
        #expect(host.draft.popouts == 1 && host.draft.transferred == "转到小窗的手记")
        #expect(host.draft.submissions == 1)
    }

    @Test func chineseCompositionAndTagCompletionTakePriorityOverSubmission() async throws {
        let host = try DiaryComposerHost()
        defer { host.close() }
        let editor = try await host.focus()
        editor.setMarkedText("中文", selectedRange: NSRange(location: 2, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
        try await host.settle()
        #expect(editor.hasMarkedText())
        try await host.pressReturn(modifiers: .command)
        #expect(host.draft.submissions == 0 && editor.hasMarkedText())
        let coordinator = try #require(editor.delegate as? DaybookTextEditor.Coordinator)
        #expect(!coordinator.textView(editor, doCommandBy: #selector(NSResponder.insertNewline(_:))))
        #expect(host.draft.submissions == 0)
        editor.unmarkText()
        editor.selectAll(nil)
        editor.insertText("#工", replacementRange: editor.selectedRange())
        try await host.settle()
        #expect(coordinator.parent.autocomplete.isActive)
        // 本用例检查“确认候选优先”，候选本身的排序由语法引擎测试覆盖。
        let completion = try #require(coordinator.parent.autocomplete.selectedCandidate()?.insertText)
        try await host.pressReturn()
        #expect(host.draft.text == completion)
        #expect(!coordinator.parent.autocomplete.isActive && host.draft.submissions == 0)
        try await host.pressReturn()
        #expect(host.draft.text == completion + "\n" && host.draft.submissions == 0)
        try await host.pressReturn(modifiers: .command)
        #expect(host.draft.submissions == 1)
    }

    @Test func failedSaveKeepsDraftAndFixedRowHeight() async throws {
        let host = try DiaryComposerHost()
        defer { host.close() }
        _ = try await host.focus()
        try await host.enter("失败时继续保留的内容")
        let before = try NativeSyntaxUI.frame("syntax.diary.composer", in: host.window)
        host.draft.rejectSave = true
        try await host.pressReturn(modifiers: .command)
        #expect(host.draft.text == "失败时继续保留的内容")
        #expect(host.draft.status == "diary.window.save.failed")
        #expect(try NativeSyntaxUI.frame("syntax.diary.composer", in: host.window) == before)
        try host.snapshot("note-composer-save-failed")
    }

    @Test(arguments: ["zh-Hans", "en"], [ColorScheme.light, .dark])
    func actionsRemainBesideFixedEditorInBothLanguagesAndAppearances(locale: String, scheme: ColorScheme) async throws {
        let host = try DiaryComposerHost(locale: locale, scheme: scheme)
        defer { host.close() }
        let editor = try await host.focus()
        let row = try NativeSyntaxUI.frame("syntax.diary.composer", in: host.window)
        let button = try NativeSyntaxUI.frame("syntax.commandReturn.button", in: host.window)
        let popout = try NativeSyntaxUI.frame("syntax.diary.popout", in: host.window)
        let scroll = try #require(editor.enclosingScrollView)
        let input = scroll.convert(scroll.bounds, to: nil)
        #expect(row.height <= 60 && input.height == 44)
        #expect(popout.minX >= input.maxX && button.minX >= popout.maxX)
        #expect(abs(button.midY - input.midY) < 1 && abs(popout.midY - input.midY) < 1)
        let appearance = scheme == .dark ? "dark" : "light"
        try host.snapshot("note-composer-empty-\(locale)-\(appearance)")
        try await host.enter(String(repeating: "保持固定高度。Fixed-height note.\n", count: 50))
        #expect(try NativeSyntaxUI.frame("syntax.diary.composer", in: host.window) == row)
        #expect(scroll.bounds.height == 44)
        #expect(editor.bounds.height > scroll.contentView.bounds.height)
        try host.snapshot("note-composer-long-\(locale)-\(appearance)")
    }

    @Test func commandModifierEmphasizesTheSameButtonWithoutMovingIt() async throws {
        let host = try DiaryComposerHost()
        defer { host.close() }
        _ = try await host.focus()
        try await host.enter("按住 Command 高亮保存")
        try await host.postModifiers([])
        let frame = try NativeSyntaxUI.frame("syntax.commandReturn.button", in: host.window)
        let idle = try host.buttonPixels()
        try await host.postModifiers(.command)
        let active = try host.buttonPixels()
        #expect(idle != active)
        let activeFrame = try NativeSyntaxUI.frame("syntax.commandReturn.button", in: host.window)
        #expect(abs(frame.midX - activeFrame.midX) < 1 && abs(frame.midY - activeFrame.midY) < 1)
        try host.snapshot("note-composer-command-highlight")
        try await host.postModifiers([])
        #expect(try host.buttonPixels() == idle)
    }

    @Test func capsLockDoesNotChangeTheCommandReturnAction() async throws {
        let host = try DiaryComposerHost()
        defer { host.close() }
        _ = try await host.focus()
        try await host.enter("Caps Lock 下的手记")
        try await host.pressReturn(modifiers: [.command, .capsLock])
        #expect(host.draft.submissions == 1 && host.draft.lastSaved == "Caps Lock 下的手记")
    }
}

@Observable @MainActor
private final class DiaryComposerProbe {
    var text = ""
    var focused = true
    var tagIDs: Set<UUID> = []
    var status: String?
    var rejectSave = false
    var submissions = 0
    var lastSaved = ""
    var popouts = 0
    var transferred = ""

    func submit() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if rejectSave { status = "diary.window.save.failed"; return }
        submissions += 1
        lastSaved = text
        text = ""
        focused = true
        status = "diary.window.saved"
    }

    func popout() { popouts += 1; transferred = text }
}

@MainActor
private final class DiaryComposerHost {
    private static var retainedContainers: [ModelContainer] = []
    let draft = DiaryComposerProbe()
    let window: NSWindow

    init(locale: String = "zh-Hans", scheme: ColorScheme = .light) throws {
        let container = try ModelContainer(for: Schema(AreaChainSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        container.mainContext.insert(TagItem(name: "工作", sortOrder: 0))
        try container.mainContext.save()
        Self.retainedContainers.append(container)
        let hosting = NSHostingView(rootView: ComposerProbeView(probe: draft)
            .padding(12).frame(width: 380, height: 200, alignment: .top)
            .modelContainer(container).environment(AppPreferences.shared)
            .environment(\.locale, Locale(identifier: locale))
            .preferredColorScheme(scheme).background(DaybookTheme.paper)
            .transaction { $0.disablesAnimations = true }.syntaxOverlayHost())
        hosting.safeAreaRegions = []
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 200),
                          styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() { window.contentView = nil; window.orderOut(nil) }

    func settle() async throws {
        window.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(180))
        window.contentView?.layoutSubtreeIfNeeded()
    }

    func focus() async throws -> NSTextView {
        try await settle()
        let editor = try #require(findEditor(window.contentView))
        window.makeFirstResponder(editor)
        try await settle()
        return editor
    }

    func enter(_ text: String) async throws {
        let editor = try #require(findEditor(window.contentView))
        window.makeFirstResponder(editor)
        editor.insertText(text, replacementRange: editor.selectedRange())
        try await settle()
    }

    func pressReturn(modifiers: NSEvent.ModifierFlags = []) async throws {
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        if modifiers.contains(.command) { #expect(window.performKeyEquivalent(with: event)) }
        else { window.sendEvent(event) }
        try await settle()
    }

    func click(_ identifier: String) async throws {
        let point = try NativeSyntaxUI.center(identifier, in: window)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            window.sendEvent(try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
                eventNumber: 0, clickCount: 1, pressure: 1)))
        }
        try await settle()
    }

    func postModifiers(_ flags: NSEvent.ModifierFlags) async throws {
        let event = try #require(NSEvent.keyEvent(with: .flagsChanged, location: .zero, modifierFlags: flags,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 55))
        NSApp.postEvent(event, atStart: true)
        try await settle()
        try await Task.sleep(for: .milliseconds(350))
    }

    func buttonPixels() throws -> Data {
        let view = try #require(window.contentView)
        let rect = view.convert(try NativeSyntaxUI.frame("syntax.commandReturn.button", in: window), from: nil)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: rect))
        view.cacheDisplay(in: rect, to: bitmap)
        return Data(bytes: try #require(bitmap.bitmapData), count: bitmap.bytesPerRow * bitmap.pixelsHigh)
    }

    func snapshot(_ name: String) throws {
        let view = try #require(window.contentView)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AreaChain-UI-QA")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try #require(bitmap.representation(using: .png, properties: [:]))
            .write(to: directory.appendingPathComponent(name + ".png"), options: .atomic)
    }

    private func findEditor(_ view: NSView?) -> NSTextView? {
        guard let view else { return nil }
        if let editor = view as? DaybookAppKitTextView { return editor }
        return view.subviews.lazy.compactMap { self.findEditor($0) }.first
    }
}

private struct ComposerProbeView: View {
    @Bindable var probe: DiaryComposerProbe

    var body: some View {
        DiaryQuickComposerView(text: $probe.text, focused: $probe.focused,
            orderedTags: [], selectedTagIDs: $probe.tagIDs, onSubmit: probe.submit,
            isCompact: true, status: probe.status, onOpenWindow: probe.popout)
    }
}
