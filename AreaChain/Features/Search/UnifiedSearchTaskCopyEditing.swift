import Foundation

/// 复制只读当前操作草稿；不入列、不建 Run、不改数据，结果只是本次写入剪贴板的反馈。
extension UnifiedSearchController {
    var showsTaskCopy: Bool { operations?.active.map { routesTaskCopy($0.commandID) } == true }

    func routesTaskCopy(_ command: CommandID) -> Bool { taskCopy?.supports(command) == true }

    var currentTaskCopyPreview: CommandTaskCopyPreview? {
        guard operationVisible, let preview = taskCopyPreview, let taskCopy,
              (try? taskCopy.validatePreview(preview, expecting: buffer.lease, displaySession: session)) != nil else { return nil }
        return preview
    }

    var currentTaskCopyResult: CommandTaskCopyResult? {
        guard let result = taskCopyResult, result.draft == operations?.active?.stamp else { return nil }
        return result
    }

    func revokeTaskCopy() {
        taskCopyPreview = nil
        taskCopyResult = nil
    }

    private func taskCopyAction(_ source: UnifiedSearchBuffer, _ work: (TaskCopyCommandAdapter, CommandDraft) throws -> Void) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            guard let taskCopy else { throw TaskCopyCommandIssue.unassembled }
            guard editingParameter == nil, tagSelection == nil, objectSelectionLocation == nil, !objectSelectionLoading,
                  settingExecution == nil, plan?.items.isEmpty == true, let draft = operations?.active,
                  draft.stamp == source.operation else { throw TaskCopyCommandIssue.unsupportedPlan }
            try session.validateDisplayHost(expecting: source.lease)
            try work(taskCopy, draft)
            taskCopyFailure = nil
        } catch {
            taskCopyResult = nil
            taskCopyFailure = UnifiedSearchTaskCopyCopy.error(error)
        }
    }

    func prepareTaskCopy(_ source: UnifiedSearchBuffer) {
        taskCopyAction(source) { taskCopy, draft in
            revokeTaskCopy()
            taskCopyPreview = try taskCopy.prepare(draft: draft.stamp, expecting: source.lease, displaySession: session)
        }
    }

    func submitTaskCopy(_ source: UnifiedSearchBuffer) {
        taskCopyAction(source) { taskCopy, _ in
            taskCopyResult = nil
            guard let preview = currentTaskCopyPreview else { throw TaskCopyCommandIssue.stale }
            taskCopyResult = try taskCopy.submit(preview, expecting: source.lease, displaySession: session)
        }
    }
}

enum UnifiedSearchTaskCopyCopy {
    static func error(_ error: Error) -> String {
        guard let issue = error as? TaskCopyCommandIssue else { return "unified.copy.stale" }
        switch issue {
        case .unassembled: return "unified.copy.unassembled"
        case .unsupportedPlan: return "unified.copy.single"
        case .invalidArguments, .invalidTarget: return "unified.copy.input"
        case .missing, .duplicate, .deleted, .changed, .stale: return "unified.copy.stale"
        case .protectedContent, .sourceUnavailable, .notesUnverified: return "unified.copy.ineligible"
        case .notesEmpty: return "unified.copy.notesEmpty"
        case .writeFailed: return "unified.copy.writeFailed"
        }
    }

    static func section(_ section: TaskCopySection) -> String { "unified.copy.section." + section.rawValue }
}
