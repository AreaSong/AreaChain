import SwiftUI

/// 有界视口保留全部日期，按稳定民事日定位；计数是物理行数，不是完成次数。
struct UnifiedSearchRoutineStateImpact: View {
    let impact: CommandRoutineStateImpact
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text(verbatim: label(impact.definition.isEnabled ? "enabled" : "disabled") + " → "
                 + label(impact.finalEnabled ? "enabled" : "disabled"))
            Text(verbatim: L10n.format("unified.routineState.pause", locale: locale,
                impact.definition.pausedOnDayKey ?? "—", impact.finalPause ?? "—"))
            if let start = impact.start, let source = impact.startSource {
                Text(verbatim: L10n.format("unified.routineState.interval", locale: locale, start, impact.today, impact.span))
                Text(LocalizedStringKey("unified.routineState.source." + source.rawValue))
                Text(verbatim: WeekdayMask.selectedLabels(impact.definition.weekdayMask, locale: locale, calendar: impact.calendar))
                Text("unified.routineState.currentSchedule").accessibilityIdentifier("unified.routineState.policy")
            }
            Text(verbatim: L10n.format("unified.routineState.counts", locale: locale,
                                      impact.inserted, impact.modified, impact.preserved))
                .accessibilityIdentifier("unified.routineState.counts")
            if !impact.effects.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DaybookSpacing.sm) {
                        ForEach(impact.effects) { effect in detail(effect) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                // 局部预览视口，避免4000日影响撑开原计划；不改变共享宿主尺寸。
                .frame(height: 180)
                .accessibilityLabel(Text("unified.routineState.details"))
                .accessibilityIdentifier("unified.routineState.details")
            }
        }.font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
    }

    private func detail(_ effect: CommandRoutineCheckEffect) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            Text(verbatim: effect.day + " · " + L10n.format("unified.routineState.action." + String(describing: effect.action), locale: locale))
            if effect.original.isEmpty { Text("unified.routineState.noRecord") }
            ForEach(effect.original, id: \.id) { row in
                Text(verbatim: row.id.uuidString + " · " + state(row.done, row.skipped))
                    .textSelection(.enabled)
            }
            if effect.action != .preserve { Text(verbatim: "→ " + state(effect.done, effect.skipped)) }
            if effect.diagnostics.contains(.conflictingRecords) { Text("unified.routineState.preservedConflict") }
            if effect.diagnostics.contains(.identicalDuplicates) { Text("unified.routineState.identicalDuplicates") }
            if effect.diagnostics.contains(.equivalentEncodingDuplicates) { Text("unified.routineState.encodingDuplicates") }
        }.accessibilityElement(children: .combine).accessibilityIdentifier("unified.routineState.day." + effect.day)
    }

    private func state(_ done: Bool, _ skipped: Bool) -> String {
        L10n.format("unified.routineState.state." + (skipped ? "skipped" : (done ? "completed" : "unprocessed")), locale: locale)
            + " (" + String(done) + "/" + String(skipped) + ")"
    }
    private func label(_ key: String) -> String { L10n.format("unified.routine." + key, locale: locale) }
}
