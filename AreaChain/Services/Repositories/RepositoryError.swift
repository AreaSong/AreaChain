import Foundation

/// 仓储层标准领域错误
enum RepositoryError: LocalizedError, Sendable {
    case notFound(String)
    case invalidArgument(String)

    var errorDescription: String? {
        switch self {
        case let .notFound(msg):
            return "未找到对应数据：\(msg)"
        case let .invalidArgument(msg):
            return "无效参数：\(msg)"
        }
    }
}
