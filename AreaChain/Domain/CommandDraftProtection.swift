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

    /// 按目录声明的类型判定。凡声明为 longText 的参数，值是正文、空值还是 clear，都必须经托管、只剩印记才放行；
    /// 长文值落在其他参数上、印记落在非 longText 参数上同样拦下。不根据关键词缺失放行。
    var blocksUnprotectedExport: Bool {
        blocksUnprotectedTransfer
            || arguments.contains { !escrowedOrPlain($0) }
            || baseline.values.values.contains {
                if case .uniform(.longText) = $0 { return true }; return false
            }
    }

    private func escrowedOrPlain(_ argument: CommandArgument) -> Bool {
        if case .longText? = argument.value { return false }
        let longText = declaredType(argument.parameter) == .longText
        guard case .longTextImprint(let imprint)? = argument.value else { return !longText }
        return longText && imprint.parameter == argument.parameter && imprint.operation == argument.operation
    }
}
