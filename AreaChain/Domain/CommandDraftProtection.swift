import Foundation

/// 身份不授予读取权限；密文和访问资格只存在于隔离内容服务中。
struct CommandProtectedReference: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let payloadID: UUID
    let revision: UUID
    var description: String { "CommandProtectedReference(opaque)" }
    var debugDescription: String { description }
}

enum CommandProtectionRequirement: Equatable { case ordinary, required, unknown }
enum CommandParameterCompleteness: Equatable { case complete, incomplete, protectedUnknown }

extension CommandDraft {
    var blocksUnprotectedTransfer: Bool { protectedReference != nil || protectionRequirement != .ordinary }

    /// 自由长文的协议导出尚无受控借用契约；不根据关键词缺失放行。
    var blocksUnprotectedExport: Bool {
        blocksUnprotectedTransfer
            || arguments.contains { if case .longText = $0.value { return true }; return false }
            || baseline.values.values.contains {
                if case .uniform(.longText) = $0 { return true }; return false
            }
    }
}
