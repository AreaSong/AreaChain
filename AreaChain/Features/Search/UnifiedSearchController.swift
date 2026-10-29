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
    /// 合并批 M-3：help.syntax／help.example 在导航面板里打开语法帮助卡。
    var helpCardPresented = false
    var contentOwnerMessage = "unified.content.ownerHint"
    @ObservationIgnored var navigationTask: Task<Void, Never>?
    var navigationRequestID: UUID?
    var inputFocused = true
    @ObservationIgnored var longTextContent: CommandDraftContentSession?
    var longTextEditing: UnifiedSearchLongTextEditing?
    var longTextMessage: String?
    /// 超限旧稿只记字段身份，不持正文；有值时长文区改显上限提示、清空与原入口引导。
    var longTextOversized: UnifiedSearchLongTextOversize?
    var operationExpanded = true
    var planMessage = "unified.plan.notExecutable"
    var planRemovalDependents: [UUID] = []
    var planReturnItem: UUID?
    var planReturnRevision: UInt64 = 0
    var editingParameter: CommandParameterID?
    var operationMessage = "unified.operation.notExecuted"
    var taskCreatePreparation: CommandTaskCreatePreparation?
    var taskCreateFailure: TaskCreateCommandIssue?
    var taskCreateVerification: CommandTaskCreateVerification?
    var taskTitlePreview: CommandTaskTitlePreview?
    var taskTitleAcceptance: CommandTaskTitleAcceptance?
    var taskTitleFailure: String?
    var taskTitleVerification: CommandTaskTitleVerification?
    var batchPreview: CommandBatchPreview?
    var batchAcceptance: CommandBatchAcceptance?
    var batchFailure: String?
    var batchProblems: [CommandBatchTargetProblem] = []
    var taskFieldPreview: CommandTaskFieldPreview?
    var taskFieldAcceptance: CommandTaskFieldAcceptance?
    var taskFieldFailure: String?
    var taskFieldVerification: CommandTaskCreateVerification?
    var routinePreview: CommandRoutinePreview?
    var routineAcceptance: CommandRoutineAcceptance?
    var routineFailure: String?
    var routineVerification: CommandTaskCreateVerification?
    var routineCreatePreview: CommandRoutineCreatePreview?
    var routineCreateAcceptance: CommandRoutineCreateAcceptance?
    var routineCreateFailure: String?
    var routineCreateVerification: CommandTaskCreateVerification?
    var subtaskPreview: CommandSubtaskPreview?
    var subtaskAcceptance: CommandSubtaskAcceptance?
    var subtaskFailure: String?
    var subtaskVerification: CommandTaskCreateVerification?
    var trashPreview: CommandTrashPreview?
    var trashAcceptance: CommandTrashAcceptance?
    var trashConfirmation: CommandTrashConfirmation?
    /// 独立确认面板（回收与转换共用）的默认焦点修订。
    var confirmationFocus: UInt64 = 0
    var trashFailure: String?
    var trashProblems: [CommandTrashTargetProblem] = []
    var convertPreview: CommandConvertPreview?
    var convertAcceptance: CommandConvertAcceptance?
    var convertConfirmation: CommandConvertConfirmation?
    var convertFailure: String?
    var convertVerification: CommandConvertVerification?
    var simplePreview: CommandSimplePreview?
    var simpleAcceptance: CommandSimpleAcceptance?
    var simpleFailure: String?
    var simpleVerification: CommandSimpleVerification?
    /// 合并批 M-2：需要独立确认的简单指令在共用确认面板里的当前确认。
    var simpleConfirmation: CommandSimpleConfirmation?
    var taskCopyPreview: CommandTaskCopyPreview?
    var taskCopyResult: CommandTaskCopyResult?
    var taskCopyFailure: String?
    /// 合并批 M-1 C 页面指令；默认未装配（nil），生产没有构造点。
    @ObservationIgnored var pageCommands: WorkspacePageCommands?
    @ObservationIgnored var workspaceHandoff: UnifiedSearchWorkspaceHandoff? // 只有菜单栏装配；工作台为 nil
    @ObservationIgnored var trustedPage: (() -> ContentQueryPageContext)? // 宿主当前页面，锁定清查询后重建用
    var pagePreview: WorkspacePagePreview?
    var pageReceipt: WorkspacePageReceipt?
    var pageFailure: CommandPageIssue?
    /// 合并批 M-2：image.preview 先按当前查询重读结果再沿 N-M2 打开；这一步的任务。
    @ObservationIgnored var contentCommandTask: Task<Void, Never>?
    /// 修复批 M-7G：失焦遮罩后显式恢复的重读任务（UnifiedSearchDisplayResume）。
    @ObservationIgnored var resumeTask: Task<Void, Never>?
    var clipboardCapture = UnifiedSearchClipboardCaptureState()
    var chainCreationPreparation: CommandTaskCreatePreparation?
    var chainFailure: String?
    var multiPlanFailure: String?
    @ObservationIgnored var multiPlanTask: Task<Void, Never>?
    var taskCompositionPreview: CommandTaskCreatePreview?
    var taskCompositionAccepted: CommandTaskCreatePreparation?
    var compositionFailure: String?
    var tagSelection: UnifiedSearchTagSelection?
    var tagReturnRevision: UInt64 = 0
    var tagReturnDraftID: UUID?
    var settingSubmitting = false
    var settingFailure: UnifiedSearchSettingFailure?
    var settingConfirmation: UnifiedSearchSettingConfirmation?
    var settingMessage = "unified.setting.pending"
    var objectSelection: UnifiedSearchObjectSelection?
    var objectSelectionLocation: UnifiedSearchObjectLocation?
    var objectSelectionLoading = false
    var objectRequestID: UUID?
    var objectSelectionMessage = "unified.objects.hint"
    var objectReturnLocation: UnifiedSearchObjectLocation?
    var objectReturnRevision: UInt64 = 0
    @ObservationIgnored var objectSelectionTask: Task<Void, Never>?
    // 只保存原生未完成文字，不是可提交的参数字典；合法值唯一存在 operations 或 plan。
    var parameterText: [UUID: [CommandParameterID: UnifiedSearchParameterBuffer]] = [:]
    @ObservationIgnored var syntheticBaselines: [CommandID: CommandDraftBaseline] = [:]
    var messageKey = "unified.results.awaiting"
    private(set) var revision: UInt64 = 0
    private(set) var controlFocus: ContentQueryDisplayControl?
    private(set) var focusRevision: UInt64 = 0
    let session: ContentQueryReadSession
    let inputReset = UnifiedSearchInputReset()
    @ObservationIgnored let coordinator: CommandHandoffCoordinator
    @ObservationIgnored let taskCreate: TaskCreateCommandAdapter?
    @ObservationIgnored let taskTitle: TaskTitleCommandAdapter?
    @ObservationIgnored let batch: BatchCommandAdapter?
    @ObservationIgnored let taskField: TaskFieldCommandAdapter?
    @ObservationIgnored let routine: RoutineCommandAdapter?
    @ObservationIgnored let subtask: SubtaskCommandAdapter?
    @ObservationIgnored let multiPlan: MultiPlanCommandAdapter?
    @ObservationIgnored let taskChain: TaskChainCommandAdapter?
    @ObservationIgnored let trash: TrashCommandAdapter?
    @ObservationIgnored let taskCopy: TaskCopyCommandAdapter?
    @ObservationIgnored let convert: ConvertCommandAdapter?
    @ObservationIgnored let simple: SimpleCommandAdapter?
    @ObservationIgnored let clipboard: ClipboardCaptureCommandAdapter?
    @ObservationIgnored let settingBackend: UnifiedSearchSettingBackend
    var fileSettingFailure: UnifiedSearchFileSettingFailure?
    var fileSettingConfirmation: UnifiedSearchFileSettingConfirmation?

    @ObservationIgnored private let read: () async throws -> ContentQueryReadEffect
    @ObservationIgnored private let recordOpen: (ContentQueryBrowseOpen) -> Void
    @ObservationIgnored private var observer: UUID?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored var focusResults: ((ContentQueryBrowseFocus) -> Void)?

    convenience init(session: ContentQueryReadSession, coordinator: CommandHandoffCoordinator,
         buffer: UnifiedSearchBuffer, read: @escaping () async throws -> ContentQueryReadEffect,
         recordOpen: @escaping (ContentQueryBrowseOpen) -> Void,
         localSettings: LocalSettingCommandAdapter? = nil, taskCreate: TaskCreateCommandAdapter? = nil,
         taskTitle: TaskTitleCommandAdapter? = nil, taskField: TaskFieldCommandAdapter? = nil,
         taskChain: TaskChainCommandAdapter? = nil, subtask: SubtaskCommandAdapter? = nil, routine: RoutineCommandAdapter? = nil, batch: BatchCommandAdapter? = nil, multiPlan: MultiPlanCommandAdapter? = nil) {
        self.init(session: session, coordinator: coordinator, buffer: buffer, read: read, recordOpen: recordOpen,
                  settingBackend: localSettings.map(UnifiedSearchSettingBackend.legacy) ?? .unassembled,
                  taskCreate: taskCreate, taskTitle: taskTitle, taskField: taskField, taskChain: taskChain,
                  subtask: subtask, routine: routine, batch: batch, multiPlan: multiPlan)
    }

    init(session: ContentQueryReadSession, coordinator: CommandHandoffCoordinator,
         buffer: UnifiedSearchBuffer, read: @escaping () async throws -> ContentQueryReadEffect,
         recordOpen: @escaping (ContentQueryBrowseOpen) -> Void, settingBackend: UnifiedSearchSettingBackend,
         taskCreate: TaskCreateCommandAdapter? = nil, taskTitle: TaskTitleCommandAdapter? = nil,
         taskField: TaskFieldCommandAdapter? = nil, taskChain: TaskChainCommandAdapter? = nil, subtask: SubtaskCommandAdapter? = nil, routine: RoutineCommandAdapter? = nil, batch: BatchCommandAdapter? = nil, multiPlan: MultiPlanCommandAdapter? = nil,
         trash: TrashCommandAdapter? = nil, taskCopy: TaskCopyCommandAdapter? = nil, convert: ConvertCommandAdapter? = nil,
         simple: SimpleCommandAdapter? = nil, clipboard: ClipboardCaptureCommandAdapter? = nil) {
        self.session = session
        self.clipboard = clipboard
        self.trash = trash
        self.taskCopy = taskCopy
        self.convert = convert
        self.simple = simple
        self.coordinator = coordinator
        self.settingBackend = settingBackend
        self.taskCreate = taskCreate
        self.taskTitle = taskTitle
        self.batch = batch
        self.taskField = taskField
        self.subtask = subtask
        self.routine = routine
        self.taskChain = taskChain
        self.multiPlan = multiPlan
        var initial = buffer
        initial.plan = try? coordinator.host(buffer.lease.ownership.hostID).session.plan.stamp
        self.buffer = initial
        self.read = read
        self.recordOpen = recordOpen
        observer = session.displayUpdates.observe { [weak self] change in self?.changed(change) }
    }

    var actions: UnifiedSearchActions {
        .init(edit: edit, accept: accept, focus: { [weak self] in self?.inputFocused = $0 },
              intent: { [weak self] in self?.intent($0, source: $1) },
              disposition: { [weak self] in self?.disposition(for: $0) ?? .unwired })
    }

    func edit(_ request: UnifiedSearchEdit) -> UnifiedSearchBuffer? {
        guard validates(request.source) else { return nil }
        guard objectSelection == nil, !objectSelectionLoading, tagSelection == nil else { return nil }
        clearBlockedHandoff()
        let state = CommandPathParser().parse(.init(text: request.text, cursorLocation: request.selection.location)).state
        let content = state == .ordinaryText || state == .scope
        // 改字是显式动作：遮罩时先恢复；普通文字随后按新文字重读，指令文字按保留的查询重读。
        guard let request = resumedRequest(request, reread: !content || inputParameterContext != nil) else { return nil }
        if let context = inputParameterContext { return editParameterText(request, context: context, mainInput: true) }
        if content {
            newNavigationQuery()
            do {
                try session.modelDidChange(expecting: buffer.lease.ownership)
                try coordinator.send(.query(.setInput(request.text)), expecting: request.source.lease)
            } catch { reportGate(); return nil }
        } else { showSearchForCommandOnOriginalPage() }
        guard let owned = try? coordinator.host(buffer.lease.ownership.hostID) else { return nil }
        buffer = .init(lease: owned.lease, version: buffer.version + 1, text: request.text,
                       privacyRevision: buffer.privacyRevision, operation: editingDraft?.stamp, plan: plan?.stamp, planItem: editingPlanItem?.stamp)
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
        // Return、⌘Return、↑↓、空格选择是显式动作：遮罩时先恢复并重读，读完再处理这次动作；Esc 不恢复。
        if session.isMasked || (trustedPage != nil && queryAwaitsTrustedPage), intent != .escape {
            resumeForExplicitAction(source: source) { [weak self] renewed in self?.intent(intent, source: renewed) }
            return
        }
        if intent == .open, handOffToWorkspace(source) { return }
        if returnForCommand(intent) { return }
        if isNavigationInput {
            if intent == .submit { return }
            if intent == .open { executeNavigation(source: source); return }
            if intent == .escape { _ = navigationInput(queryInputText); return }
            if hidesResultsForCommand { return }
        }
        if hasIndependentConfirmation {
            // 独立确认期间只接受 Esc 取消；提交、打开和结果移动都不能越过确认。
            if intent == .escape { cancelIndependentConfirmation() }
            return
        }
        if intent == .submit { requestOperationSubmit(source); return }
        if let picker = tagSelection {
            switch intent {
            case .escape: cancelTags(picker.id)
            case .open: acceptTags(picker)
            case .results(let direction): moveTag(direction > 0 ? 1 : -1, picker: picker)
            case .selectActive: if let id = picker.active { toggleTag(id, picker: picker) }
            case .submit: break
            }
            return
        }
        if let picker = objectSelection {
            switch intent {
            case .escape: cancelObjectSelection()
            case .open: _ = acceptObjects(picker.stamp)
            case .results(let direction):
                browseObjects(.move(direction > 0 ? .next : .previous, inputEditing: false), stamp: picker.stamp)
            case .selectActive:
                if let active = picker.browse.active { toggleObject(active, stamp: picker.stamp) }
            case .submit: break
            }
            return
        }
        if objectSelectionLoading {
            if intent == .escape { cancelObjectSelection() }
            return
        }
        if intent == .open, isCommandInput {
            if editingParameter != nil { finishParameter(source) }
            else if let command = browsedCommand { _ = beginOperation(command.id, source: source) }
            return
        }
        if intent == .escape, editingParameter != nil { finishParameter(source); return }
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
        endLongText()
        invalidateNavigation(privacy: true)
        multiPlan?.invalidatePresentation()
        multiPlanTask?.cancel()
        multiPlanTask = nil
        chainCreationPreparation = nil
        revokeRoutine()
        revokeSubtask()
        revokeBatch()
        revokeTrash()
        revokeTaskCopy()
        revokePage()
        revokeConvert()
        revokeSimple()
        clipboardCapture = .init()
        revokeTaskField()
        revokeTaskTitle()
        revokeTaskComposition()
        cancelObjectSelection(returnFocus: false)
        contentCommandTask?.cancel()
        contentCommandTask = nil
        resumeTask?.cancel()
        resumeTask = nil
        task?.cancel()
        if let observer { session.displayUpdates.remove(observer) }
        observer = nil
        focusResults = nil
        captureSearchScroll = nil
        restoreSearchScroll = nil
        session.detach()
    }

    @discardableResult
    func publishOperation(text: String) -> UnifiedSearchBuffer? {
        guard let owned = try? coordinator.host(buffer.lease.ownership.hostID),
              owned.lease.ownership == buffer.lease.ownership else { return nil }
        buffer = .init(lease: owned.lease, version: buffer.version + 1, text: text,
            privacyRevision: buffer.privacyRevision, operation: editingDraft?.stamp, plan: owned.session.plan.stamp, planItem: editingPlanItem?.stamp)
        revision &+= 1
        taskCreateFailure = nil
        chainCreationPreparation = nil
        chainFailure = nil
        revokeRoutine()
        revokeSubtask()
        subtaskFailure = nil
        routineFailure = nil
        revokeBatch()
        revokeTrash()
        trashFailure = nil
        trashProblems = []
        revokeTaskCopy()
        revokePage()
        pageFailure = nil
        taskCopyFailure = nil
        revokeConvert()
        convertFailure = nil
        convertVerification = nil
        revokeSimple()
        clipboardCapture.revoke()
        simpleFailure = nil
        simpleVerification = nil
        revokeTaskField()
        taskFieldFailure = nil
        revokeTaskTitle()
        taskTitleFailure = nil
        revokeTaskComposition()
        compositionFailure = nil
        settingFailure = nil
        settingConfirmation = nil
        fileSettingFailure = nil
        fileSettingConfirmation = nil
        settingMessage = "unified.setting.pending"
        return buffer
    }

    func replaceOperationInputText(_ text: String) {
        buffer = .init(lease: buffer.lease, version: buffer.version, text: text,
            privacyRevision: buffer.privacyRevision, operation: buffer.operation, plan: buffer.plan, planItem: buffer.planItem)
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
            privacyRevision: buffer.privacyRevision, operation: buffer.operation, selectingObjects: selecting, plan: buffer.plan, planItem: buffer.planItem)
        revision &+= 1
    }

    func renewObjectCandidateSource() {
        buffer = .init(lease: buffer.lease, version: buffer.version + 1, text: buffer.text,
            privacyRevision: buffer.privacyRevision, operation: buffer.operation, selectingObjects: true,
            plan: buffer.plan, planItem: buffer.planItem)
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
        if change == .privacyInvalidated || session.isMasked { endLongText() }
        revision &+= 1
        if change == .privacyInvalidated || session.isMasked { multiPlan?.invalidatePresentation() }
        if change != .published, navigationRouter?.contents?.content != nil || navigationRouter?.contents?.loading == true {
            navigationRouter?.contents?.invalidate()
            navigationMessage = "unified.content.stale"
        }
        if change != .published, navigationRouter?.navigation.navigationObject != nil {
            invalidateNavigation(privacy: change == .privacyInvalidated)
        }
        // 普通查询的迟到失效通知可能来自刚完成的 enqueue；不可撤掉基于新 lease 准备的效果。
        if change == .privacyInvalidated || !operationVisible { revokeTaskComposition() }
        if change == .privacyInvalidated || !operationVisible { revokeTaskTitle() }
        if change == .privacyInvalidated || !operationVisible { revokeBatch(); revokeTaskField() }
        if change == .privacyInvalidated || !operationVisible { revokeSubtask(); revokeRoutine() }
        if change == .privacyInvalidated || !operationVisible {
            revokeTrash(); revokeTaskCopy(); revokeConvert(); revokeSimple(); revokePage(); clipboardCapture.revoke()
        }
        if change == .privacyInvalidated || !operationVisible { chainCreationPreparation = nil }
        if change != .published, objectSelection != nil || session.isMasked {
            cancelObjectSelection(returnFocus: false)
            objectSelectionMessage = "unified.objects.stale"
        }
        if change == .privacyInvalidated {
            invalidateNavigation(privacy: true)
            task?.cancel()
            // 旧宿主只清自身原生缓冲，不能拿新所有权的 lease 续接旧事件。
            let current = try? coordinator.host(buffer.lease.ownership.hostID).lease
            let lease = current?.ownership == buffer.lease.ownership ? current! : buffer.lease
            buffer = .init(lease: lease, version: buffer.version + 1, text: "",
                           privacyRevision: buffer.privacyRevision + 1, operation: editingDraft?.stamp, plan: plan?.stamp, planItem: editingPlanItem?.stamp)
            editingParameter = nil
            inputReset.invalidate(buffer)
            messageKey = "unified.results.invalidated"
        } else if change == .invalidated {
            // 普通模型重读也发 invalidated；只有遮罩撤显示才使原生操作事件失效。
            if session.isMasked {
                buffer = .init(lease: buffer.lease, version: buffer.version + 1, text: buffer.text,
                    privacyRevision: buffer.privacyRevision, operation: buffer.operation, plan: buffer.plan, planItem: buffer.planItem)
            }
            messageKey = session.isMasked ? "unified.results.masked" : "unified.results.awaiting"
        }
    }
}

extension UnifiedSearchController {
    /// 页面事件推进了 lease：沿原文字与草稿戳重新发布显示缓冲，旧缓冲上的事件随之失效（修复批 M-7F 菜单栏筛选派生）。
    func renewBuffer(_ lease: CommandHostLease) {
        buffer = .init(lease: lease, version: buffer.version + 1, text: buffer.text, privacyRevision: buffer.privacyRevision,
            operation: buffer.operation, selectingObjects: buffer.selectingObjects, plan: buffer.plan, planItem: buffer.planItem)
    }
}
