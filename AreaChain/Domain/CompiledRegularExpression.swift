import Foundation

/// 编译期常量正则。模式写错应直接失败，避免 `try!` 把不变量伪装成可恢复错误。
enum CompiledRegularExpression {
    static func make(_ pattern: String, options: NSRegularExpression.Options = []) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern, options: options)
        } catch {
            preconditionFailure("Invalid regular expression \(pattern): \(error)")
        }
    }
}
