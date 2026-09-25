import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// 工作台「数据与备份」：普通 JSON、独立口令加密备份、内存回退时的磁盘库重置。
struct DataBackupView: View {
    private enum Dialog: String, Identifiable {
        case export, restore
        var id: String { rawValue }
    }

    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query private var checks: [RoutineCheck]
    @Query private var todos: [TodoItem]
    @Query private var diaries: [DiaryEntry]
    @Query private var tags: [TagItem]
    @Query private var attachments: [AttachmentItem]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @State private var dialog: Dialog?
    @State private var statusMessage: String?
    @State private var pendingImport: ExportSnapshot?
    @State private var pendingPreview: ImportPreview?
    @State private var confirmReset = false
    @State private var markers: Set<String> = []

    private var usingMemoryFallback: Bool { StoreHealth.shared.isUsingMemoryFallback }

    var body: some View {
        DaybookPage(title: "tab.dataBackup", systemImage: "externaldrive", minWidth: 420, minHeight: 560) {
            backupForm
        }
        .accessibilityIdentifier("data.backup.page")
        .accessibilityValue(markers.sorted().joined(separator: " "))
        .alert("alert.import", isPresented: importPresented) {
            Button("alert.cancel", role: .cancel) { clearImport() }
            Button("alert.write") { confirmImport() }
        } message: {
            Text(pendingPreview?.summary(locale: locale) ?? "")
        }
        .confirmationDialog("alert.reset", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("alert.reset.quit", role: .destructive) { resetStoreAndQuit() }
            Button("alert.cancel", role: .cancel) {}
        }
        .sheet(item: $dialog) { item in
            passwordSheet(item).environment(\.locale, locale)
        }
    }

    private var importPresented: Binding<Bool> {
        Binding(get: { pendingPreview != nil }, set: { if !$0 { clearImport() } })
    }

    private var backupForm: some View {
        Form {
            jsonSection
            encryptedSection
            healthSection
            if let statusMessage { statusRow(statusMessage) }
        }
        .formStyle(.grouped)
        .daybookScroll()
        .systemPageMarkers($markers)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var jsonSection: some View {
        Section("dataBackup.json") {
            Text("dataBackup.json.help")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("settings.export", action: exportJSON)
                .accessibilityIdentifier("dataBackup.export.json")
                .systemPageMarker("dataBackup.export.json")
            Button("settings.import", action: importJSON)
                .accessibilityIdentifier("dataBackup.import.json")
                .systemPageMarker("dataBackup.import.json")
        }
    }

    private var encryptedSection: some View {
        Section("dataBackup.encrypted") {
            Text("dataBackup.encrypted.help")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("privacy.backup.export") { dialog = .export }
                .accessibilityIdentifier("dataBackup.export.encrypted")
                .systemPageMarker("dataBackup.export.encrypted")
            Button("privacy.backup.restore") { dialog = .restore }
                .accessibilityIdentifier("dataBackup.restore.encrypted")
                .systemPageMarker("dataBackup.restore.encrypted")
        }
        .disabled(dialog != nil)
    }

    @ViewBuilder
    private var healthSection: some View {
        Section("dataBackup.health") {
            if usingMemoryFallback {
                Label("settings.memory", systemImage: "exclamationmark.triangle")
                    .font(DaybookType.subtitle)
                    .foregroundStyle(DaybookPalette.status.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("dataBackup.health.warning")
                    .systemPageMarker("dataBackup.health.warning")
                Button("settings.reset", role: .destructive) { confirmReset = true }
                    .accessibilityIdentifier("dataBackup.reset")
                    .systemPageMarker("dataBackup.reset")
            } else {
                Label("dataBackup.health.ok", systemImage: "checkmark.circle")
                    .font(DaybookType.subtitle)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .accessibilityIdentifier("dataBackup.health.ok")
                    .systemPageMarker("dataBackup.health.ok")
            }
        }
    }

    private func statusRow(_ message: String) -> some View {
        Section {
            Text(message)
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookPalette.text.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func exportJSON() {
        do {
            let data = try SyncPort.encode(SyncPort.makeSnapshot(
                routines: routines, checks: checks, todos: todos,
                diaries: diaries, tags: tags, attachments: attachments
            ))
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
            loadImport(from: url)
        }
    }

    private func loadImport(from url: URL) {
        do {
            let snapshot = try SyncPort.decode(try Data(contentsOf: url))
            try SnapshotImporter.validate(snapshot, context: modelContext)
            pendingPreview = ImportPreviewing.preview(snapshot, existing: currentIDs())
            pendingImport = snapshot
        } catch {
            statusMessage = importErrorMessage(error)
        }
    }

    private func confirmImport() {
        guard let snapshot = pendingImport else { return }
        do {
            try SnapshotImporter.apply(snapshot, context: modelContext)
            statusMessage = L10n.string("settings.imported", locale: locale)
            BoardEvents.changed()
        } catch {
            statusMessage = importErrorMessage(error)
        }
        clearImport()
    }

    private func presentSavePanel(data: Data) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "areachain-\(DayKey.today()).json"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            writeExport(data, to: url)
        }
    }

    private func writeExport(_ data: Data, to url: URL) {
        do {
            try data.write(to: url)
            statusMessage = L10n.string("settings.exported", locale: locale)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func currentIDs() -> ExistingIDs {
        ExistingIDs(
            routines: Set(routines.map(\.id)),
            todos: Set(todos.map(\.id)),
            diaries: Set(diaries.map(\.id)),
            checks: Set(checks.map(\.id)),
            tags: Set(tags.map(\.id)),
            attachments: Set(attachments.map(\.id))
        )
    }

    private func importErrorMessage(_ error: Error) -> String {
        (error as? SnapshotImportError)?.message(locale: locale) ?? error.localizedDescription
    }

    private func clearImport() {
        pendingImport = nil
        pendingPreview = nil
    }

    private func resetStoreAndQuit() {
        Persistence.resetStoreOnDisk()
        NSApplication.shared.terminate(nil)
    }

    private func passwordSheet(_ item: Dialog) -> some View {
        PrivacyPasswordSheet(
            title: "privacy.backup.password.title",
            confirmation: item == .export,
            explanation: "privacy.backup.password.help",
            action: { password in try await perform(item, password: password) },
            onComplete: {
                let finished = dialog
                dialog = nil
                switch finished {
                case .export:
                    statusMessage = L10n.string("dataBackup.encrypted.exported", locale: locale)
                case .restore:
                    statusMessage = L10n.string("dataBackup.encrypted.restored", locale: locale)
                case nil:
                    break
                }
            }
        )
    }

    private func perform(_ item: Dialog, password: String) async throws {
        let environment = PrivacyPersistence(context: modelContext, vault: .shared)
        switch item {
        case .export:
            guard let url = await PrivacyFilePanels.save() else { throw PrivacyError.cancelled }
            try await authenticate()
            _ = try await PrivateBackupService.export(to: url, password: password, environment: environment)
        case .restore:
            guard let url = await PrivacyFilePanels.open() else { throw PrivacyError.cancelled }
            let preview = try await PrivateBackupService.inspect(url: url, password: password)
            guard PrivacyFilePanels.confirmRestore(preview, locale: locale) else { throw PrivacyError.cancelled }
            try await authenticate()
            try await PrivateBackupService.restore(from: url, password: password, environment: environment)
        }
    }

    private func authenticate() async throws {
        try await PrivacyUnlockPresenter.shared.request(
            reason: L10n.string("privacy.manage.reason", locale: locale),
            force: true, vault: .shared
        )
    }
}
