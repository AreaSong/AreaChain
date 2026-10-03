import SwiftUI

/// 非命中上下文只读显示提供者已有的安全名称，不生成正文片段或选择目标。
struct UnifiedSearchTrashContext: View {
    let value: TrashTombstone
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("unified.results.deletedContext").font(DaybookType.caption.weight(.semibold))
            Text(verbatim: title).font(DaybookType.body).lineLimit(2)
            Text(LocalizedStringKey(restorationKey)).font(DaybookType.caption)
        }
        .foregroundStyle(DaybookPalette.text.secondary)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DaybookPalette.fill.hover, in: RoundedRectangle(cornerRadius: DaybookRadius.small))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("unified.context." + value.id.searchIdentifier)
    }

    private var title: String {
        switch value.fields {
        case .todo(let item): item.title
        case .subtask(let item): item.title
        case .routine(let item): item.title
        case .tag(let item): item.name
        case .image(let item): item.filename
        case .diary(let item):
            switch item.presentation {
            case .hiddenTitle(let title): title
            case .publicText: L10n.format("unified.results.type.diary", locale: locale)
            }
        }
    }

    private var restorationKey: String {
        switch value.restoration.independent {
        case .existingEntry: "unified.results.restoreNotice"
        case .notProvided: "unified.results.restoreWithParent"
        case .requiresLiveOwner: "unified.results.restoreNeedsOwner"
        case .undetermined: "unified.results.groupUnknown"
        }
    }
}
