import Foundation

extension CommandCatalogBuilder {
    static var settings: [CommandDescriptor] {
        [
            entry("setting.language", "/setting/language", .modification, "S1:language",
                  [choice(.value, "system chinese english")])
                .ordinary(),
            entry("setting.appearance", "/setting/appearance", .modification, "S1:appearance",
                  [choice(.value, "system light dark")])
                .ordinary(),
            entry("setting.truncation", "/setting/title-truncation", .modification, "S1:truncation",
                  [choice(.value, "tail middle")])
                .ordinary(),
            entry("setting.captureSource", "/setting/capture-source", .modification, "S1:captureSource",
                  [p(.enabled, .boolean)])
                .ordinary(),
            entry("setting.login", "/setting/login", .systemAction, "S2:enable S2:disable",
                  [p(.enabled, .boolean)])
                .requiring([.systemPermission]),
            entry("setting.loginSettings", "/setting/login-settings", .systemAction, "S2:systemSettings")
                .requiring([.externalApplication]),
            entry("notification.status", "/notification/status", .query, "S3:status"),
            entry("notification.request", "/notification/request", .systemAction, "S3:request")
                .requiring([.systemPermission]),
            entry("notification.test", "/notification/test", .systemAction, "S3:test")
                .risk([.externalEffect]),
            entry("notification.settings", "/notification/system-settings", .systemAction, "S3:systemSettings")
                .requiring([.externalApplication]),
            entry("notification.complete", "/notification/complete", .systemAction, "S4:complete")
                .targets([.todo, .routineOccurrence]).unresolved("routineCompletion"),
            entry("notification.snooze", "/notification/snooze", .systemAction, "S4:snooze10 S4:snooze60",
                  [choice(.duration, "tenMinutes oneHour")])
                .targets([.todo, .routineOccurrence]).risk([.externalEffect]),
            entry("notification.open", "/notification/open", .navigation, "S4:open")
                .targets([.todo, .routineOccurrence]),
            entry("calendarSync.enabled", "/calendar-sync/enabled", .systemAction, "S5:enable S5:disable",
                  [p(.enabled, .boolean)])
                .requiring([.systemPermission]).risk([.externalEffect]),
            entry("calendarSync.status", "/calendar-sync/status", .query, "S5:status"),
            entry("calendarSync.retry", "/calendar-sync/retry", .systemAction, "S5:retry")
                .risk([.externalEffect]),
            entry("calendarSync.settings", "/calendar-sync/system-settings", .systemAction, "S5:systemSettings")
                .requiring([.externalApplication]),
            entry("calendarSync.conflicts", "/calendar-sync/conflicts", .query, "S5:conflicts"),
            entry("calendarSync.openLocal", "/calendar-sync/open-local", .navigation, "S5:openLocal")
                .targets([.calendarConflict]),
            entry("setting.icloud", "/setting/icloud", .query, "S6:status"),
            entry("shortcut.record", "/shortcut/record", .systemAction, "S7:record",
                  [p(.shortcut, .choice(ShortcutAction.allCases.map { CommandChoice(value: $0.rawValue) })), p(.chord, .nativeShortcut)])
                .requiring([.nativeShortcutRecorder]),
            entry("shortcut.reset", "/shortcut/reset", .systemAction, "S7:reset",
                  [p(.shortcut, .choice(ShortcutAction.allCases.map { CommandChoice(value: $0.rawValue) }))])
                .requiring([.independentConfirmation]),
            entry("shortcut.resetAll", "/shortcut/reset-all", .systemAction, "S7:resetAll")
                .requiring([.independentConfirmation]),
            entry("shortcut.cancel", "/shortcut/cancel", .interaction, "S7:cancel"),
        ]
    }
}
