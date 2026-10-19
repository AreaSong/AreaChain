import Foundation

/// 只沿当前发布的完整类型化身份取安全行；不回查实体、正文或另一批 UUID。
extension ContentQueryReadSession {
    /// known 包含尚未展开的分页项；只有同批匹配与展示身份均完整时才是全部结果。
    func allObjectResultsComplete(sourceID: UUID) -> Bool {
        guard let publication = try? presentation() else { return false }
        let snapshot = publication.pagination.snapshot
        let identities = publication.response.matches.map(\.id)
        return snapshot.sourceID == sourceID && publication.response.completeness.matchingIsComplete
            && identities.count == snapshot.known.count && Set(identities) == snapshot.known
            && snapshot.known.allSatisfy { snapshot.row($0) != nil }
    }

    func objectCandidate(_ object: CommandObjectReference, sourceID: UUID) throws -> ContentQueryPresentationRow {
        let publication = try presentation()
        let snapshot = publication.pagination.snapshot
        guard snapshot.sourceID == sourceID, snapshot.known.contains(object),
              let row = snapshot.row(object),
              publication.response.matches.contains(where: { match in
                  guard match.id == object else { return false }
                  switch match {
                  // 标签只给已装配的简单标签指令；宿主侧按指令决定是否提供标签对象字段。
                  case .todo, .subtask, .routine, .routineOccurrence, .tag: return true
                  default: return false
                  }
              }) else { throw ContentQueryReadSessionError.noPresentation }
        return row
    }
}
