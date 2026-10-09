import SwiftUI

/// 单项与多项共用同一新增影响展示，展开状态不承担执行资格。
struct UnifiedSearchTaskCreationImpact: View {
    let preview: CommandTaskCreatePreview
    @Environment(\.locale) private var locale
    @State private var expanded = true
    private typealias Copy = UnifiedSearchTaskCompositionCopy
    var body: some View { effects(preview) }

    private func effects(_ preview: CommandTaskCreatePreview) -> some View {
        let fields = preview.composition
        return VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.composition.final").font(DaybookType.body.weight(.semibold))
            Text(verbatim: fields.title.isEmpty ? L10n.format("unified.composition.metadata", locale: locale) : fields.title)
                .font(DaybookType.body).accessibilityIdentifier("unified.composition.title")
            Text(verbatim: fields.day).font(DaybookType.caption).accessibilityIdentifier("unified.task.day")
            UnifiedSearchTaskTagSummary(associations: fields.tags.final)
                .accessibilityIdentifier("unified.composition.tagSummary")
            Button(expanded ? "unified.composition.collapse" : "unified.composition.expand") { expanded.toggle() }
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                .accessibilityIdentifier("unified.composition.disclosure")
            if expanded { details(preview) }
            ForEach(Array(preview.issues.enumerated()), id: \.offset) { _, issue in
                Text(LocalizedStringKey(Copy.error(issue))).font(DaybookType.caption)
            }
            ForEach(Array(fields.tags.problems.enumerated()), id: \.offset) { _, problem in
                Text(LocalizedStringKey(Copy.problem(problem.kind))).font(DaybookType.caption)
            }
        }
    }

    private func details(_ preview: CommandTaskCreatePreview) -> some View {
        let fields = preview.composition
        return VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.composition.raw").font(DaybookType.caption)
            if case .shortText(let raw) = preview.arguments.first(where: { $0.parameter == .title })?.value {
                Text(verbatim: raw).font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
            }
            Text(verbatim: L10n.format("command.parameter.priority", locale: locale) + ": "
                + (fields.priority.hasConflict ? L10n.format("unified.composition.conflict", locale: locale)
                   : fields.priorityFlags.map(Copy.priority) ?? ""))
            Text(verbatim: Copy.field(fields.priority, locale: locale, format: Copy.priority))
            Text(verbatim: L10n.format("command.parameter.time", locale: locale) + ": "
                + (fields.reminder.hasConflict ? L10n.format("unified.composition.conflict", locale: locale)
                   : fields.reminder.value.map(Copy.time) ?? L10n.format("unified.operation.mode.cancelReminder", locale: locale)))
            Text(verbatim: Copy.field(fields.reminder, locale: locale, format: Copy.time))
            tags(fields.tags)
            Text(preview.source.stampEnabled ? "unified.task.sourceEnabled" : "unified.task.sourceDisabled")
            if preview.source.stampEnabled { Text(verbatim: preview.source.bundleID) }
            Text("unified.composition.notSaved")
        }.font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
    }

    private func tags(_ tags: CommandTaskTagPlan) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            UnifiedSearchTaskTagEffects(associations: tags.final)
            ForEach(Array(tags.removed.enumerated()), id: \.offset) { _, target in
                Text(verbatim: L10n.format("unified.composition.removed", locale: locale) + " · " + Copy.name(target))
            }
            ForEach(Array(tags.noEffects.enumerated()), id: \.offset) { _, effect in
                switch effect {
                case .empty: Text("unified.composition.noEffect")
                case .alreadyAssociated(let target), .notAssociated(let target):
                    Text(verbatim: L10n.format("unified.composition.noEffect", locale: locale) + " · " + Copy.name(target))
                }
            }
        }
    }
}
