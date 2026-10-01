import AppKit
import SwiftUI
import Testing
import UserNotifications
@testable import AreaChain

@Suite(.serialized) @MainActor
struct SettingsButtonConsumerTests {
    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func notificationAndCalendarStates(locale: String, scheme: ColorScheme) async throws {
        let f = try SettingsButtonTestSupport()
        defer { f.cleanup() }
        let status = CalendarSyncStatus.shared
        let oldPhase = status.phase
        let oldComparisons = status.conflictComparisons
        defer {
            status.phase = oldPhase
            status.conflictComparisons = oldComparisons
        }
        // 仅改 XCTest 进程内的合成呈现状态，不启动协调器或刷新日历。
        f.prefs.syncCalendarEvents = true
        for authorization in [UNAuthorizationStatus.notDetermined, .authorized, .denied] {
            status.phase = authorization == .denied ? .denied : .conflict
            status.conflictComparisons = []
            var requests = 0
            let window = f.window(Form {
                SyncSettingsSection(prefs: f.prefs, notifyStatus: .constant(authorization),
                    notifyStatusText: "Synthetic notification status · 合成通知状态",
                    calendarSyncStatusText: "Synthetic calendar status · 合成日历状态",
                    onRequestNotifyAuth: { requests += 1 })
            }.formStyle(.grouped), locale: locale, scheme: scheme)
            defer { SystemPageHost.release(window) }
            try await NativeSyntaxUI.prepareFocus(in: window)
            try await SystemPageHost.settle(window)
            let notificationKey = authorization == .denied ? "settings.notify.openSystem" : "settings.notify.request"
            let request = try SettingsButtonTestSupport.button(notificationKey, locale: locale, in: window)
            if authorization != .denied {
                _ = try SettingsButtonTestSupport.button("settings.notify.test", locale: locale, in: window)
                try await SettingsButtonTestSupport.click(request, in: window)
                #expect(requests == 1)
            } else {
                _ = try SettingsButtonTestSupport.button("settings.calendar.openSystem", locale: locale, in: window)
                #expect(!SystemPageHost.identifiers(in: window).contains("settings.notify.test"))
            }
            _ = try SettingsButtonTestSupport.button("settings.calendar.sync.retry", locale: locale, in: window)
            try SettingsButtonTestSupport.assertBounds(SettingsButtonTestSupport.buttons(in: window), in: window)
            try SettingsButtonTestSupport.snapshot(window, name: "sync-\(authorization.rawValue)-\(locale)-\(scheme)")
        }
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func supportLinksHaveContainedLabels(locale: String, scheme: ColorScheme) async throws {
        let f = try SettingsButtonTestSupport()
        defer { f.cleanup() }
        let window = f.window(Form { ProjectSupportSections() }.formStyle(.grouped), locale: locale, scheme: scheme)
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let keys = ["project.support.usage", "project.support.issue", "project.support.idea",
                    "project.about.repository", "project.about.license"]
        let buttons = try keys.map { try SettingsButtonTestSupport.button($0, locale: locale, in: window) }
        try SettingsButtonTestSupport.assertBounds(buttons, in: window)
        try SettingsButtonTestSupport.snapshot(window, name: "support-\(locale)-\(scheme)")
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func calendarConflictClickKeepsOriginalComparison(locale: String, scheme: ColorScheme) async throws {
        let f = try SettingsButtonTestSupport()
        defer { f.cleanup() }
        let comparison = CalendarConflictComparison(taskID: UUID(),
            local: CalendarContent(title: String(repeating: "Synthetic local long title 合成本地长标题 ", count: 3),
                                   dayKey: "2026-10-01", remindMinutes: 540),
            remote: CalendarContent(title: "Synthetic remote 合成远端", dayKey: "2026-10-02", remindMinutes: nil))
        var opened: [UUID] = []
        let window = f.window(Form {
            CalendarConflictList(comparisons: [comparison]) { opened.append($0.taskID) }
        }.formStyle(.grouped), locale: locale, scheme: scheme)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let button = try SettingsButtonTestSupport.button("settings.calendar.conflict.open", locale: locale, in: window)
        try await SettingsButtonTestSupport.click(button, in: window)
        #expect(opened == [comparison.taskID])
        try SettingsButtonTestSupport.snapshot(window, name: "conflict-\(locale)-\(scheme)")
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func loginApprovalButtonKeepsConditionalPresentation(locale: String, scheme: ColorScheme) async throws {
        let f = try SettingsButtonTestSupport()
        defer { f.cleanup() }
        for approval in [false, true] {
            let window = f.window(Form {
                GeneralSettingsSection(prefs: f.prefs, launchesAtLogin: .constant(false), loginNeedsApproval: approval,
                    statusMessage: "Synthetic login status · 合成登录状态", onUpdateLoginItem: { _ in })
            }.formStyle(.grouped), locale: locale, scheme: scheme)
            defer { SystemPageHost.release(window) }
            try await SystemPageHost.settle(window)
            if approval {
                let button = try SettingsButtonTestSupport.button("settings.login.openSystem", locale: locale, in: window)
                try await SettingsButtonTestSupport.reveal(button, in: window)
                let visible = try SettingsButtonTestSupport.button("settings.login.openSystem", locale: locale, in: window)
                try SettingsButtonTestSupport.assertBounds([visible], in: window)
                try SettingsButtonTestSupport.snapshot(window, name: "login-\(locale)-\(scheme)")
            } else {
                #expect(!SystemPageHost.identifiers(in: window).contains("settings.login.openSystem"))
            }
        }
    }
}
