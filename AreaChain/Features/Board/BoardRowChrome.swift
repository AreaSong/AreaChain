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

    @ObservationIgnored private var rowHoverTask: Task<Void, Never>?
    @ObservationIgnored private var titleHoverTask: Task<Void, Never>?
    @ObservationIgnored private var noteHoverTask: Task<Void, Never>?
    @ObservationIgnored private var flagsMonitor: Any?

    func handleRowHover(_ hovering: Bool, reduceMotion: Bool) {
        rowHoverTask?.cancel()
        if hovering {
            rowHoverTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled else { return }
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    self.isRowHovered = true
                    self.isCommandPressed = NSEvent.modifierFlags.contains(.command)
                }
            }
        } else {
            rowHoverTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(80))
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
            }
        }
    }

    func revealRow(reduceMotion: Bool) {
        rowHoverTask?.cancel()
        withAnimation(DaybookMotion.interactive(reduceMotion)) {
            isRowHovered = true
        }
    }

    func handleTitleHover(_ hovering: Bool, reduceMotion: Bool) {
        scheduleBubble(
            hovering,
            reduceMotion: reduceMotion,
            task: &titleHoverTask,
            isActive: \.isTitleTextHovered,
            bubbleHeld: \.isTitleBubbleHovered
        )
    }

    func handleNoteHover(_ hovering: Bool, reduceMotion: Bool) {
        scheduleBubble(
            hovering,
            reduceMotion: reduceMotion,
            task: &noteHoverTask,
            isActive: \.isNoteHovered,
            bubbleHeld: \.isNoteBubbleHovered
        )
    }

    func startCommandMonitor(reduceMotion: Bool) {
        isCommandPressed = NSEvent.modifierFlags.contains(.command)
        guard flagsMonitor == nil else { return }
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let command = event.modifierFlags.contains(.command)
            MainActor.assumeIsolated {
                self?.applyCommand(command, reduceMotion: reduceMotion)
            }
            return event
        }
    }

    func stop() {
        if let flagsMonitor {
            NSEvent.removeMonitor(flagsMonitor)
            self.flagsMonitor = nil
        }
        rowHoverTask?.cancel()
        rowHoverTask = nil
        titleHoverTask?.cancel()
        titleHoverTask = nil
        noteHoverTask?.cancel()
        noteHoverTask = nil
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
                guard !Task.isCancelled else { return }
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
                }
            }
        }
    }
}
