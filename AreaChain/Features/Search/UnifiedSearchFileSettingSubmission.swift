import SwiftUI

/// 文件模式的整组结果投影，成员值仅从原计划或原运行读取。
struct UnifiedSearchFileSettingSubmission: View {
    @Bindable var controller: UnifiedSearchController
    @Environment(\.locale) private var locale

    var body: some View {
        let source = controller.buffer
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            if let report = controller.fileSettingReport {
                result(report, source: source)
            } else if controller.settingExecution != nil {
                Text("unified.setting.runHeld").font(DaybookType.caption)
            } else if controller.settingDraft != nil || controller.plan?.items.isEmpty == false {
                pending(source)
            }
        }.disabled(controller.settingSubmitting)
    }

    private func pending(_ source: UnifiedSearchBuffer) -> some View {
        let issue = controller.fileSettingIssue
        let confirmation = controller.fileSettingConfirmation.flatMap { $0.source == source ? $0 : nil }
        let count = controller.operations?.active == nil ? controller.plan?.items.count ?? 0 : 1
        return VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text(LocalizedStringKey(issue ?? "unified.group.ready"))
                .font(DaybookType.caption).accessibilityIdentifier("unified.setting.status")
            if let confirmation {
                conflict(confirmation)
            } else if issue == "unified.group.conflict" {
                control("unified.setting.reviewConflict") { controller.requestFileSettingConflict(source) }
            }
            control(count > 1 ? "unified.group.prepare" : "unified.setting.readBaseline") {
                controller.requestFileSettingPreparation(source)
            }.disabled(issue == nil || confirmation != nil)
            UnifiedSearchPlanButton(title: LocalizedStringKey(L10n.format("unified.group.submit", locale: locale, count)),
                                    identifier: "unified.setting.submit", variant: .prominent) {
                controller.requestOperationSubmit(source)
            }
            .onKeyPress(keys: [.return]) { press in
                if press.modifiers == .command { controller.requestOperationSubmit(source) }
                return .handled
            }
            .disabled(issue != nil || confirmation != nil)
            Text("unified.setting.finalCheck").font(DaybookType.micro)
        }
    }

    private func conflict(_ confirmation: UnifiedSearchFileSettingConfirmation) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            ForEach(confirmation.evidence.differences, id: \.command) { difference in
                if let command = CommandCatalog.standard.command(id: difference.command) {
                    Text(verbatim: command.name(locale: locale)).font(DaybookType.body.weight(.medium))
                }
                UnifiedSearchSettingValues(before: difference.baseline,
                    after: controller.plan?.items.first { $0.draft.commandID == difference.command }?.draft.arguments.first?.value,
                    current: difference.current, conflict: true)
            }
            control("unified.setting.adopt") { controller.resolveFileSettingConflict(confirmation, choice: .adoptCurrent) }
            control("unified.setting.overwrite") { controller.resolveFileSettingConflict(confirmation, choice: .confirmOverwrite) }
            control("unified.setting.edit") { controller.resolveFileSettingConflict(confirmation, choice: .continueEditing) }
        }
    }

    private func result(_ report: FileLocalSettingCommandReport, source: UnifiedSearchBuffer) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text(verbatim: L10n.format("unified.group.title", locale: locale, report.identity.members.count))
                .font(DaybookType.body.weight(.semibold))
            Text(LocalizedStringKey(UnifiedSearchFileSettingCopy.result(report)))
                .font(DaybookType.body).accessibilityIdentifier("unified.setting.status")
            if case .committed(_, let cleanup) = UnifiedSearchFileSettingCopy.commit(report), cleanup {
                Text("unified.group.cleanupPending").font(DaybookType.caption)
            }
            if let failure = controller.fileSettingFailure, failure.source == source {
                Text(LocalizedStringKey(failure.message)).font(DaybookType.caption)
            }
            if case .unknown = UnifiedSearchFileSettingCopy.commit(report) {
                Text("unified.group.verifyDetail").font(DaybookType.caption)
                control("unified.group.verify") { controller.fileSettingResultAction(.verify, report: report, source: source) }
            }
            if UnifiedSearchFileSettingCopy.canReturn(report) {
                control("unified.group.return") { controller.fileSettingResultAction(.returnToPlan, report: report, source: source) }
            }
            if UnifiedSearchFileSettingCopy.presentation(report)?.incomplete == true {
                control("unified.setting.retryPresentation") {
                    controller.fileSettingResultAction(.presentation, report: report, source: source)
                }
            }
            if controller.settingExecution?.units.first?.state == .succeeded {
                control("unified.setting.done") { controller.fileSettingResultAction(.done, report: report, source: source) }
            }
        }
    }

    private func control(_ key: String, action: @escaping () -> Void) -> some View {
        UnifiedSearchPlanButton(title: LocalizedStringKey(key), identifier: key, action: action)
    }
}
