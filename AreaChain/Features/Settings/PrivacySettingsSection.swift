import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct PrivacySettingsSection: View {
    private enum Dialog: String, Identifiable {
        case setup, tags, master, disableSystem
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
            vaultStateRow
            if vault.state == .unavailable {
                Text(LocalizedStringKey(vault.issue?.messageKey ?? "privacy.error.storageFailure"))
                    .foregroundStyle(DaybookPalette.status.danger)
            } else if !vault.isConfigured {
                unconfiguredControls
            } else {
                configuredControls
            }
            cleanupNotices
            if let statusKey {
                Text(LocalizedStringKey(statusKey)).font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
            }
            systemKeyCleanupRow
            if busy { ProgressView().controlSize(.small) }
        }
        .disabled(busy || StoreHealth.shared.isUsingMemoryFallback)
        .sheet(item: $dialog) { item in
            Group {
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
            .environment(\.locale, locale)
        }
        .task {
            if PrivacyStoreMaintenance.isPending(context) && !attachments.contains(where: { $0.retiredStorageID != nil }) {
                _ = PrivacyStoreMaintenance.performOnlineCleanupIfPossible(for: context)
            }
        }
    }

    private var vaultStateRow: some View {
        let status = VaultStatusPresentation.current(vault)
        return VStack(alignment: .leading, spacing: 6) {
            Label(status.title, systemImage: status.symbol)
                .foregroundStyle(DaybookPalette.text.primary)
                .accessibilityIdentifier("privacy.vault.state")
                .systemPageMarker("privacy.vault.state")
                .accessibilityLabel(Text(status.title))
            if vault.hasPendingSystemKeyCleanup {
                Label("privacy.state.cleanupPending", systemImage: "key.slash")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.primary)
                    .accessibilityIdentifier("privacy.vault.cleanup")
                    .systemPageMarker("privacy.vault.cleanup")
            }
        }
    }

    @ViewBuilder
    private var unconfiguredControls: some View {
        Text("privacy.settings.intro").font(DaybookType.caption).foregroundStyle(DaybookPalette.text.secondary)
        if diaries.contains(where: \.hasProtectedContent) || attachments.contains(where: { $0.privacyVaultID != nil }) {
            Text("privacy.missing.config").foregroundStyle(DaybookPalette.status.danger)
        } else {
            Button("privacy.setup") { dialog = .setup }
                .accessibilityIdentifier("privacy.setup")
                .systemPageMarker("privacy.setup")
        }
    }

    @ViewBuilder
    private var cleanupNotices: some View {
        if attachments.contains(where: { $0.retiredStorageID != nil }) {
            VStack(alignment: .leading, spacing: 6) {
                Text("privacy.cleanup.pending").font(DaybookType.caption).foregroundStyle(DaybookPalette.status.danger)
                Button("privacy.cleanup.retry") { retryCleanup() }
                    .accessibilityIdentifier("privacy.cleanup.retry")
                    .systemPageMarker("privacy.cleanup.retry")
            }
        } else if PrivacyStoreMaintenance.isPending(context) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "checkmark.shield")
                        .font(DaybookType.caption.weight(.semibold))
                        .foregroundStyle(DaybookPalette.accent.base)
                    Text("privacy.cleanup.database")
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.secondary)
                }
                HStack(spacing: 8) {
                    Button("privacy.cleanup.now") { retryCleanup() }
                        .accessibilityIdentifier("privacy.cleanup.now")
                        .systemPageMarker("privacy.cleanup.now")
                        .buttonStyle(.bordered)
                    Button("privacy.cleanup.quit") { NSApp.terminate(nil) }
                }
            }
        }
    }

    @ViewBuilder
    private var systemKeyCleanupRow: some View {
        if vault.hasPendingSystemKeyCleanup {
            Text("privacy.error.systemCleanupPending").font(DaybookType.caption).foregroundStyle(DaybookPalette.status.danger)
            Button("privacy.system.cleanup.retry") {
                run {
                    if vault.isConfigured { try await authenticate() }
                    try await vault.retrySystemKeyCleanup()
                }
            }
            .accessibilityIdentifier("privacy.system.cleanup.retry")
            .systemPageMarker("privacy.system.cleanup.retry")
        }
    }

    private var configuredControls: some View {
        Group {
            HStack {
                Button("privacy.tags.manage") { dialog = .tags }
                    .accessibilityIdentifier("privacy.tags.manage")
                    .systemPageMarker("privacy.tags.manage")
                Spacer()
                Button(vault.isUnlocked ? "privacy.lock.now" : "privacy.unlock.title") {
                    if vault.isUnlocked { vault.lock() }
                    else { run { try await authenticate() } }
                }
                .accessibilityIdentifier("privacy.lock.toggle")
                .systemPageMarker("privacy.lock.toggle")
            }
            Text(L10n.format("privacy.tags.count", locale: locale, tags.filter(\.isPrivateDiary).count))
                .font(DaybookType.caption).foregroundStyle(DaybookPalette.text.secondary)
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
            .accessibilityIdentifier("privacy.autolock")
            .systemPageMarker("privacy.autolock")
            Text("privacy.methods.help").font(DaybookType.caption).foregroundStyle(DaybookPalette.text.secondary)
        }
    }

    private func passwordSheet(_ item: Dialog) -> some View {
        PrivacyPasswordSheet(
            title: "privacy.master.label",
            confirmation: item == .master,
            explanation: "privacy.master.help",
            action: { password in try await perform(item, password: password) },
            onComplete: { dialog = nil; statusKey = "privacy.settings.saved" })
    }

    private func perform(_ item: Dialog, password: String) async throws {
        switch item {
        case .master:
            try await authenticate()
            try await vault.changePassword(to: password)
        case .disableSystem:
            try await vault.disableSystemUnlock(masterPassword: password)
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
            if PrivacyStoreMaintenance.isPending(context) {
                _ = PrivacyStoreMaintenance.performOnlineCleanupIfPossible(for: context)
            }
            vault.changed()
        }
    }
}

private struct VaultStatusPresentation {
    var title: LocalizedStringKey
    var symbol: String

    @MainActor
    static func current(_ vault: PrivacyVault) -> Self {
        switch vault.state {
        case .unconfigured: return Self(title: "privacy.state.unconfigured", symbol: "lock.slash")
        case .locked: return Self(title: "privacy.state.locked", symbol: "lock")
        case .unlocked: return Self(title: "privacy.state.unlocked", symbol: "lock.open")
        case .unavailable: return Self(title: "privacy.state.unavailable", symbol: "exclamationmark.triangle")
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
