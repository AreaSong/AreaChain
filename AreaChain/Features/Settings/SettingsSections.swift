import AppKit
import SwiftUI
import UserNotifications

// MARK: - General Settings Section

struct GeneralSettingsSection: View {
    @Bindable var prefs = AppPreferences.shared
    @Binding var launchesAtLogin: Bool
    var loginNeedsApproval: Bool
    var statusMessage: String?
    var onUpdateLoginItem: (Bool) -> Void

    var body: some View {
        Section("settings.chrome") {
            Picker("settings.language", selection: $prefs.language) {
                Text("language.system").tag(AppLanguage.system)
                Text("language.chinese").tag(AppLanguage.chinese)
                Text("language.english").tag(AppLanguage.english)
            }
            .accessibilityIdentifier("settings.language")
            .systemPageMarker("settings.language")
            Picker("settings.look", selection: $prefs.appearance) {
                Text("appearance.system").tag(AppAppearance.system)
                Text("appearance.light").tag(AppAppearance.light)
                Text("appearance.dark").tag(AppAppearance.dark)
            }
            .accessibilityIdentifier("settings.look")
            .systemPageMarker("settings.look")
            Picker("settings.quadrant.truncation", selection: $prefs.quadrantTitleTruncation) {
                Text("settings.quadrant.truncation.tail").tag(QuadrantTitleTruncation.tail)
                Text("settings.quadrant.truncation.middle").tag(QuadrantTitleTruncation.middle)
            }
            .accessibilityIdentifier("settings.quadrant.truncation")
            .systemPageMarker("settings.quadrant.truncation")
            Text("settings.quadrant.truncation.help")
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookPalette.text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        Section("settings.launch") {
            Toggle("settings.login", isOn: Binding(
                get: { launchesAtLogin },
                set: { enabled in
                    launchesAtLogin = enabled
                    onUpdateLoginItem(enabled)
                }
            ))
            .accessibilityIdentifier("settings.login")
            .systemPageMarker("settings.login")
            if let statusMessage {
                Text(statusMessage)
                    .font(DaybookType.subtitle)
                    .foregroundStyle(DaybookPalette.text.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        Section("settings.capture") {
            Toggle("settings.capture.stamp", isOn: $prefs.stampCaptureApp)
                .accessibilityIdentifier("settings.capture")
                .systemPageMarker("settings.capture")
            Text("settings.capture.stamp.help")
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookPalette.text.secondary)
            Text("settings.capture.screen.help")
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookPalette.text.secondary)
        }

        if loginNeedsApproval {
            Section {
                Text("settings.login.needsApproval")
                    .font(DaybookType.subtitle)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.login.needsApproval")
                    .systemPageMarker("settings.login.needsApproval")
                Button("settings.login.openSystem") {
                    SystemSettingsLinks.open("x-apple.systempreferences:com.apple.LoginItems-Settings.extension")
                }
                .accessibilityIdentifier("settings.login.openSystem")
                .systemPageMarker("settings.login.openSystem")
            }
        }
    }
}

// MARK: - Sync Settings Section

struct SyncSettingsSection: View {
    @Bindable var prefs = AppPreferences.shared
    @Binding var notifyStatus: UNAuthorizationStatus
    var notifyStatusText: String
    var calendarSyncStatusText: String?
    var onRequestNotifyAuth: () -> Void
    @Bindable private var calendarStatus = CalendarSyncStatus.shared

    private func openNotificationSettings() {
        SystemSettingsLinks.open("x-apple.systempreferences:com.apple.Notifications-Settings.extension")
    }

    var body: some View {
        Section("settings.notify") {
            Text(notifyStatusText)
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookPalette.text.secondary)
            if notifyStatus == .denied {
                Button("settings.notify.openSystem", action: openNotificationSettings)
                    .accessibilityIdentifier("settings.notify.openSystem")
                    .systemPageMarker("settings.notify.openSystem")
            } else {
                Button("settings.notify.request", action: onRequestNotifyAuth)
                    .accessibilityIdentifier("settings.notify")
                    .systemPageMarker("settings.notify")
            }
        }

        Section("settings.calendar.sync") {
            Toggle("settings.calendar.sync.toggle", isOn: $prefs.syncCalendarEvents)
                .accessibilityIdentifier("settings.calendar.sync")
                .systemPageMarker("settings.calendar.sync")
            if let calendarSyncStatusText {
                Text(calendarSyncStatusText)
                    .font(DaybookType.subtitle)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
            if prefs.syncCalendarEvents {
                Button("settings.calendar.sync.retry") { CalendarSync.refreshIfEnabled() }
                if calendarStatus.phase == .denied {
                    Button("settings.calendar.openSystem") {
                        SystemSettingsLinks.open(
                            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Calendars"
                        )
                    }
                    .accessibilityIdentifier("settings.calendar.openSystem")
                    .systemPageMarker("settings.calendar.openSystem")
                }
                CalendarConflictList(comparisons: calendarStatus.conflictComparisons) { item in
                    AppWindows.openWorkspace(tab: .calendar, inspecting: item.taskID, dayKey: item.local.dayKey)
                }
            }
            Text("settings.calendar.sync.help")
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookPalette.text.secondary)
        }

        Section("settings.icloud") {
            Text("settings.icloud.hint")
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookPalette.text.secondary)
                .accessibilityIdentifier("settings.icloud")
                .systemPageMarker("settings.icloud")
        }
    }
}

enum SystemSettingsLinks {
    static func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}

struct CalendarConflictList: View {
    var comparisons: [CalendarConflictComparison]
    var onOpen: (CalendarConflictComparison) -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        ForEach(comparisons) { item in
            Section {
                Button("settings.calendar.conflict.open") { onOpen(item) }
                    .accessibilityIdentifier("settings.calendar.conflict.open")
                side(key: "settings.calendar.conflict.local", content: item.local)
                if let remote = item.remote {
                    side(key: "settings.calendar.conflict.remote", content: remote)
                } else {
                    labeledLine(
                        key: "settings.calendar.conflict.remote",
                        value: L10n.string("settings.calendar.conflict.missing", locale: locale)
                    )
                }
            }
            .systemPageMarker("settings.calendar.conflict")
        }
    }

    private func side(key: String, content: CalendarContent) -> some View {
        let time = content.remindMinutes.map { RemindMinutes.label($0, locale: locale) }
            ?? L10n.string("settings.calendar.conflict.noTime", locale: locale)
        let detail = content.title + " · " + DayKey.displayName(content.dayKey, locale: locale) + " · " + time
        return labeledLine(key: key, value: detail)
    }

    private func labeledLine(key: String, value: String) -> some View {
        let heading = L10n.string(String.LocalizationValue(stringLiteral: key), locale: locale)
        return Text(heading + " · " + value)
            .font(DaybookType.subtitle)
            .foregroundStyle(DaybookPalette.text.primary)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(key)
    }
}
