import Foundation

/// 固定、无内容错误。首次失败表示尚未保护；编辑失败表示新输入未被应用接受。
enum CommandDraftProtectionError: Error, Equatable {
    case notProtected, revisionNotAccepted, stale, unavailable, invalidPayload, unsupported
}

/// 无公开构造器，不是所有权或解锁许可；只有成功建立恢复点才能签发。
@MainActor final class CommandDraftCheckpoint {
    let lease: CommandHostLease
    let draft: CommandDraftStamp
    let reference: CommandProtectedReference
    private var consumed = false
    fileprivate init(lease: CommandHostLease, draft: CommandDraftStamp, reference: CommandProtectedReference) {
        self.lease = lease; self.draft = draft; self.reference = reference
    }
    func consume() throws {
        guard !consumed else { throw CommandDraftProtectionError.stale }
        consumed = true
    }
}

struct CommandDraftContentAccess: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    fileprivate let id: UUID
    fileprivate let lease: CommandHostLease
    fileprivate let draft: CommandDraftStamp
    fileprivate let reference: CommandProtectedReference
    fileprivate let generation: UInt64
    fileprivate let epoch: UInt64
    var description: String { "CommandDraftContentAccess(opaque)" }
    var debugDescription: String { description }
}

/// 只供隔离装配。资源表不授予 owner；每次操作回查唯一 Coordinator。
/// 不挂接生产编辑器，不做认证、磁盘写入、延迟加密或锁定时首次封存。
@MainActor final class CommandDraftContentSession {
    private let coordinator: CommandHandoffCoordinator
    private let vault: PrivacyVault
    private var sealed: [UUID: SealedCommandDraft] = [:]
    private var restored: [UUID: CommandDraftContents] = [:]
    private var presentingNative = false
    private weak var nativeOwner: (any CommandDraftNativeOwner)?
    private var epoch: UInt64 = 0
    private var lockingGeneration: UInt64?
    private var observers: [NSObjectProtocol] = []

    init(coordinator: CommandHandoffCoordinator, vault: PrivacyVault) {
        self.coordinator = coordinator; self.vault = vault
        for name in [Notification.Name.privacyWillLock, .privacyDidChange, .privacyMask] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: vault, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if name == .privacyWillLock { self.lockingGeneration = self.vault.generation }
                    self.revokeAccess()
                }
            })
        }
    }

    deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }

    func revokeAccess() {
        epoch &+= 1
        restored.removeAll()
        let owner = nativeOwner
        nativeOwner = nil
        owner?.clearProtectedContents()
    }

    /// 原普通稿完整保留至密文完成。失败不推进任何宿主/草稿修订。
    func protect(_ stamp: CommandDraftStamp, expecting lease: CommandHostLease,
                 editing: [CommandDraftEditingState] = []) throws -> CommandProtectedReference {
        let draft = try current(stamp, lease: lease)
        guard draft.protectedReference == nil else { throw CommandDraftProtectionError.unsupported }
        do {
            let contents = CommandDraftContents(arguments: draft.arguments, baseline: draft.baseline, editing: editing)
            return try checkpoint(contents, draft: draft, lease: lease)
        } catch { throw CommandDraftProtectionError.notProtected }
    }

    /// 调用方必须先显式恢复；候选失败保留前一已接受修订及其密文。
    func acceptRevision(_ contents: CommandDraftContents, using access: CommandDraftContentAccess) throws -> CommandProtectedReference {
        try accept(contents, using: access, continuingNative: false)
    }

    private func accept(_ contents: CommandDraftContents, using access: CommandDraftContentAccess,
                        continuingNative: Bool) throws -> CommandProtectedReference {
        do {
            try validate(access)
            guard let previous = restored[access.id], previous.baseline == contents.baseline else {
                throw CommandDraftProtectionError.invalidPayload
            }
            let draft = try current(access.draft, lease: access.lease)
            return try checkpoint(contents, draft: draft, lease: access.lease, continuingNative: continuingNative)
        } catch { throw CommandDraftProtectionError.revisionNotAccepted }
    }

    /// 显式动作是唯一解密入口。解锁通知只撤销旧访问，不自动恢复。
    func explicitlyRestore(_ stamp: CommandDraftStamp, expecting lease: CommandHostLease) throws -> CommandDraftContentAccess {
        let draft = try current(stamp, lease: lease)
        let vaultID = try availableVault()
        guard let reference = draft.protectedReference, let envelope = sealed[reference.payloadID],
              envelope.reference == reference, envelope.vaultID == vaultID,
              envelope.draftID == stamp.draftID, envelope.commandID == draft.commandID.rawValue else {
            throw CommandDraftProtectionError.stale
        }
        let access = CommandDraftContentAccess(id: UUID(), lease: lease, draft: stamp, reference: reference,
                                               generation: vault.generation, epoch: epoch)
        let contents: CommandDraftContents
        do { contents = try envelope.open(keys: vault.keys) }
        catch { throw CommandDraftProtectionError.invalidPayload }
        try validateIdentity(access)
        revokeAccess()
        let next = CommandDraftContentAccess(id: UUID(), lease: lease, draft: stamp, reference: reference,
                                             generation: vault.generation, epoch: epoch)
        try validateIdentity(next)
        restored[next.id] = contents
        return next
    }

    /// 同步受控借用；调用方不得缓存/日志/异步捕获 String。释放引用不承诺物理零化。
    func withRestoredContents(_ access: CommandDraftContentAccess, _ body: (CommandDraftContents) throws -> Void) throws {
        try validate(access)
        guard let contents = restored[access.id] else { throw CommandDraftProtectionError.stale }
        try body(contents)
        try validate(access)
    }

    /// 唯一允许原生暂持的出口。普通借用契约不变；owner 只能持有当前字段和本控件撤销密文。
    func attachNative(_ owner: any CommandDraftNativeOwner, using access: CommandDraftContentAccess) throws {
        try validate(access)
        let host = try coordinator.host(access.draft.hostID).session
        guard host.operations.active?.stamp == access.draft, nativeOwner == nil else {
            throw CommandDraftProtectionError.unsupported
        }
        nativeOwner = owner
        presentingNative = true
        defer { presentingNative = false }
        do {
            try withRestoredContents(access) { contents in
                try owner.installProtectedContents(Self.nativeState(contents, parameter: owner.parameter))
            }
        } catch { revokeAccess(); throw error }
    }

    func detachNative(_ owner: any CommandDraftNativeOwner) {
        guard nativeOwner === owner else { return }
        revokeAccess()
    }

    func validateNative(_ access: CommandDraftContentAccess, owner: any CommandDraftNativeOwner) throws {
        guard nativeOwner === owner else { throw CommandDraftProtectionError.stale }
        try validate(access)
        guard try coordinator.host(access.draft.hostID).session.operations.active?.stamp == access.draft else {
            throw CommandDraftProtectionError.stale
        }
    }

    func nativeRecoveryPoint(_ access: CommandDraftContentAccess, owner: any CommandDraftNativeOwner) throws -> SealedCommandDraft {
        try validateNative(access, owner: owner)
        guard let envelope = sealed[access.reference.payloadID] else { throw CommandDraftProtectionError.stale }
        return envelope
    }

    func acceptNative(_ state: CommandDraftEditingState, using access: CommandDraftContentAccess,
                      owner: any CommandDraftNativeOwner) throws -> CommandDraftContentAccess {
        try validateNative(access, owner: owner)
        guard state.parameter == owner.parameter.rawValue, var contents = restored[access.id] else {
            throw CommandDraftProtectionError.invalidPayload
        }
        contents.arguments.removeAll { $0.parameter == owner.parameter }
        contents.arguments.append(.init(parameter: owner.parameter, operation: .replace, value: .longText(state.spelling)))
        contents.editing.removeAll { $0.parameter == state.parameter }
        contents.editing.append(state)
        return try advanceNative(contents, using: access, owner: owner)
    }

    /// 撤销只读本控件的旧密文；仍在当前资格下解码，并重新保护为新修订，不续用历史 access。
    func undoNative(_ point: SealedCommandDraft, using access: CommandDraftContentAccess,
                    owner: any CommandDraftNativeOwner) throws -> CommandDraftContentAccess {
        try validateNative(access, owner: owner)
        guard point.draftID == access.draft.draftID, point.vaultID == (try availableVault()),
              point.reference.payloadID == access.reference.payloadID else { throw CommandDraftProtectionError.stale }
        let contents = try point.open(keys: vault.keys)
        try validateNative(access, owner: owner)
        return try advanceNative(contents, using: access, owner: owner)
    }

    func permitsNativeInstallation(_ owner: any CommandDraftNativeOwner) -> Bool {
        presentingNative && nativeOwner === owner
    }

    func presentNative(_ access: CommandDraftContentAccess, owner: any CommandDraftNativeOwner) throws {
        try validateNative(access, owner: owner)
        presentingNative = true
        defer { presentingNative = false }
        try withRestoredContents(access) { contents in
            try owner.installProtectedContents(Self.nativeState(contents, parameter: owner.parameter))
        }
    }

    private func advanceNative(_ contents: CommandDraftContents, using old: CommandDraftContentAccess,
                               owner: any CommandDraftNativeOwner) throws -> CommandDraftContentAccess {
        try validateNative(old, owner: owner)
        let reference = try accept(contents, using: old, continuingNative: true)
        let host = try coordinator.host(old.draft.hostID)
        guard nativeOwner === owner, vault.generation == old.generation,
              let draft = host.session.operations.active, draft.id == old.draft.draftID,
              draft.protectedReference == reference else { throw CommandDraftProtectionError.stale }
        let next = CommandDraftContentAccess(id: UUID(), lease: host.lease, draft: draft.stamp, reference: reference,
                                            generation: old.generation, epoch: epoch)
        try validateIdentity(next)
        restored[next.id] = contents
        return next
    }

    private static func nativeState(_ contents: CommandDraftContents, parameter: CommandParameterID) throws -> CommandDraftEditingState {
        guard let argument = contents.arguments.first(where: { $0.parameter == parameter }),
              argument.operation == .replace, case .longText(let text) = argument.value else {
            throw CommandDraftProtectionError.unsupported
        }
        return contents.editing.first(where: { $0.parameter == parameter.rawValue })
            ?? .init(parameter: parameter.rawValue, spelling: text, selectionLocation: text.utf16.count, selectionLength: 0)
    }

    private func current(_ stamp: CommandDraftStamp, lease: CommandHostLease) throws -> CommandDraft {
        try coordinator.validate(lease)
        let host = try coordinator.host(lease.ownership.hostID).session
        guard host.execution == nil, stamp.hostID == host.hostID,
              let draft = host.allDrafts.first(where: { $0.stamp == stamp }) else { throw CommandDraftProtectionError.stale }
        return draft
    }

    private func availableVault() throws -> UUID {
        guard lockingGeneration != vault.generation, vault.isUnlocked, !vault.isAuthenticating, !vault.isChangingMethods,
              let id = vault.configuration?.vaultID else { throw CommandDraftProtectionError.unavailable }
        // 仅验证已安装的 key，不发起认证，也不导出 key 字节。
        try vault.keys.withKey(vaultID: id) { _ in () }
        return id
    }

    private func validateIdentity(_ access: CommandDraftContentAccess) throws {
        guard access.epoch == epoch, access.generation == vault.generation else { throw CommandDraftProtectionError.stale }
        let draft = try current(access.draft, lease: access.lease)
        let id = try availableVault()
        guard draft.protectedReference == access.reference,
              sealed[access.reference.payloadID]?.reference == access.reference,
              sealed[access.reference.payloadID]?.vaultID == id else { throw CommandDraftProtectionError.stale }
    }

    private func validate(_ access: CommandDraftContentAccess) throws {
        try validateIdentity(access)
        guard restored[access.id] != nil else { throw CommandDraftProtectionError.stale }
    }

    private func checkpoint(_ contents: CommandDraftContents, draft: CommandDraft,
                            lease: CommandHostLease, continuingNative: Bool = false) throws -> CommandProtectedReference {
        let vaultID = try availableVault()
        let generation = vault.generation, epoch = self.epoch
        let reference = CommandProtectedReference(payloadID: draft.protectedReference?.payloadID ?? UUID(), revision: UUID())
        let candidate = try SealedCommandDraft.seal(contents, reference: reference, draft: draft, vaultID: vaultID, keys: vault.keys)
        guard vault.generation == generation, self.epoch == epoch, try availableVault() == vaultID,
              try current(draft.stamp, lease: lease) == draft else { throw CommandDraftProtectionError.stale }
        let previous = sealed[reference.payloadID]
        sealed[reference.payloadID] = candidate
        do {
            try coordinator.acceptProtection(.init(lease: lease, draft: draft.stamp, reference: reference))
        } catch {
            sealed[reference.payloadID] = previous
            throw error
        }
        // 只有本次已核验的原生推进可以移交到新资格；所有外部失效仍同步清控件。
        if continuingNative {
            self.epoch &+= 1
            restored.removeAll()
        } else { revokeAccess() }
        return reference
    }
}
