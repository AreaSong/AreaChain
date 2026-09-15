import Foundation
import Observation

struct DiaryComposerDraft {
    var id = UUID()
    var text = ""
    var selectedTagIDs: Set<UUID> = []
    var needsProtection = false
    var sealed: SealedDiaryDraft?

    var hasContent: Bool { sealed != nil || !text.isEmpty }

    @MainActor mutating func seal(vault: PrivacyVault) throws {
        guard needsProtection, sealed == nil, vault.isUnlocked else { return }
        sealed = try SealedDiaryDraft.seal(text: text, baseline: "", id: id, vault: vault)
        text = ""
    }

    @MainActor mutating func restore(vault: PrivacyVault) throws {
        guard let sealed, vault.isUnlocked else { return }
        text = try sealed.open(vault: vault).text
        self.sealed = nil
    }
}

/// 只在本次运行保留快速草稿；收起菜单栏不等于主动丢弃，也不把未保存正文写到偏好中。
@Observable @MainActor
final class DiaryCaptureSession {
    static let shared = DiaryCaptureSession()
    var draft = DiaryComposerDraft()
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init(vault: PrivacyVault? = nil) {
        let vault = vault ?? .shared
        observers.append(NotificationCenter.default.addObserver(forName: .privacyWillLock, object: vault, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { try? self?.draft.seal(vault: vault) }
        })
    }

    deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }
}
