import Foundation

struct ContentQueryParser {
    func parse(_ source: String, context: ContentQueryDateContext) -> ContentQueryInput {
        var query = ContentQuery(source: source)
        var start = source.startIndex
        if source.hasPrefix("/") {
            let firstBoundary = source.firstIndex(where: \.isWhitespace) ?? source.endIndex
            let firstToken = String(source[..<firstBoundary])
            let scopeCandidate = String(firstToken.dropFirst()).lowercased()
            if let scope = CommandContentScope(rawValue: scopeCandidate) {
                query.scopes.append(.init(scope: scope, range: NSRange(source.startIndex..<firstBoundary, in: source)))
                start = firstBoundary
            } else if scopeCandidate.contains(".") || firstToken.hasPrefix("/tmp/") || firstToken.hasPrefix("/var/") || firstToken.hasPrefix("/usr/") || firstToken.hasPrefix("/Users/") {
                // 文件路径（如 /tmp/example.txt）进入普通内容查询
            } else {
                return .command(source)
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

    private func append(_ token: ContentQueryLexeme, context: ContentQueryDateContext, query: inout ContentQuery) {
        if !token.literal, token.raw.hasPrefix("/") {
            let body = String(token.raw.dropFirst())
            if let scope = CommandContentScope(rawValue: body.lowercased()) {
                query.scopes.append(.init(scope: scope, range: token.range))
            } else if body.contains("/") || body.contains(".") {
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
