import SwiftUI

struct UnifiedSearchRoutineCreationImpact: View {
    let preview: CommandRoutineCreatePreview
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    private typealias Copy = UnifiedSearchTaskCompositionCopy
    var body: some View { effects(preview) }

    private func effects(_ preview: CommandRoutineCreatePreview) -> some View {
        let fields = preview.composition
        return VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.composition.final").font(DaybookType.body.weight(.semibold))
            Text(verbatim: fields.title.isEmpty ? L10n.format("unified.composition.metadata", locale: locale) : fields.title)
                .font(DaybookType.body).accessibilityIdentifier("unified.routineCreate.title")
            Text(verbatim: WeekdayMask.selectedLabels(preview.weekdayMask, locale: locale, calendar: calendar))
                .font(DaybookType.body).accessibilityIdentifier("unified.routineCreate.weekdays")
            Text(verbatim: L10n.format("unified.routineCreate.defaults", locale: locale, preview.createdDayKey, preview.sortOrder))
                .font(DaybookType.caption).accessibilityIdentifier("unified.routineCreate.defaults")
            if case .shortText(let raw) = preview.arguments.first(where: { $0.parameter == .title })?.value {
                Text("unified.composition.raw").font(DaybookType.caption)
                Text(verbatim: raw).font(DaybookType.caption)
            }
            Text(verbatim: fields.priorityFlags.map(Copy.priority) ?? L10n.format("unified.composition.conflict", locale: locale))
            Text(verbatim: Copy.field(fields.priority, locale: locale, format: Copy.priority,
                                     unspecifiedKey: "unified.routineCreate.unspecified"))
            Text(verbatim: fields.reminder.value.map(Copy.time) ?? L10n.format("unified.field.noReminder", locale: locale))
            Text(verbatim: Copy.field(fields.reminder, locale: locale, format: Copy.time,
                                     unspecifiedKey: "unified.routineCreate.unspecified"))
            if fields.priority.hasConflict { Text("unified.composition.priorityConflict") }
            if fields.reminder.hasConflict { Text("unified.composition.timeConflict") }
            if !fields.hasEffectiveContent { Text("unified.composition.empty") }
            UnifiedSearchTaskTagSummary(associations: fields.tags.final)
            UnifiedSearchTaskTagEffects(associations: fields.tags.final)
                .accessibilityIdentifier("unified.routineCreate.tags")
            ForEach(Array(fields.tags.removed.enumerated()), id: \.offset) { _, target in
                Text(verbatim: L10n.format("unified.composition.removed", locale: locale) + " · " + Copy.name(target))
            }
            ForEach(Array(fields.tags.problems.enumerated()), id: \.offset) { _, problem in
                Text(LocalizedStringKey(Copy.problem(problem.kind)))
            }
            Text("unified.composition.notSaved")
        }.font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
    }

}
