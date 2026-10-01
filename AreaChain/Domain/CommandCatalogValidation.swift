import Foundation

enum CommandCatalogIssue: Equatable {
    case invalidID(CommandID)
    case duplicateID(CommandID), duplicatePath(String), invalidPath(String), invalidParent(CommandID)
    case invalidCategory(CommandID), unsafeQueue(CommandID), invalidParameter(CommandID, CommandParameterID)
    case invalidPreview(CommandID, CommandParameterID), missingCoverage(CommandCoverage)
    case duplicateCoverage(CommandCoverage), unknownCoverage(CommandCoverage), invalidFeatureManifest
}

enum CommandCatalogValidation {
    static func issues(in catalog: CommandCatalog) -> [CommandCatalogIssue] {
        var result: [CommandCatalogIssue] = []
        var ids: Set<CommandID> = []
        var paths: Set<String> = []
        for entry in catalog.entries {
            if entry.id.rawValue.range(of: #"^[a-z][A-Za-z0-9]*(\.[a-z][A-Za-z0-9]*)*$"#, options: .regularExpression) == nil {
                result.append(.invalidID(entry.id))
            }
            if !ids.insert(entry.id).inserted { result.append(.duplicateID(entry.id)) }
            for path in [entry.path] + entry.pathAliases {
                if !paths.insert(path).inserted { result.append(.duplicatePath(path)) }
                if !canonical(path) { result.append(.invalidPath(path)) }
            }
            result += structureIssues(entry, catalog: catalog)
            result += parameterIssues(entry)
        }
        result += coverageIssues(catalog.entries)
        return result
    }

    private static func canonical(_ path: String) -> Bool {
        if path == "/" { return true }
        return path.range(of: #"^/[a-z][a-z0-9-]*(/[a-z][a-z0-9-]*)*$"#, options: .regularExpression) != nil
    }

    private static func structureIssues(_ entry: CommandDescriptor, catalog: CommandCatalog) -> [CommandCatalogIssue] {
        var issues: [CommandCatalogIssue] = []
        if entry.path == "/" {
            if entry.parentID != nil || entry.category != .group { issues.append(.invalidParent(entry.id)) }
        } else if let parentID = entry.parentID, let parent = catalog.command(id: parentID) {
            if ![.group, .scope].contains(parent.category) || parent.path != CommandCatalog.parentPath(of: entry.path) {
                issues.append(.invalidParent(entry.id))
            }
        } else { issues.append(.invalidParent(entry.id)) }
        if [.group, .scope].contains(entry.category) && (!entry.parameters.isEmpty || !entry.coverage.isEmpty) {
            issues.append(.invalidCategory(entry.id))
        }
        if entry.category == .scope && entry.contentScope == nil { issues.append(.invalidCategory(entry.id)) }
        if entry.category == .group && entry.contentScope != nil { issues.append(.invalidCategory(entry.id)) }
        if entry.queue == .eligibleAfterWiring {
            if entry.category != .modification || !entry.hazards.isEmpty || entry.availability != .declared {
                issues.append(.unsafeQueue(entry.id))
            }
        }
        return issues
    }

    private static func parameterIssues(_ entry: CommandDescriptor) -> [CommandCatalogIssue] {
        var result: [CommandCatalogIssue] = []
        var seen: Set<CommandParameterID> = []
        for parameter in entry.parameters {
            if !seen.insert(parameter.id).inserted || !validDefinition(parameter) {
                result.append(.invalidParameter(entry.id, parameter.id))
            }
            if case .nativeFile = parameter.type, !entry.interactions.contains(.nativeFilePanel) {
                result.append(.invalidParameter(entry.id, parameter.id))
            }
            if case .nativeShortcut = parameter.type, !entry.interactions.contains(.nativeShortcutRecorder) {
                result.append(.invalidParameter(entry.id, parameter.id))
            }
        }
        for field in entry.preview {
            if case .parameter(let id) = field, !seen.contains(id) { result.append(.invalidPreview(entry.id, id)) }
        }
        if let target = entry.parameters.first(where: { $0.id == .target }) {
            let expected: CommandParameterType = entry.batch == .explicitMultiple
                ? .objects(entry.targetTypes) : .object(entry.targetTypes)
            if target.type != expected { result.append(.invalidParameter(entry.id, .target)) }
        } else if !entry.targetTypes.isEmpty { result.append(.invalidParameter(entry.id, .target)) }
        return result
    }

    static func validDefinition(_ parameter: CommandParameter) -> Bool {
        guard !parameter.operations.isEmpty, parameter.operations.contains(parameter.defaultOperation),
              parameter.operations.isSubset(of: allowedOperations(parameter.type)) else { return false }
        if let value = parameter.defaultValue {
            guard parameter.defaultOperation.requiresValue,
                  CommandArgumentValidation.accepts(value, type: parameter.type) else { return false }
        }
        switch parameter.type {
        case .choice(let choices):
            return !choices.isEmpty && Set(choices.map(\.value)).count == choices.count
                && choices.allSatisfy {
                    $0.value.range(of: #"^[A-Za-z][A-Za-z0-9-]*$"#, options: .regularExpression) != nil
                }
        case .number(let range, _): return range.lowerBound.isFinite && range.upperBound.isFinite
        case .object(let types), .objects(let types): return !types.isEmpty
        default: return true
        }
    }

    private static func allowedOperations(_ type: CommandParameterType) -> Set<CommandFieldOperation> {
        switch type {
        case .longText: [.assign, .replace, .append, .clear]
        case .tags: [.assign, .add, .remove, .replaceAll, .clear]
        case .time: [.assign, .clear, .setReminder, .cancelReminder]
        case .shortText, .choice, .day, .number: [.assign, .clear]
        default: [.assign]
        }
    }

    private static func coverageIssues(_ entries: [CommandDescriptor]) -> [CommandCatalogIssue] {
        let expected = Set(CommandCoverageRequirements.all)
        var seen: Set<CommandCoverage> = []
        var issues: [CommandCatalogIssue] = []
        if Set(CommandCoverageRequirements.actions.keys) != Set(CommandFeature.allCases)
            || expected.count != CommandCoverageRequirements.all.count { issues.append(.invalidFeatureManifest) }
        for slot in entries.flatMap(\.coverage) {
            if !expected.contains(slot) { issues.append(.unknownCoverage(slot)) }
            if !seen.insert(slot).inserted { issues.append(.duplicateCoverage(slot)) }
        }
        for slot in CommandCoverageRequirements.all where !seen.contains(slot) { issues.append(.missingCoverage(slot)) }
        return issues
    }
}
