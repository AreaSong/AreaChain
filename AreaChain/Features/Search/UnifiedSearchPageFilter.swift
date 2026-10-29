import Foundation

extension UnifiedSearchController {
    /// 菜单栏筛选重新作用于统一搜索结果。筛选只有 `BoardFilterSession` 一份可编辑状态；
    /// 这里只把它派生进当前今日页访问（同一 visitID）的自动条件，不回写筛选、不另存一份。
    /// 查询已脱离页面（显式范围、转交等）时 reducer 不改写自动条件：脱离后的查询与页面相互独立。
    func refreshTodayPageFilter(_ filter: BoardFilter) {
        let hostID = buffer.lease.ownership.hostID
        guard let current = try? coordinator.host(hostID).session.query.page,
              case .today(let old) = current.page, old != filter else { return }
        var page = current
        page.page = .today(filter)
        do {
            try session.modelDidChange(expecting: buffer.lease.ownership)
            try coordinator.send(.query(.refreshPage(page)), expecting: buffer.lease)
        } catch { return }
        guard let owned = try? coordinator.host(hostID) else { return }
        renewBuffer(owned.lease)
        if owned.session.query.showsResults { refresh() }
    }
}
