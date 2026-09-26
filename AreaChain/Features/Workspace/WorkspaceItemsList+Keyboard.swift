import AppKit

enum ItemsListKey {
    static let edit: UInt16 = 14
    static let returnKey: UInt16 = 36
    static let space: UInt16 = 49
    static let delete: UInt16 = 51
    static let escape: UInt16 = 53
    static let arrowDown: UInt16 = 125
    static let arrowUp: UInt16 = 126
}

struct ItemsListKeyContext: Equatable {
    var responderClaimsKeys: Bool
    var hasRows: Bool
    var hasSelection: Bool
    var hasMultiSelection: Bool
    var inspectorPresented: Bool
}

/// 按钮、菜单和输入框聚焦时，待处理与全部事项清单不接管按键。
enum ItemsListKeyRouting {
    static func responderClaimsKeys(_ responder: NSResponder?) -> Bool {
        if responder is NSTextView { return false }
        if responder is NSControl { return false }
        return true
    }

    static func consumes(_ keyCode: UInt16, context: ItemsListKeyContext) -> Bool {
        guard context.responderClaimsKeys, context.hasRows else { return false }
        switch keyCode {
        case ItemsListKey.arrowDown, ItemsListKey.arrowUp:
            return true
        case ItemsListKey.space, ItemsListKey.returnKey, ItemsListKey.edit, ItemsListKey.delete:
            return context.hasSelection
        case ItemsListKey.escape:
            return context.inspectorPresented || context.hasMultiSelection || context.hasSelection
        default:
            return false
        }
    }
}
