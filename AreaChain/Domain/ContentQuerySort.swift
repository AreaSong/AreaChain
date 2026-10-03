import Foundation

enum ContentQuerySortMode: Equatable { case relevance, recent }
enum ContentQuerySortFallback: Equatable {
    case noPositiveText, explicitModeWithoutComparableText
}
enum ContentQueryRelevanceTier: Int, Equatable {
    case exactName, allName, mixedFields, otherFields
}
enum ContentQueryRankReason: Equatable {
    case publicEvidence, protectedText, noPublicTextEvidence, invalidEvidence, explicitModeEvidence, recentOnly
}

/// 只存身份、枚举原因和真实精度时间，不复制正文、名称或查询到排序键。
struct ContentQueryRankedMatch: Equatable, Identifiable, CustomStringConvertible, CustomDebugStringConvertible {
    let id: CommandObjectReference
    let tier: ContentQueryRelevanceTier?
    let reason: ContentQueryRankReason
    let time: ContentQuerySortTime
    var description: String { "ContentQueryRankedMatch(redacted)" }
    var debugDescription: String { description }
}

/// source 原样保留 groups、诊断与保护限制；ordered 只表达确定命中身份序列。
struct ContentQuerySortedResponse: CustomStringConvertible, CustomDebugStringConvertible {
    let source: ContentQueryBatchResponse
    let requested: ContentQuerySortMode
    let applied: ContentQuerySortMode
    let fallback: ContentQuerySortFallback?
    let ordered: [ContentQueryRankedMatch]
    var onlyKnownSubset: Bool { !source.completeness.matchingIsComplete }
    var description: String { "ContentQuerySortedResponse(redacted)" }
    var debugDescription: String { description }
}

enum ContentQuerySorter {
    static func sort(_ response: ContentQueryBatchResponse, mode: ContentQuerySortMode) -> ContentQuerySortedResponse {
        let context = response.sortContext
        let matches = response.matches
        let fallback = fallback(context, matches: matches, requested: mode)
        let applied: ContentQuerySortMode = fallback == nil ? mode : .recent
        var ordered = matches.map { match in
            let rank = ContentQueryRelevance.rank(match, context: context)
            return ContentQueryRankedMatch(id: match.id, tier: applied == .relevance ? rank.tier : nil,
                reason: applied == .relevance ? rank.reason : .recentOnly,
                time: ContentQuerySortTime(match: match, dates: context.dates))
        }.sorted(by: precedes)
        preserveTagView(response, ordered: &ordered)
        return .init(source: response, requested: mode, applied: applied, fallback: fallback, ordered: ordered)
    }

    /// 目录视图的标签相对次序来自唯一提供者；不把内部最近时间升级为公开排序键。
    private static func preserveTagView(_ response: ContentQueryBatchResponse,
                                        ordered: inout [ContentQueryRankedMatch]) {
        guard let tags = response.readings.compactMap({ reading -> TagQueryResponse? in
            if case .tag(let value) = reading { return value }; return nil
        }).first, case .catalog = tags.view else { return }
        let ranks = Dictionary(uniqueKeysWithValues: ordered.filter { $0.id.type == .tag }.map { ($0.id, $0) })
        var sequence = tags.matches.compactMap { ranks[$0.id] }.makeIterator()
        for index in ordered.indices where ordered[index].id.type == .tag {
            if let next = sequence.next() { ordered[index] = next }
        }
    }

    private static func fallback(
        _ context: ContentQuerySortContext, matches: [ContentQueryBatchMatch], requested: ContentQuerySortMode
    ) -> ContentQuerySortFallback? {
        guard requested == .relevance else { return nil }
        if let mode = context.explicitMode {
            guard mode != .regex, context.hasExplicitText,
                  matches.contains(where: { ContentQueryRelevance.hasModeEvidence($0, mode: mode) }) else {
                return .explicitModeWithoutComparableText
            }
            return nil
        }
        return context.hasPositiveText ? nil : .noPositiveText
    }

    /// 字典序比较固定各维度的优先级，混合精度不能因对象配对改变比较策略。
    static func precedes(_ lhs: ContentQueryRankedMatch, _ rhs: ContentQueryRankedMatch) -> Bool {
        let leftTier = lhs.tier?.rawValue ?? ContentQueryRelevanceTier.otherFields.rawValue
        let rightTier = rhs.tier?.rawValue ?? ContentQueryRelevanceTier.otherFields.rawValue
        if leftTier != rightTier { return leftTier < rightTier }
        if lhs.time.day != rhs.time.day { return (lhs.time.day ?? "") > (rhs.time.day ?? "") }
        if lhs.time.instant != rhs.time.instant {
            switch (lhs.time.instant, rhs.time.instant) {
            case (.some(let left), .some(let right)): return left > right
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): break
            }
        }
        if lhs.id.type != rhs.id.type { return lhs.id.type.rawValue < rhs.id.type.rawValue }
        if lhs.id.id != rhs.id.id { return lhs.id.id.uuidString < rhs.id.id.uuidString }
        return (lhs.id.dayKey ?? "") < (rhs.id.dayKey ?? "")
    }
}
