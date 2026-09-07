import AppKit
import SwiftData
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        AppPreferences.shared.applyAppAppearance()
        NSApp.setActivationPolicy(.accessory)
        StatusItemController.shared.attach(container: Persistence.session.container)
        HotKeyCenter.shared.start()
        NotificationScheduler.shared.start()
        AppWindows.hideStrayWindows()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct AreaChainApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container = Persistence.session.container

    init() {
        StoreHealth.shared.apply(Persistence.session)
    }

    var body: some Scene {
        // 日记只走 AppWindows。这里若再声明 Window，关设置时系统会把它当下一扇窗打开。
        Settings {
            SettingsView()
                .appChrome()
        }
        .modelContainer(container)
    }
}
