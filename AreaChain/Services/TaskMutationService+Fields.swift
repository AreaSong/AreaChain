import Foundation
import SwiftData

extension TaskMutationService {
    /// 旧 setDue 的表示规则；此入口只赋值，保存时机继续由各调用者决定。
    static func assignDue(_ todo: TodoItem, minutes: Int?) {
        todo.dueMinutes = RemindMinutes.clamped(minutes)
    }
}
