import Foundation

/// 普通入口总是发现全目录；限制只能来自带解释的特殊选择器。
struct CommandDiscoveryConfiguration: Equatable, Sendable {
    let allowedIDs: Set<CommandID>?
    let explanationKey: String?

    static let standard = Self(allowedIDs: nil, explanationKey: nil)

    static func selector(allowing ids: Set<CommandID>, explanationKey: String) -> Self? {
        guard !explanationKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return Self(allowedIDs: ids, explanationKey: explanationKey)
    }

    private init(allowedIDs: Set<CommandID>?, explanationKey: String?) {
        self.allowedIDs = allowedIDs
        self.explanationKey = explanationKey
    }
}

/// 唯一聚合入口。只读路径/别名匹配不解析斜杠全文、参数尾段、光标或页面默认范围。
struct CommandCatalog: Sendable {
    let entries: [CommandDescriptor]

    static let standard: CommandCatalog = {
        let definitions = CommandCatalogBuilder.structure + CommandCatalogBuilder.tasks
            + CommandCatalogBuilder.content + CommandCatalogBuilder.clipboard
            + CommandCatalogBuilder.clipboardOptions + CommandCatalogBuilder.settings
            + CommandCatalogBuilder.safety + CommandCatalogBuilder.planning
            + CommandCatalogBuilder.navigation + CommandCatalogBuilder.support
        let entries = definitions.map { definition in
            var entry = definition
            if entry.path != "/" {
                let parentPath = parentPath(of: entry.path)
                entry.parentID = definitions.first { $0.path == parentPath }?.id
            }
            if entry.id.rawValue == "group.setting" { entry.pathAliases = ["/settings"] }
            if entry.id.rawValue == "todo.toRoutine" || entry.id.rawValue == "routine.toTodo" {
                entry.preview.append(.fieldLoss)
            }
            if entry.hazards.contains(.externalEffect) { entry.preview.append(.externalResult) }
            return entry
        }
        return CommandCatalog(entries: entries)
    }()

    func command(id: CommandID) -> CommandDescriptor? { entries.first { $0.id == id } }
    func command(path: String) -> CommandDescriptor? {
        entries.first { $0.path == path || $0.pathAliases.contains(path) }
    }
    func children(of id: CommandID) -> [CommandDescriptor] { entries.filter { $0.parentID == id } }
    func commands(for feature: CommandFeature) -> [CommandDescriptor] {
        entries.filter { $0.coverage.contains { $0.feature == feature } }
    }

    func discover(
        contentScopes: Set<CommandContentScope> = [],
        configuration: CommandDiscoveryConfiguration = .standard
    ) -> [CommandDescriptor] {
        // 内容范围只约束后续数据提供者，不能拿来过滤应用功能目录。
        guard var allowed = configuration.allowedIDs else { return entries }
        for id in allowed {
            var parent = command(id: id)?.parentID
            var visited: Set<CommandID> = []
            while let next = parent, visited.insert(next).inserted {
                allowed.insert(next)
                parent = command(id: next)?.parentID
            }
        }
        return entries.filter { allowed.contains($0.id) }
    }

    func matches(_ text: String, locale: Locale) -> [CommandDescriptor] {
        entries.filter { entry in
            ([entry.path] + entry.pathAliases + [entry.name(locale: locale)] + entry.aliases(locale: locale))
                .contains { $0.compare(text, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        }
    }

    static func parentPath(of path: String) -> String {
        let parts = path.split(separator: "/").dropLast()
        return parts.isEmpty ? "/" : "/" + parts.joined(separator: "/")
    }
}
