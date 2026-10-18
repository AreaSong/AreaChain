import AppKit
import Foundation

/// 纯文本剪贴板写入的唯一可注入接口；只有写入成功才可显示“已复制”。
@MainActor protocol ClipboardTextWriting: AnyObject {
    func write(_ text: String) throws
}

enum ClipboardTextWriteError: Error, Equatable {
    case rejected
}

/// 生产实现沿任务行原有写法：清空后写一份 string；内容仍会被系统及已开启的剪贴板历史看到。
@MainActor final class SystemClipboardTextWriter: ClipboardTextWriting {
    static let shared = SystemClipboardTextWriter()
    private let board: NSPasteboard

    init(board: NSPasteboard = .general) {
        self.board = board
    }

    func write(_ text: String) throws {
        board.clearContents()
        guard board.setString(text, forType: .string) else { throw ClipboardTextWriteError.rejected }
    }
}
