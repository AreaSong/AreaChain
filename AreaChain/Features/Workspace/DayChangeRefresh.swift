import SwiftUI

extension View {
    /// 和今日页一样，在系统跨日通知时刷新「今天」。`DayClock` 自己也会听这条通知。
    func refreshBoardOnDayChange() -> some View {
        onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            DayClock.shared.refresh()
        }
    }
}
