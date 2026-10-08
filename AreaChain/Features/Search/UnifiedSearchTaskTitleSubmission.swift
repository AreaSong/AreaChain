import SwiftUI

/// 不开放返回计划、普通重试或执行后撤销；原运行始终保留事实和唯一输入。
struct UnifiedSearchTaskTitleSubmission: View {
    @Bindable var controller: UnifiedSearchController
    @Environment(\.locale) private var locale

    var body: some View {
        let source = controller.buffer
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            if let unit = controller.taskTitleUnit, let facts = unit.taskTitle {
                result(facts, unit: unit, source: source)
            } else if controller.settingExecution != nil {
                Text("unified.title.held").font(DaybookType.caption)
            } else { pending(source) }
            if let failure = controller.taskTitleFailure {
                Text(LocalizedStringKey(failure)).font(DaybookType.caption)
                    .accessibilityIdentifier("unified.title.issue")
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("unified.title.submission")
    }

    private func pending(_ source: UnifiedSearchBuffer) -> some View {
        let preview = controller.currentTaskTitlePreview
        let accepted = controller.currentTaskTitleAcceptance != nil
        return VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.title.pending").font(DaybookType.body)
            if !controller.hasTaskTitle { Text("unified.title.unassembled").font(DaybookType.caption) }
            if let preview {
                UnifiedSearchTaskTitlePreview(preview: preview)
                if accepted { Text("unified.title.accepted").font(DaybookType.caption) }
                else {
                    UnifiedSearchPlanButton(title: "unified.title.accept", identifier: "unified.title.accept", variant: .prominent) {
                        controller.acceptTaskTitle(preview, source: source)
                    }.disabled(controller.settingSubmitting)
                }
            } else {
                Text(controller.taskTitlePreview == nil ? "unified.title.baseline" : "unified.title.stale")
                    .font(DaybookType.caption)
            }
            UnifiedSearchPlanButton(title: "unified.title.prepare", identifier: "unified.title.prepare") {
                controller.prepareTaskTitle(source)
            }.disabled(controller.settingSubmitting || !controller.hasTaskTitle)
            UnifiedSearchPlanButton(title: "unified.title.save", identifier: "unified.title.save", variant: .prominent) {
                controller.requestOperationSubmit(source)
            }.disabled(controller.settingSubmitting || !accepted)
        }
    }

    func result(_ facts: CommandTaskTitleFacts, unit: CommandExecutionUnit,
                        source: UnifiedSearchBuffer) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text(LocalizedStringKey(UnifiedSearchTaskTitleCopy.result(facts)))
                .font(DaybookType.body).accessibilityIdentifier("unified.title.status")
            if case .shortText(let raw) = controller.settingExecution?.snapshot.items.first(where: { unit.members.contains($0.id) })?.draft.arguments
                .first(where: { $0.parameter == .title })?.value {
                Text("unified.composition.raw").font(DaybookType.caption)
                Text(verbatim: raw).font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
            }
            if facts.state == .saved {
                Text(facts.publication == .returned && !facts.publicationFailed
                    ? "unified.task.published" : "unified.title.publicationIssue").font(DaybookType.caption)
                if facts.registrationFailed { Text("unified.title.registrationIssue").font(DaybookType.caption) }
                Text(facts.refreshRequested ? "unified.task.refreshRequested" : "unified.task.refreshUnconfirmed")
                    .font(DaybookType.caption)
                UnifiedSearchTaskExternalFeedback(authorizationCall: String(describing: facts.authorizationRequest),
                    authorizationResult: String(describing: facts.authorizationResult),
                    notificationRequested: facts.notificationRequested, calendarRequested: facts.calendarRequested, unit: unit)
                if unit.effects.values.contains(.failed) { Text("unified.title.externalFailed").font(DaybookType.caption) }
                if let effects = facts.savedTagEffects {
                    Text(verbatim: L10n.format("unified.composition.savedTags", locale: locale,
                        effects.filter { $0 == .createAndAssociate }.count,
                        effects.filter { $0 == .restoreAndAssociate }.count,
                        effects.filter { $0 == .associateLive }.count)).font(DaybookType.caption)
                }
            }
            if let conflict = facts.conflict {
                Text(LocalizedStringKey(UnifiedSearchTaskTitleCopy.error(conflict))).font(DaybookType.caption)
            }
            if facts.state == .unknown {
                UnifiedSearchPlanButton(title: "unified.task.verify", identifier: "unified.title.verify") {
                    controller.verifyTaskTitle(source)
                }
                if let verification = controller.taskTitleVerification {
                    Text(LocalizedStringKey("unified.title.verify." + String(describing: verification.presence)))
                        .font(DaybookType.caption)
                }
            }
            Text("unified.title.held").font(DaybookType.caption)
        }
    }
}
