import AppKit
import ServiceManagement
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    var resignsChromeOnDisappear: Bool = true
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query private var checks: [RoutineCheck]
    @Query private var todos: [TodoItem]
    @Query private var diaries: [DiaryEntry]
    @Query private var projects: [ProjectItem]
    @Query private var tags: [TagItem]
    @Query private var attachments: [AttachmentItem]
    @Environment(AppPreferences.self) private var prefs
    @Environment(\.locale) private var locale

    @State private var launchesAtLogin = SMAppService.mainApp.status == .enabled
    @State private var statusMessage: String?
    @State private var pendingImport: ExportSnapshot?
    @State private var pendingPreview: ImportPreview?
    @State private var confirmReset = false
    @State private var notifyStatus: UNAuthorizationStatus = .notDetermined
    @Bindable private var syncStatus = CalendarSyncStatus.shared

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        @Bindable var prefs = prefs
        Form {
            ResidentSettings()
            CatalogSettings()

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
                        updateLoginItem(enabled)
                    }
                ))
                HotKeyRecorder()
                HotKeyRecorder(slot: .paste, title: "hotkey.paste", help: "hotkey.paste.help")
            }

            Section("settings.capture") {
                Toggle("settings.capture.stamp", isOn: $prefs.stampCaptureApp)
                Text("settings.capture.stamp.help")
                    .font(.system(size: 12))
                    .foregroundStyle(DaybookTheme.muted)
                Text("settings.capture.screen.help")
                    .font(.system(size: 12))
                    .foregroundStyle(DaybookTheme.muted)
            }

            Section("settings.notify") {
                Text(notifyStatusText)
                    .font(.system(size: 12))
                    .foregroundStyle(DaybookTheme.muted)
                Button("settings.notify.request") {
                    Task {
                        await NotificationScheduler.shared.requestAuthorizationAndRefresh()
                        notifyStatus = await NotificationScheduler.shared.currentStatus()
                    }
                }
            }

            Section("settings.calendar.sync") {
                Toggle("settings.calendar.sync.toggle", isOn: $prefs.syncCalendarEvents)
                if let calendarSyncStatusText {
                    Text(calendarSyncStatusText)
                        .font(.system(size: 12))
                        .foregroundStyle(DaybookTheme.muted)
                }
                Text("settings.calendar.sync.help")
                    .font(.system(size: 12))
                    .foregroundStyle(DaybookTheme.muted)
            }

            Section("settings.icloud") {
                Toggle("settings.icloud.toggle", isOn: $prefs.wantsICloudSync)
                Text("settings.icloud.hint")
                    .font(.system(size: 12))
                    .foregroundStyle(DaybookTheme.muted)
            }

            Section("settings.data") {
                Button("settings.export") { exportJSON() }
                Button("settings.import") { importJSON() }
                if StoreHealth.shared.isUsingMemoryFallback {
                    Text("settings.memory")
                        .font(.system(size: 12))
                        .foregroundStyle(DaybookTheme.destructive)
                    Button("settings.reset", role: .destructive) {
                        confirmReset = true
                    }
                }
                if let statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(DaybookTheme.ink)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 560)
        .navigationTitle("AreaChain")
        .alert("alert.import", isPresented: Binding(
            get: { pendingPreview != nil },
            set: { if !$0 { pendingImport = nil; pendingPreview = nil } }
        )) {
            Button("alert.cancel", role: .cancel) {
                pendingImport = nil
                pendingPreview = nil
            }
            Button("alert.write") { confirmImport() }
        } message: {
            Text(pendingPreview?.summary(locale: locale) ?? "")
        }
        .confirmationDialog("alert.reset", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("alert.reset.quit", role: .destructive) { resetStoreAndQuit() }
            Button("alert.cancel", role: .cancel) {}
        }
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
        } catch {
            statusMessage = error.localizedDescription
            launchesAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func exportJSON() {
        do {
            let data = try SyncPort.encode(
                SyncPort.makeSnapshot(
                    routines: routines,
                    checks: checks,
                    todos: todos,
                    diaries: diaries,
                    projects: projects,
                    tags: tags,
                    attachments: attachments
                )
            )
            presentSavePanel(data: data)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func importJSON() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let snapshot = try SyncPort.decode(try Data(contentsOf: url))
                pendingPreview = ImportPreviewing.preview(snapshot, existing: currentIDs())
                pendingImport = snapshot
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    private func currentIDs() -> ExistingIDs {
        ExistingIDs(
            routines: Set(routines.map(\.id)),
            todos: Set(todos.map(\.id)),
            diaries: Set(diaries.map(\.id)),
            checks: Set(checks.map(\.id))
        )
    }

    private func confirmImport() {
        guard let snapshot = pendingImport else { return }
        do {
            try SnapshotImporter.apply(snapshot, context: modelContext)
            statusMessage = L10n.string("settings.imported", locale: locale)
            BoardEvents.changed()
        } catch {
            statusMessage = error.localizedDescription
        }
        pendingImport = nil
        pendingPreview = nil
    }

    private func resetStoreAndQuit() {
        Persistence.resetStoreOnDisk()
        NSApplication.shared.terminate(nil)
    }

    private func presentSavePanel(data: Data) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "areachain-\(DayKey.today()).json"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url)
                statusMessage = L10n.string("settings.exported", locale: locale)
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }
}
