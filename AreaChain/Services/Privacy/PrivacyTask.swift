import Foundation

/// 把父任务取消转发到 `Task.detached`。分离任务默认不继承取消，备份加解密必须自己观察。
enum PrivacyTask {
    static func checkCancellation() throws {
        do {
            try Task.checkCancellation()
        } catch is CancellationError {
            throw PrivacyError.cancelled
        }
    }

    static func detached<Success: Sendable>(
        priority: TaskPriority = .userInitiated,
        operation: @escaping @Sendable () throws -> Success
    ) async throws -> Success {
        let work = Task.detached(priority: priority) {
            try checkCancellation()
            return try operation()
        }
        do {
            return try await withTaskCancellationHandler {
                try await work.value
            } onCancel: {
                work.cancel()
            }
        } catch is CancellationError {
            throw PrivacyError.cancelled
        }
    }
}
