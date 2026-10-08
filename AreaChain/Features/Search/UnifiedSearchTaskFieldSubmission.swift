import SwiftUI

enum UnifiedSearchTaskFieldCopy {
    static func error(_ error: Error) -> String {
        if let issue = error as? TaskFieldCommandIssue {
            switch issue {
            case .unassembled: return "unified.field.unassembled"
            case .unsupportedPlan: return "unified.field.single"
            case .invalidArguments: return "unified.field.input"
            case .fieldsChanged: return "unified.field.fields"
            case .stale, .alreadyInvoked: return "unified.field.stale"
            }
        }
        return UnifiedSearchTaskTitleCopy.error(error).replacingOccurrences(of: "unified.title.", with: "unified.field.")
    }
}

struct UnifiedSearchTaskFieldSubmission: View {
    @Bindable var controller: UnifiedSearchController
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    var body: some View {
        let source = controller.buffer
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            if let unit = controller.taskFieldUnit, let facts = unit.taskField {
                result(facts, unit: unit, source: source)
            } else if controller.settingExecution != nil { Text("unified.field.held").font(DaybookType.caption) }
            else { pending(source) }
            if let failure = controller.taskFieldFailure {
                Text(LocalizedStringKey(failure)).font(DaybookType.caption).accessibilityIdentifier("unified.field.issue")
            }
        }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .contain).accessibilityIdentifier("unified.field.submission")
    }

    private func pending(_ source: UnifiedSearchBuffer) -> some View {
        let preview = controller.currentTaskFieldPreview
        let accepted = controller.currentTaskFieldAcceptance != nil
        return VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.field.pending").font(DaybookType.body)
            if !controller.hasTaskField { Text("unified.field.unassembled").font(DaybookType.caption) }
            if let preview {
                UnifiedSearchTaskFieldImpact(preview: preview)
                if preview.noChange { Text("unified.field.noChange").font(DaybookType.caption) }
                if accepted { Text("unified.field.accepted").font(DaybookType.caption) }
                else {
                    UnifiedSearchPlanButton(title: "unified.field.accept", identifier: "unified.field.accept", variant: .prominent) {
                        controller.acceptTaskField(preview, source: source)
                    }.disabled(controller.settingSubmitting)
                }
            } else { Text(controller.taskFieldPreview == nil ? "unified.field.baseline" : "unified.field.stale").font(DaybookType.caption) }
            UnifiedSearchPlanButton(title: "unified.field.prepare", identifier: "unified.field.prepare") {
                controller.prepareTaskField(source)
            }.disabled(controller.settingSubmitting || !controller.hasTaskField)
            UnifiedSearchPlanButton(title: "unified.field.save", identifier: "unified.field.save", variant: .prominent) {
                controller.requestOperationSubmit(source)
            }.disabled(controller.settingSubmitting || !accepted)
        }
    }

    private func result(_ facts: CommandTaskFieldFacts, unit: CommandExecutionUnit, source: UnifiedSearchBuffer) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text(LocalizedStringKey("unified.field." + (facts.state == .pending ? "pendingResult" : String(describing: facts.state))))
                .font(DaybookType.body).accessibilityIdentifier("unified.field.status")
            if facts.state == .saved {
                Text(facts.publication == .returned && !facts.publicationFailed ? "unified.task.published" : "unified.field.publicationIssue")
                    .font(DaybookType.caption)
                if let children = facts.completedSubtaskIDs {
                    Text(verbatim: L10n.format("unified.field.childrenSaved", locale: locale, children.count)).font(DaybookType.caption)
                }
                if let effects = facts.savedTagEffects {
                    Text(verbatim: L10n.format("unified.field.tagsSaved", locale: locale,
                        effects.filter { $0 == .createAndAssociate }.count,
                        effects.filter { $0 == .restoreAndAssociate }.count,
                        effects.filter { $0 == .associateLive }.count)).font(DaybookType.caption)
                }
                if facts.registrationFailed { Text("unified.field.registrationIssue").font(DaybookType.caption) }
                UnifiedSearchTaskExternalFeedback(authorizationCall: String(describing: facts.authorizationRequest),
                    authorizationResult: String(describing: facts.authorizationResult), notificationRequested: facts.notificationRequested,
                    calendarRequested: facts.calendarRequested, unit: unit)
            }
            if facts.conflict { Text("unified.field.fields").font(DaybookType.caption) }
            if facts.state == .unknown {
                UnifiedSearchPlanButton(title: "unified.task.verify", identifier: "unified.field.verify") { controller.verifyTaskField(source) }
                if let verification = controller.taskFieldVerification {
                    Text(LocalizedStringKey(UnifiedSearchTaskCreateCopy.verification(verification))).font(DaybookType.caption)
                }
            }
            Text("unified.field.held").font(DaybookType.caption)
        }
    }
}
