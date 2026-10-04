import SwiftUI

struct UnifiedSearchPlanDependencies: View {
    @Bindable var controller: UnifiedSearchController
    let item: CommandPlanItem
    let source: UnifiedSearchBuffer
    var editable = true
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            ForEach(item.links.predecessors.sorted { $0.uuidString < $1.uuidString }, id: \.self) { id in
                Text(verbatim: L10n.format("unified.plan.predecessor", locale: locale) + " · " + name(id))
                if editable {
                    Button("unified.plan.unlink") { controller.removePredecessor(id, item: item.stamp, source: source) }
                }
            }
            ForEach(item.links.results.keys.sorted { $0.rawValue < $1.rawValue }, id: \.self) { parameter in
                if let reference = item.links.results[parameter] {
                    Text(verbatim: L10n.format(parameter.nameKey, locale: locale) + " ← " + name(reference.producer.id)
                        + " · " + L10n.format("unified.plan.output." + reference.outputType.rawValue, locale: locale))
                }
            }
            if editable, let command = CommandCatalog.standard.command(id: item.draft.commandID) {
                ForEach(command.parameters, id: \.id) { parameter in
                    let candidates = controller.creationSources(for: parameter.id, item: item)
                    if !candidates.isEmpty || item.links.results[parameter.id] != nil {
                        referencePicker(parameter, candidates: candidates)
                    }
                }
            }
        }
        .font(DaybookType.caption)
        .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
    }

    private func name(_ id: UUID) -> String {
        guard let plan = controller.plan, let index = plan.items.firstIndex(where: { $0.id == id }),
              let command = CommandCatalog.standard.command(id: plan.items[index].draft.commandID) else {
            return L10n.format("unified.plan.reference.missing", locale: locale)
        }
        return "\(index + 1). " + command.name(locale: locale)
    }

    private func referencePicker(_ parameter: CommandParameter, candidates: [CommandPlanItem]) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            Text(verbatim: L10n.format(parameter.id.nameKey, locale: locale) + " · "
                + L10n.format("unified.plan.reference.choose", locale: locale))
            ForEach(candidates, id: \.id) { producer in
                Button {
                    controller.setCreationReference(producer.stamp, parameter: parameter.id, item: item.stamp, source: source)
                } label: { Text(verbatim: name(producer.id)) }
                .accessibilityIdentifier("unified.plan.reference." + parameter.id.rawValue + "." + producer.id.uuidString)
            }
            if item.links.results[parameter.id] != nil {
                Button("unified.plan.reference.remove") {
                    controller.setCreationReference(nil, parameter: parameter.id, item: item.stamp, source: source)
                }.accessibilityIdentifier("unified.plan.reference.remove." + parameter.id.rawValue)
            }
        }
    }
}
