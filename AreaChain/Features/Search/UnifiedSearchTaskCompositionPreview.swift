import SwiftUI

/// 只展示服务给出的来源与最终计划；折叠不隐藏新建/恢复副作用的数量。
struct UnifiedSearchTaskCompositionPreview: View {
    @Bindable var controller: UnifiedSearchController
    @Environment(\.locale) private var locale
    @State private var expanded = true
    private typealias Copy = UnifiedSearchTaskCompositionCopy

    var body: some View {
        let source = controller.buffer
        let preview = controller.currentTaskComposition
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.composition.capability").font(DaybookType.caption)
            if let preview {
                effects(preview)
                if controller.currentTaskAcceptance != nil {
                    Text("unified.composition.accepted").font(DaybookType.caption)
                } else {
                    Button("unified.composition.accept") { controller.acceptTaskComposition(preview, source: source) }
                        .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
                        .disabled(!preview.canPrepareExecution || controller.settingSubmitting)
                        .accessibilityIdentifier("unified.composition.accept")
                }
            } else {
                Text(controller.taskCompositionPreview == nil ? "unified.composition.unprepared" : "unified.composition.stale")
                    .font(DaybookType.caption)
            }
            if let failure = controller.compositionFailure {
                Text(LocalizedStringKey(failure)).font(DaybookType.caption)
                    .accessibilityIdentifier("unified.composition.issue")
            }
            Button("unified.composition.prepare") { controller.prepareTaskComposition(source) }
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact)).disabled(controller.settingSubmitting)
                .accessibilityIdentifier("unified.task.prepare")
            Button("unified.task.create") { controller.requestOperationSubmit(source) }
                .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
                .disabled(controller.settingSubmitting || controller.currentTaskAcceptance == nil)
                .accessibilityIdentifier("unified.task.create")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("unified.composition.preview")
    }

    private func effects(_ preview: CommandTaskCreatePreview) -> some View {
        let fields = preview.composition
        return VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.composition.final").font(DaybookType.body.weight(.semibold))
            Text(verbatim: fields.title.isEmpty ? L10n.format("unified.composition.metadata", locale: locale) : fields.title)
                .font(DaybookType.body).accessibilityIdentifier("unified.composition.title")
            Text(verbatim: fields.day).font(DaybookType.caption).accessibilityIdentifier("unified.task.day")
            UnifiedSearchTaskTagSummary(associations: fields.tags.final)
                .accessibilityIdentifier("unified.composition.tagSummary")
            Button(expanded ? "unified.composition.collapse" : "unified.composition.expand") { expanded.toggle() }
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                .accessibilityIdentifier("unified.composition.disclosure")
            if expanded { details(preview) }
            ForEach(Array(preview.issues.enumerated()), id: \.offset) { _, issue in
                Text(LocalizedStringKey(Copy.error(issue))).font(DaybookType.caption)
            }
            ForEach(Array(fields.tags.problems.enumerated()), id: \.offset) { _, problem in
                Text(LocalizedStringKey(Copy.problem(problem.kind))).font(DaybookType.caption)
            }
        }
    }

    private func details(_ preview: CommandTaskCreatePreview) -> some View {
        let fields = preview.composition
        return VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.composition.raw").font(DaybookType.caption)
            if case .shortText(let raw) = preview.arguments.first(where: { $0.parameter == .title })?.value {
                Text(verbatim: raw).font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
            }
            Text(verbatim: L10n.format("command.parameter.priority", locale: locale) + ": "
                + (fields.priority.hasConflict ? L10n.format("unified.composition.conflict", locale: locale)
                   : fields.priorityFlags.map(Copy.priority) ?? ""))
            Text(verbatim: Copy.field(fields.priority, locale: locale, format: Copy.priority))
            Text(verbatim: L10n.format("command.parameter.time", locale: locale) + ": "
                + (fields.reminder.hasConflict ? L10n.format("unified.composition.conflict", locale: locale)
                   : fields.reminder.value.map(Copy.time) ?? L10n.format("unified.operation.mode.cancelReminder", locale: locale)))
            Text(verbatim: Copy.field(fields.reminder, locale: locale, format: Copy.time))
            tags(fields.tags)
            Text(preview.source.stampEnabled ? "unified.task.sourceEnabled" : "unified.task.sourceDisabled")
            if preview.source.stampEnabled { Text(verbatim: preview.source.bundleID) }
            Text("unified.composition.notSaved")
        }.font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
    }

    private func tags(_ tags: CommandTaskTagPlan) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            UnifiedSearchTaskTagEffects(associations: tags.final)
            ForEach(Array(tags.removed.enumerated()), id: \.offset) { _, target in
                Text(verbatim: L10n.format("unified.composition.removed", locale: locale) + " · " + Copy.name(target))
            }
            ForEach(Array(tags.noEffects.enumerated()), id: \.offset) { _, effect in
                switch effect {
                case .empty: Text("unified.composition.noEffect")
                case .alreadyAssociated(let target), .notAssociated(let target):
                    Text(verbatim: L10n.format("unified.composition.noEffect", locale: locale) + " · " + Copy.name(target))
                }
            }
        }
    }
}
