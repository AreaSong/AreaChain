import Foundation

/// 仅识别从 UTF-16 位置 0 开始的独立斜杠输入。混合内容查询留给 1B-2。
struct CommandPathParser {
    var catalog = CommandCatalog.standard

    func parse(_ request: CommandPathRequest) -> CommandPathResult {
        let text = request.text
        var result = CommandPathResult(input: text, state: .ordinaryText, requiresCompositionEnd: request.hasMarkedText)
        guard text.hasPrefix("/"), !text.hasPrefix("//"),
              !TagSyntax.protectedRanges(in: text).contains(where: { NSLocationInRange(0, $0) }),
              recognizesStart(text) else { return result }
        let cursor = request.cursorLocation ?? text.utf16.count
        guard CommandPathText.valid(NSRange(location: cursor, length: 0), in: text) else {
            result.state = .invalid
            result.diagnostics = [.init(issue: .invalidCursor, range: NSRange(location: 0, length: text.utf16.count))]
            return result
        }
        result = analyze(text, configuration: request.configuration)
        result.requiresCompositionEnd = request.hasMarkedText
        result.candidates = CommandPathCompletion(catalog: catalog).candidates(request, cursor: cursor)
        if result.state == .invalid, result.diagnostics.first?.issue == .unknownPath,
           !result.candidates.isEmpty, cursor == text.utf16.count {
            result.state = .incompletePath
        }
        return result
    }

    private func recognizesStart(_ text: String) -> Bool {
        let parts = text.dropFirst().split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count > 1, let first = parts.first else { return true }
        let resolver = CommandPathResolver(catalog: catalog)
        // 未知的多段绝对路径按普通文本保留；保留目录根词才进入指令语法。
        return !resolver.resolve("/" + first).isEmpty
    }

    private func analyze(_ text: String, configuration: CommandDiscoveryConfiguration) -> CommandPathResult {
        let range = NSRange(location: 0, length: text.utf16.count)
        // 名称可以包含空格，但不解释混合查询、引号或转义；原文仍完整返回。
        if text.contains(where: { $0.isNewline || "\\\"`?#".contains($0) }) || text.contains("://") {
            return invalid(text, issue: .invalidSyntax, range: range)
        }
        let trailing = text.count > 1 && text.hasSuffix("/")
        let path = trailing ? String(text.dropLast()) : text
        let resolver = CommandPathResolver(catalog: catalog)
        let exact = resolver.resolve(path)
        let canonical = exact.filter { $0.path == path }
        if !canonical.isEmpty { return resolved(canonical, text: text, configuration: configuration) }
        let tail = tailResolution(path, text: text, configuration: configuration)
        if !exact.isEmpty {
            if let tail, !tail.arguments.isEmpty || tail.diagnostics.first?.issue == .ambiguous {
                let tailIDs = tail.command.map { [$0.id] } ?? tail.diagnostics.flatMap(\.commandIDs)
                return invalid(text, issue: .ambiguous, range: range, ids: exact.map(\.id) + tailIDs)
            }
            return resolved(exact, text: text, configuration: configuration)
        }
        if let tail { return tail }
        return invalid(text, issue: .unknownPath, range: lastRange(text))
    }

    private func resolved(
        _ entries: [CommandDescriptor], text: String, configuration: CommandDiscoveryConfiguration
    ) -> CommandPathResult {
        guard entries.count == 1, let command = entries.first else {
            return invalid(text, issue: .ambiguous, range: lastRange(text), ids: entries.map(\.id))
        }
        guard permitted(command, configuration: configuration) else {
            return invalid(text, issue: .restricted, range: lastRange(text), ids: [command.id])
        }
        var result = CommandPathResult(input: text, state: .command, command: command)
        result.argumentIssues = CommandArgumentValidation.issues(for: [], command: command)
        switch command.category {
        case .group: result.state = .group
        case .scope: result.state = .scope
        default:
            if !command.parameters.isEmpty {
                result.state = result.argumentIssues.contains {
                    if case .missing = $0 { return true }
                    return false
                } ? .incompleteArguments : .command
                result.diagnostics = [.init(
                    issue: .chooseParameter, range: NSRange(location: text.utf16.count, length: 0),
                    commandIDs: [command.id], parameterIDs: command.parameters.map(\.id)
                )]
            }
        }
        return result
    }

    private func tailResolution(
        _ path: String, text: String, configuration: CommandDiscoveryConfiguration
    ) -> CommandPathResult? {
        let parentPath = CommandCatalog.parentPath(of: path)
        guard parentPath != "/" else { return nil }
        let parents = CommandPathResolver(catalog: catalog).resolve(parentPath)
        guard !parents.isEmpty else { return nil }
        guard parents.count == 1, let command = parents.first else {
            return invalid(text, issue: .ambiguous, range: lastRange(text), ids: parents.map(\.id))
        }
        guard permitted(command, configuration: configuration) else {
            return invalid(text, issue: .restricted, range: lastRange(text), ids: [command.id])
        }
        guard command.category != .group else { return nil }
        var result = resolved([command], text: text, configuration: configuration)
        guard let parameter = CommandPathArguments.parameter(for: command) else {
            result.state = command.parameters.isEmpty ? .invalid : .incompleteArguments
            result.diagnostics = [.init(
                issue: command.parameters.isEmpty ? .unsupportedTail : .chooseParameter, range: lastRange(text),
                commandIDs: [command.id], parameterIDs: command.parameters.map(\.id)
            )]
            return result
        }
        let token = String(path.split(separator: "/", omittingEmptySubsequences: false).last ?? "")
        let values = CommandPathArguments.values(token, parameter: parameter)
            .filter { CommandArgumentValidation.accepts($0, type: parameter.type) }
        guard values.count == 1, let value = values.first else {
            result.state = values.isEmpty ? .incompleteArguments : .invalid
            result.diagnostics = [.init(
                issue: values.isEmpty ? .invalidArgument : .ambiguous, range: lastRange(text),
                commandIDs: [command.id], parameterIDs: [parameter.id]
            )]
            return result
        }
        result.arguments = [CommandPathArguments.argument(value, parameter: parameter)]
        result.argumentIssues = CommandArgumentValidation.issues(for: result.arguments, command: command)
        result.state = result.argumentIssues.contains { $0 != .unavailable } ? .invalid : .command
        result.diagnostics = []
        return result
    }

    func permitted(_ command: CommandDescriptor, configuration: CommandDiscoveryConfiguration) -> Bool {
        guard let allowed = configuration.allowedIDs else { return true }
        return allowed.contains(command.id) || (command.category == .group
            && catalog.discover(configuration: configuration).contains { $0.id == command.id })
    }

    private func invalid(
        _ text: String, issue: CommandPathIssue, range: NSRange, ids: [CommandID] = []
    ) -> CommandPathResult {
        CommandPathResult(input: text, state: .invalid, diagnostics: [.init(issue: issue, range: range, commandIDs: ids)])
    }

    private func lastRange(_ text: String) -> NSRange {
        let source = text as NSString
        let slash = source.range(of: "/", options: .backwards)
        let start = slash.location == NSNotFound ? 0 : NSMaxRange(slash)
        return NSRange(location: start, length: source.length - start)
    }
}
