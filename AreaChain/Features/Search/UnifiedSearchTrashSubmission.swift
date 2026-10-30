import SwiftUI

/// 回收沿原面板：准备与接受之后，普通提交只打开独立确认；结果仍由原 Run 展示。
struct UnifiedSearchTrashSubmission: View {
    @Bindable var controller: UnifiedSearchController
    @Environment(\.locale) private var locale

    var body: some View {
        let source = controller.buffer
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            if let unit = controller.trashUnit, let facts = unit.trash { result(facts, unit: unit) }
            else if controller.settingExecution != nil { Text("unified.trash.held").font(DaybookType.caption) }
            else if let confirmation = controller.trashConfirmation {
                UnifiedSearchIndependentConfirmationPanel(controller: controller, identifier: "unified.trash",
                    title: "alert.trash.title", confirmTitle: "alert.trash.move",
                    confirm: { controller.confirmTrash(confirmation, source: source) }) {
                    UnifiedSearchTrashConfirmationDetails(confirmation: confirmation)
                }
            } else { pending(source) }
            if let failure = controller.trashFailure {
                Text(LocalizedStringKey(failure)).font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("unified.trash.issue")
            }
            ForEach(controller.trashProblems, id: \.target) { problem in
                Text(LocalizedStringKey(UnifiedSearchTrashCopy.reason(problem.reason))).font(DaybookType.caption)
                    .accessibilityIdentifier("unified.trash.problem." + problem.target.searchIdentifier)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .contain).accessibilityIdentifier("unified.trash.submission")
    }

    private func pending(_ source: UnifiedSearchBuffer) -> some View {
        let preview = controller.currentTrashPreview
        let accepted = controller.currentTrashAcceptance != nil
        return VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.trash.pending").font(DaybookType.body)
            if !controller.hasTrash { Text("unified.trash.single").font(DaybookType.caption) }
            if let preview {
                UnifiedSearchTrashImpact(impacts: preview.impacts, counts: preview.counts,
                                         remove: preview.edit == .batch && preview.impacts.count > 1 ? { target in
                    controller.removeTrashTarget(target, preview: preview, source: source)
                } : nil)
                if accepted { Text("unified.trash.accepted").font(DaybookType.caption) }
                else {
                    UnifiedSearchPlanButton(title: "unified.trash.accept", identifier: "unified.trash.accept", variant: .prominent) {
                        controller.acceptTrash(preview, source: source)
                    }.disabled(controller.settingSubmitting || preview.counts.exceedsLimit && preview.edit == .batch)
                }
            } else {
                Text(controller.trashPreview == nil ? "unified.trash.baseline" : "unified.trash.stale").font(DaybookType.caption)
            }
            UnifiedSearchPlanButton(title: "unified.trash.prepare", identifier: "unified.trash.prepare") {
                controller.prepareTrash(source)
            }.disabled(controller.settingSubmitting || !controller.hasTrash)
            UnifiedSearchPlanButton(title: "unified.trash.review", identifier: "unified.trash.review", variant: .prominent) {
                controller.requestOperationSubmit(source)
            }.disabled(controller.settingSubmitting || !accepted)
            Text("unified.trash.reviewHint").font(DaybookType.micro).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func result(_ facts: CommandTrashFacts, unit: CommandExecutionUnit) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text(LocalizedStringKey(UnifiedSearchTrashCopy.result(facts)))
                .font(DaybookType.body).accessibilityIdentifier("unified.trash.status")
            if facts.state == .saved {
                Text(verbatim: L10n.format("unified.trash.savedCount", locale: locale, facts.counts.targets,
                                           facts.counts.subtasks, facts.counts.attachments))
                    .font(DaybookType.caption).accessibilityIdentifier("unified.trash.savedCount")
                Text("unified.trash.restoreHint").font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
                if !(facts.publication == .returned && !facts.publicationFailed) { Text("unified.field.publicationIssue").font(DaybookType.caption) }
                if facts.registrationFailed { Text("unified.field.registrationIssue").font(DaybookType.caption) }
                ForEach(facts.external, id: \.target) { external in
                    UnifiedSearchTaskExternalFeedback(authorizationCall: "notCalled", authorizationResult: "unknown",
                        notificationRequested: external.notificationRequested, calendarRequested: external.calendarRequested,
                        unit: unit, externalResults: [.notification: external.notification, .calendar: external.calendar])
                }
            }
            if facts.conflict { Text("unified.trash.targetsChanged").font(DaybookType.caption) }
            if facts.state == .unknown { Text("unified.trash.unknownDetail").font(DaybookType.caption) }
            Text("unified.trash.held").font(DaybookType.caption)
        }
    }
}

struct UnifiedSearchTrashImpact: View {
    let impacts: [CommandTrashTargetImpact]
    let counts: CommandTrashCounts
    var remove: ((CommandObjectReference) -> Void)?
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text(verbatim: L10n.format("unified.trash.count", locale: locale, counts.targets, counts.subtasks, counts.attachments))
                .font(DaybookType.body.weight(.semibold)).accessibilityIdentifier("unified.trash.count")
            if counts.notes > 0 {
                Text(verbatim: L10n.format("unified.trash.notes", locale: locale, counts.notes)).font(DaybookType.caption)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("unified.trash.notes")
            }
            if counts.exceedsLimit { Text("unified.trash.writeLimit").font(DaybookType.caption) }
            if impacts.count > 3 {
                ScrollView { rows }.frame(height: 160).modifier(DaybookScrollTargetModifier())
                    .accessibilityIdentifier("unified.trash.details")
            } else { rows }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("unified.trash.values")
    }

    private var rows: some View {
        LazyVStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            ForEach(impacts, id: \.target) { impact in
                VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
                    Text(verbatim: impact.title).font(DaybookType.body).fixedSize(horizontal: false, vertical: true)
                    Text(LocalizedStringKey(UnifiedSearchResultCopy.typeKey(impact.target.type))).font(DaybookType.caption)
                    if let parent = impact.parentTitle {
                        Text(verbatim: L10n.format("unified.trash.parent", locale: locale, parent)).font(DaybookType.caption)
                    }
                    if !impact.subtasks.isEmpty || !impact.attachments.isEmpty {
                        Text(verbatim: L10n.format("unified.trash.cascade", locale: locale, impact.subtasks.count, impact.attachments.count))
                            .font(DaybookType.caption)
                    }
                    if let remove {
                        Button("unified.batch.removeTarget") { remove(impact.target) }
                            .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                            .accessibilityIdentifier("unified.trash.remove." + impact.target.searchIdentifier)
                    }
                    DaybookDivider()
                }.accessibilityElement(children: .contain)
                    .accessibilityIdentifier("unified.trash.target." + impact.target.searchIdentifier)
            }
        }
    }
}
