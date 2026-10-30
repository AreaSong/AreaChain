import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 无备注证明改为适配自读备注取带键摘要，并按用户 2026-10-20 的决定放宽门槛。
/// 每个放宽的指令：带备注对象执行成功、预览后备注被改即拒绝；todo.title／subtask.title 仍拒绝带备注对象。
@Suite(.serialized) @MainActor struct NotesProofRelaxationTests {
    static let notes = "合成备注 #不解析 !p1"
    static let edited = "预览后改过的备注"

    // MARK: - 字段类 todo.move／priority／reminder／tags／due

    private static func field(_ kind: Int) -> (String, CommandArgument) {
        switch kind {
        case 0: return ("todo.move", TaskFieldCommandFixture.argument(0))
        case 1: return ("todo.priority", TaskFieldCommandFixture.argument(1))
        case 2: return ("todo.reminder", TaskFieldCommandFixture.argument(2))
        case 3: return ("todo.tags", TaskCompletionTagsDueFixture.tags(.remove, [TaskTitleFixture.liveID]))
        default: return ("todo.due", TaskCompletionTagsDueFixture.due(720))
        }
    }

    private func fieldFixture() throws -> TaskCompletionTagsDueFixture {
        let f = try TaskCompletionTagsDueFixture()
        f.base.todo.notes = Self.notes
        try f.context.save()
        return f
    }

    @Test(arguments: 0..<5) func fieldCommandsRunOnTodosWithNotes(kind: Int) throws {
        let f = try fieldFixture()
        let (command, argument) = Self.field(kind)
        let accepted = try f.accept(command, argument)
        #expect(accepted.preview.source.notes?.isPresent == true)
        #expect(try f.submit(accepted).state == .saved)
        #expect(try f.todo().notes == Self.notes && f.count("save") == 1)
    }

    @Test(arguments: 0..<5) func fieldNotesEditedAfterPreviewAreRejected(kind: Int) throws {
        let f = try fieldFixture()
        let (command, argument) = Self.field(kind)
        let accepted = try f.accept(command, argument)
        f.base.todo.notes = Self.edited
        try f.context.save()
        #expect(throws: (any Error).self) { try f.submit(accepted) }
        #expect(f.count("save") == 0 && f.base.todo.notes == Self.edited)
    }

    /// 完成与建标签未放宽，仍要求无备注。
    @Test func completionStillRequiresNoNotes() throws {
        let f = try fieldFixture()
        #expect(throws: TaskTitleCommandIssue.notesNotSupported) { try f.accept("todo.completion", TaskCompletionTagsDueFixture.completion(false)) }
        #expect(f.count("save") == 0)
    }

    // MARK: - 批量 batch.move／batch.tags

    @Test(arguments: [false, true]) func batchFieldsRunOnObjectsWithNotes(tags: Bool) throws {
        let f = try BatchCommandFixture()
        f.todos[1].notes = Self.notes
        f.routine.notes = Self.notes
        try f.context.save()
        if tags { try f.queue("batch.tags", argument: f.tagArgument(.add, index: 1), targets: f.mixedTargets) }
        else { try f.queue("batch.move") }
        let accepted = try f.accept()
        #expect(try f.submit(accepted).state == .saved)
        #expect(f.todos[1].notes == Self.notes && f.routine.notes == Self.notes)
    }

    @Test(arguments: [false, true]) func batchNotesEditedAfterPreviewAreRejected(tags: Bool) throws {
        let f = try BatchCommandFixture()
        f.todos[1].notes = Self.notes
        try f.context.save()
        if tags { try f.queue("batch.tags", argument: f.tagArgument(.add, index: 1), targets: f.mixedTargets) }
        else { try f.queue("batch.move") }
        let accepted = try f.accept()
        f.todos[1].notes = Self.edited
        try f.context.save()
        #expect(throws: (any Error).self) { try f.submit(accepted) }
        #expect(f.count("save") == 0)
    }

    @Test func batchStateCommandsStillRequireNoNotes() throws {
        let f = try BatchCommandFixture()
        f.todos[1].notes = Self.notes
        try f.context.save()
        try f.queue("batch.completion", argument: TaskCompletionTagsDueFixture.completion(true))
        #expect(throws: CommandBatchIssue.self) { try f.preview() }
    }

    // MARK: - 回收 todo.trash／routine.trash／batch.trash

    private static func trash(_ kind: Int, _ f: TrashCommandFixture) -> (String, [CommandObjectReference]) {
        switch kind {
        case 0: return ("todo.trash", [f.todoTarget])
        case 1: return ("routine.trash", [f.routineTarget])
        default: return ("batch.trash", f.base.mixedTargets)
        }
    }

    private func trashFixture() throws -> TrashCommandFixture {
        let f = try TrashCommandFixture()
        f.parent.notes = Self.notes
        f.base.routine.notes = Self.notes
        try f.context.save()
        return f
    }

    @Test(arguments: 0..<3) func trashRunsOnObjectsWithNotesAndCountsThem(kind: Int) throws {
        let f = try trashFixture()
        let (command, targets) = Self.trash(kind, f)
        try f.queue(command, targets: targets)
        let accepted = try f.accept()
        #expect(accepted.preview.counts.notes == (kind == 2 ? 2 : 1))
        let confirmation = try f.confirm(accepted)
        #expect(confirmation.counts.notes == accepted.preview.counts.notes)
        #expect(try f.submit(accepted, confirmation).state == .saved)
        #expect(kind == 1 || f.parent.deletedAt != nil)
        #expect(f.parent.notes == Self.notes && f.base.routine.notes == Self.notes)
    }

    @Test(arguments: 0..<3) func trashNotesEditedAfterPreviewAreRejected(kind: Int) throws {
        let f = try trashFixture()
        let (command, targets) = Self.trash(kind, f)
        try f.queue(command, targets: targets)
        let accepted = try f.accept()
        let confirmation = try f.confirm(accepted)
        if kind == 1 { f.base.routine.notes = Self.edited } else { f.parent.notes = Self.edited }
        try f.context.save()
        #expect(throws: (any Error).self) { try f.submit(accepted, confirmation) }
        #expect(f.count("save") == 0 && f.parent.deletedAt == nil && f.base.routine.deletedAt == nil)
    }

    // MARK: - 转换 todo.toRoutine／routine.toTodo

    @Test(arguments: [false, true]) func conversionCarriesNotesAndListsThem(back: Bool) throws {
        let f = try ConvertCommandFixture()
        if back { f.routine.notes = Self.notes } else { f.todo.notes = Self.notes }
        try f.context.save()
        let (accepted, facts) = try f.run(back ? "routine.toTodo" : "todo.toRoutine", target: back ? f.routineTarget : f.todoTarget)
        switch accepted.preview.impact.losses {
        case .todoToRoutine(let losses): #expect(losses.notes)
        case .routineToTodo(let losses): #expect(losses.notes)
        }
        #expect(facts.state == .saved)
        let created = facts.created
        let notes = back ? try f.todos(created.id).first?.notes : try f.routines(created.id).first?.notes
        #expect(notes == Self.notes)
    }

    @Test(arguments: [false, true]) func conversionNotesEditedAfterPreviewAreRejected(back: Bool) throws {
        let f = try ConvertCommandFixture()
        if back { f.routine.notes = Self.notes } else { f.todo.notes = Self.notes }
        try f.context.save()
        try f.queue(back ? "routine.toTodo" : "todo.toRoutine", target: back ? f.routineTarget : f.todoTarget)
        let accepted = try f.accept()
        let confirmation = try f.confirm(accepted)
        if back { f.routine.notes = Self.edited } else { f.todo.notes = Self.edited }
        try f.context.save()
        #expect(throws: (any Error).self) { try f.submit(accepted, confirmation) }
        #expect(f.count("save") == 0 && f.todo.deletedAt == nil && f.routine.deletedAt == nil)
    }

    // MARK: - 复制 todo.copy

    @Test func copyRunsOnTodoWithNotes() throws {
        let f = try TaskCopyCommandFixture(notes: Self.notes)
        try f.start(.notes)
        let preview = try f.preview()
        #expect(preview.source.notes.isPresent)
        _ = try f.submit(preview)
        #expect(f.writer.writes == [Self.notes])
    }

    @Test func copyNotesEditedAfterPreviewAreRejected() throws {
        let f = try TaskCopyCommandFixture(notes: Self.notes)
        try f.start(.record)
        let preview = try f.preview()
        f.todo.notes = Self.edited
        try f.io.context.save()
        #expect(throws: TaskCopyCommandIssue.changed) { try f.submit(preview) }
        #expect(f.writer.writes.isEmpty)
    }

    // MARK: - 不放宽：todo.title／subtask.title

    @Test func todoTitleStillRejectsTodosWithNotes() throws {
        let f = try TaskTitleCommandFixture()
        f.base.todo.notes = Self.notes
        try f.base.io.context.save()
        #expect(throws: TaskTitleCommandIssue.notesNotSupported) { try f.prepare() }
        #expect(f.base.io.trace.isEmpty)
    }

    @Test func subtaskTitleStillRejectsParentsWithNotes() throws {
        let f = try SubtaskCommandFixture()
        f.base.todo.notes = Self.notes
        try f.context.save()
        #expect(throws: TaskTitleCommandIssue.notesNotSupported) {
            try f.accept("subtask.title", [SubtaskCommandFixture.title("改名")])
        }
        #expect(f.count("save") == 0)
    }

    /// 摘要只用协调者内存密钥：同一备注在两个协调者下摘要不同，不能跨协调者复用或比较。
    @Test func digestIsKeyedPerCoordinator() throws {
        let first = CommandNotesProofReader.proof(Self.notes, key: CommandTextDigest())
        let second = CommandNotesProofReader.proof(Self.notes, key: CommandTextDigest())
        #expect(first.isPresent && second.isPresent && first != second)
        #expect(!String(describing: first).contains("合成"))
        #expect(CommandNotesProofReader.proof("  \n", key: CommandTextDigest()).isAbsent)
    }
}
