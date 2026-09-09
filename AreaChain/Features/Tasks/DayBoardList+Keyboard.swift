import AppKit
import SwiftUI

extension DayBoardList {
    func setupKeyMonitor() {
        guard focusedTaskID != nil else { return }
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard self.shouldHandle(event) else { return event }

            let firstResponder = NSApp.keyWindow?.firstResponder
            let isTextViewEditing = (firstResponder as? NSTextView)?.isEditable == true

            if isTextViewEditing {
                if event.keyCode == 53 {
                    BoardSelection.shared.markEscapeCancelsEdits()
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    return nil
                }
                if event.keyCode == 125,
                   let tv = firstResponder as? NSTextView,
                   tv.string.isEmpty,
                   !WorkspaceNavigation.shared.isInspectorPresented
                {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    navigateSelection(delta: 1)
                    return nil
                }
                return event
            }

            switch event.keyCode {
            case 125:
                navigateSelection(delta: 1)
                return nil
            case 126:
                navigateSelection(delta: -1)
                return nil
            case 49:
                if let id = focusedTaskID?.wrappedValue {
                    toggleSelected(id: id)
                    return nil
                }
            case 36:
                if let id = focusedTaskID?.wrappedValue {
                    inspectSelected(id: id)
                    return nil
                }
            case 51:
                if let id = focusedTaskID?.wrappedValue {
                    deleteSelected(id: id)
                    return nil
                }
            case 14:
                let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock)
                guard mods.isEmpty else { break }
                if let id = focusedTaskID?.wrappedValue {
                    editingTaskID = id
                    return nil
                }
            case 53:
                if WorkspaceNavigation.shared.isInspectorPresented,
                   hostWindow === PanelWindowController.workspace.hostedWindow
                {
                    WorkspaceNavigation.shared.isInspectorPresented = false
                    return nil
                }
                if focusedTaskID?.wrappedValue != nil {
                    focusedTaskID?.wrappedValue = nil
                    onReturnToInput?()
                    return nil
                }
            default:
                break
            }
            return event
        }
    }

    func shouldHandle(_ event: NSEvent) -> Bool {
        let mine = hostWindow
        let eventWindow = event.window
        if let mine, let eventWindow {
            return eventWindow === mine
        }
        return mine != nil && NSApp.keyWindow === mine
    }

    func tearDownKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    func navigateSelection(delta: Int) {
        let ids = orderedVisibleIDs
        guard !ids.isEmpty else { return }
        if let current = focusedTaskID?.wrappedValue, let idx = ids.firstIndex(of: current) {
            let nextIdx = idx + delta
            if nextIdx >= 0 && nextIdx < ids.count {
                let nextID = ids[nextIdx]
                focusedTaskID?.wrappedValue = nextID
                BoardSelection.shared.inspectBoard(dayKey)
            } else if nextIdx < 0 {
                focusedTaskID?.wrappedValue = nil
                onReturnToInput?()
            }
        } else {
            let nextID = delta >= 0 ? ids.first : ids.last
            focusedTaskID?.wrappedValue = nextID
            if nextID != nil {
                BoardSelection.shared.inspectBoard(dayKey)
            }
        }
    }

    func mappedDayKey(for id: UUID) -> String {
        dayKeyForID?(id) ?? dayKey
    }

    func checkDay(for id: UUID) -> String {
        BoardFocusDay.checkDay(
            inspecting: BoardSelection.shared.inspectingDayKey,
            mapped: mappedDayKey(for: id),
            listDayKey: dayKey
        )
    }

    var orderedVisibleIDs: [UUID] {
        var ids: [UUID] = []
        ids.append(contentsOf: openTodosList.map(\.id))
        ids.append(contentsOf: openRoutinesList.map(\.id))
        if showCompleted {
            ids.append(contentsOf: doneItemsList.map(\.id))
        }
        return ids
    }

    func toggleSelected(id: UUID) {
        let checkOn = checkDay(for: id)
        if let todo = todos.first(where: { $0.id == id }) {
            DayBoardMutations.toggleTodo(todo)
        } else if let routine = routines.first(where: { $0.id == id }) {
            DayBoardMutations.toggleRoutine(
                routine,
                on: checkOn,
                checks: checks,
                context: modelContext
            )
        }
        let ids = orderedVisibleIDs
        guard let idx = ids.firstIndex(of: id), !showCompleted else { return }
        if idx + 1 < ids.count {
            focusedTaskID?.wrappedValue = ids[idx + 1]
            BoardSelection.shared.inspectBoard(dayKey)
        } else if idx > 0 {
            focusedTaskID?.wrappedValue = ids[idx - 1]
            BoardSelection.shared.inspectBoard(dayKey)
        }
    }

    func deleteSelected(id: UUID) {
        let ids = orderedVisibleIDs
        if let idx = ids.firstIndex(of: id) {
            if idx + 1 < ids.count {
                focusedTaskID?.wrappedValue = ids[idx + 1]
            } else if idx > 0 {
                focusedTaskID?.wrappedValue = ids[idx - 1]
            } else {
                focusedTaskID?.wrappedValue = nil
                onReturnToInput?()
            }
        }
        if let todo = todos.first(where: { $0.id == id }) {
            pendingTrash = PendingTrash(title: todo.title) {
                DayBoardMutations.trashTodo(todo)
            }
            return
        }
        if let routine = routines.first(where: { $0.id == id }) {
            pendingTrash = PendingTrash(title: routine.title) {
                DayBoardMutations.trashRoutine(routine)
            }
        }
    }

    func inspectSelected(id: UUID) {
        revealCompletedIfNeeded(id)
        BoardSelection.shared.inspectBoard(checkDay(for: id))
        if let onInspect {
            onInspect(id)
            return
        }
        if dayKey == todayKey {
            AppWindows.openWorkspace(tab: .today)
        } else {
            AppWindows.openWorkspace(tab: .calendar)
        }
        WorkspaceNavigation.shared.inspectTask(id)
    }
}
