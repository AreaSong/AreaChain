import SwiftUI

struct UnifiedSearchRoutineSubmission: View {
    @Bindable var controller: UnifiedSearchController
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    var body: some View {
        let source = controller.buffer
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            if let unit = controller.routineUnit, let facts = unit.routine {
                result(facts, unit: unit, source: source)
            } else if controller.settingExecution != nil { Text("unified.routine.held").font(DaybookType.caption) }
            else { pending(source) }
            if let failure = controller.routineFailure {
                Text(LocalizedStringKey(failure)).font(DaybookType.caption).accessibilityIdentifier("unified.routine.issue")
            }
        }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .contain).accessibilityIdentifier("unified.routine.submission")
    }

    private func pending(_ source: UnifiedSearchBuffer) -> some View {
        let preview = controller.currentRoutinePreview
        let accepted = controller.currentRoutineAcceptance != nil
        return VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.routine.pending").font(DaybookType.body)
            if !controller.hasRoutine { Text("unified.routine.single").font(DaybookType.caption) }
            if let preview {
                UnifiedSearchRoutineImpact(preview: preview)
                if preview.noChange { Text("unified.routine.noChange").font(DaybookType.caption) }
                if accepted { Text("unified.routine.accepted").font(DaybookType.caption) }
                else {
                    UnifiedSearchPlanButton(title: "unified.routine.accept", identifier: "unified.routine.accept", variant: .prominent) {
                        controller.acceptRoutine(preview, source: source)
                    }.disabled(controller.settingSubmitting)
                }
            } else { Text(controller.routinePreview == nil ? "unified.routine.baseline" : "unified.routine.stale").font(DaybookType.caption) }
            UnifiedSearchPlanButton(title: "unified.routine.prepare", identifier: "unified.routine.prepare") {
                controller.prepareRoutine(source)
            }.disabled(controller.settingSubmitting || !controller.hasRoutine)
            UnifiedSearchPlanButton(title: "unified.routine.save", identifier: "unified.routine.save", variant: .prominent) {
                controller.requestOperationSubmit(source)
            }.disabled(controller.settingSubmitting || !accepted)
        }
    }

    private func result(_ facts: CommandRoutineFacts, unit: CommandExecutionUnit, source: UnifiedSearchBuffer) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text(LocalizedStringKey(UnifiedSearchRoutineCopy.result(facts)))
                .font(DaybookType.body).accessibilityIdentifier("unified.routine.status")
            if facts.state == .saved {
                if let title = facts.savedTitle { Text(verbatim: title).font(DaybookType.body) }
                let values = savedValues(facts)
                if !values.isEmpty {
                    Text(verbatim: values).font(DaybookType.body).accessibilityIdentifier("unified.routine.savedValues")
                }
                Text(facts.publication == .returned && !facts.publicationFailed ? "unified.task.published" : "unified.routine.publicationIssue")
                    .font(DaybookType.caption)
                if let tags = facts.savedTagIDs {
                    Text(verbatim: L10n.format("unified.routine.savedTagCount", locale: locale, tags.count))
                        .font(DaybookType.caption).accessibilityIdentifier("unified.routine.savedTagCount")
                }
                if let effects = facts.savedTagEffects {
                    Text(verbatim: L10n.format("unified.field.tagsSaved", locale: locale,
                        effects.filter { $0 == .createAndAssociate }.count,
                        effects.filter { $0 == .restoreAndAssociate }.count,
                        effects.filter { $0 == .associateLive }.count)).font(DaybookType.caption)
                }
                if facts.registrationFailed { Text("unified.routine.registrationIssue").font(DaybookType.caption) }
                UnifiedSearchTaskExternalFeedback(authorizationCall: String(describing: facts.authorizationRequest),
                    authorizationResult: String(describing: facts.authorizationResult),
                    notificationRequested: facts.notificationRequested, calendarRequested: facts.calendarRequested, unit: unit)
            }
            if facts.conflict { Text("unified.routine.fields").font(DaybookType.caption) }
            if facts.state == .unknown {
                UnifiedSearchPlanButton(title: "unified.task.verify", identifier: "unified.routine.verify") { controller.verifyRoutine(source) }
                if let verification = controller.routineVerification {
                    Text(LocalizedStringKey("unified.routine.presence." + String(describing: verification))).font(DaybookType.caption)
                }
            }
            Text("unified.routine.held").font(DaybookType.caption)
        }
    }

    private func savedValues(_ facts: CommandRoutineFacts) -> String {
        guard let fields = facts.savedValues else { return "" }
        var values: [String] = []
        if case .number(let mask?) = fields[.weekdayMask] {
            values.append(WeekdayMask.selectedLabels(mask, locale: locale, calendar: calendar))
        }
        if case .number(let minutes) = fields[.remindMinutes] {
            values.append(minutes.map { UnifiedSearchOperationCopy.value(.time($0), locale: locale, calendar: calendar) }
                ?? L10n.format("unified.field.noReminder", locale: locale))
        }
        if case .flag(let important) = fields[.isImportant], case .flag(let urgent) = fields[.isUrgent] {
            values.append(UnifiedSearchOperationCopy.value(.choice(important ? (urgent ? "p1" : "p2") : (urgent ? "p3" : "p4")),
                                                            locale: locale, calendar: calendar))
        }
        return values.joined(separator: " · ")
    }
}
