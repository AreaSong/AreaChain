import AppKit
import SwiftUI

extension DayBoardList {
    func setupKeyMonitor() {
        guard focusedTaskID != nil else { return }
        keyMonitor = BoardKeyMonitor.install(existing: keyMonitor) { event in
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
            boardSelection.markEscapeCancelsEdits()
            NSApp.keyWindow?.makeFirstResponder(nil)
            return nil
        }
        if event.keyCode == 125,
           let tv = firstResponder as? NSTextView,
           tv.string.isEmpty,
           !workspaceNavigation.isInspectorPresented
        {
            NSApp.keyWindow?.makeFirstResponder(nil)
            navigateSelection(delta: 1)
            return nil
        }
        return event
    }

    private func handleNavigationKey(event: NSEvent) -> NSEvent? {
        let keyCode = event.keyCode
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock)

        if handleArrowNavigation(keyCode: keyCode, mods: mods) { return nil }
        if handleSelectionAction(keyCode: keyCode) { return nil }
        if ShortcutStore.shared.binding(for: .selectAll).matches(event) {
            selectAllVisible()
            return nil
        }
        if handleShortcutAction(keyCode: keyCode, mods: mods) { return nil }

        return event
    }

    private func handleArrowNavigation(keyCode: UInt16, mods: NSEvent.ModifierFlags) -> Bool {
        if keyCode == 125 {
            navigateSelection(delta: 1, extending: mods.contains(.shift))
            return true
        }
        if keyCode == 126 {
            navigateSelection(delta: -1, extending: mods.contains(.shift))
            return true
        }
        return false
    }

    private func handleSelectionAction(keyCode: UInt16) -> Bool {
        let targetID = focusedTaskID?.wrappedValue ?? taskSelection.ids.first
        switch keyCode {
        case 49:
            guard let targetID else { return false }
            toggleSelected(id: targetID)
            return true
        case 36:
            guard let id = focusedTaskID?.wrappedValue else { return false }
            inspectSelected(id: id)
            return true
        case 51:
            guard let targetID else { return false }
            deleteSelected(id: targetID)
            return true
        default:
            return false
        }
    }

    private func handleShortcutAction(keyCode: UInt16, mods: NSEvent.ModifierFlags) -> Bool {
        if keyCode == 14, mods.isEmpty, let id = focusedTaskID?.wrappedValue {
            editingTaskID = id
            return true
        }
        if keyCode == 53 {
            if workspaceNavigation.isInspectorPresented,
               hostWindow === PanelWindowController.workspace.hostedWindow {
                workspaceNavigation.isInspectorPresented = false
                return true
            }
            if focusedTaskID?.wrappedValue != nil || !taskSelection.ids.isEmpty {
                focusTask(nil)
                onReturnToInput?()
                return true
            }
        }
        return false
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
        BoardKeyMonitor.remove(keyMonitor)
        keyMonitor = nil
    }

    var orderedVisibleRows: [BoardRow] {
        makeListIdentity().visibleRows(showCompleted: showCompleted)
    }

    func navigateSelection(delta: Int, extending: Bool = false) {
        let identity = makeListIdentity()
        let rows = identity.visibleRows(showCompleted: showCompleted)
        guard !rows.isEmpty else { return }
        let listIDs = rows.map(\.listID)
        let current = focusedListID ?? focusedTaskID?.wrappedValue.flatMap { modelID in
            rows.first { $0.id == modelID }?.listID
        }

        guard let current, let idx = listIDs.firstIndex(of: current) else {
            if let next = delta >= 0 ? rows.first : rows.last {
                focusRow(next)
            }
            return
        }

        let nextIdx = idx + delta
        guard nextIdx >= 0 && nextIdx < rows.count else {
            if nextIdx < 0 && !extending {
                focusedListID = nil
                focusTask(nil)
                onReturnToInput?()
            }
            return
        }

        let next = rows[nextIdx]
        if extending {
            var selection = taskSelection
            if selection.anchorID == nil { selection.anchorID = rows[idx].id }
            selection.select(next.id, in: rows.map(\.id), modifiers: .shift)
            taskSelection = selection
            focusedListID = next.listID
            focusedTaskID?.wrappedValue = next.id
            boardSelection.inspectBoard(mappedDayKey(for: next.id))
        } else {
            focusRow(next)
        }
    }

    func focusRow(_ row: BoardRow) {
        focusedListID = row.listID
        focusTask(row.id)
        boardSelection.inspectBoard(mappedDayKey(for: row.id))
    }

    func activeReference(preferring id: UUID, identity: DayBoardListIdentity? = nil) -> BoardItemReference? {
        let rows = (identity ?? makeListIdentity()).visibleRows(showCompleted: showCompleted).filter { $0.id == id }
        if let focusedListID, let match = rows.first(where: { $0.listID == focusedListID }) {
            return match.reference
        }
        return rows.first?.reference
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
            inspecting: boardSelection.inspectingDayKey,
            mapped: mappedDayKey(for: id),
            listDayKey: dayKey
        )
    }

    var orderedVisibleIDs: [UUID] {
        makeListIdentity().visibleIDs(showCompleted: showCompleted)
    }

    func toggleSelected(id: UUID) {
        // 范围选择只高亮。空格仍只完成焦点行；整批完成留在有批量栏的页面。
        singleToggleSelected(id: id)
    }

    func singleToggleSelected(id: UUID) {
        let identity = makeListIdentity()
        let checkOn = checkDay(for: id)
        let reference = activeReference(preferring: id, identity: identity)
        if reference?.kind == .recurring, let routine = identity.routine(id) {
            let isDone = identity.source.checkIndex.isClosed(routineId: routine.id, dayKey: checkOn)
            PendingCompletionManager.shared.toggle(
                id: routine.id,
                currentlyDone: isDone,
                reduceMotion: reduceMotion
            ) {
                persistToggleSelected(id: id)
            }
            return
        }
        if let todo = identity.todo(id), reference?.kind != .recurring {
            PendingCompletionManager.shared.toggle(
                id: todo.id,
                currentlyDone: todo.isDone,
                reduceMotion: reduceMotion
            ) {
                persistToggleSelected(id: id)
            }
        }
    }

    /// 行复选框已经做过驻留；这里只落盘，避免鼠标路径套两层 0.4 秒。
    func persistToggleSelected(id: UUID) {
        let identity = makeListIdentity()
        let previousIDs = identity.visibleIDs(showCompleted: showCompleted)
        let checkOn = checkDay(for: id)
        let reference = activeReference(preferring: id, identity: identity)
        if reference?.kind == .recurring, let routine = identity.routine(id) {
            guard DayBoardMutations.toggleRoutine(
                routine,
                on: checkOn,
                checks: checks,
                context: modelContext
            ) else { return }
            shiftFocusAfterCompletion(id: id, previousIDs: previousIDs)
            return
        }
        if let todo = identity.todo(id), reference?.kind != .recurring {
            guard DayBoardMutations.toggleTodo(todo) else { return }
            shiftFocusAfterCompletion(id: id, previousIDs: previousIDs)
        }
    }

    private func shiftFocusAfterCompletion(id: UUID, previousIDs: [UUID]) {
        guard !showCompleted, let index = previousIDs.firstIndex(of: id) else { return }
        let remaining = Set(effectiveVisibleIDs)
        let candidates = Array(previousIDs.dropFirst(index + 1)) + Array(previousIDs.prefix(index).reversed())
        focusTask(candidates.first { remaining.contains($0) })
        if let focused = focusedTaskID?.wrappedValue {
            boardSelection.inspectBoard(mappedDayKey(for: focused))
        } else {
            onReturnToInput?()
        }
    }

    func deleteSelected(id: UUID) {
        singleDeleteSelected(id: id)
    }

    private func singleDeleteSelected(id: UUID) {
        let identity = makeListIdentity()
        let reference = activeReference(preferring: id, identity: identity)
        let rows = identity.visibleRows(showCompleted: showCompleted)
        if let idx = rows.firstIndex(where: { $0.listID == reference?.id }) ?? rows.firstIndex(where: { $0.id == id }) {
            if idx + 1 < rows.count {
                focusRow(rows[idx + 1])
            } else if idx > 0 {
                focusRow(rows[idx - 1])
            } else {
                focusTask(nil)
                onReturnToInput?()
            }
        }
        switch reference?.kind {
        case .recurring:
            guard let routine = identity.routine(id) else { return }
            pendingTrash = PendingTrash(title: routine.title) {
                DayBoardMutations.trashRoutine(routine)
            }
        case .oneOff:
            guard let todo = identity.todo(id) else { return }
            pendingTrash = PendingTrash(title: todo.title) {
                DayBoardMutations.trashTodo(todo)
            }
        case nil:
            if let todo = identity.todo(id) {
                pendingTrash = PendingTrash(title: todo.title) {
                    DayBoardMutations.trashTodo(todo)
                }
            } else if let routine = identity.routine(id) {
                pendingTrash = PendingTrash(title: routine.title) {
                    DayBoardMutations.trashRoutine(routine)
                }
            }
        }
    }

    func inspectSelected(id: UUID) {
        revealCompletedIfNeeded(id)
        let inspectDay = checkDay(for: id)
        boardSelection.inspectBoard(inspectDay)
        if let reference = activeReference(preferring: id) {
            workspaceNavigation.inspectedReference = reference
        }
        if let onInspect {
            onInspect(id)
            if let reference = activeReference(preferring: id) {
                workspaceNavigation.inspectedReference = reference
            }
            return
        }
        AppWindows.openWorkspace(
            tab: dayKey == todayKey ? .today : .calendar,
            inspecting: id,
            dayKey: inspectDay
        )
    }
}
