import Foundation
import Observation
import SwiftData

/// 外部任务/候选只含不可拼装的运行内身份；候选响应始终留在适配器内。
struct ContentQueryReadHandle: Equatable {
    fileprivate let id: UUID
}

/// 正文模式内部创建 owner，外部无法取得别名；旧注入 owner 的入口只允许 metadataOnly。
/// 返回的安全展示值仍可被外部复制，撤引用不保证 String 零化。
@MainActor
final class ContentQueryReadSession {
    let displayUpdates = ContentQueryDisplayUpdates()
    private(set) var expansionIndex: ContentQueryExpansionIndex?
    private struct Permit {
        let lease: CommandHostLease
        let epoch: UInt64
        let vault: ContentQueryVaultStamp
        let source: ContentQueryReadSource
    }
    private struct Pending {
        let handle: ContentQueryReadHandle
        let task: ContentQueryReadTask
        var ticket: ContentQueryReadTicket?
    }
    private var bodyReads: ContentQueryBodyReads?
    private var imageReads: ImageContentQueryReads?
    private var trashReads: TrashContentQueryReads?
    private var tagUsageReads: TagUsageContentQueryReads?
    private var bodyFacts: ContentQueryBodyReadPermit?
    private let vault: PrivacyVault
    private let owner: ContentQueryReadOwner
    private let coordinator: CommandHandoffCoordinator
    private let ownership: CommandHostOwnership
    private let notifications: ContentQueryReadNotifications
    private var subscriptions: ContentQueryReadSubscriptions?
    private var installation = UUID()
    private var tracking = UUID()
    private var rearm: Task<Void, Never>?
    private var permit: Permit?
    private var pending: Pending?
    private var preparing: UUID?
    private var displayed: ContentQueryReadPublication?
    private var pendingOpen: (UUID, ContentQueryBrowseOpen)?
    private var completionBuffer = ""
    private var cleanupFailed = false
    private(set) var isMasked = false
    private(set) var isTrackingReady = false
    private(set) var diagnostic: ContentQueryReadSessionError?
    var invalidationEpoch: UInt64 { subscriptions?.gate.state.epoch ?? 0 }
    var hasRetainedPresentation: Bool { displayed != nil }
    var hasCompletionBuffer: Bool { !completionBuffer.isEmpty }
    var hasPublicationPermit: Bool { (try? validatePermit()) != nil }
    /// 文件搜索宿主不接收或导出底层 owner，发布仍只经过本适配器。
    convenience init(vault: PrivacyVault, coordinator: CommandHandoffCoordinator,
                     ownership: CommandHostOwnership, notifications: ContentQueryReadNotifications) throws {
        try self.init(vault: vault, owner: ContentQueryReadOwner(), coordinator: coordinator,
                      ownership: ownership, notifications: notifications)
    }
    /// 使用协调者当前查询；文件读取前后、冻结与最终发布复用同一门禁。
    /// state 只描述该次读取，不赋予句柄发布资格，也不替代 provider 完整性。
    func prepareClipboard(reader: ClipboardContentQueryReader, requestID: UUID,
                          options: ContentQueryBatchOptions = .init(),
                          presentation: ContentQueryReadPresentation = .init()) throws
        -> (handle: ContentQueryReadHandle, state: ClipboardContentQueryReadState) {
        var state = ClipboardContentQueryReadState.notRequested
        let handle = try prepare(presentation: presentation) { query in
            let result = reader.read(session: query, requestID: requestID, options: options)
            state = result.state
            return result.batch
        }
        return (handle, state)
    }
    init(vault: PrivacyVault, owner: ContentQueryReadOwner, coordinator: CommandHandoffCoordinator,
         ownership: CommandHostOwnership, notifications: ContentQueryReadNotifications) throws {
        guard try coordinator.host(ownership.hostID).lease.ownership == ownership else {
            throw ContentQueryReadSessionError.staleHost
        }
        self.vault = vault
        self.owner = owner
        self.coordinator = coordinator
        self.ownership = ownership
        self.notifications = notifications
    }
    /// 依赖只接受已打开的隔离上下文；正文 Batch 和底层 owner 均不返回给装配方。
    convenience init(vault: PrivacyVault, bodyReads: ContentQueryBodyReads,
                     coordinator: CommandHandoffCoordinator, ownership: CommandHostOwnership,
                     notifications: ContentQueryReadNotifications) throws {
        try self.init(vault: vault, owner: ContentQueryReadOwner(), coordinator: coordinator,
                      ownership: ownership, notifications: notifications)
        self.bodyReads = bodyReads
    }
    func prepareBodies(observation: RoutineContentQueryObservation,
                       options: ContentQueryBatchOptions = .init(),
                       presentation: ContentQueryReadPresentation = .init()) throws -> ContentQueryReadHandle {
        guard let bodyReads else { throw ContentQueryReadSessionError.metadataOnlyRequired }
        return try prepareControlled(presentation: presentation) { query, validate in
            let capability = ContentQueryBodyReadPermit(validate: validate)
            let batch = try bodyReads.read(query: query, vault: self.vault, observation: observation,
                                           options: options, permit: capability)
            try capability.validate()
            self.bodyFacts = capability
            return batch
        }
    }
    /// 图片适配与可选原正文查询共享内部 owner；没有外部 Batch 或公开证据注入入口。
    convenience init(vault: PrivacyVault, imageReads: ImageContentQueryReads,
                     coordinator: CommandHandoffCoordinator, ownership: CommandHostOwnership,
                     notifications: ContentQueryReadNotifications) throws {
        try self.init(vault: vault, coordinator: coordinator, ownership: ownership, notifications: notifications)
        self.imageReads = imageReads
    }
    func prepareImages(observation: RoutineContentQueryObservation,
                       options: ContentQueryBatchOptions = .init(),
                       presentation: ContentQueryReadPresentation = .init()) throws -> ContentQueryReadHandle {
        guard let imageReads else { throw ContentQueryReadSessionError.metadataOnlyRequired }
        return try prepareControlled(presentation: presentation) { query, validate in
            let capability = ContentQueryBodyReadPermit(validate: validate)
            let batch = try imageReads.read(query: query, vault: self.vault, observation: observation,
                                            options: options, permit: capability)
            try capability.validate()
            self.bodyFacts = capability
            return batch
        }
    }
    convenience init(vault: PrivacyVault, trashReads: TrashContentQueryReads,
                     coordinator: CommandHandoffCoordinator, ownership: CommandHostOwnership,
                     notifications: ContentQueryReadNotifications) throws {
        try self.init(vault: vault, coordinator: coordinator, ownership: ownership, notifications: notifications)
        self.trashReads = trashReads
    }
    /// 固定当前查询并内部持有正文许可；details 只表达读取范围，不授予结果发布资格。
    func prepareTrash(requestID: UUID = UUID(), observation: RoutineContentQueryObservation,
                      options: ContentQueryBatchOptions = .init(),
                      presentation: ContentQueryReadPresentation = .init()) throws
        -> (handle: ContentQueryReadHandle, details: TrashContentQueryReadDetails) {
        guard let trashReads else { throw ContentQueryReadSessionError.metadataOnlyRequired }
        var details = TrashContentQueryReadDetails()
        let handle = try prepareControlled(presentation: presentation) { query, validate in
            let capability = ContentQueryBodyReadPermit(validate: validate)
            let result = try trashReads.read(query: query, requestID: requestID, vault: self.vault,
                observation: observation, options: options, permit: capability)
            try capability.validate()
            self.bodyFacts = capability
            details = result.1
            return result.0
        }
        return (handle, details)
    }
    convenience init(vault: PrivacyVault, tagUsageReads: TagUsageContentQueryReads,
                     coordinator: CommandHandoffCoordinator, ownership: CommandHostOwnership,
                     notifications: ContentQueryReadNotifications) throws {
        try self.init(vault: vault, coordinator: coordinator, ownership: ownership, notifications: notifications)
        self.tagUsageReads = tagUsageReads
    }

    /// 统计只在内部冻结；即使没有正文，也沿敏感来源的撤回和旧票据拒绝门禁。
    func prepareTagUsage(requestID: UUID = UUID(), observation: RoutineContentQueryObservation,
                         options: ContentQueryBatchOptions = .init(),
                         presentation: ContentQueryReadPresentation = .init()) throws
        -> (handle: ContentQueryReadHandle, details: TagUsageContentQueryDetails) {
        guard let tagUsageReads else { throw ContentQueryReadSessionError.metadataOnlyRequired }
        var details = TagUsageContentQueryDetails()
        let handle = try prepareControlled(presentation: presentation) { query, validate in
            let capability = ContentQueryBodyReadPermit(validate: validate)
            let result = try tagUsageReads.read(query: query, requestID: requestID, observation: observation,
                                                options: options, permit: capability)
            try capability.validate()
            self.bodyFacts = capability
            details = result.1
            return result.0
        }
        return (handle, details)
    }

    /// 幂等安装；不签发读取许可。重新安装也不能恢复旧任务或旧展示。
    func install() {
        guard subscriptions == nil else { return }
        installation = UUID()
        let identifier = installation
        let observers = ContentQueryReadSubscriptions()
        subscriptions = observers
        observers.observe(notifications, vault: vault) { [weak self] event in
            self?.receive(event, installation: identifier)
        }
        revokeReferences()
        track(installation: identifier)
    }

    func detach() {
        subscriptions?.detach()
        subscriptions = nil
        installation = UUID()
        rearm?.cancel()
        rearm = nil
        isTrackingReady = false
        revokeReferences()
        completionBuffer = ""
        diagnostic = .detached
    }

    deinit {
        subscriptions?.detach()
        rearm?.cancel()
        if let source = owner.source { try? owner.invalidateSource(source) }
    }

    /// 只读闭包可重入/失败，所以前后都核验；不能把外部准备好的旧查询盖成新许可。
    func prepare(presentation: ContentQueryReadPresentation = .init(),
                 read: (ContentQuerySession) throws -> ContentQueryBatch) throws -> ContentQueryReadHandle {
        try prepareControlled(presentation: presentation) { query, _ in
            let batch = try read(query)
            // 外部闭包永远没有正文权限；requestID、模式或重新解锁均不能升级旧 Batch。
            guard batch.facts.imagePrivacy == nil,
                  batch.snapshots.diaries.values?.allSatisfy({ !$0.isContentAvailable && $0.text.isEmpty }) != false else {
                throw ContentQueryReadSessionError.metadataOnlyRequired
            }
            return batch
        }
    }
    private func prepareControlled(presentation: ContentQueryReadPresentation,
        read: (ContentQuerySession, @escaping () throws -> Void) throws -> ContentQueryBatch
    ) throws -> ContentQueryReadHandle {
        let lease = try eligibleHost()
        // 新读取先撤旧来源；失败或普通 cancel 均不能保留上一份敏感结果。
        if bodyReads != nil || imageReads != nil || trashReads != nil || tagUsageReads != nil
            || (permit != nil && (try? validatePermit()) == nil) {
            revokeReferences()
        }
        let epoch = invalidationEpoch
        let stamp = ContentQueryVaultStamp(vault)
        let preparation = UUID()
        preparing = preparation
        defer { if preparing == preparation { preparing = nil } }
        let validate = { [unowned self] in
            guard self.preparing == preparation else { throw ContentQueryReadSessionError.staleTask }
            try self.validateContext(lease: lease, epoch: epoch, stamp: stamp)
        }
        let query = try coordinator.host(ownership.hostID).session.query
        let batch: ContentQueryBatch
        do { batch = try read(query, validate) }
        catch {
            // 重入的新准备不能被旧任务清理；它已拥有自己的 preparation 身份。
            if preparing == preparation { revokeReferences() }
            if let error = error as? ContentQueryReadSessionError { throw error }
            diagnostic = .readFailed
            throw ContentQueryReadSessionError.readFailed
        }
        try validate()
        guard batch.session == query else { throw ContentQueryReadSessionError.queryMismatch }
        let task = try owner.begin(batch, presentation: presentation)
        permit = .init(lease: lease, epoch: epoch, vault: stamp, source: task.source)
        let handle = ContentQueryReadHandle(id: UUID())
        pending = .init(handle: handle, task: task)
        pendingOpen = nil
        diagnostic = nil
        return handle
    }

    func evaluate(_ handle: ContentQueryReadHandle) throws {
        let task = try validateTask(handle)
        let ticket = try owner.evaluate(task)
        _ = try validateTask(handle)
        pending?.ticket = ticket
    }

    /// 同步计算结束后先让出调度，再核验并同步发布；不声称计算期间可即时中断。
    @discardableResult
    func publish(_ handle: ContentQueryReadHandle) async throws -> ContentQueryReadEffect {
        await Task.yield()
        _ = try validateTask(handle)
        guard let ticket = pending?.ticket else { throw ContentQueryReadSessionError.staleTask }
        // 此段到 displayed 赋值之间无 await、通知或调用方闭包。
        let effect = try owner.publish(ticket, focused: displayUpdates.focusedControl)
        pending = nil
        displayed = owner.published
        pendingOpen = nil
        expansionIndex = displayed.map(ContentQueryExpansionIndex.init)
        displayUpdates.send(.published)
        return effect
    }

    func continueReading(budget: RoutineOccurrenceQueryBudget) throws -> ContentQueryReadHandle {
        let current = try validatePermit()
        let task = try owner.continueReading(source: current.source, budget: budget)
        let handle = ContentQueryReadHandle(id: UUID())
        pending = .init(handle: handle, task: task)
        return handle
    }

    /// metadataOnly 保留旧取消语义；正文模式取消即释放来源和展示，隐私事件另走撤权。
    func cancel(_ handle: ContentQueryReadHandle) throws {
        let task = try validateTask(handle)
        if bodyReads != nil || imageReads != nil || trashReads != nil || tagUsageReads != nil { revokeReferences() }
        else { try owner.cancel(task); pending = nil }
    }

    func presentation() throws -> ContentQueryReadPublication {
        _ = try validatePermit()
        guard let displayed, owner.published?.task == displayed.task else {
            throw ContentQueryReadSessionError.noPresentation
        }
        return displayed
    }
    @discardableResult
    func loadMore(_ event: ContentQueryPaginationEvent) throws -> ContentQueryPaginationEffect {
        _ = try presentation()
        let effect = owner.loadMore(event, focused: displayUpdates.focusedControl)
        displayed = owner.published
        pendingOpen = nil
        if effect.didPublish { displayUpdates.send(.published) }
        return effect
    }

    /// open 留在适配器，返回 effect 去掉该字段；消费时再查资格和可见性版本。
    func browse(_ event: ContentQueryBrowseEvent) throws -> ContentQueryBrowseEffect {
        _ = try presentation()
        var effect = owner.applyBrowse(event)
        displayed = owner.published
        pendingOpen = effect.open.map { (event.version, $0) }
        effect.open = nil
        if effect.rejection == nil { displayUpdates.send(.published) }
        return effect
    }

    func consumeOpenIntent() throws -> ContentQueryBrowseOpen {
        let publication = try presentation()
        guard let (version, intent) = pendingOpen, version == publication.pagination.snapshot.version else {
            throw ContentQueryReadSessionError.noOpenIntent
        }
        pendingOpen = nil
        return intent
    }

    /// 普通操作面板复用宿主展示门禁；不读取业务基线，不取得正文许可。
    func validateDisplayHost(expecting lease: CommandHostLease) throws {
        guard try eligibleHost() == lease else { throw ContentQueryReadSessionError.staleHost }
    }

    func setCompletionBuffer(_ value: String, expecting lease: CommandHostLease) throws {
        guard try eligibleHost() == lease else { throw ContentQueryReadSessionError.staleHost }
        completionBuffer = value
    }

    /// 仅当前宿主的输入信号；失焦不自动锁定、认证或提交。refocus 本身不解除遮罩。
    func loseFocus(expecting ownership: CommandHostOwnership) throws {
        guard ownership == self.ownership else { throw ContentQueryReadSessionError.staleHost }
        try checkOwnership()
        subscriptions?.gate.revoke()
        isMasked = true
        let displayRevision = displayUpdates.revision
        revokeReferences()
        if displayUpdates.revision == displayRevision { displayUpdates.send(.invalidated) }
    }

    func resumeDisplay(expecting lease: CommandHostLease) throws {
        try checkOwnership()
        try coordinator.validate(lease)
        guard lease.ownership == ownership else { throw ContentQueryReadSessionError.staleHost }
        isMasked = false
        // 只允许下一次显式 prepare；没有恢复旧许可或结果。
    }

    /// 未保存变化由宿主明确调用；通知缺席不能被解释为模型未变。
    func modelDidChange(expecting ownership: CommandHostOwnership) throws {
        guard ownership == self.ownership else { throw ContentQueryReadSessionError.staleHost }
        try checkOwnership()
        subscriptions?.gate.revoke()
        revokeReferences()
    }
    private func receive(_ event: ContentQueryReadInvalidation, installation identifier: UUID) {
        guard installation == identifier, let subscriptions, subscriptions.gate.state.active else { return }
        if event == .mask || event == .focusLost { isMasked = true }
        // gate 已在同步 SDK 回调入口推进；普通参数面板也需收到无搜索资料时的撤显示通知。
        let displayRevision = displayUpdates.revision
        revokeReferences()
        if isMasked, displayUpdates.revision == displayRevision { displayUpdates.send(.invalidated) }
        if event == .willLock {
            completionBuffer = ""
            do { try coordinator.invalidateSearch(ownedBy: ownership) }
            catch { diagnostic = .staleHost }
            displayUpdates.send(.privacyInvalidated)
        }
        if subscriptions.gate.state.unexpectedExecutor { diagnostic = .unexpectedExecutor }
        if event == .observation || event == .willLock || event == .privacyChanged {
            scheduleTracking(installation: identifier)
        }
    }
    private func track(installation identifier: UUID) {
        guard identifier == installation, let subscriptions, subscriptions.gate.state.active else { return }
        let generation = UUID()
        tracking = generation
        let gate = subscriptions.gate
        let token = subscriptions.beginTracking()
        withObservationTracking {
            _ = ContentQueryVaultStamp(vault)
            _ = coordinator.ownershipRevision
        } onChange: { [weak self] in
            guard token.state.active else { return }
            gate.deliver(.observation) { [weak self] event in
                guard let self, self.tracking == generation else { return }
                self.receive(event, installation: identifier)
            }
        }
        isTrackingReady = !gate.state.unexpectedExecutor
    }
    private func scheduleTracking(installation identifier: UUID) {
        isTrackingReady = false
        subscriptions?.stopTracking()
        // onChange 是 will-change；原 setter 返回之前不得在旧字段上重新打开门禁。
        // 多次通知只保留一个重订阅任务，空窗内无许可，结束后仍须显式 prepare。
        guard rearm == nil else { return }
        rearm = Task { @MainActor [weak self] in
            guard let self, !Task.isCancelled, self.installation == identifier else { return }
            self.rearm = nil
            self.track(installation: identifier)
        }
    }
    private func revokeReferences() {
        let hadReferences = displayed != nil || permit != nil || pending != nil
        bodyFacts = nil
        permit = nil
        preparing = nil
        pending = nil
        pendingOpen = nil
        displayed = nil
        expansionIndex = nil
        if let source = owner.source {
            do { try owner.invalidateSource(source) }
            catch { cleanupFailed = true; diagnostic = .cleanupFailed }
        }
        if hadReferences { displayUpdates.send(.invalidated) }
    }
    private func checkOwnership() throws {
        guard try coordinator.host(ownership.hostID).lease.ownership == ownership else {
            revokeReferences()
            diagnostic = .staleHost
            throw ContentQueryReadSessionError.staleHost
        }
    }
    private func eligibleHost() throws -> CommandHostLease {
        guard let subscriptions, subscriptions.gate.state.active else { throw ContentQueryReadSessionError.detached }
        guard !subscriptions.gate.state.unexpectedExecutor else { throw ContentQueryReadSessionError.unexpectedExecutor }
        guard !cleanupFailed else { throw ContentQueryReadSessionError.cleanupFailed }
        guard isTrackingReady else { throw ContentQueryReadSessionError.trackingPending }
        try checkOwnership()
        guard !isMasked else { throw ContentQueryReadSessionError.masked }
        guard !vault.isAuthenticating, !vault.isChangingMethods else { throw ContentQueryReadSessionError.vaultBusy }
        guard vault.state != .unavailable else { throw ContentQueryReadSessionError.vaultUnavailable }
        let host = try coordinator.host(ownership.hostID)
        guard host.session.query.binding != .independent(.privacyInvalidated) else {
            throw ContentQueryReadSessionError.pageContextRequired
        }
        return host.lease
    }
    private func validateContext(lease: CommandHostLease, epoch: UInt64, stamp: ContentQueryVaultStamp) throws {
        guard try eligibleHost() == lease, invalidationEpoch == epoch, ContentQueryVaultStamp(vault) == stamp else {
            revokeReferences()
            diagnostic = .stalePermit
            throw ContentQueryReadSessionError.stalePermit
        }
    }
    private func validatePermit() throws -> Permit {
        guard let permit else { throw ContentQueryReadSessionError.stalePermit }
        do {
            try validateContext(lease: permit.lease, epoch: permit.epoch, stamp: permit.vault)
            try bodyFacts?.validateFacts()
            guard owner.source == permit.source else { throw ContentQueryReadSessionError.stalePermit }
        } catch {
            revokeReferences()
            throw error
        }
        return permit
    }
    private func validateTask(_ handle: ContentQueryReadHandle) throws -> ContentQueryReadTask {
        _ = try validatePermit()
        guard let pending, pending.handle == handle, owner.request == pending.task else {
            throw ContentQueryReadSessionError.staleTask
        }
        return pending.task
    }
}

/// 仅 prepareControlled 当前校验路径生成，不可由调用方拼装或取出。
@MainActor
final class ContentQueryBodyReadPermit {
    private let check: () throws -> Void
    private var facts: [() throws -> Void] = []
    fileprivate init(validate: @escaping () throws -> Void) { check = validate }
    func validate() throws { try check(); try validateFacts() }
    func retainFacts(_ check: @escaping () throws -> Void) { facts.append(check) }
    func validateFacts() throws {
        do { for check in facts { try check() } }
        catch let error as ContentQueryReadSessionError { throw error }
        catch { throw ContentQueryReadSessionError.readFailed }
    }
}
