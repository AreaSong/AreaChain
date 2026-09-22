import AppKit

/// 清单页共用的本地按键监视安装。各页仍自己决定哪些键生效。
enum BoardKeyMonitor {
    static func install(existing: Any?, handler: @escaping (NSEvent) -> NSEvent?) -> Any? {
        if existing != nil { return existing }
        return NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: handler)
    }

    static func remove(_ token: Any?) {
        if let token { NSEvent.removeMonitor(token) }
    }
}
