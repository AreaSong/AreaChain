import Foundation

extension UnifiedSearchController {
    var showsTaskChain: Bool {
        let drafts = (operations?.allDrafts ?? []) + (plan?.items.map(\.draft) ?? [])
            + (settingExecution?.snapshot.items.map(\.draft) ?? [])
        return drafts.count > 1 && drafts.contains { $0.commandID.rawValue == "todo.create" }
            && drafts.contains { $0.commandID.rawValue == "todo.title" }
    }

    var chainCanPrepareTitle: Bool {
        guard let run = settingExecution, let unit = taskTitleUnit, unit.taskTitle == nil,
              [.ready, .running].contains(unit.state),
              (try? coordinator.taskChainOutput(in: run)) != nil else { return false }
        return true
    }

    private func chainAction(_ source: UnifiedSearchBuffer, _ work: () throws -> Void) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            guard editingParameter == nil, objectSelectionLocation == nil, tagSelection == nil,
                  !objectSelectionLoading, taskChain != nil else { throw TaskFieldCommandIssue.unassembled }
            try session.validateDisplayHost(expecting: source.lease)
            try work()
            chainFailure = nil
        } catch {
            _ = publishOperation(text: buffer.text)
            if error is TaskFieldCommandIssue { chainFailure = "unified.chain.shape" }
            else if let issue = error as? TaskCreateCommandIssue { chainFailure = UnifiedSearchTaskCreateCopy.issue(issue) }
            else { chainFailure = UnifiedSearchTaskTitleCopy.error(error) }
        }
    }

    func prepareTaskChain(_ source: UnifiedSearchBuffer) {
        chainAction(source) {
            guard let taskChain, let plan else { throw TaskFieldCommandIssue.unassembled }
            chainCreationPreparation = try taskChain.prepareCreation(plan: plan.stamp, expecting: source.lease, displaySession: session)
        }
    }

    func prepareTaskChainTitle(_ source: UnifiedSearchBuffer) {
        chainAction(source) {
            guard let taskChain else { throw TaskFieldCommandIssue.unassembled }
            let preview = try taskChain.prepareTitle(expecting: source.lease, displaySession: session)
            _ = publishOperation(text: buffer.text)
            taskTitlePreview = preview
        }
    }

    func acceptTaskChainTitle(_ preview: CommandTaskTitlePreview, source: UnifiedSearchBuffer) {
        chainAction(source) {
            guard let taskChain, preview == taskTitlePreview else { throw TaskTitleCommandIssue.stale }
            taskTitleAcceptance = try taskChain.acceptTitle(preview, expecting: source.lease, displaySession: session)
        }
    }

    func submitTaskChain(_ source: UnifiedSearchBuffer) {
        chainAction(source) {
            guard let taskChain else { throw TaskFieldCommandIssue.unassembled }
            if settingExecution == nil {
                guard let prepared = chainCreationPreparation else { throw TaskCreateCommandIssue.stale }
                _ = try taskChain.submitCreation(prepared, expecting: source.lease, displaySession: session)
            } else {
                guard let accepted = taskTitleAcceptance else { throw TaskTitleCommandIssue.stale }
                _ = try taskChain.submitTitle(accepted, expecting: source.lease, displaySession: session)
            }
            _ = publishOperation(text: buffer.text)
            planMessage = "unified.plan.notExecutable"
        }
    }
}
