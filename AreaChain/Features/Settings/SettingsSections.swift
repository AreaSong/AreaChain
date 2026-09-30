import AppKit
import SwiftUI
import SwiftData
import UserNotifications

// MARK: - General Settings Section

struct GeneralSettingsSection: View {
    @Bindable var prefs = AppPreferences.shared
    @Binding var launchesAtLogin: Bool
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
    }
}

// MARK: - Sync Settings Section

struct SyncSettingsSection: View {
    @Bindable var prefs = AppPreferences.shared
    @Binding var notifyStatus: UNAuthorizationStatus
    var notifyStatusText: String
    var calendarSyncStatusText: String?
    var onRequestNotifyAuth: () -> Void
    @Query private var todos: [TodoItem]
    @Bindable private var calendarStatus = CalendarSyncStatus.shared

    private func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
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
                ForEach(todos.filter { calendarStatus.conflictTaskIDs.contains($0.id) }) { todo in
                    Button(todo.title) {
                        AppWindows.openWorkspace(tab: .calendar, inspecting: todo.id, dayKey: todo.dayKey)
                    }
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
