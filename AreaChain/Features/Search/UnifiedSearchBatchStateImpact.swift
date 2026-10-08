import SwiftUI

struct UnifiedSearchBatchWriteCounts: View {
    let counts: CommandBatchWriteSet.Counts
    @Environment(\.locale) private var locale
    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            Text(verbatim: L10n.format("unified.batch.writeCounts", locale: locale,
                counts.selected, counts.changed, counts.total, counts.limit))
                .accessibilityIdentifier("unified.batch.writeCounts")
            ForEach(CommandBatchWriteSet.Kind.allCases, id: \.self) { kind in
                Text(verbatim: L10n.format("unified.batch.entity." + kind.rawValue, locale: locale,
                    counts.inserted[kind, default: 0], counts.modified[kind, default: 0]))
            }
            if counts.exceedsLimit {
                Text("unified.batch.writeLimit").accessibilityIdentifier("unified.batch.overLimit")
            }
        }.font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
    }
}

/// 仅呈现接受／事实中的状态与级联；不在 View 重新计算排程或保存。
struct UnifiedSearchBatchStateImpact: View {
    let impact: CommandBatchTargetImpact
    @Environment(\.locale) private var locale
    @State private var childrenExpanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            if let completion = impact.completion {
                Text(verbatim: state(completion.original) + " → " + state(completion.final))
                Text(verbatim: L10n.format("unified.batch.cascade", locale: locale, completion.affected.count))
                if !completion.affected.isEmpty {
                    Button("unified.batch.cascadeDetails") { childrenExpanded.toggle() }
                        .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                        .accessibilityIdentifier("unified.batch.cascade." + impact.target.searchIdentifier)
                    if childrenExpanded {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: DaybookSpacing.xs) {
                                ForEach(completion.affected, id: \.id) { child in
                                    Text(verbatim: child.title).fixedSize(horizontal: false, vertical: true)
                                        .accessibilityIdentifier("unified.batch.child." + child.id.uuidString)
                                }
                            }
                        }.frame(height: 120)
                    }
                }
            }
            if let value = impact.state { UnifiedSearchRoutineStateImpact(impact: value) }
        }.font(DaybookType.caption)
    }
    private func state(_ done: Bool) -> String {
        L10n.format("unified.routineState.state." + (done ? "completed" : "unprocessed"), locale: locale)
    }
}
