import Foundation

extension CommandCatalogBuilder {
    static var structure: [CommandDescriptor] {
        [
            entry("catalog.root", "/", .group, ""),
            entry("group.taskBatch", "/tasks/batch", .group, ""),
            entry("group.routineChecks", "/routines/checks", .group, ""),
            entry("group.capture", "/capture", .group, ""),
            entry("group.setting", "/setting", .group, ""),
            entry("group.clipboardSettings", "/setting/clipboard", .group, ""),
            entry("group.notification", "/notification", .group, ""),
            entry("group.calendarSync", "/calendar-sync", .group, ""),
            entry("group.shortcut", "/shortcut", .group, ""),
            entry("group.privacy", "/privacy", .group, ""),
            entry("group.privacyMaintenance", "/privacy/maintenance", .group, ""),
            entry("group.data", "/data", .group, ""),
            entry("group.dataImport", "/data/import", .group, ""),
            entry("group.backup", "/backup", .group, ""),
            entry("group.recovery", "/recovery", .group, ""),
            entry("group.calendar", "/calendar", .group, ""),
            entry("group.quadrant", "/quadrant", .group, ""),
            entry("group.gantt", "/gantt", .group, ""),
            entry("group.go", "/go", .group, ""),
            entry("group.window", "/window", .group, ""),
            entry("group.workspaceWindow", "/window/workspace", .group, ""),
            entry("group.overlayWindow", "/window/overlay", .group, ""),
            entry("group.routinePanel", "/window/routines", .group, ""),
            entry("group.diaryWindow", "/window/diary", .group, ""),
            entry("group.clipboardWindow", "/window/clipboard", .group, ""),
            entry("group.inspector", "/inspector", .group, ""),
            entry("group.selection", "/selection", .group, ""),
            entry("group.stats", "/stats", .group, ""),
            entry("group.help", "/help", .group, ""),
            entry("group.support", "/support", .group, ""),
            entry("scope.tasks", "/tasks", .scope, "")
                .scope(.tasks),
            entry("scope.routines", "/routines", .scope, "")
                .scope(.routines),
            entry("scope.subtasks", "/subtasks", .scope, "")
                .scope(.subtasks),
            entry("scope.diaries", "/diaries", .scope, "")
                .scope(.diaries),
            entry("scope.tags", "/tags", .scope, "")
                .scope(.tags),
            entry("scope.images", "/images", .scope, "")
                .scope(.images),
            entry("scope.clipboard", "/clipboard", .scope, "")
                .scope(.clipboard),
            entry("scope.trash", "/trash", .scope, "")
                .scope(.trash),
        ]
    }
}
