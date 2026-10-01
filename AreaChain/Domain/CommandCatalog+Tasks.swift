import Foundation

extension CommandCatalogBuilder {
    static var tasks: [CommandDescriptor] {
        [
            entry("todo.create", "/tasks/add", .modification, "T1:create",
                  [title, day, notes.optional(), tags.optional(), reminder.optional(), priority.optional()])
                .ordinary(),
            entry("todo.title", "/tasks/title", .modification, "T1:editTitle",
                  [title])
                .targets([.todo]).ordinary(),
            entry("todo.cancelTitle", "/tasks/cancel-title", .interaction, "T1:cancelTitle")
                .targets([.todo]),
            entry("todo.notes", "/tasks/notes", .modification, "T1:notes",
                  [notes])
                .targets([.todo], batch: .explicitMultiple).ordinary(),
            entry("todo.completion", "/tasks/completion", .modification, "T2:complete T2:reopen",
                  [p(.enabled, .boolean)])
                .targets([.todo], batch: .explicitMultiple).ordinary(),
            entry("todo.cancelCompletion", "/tasks/cancel-completion", .interaction, "T2:cancelCompletion")
                .targets([.todo]),
            entry("todo.move", "/tasks/move", .modification, "T2:move B1:move",
                  [day])
                .targets([.todo], batch: .explicitMultiple).ordinary(),
            entry("todo.reminder", "/tasks/reminder", .modification, "T2:reminder",
                  [reminder])
                .targets([.todo], batch: .explicitMultiple).ordinary(),
            entry("todo.priority", "/tasks/priority", .modification, "T2:priority",
                  [priority])
                .targets([.todo], batch: .explicitMultiple).ordinary(),
            entry("todo.tags", "/tasks/tags", .modification, "T2:tags",
                  [tags])
                .targets([.todo], batch: .explicitMultiple).ordinary(),
            entry("todo.createTag", "/tasks/create-tag", .modification, "T2:createTag",
                  [p(.name, .shortText)])
                .targets([.todo], batch: .explicitMultiple).ordinary(),
            entry("todo.due", "/tasks/due", .modification, "T2:due",
                  [p(.time, .time).editing([.assign, .clear], default: .assign)])
                .targets([.todo], batch: .explicitMultiple).ordinary(),
            entry("todo.copy", "/tasks/copy", .systemAction, "T3:copyRecord T3:copyTitle T3:copyNotes",
                  [choice(.section, "record title notes").defaulting(to: .choice("record"))])
                .targets([.todo]).risk([.externalEffect]),
            entry("todo.trash", "/tasks/trash", .modification, "T3:trash")
                .targets([.todo], batch: .explicitMultiple).ordinary().requiring([.independentConfirmation]),
            entry("subtask.create", "/subtasks/add", .modification, "T4:create",
                  [p(.parent, .object([.todo])), title, tags.optional()])
                .ordinary(),
            entry("subtask.completion", "/subtasks/completion", .modification, "T4:complete T4:reopen",
                  [p(.enabled, .boolean)])
                .targets([.subtask]).ordinary(),
            entry("subtask.title", "/subtasks/title", .modification, "T4:editTitle",
                  [title])
                .targets([.subtask]).ordinary(),
            entry("subtask.cancelTitle", "/subtasks/cancel-title", .interaction, "T4:cancelTitle")
                .targets([.subtask]),
            entry("subtask.tags", "/subtasks/tags", .modification, "T4:tags",
                  [tags])
                .targets([.subtask]).ordinary(),
            entry("subtask.order", "/subtasks/order", .modification, "T4:reorder",
                  [p(.parent, .object([.todo])), p(.position, .number(0...Double(Int.max), integer: true))])
                .targets([.subtask]).ordinary(),
            entry("subtask.delete", "/subtasks/delete", .modification, "T4:delete")
                .targets([.subtask]).ordinary().requiring([.independentConfirmation]),
            entry("routine.capture", "/routines/capture", .modification, "T5:capture",
                  [p(.body, .longText)])
                .ordinary(),
            entry("routine.create", "/routines/add", .modification, "T5:create",
                  [title, notes.optional(), p(.weekdays, .weekdays), reminder.optional(), priority.optional(), tags.optional()])
                .ordinary(),
            entry("routine.title", "/routines/title", .modification, "T5:title",
                  [title])
                .targets([.routine]).ordinary(),
            entry("routine.notes", "/routines/notes", .modification, "T5:notes",
                  [notes])
                .targets([.routine], batch: .explicitMultiple).ordinary(),
            entry("routine.weekdays", "/routines/weekdays", .modification, "T5:weekdays",
                  [p(.weekdays, .weekdays)])
                .targets([.routine]).ordinary(),
            entry("routine.reminder", "/routines/reminder", .modification, "T5:reminder",
                  [reminder])
                .targets([.routine], batch: .explicitMultiple).ordinary(),
            entry("routine.priority", "/routines/priority", .modification, "T5:priority",
                  [priority])
                .targets([.routine], batch: .explicitMultiple).ordinary(),
            entry("routine.tags", "/routines/tags", .modification, "T5:tags",
                  [tags])
                .targets([.routine], batch: .explicitMultiple).ordinary(),
            entry("routine.enabled", "/routines/enabled", .modification, "T5:enable T5:pause",
                  [p(.enabled, .boolean)])
                .targets([.routine], batch: .explicitMultiple).ordinary(),
            entry("routine.order", "/routines/order", .modification, "T5:reorder",
                  [p(.position, .number(0...Double(Int.max), integer: true))])
                .targets([.routine]).ordinary(),
            entry("routine.trash", "/routines/trash", .modification, "T5:delete")
                .targets([.routine], batch: .explicitMultiple).ordinary().requiring([.independentConfirmation]),
            entry("occurrence.complete", "/routines/checks/complete", .modification, "T6:complete")
                .targets([.routineOccurrence], batch: .explicitMultiple).unresolved("routineCompletion"),
            entry("occurrence.reopen", "/routines/checks/reopen", .modification, "T6:reopen")
                .targets([.routineOccurrence], batch: .explicitMultiple).ordinary(),
            entry("occurrence.skip", "/routines/checks/skip", .modification, "T6:skip")
                .targets([.routineOccurrence]).ordinary(),
            entry("occurrence.inspect", "/routines/checks/inspect", .navigation, "T6:inspectDate",
                  [day])
                .targets([.routine]),
            entry("routine.streak", "/routines/streak", .query, "T6:currentStreak T6:bestStreak",
                  [choice(.kind, "current best"), day])
                .targets([.routine]),
            entry("batch.move", "/tasks/batch/move", .modification, "T7:today T7:tomorrow",
                  [day])
                .targets([.todo], batch: .explicitMultiple).ordinary(),
            entry("batch.completion", "/tasks/batch/completion", .modification, "T7:complete T7:reopen",
                  [p(.enabled, .boolean)])
                .targets([.todo, .routineOccurrence], batch: .explicitMultiple).unresolved("routineCompletion"),
            entry("batch.tags", "/tasks/batch/tags", .modification, "T7:addTags T7:removeTags",
                  [p(.tags, .tags).editing([.add, .remove], default: .add)])
                .targets([.todo, .routine], batch: .explicitMultiple).ordinary(),
            entry("batch.enabled", "/tasks/batch/enabled", .modification, "T7:enable T7:disable",
                  [p(.enabled, .boolean)])
                .targets([.routine], batch: .explicitMultiple).ordinary(),
            entry("batch.trash", "/tasks/batch/trash", .modification, "T7:trash")
                .targets([.todo, .routine], batch: .explicitMultiple).ordinary().requiring([.independentConfirmation]),
            entry("todo.toRoutine", "/tasks/convert-to-routine", .modification, "T8:todoToRoutine")
                .targets([.todo]).ordinary().requiring([.independentConfirmation]),
            entry("routine.toTodo", "/routines/convert-to-task", .modification, "T8:routineToTodo")
                .targets([.routine]).ordinary().requiring([.independentConfirmation]),
            entry("tasks.sections", "/tasks/sections", .interaction, "T9:sections",
                  [choice(.section, "today yesterday upcoming"), p(.enabled, .boolean)]),
            entry("tasks.postponeYesterday", "/tasks/postpone-yesterday", .modification, "T9:postponeYesterday",
                  [day])
                .targets([.todo], batch: .explicitMultiple).ordinary(),
            entry("tasks.filter", "/tasks/filter", .query, "T9:filter",
                  [p(.tags, .tags).optional(), priority.optional(), p(.source, .shortText).optional(),
                   choice(.dateFilter, "all overdue upcoming").optional(),
                   choice(.reminderFilter, "all withReminder withoutReminder").optional()]),
            entry("tasks.clearFilter", "/tasks/clear-filter", .query, "T9:clearFilter"),
            entry("tasks.kind", "/tasks/kind", .query, "T9:itemKind",
                  [p(.kind, .choice(ItemKindScope.allCases.map { CommandChoice(value: $0.rawValue) }))]),
            entry("tasks.status", "/tasks/status", .query, "T9:itemStatus",
                  [p(.status, .choice(TodoStatusScope.allCases.map { CommandChoice(value: $0.rawValue) })).optional(),
                   p(.routineStatus, .choice(RoutineStatusScope.allCases.map { CommandChoice(value: $0.rawValue) })).optional()]),
            entry("tasks.select", "/tasks/select", .interaction, "T9:select")
                .targets([.todo, .routineOccurrence], batch: .explicitMultiple),
            entry("tasks.order", "/tasks/order", .modification, "T9:order",
                  [day])
                .targets([.todo, .routine], batch: .explicitMultiple).ordinary(),
            entry("capture.clipboard", "/capture/clipboard", .systemAction, "T10:capture")
                .risk([.externalEffect]),
        ]
    }
}
