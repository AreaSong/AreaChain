import Foundation

extension CommandCatalogBuilder {
    static var navigation: [CommandDescriptor] {
        [
            entry("go.dashboard", "/go/dashboard", .navigation, "N1:dashboard"),
            entry("go.today", "/go/today", .navigation, "N1:today"),
            entry("go.pending", "/go/pending", .navigation, "N1:pending"),
            entry("go.allItems", "/go/all-items", .navigation, "N1:allItems"),
            entry("go.calendar", "/go/calendar", .navigation, "N1:calendar"),
            entry("go.quadrant", "/go/quadrant", .navigation, "N1:quadrant"),
            entry("go.gantt", "/go/gantt", .navigation, "N1:gantt"),
            entry("go.diaries", "/go/diaries", .navigation, "N1:diaries"),
            entry("go.images", "/go/images", .navigation, "N1:images"),
            entry("go.clipboard", "/go/clipboard", .navigation, "N1:clipboard"),
            entry("go.tags", "/go/tags", .navigation, "N1:tags"),
            entry("go.privacy", "/go/privacy", .navigation, "N1:privacy"),
            entry("go.backup", "/go/backup", .navigation, "N1:backup"),
            entry("go.trash", "/go/trash", .navigation, "N1:trash"),
            entry("go.settings", "/go/settings", .navigation, "N1:settings"),
            entry("go.shortcuts", "/go/shortcuts", .navigation, "N1:shortcuts"),
            entry("go.tagList", "/go/tag", .navigation, "N1:tagList")
                .targets([.tag]),
            entry("workspace.open", "/window/workspace/open", .navigation, "N2:openWorkspace"),
            entry("workspace.reveal", "/window/workspace/reveal", .navigation, "N2:revealWorkspace"),
            entry("workspace.close", "/window/workspace/close", .navigation, "N2:closeWorkspace")
                .requiring([.unsavedChangesConfirmation]),
            entry("overlay.toggle", "/window/overlay/toggle", .navigation, "N2:toggleOverlay"),
            entry("overlay.mode", "/window/overlay/mode", .navigation, "N2:overlayTasks N2:overlayDiaries",
                  [choice(.mode, "tasks diaries")]),
            entry("routine.addPanel", "/window/routines/add", .navigation, "N2:addRoutine"),
            entry("routine.managePanel", "/window/routines/manage", .navigation, "N2:manageRoutines"),
            entry("inspector.open", "/inspector/open", .navigation, "N3:open N3:selectObject")
                .targets([.todo, .subtask, .routineOccurrence]),
            entry("inspector.day", "/inspector/day", .navigation, "N3:selectDate",
                  [day]),
            entry("inspector.close", "/inspector/close", .navigation, "N3:close")
                .requiring([.unsavedChangesConfirmation]),
            entry("selection.all", "/selection/all", .interaction, "N3:selectAll"),
            entry("selection.clear", "/selection/clear", .interaction, "N3:clearSelection T7:clearSelection"),
            entry("diaryWindow.open", "/window/diary/open", .navigation, "N4:open")
                .targets([.diary]).requiring([.authentication]),
            entry("diaryWindow.draft", "/window/diary/draft", .navigation, "N4:draft")
                .targets([.draft]),
            entry("diaryWindow.pinned", "/window/diary/pinned", .systemAction, "N4:pin N4:unpin",
                  [p(.enabled, .boolean)])
                .targets([.diaryWindow]),
            entry("diaryWindow.save", "/window/diary/save", .interaction, "N4:save")
                .targets([.diaryWindow]).requiring([.authentication]),
            entry("diaryWindow.close", "/window/diary/close", .navigation, "N4:close")
                .targets([.diaryWindow]).requiring([.unsavedChangesConfirmation]),
        ]
    }
}
