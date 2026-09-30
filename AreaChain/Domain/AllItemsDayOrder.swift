import Foundation

/// 全部事项里一次性事项的日期顺序：今天，然后未来由近到远，再是过去由近到远。
enum AllItemsDayOrder {
    static func ordered(_ dayKeys: [String], todayKey: String) -> [String] {
        let unique = Array(Set(dayKeys))
        let today = unique.filter { $0 == todayKey }
        let future = unique.filter { $0 > todayKey }.sorted()
        let past = unique.filter { $0 < todayKey }.sorted(by: >)
        return today + future + past
    }
}
