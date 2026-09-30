import AppKit
import SwiftData
import SwiftUI

enum SearchResultOrder {
    static func flat(_ hits: [BoardSearchHit]) -> [BoardSearchHit] {
        BoardSearch.grouped(hits).flatMap(\.items)
    }
}

enum SearchHitCommands {
    @MainActor
    static func complete(_ hit: BoardSearchHit, context: ModelContext) {
        switch hit.kind {
        case .diary:
            return
        case .todo:
            guard let todo = try? SwiftDataTaskRepository(context: context).fetchTodo(id: hit.id),
                  todo.deletedAt == nil else { return }
            _ = DayBoardMutations.toggleTodo(todo)
        case .subtask:
            let subtaskID = hit.id
            guard let subtask = try? context.fetch(
                FetchDescriptor<SubtaskItem>(predicate: #Predicate { $0.id == subtaskID })
            ).first, subtask.deletedAt == nil else { return }
            _ = DayBoardMutations.toggleSubtask(subtask)
        case .routine:
            guard let routine = try? SwiftDataRoutineRepository(context: context).fetchRoutine(id: hit.id),
                  routine.deletedAt == nil else { return }
            let checks = (try? SwiftDataRoutineRepository(context: context).fetchChecks(for: hit.id)) ?? []
            _ = DayBoardMutations.toggleRoutine(routine, on: hit.dayKey, checks: checks, context: context)
        }
    }
}

struct SearchResultKeys: ViewModifier {
    var hits: [BoardSearchHit]
    @Binding var index: Int?
    var onOpen: (BoardSearchHit) -> Void
    var onComplete: (BoardSearchHit) -> Void
    var onLeaveToField: () -> Void
    @State private var token: Any?
    @State private var hostWindow: NSWindow?
    @State private var sink = SearchKeySink()

    func body(content: Content) -> some View {
        let ordered = SearchResultOrder.flat(hits)
        sink.hits = ordered
        sink.index = $index
        sink.onOpen = onOpen
        sink.onComplete = onComplete
        sink.onLeaveToField = onLeaveToField
        return content
            .background(KeyWindowHost { hostWindow = $0 })
            .onChange(of: hits.map(\.id)) { _, _ in
                if let index, !ordered.indices.contains(index) { self.index = ordered.isEmpty ? nil : 0 }
            }
            .onAppear { install() }
            .onDisappear {
                BoardKeyMonitor.remove(token)
                token = nil
            }
    }

    private func install() {
        token = BoardKeyMonitor.install(existing: token) { event in
            guard hostWindow == nil || event.window === hostWindow else { return event }
            guard sink.index.wrappedValue != nil else { return event }
            if NSApp.keyWindow?.firstResponder is NSTextView { return event }
            switch event.keyCode {
            case ItemsListKey.arrowDown:
                sink.move(1)
            case ItemsListKey.arrowUp:
                sink.move(-1)
            case ItemsListKey.returnKey:
                if let hit = sink.current { sink.onOpen(hit) }
            case ItemsListKey.space:
                if let hit = sink.current { sink.onComplete(hit) }
            case ItemsListKey.escape:
                sink.index.wrappedValue = nil
            default:
                return event
            }
            return nil
        }
    }
}

private final class SearchKeySink {
    var hits: [BoardSearchHit] = []
    var index: Binding<Int?> = .constant(nil)
    var onOpen: (BoardSearchHit) -> Void = { _ in }
    var onComplete: (BoardSearchHit) -> Void = { _ in }
    var onLeaveToField: () -> Void = {}

    var current: BoardSearchHit? {
        guard let index = index.wrappedValue, hits.indices.contains(index) else { return nil }
        return hits[index]
    }

    func move(_ delta: Int) {
        guard !hits.isEmpty else {
            index.wrappedValue = nil
            return
        }
        let current = index.wrappedValue ?? 0
        if delta < 0, current == 0 {
            index.wrappedValue = nil
            onLeaveToField()
            return
        }
        let next = min(max(current + delta, 0), hits.count - 1)
        index.wrappedValue = next
    }
}
