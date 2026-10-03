import Foundation

enum ContentQueryReadError: Error, Equatable {
    case invalidConfiguration, invalidBudget, budgetExceeded, budgetNotIncreased, budgetCannotAdvance, atBudgetLimit
    case staleSource, staleTask, busy, noPublishedResult, noBudgetRemainder, invalidPhase
}

enum ContentQueryBudgetDimension: Hashable { case input, work, results }

/// 续读只识别提供者显式预算余量；历史、保护、冲突和展示限制没有对应维度。
struct ContentQueryContinuationRemainder: Equatable {
    let dimensions: Set<ContentQueryBudgetDimension>

    init(_ response: ContentQueryBatchResponse) {
        var dimensions: Set<ContentQueryBudgetDimension> = []
        if let reading = response.occurrenceReading, reading.state == .evaluated {
            dimensions.formUnion(reading.coverage.unprocessed.compactMap { Self.dimension($0.reason) })
            if !reading.coverage.unprocessedCheckIndices.isEmpty {
                dimensions.formUnion(reading.diagnostics.compactMap { Self.dimension($0.issue) })
            }
        }
        self.dimensions = dimensions
    }

    private static func dimension(_ issue: RoutineOccurrenceQueryIssue) -> ContentQueryBudgetDimension? {
        switch issue {
        case .inputLimit: .input
        case .workLimit: .work
        case .resultLimit: .results
        default: nil
        }
    }
}

/// 调用方显式给下一预算，不自动倍增。默认上限取原预算的四倍以约束本阶段复算；不是产品容量保证。
struct ContentQueryContinuationPolicy {
    static let technicalCeiling = RoutineOccurrenceQueryBudget(maxInputItems: 16_384, maxWork: 400_000, maxResults: 4_000)
    var maximum = technicalCeiling
    var isValid: Bool { maximum.isValid && maximum.fits(within: Self.technicalCeiling) }

    func validate(_ budget: RoutineOccurrenceQueryBudget) throws {
        guard budget.isValid else { throw ContentQueryReadError.invalidBudget }
        guard budget.fits(within: maximum) else { throw ContentQueryReadError.budgetExceeded }
    }

    func validateGrowth(from old: RoutineOccurrenceQueryBudget, to next: RoutineOccurrenceQueryBudget,
                        remainder: ContentQueryContinuationRemainder) throws {
        try validate(next)
        guard remainder.dimensions.contains(where: { old.value($0) < maximum.value($0) }) else {
            throw ContentQueryReadError.atBudgetLimit
        }
        guard old.fits(within: next), old != next else { throw ContentQueryReadError.budgetNotIncreased }
        guard remainder.dimensions.contains(where: { old.value($0) < next.value($0) }) else {
            throw ContentQueryReadError.budgetCannotAdvance
        }
    }
}

extension RoutineOccurrenceQueryBudget {
    fileprivate func value(_ dimension: ContentQueryBudgetDimension) -> Int {
        switch dimension {
        case .input: maxInputItems
        case .work: maxWork
        case .results: maxResults
        }
    }

    fileprivate func fits(within other: Self) -> Bool {
        maxInputItems <= other.maxInputItems && maxWork <= other.maxWork && maxResults <= other.maxResults
    }
}

extension ContentQueryBatchResponse {
    var occurrenceReading: RoutineOccurrenceQueryResponse? {
        for reading in readings {
            if case .routineOccurrence(let value) = reading { return value }
        }
        return nil
    }

    /// 工作计费增加本身不是进展；必须进入枚举、处理新行或推进实际未处理范围。
    func advancesOccurrenceWork(over previous: ContentQueryBatchResponse) -> Bool {
        guard let old = previous.occurrenceReading?.coverage, let next = occurrenceReading?.coverage else { return false }
        if !old.didEnumerate && next.didEnumerate { return true }
        if next.resultRowsUsed > old.resultRowsUsed { return true }
        if next.unprocessedCheckIndices != old.unprocessedCheckIndices { return true }
        let sameWindows = old.unprocessed.count == next.unprocessed.count && zip(old.unprocessed, next.unprocessed).allSatisfy {
            $0.routine == $1.routine && $0.window == $1.window
        }
        return !sameWindows
    }
}
