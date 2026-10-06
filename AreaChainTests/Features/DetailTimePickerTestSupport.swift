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
        let candidates = try buttons(key, due: due, locale: locale, in: window)
        try #require(candidates.count == 1, "时间按钮须在所属分组内唯一：\(key), due=\(due), count=\(candidates.count)")
        return candidates[0]
    }

    static func buttons(_ key: String, due: Bool, locale: String = "en", in window: NSWindow) throws -> [NSObject] {
        let title = L10n.string(String.LocalizationValue(key), locale: Locale(identifier: locale))
        return try nodes(due: due, locale: locale, in: window).filter {
            Native.value($0, "accessibilityRole") as? String == "AXButton"
                && (matches($0, title) || Native.value($0, "accessibilityIdentifier") as? String == key)
        }
    }

    static func nodes(due: Bool, locale: String = "en", in window: NSWindow) throws -> [NSObject] {
        let localized = { (key: String) in L10n.string(String.LocalizationValue(key), locale: Locale(identifier: locale)) }
        let nodes = Native.elements(window.contentView)
        let heading = try #require(nodes.first { matches($0, localized(due ? "drawer.due.title" : "drawer.remind.title")) })
        let top = try Native.frame(heading, in: window).midY
        let nextKey = due ? "drawer.date.title" : "drawer.due.title"
        let next = nodes.first { matches($0, localized(nextKey)) }
        let bottom = try next.map { try Native.frame($0, in: window).midY } ?? -.infinity
        return try nodes.filter {
            guard $0.responds(to: NSSelectorFromString("accessibilityFrame")) else { return false }
            let mid = try Native.frame($0, in: window).midY
            return mid <= top + 3 && mid > bottom
        }
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
        let popup = try #require(pickers[0].window)
        try #require(popup.parent === window && popup.isVisible, "时间弹出层必须属于本例宿主")
        return pickers[0]
    }

    static func displayed(_ picker: NSDatePicker) -> Int {
        RemindMinutes.from(date: picker.dateValue, calendar: picker.calendar ?? .current)
    }

    // 只读焦点日志：不激活、不改归属，也不以日志代替 key window 断言。
    static func lifecycleState(_ stage: String, host: NSWindow, picker: NSDatePicker? = nil) {
        let popup = picker?.window
        print("TIME_LIFECYCLE \(stage) bundle=\(Bundle.main.bundleIdentifier ?? "none") "
            + "host=\(host.windowNumber) visible=\(host.isVisible) key=\(host.isKeyWindow) "
            + "popup=\(popup?.windowNumber ?? -1) parent=\(popup?.parent?.windowNumber ?? -1) "
            + "popupVisible=\(popup?.isVisible ?? false) popupKey=\(popup?.isKeyWindow ?? false) "
            + "active=\(NSApp.isActive) key=\(NSApp.keyWindow?.windowNumber ?? -1) "
            + "foreground=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none")")
    }

    static func partial(_ picker: NSDatePicker) async throws {
        let window = try #require(picker.window)
        try await NativeSyntaxUI.prepareFocus(in: window)
        var stage = "partial focused"
        defer { lifecycleState(stage, host: window, picker: picker) }
        let rect = picker.convert(picker.bounds, to: nil)
        try await TimePickerNativeTestSupport.click(NSPoint(x: rect.minX + 10, y: rect.midY), in: window)
        stage = "partial click returned; next arrow"
        try await TimePickerNativeTestSupport.key(124, "\u{F703}", in: window)
        stage = "partial arrow returned; next digit"
        try await TimePickerNativeTestSupport.key(21, "4", in: window)
    }
    static func expectDisplay(_ minutes: Int, due: Bool, in window: NSWindow) throws {
        let clear = try button("row.time.clear", due: due, locale: "en", in: window)
        let headerY = try Native.frame(clear, in: window).midY
        let label = RemindMinutes.label(minutes, locale: Locale(identifier: "en"))
        // 提醒快捷项也有 12:00；旧值必须来自清除按钮同一标题行，不能误认下方快捷项。
        #expect(try nodes(due: due, in: window).contains {
            guard matches($0, label) else { return false }
            return abs(try Native.frame($0, in: window).midY - headerY) < 8
        }, "原分组必须自然显示旧分钟文字：\(label)")
    }

    static func press(_ button: NSObject, native: Bool, in window: NSWindow) throws {
        if native {
            try #require(window.isKeyWindow && NSApp.isActive)
            let frame = try SettingsButtonTestSupport.frame(button, in: window)
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                let event = try #require(NSEvent.mouseEvent(with: type, location: .init(x: frame.midX, y: frame.midY),
                    modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                    context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
                NSApp.sendEvent(event)
            }
        } else {
            let selector = NSSelectorFromString("accessibilityPerformPress")
            try #require(button.responds(to: selector))
            _ = button.perform(selector)
        }
    }

    static func failureFixture() throws -> TimePickerConsumerFixture {
        let fixture = try TimePickerConsumerFixture(minutes: 720)
        do {
            fixture.todo.dueMinutes = 600
            try fixture.native.container.mainContext.save()
            return fixture
        } catch {
            fixture.cleanup()
            throw error
        }
    }
}

/// 只观察本例 context 的真实 save 调用；失败注入边界另行计数。
@MainActor
final class DetailTimeSaveCounter {
    private var observer: NSObjectProtocol?
    private(set) var count = 0

    init(_ context: ModelContext) {
        observer = NotificationCenter.default.addObserver(forName: ModelContext.willSave,
            object: context, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.count += 1 }
            }
    }

    func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }
}
