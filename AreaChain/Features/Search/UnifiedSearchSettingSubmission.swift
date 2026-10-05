import SwiftUI

/// 原操作面板中的普通设置反馈；所有按钮带渲染时的原身份，只调用具体适配入口。
struct UnifiedSearchSettingSubmission: View {
    @Bindable var controller: UnifiedSearchController
    @Environment(\.locale) private var locale

    var body: some View {
        let source = controller.buffer
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            if controller.fileSettings != nil {
                UnifiedSearchFileSettingSubmission(controller: controller)
            } else if let run = controller.settingExecution {
                if let report = controller.settingReport, let unit = run.units.first,
                   let draft = run.snapshot.items.first?.draft {
                    result(report, unit: unit, draft: draft, source: source)
                } else { Text("unified.setting.runHeld").font(DaybookType.caption) }
            } else if controller.settingDraft != nil || controller.plan?.items.isEmpty == false {
                pending(source)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("unified.setting.submission")
    }

    private func pending(_ source: UnifiedSearchBuffer) -> some View {
        let issue = controller.settingIssue
        let confirmation = controller.settingConfirmation.flatMap { $0.source == source ? $0 : nil }
        return VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            if let confirmation {
                conflict(confirmation.evidence.conflict)
                conflictChoices(confirmation)
            } else if case .conflict(let evidence) = issue {
                conflict(evidence)
                UnifiedSearchPlanButton(title: "unified.setting.reviewConflict", identifier: "unified.setting.reviewConflict") {
                    controller.requestSettingConflict(source: source)
                }
            } else {
                Text(LocalizedStringKey(issue.map(UnifiedSearchSettingCopy.issue) ?? controller.settingMessage))
                    .font(DaybookType.caption)
                    .accessibilityIdentifier("unified.setting.status")
            }
            if controller.hasSettingAdapter, controller.editingDraft?.baseline.preference == nil,
               controller.editingDraft.map({ controller.localSettings?.supports($0.commandID) == true }) == true {
                UnifiedSearchPlanButton(title: "unified.setting.readBaseline", identifier: "unified.setting.readBaseline") {
                    controller.requestSettingBaseline(source: source)
                }
            }
            UnifiedSearchPlanButton(title: LocalizedStringKey(UnifiedSearchSettingCopy.action(controller.settingDraft?.commandID)),
                identifier: "unified.setting.submit", variant: .prominent) {
                controller.requestOperationSubmit(source)
            }
            .disabled(controller.settingSubmitting || issue != nil || confirmation != nil)
            if issue == nil { Text("unified.setting.finalCheck").font(DaybookType.micro) }
        }
    }

    private func conflict(_ evidence: LocalSettingCommandConflict) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.setting.conflict").font(DaybookType.body.weight(.semibold))
            UnifiedSearchSettingValues(before: evidence.baseline.memory, after: controller.settingDraft?.arguments.first?.value,
                current: evidence.current.storedValue.map(LocalSettingCommandMapping.commandValue), conflict: true)
        }
    }

    private func conflictChoices(_ confirmation: UnifiedSearchSettingConfirmation) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            UnifiedSearchPlanButton(title: "unified.setting.adopt", identifier: "unified.setting.adopt") {
                controller.resolveSettingConflict(confirmation, choice: .adoptCurrent)
            }
            UnifiedSearchPlanButton(title: "unified.setting.overwrite", identifier: "unified.setting.overwrite") {
                controller.resolveSettingConflict(confirmation, choice: .confirmOverwrite)
            }
            UnifiedSearchPlanButton(title: "unified.setting.edit", identifier: "unified.setting.edit") {
                controller.resolveSettingConflict(confirmation, choice: .continueEditing)
            }
        }.disabled(controller.settingSubmitting)
    }

    private func result(_ report: LocalSettingCommandReport, unit: CommandExecutionUnit,
                        draft: CommandDraft, source: UnifiedSearchBuffer) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            if let command = CommandCatalog.standard.command(id: draft.commandID) {
                Text(verbatim: command.name(locale: locale)).font(DaybookType.body.weight(.semibold))
            }
            Text(LocalizedStringKey(UnifiedSearchSettingCopy.result(report, unit: unit)))
                .font(DaybookType.body).accessibilityIdentifier("unified.setting.status")
            if unit.local == .committed { Text("unified.setting.readback").font(DaybookType.caption) }
            if case .conflict(let evidence) = report.outcome {
                UnifiedSearchSettingValues(before: evidence.baseline.memory, after: draft.arguments.first?.value,
                    current: evidence.current.storedValue.map(LocalSettingCommandMapping.commandValue), conflict: true)
            }
            if unit.local == .unknown { Text("unified.setting.unknownDetail").font(DaybookType.caption) }
            if let failure = controller.settingFailure, failure.source == source {
                Text(LocalizedStringKey(UnifiedSearchSettingCopy.issue(failure.issue))).font(DaybookType.caption)
            }
            resultActions(report, unit: unit, source: source)
        }
    }

    private func resultActions(_ report: LocalSettingCommandReport, unit: CommandExecutionUnit,
                               source: UnifiedSearchBuffer) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            if unit.state == .succeeded {
                UnifiedSearchPlanButton(title: "unified.setting.done", identifier: "unified.setting.done") {
                    controller.acknowledgeSettingResult(report, source: source)
                }
            }
            if controller.localSettings?.canReturnToPlan(report.receipt.attempt, expecting: source.lease) == true {
                UnifiedSearchPlanButton(title: "unified.setting.edit", identifier: "unified.setting.return") {
                    controller.returnSettingToPlan(report, source: source)
                }
            }
            if controller.localSettings?.canRetryPresentation(report.receipt.attempt, expecting: source.lease) == true {
                UnifiedSearchPlanButton(title: "unified.setting.retryPresentation", identifier: "unified.setting.retryPresentation") {
                    controller.retrySettingPresentation(report, source: source)
                }
            }
        }.disabled(controller.settingSubmitting)
    }
}

struct UnifiedSearchSettingValues: View {
    let before: CommandValue?
    let after: CommandValue?
    var current: CommandValue?
    var conflict = false
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            line(conflict ? "unified.setting.original" : "unified.setting.current", value: before, original: true)
            if conflict { line("unified.setting.current", value: current, original: true) }
            line("unified.setting.proposed", value: after)
        }
        .font(DaybookType.caption).foregroundStyle(DaybookPalette.text.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func line(_ key: String, value: CommandValue?, original: Bool = false) -> some View {
        let text = original && value == nil ? L10n.format("unified.setting.unreadValue", locale: locale)
            : UnifiedSearchSettingCopy.value(value, locale: locale, calendar: calendar)
        return Text(verbatim: L10n.format(key, locale: locale) + ": " + text)
    }
}
