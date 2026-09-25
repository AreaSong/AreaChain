import Security
import SwiftData
import SwiftUI

struct PrivacySetupSheet: View {
    var vault: PrivacyVault
    var tags: [TagItem]
    var creating: Bool
    var onComplete: () -> Void
    var probeSystem = true
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<UUID> = []
    @State private var useSystem = true
    @State private var useMaster = false
    @State private var master = ""
    @State private var repeated = ""
    @State private var backupPassword = ""
    @State private var backupRepeated = ""
    @State private var includeLegacy = true
    @State private var busy = false
    @State private var errorKey: String?
    @State private var systemAvailable = true
    @State private var markers: Set<String> = []

    private var count: Int {
        (try? DiaryProtection.candidates(tagIDs: selected, context: context, includeLegacy: includeLegacy).count) ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(creating ? "privacy.setup" : "privacy.tags.manage", systemImage: "lock.shield")
                .font(DaybookType.title)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if creating && !vault.isConfigured { methods }
                    Text("privacy.tags.help").font(DaybookType.body).foregroundStyle(DaybookPalette.text.secondary)
                    tagChoices
                    Toggle("privacy.legacy.include", isOn: $includeLegacy)
                    Text(L10n.format("privacy.migration.count", locale: locale, count))
                        .font(DaybookType.caption).foregroundStyle(DaybookPalette.text.secondary)
                    if count > 0 { backupFields }
                    if let errorKey {
                        Text(LocalizedStringKey(errorKey)).font(DaybookType.caption)
                            .foregroundStyle(DaybookPalette.status.danger).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .daybookScroll()
            .disabled(busy)
            .frame(maxHeight: 430)
            HStack {
                if busy { ProgressView().controlSize(.small) }
                Spacer()
                Button("alert.cancel") { clearPasswords(); dismiss() }.disabled(busy).keyboardShortcut(.cancelAction)
                Button("privacy.apply", action: submit).buttonStyle(.borderedProminent).disabled(busy || !valid)
            }
        }
        .textFieldStyle(.roundedBorder).padding(24).frame(width: 480)
        .systemPageMarkers($markers)
        .accessibilityIdentifier("privacy.setup.sheet")
        .accessibilityValue(markers.sorted().joined(separator: " "))
        .interactiveDismissDisabled(busy)
        .task {
            selected = Set(tags.filter { $0.isPrivateDiary || (creating && DiaryMemoTags.isPasswordName($0.name)) }.map(\.id))
            includeLegacy = creating
            if creating && probeSystem {
                let status = await Task.detached { SystemVaultKeyStore().availabilityStatus() }.value
                systemAvailable = status == errSecItemNotFound || status == errSecSuccess
                if !systemAvailable { useSystem = false; useMaster = true }
            }
        }
        .onDisappear(perform: clearPasswords)
    }

    private var methods: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("privacy.methods.system", isOn: $useSystem).disabled(!systemAvailable)
            if !systemAvailable {
                Text("privacy.system.signing").font(DaybookType.caption).foregroundStyle(DaybookPalette.status.danger)
            }
            Toggle("privacy.methods.master", isOn: $useMaster)
            if useSystem && !useMaster {
                Text("privacy.system.only.warning").font(DaybookType.caption).foregroundStyle(DaybookPalette.text.secondary)
            }
            if useMaster {
                SecureField("privacy.master.label", text: $master)
                SecureField("privacy.password.repeat", text: $repeated)
            }
            Text("privacy.methods.help").font(DaybookType.caption).foregroundStyle(DaybookPalette.text.secondary)
        }
    }

    private var tagChoices: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(tags.filter { $0.deletedAt == nil || $0.isPrivateDiary }.sorted { $0.sortOrder < $1.sortOrder }) { tag in
                Toggle(isOn: Binding(get: { selected.contains(tag.id) }, set: { enabled in
                    if enabled { selected.insert(tag.id) } else { selected.remove(tag.id) }
                })) {
                    Label(tag.name, systemImage: selected.contains(tag.id) ? "lock" : "tag")
                }
                .toggleStyle(.checkbox)
            }
        }
    }

    private var backupFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("privacy.migration.backup").font(DaybookType.body).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("privacy.migration.backup")
                .systemPageMarker("privacy.migration.backup")
            SecureField("privacy.backup.password.title", text: $backupPassword)
            SecureField("privacy.password.repeat", text: $backupRepeated)
            Text("privacy.backup.password.help").font(DaybookType.caption).foregroundStyle(DaybookPalette.text.secondary)
        }
    }

    private var valid: Bool {
        let methodsValid = vault.isConfigured || ((useMaster || useSystem)
            && (!useMaster || (master.count >= 12 && master == repeated)))
        return methodsValid && (count == 0 || (backupPassword.count >= 12 && backupPassword == backupRepeated))
    }

    private func submit() {
        guard valid, !busy else { return }
        busy = true
        errorKey = nil
        let newPassword = useMaster ? master : nil
        let backupInput = backupPassword
        Task {
            do {
                guard !StoreHealth.shared.isUsingMemoryFallback else { throw PrivacyError.storageFailure }
                if !vault.isConfigured {
                    let existing = try context.fetch(FetchDescriptor<DiaryEntry>())
                    let images = try context.fetch(FetchDescriptor<AttachmentItem>())
                    guard !existing.contains(where: \.hasProtectedContent),
                          !images.contains(where: { $0.privacyVaultID != nil }) else { throw PrivacyError.corruptData }
                    try await vault.create(password: newPassword, systemUnlock: useSystem)
                } else {
                    try await authenticate()
                }
                let environment = PrivacyPersistence(context: context, vault: vault)
                var proof: VerifiedPrivateBackup?
                if count > 0 {
                    guard let url = await PrivacyFilePanels.save() else { throw PrivacyError.cancelled }
                    try await authenticate()
                    proof = try await PrivateBackupService.export(to: url, password: backupInput,
                                                                  environment: environment, additionalPrivateTags: selected)
                }
                if (try? vault.requireFreshAuthentication()) == nil { try await authenticate() }
                try await DiaryProtection.applyTagsAsync(selected, in: environment, backup: proof, includeLegacy: includeLegacy)
                clearPasswords()
                busy = false
                onComplete()
            } catch {
                clearPasswords()
                errorKey = (error as? PrivacyError ?? .storageFailure).messageKey
                busy = false
            }
        }
    }

    private func authenticate() async throws {
        try await PrivacyUnlockPresenter.shared.request(reason: L10n.string("privacy.manage.reason", locale: locale),
                                                        force: true, vault: vault)
    }

    private func clearPasswords() {
        master = ""; repeated = ""; backupPassword = ""; backupRepeated = ""
    }
}
