import Foundation

extension UnifiedSearchController {
    /// 原 Plan 事件建立整组；适配器负责白名单与结构资格，UI 不另建分组规则。
    func establishFileSettingGroup(_ adapter: FileLocalSettingCommandAdapter, source: UnifiedSearchBuffer) throws {
        guard validates(source), let plan, source.plan == plan.stamp else { throw FileLocalSettingCommandIssue.stale }
        if let event = try adapter.groupingEvent(plan: plan.stamp, expecting: source.lease) {
            try coordinator.send(.plan(event, plan.stamp), expecting: source.lease)
            _ = publishOperation(text: buffer.text)
        }
    }

    /// 候选只包含同一计划内、排在前面且通过领域参数互斥/类型检查的声明输出。
    func creationSources(for parameter: CommandParameterID, item: CommandPlanItem) -> [CommandPlanItem] {
        guard let plan, let index = plan.items.firstIndex(where: { $0.stamp == item.stamp }) else { return [] }
        return plan.items.prefix(index).filter { producer in
            guard let type = CommandCatalog.standard.command(id: producer.draft.commandID)?.createdObjectType else { return false }
            if let multiPlan {
                guard multiPlan.permitsReference(producer, consumer: item, parameter: parameter) else { return false }
                if multiPlan.outputCapability == .taskTitle, plan.items.contains(where: {
                    $0.id != item.id && $0.links.results.values.contains { $0.producer.id == producer.id }
                }) { return false }
            } else if type != .todo { return false }
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

extension UnifiedSearchController {
    func creationReferenceLabel(_ reference: CommandCreationReference, parameter: CommandParameterID, locale: Locale) -> String {
        let items = settingExecution?.snapshot.items ?? plan?.items ?? []
        guard let index = items.firstIndex(where: { $0.stamp == reference.producer }) else {
            return L10n.format("unified.plan.reference.stale", locale: locale)
        }
        let key = parameter == .parent ? "unified.plan.reference.futureParent" : "unified.plan.reference.futureTarget"
        return L10n.format(key, locale: locale, index + 1,
                           L10n.format("unified.plan.reference.type." + reference.outputType.rawValue, locale: locale))
    }
}

extension UnifiedSearchController {
    func addPredecessor(_ predecessor: UUID, item: CommandPlanItemStamp, source: UnifiedSearchBuffer) {
        guard validates(source), settingExecution == nil,
              let current = plan?.items.first(where: { $0.stamp == item }) else { return }
        var links = current.links
        links.predecessors.insert(predecessor)
        _ = sendPlan(.link(item, links), source: source)
    }

    func adjacentSettingGroup(starting item: CommandPlanItemStamp) -> [UUID] {
        guard multiPlan?.fileSettings != nil, let plan,
              let index = plan.items.firstIndex(where: { $0.stamp == item }) else { return [] }
        var members: [UUID] = []
        var commands: Set<CommandID> = []
        for candidate in plan.items[index...] {
            guard candidate.atomicGroup == nil, CommandPlanSemantics.isAtomicSetting(candidate.draft.commandID),
                  commands.insert(candidate.draft.commandID).inserted, members.count < 4 else { break }
            members.append(candidate.id)
        }
        return members.count > 1 ? members : []
    }

    func groupAdjacentSettings(_ item: CommandPlanItemStamp, source: UnifiedSearchBuffer) {
        let members = adjacentSettingGroup(starting: item)
        guard validates(source), members.count > 1 else { return }
        _ = sendPlan(.atomicGroup(UUID(), members: members), source: source)
    }
}
