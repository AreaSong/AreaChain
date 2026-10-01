import Foundation

/// 排序只用匹配类别、规范路径和稳定身份；不依赖使用历史或系统时间。
struct CommandPathCompletion {
    let catalog: CommandCatalog

    func candidates(_ request: CommandPathRequest, cursor: Int) -> [CommandPathCandidate] {
        guard cursor > 0, CommandPathText.valid(NSRange(location: cursor, length: 0), in: request.text) else { return [] }
        let source = request.text as NSString
        let prefix = source.substring(to: cursor)
        guard !prefix.contains(where: { $0.isNewline || "\\\"`?#".contains($0) }),
              !prefix.contains("://") else { return [] }
        let slash = (prefix as NSString).range(of: "/", options: .backwards).location
        guard slash != NSNotFound else { return [] }
        let start = slash + 1
        let remainder = source.substring(from: cursor)
        let wholeSuffix = remainder.prefix { $0 != "/" }
        let wholePath = source.substring(to: cursor) + wholeSuffix
        let knownAlias = !CommandPathResolver(catalog: catalog).resolve(wholePath).isEmpty
        let suffixLength = knownAlias ? wholeSuffix.utf16.count
            : remainder.prefix { $0 != "/" && !$0.isWhitespace }.utf16.count
        let range = NSRange(location: start, length: cursor - start + suffixLength)
        guard CommandPathText.valid(range, in: request.text),
              !TagSyntax.protectedRanges(in: request.text).contains(where: { NSIntersectionRange($0, range).length > 0 }) else { return [] }
        let query = source.substring(with: NSRange(location: start, length: cursor - start))
        let parentPath = slash == 0 ? "/" : source.substring(to: slash)
        let parents = CommandPathResolver(catalog: catalog).resolve(parentPath)
        let visible = catalog.discover(contentScopes: request.contentScopes, configuration: request.configuration)
        var result = pathCandidates(query: query, parents: parents, visible: visible, range: range, locale: request.locale)
        for parent in parents where explicitlyAllowed(parent, request: request) {
            result += argumentCandidates(parent, query: query, range: range, request: request)
        }
        // 完整参数指令无需先手工键入尾斜杠；追加候选仍然只修改文本。
        if cursor == NSMaxRange(range), !remainder.hasPrefix("/") {
            let exact = CommandPathResolver(catalog: catalog).resolve(prefix)
            if exact.count == 1, let command = exact.first, explicitlyAllowed(command, request: request) {
                result += argumentCandidates(
                    command, query: "", range: NSRange(location: cursor, length: 0), request: request, leadingSlash: true
                )
            }
        }
        return sortedUnique(result)
    }

    private func pathCandidates(
        query: String, parents: [CommandDescriptor], visible: [CommandDescriptor], range: NSRange, locale: Locale
    ) -> [CommandPathCandidate] {
        var result: [CommandPathCandidate] = []
        for parent in parents {
            let base = parent.path == "/" ? "/" : parent.path + "/"
            for entry in visible where entry.path != "/" {
                let relative = entry.path.hasPrefix(base) ? String(entry.path.dropFirst(base.count)) : nil
                let aliases = entry.pathAliases.filter { $0.hasPrefix(base) }.map { String($0.dropFirst(base.count)) }
                let names = parent.path == "/" || entry.parentID == parent.id ? CommandPathText.names(of: entry) : []
                guard let match = rank(query, canonical: relative, aliases: aliases + names) else { continue }
                // 顶层关键词可定位任意目录项；嵌套关键词仅在已确定的父级下匹配。
                let insertion = relative ?? entry.path
                let replacement = relative == nil ? NSRange(location: 0, length: NSMaxRange(range)) : range
                result.append(CommandPathCandidate(
                    id: "command:\(entry.id.rawValue)", command: entry, title: entry.name(locale: locale),
                    summary: entry.summary(locale: locale), replacementRange: replacement, insertText: insertion,
                    intent: intent(for: entry), match: match
                ))
            }
        }
        return result
    }

    private func argumentCandidates(
        _ command: CommandDescriptor, query: String, range: NSRange, request: CommandPathRequest, leadingSlash: Bool = false
    ) -> [CommandPathCandidate] {
        guard let parameter = CommandPathArguments.parameter(for: command) else { return [] }
        return CommandPathArguments.options(for: parameter, locale: request.locale).compactMap { value, title, aliases, typed in
            let insertion = (leadingSlash ? "/" : "") + value
            let path = (request.text as NSString).substring(to: range.location) + insertion
            guard !shadowsDirectory(path, request: request),
                  let match = rank(query, canonical: value, aliases: aliases),
                  CommandArgumentValidation.accepts(typed, type: parameter.type) else { return nil }
            let argument = CommandPathArguments.argument(typed, parameter: parameter)
            return CommandPathCandidate(
                id: "argument:\(command.id.rawValue):\(parameter.id.rawValue):\(value)", command: command,
                title: title, summary: L10n.format(parameter.id.nameKey, locale: request.locale), replacementRange: range,
                insertText: insertion, intent: .setArgument(command.id, argument),
                match: [.exactPath, .exactNameOrAlias].contains(match) ? .exactArgument : .argumentPrefix
            )
        }
    }

    private func shadowsDirectory(_ path: String, request: CommandPathRequest) -> Bool {
        // 参数候选也遵守精确目录优先，不能靠接受意图绕过解析限制。
        if catalog.entries.contains(where: { $0.path == path }) { return true }
        guard let allowed = request.configuration.allowedIDs else { return false }
        return CommandPathResolver(catalog: catalog).resolve(path).contains { !allowed.contains($0.id) }
    }

    private func intent(for command: CommandDescriptor) -> CommandPathIntent {
        if command.category == .group { return .expand(command.id) }
        if !command.parameters.isEmpty { return .chooseParameter(command.id, command.parameters.map(\.id)) }
        return .complete(command.id)
    }

    private func explicitlyAllowed(_ command: CommandDescriptor, request: CommandPathRequest) -> Bool {
        request.configuration.allowedIDs?.contains(command.id) ?? true
    }

    private func rank(_ query: String, canonical: String?, aliases: [String]) -> CommandPathMatch? {
        let query = CommandPathText.folded(query)
        if let canonical {
            if canonical == query { return .exactPath }
            if CommandPathText.folded(canonical).hasPrefix(query) { return .pathPrefix }
        }
        let names = aliases.map(CommandPathText.folded)
        if names.contains(query) { return .exactNameOrAlias }
        if !query.isEmpty, names.contains(where: { $0.hasPrefix(query) }) { return .nameOrAliasPrefix }
        return nil
    }

    private func sortedUnique(_ candidates: [CommandPathCandidate]) -> [CommandPathCandidate] {
        let sorted = candidates.sorted { lhs, rhs in
            if lhs.match != rhs.match { return lhs.match.rawValue < rhs.match.rawValue }
            if lhs.command.path != rhs.command.path { return lhs.command.path < rhs.command.path }
            return lhs.id < rhs.id
        }
        var seen: Set<String> = []
        return sorted.filter { seen.insert($0.id).inserted }
    }
}
