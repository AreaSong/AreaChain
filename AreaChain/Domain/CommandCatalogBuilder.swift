import Foundation

/// 仅缩短静态声明，不注册 handler，也不读取偏好或对象。
enum CommandCatalogBuilder {
    static func entry(
        _ id: String, _ path: String, _ category: CommandCategory,
        _ coverage: String, _ parameters: [CommandParameter] = []
    ) -> CommandDescriptor {
        let slots = coverage.split(separator: " ").map { token -> CommandCoverage in
            let parts = token.split(separator: ":")
            guard parts.count == 2, let feature = CommandFeature(rawValue: String(parts[0])) else {
                preconditionFailure("Invalid static command coverage: \(token)")
            }
            return CommandCoverage(feature: feature, action: String(parts[1]))
        }
        return CommandDescriptor(
            id: CommandID(rawValue: id), path: path, category: category,
            coverage: slots, parameters: parameters,
            preview: parameters.map { .parameter($0.id) } + [.effect]
        )
    }

    static func p(_ id: CommandParameterID, _ type: CommandParameterType) -> CommandParameter {
        CommandParameter(id: id, type: type)
    }

    static func choice(_ id: CommandParameterID, _ values: String) -> CommandParameter {
        p(id, .choice(values.split(separator: " ").map { CommandChoice(value: String($0)) }))
    }

    static var title: CommandParameter { p(.title, .shortText) }
    static var day: CommandParameter { p(.day, .day) }
    static var notes: CommandParameter {
        var result = p(.notes, .longText).editing([.replace, .append, .clear], default: .replace)
        result.allowsEmpty = true
        return result
    }
    static var body: CommandParameter {
        p(.body, .longText).editing([.replace, .append, .clear], default: .replace)
    }
    static var tags: CommandParameter {
        p(.tags, .tags).editing([.add, .remove, .replaceAll, .clear], default: .add)
    }
    static var reminder: CommandParameter {
        p(.time, .time).editing([.setReminder, .cancelReminder], default: .setReminder)
    }
    static var priority: CommandParameter {
        choice(.priority, "p1 p2 p3 p4").editing([.assign, .clear], default: .assign)
    }
}

extension CommandDescriptor {
    func targets(_ types: Set<CommandObjectType>, batch: CommandBatchCapability = .singleOnly) -> Self {
        var copy = self
        copy.targetTypes = types
        copy.batch = batch
        let type: CommandParameterType = batch == .explicitMultiple ? .objects(types) : .object(types)
        copy.parameters.insert(CommandParameter(id: .target, type: type), at: 0)
        copy.preview += [.parameter(.target), .targetIdentity, .currentValues]
        if types.contains(.routineOccurrence) { copy.preview.append(.concreteDate) }
        return copy
    }

    func ordinary() -> Self {
        var copy = self
        copy.queue = .eligibleAfterWiring
        return copy
    }

    func requiring(_ requirements: Set<CommandInteractionRequirement>) -> Self {
        var copy = self
        copy.interactions.formUnion(requirements)
        return copy
    }

    func risk(_ hazards: Set<CommandHazard>) -> Self {
        var copy = self
        copy.hazards.formUnion(hazards)
        copy.queue = .excluded
        if !hazards.subtracting([.externalEffect]).isEmpty {
            copy.interactions.insert(.independentConfirmation)
        }
        return copy
    }

    func unresolved(_ reason: String) -> Self {
        var copy = self
        copy.availability = .unresolved(reasonKey: "command.reason.\(reason)")
        copy.queue = .excluded
        return copy
    }

    func unavailable(_ reason: String) -> Self {
        var copy = self
        copy.availability = .unavailable(reasonKey: "command.reason.\(reason)")
        copy.queue = .excluded
        return copy
    }

    func scope(_ scope: CommandContentScope) -> Self {
        var copy = self
        copy.contentScope = scope
        return copy
    }
}
