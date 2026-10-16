import AppKit
import SwiftData
import SwiftUI

@main
enum AreaChainEntry {
    @MainActor static func main() {
        AppStartup.requireAllowed()
        AreaChainApp.main()
    }
}

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
    var terminationPolicy = AppStartup.requireAllowed()
    var terminationLocale: () -> Locale = { AppPreferences.shared.resolvedLocale }
    private var isConfirmingTermination = false
    var presentQuitConfirmation: (NSAlert) -> NSApplication.ModalResponse = { alert in
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal()
    }
    var confirmDiaryTermination: () -> Bool = {
        DiaryWindows.shared.confirmTermination(composer: .shared, context: Persistence.session.container.mainContext)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard AppStartup.requireAllowed() == .application else { return }
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
        if CommandLine.arguments.contains("--open-workspace-shell-preview") {
            DispatchQueue.main.async {
                WorkspaceShellPreviewSettings.shared.isEnabled = true
                AppWindows.revealWorkspace()
                WorkspaceNavigation.shared.revealShellPreview()
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.scheme == "areachain" {
                AppWindows.revealWorkspace()
                let target = url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if target == "quadrant" {
                    WorkspaceNavigation.shared.revealTab(.quadrant)
                } else if target == "today" {
                    WorkspaceNavigation.shared.revealTab(.today)
                } else if target == "diary" {
                    WorkspaceNavigation.shared.revealTab(.diary)
                }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard terminationPolicy == .application else { return .terminateNow }
        // 模态框会运行嵌套事件循环，重复退出请求不能绕过确认或叠出新弹窗。
        guard !isConfirmingTermination else { return .terminateCancel }
        isConfirmingTermination = true
        defer { isConfirmingTermination = false }

        let alert = Self.quitAlert(locale: terminationLocale())
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

struct AreaChainApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container: ModelContainer

    init() {
        do {
            container = try AppStartup.requireAllowed().construct(application: {
                let session = Persistence.session
                StoreHealth.shared.apply(session)
                return session.container
            }, testing: { try AppStartup.memoryContainer() })
        } catch {
            fatalError("无法打开启动容器")
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
            if AppStartup.requireAllowed() == .application {
                AreaChainCommands()
            }
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
