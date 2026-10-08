import SwiftUI

/// 影响原值和最终值唯一来自 prepare；日期等后续上下文不列为本次修改。
struct UnifiedSearchTaskTitlePreview: View {
    let preview: CommandTaskTitlePreview
    @Environment(\.locale) private var locale
    @State private var expanded = true
    private var impact: CommandTaskTitleImpact { preview.impact }

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.title.changes").font(DaybookType.body.weight(.semibold))
            field(.title, name: "command.parameter.title")
            UnifiedSearchTaskTagSummary(associations: impact.tags.associations)
                .accessibilityIdentifier("unified.title.tagSummary")
            Button(expanded ? "unified.composition.collapse" : "unified.composition.expand") { expanded.toggle() }
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                .accessibilityIdentifier("unified.title.disclosure")
            if expanded {
                tags("unified.title.originalTags", values: impact.tags.original)
                tags("unified.title.finalTags", values: impact.tags.final)
                if !impact.changedFields.contains(.tagIDs) { Text("unified.title.tagsKept").font(DaybookType.caption) }
                UnifiedSearchTaskTagEffects(associations: impact.tags.associations)
                if impact.writeFields.contains(.isImportant) {
                    field(.isImportant, name: "unified.title.important")
                    field(.isUrgent, name: "unified.title.urgent")
                }
                if impact.writeFields.contains(.remindMinutes) { field(.remindMinutes, name: "command.parameter.time") }
                Text("unified.title.otherKept").font(DaybookType.caption)
                Text("unified.composition.notSaved").font(DaybookType.caption)
            }
        }.fixedSize(horizontal: false, vertical: true)
    }

    private func field(_ field: TaskTitleField, name: String) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            Text(verbatim: L10n.format(name, locale: locale) + " · "
                + L10n.format(impact.changedFields.contains(field) ? "unified.title.changed" : "unified.title.kept", locale: locale))
                .font(DaybookType.caption)
            Text(verbatim: UnifiedSearchTaskTitleCopy.value(impact.originalValues[field], locale: locale)
                + " → " + UnifiedSearchTaskTitleCopy.value(impact.finalValues[field], locale: locale))
                .font(DaybookType.body).fixedSize(horizontal: false, vertical: true)
        }.accessibilityIdentifier("unified.title.field." + String(describing: field))
    }

    private func tags(_ key: String, values: [CommandTaskTagTarget]) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            Text(LocalizedStringKey(key)).font(DaybookType.caption)
            if values.isEmpty { Text("unified.title.noTags").font(DaybookType.caption) }
            ForEach(Array(values.enumerated()), id: \.offset) { index, target in
                Text(verbatim: "\(index + 1). " + UnifiedSearchTaskCompositionCopy.name(target)).font(DaybookType.caption)
            }
        }.accessibilityIdentifier(key)
    }
}
