import AppKit
import SwiftData
import SwiftUI
import Testing
import UserNotifications
@testable import AreaChain

@Suite(.serialized) @MainActor
struct SettingsSectionPresentationTests {
    @Test func loginApprovalExplainsAndOffersSystemSettings() async throws {
        let fixture = try SettingsButtonTestSupport()
        defer { fixture.cleanup() }
        let container = fixture.container
        let view = LoginApprovalProbe(prefs: fixture.prefs)
        let window = SystemPageHost.window(
            view, container: container, scheme: .light, locale: "zh-Hans", size: NSSize(width: 520, height: 420)
        )
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let ids = SystemPageHost.identifiers(in: window)
        #expect(ids.contains("settings.login.needsApproval"))
        #expect(ids.contains("settings.login.openSystem"))
        try SystemPageHost.assertContained(["settings.login.needsApproval", "settings.login.openSystem"], in: window)
    }

    @Test func notificationTestBannerIsOfferedUntilDenied() async throws {
        let fixture = try SettingsButtonTestSupport()
        defer { fixture.cleanup() }
        let container = fixture.container
        let allowed = SystemPageHost.window(
            NotificationSettingsProbe(prefs: fixture.prefs, status: .authorized),
            container: container,
            scheme: .light,
            locale: "zh-Hans",
            size: NSSize(width: 420, height: 560)
        )
        defer { SystemPageHost.release(allowed) }
        try await SystemPageHost.settle(allowed)
        #expect(SystemPageHost.identifiers(in: allowed).contains("settings.notify.test"))
        try SystemPageHost.assertContained(["settings.notify.test"], in: allowed)
        #expect(L10n.string("settings.notify.test", locale: Locale(identifier: "zh-Hans")) == "测试通知")
        #expect(L10n.string("settings.notify.test", locale: Locale(identifier: "en")) == "Send a test")
        #expect(L10n.string("notify.test.body", locale: Locale(identifier: "zh-Hans")) == "这是一条测试通知。")
        #expect(L10n.string("notify.test.body", locale: Locale(identifier: "en")) == "This is a test notification.")
        #expect(L10n.string("settings.notify.test.sent", locale: Locale(identifier: "zh-Hans")) == "已发出测试通知。")
        #expect(L10n.string("settings.notify.test.sent", locale: Locale(identifier: "en")) == "A test notification was sent.")

        let english = SystemPageHost.window(
            NotificationSettingsProbe(prefs: fixture.prefs, status: .authorized),
            container: container,
            scheme: .dark,
            locale: "en",
            size: NSSize(width: 420, height: 560)
        )
        defer { SystemPageHost.release(english) }
        try await SystemPageHost.settle(english)
        try SystemPageHost.assertContained(["settings.notify.test"], in: english)

        let denied = SystemPageHost.window(
            NotificationSettingsProbe(prefs: fixture.prefs, status: .denied),
            container: container,
            scheme: .light,
            locale: "zh-Hans",
            size: NSSize(width: 420, height: 560)
        )
        defer { SystemPageHost.release(denied) }
        try await SystemPageHost.settle(denied)
        let deniedIDs = SystemPageHost.identifiers(in: denied)
        #expect(!deniedIDs.contains("settings.notify.test"))
        #expect(deniedIDs.contains("settings.notify.openSystem"))
    }

    @Test func calendarConflictListsBothSidesAndAMissingEvent() async throws {
        let fixture = try SettingsButtonTestSupport()
        defer { fixture.cleanup() }
        let container = fixture.container
        let local = CalendarContent(title: "本地标题", dayKey: "2026-09-30", remindMinutes: 9 * 60)
        let remote = CalendarContent(title: "日历标题", dayKey: "2026-10-01", remindMinutes: nil)
        let view = CalendarConflictProbe(local: local, remote: remote)
        let window = SystemPageHost.window(
            view, container: container, scheme: .light, locale: "zh-Hans", size: NSSize(width: 520, height: 420)
        )
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let described = accessibilityDump(window)
        #expect(described.contains("本机 · 本地标题"), "\(described)")
        #expect(described.contains("09:00"), "\(described)")
        #expect(described.contains("日历 · 日历标题"), "\(described)")
        #expect(described.contains("无提醒"), "\(described)")
        #expect(described.contains("日历 · 日历里没有可对照的这一条"), "\(described)")
    }

    private struct NotificationSettingsProbe: View {
        var prefs: AppPreferences
        @State private var status: UNAuthorizationStatus
        @State private var markers: Set<String> = []

        init(prefs: AppPreferences, status: UNAuthorizationStatus) {
            self.prefs = prefs
            _status = State(initialValue: status)
        }

        var body: some View {
            Form {
                SyncSettingsSection(
                    prefs: prefs,
                    notifyStatus: $status,
                    notifyStatusText: "状态",
                    calendarSyncStatusText: nil,
                    onRequestNotifyAuth: {}
                )
            }
            .formStyle(.grouped)
            .systemPageMarkers($markers)
            .accessibilityIdentifier("settings.notify.probe")
            .accessibilityValue(markers.sorted().joined(separator: " "))
        }
    }

    private struct LoginApprovalProbe: View {
        var prefs: AppPreferences
        @State private var markers: Set<String> = []

        var body: some View {
            Form {
                GeneralSettingsSection(
                    prefs: prefs,
                    launchesAtLogin: .constant(false),
                    loginNeedsApproval: true,
                    statusMessage: nil,
                    onUpdateLoginItem: { _ in }
                )
            }
            .formStyle(.grouped)
            .systemPageMarkers($markers)
            .accessibilityIdentifier("settings.login.probe")
            .accessibilityValue(markers.sorted().joined(separator: " "))
        }
    }

    private struct CalendarConflictProbe: View {
        var local: CalendarContent
        var remote: CalendarContent
        @State private var markers: Set<String> = []

        var body: some View {
            Form {
                CalendarConflictList(comparisons: [
                    CalendarConflictComparison(taskID: UUID(), local: local, remote: remote),
                    CalendarConflictComparison(taskID: UUID(), local: local, remote: nil)
                ]) { _ in }
            }
            .formStyle(.grouped)
            .systemPageMarkers($markers)
            .accessibilityIdentifier("settings.calendar.probe")
            .accessibilityValue(markers.sorted().joined(separator: " "))
        }
    }

    private func accessibilityDump(_ window: NSWindow) -> String {
        var lines: [String] = []
        func walk(_ element: NSObject) {
            if let accessible = element as? NSAccessibilityProtocol {
                let pieces = [
                    accessible.accessibilityIdentifier() ?? "",
                    accessible.accessibilityLabel() ?? "",
                    accessible.accessibilityTitle() ?? "",
                    String(describing: accessible.accessibilityValue() ?? "")
                ].filter { !$0.isEmpty && $0 != "nil" && $0 != "0" }
                if !pieces.isEmpty { lines.append(pieces.joined(separator: " ")) }
                for child in accessible.accessibilityChildren() ?? [] {
                    if let object = child as? NSObject { walk(object) }
                }
            }
            if let view = element as? NSView {
                for subview in view.subviews { walk(subview) }
            }
        }
        if let root = window.contentView { walk(root) }
        return lines.joined(separator: "\n")
    }

}
