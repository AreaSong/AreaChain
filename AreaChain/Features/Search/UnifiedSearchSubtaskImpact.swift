import SwiftUI

/// 父名称仅说明所属关系；原值和标签效果直接消费本次已核实的子项影响。
struct UnifiedSearchSubtaskImpact: View {
    let preview: CommandSubtaskPreview
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text(verbatim: L10n.format("unified.subtask.parent", locale: locale, preview.parent.title))
                .font(DaybookType.caption).accessibilityIdentifier("unified.subtask.parent")
            if case .completion = preview.input.edit, let original = preview.original {
                Text(verbatim: L10n.format("unified.subtask.targetTitle", locale: locale, original.title))
                    .font(DaybookType.body).accessibilityIdentifier("unified.subtask.targetTitle")
            }
            Text(verbatim: values).font(DaybookType.body).accessibilityIdentifier("unified.subtask.values")
            if preview.input.edit.isCreation { Text("unified.subtask.append").font(DaybookType.caption) }
            if let tags = preview.tags {
                Text(verbatim: names(tags.original) + " → " + names(tags.final))
                    .font(DaybookType.caption).accessibilityIdentifier("unified.subtask.tags")
                let effects = tags.actions.final.filter { $0.effect != .associateLive || !tags.original.contains($0.target) }
                UnifiedSearchTaskTagSummary(associations: effects)
                UnifiedSearchTaskTagEffects(associations: effects)
            }
            Text("unified.subtask.preserve").font(DaybookType.caption)
        }.fixedSize(horizontal: false, vertical: true)
    }

    private var values: String {
        switch preview.input.edit {
        case .create(let edit): return edit.title
        case .title(let edit): return (preview.original?.title ?? "") + " → " + edit.title
        case .completion(let done):
            return L10n.format(preview.original?.isDone == true ? "checkbox.done" : "checkbox.open", locale: locale)
                + " → " + L10n.format(done ? "checkbox.done" : "checkbox.open", locale: locale)
        case .tags: return preview.original?.title ?? ""
        }
    }
    private func names(_ targets: [CommandTaskTagTarget]) -> String {
        targets.isEmpty ? L10n.format("unified.field.noTags", locale: locale)
            : targets.map(UnifiedSearchTaskCompositionCopy.name).joined(separator: " · ")
    }
}
