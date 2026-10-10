import Foundation

/// 仅 Debug 合成测量使用；没有正文、持久化或运行态日志，Release 直接执行原调用。
enum CommandTextTiming {
    #if DEBUG
    static var observe: ((String, Double) -> Void)?
    #endif

    static func measure<T>(_ phase: String, _ body: () throws -> T) rethrows -> T {
        #if DEBUG
        guard let observe else { return try body() }
        let start = ContinuousClock.now
        defer {
            let duration = start.duration(to: .now).components
            observe(phase, Double(duration.seconds) * 1_000 + Double(duration.attoseconds) / 1e15)
        }
        #endif
        return try body()
    }
}
