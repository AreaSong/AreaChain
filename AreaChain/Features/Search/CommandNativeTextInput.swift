import AppKit

/// NSTextInputClient 的范围只用于构造候选；该值本身从不发布给业务参数。
enum CommandNativeTextInput {
    /// 只用于已接受文本的原生安装；保留共同前后缀，避免 setString 使全部字形/布局失效。
    static func difference(from previous: String, to next: String) -> (range: NSRange, text: String) {
        let old = previous as NSString, new = next as NSString
        var oldUnits = [unichar](repeating: 0, count: old.length)
        var newUnits = [unichar](repeating: 0, count: new.length)
        old.getCharacters(&oldUnits, range: NSRange(location: 0, length: old.length))
        new.getCharacters(&newUnits, range: NSRange(location: 0, length: new.length))
        let common = matchingUnits(oldUnits, newUnits, limit: min(old.length, new.length), fromEnd: false)
        let prefix = min(boundary(common, in: old, roundingUp: false), boundary(common, in: new, roundingUp: false))
        var suffix = matchingUnits(oldUnits, newUnits, limit: min(old.length, new.length) - prefix, fromEnd: true)
        if suffix > 0 {
            suffix = min(old.length - boundary(old.length - suffix, in: old, roundingUp: true),
                         new.length - boundary(new.length - suffix, in: new, roundingUp: true))
            // 区域指示符等序列在两边可能有不同配对；不逐字回退造成平方级扫描。
            // 边界不能同时对齐时替换剩余区间，最终正文仍完全相同。
            if boundary(old.length - suffix, in: old, roundingUp: true) != old.length - suffix
                || boundary(new.length - suffix, in: new, roundingUp: true) != new.length - suffix { suffix = 0 }
        }
        return (.init(location: prefix, length: old.length - prefix - suffix),
                new.substring(with: .init(location: prefix, length: new.length - prefix - suffix)))
    }

    private static func matchingUnits(_ first: [unichar], _ second: [unichar], limit: Int, fromEnd: Bool) -> Int {
        guard limit > 0 else { return 0 }
        return first.withUnsafeBufferPointer { left in
            second.withUnsafeBufferPointer { right in
                var low = 0, high = limit
                while low < high {
                    let count = low + (high - low + 1) / 2
                    let offsetLeft = fromEnd ? left.count - count : 0
                    let offsetRight = fromEnd ? right.count - count : 0
                    if memcmp(left.baseAddress!.advanced(by: offsetLeft), right.baseAddress!.advanced(by: offsetRight),
                              count * MemoryLayout<unichar>.size) == 0 { low = count }
                    else { high = count - 1 }
                }
                return low
            }
        }
    }

    private static func boundary(_ offset: Int, in text: NSString, roundingUp: Bool) -> Int {
        guard offset > 0, offset < text.length else { return offset }
        let range = text.rangeOfComposedCharacterSequence(at: offset)
        return roundingUp && range.location != offset ? NSMaxRange(range) : range.location
    }

    static func text(_ value: Any) -> String? {
        (value as? String) ?? (value as? NSAttributedString)?.string
    }

    static func insert(_ text: String, range requested: NSRange, in state: CommandDraftEditingState) throws -> CommandDraftEditingState {
        let range = requested.location == NSNotFound ? state.composition?.range ?? state.selection : requested
        guard CommandDraftEditingState.valid(range, in: state.spelling) else { throw CommandPlanError.invalidInput }
        if let composition = state.composition, range != composition.range { throw CommandPlanError.invalidInput }
        // 输入法用空 insert 取消 marked text 时恢复原被替换内容，不能把被选原文吞掉。
        if let composition = state.composition, text.isEmpty, range == composition.range { return state.cancellingComposition() }
        let display = (state.spelling as NSString).replacingCharacters(in: range, with: text)
        let result = CommandDraftEditingState(parameter: state.parameter, spelling: display,
            selectionLocation: range.location + text.utf16.count, selectionLength: 0)
        try result.validate()
        return result
    }

    static func mark(_ text: String, selection: NSRange, range requested: NSRange,
                     in state: CommandDraftEditingState) throws -> CommandDraftEditingState {
        guard CommandDraftEditingState.valid(selection, in: text) else { throw CommandPlanError.invalidInput }
        if text.isEmpty, state.composition == nil { return state }
        let range = requested.location == NSNotFound ? state.composition?.range ?? state.selection : requested
        guard CommandDraftEditingState.valid(range, in: state.spelling) else { throw CommandPlanError.invalidInput }
        if text.isEmpty, let composition = state.composition, range == composition.range { return state.cancellingComposition() }
        let composition: CommandTextComposition
        if let previous = state.composition {
            // 更新可替换 marked 内的子区间；不能静默确认原组合后跨区开启第二份组合。
            guard range.location >= previous.range.location, NSMaxRange(range) <= NSMaxRange(previous.range) else {
                throw CommandPlanError.invalidInput
            }
            let local = NSRange(location: range.location - previous.location, length: range.length)
            var next = previous
            next.text = (previous.text as NSString).replacingCharacters(in: local, with: text)
            next.pendingConfirmation = false
            composition = next
        } else {
            composition = .init(text: text, location: range.location,
                                replacedText: (state.spelling as NSString).substring(with: range))
        }
        let display = (state.spelling as NSString).replacingCharacters(in: range, with: text)
        let result = CommandDraftEditingState(parameter: state.parameter, spelling: display,
            selectionLocation: range.location + selection.location, selectionLength: selection.length, composition: composition)
        try result.validate()
        return result
    }
}

/// 锁定回调发生在 undo/redo 内时，先撤销访问，等系统正常退出分组后再清本控件历史。
@MainActor final class CommandNativeUndoManager: UndoManager {
    private var revoked = false
    func revoke() {
        revoked = true
        if !isUndoing && !isRedoing { removeAllActions() }
    }
    override func undo() {
        guard !revoked else { return }
        defer { if revoked { removeAllActions() } }
        super.undo()
    }
    override func redo() {
        guard !revoked else { return }
        defer { if revoked { removeAllActions() } }
        super.redo()
    }
}
