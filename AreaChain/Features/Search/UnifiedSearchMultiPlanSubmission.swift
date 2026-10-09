import SwiftUI

/// 原 PlanList 内的执行部分：只投影同一 Run，保存结果不能回到可重放草稿。
struct UnifiedSearchMultiPlanSubmission: View {
    @Bindable var controller: UnifiedSearchController
    @Environment(\.locale) private var locale

    var body: some View {
        let source = controller.buffer
        VStack(alignment: .leading, spacing: DaybookSpacing.md) {
            Text("unified.multi.title").font(DaybookType.body.weight(.semibold))
            Text("unified.multi.boundaries").font(DaybookType.caption)
            if let run = controller.settingExecution, run.multiPlan != nil {
                running(run, source: source)
            } else {
                prepared(source)
            }
            if let failure = controller.multiPlanFailure {
                Text(LocalizedStringKey(failure)).font(DaybookType.caption)
                    .accessibilityIdentifier("unified.multi.issue")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("unified.multi.plan")
    }

    private func prepared(_ source: UnifiedSearchBuffer) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            UnifiedSearchPlanButton(title: "unified.multi.prepare", identifier: "unified.multi.prepare") {
                controller.prepareMultiPlan(source)
            }.disabled(controller.settingSubmitting || controller.plan?.editing != nil)
            if let preview = controller.currentMultiPlanPreview {
                ForEach(Array(preview.identity.units.enumerated()), id: \.offset) { index, members in
                    if let first = members.first, let value = preview.members[first] {
                        previewHeader(index, members: members)
                        ForEach(controller.plan?.items.filter { members.contains($0.id) } ?? [], id: \.id) { item in
                            if let command = CommandCatalog.standard.command(id: item.draft.commandID) {
                                Text(verbatim: command.name(locale: locale)).font(DaybookType.body.weight(.medium))
                            }
                            referenceLabels(item)
                        }
                        UnifiedSearchMultiPlanImpact(preview: value)
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("unified.multi.preview." + first.uuidString)
                    }
                }
                UnifiedSearchPlanButton(title: "unified.multi.submit", identifier: "unified.multi.submit", variant: .prominent) {
                    controller.requestOperationSubmit(source)
                }.disabled(controller.settingSubmitting || (try? preview.validateExecutable()) == nil)
            } else { Text("unified.multi.unprepared").font(DaybookType.caption) }
        }
    }

    private func previewHeader(_ index: Int, members: [UUID]) -> some View {
        Text(verbatim: L10n.format("unified.multi.unit", locale: locale, index + 1, members.count))
            .font(DaybookType.body.weight(.medium))
    }

    private func running(_ run: CommandExecutionRun, source: UnifiedSearchBuffer) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.md) {
            Text(verbatim: L10n.format("unified.multi.progress", locale: locale,
                run.units.filter { $0.state == .succeeded }.count, run.units.count))
                .font(DaybookType.body).accessibilityIdentifier("unified.multi.progress")
            if run.hasUnknownCommit {
                Text("unified.multi.unknown").font(DaybookType.body.weight(.medium))
                    .accessibilityIdentifier("unified.multi.paused")
                Text("unified.multi.unknownDetail").font(DaybookType.caption)
            }
            ForEach(Array(run.units.enumerated()), id: \.element.id) { index, unit in
                unitRow(unit, index: index, run: run, source: source)
                DaybookDivider()
            }
            if controller.multiPlan?.requiresDisplayReview == true, !run.hasUnknownCommit,
               run.units.contains(where: { $0.state == .ready }) {
                UnifiedSearchPlanButton(title: "unified.multi.reviewRemaining", identifier: "unified.multi.reviewRemaining") {
                    controller.requestOperationSubmit(source)
                }
            } else if let pending = controller.multiPlan?.pending, !run.hasUnknownCommit,
                      controller.multiPlan?.requiresDisplayReview == false {
                Text("unified.multi.changed").font(DaybookType.body.weight(.medium))
                UnifiedSearchMultiPlanImpact(preview: pending)
                UnifiedSearchPlanButton(title: "unified.multi.confirm", identifier: "unified.multi.confirm", variant: .prominent) {
                    controller.requestOperationSubmit(source)
                }.disabled(controller.settingSubmitting || controller.multiPlanTask != nil)
            } else if !run.hasUnknownCommit, run.units.contains(where: { $0.state == .ready }), controller.multiPlanTask == nil {
                UnifiedSearchPlanButton(title: "unified.multi.resume", identifier: "unified.multi.resume") {
                    controller.requestOperationSubmit(source)
                }
            }
            Text("unified.multi.runOnly").font(DaybookType.micro)
        }
    }

    private func unitRow(_ unit: CommandExecutionUnit, index: Int, run: CommandExecutionRun,
                         source: UnifiedSearchBuffer) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            previewHeader(index, members: unit.members)
            ForEach(run.snapshot.items.filter { unit.members.contains($0.id) }, id: \.id) { item in
                if let command = CommandCatalog.standard.command(id: item.draft.commandID) {
                    Text(verbatim: command.name(locale: locale)).font(DaybookType.body)
                }
                referenceLabels(item)
            }
            Text(LocalizedStringKey(controller.multiPlan?.pendingItemID.map(unit.members.contains) == true
                ? "unified.multi.awaitingConfirmation" : UnifiedSearchMultiPlanCopy.status(unit)))
                .font(DaybookType.body.weight(.medium))
            if unit.local == .committed && unit.state != .succeeded { Text("unified.multi.saved").font(DaybookType.caption) }
            if let object = unit.taskCreation?.savedID ?? unit.routineCreation?.savedID ?? unit.subtask?.createdObject?.id {
                Text(verbatim: object.uuidString).font(DaybookType.micro).textSelection(.enabled)
            }
            ForEach(unit.effects.keys.sorted { $0.rawValue < $1.rawValue }, id: \.self) { effect in
                if let result = unit.effects[effect] {
                    Text(verbatim: L10n.format("unified.multi.effect." + effect.rawValue, locale: locale) + ": "
                        + L10n.format("unified.multi.external." + String(describing: result), locale: locale))
                        .font(DaybookType.caption)
                }
            }
            if unit.attempt > 0 {
                Text(verbatim: L10n.format("unified.multi.attempts", locale: locale, Int(unit.attempt))).font(DaybookType.micro)
            }
            if unit.validationFailedBeforeInvocation { Text("unified.multi.validationFailed").font(DaybookType.caption) }
            actions(unit, run: run, source: source)
        }.accessibilityElement(children: .contain).accessibilityIdentifier("unified.multi.unit." + unit.id.uuidString)
    }

    private func referenceLabels(_ item: CommandPlanItem) -> some View {
        ForEach(item.links.results.keys.sorted { $0.rawValue < $1.rawValue }, id: \.self) { parameter in
            if let reference = item.links.results[parameter] {
                Text(verbatim: controller.creationReferenceLabel(reference, parameter: parameter, locale: locale))
                    .font(DaybookType.caption)
            }
        }
    }

    private func actions(_ unit: CommandExecutionUnit, run: CommandExecutionRun, source: UnifiedSearchBuffer) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            if let adapter = controller.multiPlan, let attempt = run.attempt(unit.id),
               adapter.canRetryLocal(attempt, expecting: source.lease) {
                UnifiedSearchPlanButton(title: "unified.multi.retry", identifier: "unified.multi.retry." + unit.id.uuidString) {
                    controller.retryMultiPlan(attempt, source: source)
                }
            }
            if let attempt = run.attempt(unit.id), controller.multiPlan?.canRetryExternal(attempt, expecting: source.lease) == true {
                UnifiedSearchPlanButton(title: "unified.setting.retryPresentation", identifier: "unified.multi.external." + unit.id.uuidString) {
                    controller.recoverMultiPlanExternal(attempt, source: source, verify: false)
                }
            }
            if let attempt = run.attempt(unit.id), !run.hasUnknownCommit, unit.local == .notSubmitted,
               unit.preferenceGroupCommit != nil, controller.multiPlan?.fileSettings?.multiBackendNeedsRecovery == true {
                UnifiedSearchPlanButton(title: "unified.multi.backend", identifier: "unified.multi.backend." + unit.id.uuidString) {
                    controller.recoverMultiPlanBackend(attempt, source: source)
                }
            }
            if let attempt = run.attempt(unit.id), unit.local == .unknown, unit.preferenceGroupCommit != nil {
                UnifiedSearchPlanButton(title: "unified.task.verify", identifier: "unified.multi.verify." + unit.id.uuidString) {
                    controller.recoverMultiPlanExternal(attempt, source: source, verify: true)
                }
            }
            if run.cancellationAssessment(unit.id) == .canMarkNotStarted {
                UnifiedSearchPlanButton(title: "unified.multi.cancel", identifier: "unified.multi.cancel." + unit.id.uuidString) {
                    controller.cancelMultiPlanUnit(unit.id, source: source)
                }
            }
        }.disabled(controller.settingSubmitting || controller.multiPlanTask != nil)
    }
}
