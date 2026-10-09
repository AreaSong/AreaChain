import SwiftUI

struct UnifiedSearchMultiPlanImpact: View {
    let preview: MultiPlanCommandMemberPreview
    @Environment(\.locale) private var locale

    var body: some View {
        switch preview {
        case .taskField(let value): UnifiedSearchTaskFieldImpact(preview: value)
        case .taskTitle(let value): UnifiedSearchTaskTitlePreview(preview: value)
        case .subtask(let value): UnifiedSearchSubtaskImpact(preview: value)
        case .routine(let value): UnifiedSearchRoutineImpact(preview: value)
        case .routineCreate(let value): UnifiedSearchRoutineCreationImpact(preview: value)
        case .batch(let value): UnifiedSearchBatchImpact(preview: value)
        case .taskCreate(let value):
            if let composed = value.evidence.preview { UnifiedSearchTaskCreationImpact(preview: composed) }
            else if let input = value.evidence.input {
                VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
                    Text(verbatim: input.parsed.cleanTitle).font(DaybookType.body)
                    Text(verbatim: input.day).font(DaybookType.caption)
                    Text("unified.composition.notSaved").font(DaybookType.caption)
                }
            }
        case .output:
            Text("unified.multi.output").font(DaybookType.caption)
        case .localSetting(let value):
            UnifiedSearchSettingValues(before: value.evidence.memory,
                                       after: LocalSettingCommandMapping.commandValue(value.value))
        case .fileSettings(let value):
            VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
                Text("unified.group.member").font(DaybookType.caption)
                ForEach(Array(value.values.enumerated()), id: \.offset) { _, field in
                    UnifiedSearchSettingValues(before: LocalSettingCommandMapping.commandValue(value.record.values.value(for: field.field)),
                                               after: LocalSettingCommandMapping.commandValue(field))
                }
            }
        }
    }
}
