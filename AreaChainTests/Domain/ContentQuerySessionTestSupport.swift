import Foundation
import Testing
@testable import AreaChain

enum QuerySessionFixture {
    static let today = "2026-10-01"

    static func page(
        _ page: ContentQueryPage = .today(.init()), visit: String = "visit-1", host: String = "workspace"
    ) -> ContentQueryPageContext {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return .init(location: .init(hostID: host, visitID: visit, reference: "page-" + visit),
                     page: page, todayKey: today, calendar: calendar)
    }

    static func interval(_ lower: String = today, _ upper: String = today) -> ContentQueryDateInterval {
        .init(lowerBound: lower, upperBound: upper)
    }

    @discardableResult static func apply(_ event: ContentQueryEvent, _ state: inout ContentQuerySession) -> [ContentQueryIntent] {
        let result = ContentQueryReducer.reduce(state, event)
        state = result.state
        return result.intents
    }

    static func condition(
        _ dimension: ContentQueryConditionDimension, in state: ContentQuerySession
    ) throws -> ContentQueryCondition {
        try #require(state.conditions.first { $0.value.dimension == dimension })
    }

    static func source(_ state: ContentQuerySession) throws -> String {
        guard case .content(let query) = state.input else { throw ExpectedContent() }
        return query.source
    }

    private struct ExpectedContent: Error {}
}
