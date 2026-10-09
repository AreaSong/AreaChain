import SwiftUI

/// 原计划面板内的创建效果和事实；不持有第二份参数，也不从候选 UUID 推断成功。
struct UnifiedSearchRoutineCreateSubmission: View {
    @Bindable var controller: UnifiedSearchController
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    private typealias Copy = UnifiedSearchTaskCompositionCopy

    var body: some View {
        let source = controller.buffer
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            if let unit = controller.routineCreationUnit, let facts = unit.routineCreation {
                result(facts, unit: unit, source: source)
            } else if controller.settingExecution != nil {
                Text("unified.routineCreate.held").font(DaybookType.caption)
            } else {
                pending(source)
            }
            if let failure = controller.routineCreateFailure {
                Text(LocalizedStringKey(failure)).font(DaybookType.caption)
                    .accessibilityIdentifier("unified.routineCreate.issue")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("unified.routineCreate.submission")
    }

    private func pending(_ source: UnifiedSearchBuffer) -> some View {
        let accepted = controller.currentRoutineCreateAcceptance != nil
        return VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.routineCreate.capability").font(DaybookType.caption)
            if let preview = controller.currentRoutineCreatePreview {
                UnifiedSearchRoutineCreationImpact(preview: preview)
                if accepted { Text("unified.composition.accepted").font(DaybookType.caption) }
                else {
                    UnifiedSearchPlanButton(title: "unified.routineCreate.accept", identifier: "unified.routineCreate.accept") {
                        controller.acceptRoutineCreation(preview, source: source)
                    }.disabled(!preview.canAccept || controller.settingSubmitting)
                }
            } else {
                Text(controller.routineCreatePreview == nil ? "unified.composition.unprepared" : "unified.routineCreate.stale")
                    .font(DaybookType.caption)
            }
            UnifiedSearchPlanButton(title: "unified.routineCreate.prepare", identifier: "unified.routineCreate.prepare") {
                controller.prepareRoutineCreation(source)
            }.disabled(controller.settingSubmitting)
            UnifiedSearchPlanButton(title: "unified.routineCreate.create", identifier: "unified.routineCreate.create", variant: .prominent) {
                controller.requestOperationSubmit(source)
            }.disabled(controller.settingSubmitting || !accepted)
        }
    }

    private func result(_ facts: CommandRoutineCreateFacts, unit: CommandExecutionUnit, source: UnifiedSearchBuffer) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text(LocalizedStringKey("unified.routineCreate." + String(describing: facts.state)))
                .font(DaybookType.body).accessibilityIdentifier("unified.routineCreate.status")
            if let object = facts.createdObject, let saved = facts.savedRoutine {
                Text(verbatim: object.id.uuidString).font(DaybookType.micro).accessibilityIdentifier("unified.routineCreate.savedID")
                Text(verbatim: saved.title).font(DaybookType.body)
                Text(verbatim: WeekdayMask.selectedLabels(saved.weekdayMask, locale: locale, calendar: calendar))
                Text(verbatim: Copy.priority(.init(isImportant: saved.isImportant, isUrgent: saved.isUrgent)) + " · "
                    + (saved.remindMinutes.map(Copy.time) ?? L10n.format("unified.field.noReminder", locale: locale)))
                Text(facts.publication == .returned && !facts.publicationFailed ? "unified.task.published" : "unified.routine.publicationIssue")
                if facts.registrationFailed { Text("unified.routine.registrationIssue") }
                if let tags = facts.savedTagEffects {
                    Text(verbatim: L10n.format("unified.routineCreate.savedTags", locale: locale,
                        tags.filter { $0 == .createAndAssociate }.count, tags.filter { $0 == .restoreAndAssociate }.count,
                        tags.filter { $0 == .associateLive }.count))
                }
                UnifiedSearchTaskExternalFeedback(authorizationCall: String(describing: facts.authorizationRequest),
                    authorizationResult: String(describing: facts.authorizationResult),
                    notificationRequested: facts.notificationRequested, calendarRequested: facts.calendarRequested, unit: unit)
            }
            if facts.state == .unknown {
                UnifiedSearchPlanButton(title: "unified.task.verify", identifier: "unified.routineCreate.verify") {
                    controller.verifyRoutineCreation(source)
                }
                if let verification = controller.routineCreateVerification {
                    Text(LocalizedStringKey("unified.routine.presence." + String(describing: verification)))
                }
            }
            Text("unified.routineCreate.held")
        }.font(DaybookType.caption)
    }
}
