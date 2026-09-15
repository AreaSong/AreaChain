import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct PrivacySettingsSection: View {
    private enum Dialog: String, Identifiable {
        case setup, tags, master, disableSystem, export, restore
        var id: String { rawValue }
    }
    var vault: PrivacyVault
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @Query private var tags: [TagItem]
    @Query private var attachments: [AttachmentItem]
    @Query private var diaries: [DiaryEntry]
    @State private var dialog: Dialog?
    @State private var busy = false
    @State private var statusKey: String?

    init(vault: PrivacyVault? = nil) { self.vault = vault ?? .shared }

    var body: some View {
        Section("privacy.settings.title") {
            Label(!vault.isConfigured ? "privacy.state.unconfigured" : (vault.isUnlocked ? "privacy.state.unlocked" : "privacy.state.locked"),
                  systemImage: vault.isUnlocked ? "lock.open" : "lock.shield")
                .foregroundStyle(DaybookTheme.ink)
            if vault.state == .unavailable {
                Text(LocalizedStringKey(vault.issue?.messageKey ?? "privacy.error.storageFailure"))
                    .foregroundStyle(DaybookTheme.destructive)
            } else if !vault.isConfigured {
                Text("privacy.settings.intro").font(DaybookType.caption).foregroundStyle(DaybookTheme.muted)
                if diaries.contains(where: \.hasProtectedContent) || attachments.contains(where: { $0.privacyVaultID != nil }) {
                    Text("privacy.missing.config").foregroundStyle(DaybookTheme.destructive)
                } else {
                    Button("privacy.setup") { dialog = .setup }
                }
            } else {
                configuredControls
            }
            if PrivacyStoreMaintenance.isPending(context) || attachments.contains(where: { $0.retiredStorageID != nil }) {
                Text("privacy.cleanup.pending").font(DaybookType.caption).foregroundStyle(DaybookTheme.destructive)
                Button("privacy.cleanup.retry") { retryCleanup() }
                Button("privacy.cleanup.quit") { NSApp.terminate(nil) }
            }
            if let statusKey {
                Text(LocalizedStringKey(statusKey)).font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
            }
            if vault.hasPendingSystemKeyCleanup {
                Text("privacy.error.systemCleanupPending").font(DaybookType.caption).foregroundStyle(DaybookTheme.destructive)
                Button("privacy.system.cleanup.retry") {
                    run {
                        if vault.isConfigured { try await authenticate() }
                        try await vault.retrySystemKeyCleanup()
                    }
                }
            }
            if busy { ProgressView().controlSize(.small) }
        }
        .disabled(busy || StoreHealth.shared.isUsingMemoryFallback)
        .sheet(item: $dialog) { item in
            switch item {
            case .setup, .tags:
                PrivacySetupSheet(vault: vault, tags: tags, creating: item == .setup) {
                    dialog = nil
                    statusKey = "privacy.settings.saved"
                }
            default:
                passwordSheet(item)
            }
        }
    }

    private var configuredControls: some View {
        Group {
            HStack {
                Button("privacy.tags.manage") { dialog = .tags }
                Spacer()
                Button(vault.isUnlocked ? "privacy.lock.now" : "privacy.unlock.title") {
                    if vault.isUnlocked { vault.lock() }
                    else { run { try await authenticate() } }
                }
            }
            Text(L10n.format("privacy.tags.count", locale: locale, tags.filter(\.isPrivateDiary).count))
                .font(DaybookType.caption).foregroundStyle(DaybookTheme.muted)
            LabeledContent("privacy.methods.system", value: L10n.string(vault.hasSystemUnlock ? "privacy.enabled" : "privacy.disabled", locale: locale))
            Button(vault.hasSystemUnlock ? "privacy.system.disable" : "privacy.system.enable") {
                if vault.hasSystemUnlock { dialog = .disableSystem }
                else { run { try await authenticate(); try await vault.enableSystemUnlock() } }
            }
            .disabled(vault.hasSystemUnlock && !vault.hasMasterPassword)
            HStack {
                Button(vault.hasMasterPassword ? "privacy.master.change" : "privacy.master.set") { dialog = .master }
                if vault.hasMasterPassword {
                    Button("privacy.master.remove") {
                        run { try await vault.removePassword(reason: L10n.string("privacy.manage.reason", locale: locale)) }
                    }
                    .disabled(!vault.hasSystemUnlock)
                }
            }
            Picker("privacy.autolock", selection: Binding(get: { vault.idleSeconds }, set: { seconds in
                run { try await authenticate(); try vault.setIdleSeconds(seconds) }
            })) {
                Text("privacy.idle.1").tag(60)
                Text("privacy.idle.5").tag(300)
                Text("privacy.idle.15").tag(900)
            }
            Text("privacy.methods.help").font(DaybookType.caption).foregroundStyle(DaybookTheme.muted)
            HStack {
                Button("privacy.backup.export") { dialog = .export }
                Button("privacy.backup.restore") { dialog = .restore }
            }
        }
    }

    private func passwordSheet(_ item: Dialog) -> some View {
        let backup = item == .export || item == .restore
        return PrivacyPasswordSheet(
            title: backup ? "privacy.backup.password.title" : "privacy.master.label",
            confirmation: item == .master || item == .export,
            explanation: backup ? "privacy.backup.password.help" : "privacy.master.help",
            action: { password in try await perform(item, password: password) },
            onComplete: { dialog = nil; statusKey = "privacy.settings.saved" })
    }

    private func perform(_ item: Dialog, password: String) async throws {
        let environment = PrivacyPersistence(context: context, vault: vault)
        switch item {
        case .master:
            try await authenticate()
            try await vault.changePassword(to: password)
        case .disableSystem:
            try await vault.disableSystemUnlock(masterPassword: password)
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
        default:
            break
        }
    }

    private func authenticate() async throws {
        try await PrivacyUnlockPresenter.shared.request(reason: L10n.string("privacy.manage.reason", locale: locale),
                                                        force: true, vault: vault)
    }

    private func run(_ work: @escaping () async throws -> Void) {
        guard !busy else { return }
        busy = true
        statusKey = nil
        Task {
            defer { busy = false }
            do { try await work(); statusKey = "privacy.settings.saved" }
            catch { statusKey = (error as? PrivacyError ?? .storageFailure).messageKey }
        }
    }

    private func retryCleanup() {
        run {
            try await authenticate()
            try PrivacyAttachmentBatch.cleanup(attachments, context: context)
            vault.changed()
        }
    }
}

@MainActor
enum PrivacyFilePanels {
    static func save() async -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "AreaChain.areachainbackup"
        panel.allowedContentTypes = [UTType(filenameExtension: "areachainbackup") ?? .data]
        return await withCheckedContinuation { continuation in
            panel.begin { continuation.resume(returning: $0 == .OK ? panel.url : nil) }
        }
    }

    static func open() async -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "areachainbackup") ?? .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        return await withCheckedContinuation { continuation in
            panel.begin { continuation.resume(returning: $0 == .OK ? panel.url : nil) }
        }
    }

    static func confirmRestore(_ manifest: PrivateBackupManifest, locale: Locale) -> Bool {
        let alert = NSAlert()
        alert.messageText = L10n.string("privacy.restore.confirm", locale: locale)
        alert.informativeText = L10n.format("privacy.restore.summary", locale: locale,
                                          manifest.snapshot.diaries.count, manifest.snapshot.attachments.count)
        alert.addButton(withTitle: L10n.string("privacy.backup.restore", locale: locale))
        alert.addButton(withTitle: L10n.string("alert.cancel", locale: locale))
        alert.alertStyle = .warning
        return alert.runModal() == .alertFirstButtonReturn
    }
}
