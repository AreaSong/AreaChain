import Foundation

/// 只沿当前发布的完整类型化身份取安全行；不回查实体、正文或另一批 UUID。
extension ContentQueryReadSession {
    func objectCandidate(_ object: CommandObjectReference, sourceID: UUID) throws -> ContentQueryPresentationRow {
        let publication = try presentation()
        let snapshot = publication.pagination.snapshot
        guard snapshot.sourceID == sourceID, snapshot.known.contains(object),
              let row = snapshot.row(object),
              publication.response.matches.contains(where: { match in
                  guard match.id == object else { return false }
                  switch match {
                  case .todo, .subtask, .routine, .routineOccurrence: return true
                  default: return false
                  }
              }) else { throw ContentQueryReadSessionError.noPresentation }
        return row
    }
}
