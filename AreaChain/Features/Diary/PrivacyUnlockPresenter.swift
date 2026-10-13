import AppKit
import SwiftUI
import SwiftData

private final class PrivacyUnlockPanel: NSPanel {
    var onCloseRequest: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func performClose(_ sender: Any?) {
        if let onCloseRequest {
            onCloseRequest()
        } else {
            super.performClose(sender)
        }
    }

    override func close() {
        if let parent = sheetParent {
            parent.endSheet(self)
        }
        super.close()
    }
}

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
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let window = PrivacyUnlockPanel(
            contentRect: NSRect(x: 0, y: 0, width: 390, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.string("privacy.unlock.title", locale: AppPreferences.shared.resolvedLocale)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.onCloseRequest = { [weak self] in self?.finish(.cancelled) }
        window.contentView = NSHostingView(rootView:
            PrivacyUnlockView(
                vault: vault,
                reason: reason,
                onComplete: { [weak self] in self?.finish(nil) },
                onCancel: { [weak self] in self?.finish(.cancelled) },
                autoTriggerSystem: !isTesting
            )
            .environment(\.locale, AppPreferences.shared.resolvedLocale)
        )
        panel = window
        NSApp.activate(ignoringOtherApps: true)
        if let parent = targetParentWindow(excluding: window) {
            parent.beginSheet(window)
        } else {
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func targetParentWindow(excluding candidate: NSWindow) -> NSWindow? {
        let candidates = [NSApp.keyWindow, NSApp.mainWindow]
        return candidates.compactMap { $0 }.first { window in
            window.isVisible
                && window !== candidate
                && window.sheetParent == nil
                && window.attachedSheet == nil
                && !String(describing: type(of: window)).contains("Popover")
                && window.contentView != nil
        }
    }

    func windowWillClose(_ notification: Notification) {
        if continuation != nil { finish(.cancelled) }
    }

    private func finish(_ error: PrivacyError?) {
        guard let continuation else { return }
        self.continuation = nil
        if error != nil { activeVault?.lock() }
        activeVault = nil
        if let panel {
            if let parent = panel.sheetParent {
                parent.endSheet(panel)
            }
            panel.orderOut(nil)
            panel.close()
        }
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
    var autoTriggerSystem: Bool = false
    @State private var password = ""
    @State private var busy = false
    @State private var error: PrivacyError?
    @State private var hasAutoTriggered = false
    @State private var passwordFocusTrigger = 0
    @Environment(\.locale) private var locale

    private var prefersPasswordFirst: Bool {
        vault.hasMasterPassword && (!vault.hasSystemUnlock || vault.preferredMethod == .password)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            if prefersPasswordFirst {
                masterPasswordSection(isPrimary: true)
                if vault.hasSystemUnlock {
                    systemUnlockButton(isPrimary: false)
                }
            } else {
                if vault.hasSystemUnlock {
                    systemUnlockButton(isPrimary: true)
                }
                if vault.hasMasterPassword {
                    masterPasswordSection(isPrimary: false)
                } else {
                    masterPasswordHintSection
                }
            }
            if let error {
                Text(LocalizedStringKey(error.messageKey))
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.status.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
            footerRow
        }
        .padding(20)
        .frame(width: 390)
        .background(DaybookPalette.fill.page)
        .onAppear {
            guard autoTriggerSystem, vault.hasSystemUnlock, !prefersPasswordFirst, !hasAutoTriggered else { return }
            hasAutoTriggered = true
            DispatchQueue.main.async {
                authenticate(system: true)
            }
        }
        .onDisappear { password = "" }
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .fill(DaybookPalette.accent.fill)
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .strokeBorder(DaybookPalette.accent.border, lineWidth: DaybookMetrics.Stroke.hairline)
                Image(systemName: "lock.shield.fill")
                    .font(DaybookType.title)
                    .foregroundStyle(DaybookPalette.accent.base)
            }
            .frame(width: 32, height: 32)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("privacy.unlock.title")
                    .font(DaybookType.title)
                    .foregroundStyle(DaybookPalette.text.primary)
                Text(reason)
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func systemUnlockButton(isPrimary: Bool) -> some View {
        Button {
            authenticate(system: true)
        } label: {
            Label("privacy.unlock.system", systemImage: "touchid")
                .font(DaybookType.body.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
        }
        .buttonStyle(
            DaybookButtonStyle(
                isPrimary ? .pill(tint: DaybookPalette.accent.base) : .active
            )
        )
        .disabled(busy)
    }

    private func masterPasswordSection(isPrimary: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "key.fill")
                    .font(DaybookType.micro)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .accessibilityHidden(true)
                Text("privacy.master.label")
                    .font(DaybookType.caption.weight(.medium))
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
            DaybookSecureField(
                "privacy.master.placeholder",
                text: $password,
                autoFocus: isPrimary,
                focusTrigger: passwordFocusTrigger
            )
            .accessibilityIdentifier("privacy.master.input")
            .onSubmit { authenticate(system: false) }
            Button {
                authenticate(system: false)
            } label: {
                Text("privacy.unlock.password")
                    .font(DaybookType.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
            }
            .buttonStyle(
                DaybookButtonStyle(
                    isPrimary ? .pill(tint: DaybookPalette.accent.base) : .active
                )
            )
            .disabled(busy || password.isEmpty)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .fill(DaybookPalette.fill.subtle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .strokeBorder(DaybookPalette.border.subtle, lineWidth: DaybookMetrics.Stroke.hairline)
        )
    }

    private var masterPasswordHintSection: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "key")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
                .accessibilityHidden(true)
            Text("privacy.unlock.master.hint")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .fill(DaybookPalette.fill.subtle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .strokeBorder(DaybookPalette.border.subtle, lineWidth: DaybookMetrics.Stroke.hairline)
        )
    }

    private var footerRow: some View {
        HStack {
            if busy { ProgressView().controlSize(.small) }
            Spacer()
            Button("alert.cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
                .buttonStyle(DaybookButtonStyle(.quiet))
        }
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
            } catch let privacyError as PrivacyError where system && privacyError == .cancelled {
                self.error = nil
                busy = false
                if vault.hasMasterPassword {
                    passwordFocusTrigger &+= 1
                }
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
