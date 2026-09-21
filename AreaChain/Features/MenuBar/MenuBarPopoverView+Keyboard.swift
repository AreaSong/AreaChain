import AppKit
import SwiftUI

extension MenuBarPopoverView {
    func setupTabKeyMonitor() {
        guard tabKeyMonitor == nil else { return }
        tabKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            handleTabKeyDown(event)
        }
    }

    func tearDownTabKeyMonitor() {
        if let monitor = tabKeyMonitor {
            NSEvent.removeMonitor(monitor)
            tabKeyMonitor = nil
        }
    }

    func handleTabKeyDown(_ event: NSEvent) -> NSEvent? {
        guard event.window === hostWindow || (event.window == nil && NSApp.keyWindow === hostWindow) else { return event }
        // macOS 方向键会自动附加 .numericPad 与 .function 标记，仅提取核心修饰键进行 Command 判定
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard modifiers == .command else { return event }
        if event.charactersIgnoringModifiers?.lowercased() == "f" {
            toolbar.focusSearch()
            return nil
        }
        guard !toolbar.searchIsFocused else { return event }

        // keyCode 123: Left Arrow (← 任务), 124: Right Arrow (→ 手记)
        if event.keyCode == 123 {
            if tab != .tasks {
                withAnimation(DaybookMotion.animation(reduceMotion)) {
                    tab = .tasks
                }
            } else {
                captureFocused = true
            }
            return nil
        } else if event.keyCode == 124 {
            if tab != .diary {
                withAnimation(DaybookMotion.animation(reduceMotion)) {
                    tab = .diary
                }
            }
            return nil
        }

        return event
    }
}
