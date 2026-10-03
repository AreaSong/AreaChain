import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@MainActor
enum DetailTimeSupport {
    typealias Native = SettingsButtonTestSupport

    static func window(_ fixture: TimePickerConsumerFixture, routine: Bool,
                       locale: String = "en", dark: Bool = false, width: CGFloat = 320) -> NSWindow {
        fixture.native.window(Group {
            if routine { RoutineScheduleSectionView(routine: fixture.routine) }
            else { TodoScheduleSectionView(todo: fixture.todo) }
        }.padding(12), locale: locale, scheme: dark ? .dark : .light,
           size: NSSize(width: width, height: 540))
    }

    static func matches(_ node: NSObject, _ title: String) -> Bool {
        ["accessibilityLabel", "accessibilityTitle", "accessibilityValue"].contains {
            Native.value(node, $0) as? String == title
        }
    }

    // 同一待办有两个“设时刻”：按提醒/截止标题与下一分组标题之间的空间归属唯一选择。
    static func button(_ key: String, due: Bool, locale: String, in window: NSWindow) throws -> NSObject {
        let localized = { (key: String) in L10n.string(String.LocalizationValue(key), locale: Locale(identifier: locale)) }
        let nodes = Native.elements(window.contentView)
        let heading = try #require(nodes.first { matches($0, localized(due ? "drawer.due.title" : "drawer.remind.title")) })
        let top = try Native.frame(heading, in: window).midY
        let nextKey = due ? "drawer.date.title" : "drawer.due.title"
        let next = nodes.first { matches($0, localized(nextKey)) }
        let bottom = try next.map { try Native.frame($0, in: window).midY } ?? -.infinity
        let candidates = try Native.buttons(in: window).filter {
            guard matches($0, localized(key)) || Native.value($0, "accessibilityIdentifier") as? String == key else { return false }
            let mid = try Native.frame($0, in: window).midY
            return mid <= top + 3 && mid > bottom
        }
        let diagnostic = Native.buttons(in: window).map {
            "\(Native.value($0, "accessibilityLabel") ?? "nil"):\((try? Native.frame($0, in: window).midY) ?? -1)"
        }.joined(separator: ", ")
        try #require(candidates.count == 1,
            "时间按钮须在所属分组内唯一：\(key), due=\(due), top=\(top), bottom=\(bottom), \(diagnostic)")
        return candidates[0]
    }

    static func open(due: Bool = false, locale: String = "en", in window: NSWindow) async throws -> NSDatePicker {
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let custom = L10n.string("drawer.remind.custom", locale: Locale(identifier: locale))
        let key = due && Native.buttons(in: window).contains { matches($0, custom) }
            ? "drawer.remind.custom" : "row.time.set"
        let target = try button(key, due: due, locale: locale, in: window)
        try await Native.click(target, in: window)
        let title = L10n.string(due ? "drawer.due.title" : "drawer.remind.title", locale: Locale(identifier: locale))
        let pickers = NSApp.windows.filter(\.isVisible).flatMap {
            Native.elements($0.contentView).compactMap { $0 as? NSDatePicker }
        }.filter { $0.accessibilityLabel() == title }
        try #require(pickers.count == 1)
        return pickers[0]
    }

    static func displayed(_ picker: NSDatePicker) -> Int {
        RemindMinutes.from(date: picker.dateValue, calendar: picker.calendar ?? .current)
    }

    static func partial(_ picker: NSDatePicker) async throws {
        let window = try #require(picker.window)
        try await NativeSyntaxUI.prepareFocus(in: window)
        let rect = picker.convert(picker.bounds, to: nil)
        try await TimePickerNativeTestSupport.click(NSPoint(x: rect.minX + 10, y: rect.midY), in: window)
        try await TimePickerNativeTestSupport.key(124, "\u{F703}", in: window)
        try await TimePickerNativeTestSupport.key(21, "4", in: window)
    }
}
