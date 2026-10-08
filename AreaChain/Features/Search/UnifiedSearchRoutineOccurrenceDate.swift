import SwiftUI

extension UnifiedSearchController {
    func editBatchOccurrenceDay(_ object: CommandObjectReference, day: String, source: UnifiedSearchBuffer) {
        guard validates(source), taskNativeInputReady, operationVisible, let draft = editingDraft,
              draft.commandID.rawValue == "batch.completion", batch?.supports(draft.commandID) == true,
              draft.targets.objects.contains(object), object.type == .routineOccurrence,
              CommandArgumentValidation.isCanonicalDay(day) else { return }
        let objects = draft.targets.objects.map { $0 == object ? CommandObjectReference(type: .routineOccurrence, id: object.id, dayKey: day) : $0 }
        _ = sendOperation(.selectTargets(draft.stamp, .init(.selected, objects: objects), baseline: nil), source: source)
    }

    func editOccurrenceDay(_ day: String, source: UnifiedSearchBuffer) {
        guard validates(source), taskNativeInputReady, operationVisible, let draft = editingDraft,
              routine?.supports(draft.commandID) == true, draft.commandID.rawValue.hasPrefix("occurrence."),
              draft.targets.objects.count == 1, let object = draft.targets.objects.first,
              object.type == .routineOccurrence, CommandArgumentValidation.isCanonicalDay(day) else { return }
        _ = sendOperation(.selectTargets(draft.stamp,
            .init(.single, objects: [.init(type: .routineOccurrence, id: object.id, dayKey: day)]), baseline: nil), source: source)
    }
}

struct UnifiedSearchRoutineOccurrenceDate: View {
    @Bindable var controller: UnifiedSearchController
    let object: CommandObjectReference
    let source: UnifiedSearchBuffer
    @State private var expanded = false
    @FocusState private var focused: Bool
    private var batch: Bool { controller.editingDraft?.commandID.rawValue == "batch.completion" }
    private var suffix: String { batch ? "." + object.searchIdentifier : "" }

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text(verbatim: object.dayKey ?? "").font(DaybookType.body)
                .accessibilityIdentifier("unified.routineState.selectedDay" + suffix)
            Button(expanded ? "unified.operation.hideDate" : "unified.operation.chooseDate") {
                guard controller.validates(source) else { return }
                expanded.toggle()
            }.buttonStyle(DaybookButtonStyle(.quiet, size: .compact)).focused($focused)
                .accessibilityIdentifier("unified.routineState.chooseDay" + suffix)
            if expanded {
                DaybookDatePicker(selection: Binding(get: { object.dayKey ?? "" }, set: {
                    if batch { controller.editBatchOccurrenceDay(object, day: $0, source: source) }
                    else { controller.editOccurrenceDay($0, source: source) }
                }))
                .onExitCommand { expanded = false; focused = true }
            }
        }
    }
}
