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
                return self.handleTextViewEditingKey(event: event, firstResponder: firstResponder)
            }
            // 焦点在筛选菜单、按钮或日期控件时，由控件处理 Space/Return，不能误勾清单。
            if firstResponder is NSControl { return event }
            return self.handleNavigationKey(event: event)
        }
    }

    func handleTextViewEditingKey(event: NSEvent, firstResponder: NSResponder?) -> NSEvent? {
        if let editor = firstResponder as? NSTextView, editor.hasMarkedText() { return event }
        if event.keyCode == 53 {
            // 单行和多行语法编辑器先处理候选与取消，列表不能提前触发失焦保存。
            if firstResponder is DaybookAppKitTextView { return event }
            if let editor = firstResponder as? NSTextView,
               let field = (editor.delegate as AnyObject?) as? DaybookAppKitTextField,
               field.delegate is DaybookTextField.Coordinator {
                return event
            }
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

    private func handleNavigationKey(event: NSEvent) -> NSEvent? {
        switch event.keyCode {
        case 125:
            navigateSelection(delta: 1, extending: event.modifierFlags.contains(.shift))
            return nil
        case 126:
            navigateSelection(delta: -1, extending: event.modifierFlags.contains(.shift))
            return nil
        case 49:
            let targetID = focusedTaskID?.wrappedValue ?? taskSelection.ids.first
            if let targetID {
                toggleSelected(id: targetID)
                return nil
            }
        case 36:
            if let id = focusedTaskID?.wrappedValue {
                inspectSelected(id: id)
                return nil
            }
        case 51:
            let targetID = focusedTaskID?.wrappedValue ?? taskSelection.ids.first
            if let targetID {
                deleteSelected(id: targetID)
                return nil
            }
        case 0:
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock)
            if mods == .command {
                selectAllVisible()
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
            if focusedTaskID?.wrappedValue != nil || !taskSelection.ids.isEmpty {
                focusTask(nil)
                onReturnToInput?()
                return nil
            }
        default:
            break
        }
        return event
    }

    func shouldHandle(_ event: NSEvent) -> Bool {
        guard config.interaction.isKeyboardEnabled() else { return false }
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

    func navigateSelection(delta: Int, extending: Bool = false) {
        let ids = effectiveVisibleIDs
        guard !ids.isEmpty else { return }
        if let current = focusedTaskID?.wrappedValue, let idx = ids.firstIndex(of: current) {
            let nextIdx = idx + delta
            if nextIdx >= 0 && nextIdx < ids.count {
                let nextID = ids[nextIdx]
                if extending {
                    var selection = taskSelection
                    if selection.anchorID == nil {
                        selection.anchorID = current
                    }
                    selection.select(nextID, in: ids, modifiers: .shift)
                    taskSelection = selection
                    focusedTaskID?.wrappedValue = nextID
                } else {
                    focusTask(nextID)
                }
                BoardSelection.shared.inspectBoard(mappedDayKey(for: nextID))
            } else if nextIdx < 0 && !extending {
                focusTask(nil)
                onReturnToInput?()
            }
        } else {
            let nextID = delta >= 0 ? ids.first : ids.last
            focusTask(nextID)
            if let nextID {
                BoardSelection.shared.inspectBoard(mappedDayKey(for: nextID))
            }
        }
    }

    func selectAllVisible() {
        let ids = effectiveVisibleIDs
        guard !ids.isEmpty else { return }
        taskSelection.ids = Set(ids)
        if taskSelection.anchorID == nil {
            taskSelection.anchorID = ids.first
        }
        if focusedTaskID?.wrappedValue == nil {
            focusedTaskID?.wrappedValue = ids.first
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
        let selected = taskSelection.ids
        if selected.count > 1 && (selected.contains(id) || focusedTaskID?.wrappedValue == nil) {
            batchToggleSelected(selected)
            return
        }
        singleToggleSelected(id: id)
    }

    private func singleToggleSelected(id: UUID) {
        let previousIDs = effectiveVisibleIDs
        let checkOn = checkDay(for: id)
        if let todo = todos.first(where: { $0.id == id }) {
            PendingCompletionManager.shared.toggle(
                id: todo.id,
                currentlyDone: todo.isDone,
                reduceMotion: reduceMotion
            ) {
                guard DayBoardMutations.toggleTodo(todo) else { return }
                self.shiftFocusAfterCompletion(id: id, previousIDs: previousIDs)
            }
        } else if let routine = routines.first(where: { $0.id == id }) {
            let isDone = DayBoardLogic.isRoutineDone(
                routine.snapshot,
                checks: checks.compactMap(\.snapshot),
                on: checkOn
            )
            PendingCompletionManager.shared.toggle(
                id: routine.id,
                currentlyDone: isDone,
                reduceMotion: reduceMotion
            ) {
                guard DayBoardMutations.toggleRoutine(
                    routine,
                    on: checkOn,
                    checks: checks,
                    context: modelContext
                ) else { return }
                self.shiftFocusAfterCompletion(id: id, previousIDs: previousIDs)
            }
        }
    }

    func batchToggleSelected(_ ids: Set<UUID>) {
        let previousIDs = effectiveVisibleIDs
        let selectedTodos = todos.filter { ids.contains($0.id) }
        let selectedRoutines = routines.filter { ids.contains($0.id) }

        let anyUndone = selectedTodos.contains(where: {
            !$0.isDone && !PendingCompletionManager.shared.pendingDoneIDs.contains($0.id)
        }) || selectedRoutines.contains(where: {
            let checkOn = checkDay(for: $0.id)
            let isDone = DayBoardLogic.isRoutineDone(
                $0.snapshot,
                checks: checks.compactMap(\.snapshot),
                on: checkOn
            )
            return !isDone && !PendingCompletionManager.shared.pendingDoneIDs.contains($0.id)
        })

        let markDone = anyUndone

        PendingCompletionManager.shared.toggleBatch(
            ids: ids,
            markDone: markDone,
            reduceMotion: reduceMotion
        ) {
            let todoIDs = Set(selectedTodos.map(\.id))
            if !todoIDs.isEmpty {
                DayBoardMutations.batchToggleDone(todoIDs, markDone: markDone, todos: self.todos)
            }
            for routine in selectedRoutines {
                let checkOn = self.checkDay(for: routine.id)
                DayBoardMutations.batchSetRoutineChecks(
                    [routine.id],
                    markDone: markDone,
                    on: checkOn,
                    routines: self.routines,
                    context: self.modelContext
                )
            }
            if markDone {
                self.shiftFocusAfterBatchCompletion(completedIDs: ids, previousIDs: previousIDs)
            }
        }
    }

    private func shiftFocusAfterCompletion(id: UUID, previousIDs: [UUID]) {
        guard !showCompleted, let index = previousIDs.firstIndex(of: id) else { return }
        let remaining = Set(effectiveVisibleIDs)
        let candidates = Array(previousIDs.dropFirst(index + 1)) + Array(previousIDs.prefix(index).reversed())
        focusTask(candidates.first { remaining.contains($0) })
        if let focused = focusedTaskID?.wrappedValue {
            BoardSelection.shared.inspectBoard(mappedDayKey(for: focused))
        } else {
            onReturnToInput?()
        }
    }

    private func shiftFocusAfterBatchCompletion(completedIDs: Set<UUID>, previousIDs: [UUID]) {
        guard !showCompleted else { return }
        let remaining = Set(effectiveVisibleIDs).subtracting(completedIDs)
        let lastSelectedIdx = previousIDs.lastIndex { completedIDs.contains($0) } ?? 0
        let candidates = Array(previousIDs.dropFirst(lastSelectedIdx + 1)) + Array(previousIDs.prefix(lastSelectedIdx).reversed())
        let nextFocus = candidates.first { remaining.contains($0) }
        focusTask(nextFocus)
        if let nextFocus {
            BoardSelection.shared.inspectBoard(mappedDayKey(for: nextFocus))
        } else {
            onReturnToInput?()
        }
    }

    func deleteSelected(id: UUID) {
        let selected = taskSelection.ids
        if selected.count > 1 && selected.contains(id) {
            batchDeleteSelected(selected)
            return
        }
        singleDeleteSelected(id: id)
    }

    private func singleDeleteSelected(id: UUID) {
        let ids = effectiveVisibleIDs
        if let idx = ids.firstIndex(of: id) {
            if idx + 1 < ids.count {
                focusTask(ids[idx + 1])
            } else if idx > 0 {
                focusTask(ids[idx - 1])
            } else {
                focusTask(nil)
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

    func batchDeleteSelected(_ ids: Set<UUID>) {
        let previousIDs = effectiveVisibleIDs
        let remaining = Set(effectiveVisibleIDs).subtracting(ids)
        let lastIdx = previousIDs.lastIndex { ids.contains($0) } ?? 0
        let candidates = Array(previousIDs.dropFirst(lastIdx + 1)) + Array(previousIDs.prefix(lastIdx).reversed())
        let nextFocus = candidates.first { remaining.contains($0) }

        pendingTrash = PendingTrash(title: "\(ids.count)") {
            DayBoardMutations.batchTrash(ids, todos: self.todos, routines: self.routines)
            self.focusTask(nextFocus)
            if let nextFocus {
                BoardSelection.shared.inspectBoard(self.mappedDayKey(for: nextFocus))
            } else {
                self.onReturnToInput?()
            }
        }
    }

    func inspectSelected(id: UUID) {
        revealCompletedIfNeeded(id)
        let inspectDay = checkDay(for: id)
        BoardSelection.shared.inspectBoard(inspectDay)
        if let onInspect {
            onInspect(id)
            return
        }
        AppWindows.openWorkspace(
            tab: dayKey == todayKey ? .today : .calendar,
            inspecting: id,
            dayKey: inspectDay
        )
    }
}
