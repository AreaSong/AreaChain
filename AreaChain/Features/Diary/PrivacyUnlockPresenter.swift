import AppKit
import SwiftUI
import SwiftData

@MainActor
final class PrivacyUnlockPresenter: NSObject, NSWindowDelegate {
    static let shared = PrivacyUnlockPresenter()
    private var panel: NSPanel?
    private var continuation: CheckedContinuation<Void, Error>?
    private var activeVault: PrivacyVault?

    func request(reason: String, force: Bool = false, vault: PrivacyVault? = nil) async throws {
        let vault = vault ?? .shared
        if vault.isUnlocked && !force { vault.touch(); return }
        guard vault.isConfigured else { throw vault.issue ?? .notConfigured }
        guard continuation == nil else { throw PrivacyError.busy }
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.activeVault = vault
            show(reason: reason, vault: vault)
        }
    }

    private func show(reason: String, vault: PrivacyVault) {
        let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 390, height: 300),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = L10n.string("privacy.unlock.title", locale: AppPreferences.shared.resolvedLocale)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView:
            PrivacyUnlockView(vault: vault, reason: reason, onComplete: { [weak self] in self?.finish(nil) },
                              onCancel: { [weak self] in self?.finish(.cancelled) })
                .environment(\.locale, AppPreferences.shared.resolvedLocale))
        panel = window
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        if continuation != nil { finish(.cancelled) }
    }

    private func finish(_ error: PrivacyError?) {
        guard let continuation else { return }
        self.continuation = nil
        if error != nil { activeVault?.lock() }
        activeVault = nil
        panel?.close()
        panel = nil
        if let error { continuation.resume(throwing: error) }
        else { continuation.resume() }
    }
}

struct PrivacyUnlockView: View {
    var vault: PrivacyVault
    var reason: String
    var onComplete: () -> Void
    var onCancel: () -> Void
    @State private var password = ""
    @State private var busy = false
    @State private var error: PrivacyError?
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("privacy.unlock.title", systemImage: "lock.shield")
                .font(DaybookType.title).foregroundStyle(DaybookTheme.ink)
            Text(reason).font(DaybookType.body).foregroundStyle(DaybookTheme.muted).fixedSize(horizontal: false, vertical: true)
            if vault.hasSystemUnlock {
                Button { authenticate(system: true) } label: {
                    Label("privacy.unlock.system", systemImage: "touchid").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(busy)
            }
            if vault.hasMasterPassword {
                VStack(alignment: .leading, spacing: 6) {
                    Text("privacy.master.label").font(DaybookType.caption)
                    SecureField("privacy.master.placeholder", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("privacy.master.input")
                        .onSubmit { authenticate(system: false) }
                    Button("privacy.unlock.password") { authenticate(system: false) }
                        .disabled(busy || password.isEmpty)
                }
            }
            if let error {
                Text(LocalizedStringKey(error.messageKey)).font(DaybookType.caption)
                    .foregroundStyle(DaybookTheme.destructive).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                if busy { ProgressView().controlSize(.small) }
                Spacer()
                Button("alert.cancel", action: onCancel).keyboardShortcut(.cancelAction)
            }
        }
        .padding(22).frame(width: 390)
        .background(DaybookTheme.paper)
        .onDisappear { password = "" }
    }

    private func authenticate(system: Bool) {
        guard !busy else { return }
        busy = true
        error = nil
        let input = password
        password = ""
        Task {
            do {
                if system { try await vault.unlockWithSystem(reason: reason) }
                else { try await vault.unlockWithPassword(input) }
                guard vault.isUnlocked else { throw PrivacyError.staleOperation }
                busy = false
                onComplete()
            } catch {
                self.error = error as? PrivacyError ?? .systemUnavailable
                busy = false
            }
        }
    }
}

@MainActor
enum PrivacyAccess {
    static func withDiary(_ entry: DiaryEntry, requiresUnlock: Bool = false, force: Bool = false,
                          vault: PrivacyVault? = nil, _ action: @escaping (DiaryEntry) throws -> Void) {
        guard let context = entry.modelContext else {
            guard !entry.hasProtectedContent, !requiresUnlock else { MutationFeedback.shared.reportFailure(PrivacyError.staleOperation); return }
            perform(requiresUnlock: false, vault: vault) { try action(entry) }
            return
        }
        let id = entry.id
        perform(requiresUnlock: entry.hasProtectedContent || requiresUnlock, force: force, vault: vault) {
            guard let current = try SwiftDataDiaryRepository(context: context).fetchDiary(id: id),
                  current.deletedAt == nil else { throw PrivacyError.staleOperation }
            try action(current)
        }
    }

    static func perform(requiresUnlock: Bool, force: Bool = false, vault: PrivacyVault? = nil,
                        _ action: @escaping () throws -> Void) {
        let vault = vault ?? .shared
        if !requiresUnlock || (vault.isUnlocked && !force) {
            do {
                if requiresUnlock { vault.touch() }
                try action()
            } catch { MutationFeedback.shared.reportFailure(error) }
            return
        }
        Task {
            do {
                let reason = L10n.string("privacy.unlock.reason", locale: AppPreferences.shared.resolvedLocale)
                try await PrivacyUnlockPresenter.shared.request(reason: reason, force: force, vault: vault)
                guard vault.isUnlocked else { throw PrivacyError.locked }
                try action()
            } catch let error as PrivacyError where error == .cancelled {
                // 取消是正常操作，不弹错误，也不执行原来的动作。
            } catch { MutationFeedback.shared.reportFailure(error) }
        }
    }
}
