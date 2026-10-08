import SwiftUI

struct UnifiedSearchSubtaskSubmission: View {
    @Bindable var controller: UnifiedSearchController
    @Environment(\.locale) private var locale

    var body: some View {
        let source = controller.buffer
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            if let unit = controller.subtaskUnit, let facts = unit.subtask {
                result(facts, unit: unit, source: source)
            } else if controller.settingExecution != nil { Text("unified.subtask.held").font(DaybookType.caption) }
            else { pending(source) }
            if let failure = controller.subtaskFailure {
                Text(LocalizedStringKey(failure)).font(DaybookType.caption).accessibilityIdentifier("unified.subtask.issue")
            }
        }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .contain).accessibilityIdentifier("unified.subtask.submission")
    }

    private func pending(_ source: UnifiedSearchBuffer) -> some View {
        let preview = controller.currentSubtaskPreview
        let accepted = controller.currentSubtaskAcceptance != nil
        return VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.subtask.pending").font(DaybookType.body)
            if !controller.hasSubtask { Text("unified.subtask.single").font(DaybookType.caption) }
            if let preview {
                UnifiedSearchSubtaskImpact(preview: preview)
                if preview.noChange { Text("unified.subtask.noChange").font(DaybookType.caption) }
                if accepted { Text("unified.subtask.accepted").font(DaybookType.caption) }
                else {
                    UnifiedSearchPlanButton(title: "unified.subtask.accept", identifier: "unified.subtask.accept", variant: .prominent) {
                        controller.acceptSubtask(preview, source: source)
                    }.disabled(controller.settingSubmitting)
                }
            } else { Text(controller.subtaskPreview == nil ? "unified.subtask.baseline" : "unified.subtask.stale").font(DaybookType.caption) }
            UnifiedSearchPlanButton(title: "unified.subtask.prepare", identifier: "unified.subtask.prepare") {
                controller.prepareSubtask(source)
            }.disabled(controller.settingSubmitting || !controller.hasSubtask)
            UnifiedSearchPlanButton(title: "unified.subtask.save", identifier: "unified.subtask.save", variant: .prominent) {
                controller.requestOperationSubmit(source)
            }.disabled(controller.settingSubmitting || !accepted)
        }
    }

    private func result(_ facts: CommandSubtaskFacts, unit: CommandExecutionUnit, source: UnifiedSearchBuffer) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text(LocalizedStringKey(UnifiedSearchSubtaskCopy.result(facts)))
                .font(DaybookType.body).accessibilityIdentifier("unified.subtask.status")
            if facts.state == .saved {
                if let title = facts.savedTitle { Text(verbatim: title).font(DaybookType.body) }
                Text(facts.publication == .returned && !facts.publicationFailed ? "unified.task.published" : "unified.subtask.publicationIssue")
                    .font(DaybookType.caption)
                if let tags = facts.savedTagIDs {
                    Text(verbatim: L10n.format("unified.subtask.savedTagCount", locale: locale, tags.count))
                        .font(DaybookType.caption).accessibilityIdentifier("unified.subtask.savedTagCount")
                }
                if let effects = facts.savedTagEffects {
                    Text(verbatim: L10n.format("unified.field.tagsSaved", locale: locale,
                        effects.filter { $0 == .createAndAssociate }.count,
                        effects.filter { $0 == .restoreAndAssociate }.count,
                        effects.filter { $0 == .associateLive }.count)).font(DaybookType.caption)
                }
                if facts.registrationFailed { Text("unified.subtask.registrationIssue").font(DaybookType.caption) }
                UnifiedSearchTaskExternalFeedback(authorizationCall: "notCalled", authorizationResult: "unknown",
                    notificationRequested: facts.notificationRequested, calendarRequested: facts.calendarRequested, unit: unit)
            }
            if facts.conflict { Text("unified.subtask.fields").font(DaybookType.caption) }
            if facts.state == .unknown {
                UnifiedSearchPlanButton(title: "unified.task.verify", identifier: "unified.subtask.verify") { controller.verifySubtask(source) }
                if let verification = controller.subtaskVerification {
                    Text(LocalizedStringKey("unified.subtask.presence." + String(describing: verification))).font(DaybookType.caption)
                }
            }
            Text("unified.subtask.held").font(DaybookType.caption)
        }
    }
}
