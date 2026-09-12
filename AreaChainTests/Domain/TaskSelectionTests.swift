import Foundation
import Testing
@testable import AreaChain

struct TaskSelectionTests {
    private let ids = (0..<5).map { _ in UUID() }

    @Test func shiftExtendsInVisibleOrderAndKeepsTheOriginalAnchor() {
        var selection = TaskSelection()
        selection.select(ids[1], in: ids)
        selection.select(ids[4], in: ids, modifiers: .shift)
        #expect(selection.ids == Set(ids[1...4]))
        selection.select(ids[2], in: ids, modifiers: .shift)
        #expect(selection.ids == Set(ids[1...2]))
        selection.select(ids[0], in: ids, modifiers: .shift)
        #expect(selection.ids == Set(ids[0...1]))
        #expect(selection.anchorID == ids[1])
    }

    @Test func plainClickReplacesRangeAndCommandTogglesOnlyTheClickedItem() {
        var selection = TaskSelection()
        selection.select(ids[0], in: ids)
        selection.select(ids[3], in: ids, modifiers: .shift)
        selection.select(ids[4], in: ids)
        #expect(selection.ids == [ids[4]])
        selection.select(ids[1], in: ids, modifiers: .command)
        #expect(selection.ids == [ids[1], ids[4]])
        selection.select(ids[1], in: ids, modifiers: .command)
        #expect(selection.ids == [ids[4]])
    }

    @Test func commandShiftAddsRangeWithoutDroppingExistingSelection() {
        var selection = TaskSelection()
        selection.select(ids[4], in: ids)
        selection.select(ids[0], in: ids, modifiers: .command)
        selection.select(ids[2], in: ids, modifiers: [.command, .shift])
        #expect(selection.ids == [ids[0], ids[1], ids[2], ids[4]])
    }

    @Test func hiddenRowsAreExcludedAndMissingAnchorFallsBackToTheClickedItem() {
        var selection = TaskSelection()
        selection.select(ids[0], in: ids)
        selection.select(ids[4], in: [ids[0], ids[2], ids[4]], modifiers: .shift)
        #expect(selection.ids == [ids[0], ids[2], ids[4]])
        selection.reconcile(with: [ids[2], ids[4]])
        #expect(selection.anchorID == nil)
        selection.select(ids[4], in: [ids[2], ids[4]], modifiers: .shift)
        #expect(selection.ids == [ids[4]])
        selection.select(UUID(), in: ids)
        #expect(selection.ids == [ids[4]])
        selection.reconcile(with: [])
        #expect(selection.ids.isEmpty)
        #expect(selection.anchorID == nil)
    }

    @Test func shiftWithoutAnchorSelectsOnlyTheClickedItem() {
        var selection = TaskSelection()
        selection.select(ids[3], in: ids, modifiers: .shift)
        #expect(selection.ids == [ids[3]])
        selection.select(ids[3], in: ids, modifiers: .shift)
        #expect(selection.ids == [ids[3]])
    }
}

@MainActor
struct WorkspaceTaskSelectionTests {
    @Test func finderSelectionPreservesSingleInspectorAndSeparatesBatchSelection() {
        let navigation = WorkspaceNavigation(boardSelection: BoardSelection())
        let ids = (0..<5).map { _ in UUID() }
        navigation.selectTask(ids[1], in: ids)
        #expect(navigation.selectedTaskID == ids[1])
        #expect(navigation.selectedTaskIDs.isEmpty)
        #expect(navigation.isInspectorPresented)
        navigation.selectTask(ids[4], in: ids, modifiers: .shift)
        #expect(navigation.selectedTaskIDs == Set(ids[1...4]))
        navigation.selectTask(ids[2], in: ids, modifiers: .shift)
        #expect(navigation.selectedTaskIDs == Set(ids[1...2]))
        navigation.selectTask(ids[0], in: ids)
        #expect(navigation.selectedTaskIDs.isEmpty)
        #expect(navigation.selectedTaskID == ids[0])
        navigation.selectTask(ids[4], in: ids, modifiers: .command)
        #expect(navigation.selectedTaskIDs == [ids[0], ids[4]])
    }

    @Test func clearAndNavigationResetTheRangeAnchorWithoutClearingInspectorTarget() {
        let navigation = WorkspaceNavigation(boardSelection: BoardSelection())
        let ids = (0..<3).map { _ in UUID() }
        navigation.selectTask(ids[0], in: ids)
        navigation.selectTask(ids[2], in: ids, modifiers: .shift)
        navigation.selectedTab = .calendar
        #expect(navigation.selectedTaskIDs.isEmpty)
        #expect(navigation.selectionAnchorID == nil)
        #expect(navigation.selectedTaskID == ids[2])
        navigation.selectAllTasks(in: ids)
        navigation.reconcileTaskSelection(with: [ids[1]])
        #expect(navigation.selectedTaskIDs == [ids[1]])
        #expect(navigation.selectionAnchorID == nil)
    }
}
