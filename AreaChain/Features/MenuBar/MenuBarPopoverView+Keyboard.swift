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
        hostWindow = nil
    }

    func handleTabKeyDown(_ event: NSEvent) -> NSEvent? {
        guard tabKeyMonitor != nil, let hostWindow, hostWindow.isVisible,
              event.window === hostWindow || (event.window == nil && NSApp.keyWindow === hostWindow) else { return event }
        return handleTabKeyDown(event, search: ShortcutStore.shared.binding(for: .search))
    }

    func handleTabKeyDown(_ event: NSEvent, search: ShortcutBinding) -> NSEvent? {
        // keyCode 53: Escape 键收起筛选抽屉
        if event.keyCode == 53 && isFilterDrawerPresented {
            dismissFilterDrawer()
            return nil
        }

        // 帮助位于输入预览之上；只消费关闭帮助的这次事件，保留原生编辑器和输入状态。
        if dismissSyntaxHelpForEscape(event) { return nil }

        // 搜索组合来自快捷键页。停用或改成别的键之后，原来的 ⌘F 不再聚焦。
        if search.matches(event) {
            toolbar.focusSearch()
            return nil
        }

        // macOS 方向键会自动附加 .numericPad 与 .function 标记，仅提取核心修饰键进行 Command 判定
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard modifiers == .command else { return event }
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
