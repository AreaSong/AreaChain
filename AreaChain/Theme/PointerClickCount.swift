import AppKit

/// 按钮动作里判断单击／双击的唯一入口。AppKit 只允许对鼠标事件读 `clickCount`，对键盘、辅助功能或
/// 系统内部事件读会抛 NSInternalInconsistencyException 直接崩溃；键盘空格、VoiceOver 按下等激活方式
/// 触发同一按钮动作时，当前事件就不是鼠标事件，这里按单击处理。默认读取 NSApp.currentEvent，只在主线程使用。
@MainActor
enum PointerClickCount {
    /// 与 NSEvent.h 的约定一致：clickCount 只对鼠标按下、抬起与拖拽事件有效。
    private static let mouseTypes: Set<NSEvent.EventType> = [
        .leftMouseDown, .leftMouseUp, .leftMouseDragged, .rightMouseDown, .rightMouseUp, .rightMouseDragged,
        .otherMouseDown, .otherMouseUp, .otherMouseDragged,
    ]

    static func current(_ event: NSEvent? = NSApp.currentEvent) -> Int {
        guard let event, mouseTypes.contains(event.type) else { return 1 }
        return event.clickCount
    }
}
