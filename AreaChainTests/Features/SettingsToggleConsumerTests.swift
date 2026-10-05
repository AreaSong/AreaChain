import AppKit
import SwiftUI
import Testing
import UserNotifications
@testable import AreaChain

@Suite(.serialized) @MainActor
struct SettingsToggleConsumerTests {
    typealias Native = SettingsButtonTestSupport
    static let keys = ["settings.login", "settings.capture", "settings.calendar.sync"]
    static let titles = ["settings.login", "settings.capture.stamp", "settings.calendar.sync.toggle"]

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func groupedSectionLayout(locale: String, scheme: ColorScheme) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = SettingsToggleProbe()
        state.needsApproval = true
        state.loginMessage = String(repeating: "Synthetic login error · 合成登录错误。", count: 5)
        for size in [NSSize(width: 640, height: 760), NSSize(width: 420, height: 560)] {
            let window = fixture.window(SettingsToggleProbeView(prefs: fixture.prefs, state: state),
                                        locale: locale, scheme: scheme, size: size)
            defer { SystemPageHost.release(window) }
            try await SystemPageHost.settle(window)
            for (key, title) in zip(Self.keys, Self.titles) {
                try await revealToggle(key, in: window)
                let visible = try toggle(key, in: window)
                try Native.assertBounds([visible], in: window)
                let expected = L10n.string(String.LocalizationValue(title), locale: Locale(identifier: locale))
                #expect(Native.value(visible, "accessibilityLabel") as? String == expected)
                let rect = try Native.frame(visible, in: window)
                #expect(rect.height >= 28)
                #expect(rect.minX == 30 && rect.maxX == size.width - 30, "保留 Form 的左右列边界")
                try Native.snapshot(window, name: "toggle-form-\(key)-\(locale)-\(scheme)-\(Int(size.width))")
            }
            let description = try textNode(try #require(state.loginMessage), in: window)
            try await reveal(description, in: window)
            try Native.assertBounds([description], in: window)
        }
    }

    @Test(arguments: ["en", "zh-Hans"])
    func loginRequestAcceptRejectAndApproval(locale: String) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = SettingsToggleProbe()
        let window = fixture.window(SettingsToggleProbeView(prefs: fixture.prefs, state: state), locale: locale)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let original = preferences(fixture)
        try await click("settings.login", in: window)
        #expect(state.requests == [true] && state.login)
        try assertValue(true, key: "settings.login", in: window)
        try await click("settings.login", in: window, label: true)
        #expect(state.requests == [true, false] && !state.login)
        try assertValue(false, key: "settings.login", in: window)
        state.reject = true
        state.needsApproval = true
        state.loginMessage = "Synthetic registration failure · 合成注册失败"
        try await click("settings.login", in: window)
        #expect(state.requests == [true, false, true] && !state.login)
        try assertValue(false, key: "settings.login", in: window)
        #expect(hasText(try #require(state.loginMessage), in: window))
        let approval = L10n.string("settings.login.needsApproval", locale: Locale(identifier: locale))
        #expect(hasText(approval, in: window))
        _ = try Native.button("settings.login.openSystem", locale: locale, in: window)
        state.needsApproval = false
        state.loginMessage = nil
        state.login = true
        try await SystemPageHost.settle(window)
        try assertValue(true, key: "settings.login", in: window)
        #expect(!hasText(approval, in: window))
        #expect(!SystemPageHost.identifiers(in: window).contains("settings.login.openSystem"))
        #expect(state.requests == [true, false, true] && state.notificationRequests == 0)
        #expect(preferences(fixture) == original)
    }

    @Test(arguments: ["en", "zh-Hans"])
    func preferencesPersistIndependentlyAndFollowExternalChanges(locale: String) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = SettingsToggleProbe()
        let calendar = SettingsCalendarSnapshot()
        defer { calendar.restore() }
        CalendarSyncStatus.shared.mark(.off)
        // AppDelegate 在 XCTest 下不装配服务，独立 suite 不能替代这层保护。
        #expect(AppWindows.workspaceViewProvider == nil)
        #expect(!fixture.prefs.stampCaptureApp && !fixture.prefs.syncCalendarEvents)
        let source = fixture.prefs.localPreferenceSource
        let observers = [Notification.Name.appPreferencesDidChange, .localPreferenceDidChange].map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { note in
                if name == .localPreferenceDidChange, (note.object as? LocalPreferenceChange)?.source != source { return }
                MainActor.assumeIsolated { state.preferenceNotifications += 1 }
            }
        }
        defer { observers.forEach { NotificationCenter.default.removeObserver($0) } }
        let window = fixture.window(SettingsToggleProbeView(prefs: fixture.prefs, state: state), locale: locale)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        for key in ["settings.capture", "settings.calendar.sync"] {
            try await checkPreferenceRoundTrip(key, fixture: fixture, state: state, window: window)
        }
        #expect(state.preferenceNotifications == 6)
        #expect(state.requests.isEmpty && !state.login && state.notificationRequests == 0)
        #expect(CalendarSyncStatus.shared.phase == .off && CalendarSyncStatus.shared.lastSyncedAt == nil)
    }

    private func checkPreferenceRoundTrip(_ key: String, fixture: Native,
                                          state: SettingsToggleProbe, window: NSWindow) async throws {
        let storageKey = key == "settings.capture" ? AppPreferences.stampCaptureAppKey : AppPreferences.syncCalendarEventsKey
        let original = preferences(fixture)
        let before = state.preferenceNotifications
        for (index, expected) in [true, false].enumerated() {
            try await click(key, in: window, label: index == 1)
            try assertValue(expected, key: key, in: window)
            #expect(fixture.defaults.bool(forKey: storageKey) == expected)
            let rebuilt = AppPreferences(defaults: fixture.defaults)
            #expect((key == "settings.capture" ? rebuilt.stampCaptureApp : rebuilt.syncCalendarEvents) == expected)
            #expect(preferences(fixture, excluding: storageKey) == original.filter { $0.key != storageKey })
            #expect(state.preferenceNotifications == before + index + 1)
        }
        if key == "settings.capture" { fixture.prefs.stampCaptureApp = true }
        else { fixture.prefs.syncCalendarEvents = true }
        try await SystemPageHost.settle(window)
        try assertValue(true, key: key, in: window)
        let rebuilt = AppPreferences(defaults: fixture.defaults)
        #expect(rebuilt.stampCaptureApp == fixture.prefs.stampCaptureApp)
        #expect(rebuilt.syncCalendarEvents == fixture.prefs.syncCalendarEvents)
        #expect(preferences(fixture, excluding: storageKey) == original.filter { $0.key != storageKey })
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func calendarIntentKeepsDeniedAndConflict(locale: String, scheme: ColorScheme) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let calendar = SettingsCalendarSnapshot()
        defer { calendar.restore() }
        let status = CalendarSyncStatus.shared
        for phase in [CalendarSyncPhase.denied, .conflict] {
            status.mark(phase)
            let comparison = CalendarConflictComparison(taskID: UUID(),
                local: CalendarContent(title: String(repeating: "Synthetic local · 合成本地 ", count: 4),
                                       dayKey: "2026-10-01", remindMinutes: 540), remote: nil)
            status.conflictComparisons = phase == .conflict ? [comparison] : []
            fixture.prefs.syncCalendarEvents = false
            let state = SettingsToggleProbe()
            state.calendarMessage = L10n.string(String.LocalizationValue(phase.messageKey), locale: Locale(identifier: locale))
            let window = fixture.window(SettingsToggleProbeView(prefs: fixture.prefs, state: state), locale: locale, scheme: scheme)
            defer { SystemPageHost.release(window) }
            try await NativeSyntaxUI.prepareFocus(in: window)
            try await SystemPageHost.settle(window)
            try await click("settings.calendar.sync", in: window)
            try assertValue(true, key: "settings.calendar.sync", in: window)
            #expect(fixture.prefs.syncCalendarEvents && status.phase == phase)
            #expect(hasText(try #require(state.calendarMessage), in: window))
            #expect(!hasText(L10n.string("settings.calendar.sync.status.ok", locale: Locale(identifier: locale)), in: window))
            let retry = try Native.button("settings.calendar.sync.retry", locale: locale, in: window)
            let detailKey = phase == .denied ? "settings.calendar.openSystem" : "settings.calendar.conflict.open"
            let detail = try Native.button(detailKey, locale: locale, in: window)
            if phase == .conflict {
                let text = Native.elements(window.contentView).compactMap { Native.value($0, "accessibilityValue") as? String }
                    .joined(separator: "\n")
                #expect(text.contains(comparison.local.title))
                #expect(text.contains(L10n.string("settings.calendar.conflict.missing", locale: Locale(identifier: locale))))
            }
            try await reveal(detail, in: window)
            try Native.assertBounds([try Native.button(detailKey, locale: locale, in: window)], in: window)
            try Native.snapshot(window, name: "toggle-calendar-\(phase)-\(locale)-\(scheme)")
            let message = try textNode(try #require(state.calendarMessage), in: window)
            try await reveal(message, in: window)
            try Native.assertBounds([message], in: window)
            #expect(retry !== detail)
            try await click("settings.calendar.sync", in: window)
            #expect(!fixture.prefs.syncCalendarEvents && status.phase == phase)
            #expect(!SystemPageHost.identifiers(in: window).contains(detailKey))
            #expect(state.requests.isEmpty && state.notificationRequests == 0 && !fixture.prefs.stampCaptureApp)
        }
    }

    @Test func disabledAndNeighborButtonDoNotCrossWrite() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = SettingsToggleProbe()
        state.disabled = true
        let window = fixture.window(SettingsToggleProbeView(prefs: fixture.prefs, state: state))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let original = preferences(fixture)
        for key in Self.keys {
            try await click(key, in: window)
            let node = try toggle(key, in: window)
            #expect((node.value(forKey: "accessibilityEnabled") as? NSNumber)?.boolValue == false)
            let press = NSSelectorFromString("accessibilityPerformPress")
            try #require(node.responds(to: press))
            _ = node.perform(press)
            try await SystemPageHost.settle(window)
            try assertValue(false, key: key, in: window)
        }
        #expect(preferences(fixture) == original && state.requests.isEmpty)
        state.disabled = false
        try await SystemPageHost.settle(window)
        let request = try Native.button("settings.notify.request", in: window)
        try await reveal(request, in: window)
        try await Native.click(try Native.button("settings.notify.request", in: window), in: window)
        #expect(state.notificationRequests == 1 && state.requests.isEmpty)
        #expect(preferences(fixture) == original && !state.login)
        for key in Self.keys {
            try await click(key, in: window)
            #expect(state.notificationRequests == 1)
        }
        #expect(state.requests == [true] && state.login)
        #expect(fixture.prefs.stampCaptureApp && fixture.prefs.syncCalendarEvents)
    }

    @Test func fixtureRestoresProcessAppearance() throws {
        let previous = NSApp.appearance
        let fixture = try Native()
        defer { fixture.cleanup() }
        fixture.prefs.appearance = .dark
        #expect(NSApp.appearance?.name == .darkAqua)
        fixture.cleanup()
        #expect(NSApp.appearance === previous)
    }

    private func preferences(_ fixture: Native, excluding key: String = "") -> [String: NSObject] {
        (fixture.defaults.persistentDomain(forName: fixture.suite) ?? [:])
            .filter { $0.key != key }.compactMapValues { $0 as? NSObject }
    }

    private func hasText(_ expected: String, in window: NSWindow) -> Bool {
        Native.elements(window.contentView).contains { node in
            ["accessibilityLabel", "accessibilityTitle", "accessibilityValue"].contains { field in
                Native.value(node, field) as? String == expected
            }
        }
    }

    private func textNode(_ expected: String, in window: NSWindow) throws -> NSObject {
        try #require(Native.elements(window.contentView).first {
            Native.value($0, "accessibilityRole") as? String == "AXStaticText"
                && (Native.value($0, "accessibilityValue") as? String == expected
                    || Native.value($0, "accessibilityLabel") as? String == expected)
        }, "未找到完整说明文本")
    }

    private func assertValue(_ expected: Bool, key: String, in window: NSWindow) throws {
        let node = try toggle(key, in: window)
        #expect((Native.value(node, "accessibilityValue") as? NSNumber)?.boolValue == expected)
        #expect(Native.value(node, "accessibilityRole") as? String == "AXCheckBox")
    }

    private func click(_ key: String, in window: NSWindow, label: Bool = false) async throws {
        try await revealToggle(key, in: window)
        try #require(window.isKeyWindow)
        let node = try toggle(key, in: window)
        try Native.assertBounds([node], in: window)
        let rect = try Native.frame(node, in: window)
        for button in Native.buttons(in: window) {
            #expect(try !rect.intersects(Native.frame(button, in: window)), "开关与相邻按钮不能共享点击区域")
        }
        let point = NSPoint(x: label ? rect.minX + 12 : rect.maxX - 17, y: rect.midY)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            NSApp.sendEvent(try MenuButtonTestSupport.mouse(type, at: point, in: window))
        }
        try await SystemPageHost.settle(window)
    }

    private func revealToggle(_ key: String, in window: NSWindow) async throws {
        try await reveal(toggle(key, in: window), in: window)
    }

    private func reveal(_ node: NSObject, in window: NSWindow) async throws {
        // AX 框贴到视口边缘时仍可能被裁切；多留一行空间后再核对真实边界。
        try await Native.reveal(node, in: window)
        let scroll = try #require(Native.elements(window.contentView).compactMap { $0 as? NSScrollView }.first)
        let document = try #require(scroll.documentView)
        for _ in 0..<12 {
            let rect = try Native.frame(node, in: window)
            let height = try #require(window.contentView).bounds.height
            if rect.minY >= 28 && rect.maxY <= height - 28 { return }
            let delta: CGFloat = rect.minY < 28 ? 100 : -100
            let origin = scroll.contentView.bounds.origin
            let maxY = max(0, document.bounds.height - scroll.contentView.bounds.height)
            let y = min(maxY, max(0, origin.y + (document.isFlipped ? delta : -delta)))
            scroll.contentView.scroll(to: NSPoint(x: origin.x, y: y))
            scroll.reflectScrolledClipView(scroll.contentView)
            try await SystemPageHost.settle(window)
        }
        Issue.record("滚动后控件仍未完整进入可见区域")
    }

    private func toggle(_ key: String, in window: NSWindow) throws -> NSObject {
        try #require(Native.elements(window.contentView).first {
            Native.value($0, "accessibilityIdentifier") as? String == key
                && ["AXCheckBox", "AXSwitch"].contains(Native.value($0, "accessibilityRole") as? String ?? "")
        }, "未找到生产 Toggle：\(key)")
    }
}

@MainActor @Observable
private final class SettingsToggleProbe {
    var login = false
    var requests: [Bool] = []
    var reject = false
    var needsApproval = false
    var loginMessage: String?
    var calendarMessage: String?
    var notificationRequests = 0
    var preferenceNotifications = 0
    var disabled = false

    func requestLogin(_ enabled: Bool) {
        requests.append(enabled)
        // 合成宿主模拟注册后的回读；不调用 SMAppService。
        if reject { login = false }
    }
}

@MainActor
private struct SettingsCalendarSnapshot {
    let phase = CalendarSyncStatus.shared.phase
    let lastSyncedAt = CalendarSyncStatus.shared.lastSyncedAt
    let conflictTaskIDs = CalendarSyncStatus.shared.conflictTaskIDs
    let comparisons = CalendarSyncStatus.shared.conflictComparisons

    func restore() {
        CalendarSyncStatus.shared.phase = phase
        CalendarSyncStatus.shared.lastSyncedAt = lastSyncedAt
        CalendarSyncStatus.shared.conflictTaskIDs = conflictTaskIDs
        CalendarSyncStatus.shared.conflictComparisons = comparisons
    }
}

@MainActor
private struct SettingsToggleProbeView: View {
    let prefs: AppPreferences
    @Bindable var state: SettingsToggleProbe

    var body: some View {
        Form {
            GeneralSettingsSection(prefs: prefs, launchesAtLogin: $state.login,
                loginNeedsApproval: state.needsApproval, statusMessage: state.loginMessage,
                onUpdateLoginItem: state.requestLogin)
            SyncSettingsSection(prefs: prefs, notifyStatus: .constant(.notDetermined),
                notifyStatusText: "Synthetic notification status · 合成通知状态",
                calendarSyncStatusText: state.calendarMessage,
                onRequestNotifyAuth: { state.notificationRequests += 1 })
        }
        .formStyle(.grouped)
        .daybookScroll()
        .disabled(state.disabled)
    }
}
