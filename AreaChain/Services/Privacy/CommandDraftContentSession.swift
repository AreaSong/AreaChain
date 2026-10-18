import Foundation

/// 固定、无内容错误。首次失败表示尚未保护；编辑失败表示新输入未被应用接受。
enum CommandDraftProtectionError: Error, Equatable {
    case notProtected, revisionNotAccepted, stale, unavailable, invalidPayload, unsupported
    /// 已确认正文超过 CommandLongTextLimit；拒绝前不写入、不建恢复点，原修订与资格不变。
    case tooLong
}

/// 无公开构造器，不是所有权或解锁许可；只有成功建立恢复点才能签发。
@MainActor final class CommandDraftCheckpoint {
    let lease: CommandHostLease
    let draft: CommandDraftStamp
    let reference: CommandProtectedReference
    let continuingOwner: UUID?
    private var consumed = false
    fileprivate init(lease: CommandHostLease, draft: CommandDraftStamp, reference: CommandProtectedReference, continuingOwner: UUID? = nil) {
        self.continuingOwner = continuingOwner
        self.lease = lease; self.draft = draft; self.reference = reference
    }
    func consume() throws {
        guard !consumed else { throw CommandDraftProtectionError.stale }
        consumed = true
    }
}

struct CommandDraftContentAccess: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let isProtected: Bool
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
    private let ownerID = UUID()
    private let coordinator: CommandHandoffCoordinator
    private let vault: PrivacyVault
    private var sealed: [UUID: SealedCommandDraft] = [:]
    private var restored: [UUID: CommandDraftContents] = [:]
    private var presentingNative = false
    private weak var nativeOwner: (any CommandDraftNativeOwner)?
    private var epoch: UInt64 = 0
    private var lockingGeneration: UInt64?
    private let validateDisplay: ((CommandHostLease) throws -> Void)?
    private var observers: [NSObjectProtocol] = []

    init(coordinator: CommandHandoffCoordinator, vault: PrivacyVault,
         validateDisplay: ((CommandHostLease) throws -> Void)? = nil) {
        self.validateDisplay = validateDisplay
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
        coordinator.nativeTextOwners.detach(ownerID)
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
            let states = editing.isEmpty ? try draft.textPositions.keys.map { try Self.ordinaryState(draft, parameter: $0) } : editing
            let contents = CommandDraftContents(arguments: draft.arguments, baseline: draft.baseline, editing: states)
            return try checkpoint(contents, draft: draft, lease: lease)
        } catch { throw CommandDraftProtectionError.notProtected }
    }

    /// 调用方必须先显式恢复；候选失败保留前一已接受修订及其密文。
    func acceptRevision(_ contents: CommandDraftContents, using access: CommandDraftContentAccess) throws -> CommandProtectedReference {
        try accept(contents, using: access, continuingNative: false)
    }

    private func accept(_ contents: CommandDraftContents, using access: CommandDraftContentAccess,
                        continuingNative: Bool) throws -> CommandProtectedReference {
        // 受保护修订、原生推进与撤销都经此建点；超限在封存前拒绝，不能被包装成一般失败。
        guard Self.allowsLongText(contents) else { throw CommandDraftProtectionError.tooLong }
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
        let access = CommandDraftContentAccess(isProtected: true, id: UUID(), lease: lease, draft: stamp, reference: reference,
                                               generation: vault.generation, epoch: epoch)
        let contents: CommandDraftContents
        do { contents = try envelope.open(keys: vault.keys) }
        catch { throw CommandDraftProtectionError.invalidPayload }
        try validateIdentity(access)
        revokeAccess()
        let next = CommandDraftContentAccess(isProtected: true, id: UUID(), lease: lease, draft: stamp, reference: reference,
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
        _ = try nativeOperation(access, parameter: owner.parameter)
        let host = try coordinator.host(access.draft.hostID).session
        guard Self.isEditing(access.draft, in: host), nativeOwner == nil else {
            throw CommandDraftProtectionError.unsupported
        }
        try coordinator.nativeTextOwners.attach(ownerID) { [weak self] in self?.revokeAccess() }
        nativeOwner = owner
        presentingNative = true
        defer { presentingNative = false }
        do {
            let state = try nativeState(access, owner: owner)
            // 加上限前留下的旧稿不装入原生编辑器，也不截断；宿主应先用 exceedsLongTextLimit 改走提示。
            guard CommandLongTextLimit.allows(state.confirmedText) else { throw CommandDraftProtectionError.tooLong }
            try owner.installProtectedContents(state.pendingRestore())
        } catch { revokeAccess(); throw error }
    }

    /// 打开前判断是否为超限旧稿；不签发 owner、不安装、不返回正文。
    func exceedsLongTextLimit(_ access: CommandDraftContentAccess, parameter: CommandParameterID) throws -> Bool {
        try validate(access)
        let state: CommandDraftEditingState
        if access.isProtected {
            guard let contents = restored[access.id] else { throw CommandDraftProtectionError.stale }
            state = try Self.nativeState(contents, parameter: parameter)
        } else {
            state = try Self.ordinaryState(current(access.draft, lease: access.lease), parameter: parameter)
        }
        return !CommandLongTextLimit.allows(state.confirmedText)
    }

    /// 超限旧稿不进原生编辑器，只允许显式清空该字段；不截断。无论成败都撤销本次资格，不续用。
    func clearOversized(_ parameter: CommandParameterID, using access: CommandDraftContentAccess) throws {
        defer { revokeAccess() }
        guard nativeOwner == nil, try exceedsLongTextLimit(access, parameter: parameter) else {
            throw CommandDraftProtectionError.unsupported
        }
        let draft = try current(access.draft, lease: access.lease)
        guard Self.isEditing(access.draft, in: try coordinator.host(access.draft.hostID).session),
              let declaration = CommandCatalog.standard.command(id: draft.commandID)?.parameters.first(where: { $0.id == parameter }),
              declaration.type == .longText, declaration.operations.contains(.clear) else {
            throw CommandDraftProtectionError.unsupported
        }
        try validateDisplay?(access.lease)
        let empty = CommandDraftEditingState(parameter: parameter.rawValue, spelling: "", selectionLocation: 0, selectionLength: 0)
        if access.isProtected {
            guard var contents = restored[access.id] else { throw CommandDraftProtectionError.stale }
            contents.arguments.removeAll { $0.parameter == parameter }
            contents.arguments.append(.init(parameter: parameter, operation: .clear, value: nil))
            contents.editing.removeAll { $0.parameter == parameter.rawValue }
            contents.editing.append(empty)
            _ = try accept(contents, using: access, continuingNative: false)
            return
        }
        // 普通稿沿原生文字的同一提交入口；独占登记与原编辑器相同，另一服务持有时被拒绝。
        try coordinator.nativeTextOwners.attach(ownerID) { [weak self] in self?.revokeAccess() }
        try coordinator.acceptNativeText(empty, operation: .clear, expecting: access.draft, lease: access.lease, owner: ownerID)
    }

    private static func allowsLongText(_ contents: CommandDraftContents) -> Bool {
        contents.arguments.allSatisfy { argument in
            guard case .longText(let text) = argument.value else { return true }
            return CommandLongTextLimit.allows(text)
        }
    }

    func detachNative(_ owner: any CommandDraftNativeOwner) {
        guard nativeOwner === owner else { return }
        revokeAccess()
    }

    func validateNative(_ access: CommandDraftContentAccess, owner: any CommandDraftNativeOwner) throws {
        guard nativeOwner === owner else { throw CommandDraftProtectionError.stale }
        try validate(access)
        try validateDisplay?(access.lease)
        guard Self.isEditing(access.draft, in: try coordinator.host(access.draft.hostID).session) else {
            throw CommandDraftProtectionError.stale
        }
    }

    func nativeRecoveryPoint(_ access: CommandDraftContentAccess, owner: any CommandDraftNativeOwner) throws -> SealedCommandDraft {
        try validateNative(access, owner: owner)
        guard access.isProtected, let envelope = sealed[access.reference.payloadID] else { throw CommandDraftProtectionError.stale }
        return envelope
    }

    func acceptNative(_ state: CommandDraftEditingState, using access: CommandDraftContentAccess,
                      owner: any CommandDraftNativeOwner) throws -> CommandDraftContentAccess {
        try validateNative(access, owner: owner)
        guard state.parameter == owner.parameter.rawValue else { throw CommandDraftProtectionError.invalidPayload }
        do { try state.validate() } catch { throw CommandDraftProtectionError.invalidPayload }
        // 普通与受保护两条路径共用：写入或建立恢复点前拒绝；组合中的未确认缓冲不计入。
        guard CommandLongTextLimit.allows(state.confirmedText) else { throw CommandDraftProtectionError.tooLong }
        let operation = try nativeOperation(access, parameter: owner.parameter)
        guard operation.requiresValue else { throw CommandDraftProtectionError.unsupported }
        if !access.isProtected { return try advanceOrdinary(state, operation: operation, using: access, owner: owner) }
        guard var contents = restored[access.id] else { throw CommandDraftProtectionError.stale }
        contents.arguments.removeAll { $0.parameter == owner.parameter }
        contents.arguments.append(.init(parameter: owner.parameter, operation: operation, value: .longText(state.confirmedText)))
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
        var contents = try point.open(keys: vault.keys)
        contents.editing = contents.editing.map { $0.pendingRestore() }
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
        try owner.installProtectedContents(nativeState(access, owner: owner))
    }

    private func advanceNative(_ contents: CommandDraftContents, using old: CommandDraftContentAccess,
                               owner: any CommandDraftNativeOwner) throws -> CommandDraftContentAccess {
        try validateNative(old, owner: owner)
        let reference = try accept(contents, using: old, continuingNative: true)
        let host = try coordinator.host(old.draft.hostID)
        guard nativeOwner === owner, vault.generation == old.generation,
              let draft = host.session.allDrafts.first(where: { $0.id == old.draft.draftID }),
              Self.isEditing(draft.stamp, in: host.session),
              draft.protectedReference == reference else { throw CommandDraftProtectionError.stale }
        let next = CommandDraftContentAccess(isProtected: true, id: UUID(), lease: host.lease, draft: draft.stamp, reference: reference,
                                            generation: old.generation, epoch: epoch)
        try validateIdentity(next)
        restored[next.id] = contents
        return next
    }

    private static func nativeState(_ contents: CommandDraftContents, parameter: CommandParameterID) throws -> CommandDraftEditingState {
        let argument = contents.arguments.first { $0.parameter == parameter }
        let text: String
        if case .longText(let value) = argument?.value { text = value } else { text = "" }
        if let saved = contents.editing.first(where: { $0.parameter == parameter.rawValue }) {
            // v1 的拼写不是已确认正文；差异按整段待确认输入恢复，原 arguments 保持。
            if saved.composition == nil, saved.spelling != text {
                var pending = saved
                pending.composition = .init(text: saved.spelling, location: 0, replacedText: text, pendingConfirmation: true)
                return pending
            }
            return saved
        }
        return .init(parameter: parameter.rawValue, spelling: text, selectionLocation: text.utf16.count, selectionLength: 0)
    }

    private static func isEditing(_ stamp: CommandDraftStamp, in host: CommandHostSession) -> Bool {
        guard host.execution == nil, host.operations.pending == nil else { return false }
        if let itemID = host.plan.editing { return host.plan.items.contains { $0.id == itemID && $0.draft.stamp == stamp } }
        return host.operations.active?.stamp == stamp
    }

    /// 普通正文仍唯一归原 draft.arguments；本服务只签发可撤销原生访问，不缓存普通正文。
    func explicitlyEditOrdinary(_ stamp: CommandDraftStamp, expecting lease: CommandHostLease) throws -> CommandDraftContentAccess {
        let draft = try current(stamp, lease: lease)
        guard draft.protectedReference == nil, draft.protectionRequirement == .ordinary,
              Self.isEditing(stamp, in: try coordinator.host(stamp.hostID).session), nativeOwner == nil,
              vault.configuration == nil || vault.isUnlocked else { throw CommandDraftProtectionError.unavailable }
        try validateDisplay?(lease)
        revokeAccess()
        return .init(isProtected: false, id: UUID(), lease: lease, draft: stamp,
                     reference: .init(payloadID: stamp.draftID, revision: UUID()), generation: vault.generation, epoch: epoch)
    }

    func nativeState(_ access: CommandDraftContentAccess, owner: any CommandDraftNativeOwner) throws -> CommandDraftEditingState {
        try validateNative(access, owner: owner)
        let parameter = owner.parameter
        if !access.isProtected { return try Self.ordinaryState(current(access.draft, lease: access.lease), parameter: parameter) }
        guard let contents = restored[access.id] else { throw CommandDraftProtectionError.stale }
        return try Self.nativeState(contents, parameter: parameter)
    }

    func nativeOperation(_ access: CommandDraftContentAccess, parameter: CommandParameterID) throws -> CommandFieldOperation {
        try validate(access)
        let draft = try current(access.draft, lease: access.lease)
        guard [.notes, .body].contains(parameter),
              let declaration = CommandCatalog.standard.command(id: draft.commandID)?.parameters.first(where: { $0.id == parameter }),
              declaration.type == .longText else { throw CommandDraftProtectionError.unsupported }
        let arguments = access.isProtected ? restored[access.id]?.arguments : draft.arguments
        let operation = arguments?.first(where: { $0.parameter == parameter })?.operation ?? declaration.defaultOperation
        guard declaration.operations.contains(operation) else { throw CommandDraftProtectionError.unsupported }
        return operation
    }

    func changeNativeOperation(_ operation: CommandFieldOperation, using access: CommandDraftContentAccess,
                               owner: any CommandDraftNativeOwner) throws -> CommandDraftContentAccess {
        try validateNative(access, owner: owner)
        let draft = try current(access.draft, lease: access.lease)
        guard let declaration = CommandCatalog.standard.command(id: draft.commandID)?.parameters.first(where: { $0.id == owner.parameter }),
              declaration.operations.contains(operation) else { throw CommandDraftProtectionError.unsupported }
        var state = try nativeState(access, owner: owner)
        guard state.composition == nil else { throw CommandDraftProtectionError.unsupported }
        if !operation.requiresValue { state = .init(parameter: owner.parameter.rawValue, spelling: "", selectionLocation: 0, selectionLength: 0) }
        if !access.isProtected { return try advanceOrdinary(state, operation: operation, using: access, owner: owner) }
        guard var contents = restored[access.id] else { throw CommandDraftProtectionError.stale }
        contents.arguments.removeAll { $0.parameter == owner.parameter }
        contents.arguments.append(.init(parameter: owner.parameter, operation: operation, value: operation.requiresValue ? .longText(state.spelling) : nil))
        contents.editing.removeAll { $0.parameter == owner.parameter.rawValue }
        contents.editing.append(state)
        return try advanceNative(contents, using: access, owner: owner)
    }

    private static func ordinaryState(_ draft: CommandDraft, parameter: CommandParameterID) throws -> CommandDraftEditingState {
        let text: String
        if case .longText(let value) = draft.arguments.first(where: { $0.parameter == parameter })?.value { text = value } else { text = "" }
        let position = draft.textPositions[parameter] ?? .init(selection: .init(location: text.utf16.count, length: 0))
        var display = text
        if let composition = position.composition {
            let range = NSRange(location: composition.location, length: composition.replacedText.utf16.count)
            guard CommandDraftEditingState.valid(range, in: text), (text as NSString).substring(with: range) == composition.replacedText else {
                throw CommandDraftProtectionError.invalidPayload
            }
            display = (text as NSString).replacingCharacters(in: range, with: composition.text)
        }
        let state = CommandDraftEditingState(parameter: parameter.rawValue, spelling: display,
            selectionLocation: position.selection.location, selectionLength: position.selection.length, composition: position.composition)
        try state.validate()
        return state
    }

    private func advanceOrdinary(_ state: CommandDraftEditingState, operation: CommandFieldOperation,
                                 using old: CommandDraftContentAccess, owner: any CommandDraftNativeOwner) throws -> CommandDraftContentAccess {
        try validateNative(old, owner: owner)
        try CommandTextTiming.measure("coordinator") {
            try coordinator.acceptNativeText(state, operation: operation, expecting: old.draft, lease: old.lease, owner: ownerID)
        }
        let host = try coordinator.host(old.draft.hostID)
        guard let draft = host.session.allDrafts.first(where: { $0.id == old.draft.draftID }), Self.isEditing(draft.stamp, in: host.session) else {
            throw CommandDraftProtectionError.stale
        }
        epoch &+= 1
        return .init(isProtected: false, id: UUID(), lease: host.lease, draft: draft.stamp,
                     reference: old.reference, generation: old.generation, epoch: epoch)
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
        if !access.isProtected {
            guard draft.protectedReference == nil, draft.protectionRequirement == .ordinary else { throw CommandDraftProtectionError.stale }
            return
        }
        let id = try availableVault()
        guard draft.protectedReference == access.reference,
              sealed[access.reference.payloadID]?.reference == access.reference,
              sealed[access.reference.payloadID]?.vaultID == id else { throw CommandDraftProtectionError.stale }
    }

    private func validate(_ access: CommandDraftContentAccess) throws {
        try validateIdentity(access)
        guard !access.isProtected || restored[access.id] != nil else { throw CommandDraftProtectionError.stale }
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
            try CommandTextTiming.measure("coordinator") {
                try coordinator.acceptProtection(.init(lease: lease, draft: draft.stamp, reference: reference,
                                                        continuingOwner: continuingNative ? ownerID : nil))
            }
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
