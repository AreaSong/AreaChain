import AppKit
import Foundation

@MainActor
enum PrivateClipboard {
    static let marker = NSPasteboard.PasteboardType("com.areachain.private-copy")

    @discardableResult
    static func copy(_ text: String, sensitive: Bool, to board: NSPasteboard = .general) -> Bool {
        let item = NSPasteboardItem()
        guard item.setString(text, forType: .string) else { return false }
        let token = sensitive ? UUID().uuidString : nil
        if let token {
            guard item.setString(token, forType: marker),
                  item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")),
                  item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType")) else { return false }
        }
        // 正文与隐私标记一次发布，避免观察者先看见一份没有标记的明文。
        board.clearContents()
        guard board.writeObjects([item]) else { return false }
        guard let token else { return true }
        let changeCount = board.changeCount
        Task {
            try? await Task.sleep(for: .seconds(30))
            expire(board, token: token, changeCount: changeCount)
        }
        return true
    }

    static func expire(_ board: NSPasteboard, token: String, changeCount: Int) {
        guard board.changeCount == changeCount, board.string(forType: marker) == token else { return }
        board.clearContents()
    }
}
