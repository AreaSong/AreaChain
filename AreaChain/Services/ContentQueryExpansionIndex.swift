import Foundation

/// 同批身份索引只保存数组位置，不复制正文；分页沿相同 sourceID 复用。
struct ContentQueryExpansionIndex {
    struct Position { let reading: Int; let match: Int }
    let sourceID: UUID
    private let positions: [CommandObjectReference: Position]

    init(_ publication: ContentQueryReadPublication) {
        sourceID = publication.pagination.snapshot.sourceID
        var all: [CommandObjectReference: [Position]] = [:]
        for (reading, value) in publication.response.readings.enumerated() {
            for (match, row) in value.matches.enumerated() {
                all[row.id, default: []].append(.init(reading: reading, match: match))
            }
        }
        positions = all.compactMapValues { $0.count == 1 ? $0[0] : nil }
    }

    func match(_ id: CommandObjectReference, in publication: ContentQueryReadPublication) -> ContentQueryBatchMatch? {
        guard sourceID == publication.pagination.snapshot.sourceID, let position = positions[id] else { return nil }
        let reading = publication.response.readings[position.reading]
        let index = position.match
        switch reading {
        case .todo(let value): return .todo(value.matches[index])
        case .subtask(let value): return .subtask(value.matches[index])
        case .routine(let value): return .routine(value.matches[index])
        case .diary(let value): return .diary(value.matches[index])
        case .image(let value): return .image(value.matches[index])
        case .tag(let value): return .tag(value.matches[index])
        case .clipboard(let value): return .clipboard(value.matches[index])
        case .trash(let value): return .trash(value.matches[index])
        case .routineOccurrence(let value): return .routineOccurrence(value.matches[index])
        }
    }
}
