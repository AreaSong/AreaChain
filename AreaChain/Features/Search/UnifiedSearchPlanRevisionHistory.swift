import SwiftUI

/// 原运行事实只读展示；唯一可编辑正文仍在原 PlanList。
struct UnifiedSearchPlanRevisionHistory: View {
    @Bindable var controller: UnifiedSearchController
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    var body: some View {
        let records = controller.coordinator.revisionChain(controller.buffer.lease.ownership.hostID)
        if !records.isEmpty {
            VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
                Text("unified.revision.history").font(DaybookType.body.weight(.semibold))
                ForEach(Array(records.reversed()), id: \.id) { record in
                    ForEach(record.run.snapshot.items, id: \.id) { item in
                        if let command = CommandCatalog.standard.command(id: item.draft.commandID),
                           let unit = record.run.units.first(where: { $0.members.contains(item.id) }) {
                            Text(verbatim: command.name(locale: locale) + " · " + L10n.format(UnifiedSearchMultiPlanCopy.status(unit), locale: locale))
                                .font(DaybookType.caption.weight(.medium))
                            Text(verbatim: UnifiedSearchOperationCopy.summary(command, draft: item.draft, locale: locale, calendar: calendar))
                                .font(DaybookType.caption)
                        }
                    }
                    DaybookDivider()
                }
                Text("unified.revision.remaining").font(DaybookType.body.weight(.semibold))
                Text("unified.revision.reaccept").font(DaybookType.caption)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("unified.revision.history")
        }
    }
}
