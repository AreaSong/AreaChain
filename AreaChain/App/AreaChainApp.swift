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
        UserDefaults.standard.register(defaults: [
            "NSSplitViewItemSidebarDefaultsToFloatingAppearance": false
        ])
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
        AppWindows.clipboardWindowProvider = { ClipboardHistoryPanel.shared.hostedWindow.map { [$0] } ?? [] }

        StatusItemController.shared.popoverViewProvider = {
            AnyView(
                MenuBarPopoverView()
                    .appChrome()
                    .modelContainer(Persistence.session.container)
            )
        }

        FirstLaunchSeeder.seedIfNeeded(container: Persistence.session.container)
        StatusItemController.shared.attach(container: Persistence.session.container)
        ShortcutStore.shared.start()
        ClipboardHistorySession.shared.start()
        ClipboardHistoryPanel.shared.install()
        NotificationScheduler.shared.start()
        CompletionUndo.shared.install()
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
    private let container: ModelContainer

    init() {
        // 测试宿主也不初始化生产 Persistence 单例；业务夹具仍需显式注入自己的上下文。
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            do {
                container = try ModelContainer(for: Schema(AreaChainSchema.models),
                    configurations: ModelConfiguration(isStoredInMemoryOnly: true))
                container.mainContext.autosaveEnabled = false
            } catch {
                fatalError("无法打开测试宿主内存库")
            }
        } else {
            container = Persistence.session.container
            StoreHealth.shared.apply(Persistence.session)
        }
    }

    var body: some Scene {
        // SwiftUI App 必须有 Scene。Settings 场景会单独开窗并接走 ⌘,；
        // 这里只占一个不插入的菜单栏场景，设置改由应用菜单进入工作台。
        MenuBarExtra("AreaChain", isInserted: .constant(false)) {
            Color.clear
        }
        .modelContainer(container)
        .commands {
            AreaChainCommands()
        }
    }
}

private struct AreaChainCommands: Commands {
    @Bindable private var shortcuts = ShortcutStore.shared

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("window.settings") {
                AppWindows.openSettings()
            }
            .keyboardShortcut(shortcuts.keyboardShortcut(for: .openSettings))
        }
    }
}
