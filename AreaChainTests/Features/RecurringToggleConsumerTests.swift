import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct RecurringToggleConsumerTests {
    typealias Native = SettingsButtonTestSupport

    @Test(arguments: [false, true])
    func editorOnlyCommitsOnSave(save: Bool) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        #expect(NotificationScheduler.isRunningTests)
        let context = fixture.container.mainContext
        let repo = RecurringToggleRepository(context)
        let previous = DayBoardMutations.routineRepositoryProvider
        DayBoardMutations.routineRepositoryProvider = { _ in repo }
        defer { DayBoardMutations.routineRepositoryProvider = previous }
        let window = fixture.window(RecurringItemEditor(), size: NSSize(width: 440, height: 600))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try await replaceTitle("Synthetic recurring item", in: window, placeholder: "Title")
        try await Native.click(toggle(in: window), in: window)
        #expect(try context.fetchCount(FetchDescriptor<DailyRoutine>()) == 0)
        #expect(repo.creations == 0 && repo.switches == 0)
        try expectEnabled(false, in: window)
        try await Native.click(Native.button(save ? "common.save" : "recurring.create.cancel", in: window), in: window)
        let records = try context.fetch(FetchDescriptor<DailyRoutine>())
        #expect(records.count == (save ? 1 : 0))
        #expect(repo.creations == (save ? 1 : 0))
        if save {
            #expect(records.first?.isEnabled == false)
            #expect(records.first?.remindMinutes == nil)
            #expect(records.first?.title == "Synthetic recurring item")
        }
    }

    @Test func editorFailureKeepsDraftAndCanRetry() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let context = fixture.container.mainContext
        let repo = RecurringToggleRepository(context)
        repo.fail = true
        let previous = DayBoardMutations.routineRepositoryProvider
        DayBoardMutations.routineRepositoryProvider = { _ in repo }
        defer { DayBoardMutations.routineRepositoryProvider = previous }
        let window = fixture.window(RecurringItemEditor(), size: NSSize(width: 440, height: 640))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try await replaceTitle("Retained synthetic draft", in: window, placeholder: "Title")
        try await Native.click(toggle(in: window), in: window)
        try await Native.click(Native.button("common.save", in: window), in: window)
        #expect(repo.creations == 1)
        #expect(try context.fetchCount(FetchDescriptor<DailyRoutine>()) == 0)
        try expectEnabled(false, in: window)
        #expect(fields(in: window).contains { $0.stringValue == "Retained synthetic draft" })
        #expect(Native.elements(window.contentView).contains {
            (Native.value($0, "accessibilityLabel") ?? Native.value($0, "accessibilityValue")) as? String == "Could not save. Your draft is still here."
        })
        repo.fail = false
        try await Native.click(Native.button("common.save", in: window), in: window)
        let saved = try #require(context.fetch(FetchDescriptor<DailyRoutine>()).first)
        #expect(saved.title == "Retained synthetic draft" && !saved.isEnabled)
    }

    @Test(arguments: ["en", "zh-Hans"], [false, true])
    func managementTransactionsAndLayout(locale: String, dark: Bool) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let context = fixture.container.mainContext
        let repo = RecurringToggleRepository(context)
        let today = DayClock.shared.todayKey
        let routine = try repo.base.addRoutine(CreateRoutineParams(title: "Synthetic recurring row", createdDayKey: today))
        let previous = DayBoardMutations.routineRepositoryProvider
        DayBoardMutations.routineRepositoryProvider = { _ in repo }
        defer { DayBoardMutations.routineRepositoryProvider = previous }
        let window = fixture.window(ResidentsPage(), locale: locale, scheme: dark ? .dark : .light,
                                    size: NSSize(width: 440, height: 520))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let node = try toggle(in: window)
        #expect(Native.value(node, "accessibilityLabel") as? String ==
                L10n.string("residents.enabled", locale: Locale(identifier: locale)))
        #expect(try Native.frame(node, in: window).width == 34)
        try await Native.click(node, in: window)
        #expect(!routine.isEnabled && routine.pausedOnDayKey == today && repo.switches == 1)
        try expectEnabled(false, in: window)
        repo.fail = true
        try await Native.click(toggle(in: window), in: window)
        #expect(!routine.isEnabled && routine.pausedOnDayKey == today && repo.switches == 2)
        try expectEnabled(false, in: window)
        repo.fail = false
        try await Native.click(toggle(in: window), in: window)
        #expect(routine.isEnabled && routine.pausedOnDayKey == nil && repo.switches == 3)
        #expect(routine.checks.isEmpty)
        try expectEnabled(true, in: window)
        try Native.assertBounds([toggle(in: window), Native.button("drawer.inspector.toggle", locale: locale, in: window),
                                 Native.button("row.delete", locale: locale, in: window)], in: window)
        try Native.snapshot(window, name: "recurring-row-\(locale)-\(dark)")
    }

    @Test func titleDraftAndAdjacentInspectorKeepTheirContracts() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let context = fixture.container.mainContext
        let routine = try SwiftDataRoutineRepository(context: context).addRoutine(title: "Original synthetic title")
        let nav = WorkspaceNavigation.shared
        let selected = nav.selectedTaskID
        let reference = nav.inspectedReference
        let presented = nav.isInspectorPresented
        defer {
            nav.selectedTaskID = selected
            nav.inspectedReference = reference
            nav.isInspectorPresented = presented
        }
        let window = fixture.window(ResidentsPage(), size: NSSize(width: 560, height: 520))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try await replaceTitle("Changed synthetic title", in: window, placeholder: "Title")
        try await Native.click(toggle(in: window), in: window)
        #expect(!routine.isEnabled)
        // 开关不清空标题草稿；原控件若仍保有焦点，则显式失焦才走原保存入口。
        #expect(fields(in: window).contains { $0.stringValue == "Changed synthetic title" })
        window.makeFirstResponder(nil)
        try await SystemPageHost.settle(window)
        #expect(routine.title == "Changed synthetic title")
        try await Native.click(Native.button("drawer.inspector.toggle", in: window), in: window)
        #expect(nav.selectedTaskID == routine.id && nav.isInspectorPresented)
        #expect(!routine.isEnabled && routine.deletedAt == nil)
        #expect(routine.title == "Changed synthetic title")
    }

    @Test(arguments: ["en", "zh-Hans"], [false, true])
    func editorLayouts(locale: String, dark: Bool) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let window = fixture.window(RecurringItemEditor(), locale: locale, scheme: dark ? .dark : .light,
                                    size: NSSize(width: dark ? 560 : 440, height: 640))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let node = try toggle(in: window)
        #expect(Native.value(node, "accessibilityLabel") as? String ==
                L10n.string("residents.enabled", locale: Locale(identifier: locale)))
        try Native.assertBounds([node, Native.button("common.save", locale: locale, in: window),
                                 Native.button("recurring.create.cancel", locale: locale, in: window)], in: window)
        try Native.snapshot(window, name: "recurring-form-\(locale)-\(dark)")
    }

    private func toggle(in window: NSWindow) throws -> NSObject {
        try #require(Native.elements(window.contentView).first {
            Native.value($0, "accessibilityRole") as? String == "AXCheckBox"
        })
    }

    private func expectEnabled(_ enabled: Bool, in window: NSWindow) throws {
        #expect((Native.value(try toggle(in: window), "accessibilityValue") as? NSNumber)?.boolValue == enabled)
    }

    private func fields(in window: NSWindow) -> [NSTextField] {
        Native.elements(window.contentView).compactMap { $0 as? NSTextField }.filter(\.isEditable)
    }

    private func replaceTitle(_ text: String, in window: NSWindow, placeholder: String) async throws {
        let field = try #require(fields(in: window).first { $0.placeholderString == placeholder })
        #expect(window.makeFirstResponder(field))
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.selectAll(nil)
        editor.insertText(text, replacementRange: editor.selectedRange())
        try await SystemPageHost.settle(window)
    }
}
