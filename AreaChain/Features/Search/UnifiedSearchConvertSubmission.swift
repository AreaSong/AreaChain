import SwiftUI

/// 转换沿回收的原面板：准备与接受之后，普通提交只打开共用的独立确认；结果仍由原 Run 展示。
struct UnifiedSearchConvertSubmission: View {
    @Bindable var controller: UnifiedSearchController

    var body: some View {
        let source = controller.buffer
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            if let unit = controller.convertUnit, let facts = unit.conversion { result(facts, unit: unit, source: source) }
            else if controller.settingExecution != nil { Text("unified.convert.held").font(DaybookType.caption) }
            else if let confirmation = controller.convertConfirmation, let preview = controller.convertAcceptance?.preview {
                UnifiedSearchIndependentConfirmationPanel(controller: controller, identifier: "unified.convert",
                    title: "unified.convert.confirmTitle \(preview.impact.title)", confirmTitle: "unified.convert.confirm",
                    confirm: { controller.confirmConvert(confirmation, source: source) }) {
                    UnifiedSearchConvertLossList(losses: confirmation.summary)
                }
            } else { pending(source) }
            if let failure = controller.convertFailure {
                Text(LocalizedStringKey(failure)).font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("unified.convert.issue")
            }
        }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .contain).accessibilityIdentifier("unified.convert.submission")
    }

    private func pending(_ source: UnifiedSearchBuffer) -> some View {
        let preview = controller.currentConvertPreview
        let accepted = controller.currentConvertAcceptance != nil
        return VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.convert.pending").font(DaybookType.body)
            if !controller.hasConvert { Text("unified.convert.single").font(DaybookType.caption) }
            if let preview {
                VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
                    Text(verbatim: preview.impact.title).font(DaybookType.body.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    UnifiedSearchConvertLossList(losses: preview.impact.losses)
                }.accessibilityElement(children: .contain).accessibilityIdentifier("unified.convert.values")
                if accepted { Text("unified.convert.accepted").font(DaybookType.caption) }
                else {
                    UnifiedSearchPlanButton(title: "unified.convert.accept", identifier: "unified.convert.accept", variant: .prominent) {
                        controller.acceptConvert(preview, source: source)
                    }.disabled(controller.settingSubmitting)
                }
            } else {
                Text(controller.convertPreview == nil ? "unified.convert.baseline" : "unified.convert.stale").font(DaybookType.caption)
            }
            UnifiedSearchPlanButton(title: "unified.convert.prepare", identifier: "unified.convert.prepare") {
                controller.prepareConvert(source)
            }.disabled(controller.settingSubmitting || !controller.hasConvert)
            UnifiedSearchPlanButton(title: "unified.convert.review", identifier: "unified.convert.review", variant: .prominent) {
                controller.requestOperationSubmit(source)
            }.disabled(controller.settingSubmitting || !accepted)
            Text("unified.convert.reviewHint").font(DaybookType.micro).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func result(_ facts: CommandConvertFacts, unit: CommandExecutionUnit, source: UnifiedSearchBuffer) -> some View {
        let toRoutine = facts.created.type == .routine
        return VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text(LocalizedStringKey(UnifiedSearchConvertCopy.result(facts)))
                .font(DaybookType.body).accessibilityIdentifier("unified.convert.status")
            if facts.state == .saved {
                Text(toRoutine ? "unified.convert.created.routine" : "unified.convert.created.todo").font(DaybookType.caption)
                    .fixedSize(horizontal: false, vertical: true)
                UnifiedSearchPlanButton(title: toRoutine ? "unified.convert.open.routine" : "unified.convert.open.todo",
                                        identifier: "unified.convert.open", variant: .prominent) {
                    controller.openConvertedObject(facts, source: source)
                }
                Text("unified.convert.restoreHint").font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
                if !(facts.publication == .returned && !facts.publicationFailed) { Text("unified.field.publicationIssue").font(DaybookType.caption) }
                if facts.registrationFailed { Text("unified.field.registrationIssue").font(DaybookType.caption) }
                ForEach(facts.external, id: \.target) { external in
                    UnifiedSearchTaskExternalFeedback(authorizationCall: "notCalled", authorizationResult: "unknown",
                        notificationRequested: external.notificationRequested, calendarRequested: external.calendarRequested,
                        unit: unit, externalResults: [.notification: external.notification, .calendar: external.calendar])
                }
            }
            if facts.conflict { Text("unified.convert.problem.changed").font(DaybookType.caption) }
            if facts.state == .unknown { unknown(source) }
            Text("unified.convert.held").font(DaybookType.caption)
        }
    }

    @ViewBuilder private func unknown(_ source: UnifiedSearchBuffer) -> some View {
        Text("unified.convert.unknownDetail").font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
        UnifiedSearchPlanButton(title: "unified.convert.verify", identifier: "unified.convert.verify") {
            controller.verifyConvertUnknown(source)
        }
        if let verification = controller.convertVerification {
            Text(LocalizedStringKey(UnifiedSearchConvertCopy.outcome(verification))).font(DaybookType.caption)
                .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("unified.convert.verification")
        }
    }
}

/// 预览与确认共用的损失清单：会新建什么、哪些字段不迁移、哪些关联改挂或留下、原对象去向。
struct UnifiedSearchConvertLossList: View {
    let losses: CommandConvertLosses
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            ForEach(lines, id: \.key) { line in
                Text(verbatim: line.text).font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("unified.convert.loss." + line.key)
            }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("unified.convert.losses")
    }

    private struct Line { let key: String; let text: String }

    private var lines: [Line] {
        func line(_ key: String, _ text: (String) -> String = { $0 }) -> Line {
            let full = "unified.convert.loss." + key
            return Line(key: key, text: text(full))
        }
        let plain: (String) -> String = { L10n.format($0, locale: locale) }
        switch losses {
        case .todoToRoutine(let value):
            var result = [line("headline.toRoutine", plain),
                          line("weekday") { L10n.format($0, locale: locale, value.dayKey, weekdayName(value.weekdayMask)) },
                          line("dueAndDone", plain)]
            if value.subtasks > 0 {
                result.append(line("subtasks") { L10n.format($0, locale: locale, value.subtasks, value.doneSubtasks) })
            }
            if value.attachments > 0 {
                result.append(line("attachments.toRoutine") { L10n.format($0, locale: locale, value.attachments) })
            }
            if value.notes { result.append(line("notes", plain)) }
            result.append(line("original.todo", plain))
            return result
        case .routineToTodo(let value):
            var result = [line("headline.toTodo", plain), line("today") { L10n.format($0, locale: locale, value.today) },
                          line("schedule", plain), line("checks") { L10n.format($0, locale: locale, value.checks) }]
            if value.templates > 0 { result.append(line("templates") { L10n.format($0, locale: locale, value.templates) }) }
            if value.attachments > 0 {
                result.append(line("attachments.toTodo") { L10n.format($0, locale: locale, value.attachments) })
            }
            if value.notes { result.append(line("notes", plain)) }
            result.append(line("original.routine", plain))
            return result
        }
    }

    /// 单日掩码显示该星期名；原日期无法解析时原规则取每天。
    private func weekdayName(_ mask: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        guard let weekday = (1...7).first(where: { WeekdayMask.only(weekday: $0) == mask }) else {
            return L10n.format("unified.convert.loss.everyDay", locale: locale)
        }
        return calendar.standaloneWeekdaySymbols[weekday - 1]
    }
}
