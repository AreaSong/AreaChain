import Foundation

/// 目录匹配保留所有同名项；规范路径的精确命中高于别名和参数解释。
struct CommandPathResolver {
    let catalog: CommandCatalog

    func resolve(_ path: String) -> [CommandDescriptor] {
        let canonical = catalog.entries.filter { $0.path == path }
        if !canonical.isEmpty { return canonical }
        let aliases = catalog.entries.filter { $0.pathAliases.contains { same($0, path) } }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false).dropFirst().map(String.init)
        guard !parts.isEmpty, parts.allSatisfy({ !$0.isEmpty }) else { return aliases }
        var matches = catalog.entries.filter { entry in
            entry.path != "/" && (
                (entry.parentID == rootID && segmentMatches(parts[0], entry: entry))
                    || CommandPathText.names(of: entry).contains { same($0, parts[0]) }
            )
        }
        for part in parts.dropFirst() {
            let parents = Set(matches.map(\.id))
            matches = catalog.entries.filter { entry in
                entry.parentID.map(parents.contains) == true && segmentMatches(part, entry: entry)
            }
        }
        return unique(aliases + matches)
    }

    var rootID: CommandID? { catalog.entries.first { $0.path == "/" }?.id }

    func segmentMatches(_ text: String, entry: CommandDescriptor) -> Bool {
        let segments = ([entry.path] + entry.pathAliases).compactMap { $0.split(separator: "/").last.map(String.init) }
        return (segments + CommandPathText.names(of: entry)).contains { same($0, text) }
    }

    func same(_ lhs: String, _ rhs: String) -> Bool {
        CommandPathText.folded(lhs) == CommandPathText.folded(rhs)
    }

    private func unique(_ entries: [CommandDescriptor]) -> [CommandDescriptor] {
        var seen: Set<CommandID> = []
        return entries.filter { seen.insert($0.id).inserted }
    }
}
