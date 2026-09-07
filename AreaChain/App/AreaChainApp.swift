import AppKit
import SwiftData
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        StatusItemController.shared.attach(container: Persistence.session.container)
        HotKeyCenter.shared.start()
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
        Window("日记", id: "diary") {
            DiaryStandaloneView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 420, height: 520)
        .modelContainer(container)

        Settings {
            SettingsView()
        }
        .modelContainer(container)
    }
}
