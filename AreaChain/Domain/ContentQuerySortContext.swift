import Foundation

/// 与响应同次构造；只保留原文字条件及日期环境，没有宿主状态或可重新读取的输入。
struct ContentQuerySortContext: CustomStringConvertible, CustomDebugStringConvertible {
    struct Clause: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
        let id: ContentQueryConditionID
        let terms: [ContentQuerySemanticTerm]
        var description: String { "ContentQuerySortContext.Clause(redacted)" }
        var debugDescription: String { description }
    }
    struct PresentationCondition: CustomStringConvertible, CustomDebugStringConvertible {
        let value: ContentQueryConditionValue
        var description: String { "ContentQuerySortContext.PresentationCondition(redacted)" }
        var debugDescription: String { description }
    }
    let conditionIDs: Set<ContentQueryConditionID>
    /// 展示只用条件的类型/分支核验来源；不持有 Session 或原始快照。
    let presentationConditions: [ContentQueryConditionID: PresentationCondition]
    let clauses: [Clause]
    let dates: ContentQueryDateContext
    let explicitMode: ClipboardSearchMode?
    let hasExplicitText: Bool

    init(batch: ContentQueryBatch) {
        conditionIDs = Set(batch.session.conditions.map(\.id))
        presentationConditions = Dictionary(batch.session.conditions.map { ($0.id, PresentationCondition(value: $0.value)) },
                                            uniquingKeysWith: { first, _ in first })
        clauses = batch.session.conditions.compactMap {
            guard case .clause(let terms) = $0.value,
                  terms.allSatisfy({ $0.atom.dimension == .text }) else { return nil }
            return Clause(id: $0.id, terms: terms)
        }
        dates = batch.dates
        if batch.session.scope == .catalog(.clipboard),
           case .explicit(let mode, let needle) = batch.options.clipboardMode {
            explicitMode = mode
            hasExplicitText = !needle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            explicitMode = nil
            hasExplicitText = false
        }
    }
    var hasPositiveText: Bool { clauses.contains { $0.terms.contains { !$0.excluded } } }
    var description: String { "ContentQuerySortContext(redacted)" }
    var debugDescription: String { description }
}
