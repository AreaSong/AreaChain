import AppKit
import SwiftUI

/// 撤销成功后告诉用户这条事项回到了哪种完成状态。标题是用户正文，不另作翻译。
enum CompletionUndoNotice: Equatable {
    case reopenedTodo(title: String, subtasks: Int)
    case recompletedTodo(title: String)
    case reopenedRoutine(title: String)
    case restoredRoutine(title: String)
    case reopenedSubtask(title: String)
    case recompletedSubtask(title: String)

    func text(locale: Locale) -> String {
        switch self {
        case .reopenedTodo(let title, let subtasks) where subtasks > 0:
            L10n.format("undo.todo.reopened.subtasks", locale: locale, title, subtasks)
        case .reopenedTodo(let title, _):
            L10n.format("undo.todo.reopened", locale: locale, title)
        case .recompletedTodo(let title):
            L10n.format("undo.todo.recompleted", locale: locale, title)
        case .reopenedRoutine(let title):
            L10n.format("undo.routine.reopened", locale: locale, title)
        case .restoredRoutine(let title):
            L10n.format("undo.routine.restored", locale: locale, title)
        case .reopenedSubtask(let title):
            L10n.format("undo.subtask.reopened", locale: locale, title)
        case .recompletedSubtask(let title):
            L10n.format("undo.subtask.recompleted", locale: locale, title)
        }
    }
}

/// 贴在当前窗口底部的短提示。不用模态框，避免下一次 ⌘Z 被确认按钮吃掉。
@MainActor
final class CompletionUndoToast {
    static let shared = CompletionUndoToast()

    private var panel: NSPanel?
    private var host: NSHostingView<CompletionUndoBanner>?
    private var parent: NSWindow?
    private var hideItem: DispatchWorkItem?
    private var observers: [NSObjectProtocol] = []
    private var generation = 0

    func show(_ text: String) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        guard let window = NSApp.keyWindow else { return }
        generation += 1
        announce(text, on: window)
        close()
        install(on: window, text: text)
        reveal()
        scheduleHide()
    }

    private func install(on window: NSWindow, text: String) {
        let host = NSHostingView(rootView: CompletionUndoBanner(text: text))
        host.sizingOptions = .intrinsicContentSize
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = true
        panel.level = window.level
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = host
        window.addChildWindow(panel, ordered: .above)
        self.panel = panel
        self.host = host
        self.parent = window
        observe(window)
        place(text)
    }

    private func place(_ text: String) {
        guard let panel, let parent, let host else { return }
        let maxWidth = min(420, max(160, parent.frame.width - 48))
        host.frame.size.width = maxWidth
        host.layoutSubtreeIfNeeded()
        var size = host.fittingSize
        if size.height < 24 {
            size = fallbackSize(text, maxWidth: maxWidth)
        }
        size.width = min(maxWidth, max(size.width, 120))
        let frame = NSRect(
            x: parent.frame.midX - size.width / 2,
            y: parent.frame.minY + 28,
            width: size.width,
            height: max(size.height, 36)
        )
        panel.setFrame(frame, display: true)
    }

    private func fallbackSize(_ text: String, maxWidth: CGFloat) -> NSSize {
        let font = NSFont.systemFont(ofSize: DaybookType.bodySize)
        let bounds = (text as NSString).boundingRect(
            with: NSSize(width: maxWidth - 28, height: 80),
            options: [.usesLineFragmentOrigin],
            attributes: [.font: font]
        )
        return NSSize(width: min(maxWidth, bounds.width + 28), height: bounds.height + 28)
    }

    private func reveal() {
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panel?.alphaValue = reduce ? 1 : 0
        guard !reduce else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            panel?.animator().alphaValue = 1
        }
    }

    private func scheduleHide() {
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let item = DispatchWorkItem { [weak self] in self?.dismiss(animated: !reduce) }
        hideItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: item)
    }

    private func dismiss(animated: Bool) {
        let token = generation
        guard let panel else { return }
        let finish = { [weak self] in
            guard let self, token == self.generation else { return }
            self.close()
        }
        guard animated else { finish(); return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 0
        } completionHandler: {
            finish()
        }
    }

    private func close() {
        hideItem?.cancel()
        hideItem = nil
        if let panel, let parent { parent.removeChildWindow(panel) }
        panel?.orderOut(nil)
        panel = nil
        host = nil
        parent = nil
        let center = NotificationCenter.default
        observers.forEach { center.removeObserver($0) }
        observers.removeAll()
    }

    private func observe(_ window: NSWindow) {
        observers.append(Self.watch(window, NSWindow.didResizeNotification) { toast in
            guard let text = toast.host?.rootView.text else { return }
            toast.place(text)
        })
        observers.append(Self.watch(window, NSWindow.willCloseNotification) { toast in
            toast.close()
        })
    }

    /// 通知回调不在 MainActor 上。先跳回主隔离域再碰窗口，避免把隔离状态带进 Sendable 闭包。
    private nonisolated static func watch(
        _ window: NSWindow,
        _ name: Notification.Name,
        _ body: @escaping @MainActor (CompletionUndoToast) -> Void
    ) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { _ in
            Task { @MainActor in body(CompletionUndoToast.shared) }
        }
    }

    private func announce(_ text: String, on window: NSWindow) {
        NSAccessibility.post(
            element: window,
            notification: .announcementRequested,
            userInfo: [
                .announcement: text,
                .priority: NSAccessibilityPriorityLevel.high
            ]
        )
    }
}

private struct CompletionUndoBanner: View {
    var text: String

    var body: some View {
        Text(text)
            .font(DaybookType.body)
            .foregroundStyle(DaybookPalette.text.primary)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 420)
            .daybookSurface(.banner)
            .daybookElevation(.floating)
            .accessibilityHidden(true)
    }
}
