import AppKit
import SwiftData
import SwiftUI

extension FirstLaunchSeeder {
    @MainActor
    static func seedIfNeeded(container: ModelContainer, defaults: UserDefaults = .standard) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<DailyRoutine>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        seedIfNeeded(context: context, existingCount: count, defaults: defaults)
        try? context.save()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var isConfirmingTermination = false
    var presentQuitConfirmation: (NSAlert) -> NSApplication.ModalResponse = { alert in
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal()
    }
    var confirmDiaryTermination: () -> Bool = {
        DiaryWindows.shared.confirmTermination(composer: .shared, context: Persistence.session.container.mainContext)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        AppPreferences.shared.applyAppAppearance()
        PrivacyVault.shared.startLifecycle()
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
        // 模态框会运行嵌套事件循环，重复退出请求不能绕过确认或叠出新弹窗。
        guard !isConfirmingTermination else { return .terminateCancel }
        isConfirmingTermination = true
        defer { isConfirmingTermination = false }

        let alert = Self.quitAlert(locale: AppPreferences.shared.resolvedLocale)
        guard presentQuitConfirmation(alert) == .alertFirstButtonReturn else { return .terminateCancel }
        return confirmDiaryTermination() ? .terminateNow : .terminateCancel
    }

    static func quitAlert(locale: Locale) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.string("alert.quit.title", locale: locale)
        alert.informativeText = L10n.string("alert.quit.message", locale: locale)
        alert.addButton(withTitle: L10n.string("footer.quit", locale: locale))
        alert.addButton(withTitle: L10n.string("alert.cancel", locale: locale))
        alert.buttons[0].keyEquivalent = "\r"
        alert.buttons[1].keyEquivalent = "\u{1b}"
        return alert
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
