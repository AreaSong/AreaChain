import AppKit
import ServiceManagement
import SwiftUI
import UserNotifications

struct SettingsView: View {
    var resignsChromeOnDisappear: Bool = true
    @Environment(AppPreferences.self) private var prefs
    @Environment(\.locale) private var locale

    @State private var launchesAtLogin = SMAppService.mainApp.status == .enabled
    @State private var statusMessage: String?
    @State private var notifyStatus: UNAuthorizationStatus = .notDetermined
    @State private var markers: Set<String> = []
    @Bindable private var syncStatus = CalendarSyncStatus.shared

    var body: some View {
        DaybookPage(title: "window.settings", minWidth: 420, minHeight: 560) {
            settingsForm
        }
        .navigationTitle("AreaChain")
        .accessibilityIdentifier("settings.preferences")
        .accessibilityValue(markers.sorted().joined(separator: " "))
        .onAppear {
            Task { notifyStatus = await NotificationScheduler.shared.currentStatus() }
        }
        .onDisappear {
            guard resignsChromeOnDisappear else { return }
            AppWindows.resignIfIdle()
            DispatchQueue.main.async {
                AppWindows.resignIfIdle()
            }
        }
    }

    private var settingsForm: some View {
        Form {
            GeneralSettingsSection(
                prefs: prefs,
                launchesAtLogin: $launchesAtLogin,
                statusMessage: statusMessage,
                onUpdateLoginItem: updateLoginItem
            )
            SyncSettingsSection(
                prefs: prefs,
                notifyStatus: $notifyStatus,
                notifyStatusText: notifyStatusText,
                calendarSyncStatusText: calendarSyncStatusText,
                onRequestNotifyAuth: requestNotificationAuth
            )
        }
        .formStyle(.grouped)
        .daybookScroll()
        .systemPageMarkers($markers)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func requestNotificationAuth() {
        Task {
            await NotificationScheduler.shared.requestAuthorizationAndRefresh()
            notifyStatus = await NotificationScheduler.shared.currentStatus()
        }
    }

    private var notifyStatusText: String {
        switch notifyStatus {
        case .authorized, .provisional, .ephemeral:
            return L10n.string("settings.notify.status.on", locale: locale)
        case .denied:
            return L10n.string("settings.notify.status.denied", locale: locale)
        default:
            return L10n.string("settings.notify.status.off", locale: locale)
        }
    }

    private var calendarSyncStatusText: String? {
        guard prefs.syncCalendarEvents else { return nil }
        switch syncStatus.phase {
        case .off:
            return nil
        case .synced:
            let stamp = syncStatus.lastSyncedAt.map { ClockLabel.created($0, locale: locale) }
            let head = L10n.string("settings.calendar.sync.status.ok", locale: locale)
            if let stamp {
                return head + " · " + stamp
            }
            return head
        default:
            return L10n.string(
                String.LocalizationValue(stringLiteral: syncStatus.phase.messageKey),
                locale: locale
            )
        }
    }

    private func updateLoginItem(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            statusMessage = nil
        } catch {
            statusMessage = error.localizedDescription
            launchesAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
