import Foundation
@testable import AreaChain

/// 等读写循环真正进入目标回调后再取消。allowPasses 用于跳过清单散列、卡在暂存写入。
final class CancelGate: @unchecked Sendable {
    private let condition = NSCondition()
    private var started = false
    private var remainingPasses: Int

    init(allowPasses: Int = 0) {
        remainingPasses = allowPasses
    }

    func waitUntilWorkStarted(timeout: TimeInterval = 5) throws {
        condition.lock()
        defer { condition.unlock() }
        let deadline = Date().addingTimeInterval(timeout)
        while !started {
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else { throw PrivacyError.busy }
            _ = condition.wait(until: Date().addingTimeInterval(remaining))
        }
    }

    func blockUntilCancelled(timeout: TimeInterval = 5) throws {
        condition.lock()
        if remainingPasses > 0 {
            remainingPasses -= 1
            condition.unlock()
            try PrivacyTask.checkCancellation()
            return
        }
        started = true
        condition.broadcast()
        condition.unlock()
        let deadline = Date().addingTimeInterval(timeout)
        while !Task.isCancelled {
            guard Date() < deadline else { throw PrivacyError.busy }
            Thread.sleep(forTimeInterval: 0.005)
        }
        try PrivacyTask.checkCancellation()
    }
}
