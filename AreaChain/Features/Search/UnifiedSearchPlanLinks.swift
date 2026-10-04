import Foundation

extension UnifiedSearchController {
    /// 候选只包含同一计划内、排在前面且通过领域参数互斥/类型检查的声明输出。
    func creationSources(for parameter: CommandParameterID, item: CommandPlanItem) -> [CommandPlanItem] {
        guard let plan, let index = plan.items.firstIndex(where: { $0.stamp == item.stamp }) else { return [] }
        return plan.items.prefix(index).filter { producer in
            guard let type = CommandCatalog.standard.command(id: producer.draft.commandID)?.createdObjectType else { return false }
            return CommandPlanValidation.acceptsReference(.init(producer: producer.stamp, outputType: type),
                                                          parameter: parameter, item: item)
        }
    }

    func setCreationReference(_ producer: CommandPlanItemStamp?, parameter: CommandParameterID,
                              item: CommandPlanItemStamp, source: UnifiedSearchBuffer) {
        guard validates(source), let current = plan?.items.first(where: { $0.stamp == item }) else {
            _ = rejectPlan(); return
        }
        var links = current.links
        if let producer {
            guard let candidate = creationSources(for: parameter, item: current).first(where: { $0.stamp == producer }),
                  let type = CommandCatalog.standard.command(id: candidate.draft.commandID)?.createdObjectType else {
                _ = rejectPlan(CommandPlanError.invalidInput); return
            }
            links.results[parameter] = .init(producer: producer, outputType: type)
        } else { links.results[parameter] = nil }
        _ = sendPlan(.link(item, links), source: source)
    }

    func removePredecessor(_ predecessor: UUID, item: CommandPlanItemStamp, source: UnifiedSearchBuffer) {
        guard validates(source), let current = plan?.items.first(where: { $0.stamp == item }) else {
            _ = rejectPlan(); return
        }
        var links = current.links
        links.predecessors.remove(predecessor)
        _ = sendPlan(.link(item, links), source: source)
    }
}
