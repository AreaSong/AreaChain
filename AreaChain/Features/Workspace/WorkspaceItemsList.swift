import AppKit
import SwiftData
import SwiftUI

enum WorkspaceItemEntry: Identifiable {
    case todo(TodoItem, checkDayKey: String, subtaskIDs: Set<UUID>?)
    case routine(
        DailyRoutine,
        checkDayKey: String,
        allowsCompletion: Bool,
        overdueCount: Int,
        noteDayKey: String?
    )

    var id: String {
        switch self {
        case .todo(let todo, _, _):
            return BoardItemReference.todo(todo.id).id
        case .routine(let routine, _, _, _, _):
            return BoardItemReference.recurring(routine.id).id
        }
    }

    var modelID: UUID {
        switch self {
        case .todo(let todo, _, _):
            return todo.id
        case .routine(let routine, _, _, _, _):
            return routine.id
        }
    }

    var checkDayKey: String {
        switch self {
        case .todo(_, let day, _):
            return day
        case .routine(_, let day, _, _, _):
            return day
        }
    }

    var allowsCompletion: Bool {
        switch self {
        case .todo:
            return true
        case .routine(_, _, let allowed, _, _):
            return allowed
        }
    }

    var reference: BoardItemReference {
        switch self {
        case .todo(let todo, _, _):
            return .todo(todo.id)
        case .routine(let routine, _, _, _, _):
            return .recurring(routine.id)
        }
    }
}

struct WorkspaceItemGroup: Identifiable {
    var id: String
    var title: LocalizedStringKey?
    var entries: [WorkspaceItemEntry]
}

struct WorkspaceItemsList: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var groups: [WorkspaceItemGroup]
    var todayKey: String
    var checks: [RoutineCheck]
    var filterActive: Bool
    var emptyTitle: LocalizedStringKey
    var emptySubtitle: LocalizedStringKey = "items.empty.hint"

    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @Query private var attachments: [AttachmentItem]
    @Bindable private var navigation = WorkspaceNavigation.shared
    @State private var pendingTrash: PendingTrash?
    @State private var editingID: UUID?
    @State private var hostWindow: NSWindow?
    @State private var keyMonitor: Any?

    var body: some View {
        Group {
            if entries.isEmpty {
                DaybookEmptyState(
                    title: emptyTitle,
                    subtitle: emptySubtitle,
                    systemImage: filterActive ? "line.3.horizontal.decrease" : "tray",
                    centerVertically: true
                )
            } else {
                VStack(alignment: .leading, spacing: DaybookSpacing.md) {
                    ForEach(groups) { group in
                        if let title = group.title {
                            DaybookSectionHeader(title: title, count: group.entries.count)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(group.entries) { entry in
                                row(entry)
                            }
                        }
                    }
                }
            }
        }
        .focusable()
        .focusEffectDisabled()
        .background(KeyWindowHost { hostWindow = $0 })
        .confirmMoveToTrash($pendingTrash)
        .onAppear {
            installKeys()
            publishCheckDays()
        }
        .onDisappear {
            removeKeys()
            navigation.clearListedCheckDays()
        }
        .onChange(of: entries.map(\.modelID)) { _, ids in
            navigation.reconcileTaskSelection(with: ids)
            publishCheckDays()
        }
        .onChange(of: checkDaySignature) { _, _ in
            publishCheckDays()
        }
    }

    private var entries: [WorkspaceItemEntry] { groups.flatMap(\.entries) }

    private var checkDaySignature: String {
        entries.map { "\($0.modelID.uuidString):\($0.checkDayKey):\($0.allowsCompletion)" }.joined(separator: "|")
    }

    private func publishCheckDays() {
        var days: [UUID: String] = [:]
        for entry in entries {
            guard entry.allowsCompletion, case .routine = entry else { continue }
            days[entry.modelID] = entry.checkDayKey
        }
        navigation.replaceListedCheckDays(days)
    }

    private func row(_ entry: WorkspaceItemEntry) -> some View {
        let selected = navigation.selectedTaskIDs.contains(entry.modelID) || navigation.selectedTaskID == entry.modelID
        return rowView(entry, selected: selected)
            .id(entry.modelID)
    }

    @ViewBuilder
    private func rowView(_ entry: WorkspaceItemEntry, selected: Bool) -> some View {
        switch entry {
        case .todo(let todo, _, let subtaskIDs):
            TaskRowFactory.todo(todoContext(todo, selected: selected, subtaskIDs: subtaskIDs))
        case .routine(let routine, let day, let allowsCompletion, let count, let noteDay):
            TaskRowFactory.routine(routineContext(
                routine,
                day: day,
                selected: selected,
                allowsCompletion: allowsCompletion,
                overdueCount: count,
                noteDay: noteDay
            ))
        }
    }

    private func todoContext(_ todo: TodoItem, selected: Bool, subtaskIDs: Set<UUID>?) -> TodoRowContext {
        TodoRowContext(
            todo: todo,
            todayKey: todayKey,
            catalogs: catalogs,
            display: TodoRowDisplayOptions(
                isDone: PendingCompletionManager.shared.isVisuallyDone(id: todo.id, actualDone: todo.isDone),
                selection: TaskRowSelectionState(isSelected: selected, isExternalEditing: editingID == todo.id),
                includeSubtasks: true,
                visibleSubtaskIDs: subtaskIDs
            ),
            actions: TodoRowActions(
                onSelect: { select(todo.id, modifiers: $0) },
                onDelete: { askTrash(title: todo.title) { DayBoardMutations.trashTodo(todo) } },
                onToggle: { toggle(todo.id) },
                onEndEditing: { editingID = nil }
            )
        )
    }

    private func routineContext(
        _ routine: DailyRoutine,
        day: String,
        selected: Bool,
        allowsCompletion: Bool,
        overdueCount: Int,
        noteDay: String?
    ) -> RoutineRowContext {
        let done = DayBoardLogic.isRoutineDone(routine.snapshot, checks: checks.compactMap(\.snapshot), on: day)
        var extras: [String] = []
        if overdueCount > 1 {
            extras.append(L10n.format("items.routine.overdueCount %lld", locale: locale, overdueCount))
        }
        if let noteDay {
            extras.append(L10n.format("items.routine.next %@", locale: locale, DayKey.displayName(noteDay, locale: locale)))
        }
        let skipped = DayBoardLogic.isRoutineSkipped(routine.snapshot, checks: checks.compactMap(\.snapshot), on: day)
        let schedule = done
            ? ResidentNote.done(routine, skipped: skipped, locale: locale)
            : ResidentNote.days(routine, locale: locale)
        let note = AgendaProjection.routineNote(schedule: schedule, extras: extras)
        return RoutineRowContext(
            routine: routine,
            schedule: RoutineScheduleContext(todayKey: todayKey, checkDayKey: day, checks: checks, locale: locale),
            catalogs: catalogs,
            display: RoutineRowDisplayOptions(
                isDone: PendingCompletionManager.shared.isVisuallyDone(id: routine.id, actualDone: done),
                selection: TaskRowSelectionState(isSelected: selected, isExternalEditing: editingID == routine.id),
                note: note,
                usesDefaultNote: note == nil,
                allowsCompletion: allowsCompletion
            ),
            actions: RoutineRowActions(
                onSelect: { select(routine.id, modifiers: $0) },
                onDelete: { askTrash(title: routine.title) { DayBoardMutations.trashRoutine(routine) } },
                onToggle: allowsCompletion ? { toggle(routine.id) } : nil,
                onSkip: allowsCompletion ? { DayBoardMutations.skipRoutine(routine, on: day, checks: checks, context: modelContext) } : nil,
                onEndEditing: { editingID = nil }
            )
        )
    }

    private var catalogs: TaskCatalogContext {
        TaskCatalogContext(tags: tags, attachments: attachments, context: modelContext)
    }

    private func select(_ id: UUID, modifiers: TaskSelectionModifiers) {
        guard let entry = entries.first(where: { $0.modelID == id }) else { return }
        if modifiers.isEmpty {
            navigation.clearSelection()
            navigation.inspectTask(id, dayKey: entry.checkDayKey)
            navigation.inspectedReference = entry.reference
            return
        }
        navigation.selectTask(id, in: entries.map(\.modelID), modifiers: modifiers)
    }

    private func toggle(_ id: UUID) {
        guard let entry = entries.first(where: { $0.modelID == id }), entry.allowsCompletion else { return }
        switch entry {
        case .todo(let todo, _, _):
            PendingCompletionManager.shared.toggle(id: todo.id, currentlyDone: todo.isDone, reduceMotion: reduceMotion) {
                _ = DayBoardMutations.toggleTodo(todo)
            }
        case .routine(let routine, let day, _, _, _):
            let done = DayBoardLogic.isRoutineDone(routine.snapshot, checks: checks.compactMap(\.snapshot), on: day)
            PendingCompletionManager.shared.toggle(id: routine.id, currentlyDone: done, reduceMotion: reduceMotion) {
                _ = DayBoardMutations.toggleRoutine(routine, on: day, checks: checks, context: modelContext)
            }
        }
    }

    private func askTrash(title: String, action: @escaping () -> Void) {
        pendingTrash = PendingTrash(title: title, confirm: action)
    }

    private func installKeys() {
        keyMonitor = BoardKeyMonitor.install(existing: keyMonitor) { event in
            guard hostWindow == nil || event.window === hostWindow else { return event }
            return handle(event)
        }
    }

    private func removeKeys() {
        BoardKeyMonitor.remove(keyMonitor)
        keyMonitor = nil
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        if let editor = NSApp.keyWindow?.firstResponder as? NSTextView, editor.hasMarkedText() { return event }
        if NSApp.keyWindow?.firstResponder is NSTextView { return event }
        let ids = entries.map(\.modelID)
        guard !ids.isEmpty else { return event }
        switch event.keyCode {
        case 125, 126:
            move(event.keyCode == 125 ? 1 : -1, ids: ids)
            return nil
        case 49:
            if let id = navigation.selectedTaskID { toggle(id) }
            return nil
        case 36:
            if let id = navigation.selectedTaskID { select(id, modifiers: []) }
            return nil
        case 51:
            if let entry = entries.first(where: { $0.modelID == navigation.selectedTaskID }) {
                askTrash(title: entryTitle(entry)) { trash(entry) }
            }
            return nil
        case 14:
            editingID = navigation.selectedTaskID
            return nil
        case 53:
            if navigation.isInspectorPresented {
                navigation.closeInspector()
            } else if !navigation.selectedTaskIDs.isEmpty {
                navigation.clearSelection()
            } else {
                navigation.selectedTaskID = nil
            }
            return nil
        default:
            return event
        }
    }

    private func move(_ delta: Int, ids: [UUID]) {
        let current = navigation.selectedTaskID
        let index = current.flatMap { ids.firstIndex(of: $0) } ?? (delta > 0 ? -1 : ids.count)
        let next = min(max(index + delta, 0), ids.count - 1)
        let id = ids[next]
        navigation.selectedTaskID = id
        navigation.clearSelection()
        if navigation.isInspectorPresented, let entry = entries.first(where: { $0.modelID == id }) {
            navigation.inspectTask(id, dayKey: entry.checkDayKey)
            navigation.inspectedReference = entry.reference
        }
    }

    private func entryTitle(_ entry: WorkspaceItemEntry) -> String {
        switch entry {
        case .todo(let todo, _, _): return todo.title
        case .routine(let routine, _, _, _, _): return routine.title
        }
    }

    private func trash(_ entry: WorkspaceItemEntry) {
        switch entry {
        case .todo(let todo, _, _):
            _ = DayBoardMutations.trashTodo(todo)
        case .routine(let routine, _, _, _, _):
            _ = DayBoardMutations.trashRoutine(routine)
        }
    }
}
