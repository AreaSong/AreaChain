import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct HabitMonthBaselineTests {
    typealias Native = SettingsButtonTestSupport

    @Test(arguments: [CGFloat(280), 320], ["en", "zh-Hans"])
    func productionBaseline(width: CGFloat, locale: String) async throws {
        let f = try HabitMonthTestSupport()
        defer { f.cleanup() }
        // 与真实检查器相同的 16pt 外边距和分区 12pt 内边距。
        let window = f.fixture.window(HabitCheckMonthView(routine: f.routine, inspectDayKey: "2026-09-09")
            .padding(28).frame(maxHeight: .infinity, alignment: .top).background(DaybookPalette.fill.page),
            locale: locale, size: NSSize(width: width, height: 260))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let frames = try HabitMonthTestSupport.frames(window)
        #expect(frames.count == 30)
        #expect(Set(frames.map(\.height)) == [11, 22])
        #expect(Set(frames.map(\.midY)).count == 5)
        #expect(abs(frames[3].minX - frames[2].maxX - 4) < 0.01)
        let labels = Native.elements(window.contentView).map {
            MenuButtonTestSupport.title($0) + (Native.value($0, "accessibilityValue") as? String ?? "")
        }.joined(separator: " ")
        #expect(labels.contains(DayKey.displayName("2026-09-09", locale: Locale(identifier: locale))))
        print("HabitC current width=\(width) locale=\(locale) first=\(frames[0]) last=\(frames[29])")
        try Native.snapshot(window, name: "habitC-current-\(Int(width))-\(locale)")
        try f.assertUnchanged()
    }

    @Test func productionDrawerNavigation() async throws {
        let f = try HabitMonthTestSupport()
        defer { f.cleanup() }
        let window = f.fixture.window(HabitDrawerTestHost(), size: NSSize(width: 320, height: 900))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let button = try HabitMonthTestSupport.day("2026-09-07", host: "habit.month.\(f.routine.id)", in: window)
        try await Native.click(button, in: window)
        #expect(BoardSelection.shared.inspectingDayKey == "2026-09-07")
        #expect(WorkspaceNavigation.shared.selectedTaskID == f.routine.id)
        #expect(WorkspaceNavigation.shared.isInspectorPresented)
        try f.assertUnchanged()
        try Native.snapshot(window, name: "habitC-current-drawer")
    }

    @Test func drawerEditingFocusBaseline() async throws {
        let f = try HabitMonthTestSupport()
        defer { f.cleanup() }
        let window = f.fixture.window(HabitDrawerTestHost(), size: NSSize(width: 320, height: 900))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let editor = try #require(Native.elements(window.contentView).compactMap { $0 as? NSTextView }.first {
            $0.string == "Synthetic notes"
        })
        #expect(window.makeFirstResponder(editor))
        editor.insertText(" draft", replacementRange: NSRange(location: editor.string.utf16.count, length: 0))
        try await SystemPageHost.settle(window)
        let button = try HabitMonthTestSupport.day("2026-09-07", host: "habit.month.\(f.routine.id)", in: window)
        try await Native.click(button, in: window)
        #expect(window.firstResponder === editor)
        #expect(f.routine.notes == "Synthetic notes")
        #expect(editor.string == "Synthetic notes draft")
        #expect(window.makeFirstResponder(nil))
        try await SystemPageHost.settle(window)
        #expect(f.routine.notes == "Synthetic notes draft")
        #expect(f.checks.compactMap(\.snapshot) == f.originalChecks)
    }

    @Test func titleEditingFocusBaseline() async throws {
        let f = try HabitMonthTestSupport()
        defer { f.cleanup() }
        let window = f.fixture.window(HabitDrawerTestHost(), size: NSSize(width: 320, height: 900))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let title = try #require(Native.elements(window.contentView).first {
            MenuButtonTestSupport.title($0) == "Synthetic habit"
                || Native.value($0, "accessibilityValue") as? String == "Synthetic habit"
        })
        try await Native.click(title, in: window)
        let editor = try #require(window.firstResponder as? NSTextView)
        editor.insertText("Synthetic title draft", replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        try await SystemPageHost.settle(window)
        let day = try HabitMonthTestSupport.day("2026-09-07", host: "habit.month.\(f.routine.id)", in: window)
        try await Native.click(day, in: window)
        #expect(window.firstResponder === editor)
        #expect(f.routine.title == "Synthetic habit")
        #expect(editor.string == "Synthetic title draft")
        #expect(window.makeFirstResponder(nil))
        try await SystemPageHost.settle(window)
        #expect(f.routine.title == "Synthetic title draft")
        #expect(f.checks.compactMap(\.snapshot) == f.originalChecks)
    }
}
