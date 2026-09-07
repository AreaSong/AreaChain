import Foundation

struct ExistingIDs: Equatable {
    var routines: Set<UUID>
    var todos: Set<UUID>
    var diaries: Set<UUID>
    var checks: Set<UUID>
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

    var totalWrites: Int {
        routinesNew + routinesUpdate + todosNew + todosUpdate
            + diariesNew + diariesUpdate + checksNew + checksUpdate
    }

    var summary: String {
        """
        例行 新增 \(routinesNew) / 覆盖 \(routinesUpdate)
        待办 新增 \(todosNew) / 覆盖 \(todosUpdate)
        日记 新增 \(diariesNew) / 覆盖 \(diariesUpdate)
        勾选 新增 \(checksNew) / 覆盖 \(checksUpdate)
        确定后才会写入本机。
        """
    }
}

enum ImportPreviewing {
    static func preview(_ snapshot: ExportSnapshot, existing: ExistingIDs) -> ImportPreview {
        let routines = split(snapshot.routines.map(\.id), existing: existing.routines)
        let todos = split(snapshot.todos.map(\.id), existing: existing.todos)
        let diaries = split(snapshot.diaries.map(\.id), existing: existing.diaries)
        let checks = split(snapshot.checks.map(\.id), existing: existing.checks)
        return ImportPreview(
            routinesNew: routines.new,
            routinesUpdate: routines.update,
            todosNew: todos.new,
            todosUpdate: todos.update,
            diariesNew: diaries.new,
            diariesUpdate: diaries.update,
            checksNew: checks.new,
            checksUpdate: checks.update
        )
    }

    private static func split(_ ids: [UUID], existing: Set<UUID>) -> (new: Int, update: Int) {
        let incoming = Set(ids)
        return (incoming.subtracting(existing).count, incoming.intersection(existing).count)
    }
}
