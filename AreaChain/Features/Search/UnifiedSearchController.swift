import Foundation
import Observation

/// 输入缓冲与只读结果的组合。业务查询仍属于协调者，选择/展开仍属于 ReadSession。
@Observable @MainActor
final class UnifiedSearchController {
    private(set) var buffer: UnifiedSearchBuffer
    var navigationRouter: WorkspaceSearchRouter?
    var returnSearch: UnifiedSearchReturnContext?
    /// 为指令回到搜索页的异步过程进行中；期间再按 Return 不重复返回和重读。
    @ObservationIgnored var commandReturnPending = false
    var navigationQueryRevision: UInt64 = 0
    @ObservationIgnored var captureSearchScroll: (() -> CGPoint?)?
    var restoreSearchScroll: (version: UUID, point: CGPoint)?
    var preservedSearchScrollVersion: UUID?
    var navigationMessage = "unified.navigation.hint"
    /// help.syntax／help.example 在导航面板里打开语法帮助卡。
    var helpCardPresented = false
    var contentOwnerMessage = "unified.content.ownerHint"
    @ObservationIgnored var navigationTask: Task<Void, Never>?
    var navigationRequestID: UUID?
    var inputFocused = true
    var editingParameter: CommandParameterID?
    @ObservationIgnored var workspaceHandoff: UnifiedSearchWorkspaceHandoff?
    @ObservationIgnored var trustedPage: (() -> ContentQueryPageContext)?
    @ObservationIgnored var contentCommandTask: Task<Void, Never>?
    @ObservationIgnored var resumeTask: Task<Void, Never>?
    var objectSelectionLocation: String?
    var messageKey = "unified.results.awaiting"
    private(set) var revision: UInt64 = 0
    private(set) var controlFocus: ContentQueryDisplayControl?
    private(set) var focusRevision: UInt64 = 0
    let session: ContentQueryReadSession
    let inputReset = UnifiedSearchInputReset()
    @ObservationIgnored let coordinator: CommandHandoffCoordinator

    @ObservationIgnored private let read: () async throws -> ContentQueryReadEffect
    @ObservationIgnored private let recordOpen: (ContentQueryBrowseOpen) -> Void
    @ObservationIgnored private var observer: UUID?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored var focusResults: ((ContentQueryBrowseFocus) -> Void)?

    init(session: ContentQueryReadSession, coordinator: CommandHandoffCoordinator,
         buffer: UnifiedSearchBuffer, read: @escaping () async throws -> ContentQueryReadEffect,
         recordOpen: @escaping (ContentQueryBrowseOpen) -> Void) {
        self.session = session
        self.coordinator = coordinator
        self.buffer = buffer
        self.read = read
        self.recordOpen = recordOpen
        observer = session.displayUpdates.observe { [weak self] change in self?.changed(change) }
    }

    var actions: UnifiedSearchActions {
        .init(edit: edit, accept: accept, focus: { [weak self] in self?.inputFocused = $0 },
              intent: { [weak self] in self?.intent($0, source: $1) },
              disposition: { [weak self] in self?.disposition(for: $0) ?? .unwired })
    }

    var operationVisible: Bool {
        !session.isMasked
            && (try? session.validateDisplayHost(expecting: buffer.lease)) != nil
            && !isNavigationPresented
    }

    var queryInputText: String {
        guard let query = try? coordinator.host(buffer.lease.ownership.hostID).session.query,
              case .content(let content) = query.input else { return "" }
        return content.source
    }

    var isCommandInput: Bool {
        let state = CommandPathParser().parse(.init(text: buffer.text, cursorLocation: buffer.text.utf16.count)).state
        return state != .ordinaryText && state != .scope
    }

    var browsedCommand: CommandDescriptor? {
        CommandPathParser().parse(.init(text: buffer.text, cursorLocation: buffer.text.utf16.count)).command
    }

    var hasUnsavedCommandWork: Bool { false }

    var hidesResultsForCommand: Bool {
        guard isCommandInput else { return false }
        guard let command = browsedCommand else { return true }
        return command.targetTypes.isEmpty && !["inspector.open", "go.tagList", "occurrence.inspect"].contains(command.id.rawValue)
    }

    var showsNavigationMessage: Bool {
        navigationMessage != "unified.navigation.hint"
    }

    func validates(_ source: UnifiedSearchBuffer) -> Bool {
        source.lease == buffer.lease
            && source.version == buffer.version
            && source.privacyRevision == buffer.privacyRevision
            && (try? coordinator.validate(buffer.lease)) != nil
    }

    func accept(_ request: UnifiedSearchEdit) -> UnifiedSearchBuffer? {
        guard let request = resumedRequest(request, reread: true) else { return nil }
        guard validates(request.source), let acceptance = request.acceptance, acceptance.text == request.text else { return nil }
        clearBlockedHandoff()
        cliSession.updateForInput(request.text)
        let state = CommandPathParser().parse(.init(text: request.text, cursorLocation: request.selection.location)).state
        if state == .ordinaryText || state == .scope {
            return edit(.init(source: request.source, text: request.text, selection: request.selection))
        }
        showSearchForCommandOnOriginalPage()
        return publishOperation(text: request.text)
    }

    func edit(_ request: UnifiedSearchEdit) -> UnifiedSearchBuffer? {
        guard validates(request.source) else { return nil }
        clearBlockedHandoff()
        cliSession.updateForInput(request.text)
        if request.text != buffer.text { navigationMessage = "unified.navigation.hint" }
        let state = CommandPathParser().parse(.init(text: request.text, cursorLocation: request.selection.location)).state
        let content = state == .ordinaryText || state == .scope
        guard let request = resumedRequest(request, reread: !content) else { return nil }
        if content {
            newNavigationQuery()
            do {
                try session.modelDidChange(expecting: buffer.lease.ownership)
                try coordinator.send(.query(.setInput(request.text)), expecting: request.source.lease)
            } catch { reportGate(); return nil }
        } else { showSearchForCommandOnOriginalPage() }
        guard let owned = try? coordinator.host(buffer.lease.ownership.hostID) else { return nil }
        buffer = .init(lease: owned.lease, version: buffer.version + 1, text: request.text,
                       privacyRevision: buffer.privacyRevision)
        if content {
            navigationRouter?.navigation.searchPresentation = owned.session.query.showsResults
            refresh()
        }
        return buffer
    }

    /// 显式重读与“加载更多”分离；异步完成不能覆盖之后的输入或新所有权。
    func refresh() {
        task?.cancel()
        let source = buffer
        task = Task { @MainActor [weak self] in
            guard let self, self.validates(source), !self.isCommandInput else { return }
            do {
                let effect = try await self.readObjectSource()
                guard self.validates(source), !Task.isCancelled else { return }
                self.applyFocus(effect.pagination?.browse.focus)
            } catch {
                guard self.validates(source), !Task.isCancelled else { return }
                self.messageKey = self.session.isMasked ? "unified.results.masked" : "unified.results.readFailed"
                if let gate = error as? ContentQueryReadSessionError, Self.explainedGates.contains(gate) { self.reportGate(gate) }
                self.revision &+= 1
            }
        }
    }

    func intent(_ intent: UnifiedSearchIntent, source: UnifiedSearchBuffer) {
        guard validates(source) else { return }
        if session.isMasked || (trustedPage != nil && queryAwaitsTrustedPage), intent != .escape {
            resumeForExplicitAction(source: source) { [weak self] renewed in self?.intent(intent, source: renewed) }
            return
        }
        if intent == .open, handOffToWorkspace(source) { return }
        if isNavigationInput {
            if intent == .submit { return }
            if intent == .open { executeNavigation(source: source); return }
            if intent == .escape { _ = navigationInput(queryInputText); return }
            if hidesResultsForCommand { return }
        }
        if returnForCommand(intent) { return }
        if handleCLIIntentIfApplicable(intent, source: source) { return }
        if hidesResultsForCommand, case .results = intent { return }
        guard let publication = try? session.presentation() else { return }
        let version = publication.pagination.snapshot.version
        switch intent {
        case .results(let direction):
            browse(.init(version: version, action: .move(direction > 0 ? .next : .previous, inputEditing: false)), source: source)
        case .open:
            guard !isCommandInput else { return }
            browse(.init(version: version, action: .open(inputEditing: false)), source: source)
        case .escape:
            browse(.init(version: version, action: .focusInput), source: source)
        case .submit, .selectActive: break
        }
    }

    func browse(_ event: ContentQueryBrowseEvent, source: UnifiedSearchBuffer) {
        guard validates(source), let effect = try? session.browse(event), effect.rejection == nil else { return }
        applyFocus(effect.focus)
        if case .open = event.action, let open = try? session.consumeOpenIntent() {
            if navigationRouter != nil { openResult(open, source: source) }
            else { recordOpen(open); navigationMessage = "unified.navigation.unassembled" }
        }
    }

    func load(_ event: ContentQueryPaginationEvent, source: UnifiedSearchBuffer) {
        guard validates(source), let effect = try? session.loadMore(event), effect.didPublish else { return }
        applyFocus(effect.browse.focus)
    }

    func detach() {
        invalidateNavigation(privacy: true)
        contentCommandTask?.cancel(); contentCommandTask = nil
        resumeTask?.cancel(); resumeTask = nil
        task?.cancel()
        if let observer { session.displayUpdates.remove(observer) }
        observer = nil; focusResults = nil; captureSearchScroll = nil; restoreSearchScroll = nil
        UnifiedSearchCLISession.removeSession(for: self)
        session.detach()
    }

    @discardableResult
    func publishOperation(text: String) -> UnifiedSearchBuffer? {
        guard let owned = try? coordinator.host(buffer.lease.ownership.hostID),
              owned.lease.ownership == buffer.lease.ownership else { return nil }
        buffer = .init(lease: owned.lease, version: buffer.version + 1, text: text,
            privacyRevision: buffer.privacyRevision)
        revision &+= 1
        return buffer
    }

    func replaceOperationInputText(_ text: String) {
        buffer = .init(lease: buffer.lease, version: buffer.version, text: text,
            privacyRevision: buffer.privacyRevision)
    }

    func refreshOperationPresentation() { revision &+= 1 }

    func readObjectSource() async throws -> ContentQueryReadEffect {
        let contents = navigationRouter?.contents
        let source = try contents?.captureSource()
        let effect = try await read()
        if let source { try contents?.bindSource(source, publication: session.presentation()) }
        return effect
    }

    func setObjectInputMode(_ selecting: Bool) {
        guard buffer.selectingObjects != selecting else { return }
        buffer = .init(lease: buffer.lease, version: buffer.version + 1, text: buffer.text,
            privacyRevision: buffer.privacyRevision, selectingObjects: selecting)
        revision &+= 1
    }

    func renewObjectCandidateSource() {
        buffer = .init(lease: buffer.lease, version: buffer.version + 1, text: buffer.text,
            privacyRevision: buffer.privacyRevision, selectingObjects: true)
        revision &+= 1
    }

    private func applyFocus(_ focus: ContentQueryBrowseFocus?) {
        guard let focus else { return }
        if focus == .input { session.displayUpdates.focusedControl = nil; inputFocused = true }
        else {
            inputFocused = false
            focusResults?(focus)
            if case .control(let control) = focus {
                controlFocus = control
                focusRevision &+= 1
            }
        }
    }

    private func changed(_ change: ContentQueryDisplayUpdates.Change) {
        revision &+= 1
        if change != .published, navigationRouter?.contents?.content != nil || navigationRouter?.contents?.loading == true {
            navigationRouter?.contents?.invalidate()
            navigationMessage = "unified.content.stale"
        }
        if change != .published, navigationRouter?.navigation.navigationObject != nil {
            invalidateNavigation(privacy: change == .privacyInvalidated)
        }
        if change == .privacyInvalidated {
            invalidateNavigation(privacy: true)
            task?.cancel()
            let current = try? coordinator.host(buffer.lease.ownership.hostID).lease
            let lease = current?.ownership == buffer.lease.ownership ? current! : buffer.lease
            buffer = .init(lease: lease, version: buffer.version + 1, text: "",
                           privacyRevision: buffer.privacyRevision + 1)
            editingParameter = nil
            inputReset.invalidate(buffer)
            messageKey = "unified.results.invalidated"
        } else if change == .invalidated {
            if session.isMasked {
                buffer = .init(lease: buffer.lease, version: buffer.version + 1, text: buffer.text,
                    privacyRevision: buffer.privacyRevision)
            }
            messageKey = session.isMasked ? "unified.results.masked" : "unified.results.awaiting"
        }
    }

    func renewBuffer(_ lease: CommandHostLease) {
        buffer = .init(lease: lease, version: buffer.version + 1, text: buffer.text,
                       privacyRevision: buffer.privacyRevision, selectingObjects: buffer.selectingObjects)
    }
}
