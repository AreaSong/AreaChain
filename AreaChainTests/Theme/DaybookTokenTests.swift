import SwiftUI
import Testing
@testable import AreaChain

struct DaybookTokenTests {
    @Test func metricsFollowTheMenuBarBaseline() {
        #expect(DaybookMetrics.inputHeight == 34)
        #expect(DaybookMetrics.controlHeight == 28)
        #expect(DaybookMetrics.rowHeight == 36)
        #expect(DaybookMetrics.chipHeight == 18)
        #expect(DaybookMetrics.Hit.regular == 28)
        #expect(DaybookMetrics.Hit.compact == 22)
        #expect(DaybookMetrics.Hit.inline == 18)
        #expect(DaybookMetrics.Radius.inputComposer == 8)
        #expect(DaybookMetrics.Radius.inputSearch == 6)
        #expect(DaybookMetrics.Radius.inputEditor == 6)
        #expect(DaybookMetrics.Stroke.regular == 0.6)
        #expect(DaybookMetrics.Stroke.focus == 0.9)
    }

    @Test func inputInsetsMatchTheMenuBarCaptureField() {
        let composer = DaybookMetrics.inputInsets(.composer)
        #expect(composer.top == 7)
        #expect(composer.leading == 10)
        let search = DaybookMetrics.inputInsets(.search)
        #expect(search.top == 4)
        #expect(search.leading == 7)
        let editor = DaybookMetrics.inputInsets(.editor)
        #expect(editor.top == 4)
        #expect(editor.leading == 4)
    }

    @Test func elevationLevelsAreDistinct() {
        #expect(DaybookElevation.flat != DaybookElevation.raised)
        #expect(DaybookElevation.raised != DaybookElevation.floating)
        #expect(DaybookElevation.floating.radius == 8)
        #expect(DaybookElevation.floating.y == 2)
    }

    @Test func newRadiusAndTypeTokensExist() {
        #expect(DaybookRadius.xxs == 2.5)
        #expect(DaybookRadius.regular == 8)
        #expect(DaybookType.kbd != DaybookType.micro)
        #expect(DaybookType.bodyLarge != DaybookType.body)
        #expect(DaybookType.display != DaybookType.title)
    }

    @Test func workspaceLayoutKeepsItsValues() {
        #expect(WorkspaceLayout.headerHeight == 50)
        #expect(WorkspaceLayout.maxContentWidth == 880)
        #expect(WorkspaceLayout.sidebarRowHeight == 28)
        #expect(WorkspaceLayout.sidebarTopInset == 28)
    }

    @Test func diaryPresetColorsFollowTagNames() {
        #expect(DaybookPalette.diaryPreset(forTagName: DiaryMemoTags.password) == DaybookPalette.DiaryPreset.password)
        #expect(DaybookPalette.diaryPreset(forTagName: DiaryMemoTags.idea) == DaybookPalette.DiaryPreset.idea)
        #expect(DaybookPalette.diaryPreset(forTagName: DiaryMemoTags.journal) == DaybookPalette.DiaryPreset.journal)
        #expect(DaybookPalette.diaryPreset(forTagName: "工作") == DaybookPalette.accent.base)
    }
}
