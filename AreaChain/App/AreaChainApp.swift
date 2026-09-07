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
        Window("window.diary", id: "diary") {
            DiaryStandaloneView()
                .appChrome()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 420, height: 520)
        .modelContainer(container)

        Settings {
            SettingsView()
                .appChrome()
        }
        .modelContainer(container)
    }
}
