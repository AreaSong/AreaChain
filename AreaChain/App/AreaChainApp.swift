import AppKit
import SwiftData
import SwiftUI

extension FirstLaunchSeeder {
    @MainActor
    static func seedIfNeeded(container: ModelContainer) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<DailyRoutine>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        seedIfNeeded(context: context, existingCount: count)
        try? context.save()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        AppPreferences.shared.applyAppAppearance()
        NSApp.setActivationPolicy(.accessory)

        AppWindows.workspaceViewProvider = {
            AnyView(
                MainSplitWorkspaceView()
                    .appChrome()
                    .modelContainer(Persistence.session.container)
            )
        }

        StatusItemController.shared.popoverViewProvider = {
            AnyView(
                MenuBarPopoverView()
                    .appChrome()
                    .modelContainer(Persistence.session.container)
            )
        }

        FirstLaunchSeeder.seedIfNeeded(container: Persistence.session.container)
        StatusItemController.shared.attach(container: Persistence.session.container)
        HotKeyCenter.shared.start()
        NotificationScheduler.shared.start()
        CalendarSync.start()
        AppWindows.hideStrayWindows()
        if Persistence.session.isFallback {
            MutationFeedback.shared.reportMemoryFallback()
        }
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
