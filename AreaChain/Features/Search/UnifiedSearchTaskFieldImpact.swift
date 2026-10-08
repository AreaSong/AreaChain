import SwiftUI

/// 只显示 Reader 的真实影响；子项范围与标签运算均由领域/服务给出。
struct UnifiedSearchTaskFieldImpact: View {
    let preview: CommandTaskFieldPreview
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            if let tags = preview.tags {
                Text(verbatim: names(tags.original) + " → " + names(tags.final))
                    .font(DaybookType.body).accessibilityIdentifier("unified.field.values")
                UnifiedSearchTaskTagSummary(associations: tags.actions.final)
                UnifiedSearchTaskTagEffects(associations: tags.actions.final)
                if tags.actions.final.isEmpty && tags.original == tags.final {
                    Text("unified.field.tagsAlready").font(DaybookType.caption)
                }
            } else {
                Text(verbatim: value(preview.original) + " → " + value(preview.edit))
                    .font(DaybookType.body).accessibilityIdentifier("unified.field.values")
            }
            if let completion = preview.completion {
                Text(verbatim: L10n.format("unified.field.children", locale: locale, completion.affected.count))
                    .font(DaybookType.caption).accessibilityIdentifier("unified.field.children")
                ForEach(completion.affected, id: \.id) { child in
                    Text(verbatim: child.title).font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
                }
                Text("unified.field.completionHint").font(DaybookType.caption)
            }
            Text("unified.field.preserve").font(DaybookType.caption)
        }.fixedSize(horizontal: false, vertical: true)
    }

    private func names(_ targets: [CommandTaskTagTarget]) -> String {
        targets.isEmpty ? L10n.format("unified.field.noTags", locale: locale)
            : targets.map(UnifiedSearchTaskCompositionCopy.name).joined(separator: " · ")
    }

    private func value(_ edit: TaskFieldEdit) -> String {
        if case .completion(let done) = edit { return L10n.format(done ? "unified.field.completed" : "unified.field.open", locale: locale) }
        if case .due(nil) = edit { return L10n.format("unified.field.noDue", locale: locale) }
        guard let value = edit.value else { return L10n.format("unified.field.noReminder", locale: locale) }
        return UnifiedSearchOperationCopy.value(value, locale: locale, calendar: calendar)
    }
}
