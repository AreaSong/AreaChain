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
        AppWindows.diaryWindowsProvider = { DiaryWindows.shared.hostedWindows }

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

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        DiaryWindows.shared.confirmTermination(capture: .shared, context: Persistence.session.container.mainContext)
            ? .terminateNow : .terminateCancel
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
        // 手记小窗由 DiaryWindows 持有，避免 SwiftUI Scene 自动恢复出重复窗口。
        Settings {
            SettingsView()
                .appChrome()
        }
        .modelContainer(container)
    }
}
