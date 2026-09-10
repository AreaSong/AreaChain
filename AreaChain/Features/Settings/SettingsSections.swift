import SwiftUI
import UserNotifications

// MARK: - General Settings Section

struct GeneralSettingsSection: View {
    @Bindable var prefs = AppPreferences.shared
    @Binding var launchesAtLogin: Bool
    var onUpdateLoginItem: (Bool) -> Void

    var body: some View {
        Section("settings.chrome") {
            Picker("settings.language", selection: $prefs.language) {
                Text("language.system").tag(AppLanguage.system)
                Text("language.chinese").tag(AppLanguage.chinese)
                Text("language.english").tag(AppLanguage.english)
            }
            Picker("settings.look", selection: $prefs.appearance) {
                Text("appearance.system").tag(AppAppearance.system)
                Text("appearance.light").tag(AppAppearance.light)
                Text("appearance.dark").tag(AppAppearance.dark)
            }
        }

        Section("settings.launch") {
            Toggle("settings.login", isOn: Binding(
                get: { launchesAtLogin },
                set: { enabled in
                    launchesAtLogin = enabled
                    onUpdateLoginItem(enabled)
                }
            ))
            HotKeyRecorder()
            HotKeyRecorder(slot: .paste, title: "hotkey.paste", help: "hotkey.paste.help")
        }

        Section("settings.capture") {
            Toggle("settings.capture.stamp", isOn: $prefs.stampCaptureApp)
            Text("settings.capture.stamp.help")
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookTheme.muted)
            Text("settings.capture.screen.help")
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookTheme.muted)
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

    var body: some View {
        Section("settings.notify") {
            Text(notifyStatusText)
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookTheme.muted)
            Button("settings.notify.request", action: onRequestNotifyAuth)
        }

        Section("settings.calendar.sync") {
            Toggle("settings.calendar.sync.toggle", isOn: $prefs.syncCalendarEvents)
            if let calendarSyncStatusText {
                Text(calendarSyncStatusText)
                    .font(DaybookType.subtitle)
                    .foregroundStyle(DaybookTheme.muted)
            }
            Text("settings.calendar.sync.help")
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookTheme.muted)
        }

        Section("settings.icloud") {
            Toggle("settings.icloud.toggle", isOn: $prefs.wantsICloudSync)
            Text("settings.icloud.hint")
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookTheme.muted)
        }
    }
}

// MARK: - Advanced Settings Section

struct AdvancedSettingsSection: View {
    @Binding var confirmReset: Bool
    var statusMessage: String?
    var onExport: () -> Void
    var onImport: () -> Void

    var body: some View {
        Section("settings.data") {
            Button("settings.export", action: onExport)
            Button("settings.import", action: onImport)
            if StoreHealth.shared.isUsingMemoryFallback {
                Text("settings.memory")
                    .font(DaybookType.subtitle)
                    .foregroundStyle(DaybookTheme.destructive)
                Button("settings.reset", role: .destructive) {
                    confirmReset = true
                }
            }
            if let statusMessage {
                Text(statusMessage)
                    .font(DaybookType.subtitle)
                    .foregroundStyle(DaybookTheme.ink)
                    .textSelection(.enabled)
            }
        }
    }
}
