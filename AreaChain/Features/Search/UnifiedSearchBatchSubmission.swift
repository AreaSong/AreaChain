import SwiftUI

enum UnifiedSearchBatchCopy {
    static func error(_ error: Error) -> String {
        guard let issue = error as? CommandBatchIssue else { return UnifiedSearchTaskFieldCopy.error(error) }
        switch issue {
        case .unassembled: return "unified.batch.unassembled"
        case .unsupportedPlan: return "unified.batch.singlePlan"
        case .invalidArguments: return "unified.batch.input"
        case .invalidTargets, .fieldsChanged: return "unified.batch.targetsChanged"
        case .catalogChanged, .inactiveTag: return "unified.batch.catalog"
        case .invalidRepository: return "unified.field.unassembled"
        case .stale, .alreadyInvoked: return "unified.field.stale"
        }
    }
    static func target(_ target: CommandObjectReference, locale: Locale) -> String {
        L10n.format(UnifiedSearchResultCopy.typeKey(target.type), locale: locale) + " · " + target.id.uuidString
    }
}

/// 复用原参数/计划/反馈层；成员是一个操作内的明细，不形成可独立重放的计划项。
struct UnifiedSearchBatchSubmission: View {
    @Bindable var controller: UnifiedSearchController
    @Environment(\.locale) private var locale

    var body: some View {
        let source = controller.buffer
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            if let unit = controller.batchUnit, let facts = unit.batch { result(facts, unit: unit) }
            else if controller.settingExecution != nil { Text("unified.batch.held").font(DaybookType.caption) }
            else { pending(source) }
            if let failure = controller.batchFailure {
                Text(LocalizedStringKey(failure)).font(DaybookType.caption).accessibilityIdentifier("unified.batch.issue")
            }
            if !controller.batchProblems.isEmpty { problems }
        }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .contain).accessibilityIdentifier("unified.batch.submission")
    }

    private func pending(_ source: UnifiedSearchBuffer) -> some View {
        let preview = controller.currentBatchPreview
        let accepted = preview != nil && controller.batchAcceptance?.preview == preview
        return VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.batch.pending").font(DaybookType.body)
            if !controller.hasBatch { Text("unified.batch.unassembled").font(DaybookType.caption) }
            if let preview {
                UnifiedSearchBatchImpact(preview: preview) { target in
                    controller.removeBatchTarget(target, preview: preview, source: source)
                }
                if accepted { Text("unified.batch.accepted").font(DaybookType.caption) }
                else {
                    UnifiedSearchPlanButton(title: "unified.batch.accept", identifier: "unified.batch.accept", variant: .prominent) {
                        controller.acceptBatch(preview, source: source)
                    }.disabled(controller.settingSubmitting)
                }
            } else { Text(controller.batchPreview == nil ? "unified.batch.baseline" : "unified.field.stale").font(DaybookType.caption) }
            UnifiedSearchPlanButton(title: "unified.batch.prepare", identifier: "unified.batch.prepare") {
                controller.prepareBatch(source)
            }.disabled(controller.settingSubmitting || !controller.hasBatch)
            UnifiedSearchPlanButton(title: "unified.batch.save", identifier: "unified.batch.save", variant: .prominent) {
                controller.requestOperationSubmit(source)
            }.disabled(controller.settingSubmitting || !accepted)
        }
    }

    private var problems: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DaybookSpacing.sm) {
                ForEach(controller.batchProblems, id: \.target) { problem in
                    VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
                        Text(verbatim: UnifiedSearchBatchCopy.target(problem.target, locale: locale))
                        Text(LocalizedStringKey("unified.batch.problem." + String(describing: problem.reason)))
                    }.font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("unified.batch.problem." + problem.target.searchIdentifier)
                }
            }
        }.frame(height: 120).modifier(DaybookScrollTargetModifier())
    }

    private func result(_ facts: CommandBatchFacts, unit: CommandExecutionUnit) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text(LocalizedStringKey("unified.batch." + String(describing: facts.state)))
                .font(DaybookType.body).accessibilityIdentifier("unified.batch.status")
            Text(verbatim: L10n.format("unified.batch.resultCount", locale: locale, facts.targets.objects.count,
                facts.state == .saved ? facts.changedCount : 0, facts.impacts.filter(\.noChange).count))
                .font(DaybookType.caption)
            if facts.state == .saved {
                Text(facts.publication == .returned && !facts.publicationFailed ? "unified.task.published" : "unified.field.publicationIssue")
                    .font(DaybookType.caption)
                if facts.registrationFailed { Text("unified.field.registrationIssue").font(DaybookType.caption) }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DaybookSpacing.sm) {
                        ForEach(facts.impacts, id: \.target) { impact in
                            Text(verbatim: impact.title).font(DaybookType.body)
                            Text(LocalizedStringKey(UnifiedSearchResultCopy.typeKey(impact.target.type))).font(DaybookType.caption)
                            if impact.noChange { Text("unified.batch.memberNoChange").font(DaybookType.caption) }
                            else if let external = facts.external.first(where: { $0.target == impact.target }) {
                                UnifiedSearchTaskExternalFeedback(authorizationCall: "notCalled", authorizationResult: "unknown",
                                    notificationRequested: external.notificationRequested, calendarRequested: external.calendarRequested,
                                    unit: unit, externalResults: [.notification: external.notification, .calendar: external.calendar])
                            }
                            DaybookDivider()
                        }
                    }
                }.frame(height: 180).modifier(DaybookScrollTargetModifier())
            }
            Text("unified.batch.held").font(DaybookType.caption)
        }
    }
}
