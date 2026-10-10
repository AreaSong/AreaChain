import SwiftUI

/// 与原标签清单共用关联/排序模型；本入口不安装新增、勾选、拖放、删除或快捷键写入动作。
struct WorkspaceTagReadOnlyList: View {
    let tag: TagItem
    let model: WorkspaceFilteredListModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DaybookSpacing.md) {
                Text(verbatim: tag.name).font(DaybookType.title)
                if model.isEmpty { DaybookEmptyState(title: "empty.filtered.todos", systemImage: "tag") }
                ForEach(model.openRows + model.doneRows, id: \.listID) { row in
                    switch row {
                    case .todo(let todo): record(todo.title, detail: todo.dayKey, icon: "checklist")
                    case .resident(let routine): record(routine.title, detail: "", icon: "repeat")
                    }
                }
                ForEach(model.matchingSubtasks) { child in
                    record(child.title, detail: child.todo?.title ?? "", icon: "checklist")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DaybookSpacing.lg)
        }
        .daybookScroll()
        .accessibilityIdentifier("unified.content.tagRecords")
    }

    private func record(_ title: String, detail: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: DaybookSpacing.sm) {
            Image(systemName: icon).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
                Text(verbatim: title).font(DaybookType.body)
                if !detail.isEmpty { Text(verbatim: detail).font(DaybookType.caption).foregroundStyle(DaybookPalette.text.secondary) }
            }
        }
        .textSelection(.enabled)
        .padding(DaybookSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .daybookStaticCardSurface()
    }
}
