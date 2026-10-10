import Foundation

/// 组合缓冲只拥有尚未确认的片段及被替换片段；不拥有第二份可执行正文。
struct CommandTextComposition: Codable, Equatable {
    var text: String
    var location: Int
    var replacedText: String
    var pendingConfirmation = false
    var range: NSRange { .init(location: location, length: text.utf16.count) }
}

struct CommandTextPosition: Equatable {
    var selection: NSRange
    var composition: CommandTextComposition?
}

/// 事务内的计算快照。spelling 是原生投影，arguments 始终只接受 confirmedText。
/// 普通草稿仅保存位置/组合缓冲；受保护载荷核对两者一致后才接受。
struct CommandDraftEditingState: Codable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    var parameter: String
    var spelling: String
    var selectionLocation: Int
    var selectionLength: Int
    var composition: CommandTextComposition?
    var description: String { "CommandDraftEditingState(redacted)" }
    var debugDescription: String { description }
    var selection: NSRange { .init(location: selectionLocation, length: selectionLength) }
    var position: CommandTextPosition { .init(selection: selection, composition: composition) }

    var confirmedText: String {
        guard let composition, Self.valid(composition.range, in: spelling) else { return spelling }
        return (spelling as NSString).replacingCharacters(in: composition.range, with: composition.replacedText)
    }

    static func valid(_ range: NSRange, in text: String) -> Bool {
        guard range.location >= 0, range.length >= 0, range.location <= text.utf16.count,
              range.length <= text.utf16.count - range.location, let swiftRange = Range(range, in: text) else { return false }
        // 不在 surrogate 或扩展字素中间接受选区/替换；emoji 与组合重音保持完整。
        return (swiftRange.lowerBound == text.endIndex || text.indices.contains(swiftRange.lowerBound))
            && (swiftRange.upperBound == text.endIndex || text.indices.contains(swiftRange.upperBound))
    }

    func validate() throws {
        guard CommandParameterID(rawValue: parameter) != nil, Self.valid(selection, in: spelling) else {
            throw CommandPlanError.invalidInput
        }
        if let composition {
            guard Self.valid(composition.range, in: spelling),
                  (spelling as NSString).substring(with: composition.range) == composition.text,
                  Self.valid(.init(location: composition.location, length: composition.replacedText.utf16.count), in: confirmedText)
            else { throw CommandPlanError.invalidInput }
        }
    }

    func cancellingComposition() -> Self {
        guard let composition else { return self }
        return .init(parameter: parameter, spelling: confirmedText, selectionLocation: composition.location,
                     selectionLength: composition.replacedText.utf16.count)
    }

    func confirmingComposition() -> Self {
        var next = self
        next.composition = nil
        return next
    }

    func pendingRestore() -> Self {
        var next = self
        next.composition?.pendingConfirmation = true
        return next
    }
}
