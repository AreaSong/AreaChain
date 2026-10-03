import Foundation
@testable import AreaChain

enum QueryDisplayFixture {
    static func display(_ batch: ContentQueryBatch = QueryBatchFixture.mixed()) -> ContentQueryDisplaySnapshot {
        ContentQueryDisplayBuilder.build(QueryPresentationFixture.project(batch))
    }

    static func changed(_ source: ContentQueryPresentationResponse,
                        groups: ([TrashQueryGroup]) -> [TrashQueryGroup]) -> ContentQueryDisplaySnapshot {
        let readings = source.source.source.readings.map { reading -> ContentQueryProviderRead in
            guard case .trash(var response) = reading else { return reading }
            response.groups = groups(response.groups)
            return .trash(response)
        }
        let sorted = QueryPresentationFixture.replacing(source.source, readings: readings)
        return ContentQueryDisplayBuilder.build(ContentQueryPresenter.project(sorted,
            budget: QueryPresentationFixture.budget, locale: QueryPresentationFixture.locale))
    }

    static func group(_ value: TrashQueryGroup, source: TrashTombstoneGroup? = nil,
                      matches: [CommandObjectReference]? = nil, context: [TrashTombstone]? = nil) -> TrashQueryGroup {
        .init(source: source ?? value.source, displayAnchor: value.displayAnchor,
              matches: matches ?? value.matches, context: context ?? value.context)
    }

    static func event(_ state: ContentQueryBrowseState, _ action: ContentQueryBrowseAction) -> ContentQueryBrowseEvent {
        .init(version: state.snapshot.version, action: action)
    }

    static func visibility(_ snapshot: ContentQueryDisplaySnapshot,
                           hits: Set<CommandObjectReference>) -> ContentQueryDisplaySnapshot {
        ContentQueryDisplayBuilder.build(snapshot.source, visibility: .init(units: Set(snapshot.units.map(\.id)), members: hits))
    }
}
