import Foundation

/// 只连接本输入实例。同步撤去原生组合、候选和撤销，后续正常更新仍消费同一 Buffer。
@MainActor
final class UnifiedSearchInputReset {
    weak var state: UnifiedSearchInputState?

    func invalidate(_ buffer: UnifiedSearchBuffer) {
        guard let state else { return }
        if let field = state.field { state.synchronize(buffer, field: field) }
        state.clearNative()
    }
}
