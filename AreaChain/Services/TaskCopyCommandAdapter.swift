import Foundation
import SwiftData

/// 仅显式隔离装配；复制内容沿 TaskCopyContent，写入只经注入的剪贴板接口。
@MainActor final class TaskCopyCommandEnvironment {
    let id = UUID()
    let context: ModelContext
    let source: (CommandObjectReference) throws -> CommandTaskTitleEligibility
    let writer: any ClipboardTextWriting

    init(context: ModelContext, source: @escaping (CommandObjectReference) throws -> CommandTaskTitleEligibility,
         writer: any ClipboardTextWriting) throws {
        self.context = context
        self.source = source
        self.writer = writer
        try validateClean()
    }

    func validateClean() throws {
        guard !context.autosaveEnabled, !context.container.configurations.isEmpty,
              context.container.configurations.allSatisfy(\.isStoredInMemoryOnly) else {
            throw TaskTitleCommandIssue.ineligibleEnvironment
        }
        // 未保存的编辑不是可复制的已核验内容。
        guard !context.hasChanges else { throw TaskTitleCommandIssue.dirtyContext }
    }
}

@MainActor final class TaskCopyCommandAdapter {
    let coordinator: CommandHandoffCoordinator
    let environment: TaskCopyCommandEnvironment?

    init(coordinator: CommandHandoffCoordinator, environment: TaskCopyCommandEnvironment? = nil) {
        self.coordinator = coordinator
        self.environment = environment
    }

    func supports(_ command: CommandID) -> Bool { environment != nil && command.rawValue == CommandTaskCopyPreview.command }

    func prepare(draft: CommandDraftStamp, expecting lease: CommandHostLease,
                 displaySession: ContentQueryReadSession? = nil) throws -> CommandTaskCopyPreview {
        let environment = try assembled(lease, displaySession: displaySession)
        let host = try coordinator.host(lease.ownership.hostID)
        let current = try CommandTaskCopyPreview.input(in: host)
        guard current.stamp == draft else { throw TaskCopyCommandIssue.stale }
        let preview = try read(current, lease: lease, environment: environment)
        try coordinator.validate(lease)
        try displaySession?.validateDisplayHost(expecting: lease)
        return preview
    }

    func validatePreview(_ preview: CommandTaskCopyPreview, expecting lease: CommandHostLease,
                         displaySession: ContentQueryReadSession? = nil) throws {
        let environment = try assembled(lease, displaySession: displaySession)
        let draft = try CommandTaskCopyPreview.input(in: coordinator.host(lease.ownership.hostID))
        guard preview.lease == lease, preview.environmentID == environment.id, draft.stamp == preview.draft else {
            throw TaskCopyCommandIssue.stale
        }
        guard try read(draft, lease: lease, environment: environment) == preview else { throw TaskCopyCommandIssue.changed }
        try coordinator.validate(lease)
    }

    /// 只在最后核验通过后写一次；写入失败如实抛出，不留下“已复制”结果。
    func submit(_ preview: CommandTaskCopyPreview, expecting lease: CommandHostLease,
                displaySession: ContentQueryReadSession? = nil) throws -> CommandTaskCopyResult {
        try validatePreview(preview, expecting: lease, displaySession: displaySession)
        guard let environment else { throw TaskCopyCommandIssue.unassembled }
        do { try environment.writer.write(preview.text) } catch { throw TaskCopyCommandIssue.writeFailed }
        return .init(draft: preview.draft, target: preview.target, section: preview.section,
                     characters: preview.text.count)
    }

    private func assembled(_ lease: CommandHostLease, displaySession: ContentQueryReadSession?) throws -> TaskCopyCommandEnvironment {
        try displaySession?.validateDisplayHost(expecting: lease)
        guard let environment else { throw TaskCopyCommandIssue.unassembled }
        try environment.validateClean()
        try coordinator.validate(lease)
        guard !coordinator.hasInvocation(lease.ownership) else { throw CommandExecutionError.busy }
        return environment
    }

    private func read(_ draft: CommandDraft, lease: CommandHostLease,
                      environment: TaskCopyCommandEnvironment) throws -> CommandTaskCopyPreview {
        let (target, section) = try CommandTaskCopyPreview.parse(draft)
        let todo = try live(target, environment: environment)
        let source = try qualification(target, environment: environment)
        let notes = TaskCopyContent.notes(todo.notes)
        // 来源声明须与真实备注一致；未知时不读备注猜测资格。
        guard source.notes != .unknown else { throw TaskCopyCommandIssue.notesUnverified }
        guard (source.notes == .present) == (notes != nil) else { throw TaskCopyCommandIssue.changed }
        guard let text = TaskCopyContent.text(section, title: todo.title, notes: notes) else {
            throw TaskCopyCommandIssue.notesEmpty
        }
        let snapshot = todo.snapshot
        // 来源回调可能重入；结束后再证明对象与来源均未变化。
        guard try live(target, environment: environment) === todo, todo.snapshot == snapshot,
              try qualification(target, environment: environment) == source else { throw TaskCopyCommandIssue.changed }
        try environment.validateClean()
        return .init(lease: lease, draft: draft.stamp, target: target, section: section, environmentID: environment.id,
                     record: todo.persistentModelID, snapshot: snapshot, source: source, text: text)
    }

    private func live(_ target: CommandObjectReference, environment: TaskCopyCommandEnvironment) throws -> TodoItem {
        let rows = try SwiftDataTaskRepository(context: environment.context).fetchTodos(withID: target.id)
        guard rows.count == 1 else { throw rows.isEmpty ? TaskCopyCommandIssue.missing : TaskCopyCommandIssue.duplicate }
        guard rows[0].modelContext === environment.context else { throw TaskCopyCommandIssue.stale }
        guard rows[0].deletedAt == nil else { throw TaskCopyCommandIssue.deleted }
        return rows[0]
    }

    private func qualification(_ target: CommandObjectReference,
                               environment: TaskCopyCommandEnvironment) throws -> CommandTaskTitleEligibility {
        let source: CommandTaskTitleEligibility
        do { source = try environment.source(target) } catch { throw TaskCopyCommandIssue.sourceUnavailable }
        guard source.protection == .ordinary else { throw TaskCopyCommandIssue.protectedContent }
        return source
    }
}
