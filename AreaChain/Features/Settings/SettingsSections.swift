import AppKit
import SwiftUI
import UserNotifications

// MARK: - General Settings Section

struct GeneralSettingsSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var prefs = AppPreferences.shared
    @Binding var launchesAtLogin: Bool
    var loginNeedsApproval: Bool
    var statusMessage: String?
    var onUpdateLoginItem: (Bool) -> Void

    var body: some View {
        Section("settings.chrome") {
            DaybookPicker("settings.language", selection: $prefs.language, options: [
                DaybookPickerOption(.system, "language.system"),
                DaybookPickerOption(.chinese, "language.chinese"),
                DaybookPickerOption(.english, "language.english")
            ], layout: .formRow)
            .accessibilityIdentifier("settings.language")
            .systemPageMarker("settings.language")
            DaybookPicker("settings.look", selection: $prefs.appearance, options: [
                DaybookPickerOption(.system, "appearance.system"),
                DaybookPickerOption(.light, "appearance.light"),
                DaybookPickerOption(.dark, "appearance.dark")
            ], layout: .formRow)
            .accessibilityIdentifier("settings.look")
            .systemPageMarker("settings.look")
            Button("controls.preview.title") {
                AppWindows.openControlsPreview(localeID: prefs.resolvedLocale.identifier,
                    dark: (prefs.resolvedColorScheme ?? colorScheme) == .dark)
            }
            .buttonStyle(DaybookButtonStyle(.quiet))
            .accessibilityIdentifier("settings.controlsPreview")
            .systemPageMarker("settings.controlsPreview")
            DaybookPicker("settings.quadrant.truncation", selection: $prefs.quadrantTitleTruncation, options: [
                DaybookPickerOption(.tail, "settings.quadrant.truncation.tail"),
                DaybookPickerOption(.middle, "settings.quadrant.truncation.middle")
            ], layout: .formRow)
            .accessibilityIdentifier("settings.quadrant.truncation")
            .systemPageMarker("settings.quadrant.truncation")
            Text("settings.quadrant.truncation.help")
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookPalette.text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        Section("settings.launch") {
            Toggle(isOn: Binding(
                get: { launchesAtLogin },
                set: { enabled in
                    launchesAtLogin = enabled
                    onUpdateLoginItem(enabled)
                }
            )) {
                Text("settings.login")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toggleStyle(DaybookToggleStyle(.switchControl))
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
            Toggle(isOn: $prefs.stampCaptureApp) {
                Text("settings.capture.stamp")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toggleStyle(DaybookToggleStyle(.switchControl))
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
                .buttonStyle(DaybookButtonStyle(.quiet))
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
    @Environment(\.locale) private var locale
    @State private var notifyTestMessage: String?
    @State private var isSendingNotifyTest = false
    @Bindable private var calendarStatus = CalendarSyncStatus.shared

    private func openNotificationSettings() {
        SystemSettingsLinks.open("x-apple.systempreferences:com.apple.Notifications-Settings.extension")
    }

    private func sendTestNotification() {
        guard !isSendingNotifyTest else { return }
        isSendingNotifyTest = true
        let title = L10n.string("notify.test.title", locale: locale)
        let body = L10n.string("notify.test.body", locale: locale)
        Task {
            let outcome = await NotificationScheduler.shared.deliverTestBanner(title: title, body: body)
            notifyStatus = await NotificationScheduler.shared.currentStatus()
            isSendingNotifyTest = false
            notifyTestMessage = message(for: outcome)
        }
    }

    private func message(for outcome: NotificationTestOutcome) -> String? {
        switch outcome {
        case .delivered:
            return L10n.string("settings.notify.test.sent", locale: locale)
        case .failed:
            return L10n.string("settings.notify.test.failed", locale: locale)
        case .notAuthorized:
            return nil
        }
    }

    var body: some View {
        Section("settings.notify") {
            Text(notifyStatusText)
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookPalette.text.secondary)
            if notifyStatus == .denied {
                Button("settings.notify.openSystem", action: openNotificationSettings)
                    .buttonStyle(DaybookButtonStyle(.quiet))
                    .accessibilityIdentifier("settings.notify.openSystem")
                    .systemPageMarker("settings.notify.openSystem")
            } else {
                Button("settings.notify.request", action: onRequestNotifyAuth)
                    .buttonStyle(DaybookButtonStyle(.prominent))
                    .accessibilityIdentifier("settings.notify")
                    .systemPageMarker("settings.notify")
                Button("settings.notify.test", action: sendTestNotification)
                    .buttonStyle(DaybookButtonStyle(.quiet))
                    .disabled(isSendingNotifyTest)
                    .accessibilityIdentifier("settings.notify.test")
                    .systemPageMarker("settings.notify.test")
            }
            if let notifyTestMessage {
                Text(notifyTestMessage)
                    .font(DaybookType.subtitle)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.notify.test.message")
            }
        }

        Section("settings.calendar.sync") {
            Toggle(isOn: $prefs.syncCalendarEvents) {
                Text("settings.calendar.sync.toggle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toggleStyle(DaybookToggleStyle(.switchControl))
            .accessibilityIdentifier("settings.calendar.sync")
            .systemPageMarker("settings.calendar.sync")
            if let calendarSyncStatusText {
                Text(calendarSyncStatusText)
                    .font(DaybookType.subtitle)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
            if prefs.syncCalendarEvents {
                Button("settings.calendar.sync.retry") { CalendarSync.refreshIfEnabled() }
                    .buttonStyle(DaybookButtonStyle(.quiet))
                if calendarStatus.phase == .denied {
                    Button("settings.calendar.openSystem") {
                        SystemSettingsLinks.open(
                            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Calendars"
                        )
                    }
                    .buttonStyle(DaybookButtonStyle(.quiet))
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
                    .buttonStyle(DaybookButtonStyle(.quiet))
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
