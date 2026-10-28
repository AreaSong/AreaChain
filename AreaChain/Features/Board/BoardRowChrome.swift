import AppKit
import Observation
import SwiftUI

/// 任务行和手记行共用的悬停与 ⌘ 状态。延迟、气泡和修饰键监听只在这里实现。
@Observable
final class BoardRowChrome {
    var isRowHovered = false
    var isCommandPressed = false
    var isTitleTextHovered = false
    var isTitleBubbleHovered = false
    var isNoteHovered = false
    var isNoteBubbleHovered = false

    @ObservationIgnored var isTitlePointerInside = false
    @ObservationIgnored private var rowHoverTask: Task<Void, Never>?
    @ObservationIgnored private var titleHoverTask: Task<Void, Never>?
    @ObservationIgnored private var noteHoverTask: Task<Void, Never>?
    @ObservationIgnored private var flagsMonitor: Any?

    func handleRowHover(_ hovering: Bool, reduceMotion: Bool) {
        rowHoverTask?.cancel()
        rowHoverTask = nil
        BoardRowChrome.ensureScrollMonitoring()
        if hovering {
            guard !Self.isPointerInSyntaxOverlay() else { return }
            claimActive()
            guard !BoardRowChrome.isLiveScrolling else { return }
            rowHoverTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(70))
                guard !Task.isCancelled, !BoardRowChrome.isLiveScrolling, !Self.isPointerInSyntaxOverlay() else { return }
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    self.isRowHovered = true
                    self.isCommandPressed = NSEvent.modifierFlags.contains(.command)
                }
                self.startCommandMonitor(reduceMotion: reduceMotion)
            }
        } else {
            stopCommandMonitor()
            rowHoverTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(60))
                guard !Task.isCancelled else { return }
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    self.isRowHovered = false
                }
                self.titleHoverTask?.cancel()
                self.titleHoverTask = nil
                self.noteHoverTask?.cancel()
                self.noteHoverTask = nil
                if !self.isTitleBubbleHovered {
                    withAnimation(DaybookMotion.interactive(reduceMotion)) {
                        self.isTitleTextHovered = false
                    }
                }
                if !self.isNoteBubbleHovered {
                    withAnimation(DaybookMotion.interactive(reduceMotion)) {
                        self.isNoteHovered = false
                    }
                }
                self.cleanActiveIfIdle()
            }
        }
    }

    func revealRow(reduceMotion: Bool) {
        rowHoverTask?.cancel()
        rowHoverTask = nil
        withAnimation(DaybookMotion.interactive(reduceMotion)) {
            isRowHovered = true
        }
    }

    func handleTitleHover(_ hovering: Bool, reduceMotion: Bool) {
        if hovering {
            guard !Self.isPointerInSyntaxOverlay() else { return }
            claimActive()
        }
        scheduleBubble(
            hovering,
            reduceMotion: reduceMotion,
            task: &titleHoverTask,
            isActive: \.isTitleTextHovered,
            bubbleHeld: \.isTitleBubbleHovered
        )
    }

    func handleNoteHover(_ hovering: Bool, reduceMotion: Bool) {
        if hovering {
            guard !Self.isPointerInSyntaxOverlay() else { return }
            claimActive()
        }
        scheduleBubble(
            hovering,
            reduceMotion: reduceMotion,
            task: &noteHoverTask,
            isActive: \.isNoteHovered,
            bubbleHeld: \.isNoteBubbleHovered
        )
    }

    @ObservationIgnored static var isLiveScrolling = false
    @ObservationIgnored private static var scrollObserverTokens: [NSObjectProtocol] = []
    @ObservationIgnored private static var sharedFlagsMonitor: Any?
    @ObservationIgnored private static var activeSubscribers: NSHashTable<BoardRowChrome> = .weakObjects()
    @ObservationIgnored private static var activeReduceMotion = false
    @ObservationIgnored private static weak var currentActiveChrome: BoardRowChrome?

    private func claimActive() {
        if let current = Self.currentActiveChrome, current !== self {
            current.dismissBubblesImmediately()
        }
        Self.currentActiveChrome = self
    }

    static func dismissActiveBubbles() {
        currentActiveChrome?.dismissBubblesImmediately()
        currentActiveChrome = nil
    }

    static func isPointerInSyntaxOverlay() -> Bool {
        SyntaxOverlayEventView.containsScreenPoint(NSEvent.mouseLocation)
    }

    func dismissBubblesImmediately() {
        titleHoverTask?.cancel()
        titleHoverTask = nil
        noteHoverTask?.cancel()
        noteHoverTask = nil
        rowHoverTask?.cancel()
        rowHoverTask = nil
        isTitleTextHovered = false
        isTitleBubbleHovered = false
        isNoteHovered = false
        isNoteBubbleHovered = false
        isRowHovered = false
        isTitlePointerInside = false
    }

    private func cleanActiveIfIdle() {
        if !isRowHovered && !isTitleTextHovered && !isTitleBubbleHovered && !isNoteHovered && !isNoteBubbleHovered {
            if Self.currentActiveChrome === self {
                Self.currentActiveChrome = nil
            }
        }
    }

    static func ensureScrollMonitoring() {
        guard scrollObserverTokens.isEmpty else { return }
        let willStart = NotificationCenter.default.addObserver(
            forName: NSScrollView.willStartLiveScrollNotification,
            object: nil,
            queue: .main
        ) { _ in
            isLiveScrolling = true
            MainActor.assumeIsolated {
                for chrome in activeSubscribers.allObjects {
                    chrome.cancelHoverForScroll()
                }
            }
        }
        let didEnd = NotificationCenter.default.addObserver(
            forName: NSScrollView.didEndLiveScrollNotification,
            object: nil,
            queue: .main
        ) { _ in
            isLiveScrolling = false
        }
        scrollObserverTokens = [willStart, didEnd]
    }

    func cancelHoverForScroll() {
        rowHoverTask?.cancel()
        rowHoverTask = nil
        titleHoverTask?.cancel()
        titleHoverTask = nil
        noteHoverTask?.cancel()
        noteHoverTask = nil
        stopCommandMonitor()
        if isRowHovered { isRowHovered = false }
        if isTitleTextHovered { isTitleTextHovered = false }
        if isNoteHovered { isNoteHovered = false }
    }

    func startCommandMonitor(reduceMotion: Bool) {
        isCommandPressed = NSEvent.modifierFlags.contains(.command)
        BoardRowChrome.activeReduceMotion = reduceMotion
        BoardRowChrome.activeSubscribers.add(self)
        guard BoardRowChrome.sharedFlagsMonitor == nil else { return }
        BoardRowChrome.sharedFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            let command = event.modifierFlags.contains(.command)
            MainActor.assumeIsolated {
                for chrome in BoardRowChrome.activeSubscribers.allObjects {
                    chrome.applyCommand(command, reduceMotion: BoardRowChrome.activeReduceMotion)
                }
            }
            return event
        }
    }

    func stopCommandMonitor() {
        BoardRowChrome.activeSubscribers.remove(self)
        if BoardRowChrome.activeSubscribers.allObjects.isEmpty, let monitor = BoardRowChrome.sharedFlagsMonitor {
            NSEvent.removeMonitor(monitor)
            BoardRowChrome.sharedFlagsMonitor = nil
        }
    }

    func stop() {
        if Self.currentActiveChrome === self {
            Self.currentActiveChrome = nil
        }
        stopCommandMonitor()
        rowHoverTask?.cancel()
        rowHoverTask = nil
        titleHoverTask?.cancel()
        titleHoverTask = nil
        noteHoverTask?.cancel()
        noteHoverTask = nil
    }

    /// 手记可见标题失效时撤销迟到任务；不改变其他行和备注的退出政策。
    func resetTitleHover() {
        titleHoverTask?.cancel()
        titleHoverTask = nil
        isTitleTextHovered = false
        isTitleBubbleHovered = false
        cleanActiveIfIdle()
    }

    func resignCommand() {
        isCommandPressed = false
    }

    private func applyCommand(_ command: Bool, reduceMotion: Bool) {
        if command {
            titleHoverTask?.cancel()
            noteHoverTask?.cancel()
        }
        if isCommandPressed != command {
            withAnimation(DaybookMotion.interactive(reduceMotion)) {
                isCommandPressed = command
            }
        }
    }

    private func scheduleBubble(
        _ hovering: Bool,
        reduceMotion: Bool,
        task: inout Task<Void, Never>?,
        isActive: ReferenceWritableKeyPath<BoardRowChrome, Bool>,
        bubbleHeld: ReferenceWritableKeyPath<BoardRowChrome, Bool>
    ) {
        task?.cancel()
        guard !isCommandPressed else { return }
        if hovering {
            task = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled, !Self.isPointerInSyntaxOverlay() else { return }
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    self[keyPath: isActive] = true
                }
            }
        } else {
            task = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                if !self[keyPath: bubbleHeld] {
                    withAnimation(DaybookMotion.interactive(reduceMotion)) {
                        self[keyPath: isActive] = false
                    }
                    self.cleanActiveIfIdle()
                }
            }
        }
    }
}
