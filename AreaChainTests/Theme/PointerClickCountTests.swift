import AppKit
import Testing
@testable import AreaChain

/// 键盘、辅助功能或系统事件触发按钮动作时不能读 clickCount（AppKit 会抛异常崩溃），统一按单击处理。
@Suite @MainActor struct PointerClickCountTests {
    @Test func mouseEventsKeepTheirClickCount() throws {
        let double = try #require(NSEvent.mouseEvent(with: .leftMouseUp, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 2, pressure: 1))
        #expect(PointerClickCount.current(double) == 2)
        let dragged = try #require(NSEvent.mouseEvent(with: .leftMouseDragged, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 2, pressure: 1))
        #expect(PointerClickCount.current(dragged) == 2)
    }

    @Test func nonMouseEventsCountAsSingleClick() throws {
        let key = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, characters: " ", charactersIgnoringModifiers: " ", isARepeat: false, keyCode: 49))
        // 与崩溃现场相同的 KitDefined 系统事件；直接读其 clickCount 会触发 NSEvent 断言。
        let kit = try #require(NSEvent.otherEvent(with: .appKitDefined, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, subtype: 4, data1: 0, data2: 0))
        #expect(PointerClickCount.current(key) == 1)
        #expect(PointerClickCount.current(kit) == 1)
        #expect(PointerClickCount.current(nil) == 1)
    }
}
