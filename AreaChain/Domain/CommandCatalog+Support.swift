import Foundation

extension CommandCatalogBuilder {
    static var support: [CommandDescriptor] {
        [
            entry("stats.today", "/stats/today", .query, "N5:today",
                  [day]),
            entry("stats.pending", "/stats/pending", .query, "N5:pending",
                  [day]),
            entry("stats.streaks", "/stats/streaks", .query, "N5:streaks",
                  [day]),
            entry("stats.routines", "/stats/routines", .query, "N5:routines",
                  [day]),
            entry("stats.diaries", "/stats/diaries", .query, "N5:diaries",
                  [day]),
            entry("stats.trend", "/stats/trend", .query, "N5:trend",
                  [day]),
            entry("stats.heatmap", "/stats/heatmap", .query, "N5:heatmap",
                  [day]),
            entry("stats.activity", "/stats/activity", .query, "N5:activity",
                  [day]),
            entry("stats.openDay", "/stats/open-day", .navigation, "N5:openDay",
                  [day]),
            entry("stats.openActivity", "/stats/open-activity", .navigation, "N5:openActivity")
                .targets([.activity]),
            entry("help.syntax", "/help/syntax", .query, "N6:syntax"),
            entry("help.page", "/help/page", .query, "N6:page"),
            entry("help.example", "/help/example", .interaction, "N6:example",
                  [p(.example, .shortText)])
                .requiring([.unsavedChangesConfirmation]),
            entry("support.version", "/support/version", .query, "N7:version"),
            entry("support.about", "/support/about", .query, "N7:about"),
            entry("support.discussion", "/support/discussion", .systemAction, "N7:discussion")
                .requiring([.externalApplication]),
            entry("support.suggestion", "/support/suggestion", .systemAction, "N7:suggestion")
                .requiring([.externalApplication]),
            entry("support.issue", "/support/issue", .systemAction, "N7:issue")
                .requiring([.externalApplication]).risk([.externalEffect]),
            entry("support.repository", "/support/repository", .systemAction, "N7:repository")
                .requiring([.externalApplication]),
            entry("support.license", "/support/license", .systemAction, "N7:license")
                .requiring([.externalApplication]),
            entry("app.quit", "/quit", .systemAction, "N8:quit")
                .requiring([.unsavedChangesConfirmation]).risk([.lifecycle]),
        ]
    }
}
