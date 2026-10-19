import Foundation
import SwiftData

/// capture.clipboard 的显式隔离装配：内存库、关闭自动保存的干净 context、私有事件与注入的剪贴板／附件目录／日期。
@MainActor final class ClipboardCaptureCommandEnvironment {
    let id = UUID()
    let context: ModelContext
    let center: NotificationCenter
    let capture: ClipboardCapture.Environment
    /// 偏好“附来源 Bundle ID”的当前值；预览据此说明，提交时由 capture.sourceBundleID 给出实际值。
    let stampsSource: () -> Bool
    var transaction: ModelChanges.Boundary
    /// 发布时请求的提醒／日历刷新；隔离环境注入 fake。
    var refresh: (Bool) -> Void = { _ in }

    init(context: ModelContext, center: NotificationCenter, capture: ClipboardCapture.Environment,
         stampsSource: @escaping () -> Bool, transaction: ModelChanges.Boundary) throws {
        self.context = context
        self.center = center
        self.capture = capture
        self.stampsSource = stampsSource
        self.transaction = transaction
        try validateClean()
    }

    func validateClean() throws {
        guard center !== NotificationCenter.default, !context.autosaveEnabled,
              !context.container.configurations.isEmpty,
              context.container.configurations.allSatisfy(\.isStoredInMemoryOnly) else {
            throw ClipboardCaptureCommandIssue.unassembled
        }
        guard !context.hasChanges, !ModelChanges.hasActiveTransaction(in: context) else { throw ClipboardCaptureCommandIssue.stale }
    }
}

/// 准备 → 提交（一次读取剪贴板）→ 可选只读核对。能力默认未装配；生产没有构造点。
@MainActor final class ClipboardCaptureCommandAdapter {
    let coordinator: CommandHandoffCoordinator
    let environment: ClipboardCaptureCommandEnvironment?
    /// 已提交过的预览（按待办身份）：同一份预览不能再提交。
    private var submitted: Set<UUID> = []
    /// 保存结果未知、尚未核对的待办身份；核对出确定结果前不能再提交新的捕获。
    private(set) var unresolved: [UUID: UUID] = [:]

    init(coordinator: CommandHandoffCoordinator, environment: ClipboardCaptureCommandEnvironment? = nil) {
        self.coordinator = coordinator
        self.environment = environment
    }

    func supports(_ command: CommandID) -> Bool {
        environment != nil && command.rawValue == CommandClipboardCapturePreview.command
    }

    /// 只读当前草稿与偏好、日期；不读剪贴板，不写库。
    func prepare(draft stamp: CommandDraftStamp, expecting lease: CommandHostLease,
                 displaySession: ContentQueryReadSession? = nil) throws -> CommandClipboardCapturePreview {
        let environment = try assembled(lease, displaySession: displaySession)
        let draft = try current(lease)
        guard draft.stamp == stamp else { throw ClipboardCaptureCommandIssue.stale }
        return .init(lease: lease, draft: stamp, environmentID: environment.id, dayKey: environment.capture.today(),
                     stampsSource: environment.stampsSource(), todoID: UUID(), attachmentID: UUID())
    }

    func validatePreview(_ preview: CommandClipboardCapturePreview, expecting lease: CommandHostLease,
                         displaySession: ContentQueryReadSession? = nil) throws {
        let environment = try assembled(lease, displaySession: displaySession)
        guard preview.lease == lease, preview.environmentID == environment.id, try current(lease).stamp == preview.draft,
              preview.dayKey == environment.capture.today(), preview.stampsSource == environment.stampsSource() else {
            throw ClipboardCaptureCommandIssue.stale
        }
    }

    /// 读取只在这里发生一次。保存成功才发布；写附件或事务失败不留孤儿文件；保存已调用但失败记为 unknown，不重试。
    func submit(_ preview: CommandClipboardCapturePreview, expecting lease: CommandHostLease,
                displaySession: ContentQueryReadSession? = nil) throws -> CommandClipboardCaptureFacts {
        try validatePreview(preview, expecting: lease, displaySession: displaySession)
        guard let environment else { throw ClipboardCaptureCommandIssue.unassembled }
        guard unresolved.isEmpty else { throw ClipboardCaptureCommandIssue.verificationRequired }
        guard submitted.insert(preview.todoID).inserted else { throw ClipboardCaptureCommandIssue.alreadySubmitted }
        var facts = CommandClipboardCaptureFacts(draft: preview.draft, todoID: preview.todoID, state: .notSubmitted)
        let contents = environment.capture.read()
        guard let payload = ClipboardCapture.payload(contents, locale: environment.capture.locale()) else {
            facts.state = .empty
            return facts
        }
        facts.kind = payload.attachImage ? .image : .text
        let capture = ClipboardCapture.Capture(payload: payload, image: contents.image, todoID: preview.todoID,
                                               attachmentID: preview.attachmentID, dayKey: preview.dayKey,
                                               sourceBundleID: environment.capture.sourceBundleID())
        var commit: ModelChanges.CommitFacts?
        var boundary = environment.transaction
        boundary.publish = {
            BoardEvents.changed(dependencies: .init(center: environment.center) { environment.refresh($0) })
        }
        do {
            try ModelChanges.transaction(in: environment.context, boundary: boundary, observe: { commit = $0 }) {
                let todo = try ClipboardCapture.apply(capture, storage: environment.capture.storage, in: environment.context)
                facts.tagCount = TagIDList.parse(todo.tagIDs).count
                facts.attachedImage = payload.attachImage
            }
            facts.state = .saved
        } catch {
            boundary.reportFailure(error)
            let unknown = commit?.save == .called || commit?.phase == .recoveryFailed
            facts.state = unknown ? .unknown : .notSubmitted
            facts.attachedImage = false
            // 确定没有保存时清掉刚写的图片文件；结果未知时文件可能已被引用，留到核对后再决定。
            if unknown { unresolved[preview.todoID] = preview.attachmentID }
            else if payload.attachImage { environment.capture.storage.removeFile(id: preview.attachmentID) }
        }
        facts.publication = commit?.publication == .returned ? .returned : commit?.publication == .called ? .called : .notCalled
        return facts
    }

    /// 只读核对：同容器新 context 按待办身份查找。确定不存在时清掉可能遗留的图片文件并解除阻止；存在时只解除阻止，
    /// 不把原 unknown 提升为成功；有歧义或读不出时保持阻止。
    func verifyUnknown(_ todoID: UUID, expecting lease: CommandHostLease,
                       displaySession: ContentQueryReadSession? = nil) throws -> CommandClipboardCaptureVerification {
        let environment = try assembled(lease, displaySession: displaySession)
        guard let attachmentID = unresolved[todoID] else { throw ClipboardCaptureCommandIssue.stale }
        let reader = ModelContext(environment.context.container)
        reader.autosaveEnabled = false
        let rows: [TodoItem]
        do { rows = try reader.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == todoID })) }
        catch { return .unreadable }
        switch rows.count {
        case 0:
            environment.capture.storage.removeFile(id: attachmentID)
            unresolved[todoID] = nil
            return .absent
        case 1:
            unresolved[todoID] = nil
            return .present
        default: return .ambiguous
        }
    }

    private func assembled(_ lease: CommandHostLease,
                           displaySession: ContentQueryReadSession?) throws -> ClipboardCaptureCommandEnvironment {
        try displaySession?.validateDisplayHost(expecting: lease)
        guard let environment else { throw ClipboardCaptureCommandIssue.unassembled }
        try environment.validateClean()
        try coordinator.validate(lease)
        guard !coordinator.hasInvocation(lease.ownership) else { throw CommandExecutionError.busy }
        return environment
    }

    private func current(_ lease: CommandHostLease) throws -> CommandDraft {
        let session = try coordinator.host(lease.ownership.hostID).session
        guard session.execution == nil, session.plan.items.isEmpty, session.operations.pending == nil,
              let draft = session.operations.active else { throw ClipboardCaptureCommandIssue.unsupportedPlan }
        try CommandClipboardCapturePreview.validate(draft)
        return draft
    }
}
