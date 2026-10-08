import SwiftUI

struct UnifiedSearchBatchImpact: View {
    let preview: CommandBatchPreview
    let remove: (CommandObjectReference) -> Void
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text(verbatim: L10n.format("unified.batch.commonSave", locale: locale, preview.impacts.count))
                .font(DaybookType.body.weight(.semibold)).accessibilityIdentifier("unified.batch.count")
            Text(verbatim: L10n.format("unified.batch.distribution", locale: locale,
                preview.impacts.filter { $0.target.type == .todo }.count,
                preview.impacts.filter { $0.target.type == .routine }.count,
                preview.changedCount, preview.impacts.count - preview.changedCount)).font(DaybookType.caption)
            if preview.baseline.original(preview.edit.parameter, targets: preview.targets) == .mixed {
                Text("unified.batch.mixed").font(DaybookType.caption).accessibilityIdentifier("unified.batch.mixed")
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DaybookSpacing.sm) {
                    ForEach(preview.impacts, id: \.target) { impact in
                        target(impact)
                        DaybookDivider()
                    }
                }
            }.frame(height: 180).modifier(DaybookScrollTargetModifier())
                .accessibilityIdentifier("unified.batch.details")
            Text("unified.batch.atomic").font(DaybookType.caption)
        }.accessibilityElement(children: .contain).accessibilityIdentifier("unified.batch.values")
    }

    private func target(_ impact: CommandBatchTargetImpact) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            Text(verbatim: impact.title).font(DaybookType.body).fixedSize(horizontal: false, vertical: true)
            Text(LocalizedStringKey(UnifiedSearchResultCopy.typeKey(impact.target.type))).font(DaybookType.caption)
            if let tags = impact.tags {
                Text(verbatim: names(tags.original) + " → " + names(tags.final)).font(DaybookType.caption)
                UnifiedSearchTaskTagEffects(associations: tags.actions.final)
                if !tags.actions.removed.isEmpty {
                    Text(verbatim: L10n.format("unified.batch.removed", locale: locale, names(tags.actions.removed)))
                        .font(DaybookType.caption)
                }
            } else {
                Text(verbatim: value(impact.original) + " → " + value(impact.final)).font(DaybookType.caption)
            }
            if impact.noChange { Text("unified.batch.memberNoChange").font(DaybookType.caption) }
            Button("unified.batch.removeTarget") { remove(impact.target) }
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                .accessibilityIdentifier("unified.batch.remove." + impact.target.searchIdentifier)
        }.accessibilityElement(children: .contain)
            .accessibilityIdentifier("unified.batch.target." + impact.target.searchIdentifier)
    }

    private func names(_ tags: [CommandTaskTagTarget]) -> String {
        tags.isEmpty ? L10n.format("unified.field.noTags", locale: locale)
            : tags.map(UnifiedSearchTaskCompositionCopy.name).joined(separator: " · ")
    }
    private func value(_ value: CommandValue) -> String {
        UnifiedSearchOperationCopy.value(value, locale: locale, calendar: calendar)
    }
}
