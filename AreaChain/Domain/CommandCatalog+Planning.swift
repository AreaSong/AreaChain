import Foundation

extension CommandCatalogBuilder {
    static var planning: [CommandDescriptor] {
        [
            entry("calendar.mode", "/calendar/mode", .interaction, "B1:mode",
                  [choice(.mode, "month week")]),
            // 合并批 M-2：导航路径只接一个尾段参数；月／周跟随日历页当前视图，与页面的上一／下一按钮一致。
            entry("calendar.step", "/calendar/step", .navigation, "B1:previous B1:next",
                  [choice(.offset, "previous next")]),
            entry("calendar.today", "/calendar/today", .navigation, "B1:today"),
            entry("calendar.day", "/calendar/day", .navigation, "B1:selectDay",
                  [day]),
            entry("calendar.dayList", "/calendar/day-list", .navigation, "B1:dayList",
                  [day]),
            entry("calendar.create", "/calendar/add", .modification, "B1:create",
                  [title, day, notes.optional(), tags.optional(), reminder.optional(), priority.optional()])
                .ordinary(),
            entry("quadrant.day", "/quadrant/day", .navigation, "B2:day",
                  [day]),
            entry("quadrant.step", "/quadrant/step", .navigation, "B2:previous B2:next",
                  [choice(.offset, "previous next")]),
            entry("quadrant.create", "/quadrant/add", .modification, "B2:create",
                  [title, day, priority])
                .ordinary(),
            entry("quadrant.priority", "/quadrant/priority", .modification, "B2:priority",
                  [priority, day])
                .targets([.todo, .routine]).ordinary(),
            entry("quadrant.complete", "/quadrant/complete", .modification, "B2:complete")
                // 合并批 M-2：1A 等的是习惯 skip 语义（R-M3 D1 已定），转交 todo.completion／occurrence.complete 执行。
                .targets([.todo, .routineOccurrence]).ordinary(),
            entry("quadrant.inspect", "/quadrant/inspect", .navigation, "B2:inspect")
                .targets([.todo, .routineOccurrence]),
            entry("quadrant.copy", "/quadrant/copy", .systemAction, "B2:copy")
                .targets([.todo, .routine]).risk([.externalEffect]),
            entry("gantt.step", "/gantt/step", .navigation, "B3:previous B3:next",
                  [choice(.offset, "previous next")]),
            entry("gantt.currentMonth", "/gantt/current-month", .navigation, "B3:currentMonth"),
            entry("gantt.select", "/gantt/select", .interaction, "B3:single B3:multiple B3:range",
                  [choice(.mode, "single multiple range")])
                .targets([.todo], batch: .explicitMultiple),
            entry("gantt.shift", "/gantt/shift", .modification, "B3:shift",
                  [p(.offset, .number(-31...31, integer: true)), day])
                .targets([.todo], batch: .explicitMultiple).ordinary(),
            entry("gantt.complete", "/gantt/complete", .modification, "B3:complete")
                .targets([.todo], batch: .explicitMultiple).ordinary(),
            entry("gantt.inspect", "/gantt/inspect", .navigation, "B3:inspect")
                .targets([.todo]),
        ]
    }
}
