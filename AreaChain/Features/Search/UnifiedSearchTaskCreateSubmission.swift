import SwiftUI

/// 保存、发布与系统请求分别显示；candidateID 永远不是已创建记录。
struct UnifiedSearchTaskCreateSubmission: View {
    @Bindable var controller: UnifiedSearchController
    @Environment(\.locale) private var locale

    var body: some View {
        let source = controller.buffer
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            if let unit = controller.taskCreateUnit, let facts = unit.taskCreation {
                result(facts, unit: unit, source: source)
            } else if controller.settingExecution != nil {
                Text("unified.task.held").font(DaybookType.caption)
            } else if controller.hasTaskComposition {
                UnifiedSearchTaskCompositionPreview(controller: controller)
            } else {
                pending(source)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("unified.task.submission")
    }

    private func pending(_ source: UnifiedSearchBuffer) -> some View {
        let issue = controller.taskCreateIssue
        return VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.task.pending").font(DaybookType.body)
            Text("unified.composition.minimal").font(DaybookType.caption)
            if let draft = controller.taskCreateDraft, let input = try? CommandTaskCreateInput(draft) {
                Text(verbatim: input.parsed.cleanTitle).font(DaybookType.body)
                Text(verbatim: input.day).font(DaybookType.caption)
                    .accessibilityIdentifier("unified.task.day")
            }
            if let preparation = controller.currentTaskPreparation {
                Text(preparation.source.stampEnabled ? "unified.task.sourceEnabled" : "unified.task.sourceDisabled")
                    .font(DaybookType.caption)
                if preparation.source.stampEnabled { Text(verbatim: preparation.source.bundleID).font(DaybookType.caption) }
            } else { Text("unified.task.sourceUnprepared").font(DaybookType.caption) }
            Text(LocalizedStringKey(issue.map(UnifiedSearchTaskCreateCopy.issue) ?? "unified.task.ready"))
                .font(DaybookType.caption).accessibilityIdentifier("unified.task.status")
            UnifiedSearchPlanButton(title: "unified.task.prepare", identifier: "unified.task.prepare") {
                controller.requestTaskCreate(source, prepareOnly: true)
            }.disabled(controller.settingSubmitting || issue != nil || controller.operations?.active != nil)
            UnifiedSearchPlanButton(title: "unified.task.create", identifier: "unified.task.create", variant: .prominent) {
                controller.requestOperationSubmit(source)
            }.disabled(controller.settingSubmitting || issue != nil)
        }
    }

    func result(_ facts: CommandTaskCreateFacts, unit: CommandExecutionUnit,
                source: UnifiedSearchBuffer, allowsRelease: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text(LocalizedStringKey(UnifiedSearchTaskCreateCopy.result(facts)))
                .font(DaybookType.body).accessibilityIdentifier("unified.task.status")
            if facts.state == .saved, let savedID = facts.savedID {
                Text(verbatim: savedID.uuidString).font(DaybookType.micro)
                    .textSelection(.enabled).accessibilityIdentifier("unified.task.savedID")
                Text(LocalizedStringKey(facts.publication == .returned && !facts.publicationFailed
                    ? "unified.task.published" : "unified.task.publicationIssue")).font(DaybookType.caption)
                if facts.registrationFailed { Text("unified.task.registrationIssue").font(DaybookType.caption) }
                Text(facts.refreshRequested ? "unified.task.refreshRequested" : "unified.task.refreshUnconfirmed")
                    .font(DaybookType.caption)
                Text("unified.task.externalLimit").font(DaybookType.caption)
                if unit.effects.values.contains(.failed) { Text("unified.task.externalFailed").font(DaybookType.caption) }
                if let effects = facts.savedTagEffects {
                    Text(verbatim: L10n.format("unified.composition.savedTags", locale: locale,
                        effects.filter { $0 == .createAndAssociate }.count,
                        effects.filter { $0 == .restoreAndAssociate }.count,
                        effects.filter { $0 == .associateLive }.count)).font(DaybookType.caption)
                }
                UnifiedSearchTaskExternalFeedback(authorizationCall: String(describing: facts.authorizationRequest),
                    authorizationResult: String(describing: facts.authorizationResult),
                    notificationRequested: facts.notificationRequested, calendarRequested: facts.calendarRequested, unit: unit)
            }
            if let failure = controller.taskCreateFailure {
                Text(LocalizedStringKey(UnifiedSearchTaskCreateCopy.issue(failure))).font(DaybookType.caption)
            }
            if let failure = controller.compositionFailure {
                Text(LocalizedStringKey(failure)).font(DaybookType.caption)
            }
            if facts.state == .unknown {
                UnifiedSearchPlanButton(title: "unified.task.verify", identifier: "unified.task.verify") {
                    controller.verifyTaskCreate(source)
                }
                if let verification = controller.taskCreateVerification {
                    Text(LocalizedStringKey(UnifiedSearchTaskCreateCopy.verification(verification))).font(DaybookType.caption)
                }
            }
            if unit.state == .succeeded, facts.state == .saved, allowsRelease {
                UnifiedSearchPlanButton(title: "unified.setting.done", identifier: "unified.task.done") {
                    controller.acknowledgeTaskCreate(source)
                }
            } else { Text("unified.task.held").font(DaybookType.caption) }
        }
    }

}

enum UnifiedSearchTaskCreateCopy {
    static func issue(_ issue: TaskCreateCommandIssue) -> String {
        switch issue {
        case .unassembled: return "unified.task.unassembled"
        case .invalidInput, .protectedContent: return "unified.task.invalid"
        case .unsupportedPlan: return "unified.task.ownership"
        case .dirtyContext, .nestedTransaction: return "unified.task.dirty"
        case .sourceChanged, .sourceUnavailable: return "unified.task.sourceIssue"
        case .stale, .alreadyInvoked: return "unified.task.stale"
        case .identityCollision, .storageUnavailable, .ineligibleEnvironment: return "unified.task.storageIssue"
        }
    }

    static func result(_ facts: CommandTaskCreateFacts) -> String {
        switch facts.state {
        case .saved: return facts.savedID != nil ? "unified.task.saved" : "unified.task.unknown"
        case .pending: return "unified.task.pendingResult"
        case .notSubmitted: return "unified.task.notSubmitted"
        case .unknown: return "unified.task.unknown"
        }
    }

    static func verification(_ value: CommandTaskCreateVerification) -> String {
        switch value {
        case .absent: return "unified.task.absent"
        case .singleLive: return "unified.task.singleLive"
        case .tombstone: return "unified.task.tombstone"
        case .ambiguous: return "unified.task.ambiguous"
        case .unreadable: return "unified.task.unreadable"
        }
    }
}
