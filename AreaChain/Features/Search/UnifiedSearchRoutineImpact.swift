import SwiftUI

/// 只呈现已核验影响；有效星期与实际兼容字段写入分别展示。
struct UnifiedSearchRoutineImpact: View {
    let preview: CommandRoutinePreview
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text(verbatim: preview.targetTitle).font(DaybookType.body)
                .accessibilityIdentifier("unified.routine.targetTitle")
            Text(preview.isEnabled ? "unified.routine.enabled" : "unified.routine.disabled").font(DaybookType.caption)
            Text(verbatim: values).font(DaybookType.body).accessibilityIdentifier("unified.routine.values")
            if case .weekdays = preview.edit {
                Text("unified.routine.scheduleHint").font(DaybookType.caption)
                if preview.original != preview.final && originalWeekdays == finalWeekdays {
                    Text("unified.routine.compatibility").font(DaybookType.caption)
                }
            }
            if case .title(let edit) = preview.edit {
                if edit.priority != nil {
                    Text(verbatim: priority(preview.original) + " → " + priority(preview.final)).font(DaybookType.caption)
                }
                if edit.remindMinutes != nil {
                    Text(verbatim: reminder(preview.original) + " → " + reminder(preview.final)).font(DaybookType.caption)
                }
            }
            if let tags = preview.tags {
                Text(verbatim: names(tags.original) + " → " + names(tags.final))
                    .font(DaybookType.caption).accessibilityIdentifier("unified.routine.tags")
                let effects = tags.actions.final.filter { $0.effect != .associateLive || !tags.original.contains($0.target) }
                UnifiedSearchTaskTagSummary(associations: effects)
                UnifiedSearchTaskTagEffects(associations: effects)
            }
            Text("unified.routine.preserve").font(DaybookType.caption)
        }.fixedSize(horizontal: false, vertical: true)
    }

    private var values: String {
        switch preview.edit {
        case .title(let edit): return preview.targetTitle + " → " + edit.title
        case .weekdays:
            return WeekdayMask.selectedLabels(originalWeekdays, locale: locale, calendar: calendar)
                + " → " + WeekdayMask.selectedLabels(finalWeekdays, locale: locale, calendar: calendar)
        case .reminder: return reminder(preview.original) + " → " + reminder(preview.final)
        case .priority: return priority(preview.original) + " → " + priority(preview.final)
        case .tags: return L10n.format("command.parameter.tags", locale: locale)
        }
    }
    private var originalWeekdays: Int {
        let stored: Int?
        if case .number(let value) = preview.original[.weekdayMask] { stored = value } else { stored = nil }
        return WeekdayMask.resolved(stored: stored, weekdaysOnly: preview.original[.weekdaysOnly] == .flag(true))
    }
    private var finalWeekdays: Int {
        if case .weekdays(let mask) = preview.edit { return mask }; return WeekdayMask.all
    }
    private func reminder(_ values: [RoutineField: RoutineFieldValue]) -> String {
        if case .number(let minutes?) = values[.remindMinutes] {
            return UnifiedSearchOperationCopy.value(.time(minutes), locale: locale, calendar: calendar)
        }
        return L10n.format("unified.field.noReminder", locale: locale)
    }
    private func priority(_ values: [RoutineField: RoutineFieldValue]) -> String {
        let important = values[.isImportant] == .flag(true), urgent = values[.isUrgent] == .flag(true)
        return UnifiedSearchOperationCopy.value(.choice(important ? (urgent ? "p1" : "p2") : (urgent ? "p3" : "p4")),
                                                locale: locale, calendar: calendar)
    }
    private func names(_ targets: [CommandTaskTagTarget]) -> String {
        targets.isEmpty ? L10n.format("unified.field.noTags", locale: locale)
            : targets.map(UnifiedSearchTaskCompositionCopy.name).joined(separator: " · ")
    }
}
