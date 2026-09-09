import Foundation

struct ExistingIDs: Equatable {
    var routines: Set<UUID>
    var todos: Set<UUID>
    var diaries: Set<UUID>
    var checks: Set<UUID>
    var projects: Set<UUID> = []
    var tags: Set<UUID> = []
    var attachments: Set<UUID> = []
}

struct ImportPreview: Equatable {
    var routinesNew: Int
    var routinesUpdate: Int
    var todosNew: Int
    var todosUpdate: Int
    var diariesNew: Int
    var diariesUpdate: Int
    var checksNew: Int
    var checksUpdate: Int
    var projectsNew: Int = 0
    var projectsUpdate: Int = 0
    var tagsNew: Int = 0
    var tagsUpdate: Int = 0
    var attachmentsNew: Int = 0
    var attachmentsUpdate: Int = 0

    var totalWrites: Int {
        routinesNew + routinesUpdate + todosNew + todosUpdate
            + diariesNew + diariesUpdate + checksNew + checksUpdate
            + projectsNew + projectsUpdate + tagsNew + tagsUpdate
            + attachmentsNew + attachmentsUpdate
    }

    var summary: String { summary(locale: .current) }

    func summary(locale: Locale) -> String {
        L10n.format(
            "import.summary",
            locale: locale,
            routinesNew,
            routinesUpdate,
            todosNew,
            todosUpdate,
            diariesNew,
            diariesUpdate,
            checksNew,
            checksUpdate,
            projectsNew,
            projectsUpdate,
            tagsNew,
            tagsUpdate,
            attachmentsNew,
            attachmentsUpdate
        )
    }
}

enum ImportPreviewing {
    static func preview(_ snapshot: ExportSnapshot, existing: ExistingIDs) -> ImportPreview {
        let routines = split(snapshot.routines.map(\.id), existing: existing.routines)
        let todos = split(snapshot.todos.map(\.id), existing: existing.todos)
        let diaries = split(snapshot.diaries.map(\.id), existing: existing.diaries)
        let checks = split(snapshot.checks.map(\.id), existing: existing.checks)
        let projects = split(snapshot.projects.map(\.id), existing: existing.projects)
        let tags = split(snapshot.tags.map(\.id), existing: existing.tags)
        let attachments = split(snapshot.attachments.map(\.id), existing: existing.attachments)
        return ImportPreview(
            routinesNew: routines.new,
            routinesUpdate: routines.update,
            todosNew: todos.new,
            todosUpdate: todos.update,
            diariesNew: diaries.new,
            diariesUpdate: diaries.update,
            checksNew: checks.new,
            checksUpdate: checks.update,
            projectsNew: projects.new,
            projectsUpdate: projects.update,
            tagsNew: tags.new,
            tagsUpdate: tags.update,
            attachmentsNew: attachments.new,
            attachmentsUpdate: attachments.update
        )
    }

    private static func split(_ ids: [UUID], existing: Set<UUID>) -> (new: Int, update: Int) {
        let incoming = Set(ids)
        return (incoming.subtracting(existing).count, incoming.intersection(existing).count)
    }
}
