import Foundation

/// 条件之间取交集，alternatives 内取并集；保留重复与源位置，不以最后值覆盖。
struct ContentQuery: Equatable {
    let source: String
    var scopes: [ContentQueryScopeToken] = []
    var clauses: [ContentQueryClause] = []
    var diagnostics: [ContentQueryDiagnostic] = []

    var isStructurallyValid: Bool { !diagnostics.contains { $0.issue.blocksStructure } }
    /// 解析阶段不具备对象绑定；语义可行性由 Session.typeAnalysis 提供。
    var isReady: Bool { isStructurallyValid }
}

struct ContentQueryScopeToken: Equatable {
    let scope: CommandContentScope
    let range: NSRange
}

struct ContentQueryClause: Equatable {
    let alternatives: [ContentQueryTerm]
    let range: NSRange
}

struct ContentQueryTerm: Equatable {
    let atom: ContentQueryAtom
    var excluded = false
    let range: NSRange
}

enum ContentQueryDimension: String, CaseIterable {
    case text, tag, priority, reminder, status, date, on, created, image
}

enum ContentQueryAtom: Equatable {
    case text(String, phrase: Bool)
    case tag(String)
    case priority(PriorityFlags)
    case reminder(Int)
    case status(ContentQueryStatus)
    case date(ContentQueryDateInterval)
    case on(String)
    case created(ContentQueryDateInterval)
    case image

    var dimension: ContentQueryDimension {
        switch self {
        case .text: .text
        case .tag: .tag
        case .priority: .priority
        case .reminder: .reminder
        case .status: .status
        case .date: .date
        case .on: .on
        case .created: .created
        case .image: .image
        }
    }
}

enum ContentQueryStatus: String { case open, done, skipped }

/// 代码供后续双语 UI 映射；range 始终对应未经改写的 source。
struct ContentQueryDiagnostic: Equatable {
    let issue: ContentQueryIssue
    let range: NSRange
    var relatedRanges: [NSRange] = []
}

enum ContentQueryIssue: String {
    case incompleteQuote, incompleteEscape, incompleteGroup, incompleteCondition
    case invalidEscape, invalidCondition, invalidDate, reversedDateInterval, invalidDateContext
    case mixedDimensions, nestedGroup, unsupportedStructure, unsupportedExclusion
    case duplicateCondition, unsatisfiable, incompatibleScopes, analysisLimit, ambiguousConditionIDs
    case occurrenceDayMustBeSingle, multipleOccurrenceDaysInGroup, conflictingOccurrenceDays

    var blocksStructure: Bool {
        ![Self.duplicateCondition, .unsatisfiable, .analysisLimit].contains(self)
    }
}

/// 独立指令（包括未完成路径）保持 1B-1 原结果，参数正文不会进入内容词法分析。
enum ContentQueryInput: Equatable {
    case content(ContentQuery)
    case command(CommandPathResult)
}
