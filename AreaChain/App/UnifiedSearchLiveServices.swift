import AppKit
import SwiftData

/// 正式版统一搜索的真实依赖，只在 application 分支由 AppDelegate 交给 UnifiedSearchProduction。
/// 这里只构造闭包与引用共享单例；闭包里的系统调用（提醒授权、日历、粘贴、窗口）只在执行对应指令时才运行。
@MainActor enum UnifiedSearchLiveServices {
    static func make() -> UnifiedSearchProductionServices {
        let preferences = AppPreferences.shared
        return .init(context: Persistence.session.container.mainContext, center: .default, vault: .shared,
                     preferences: preferences, navigation: .shared, drafts: .shared, filters: .shared,
                     clipboard: .shared, clipboardStore: ClipboardHistoryStore(), shortcuts: .shared,
                     attachments: .shared, attachmentRoot: AttachmentStore.shared.directory(),
                     productionAttachments: true, today: { DayClock.shared.todayKey },
                     effects: effects(preferences))
    }

    private static func effects(_ preferences: AppPreferences) -> UnifiedSearchProductionEffects {
        .init(refresh: BoardEvents.Dependencies.production.requestRefresh,
              calendarSyncEnabled: { preferences.syncCalendarEvents },
              requestReminderAccess: { DayBoardMutations.requestReminderAccessIfNeeded($0) },
              refreshCalendar: { CalendarSync.refreshIfEnabled() },
              clipboardWriter: SystemClipboardTextWriter(),
              clipboardActions: {
                  ClipboardHistoryActions(session: .shared, window: ClipboardHistoryPanel.shared.window)
              },
              sourceBundleID: { CaptureStamp.current(enabled: preferences.stampCaptureApp) },
              revealWorkspace: { AppWindows.revealWorkspace() })
    }
}
