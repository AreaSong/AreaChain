import AppKit

/// 只拥有原生排版网络，不持有独立可提交正文；默认仍为既有 TextKit 1。
@MainActor struct CommandTextSystem {
    let container: NSTextContainer
    private let storage: NSTextStorage
    private var content: NSTextContentStorage?

    func edit(_ replace: () -> Void) {
        if let content { content.performEditingTransaction(replace) }
        else { replace() }
    }

    func prepareCandidate(_ range: NSRange) {
        #if AREACHAIN_QA
        guard let content, let layout = content.textLayoutManagers.first,
              range.location != NSNotFound, range.location >= 0, range.length >= 0,
              range.location <= storage.length, range.length <= storage.length - range.location,
              let start = content.location(content.documentRange.location, offsetBy: range.location),
              let end = content.location(start, offsetBy: range.length),
              let textRange = NSTextRange(location: start, end: end) else { return }
        // TK2 的视口更新可能滞后于同一轮组词；候选请求必须同步布局实际字符，不能返回空锚点。
        CommandTextTiming.measure("candidateLayout") {
            layout.ensureLayout(for: textRange)
            layout.textViewportLayoutController.layoutViewport()
        }
        #endif
    }

    static func legacy() -> Self {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        let container = NSTextContainer(containerSize: NSSize(width: 400, height: CGFloat.greatestFiniteMagnitude))
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        return Self(container: container, storage: storage)
    }

    #if AREACHAIN_QA
    static func textKit2() -> Self {
        precondition(AppStartup.requireAllowed() == .testing)
        let content = NSTextContentStorage()
        let layout = NSTextLayoutManager()
        let container = NSTextContainer(size: NSSize(width: 400, height: CGFloat.greatestFiniteMagnitude))
        content.addTextLayoutManager(layout)
        layout.textContainer = container
        let storage = NSTextStorage()
        content.textStorage = storage
        return Self(container: container, storage: storage, content: content)
    }
    #endif
}
