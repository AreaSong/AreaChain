import Foundation

struct ContentQueryParser {
    var catalog = CommandCatalog.standard

    func parse(_ source: String, context: ContentQueryDateContext) -> ContentQueryInput {
        let pathParser = CommandPathParser(catalog: catalog)
        var query = ContentQuery(source: source)
        var start = source.startIndex
        if source.hasPrefix("/") {
            let fullPath = pathParser.parse(.init(text: source))
            if [.command, .incompleteArguments, .group].contains(fullPath.state)
                || fullPath.diagnostics.contains(where: { $0.issue == .ambiguous }) { return .command(fullPath) }
            // 最长、完整的目录范围别名优先；仅空白边界可连接内容条件。
            if let prefix = scopePrefix(source, parser: pathParser) {
                guard prefix.result.state == .scope, let scope = prefix.result.command?.contentScope else {
                    return .command(fullPath)
                }
                query.scopes.append(.init(scope: scope, range: NSRange(source.startIndex..<prefix.end, in: source)))
                start = prefix.end
            } else {
                let path = pathParser.parse(.init(text: source))
                if path.state != .ordinaryText { return .command(path) }
            }
        }
        let tokens = ContentQueryLexer.scan(source, from: start)
        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token.kind {
            case .atom:
                append(token, context: context, query: &query)
                index += 1
            case .open:
                parseGroup(tokens, index: &index, context: context, query: &query)
            case .close, .or:
                query.diagnostics.append(.init(issue: .unsupportedStructure, range: token.range))
                index += 1
            }
        }
        query.diagnostics += ContentQueryValidation.diagnostics(query)
        return .content(query)
    }

    private func scopePrefix(
        _ source: String, parser: CommandPathParser
    ) -> (result: CommandPathResult, end: String.Index)? {
        let boundaries = source.indices.filter { source[$0].isWhitespace } + [source.endIndex]
        for end in boundaries.reversed() {
            let result = parser.parse(.init(text: String(source[..<end])))
            if [.scope, .command, .incompleteArguments, .group].contains(result.state)
                || result.diagnostics.contains(where: { $0.issue == .ambiguous }) {
                return (result, end)
            }
        }
        return nil
    }

    private func append(_ token: ContentQueryLexeme, context: ContentQueryDateContext, query: inout ContentQuery) {
        if !token.literal, token.raw.hasPrefix("/") {
            let path = CommandPathParser(catalog: catalog).parse(.init(text: token.raw))
            if path.state == .scope, let scope = path.command?.contentScope {
                query.scopes.append(.init(scope: scope, range: token.range))
            } else if path.state == .ordinaryText {
                let term = ContentQueryTerm(atom: .text(token.raw, phrase: false), range: token.range)
                query.clauses.append(.init(alternatives: [term], range: token.range))
            } else {
                query.diagnostics.append(.init(issue: .unsupportedStructure, range: token.range))
            }
            return
        }
        switch ContentQueryAtomParser.parse(token, context: context) {
        case .success(let term): query.clauses.append(.init(alternatives: [term], range: token.range))
        case .failure(let failure): query.diagnostics.append(.init(issue: failure.issue, range: token.range))
        }
    }

    private func parseGroup(
        _ tokens: [ContentQueryLexeme], index: inout Int, context: ContentQueryDateContext, query: inout ContentQuery
    ) {
        let begin = index
        var depth = 1
        var nested = false
        index += 1
        while index < tokens.count, depth > 0 {
            if tokens[index].kind == .open { depth += 1; nested = true }
            if tokens[index].kind == .close { depth -= 1 }
            index += 1
        }
        let range = NSUnionRange(tokens[begin].range, tokens[index - 1].range)
        guard depth == 0, !nested else {
            query.diagnostics.append(.init(issue: nested ? .nestedGroup : .incompleteGroup, range: range))
            return
        }
        let body = Array(tokens[(begin + 1)..<(index - 1)])
        let validShape = body.count >= 3 && body.count % 2 == 1 && body.enumerated().allSatisfy {
            $0.element.kind == ($0.offset % 2 == 0 ? .atom : .or)
        }
        guard validShape else {
            query.diagnostics.append(.init(issue: body.last?.kind == .or ? .incompleteCondition : .unsupportedStructure, range: range))
            return
        }
        let terms = body.filter { $0.kind == .atom }.compactMap { token -> ContentQueryTerm? in
            switch ContentQueryAtomParser.parse(token, context: context) {
            case .success(let term): return term
            case .failure(let failure):
                query.diagnostics.append(.init(issue: failure.issue, range: token.range))
                return nil
            }
        }
        guard terms.count == (body.count + 1) / 2 else { return }
        guard Set(terms.map { $0.atom.dimension.rawValue }).count == 1 else {
            query.diagnostics.append(.init(issue: .mixedDimensions, range: range))
            return
        }
        query.clauses.append(.init(alternatives: terms, range: range))
    }
}
