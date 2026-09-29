import AppKit
import Foundation

/// 轮询系统剪贴板。macOS 没有公开的剪贴板变更通知，间隔由历史设置决定。
@MainActor
final class ClipboardHistoryMonitor {
    private let pasteboard: NSPasteboard
    private let interval: () -> TimeInterval
    private let onChange: () -> Void
    private var timer: Timer?
    private var changeCount: Int

    init(pasteboard: NSPasteboard, interval: @escaping () -> TimeInterval, onChange: @escaping () -> Void) {
        self.pasteboard = pasteboard
        self.interval = interval
        self.onChange = onChange
        changeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else { return }
        changeCount = pasteboard.changeCount
        schedule()
    }

    func reschedule() {
        timer?.invalidate()
        timer = nil
        schedule()
    }

    /// 自己写回剪贴板后同步计数，避免下一轮把刚复制的历史又收进来。
    func acknowledge(_ count: Int) {
        changeCount = count
    }

    private func schedule() {
        let timer = Timer(timeInterval: interval(), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.poll()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func poll() {
        let count = pasteboard.changeCount
        guard count != changeCount else { return }
        changeCount = count
        onChange()
    }
}

enum ClipboardPasteboardReader {
    static func draft(
        from board: NSPasteboard,
        now: Date = .now,
        frontBundle: String?
    ) -> ClipboardHistoryDraft {
        let types = Set((board.types ?? []).map(\.rawValue))
        var plain = board.string(forType: .string) ?? ""
        var filePaths: [String] = []
        if let urls = board.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            filePaths = urls.filter(\.isFileURL).map(\.path)
            if plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                plain = urls.map(\.path).joined(separator: "\n")
            }
        }
        let html = board.string(forType: .html)
        let rtf = board.data(forType: .rtf)
        let png = ImageBytes.pasteboardImage(board).flatMap(ImageBytes.png(from:))
        return ClipboardHistoryDraft(
            plainText: plain,
            html: html,
            rtf: rtf,
            png: png,
            filePaths: filePaths,
            types: types,
            sourceBundleID: frontBundle ?? "",
            copiedAt: now
        )
    }
}

enum ClipboardHistoryWriter {
    static let marker = NSPasteboard.PasteboardType(ClipboardHistoryRules.markerType)

    @discardableResult
    static func write(
        _ record: ClipboardHistoryRecord,
        image: Data?,
        plainOnly: Bool,
        to board: NSPasteboard
    ) -> Bool {
        board.clearContents()
        let paths = plainOnly ? [] : record.filePaths.filter { !$0.isEmpty }
        if !paths.isEmpty {
            let urls = paths.map { URL(fileURLWithPath: $0) as NSURL }
            guard board.writeObjects(urls) else { return false }
            if board.addTypes([marker], owner: nil) > 0 {
                board.setData(Data(), forType: marker)
            }
            let text = record.plainText
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                board.setString(text, forType: .string)
            }
            return board.data(forType: marker) != nil
        }
        let item = NSPasteboardItem()
        item.setData(Data(), forType: marker)
        let text = record.plainText
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        var wroteImage = false
        if hasText {
            item.setString(text, forType: .string)
        }
        if !plainOnly {
            if let html = record.html, !html.isEmpty {
                item.setString(html, forType: .html)
            }
            if let rtf = record.rtf, !rtf.isEmpty {
                item.setData(rtf, forType: .rtf)
            }
            if let image, !image.isEmpty {
                item.setData(image, forType: .png)
                wroteImage = true
            }
        } else if !hasText, let image, !image.isEmpty {
            item.setData(image, forType: .png)
            wroteImage = true
        }
        guard hasText || wroteImage else { return false }
        return board.writeObjects([item])
    }
}

/// 自动粘贴需要辅助功能。只有用户明确要求粘贴时才询问，启动时不申请。
struct ClipboardHistoryPasteGate {
    var isTrusted: () -> Bool
    var prompt: () -> Void
    var sendCommandV: () -> Void

    static let live = ClipboardHistoryPasteGate(
        isTrusted: { AXIsProcessTrusted() },
        prompt: {
            let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            let options = [key: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        },
        sendCommandV: {
            let source = CGEventSource(stateID: .hidSystemState)
            let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(ShortcutKey.v), keyDown: true)
            let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(ShortcutKey.v), keyDown: false)
            down?.flags = .maskCommand
            up?.flags = .maskCommand
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    )
}
