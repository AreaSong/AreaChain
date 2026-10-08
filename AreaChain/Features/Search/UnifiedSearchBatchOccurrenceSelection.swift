import SwiftUI

extension UnifiedSearchController {
    func allowsBatchOccurrenceSelection(_ command: CommandDescriptor) -> Bool {
        command.id.rawValue == "batch.completion" && batch?.supports(command.id) == true
    }

    func chooseBatchOccurrenceDay(_ day: String, object: CommandObjectReference, stamp: UnifiedSearchObjectSelectionStamp) {
        guard validatesObjectSelection(stamp), taskNativeInputReady, let draft = editingDraft,
              let command = CommandCatalog.standard.command(id: draft.commandID), allowsBatchOccurrenceSelection(command),
              object.type == .routine, objectSelection?.candidateObjects.contains(object) == true,
              CommandArgumentValidation.isCanonicalDay(day),
              (try? session.objectCandidate(object, sourceID: objectSelection!.browse.snapshot.sourceID)) != nil else { return }
        objectSelection?.occurrenceDays[object] = day
        objectSelection?.occurrenceDateTarget = nil
        renewObjectCandidateSource()
        objectSelection?.source = buffer
        refreshOperationPresentation()
    }

    func editBatchOccurrenceSelection(_ object: CommandObjectReference?, stamp: UnifiedSearchObjectSelectionStamp) {
        guard validatesObjectSelection(stamp), taskNativeInputReady, let draft = editingDraft,
              let command = CommandCatalog.standard.command(id: draft.commandID), allowsBatchOccurrenceSelection(command),
              object == nil || object?.type == .routine && objectSelection?.candidateObjects.contains(object!) == true else { return }
        objectSelection?.occurrenceDateTarget = object
        renewObjectCandidateSource()
        objectSelection?.source = buffer
        refreshOperationPresentation()
    }
}

/// 明确从已核验定义选择某个执行日；没有隐含 today，也不把定义本身作为完成目标。
struct UnifiedSearchBatchOccurrenceSelection: View {
    @Bindable var controller: UnifiedSearchController
    let object: CommandObjectReference
    let picker: UnifiedSearchObjectSelection
    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            Button("unified.batch.chooseExecutionDay") { controller.editBatchOccurrenceSelection(object, stamp: picker.stamp) }
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                .accessibilityIdentifier("unified.batch.selectDay." + object.searchIdentifier)
            if let day = picker.occurrenceDays[object] { Text(verbatim: day).font(DaybookType.caption) }
        }.font(DaybookType.caption)
    }
}

struct UnifiedSearchBatchOccurrenceCalendar: View {
    @Bindable var controller: UnifiedSearchController
    let object: CommandObjectReference
    let picker: UnifiedSearchObjectSelection
    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            if let title = picker.browse.snapshot.row(object)?.primary?.text {
                Text(verbatim: title).font(DaybookType.caption).lineLimit(2)
            }
            DaybookDatePicker(selection: Binding(get: { picker.occurrenceDays[object] ?? "" }, set: {
                controller.chooseBatchOccurrenceDay($0, object: object, stamp: picker.stamp)
            }))
            Button("unified.operation.cancel") { controller.editBatchOccurrenceSelection(nil, stamp: picker.stamp) }
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                .accessibilityIdentifier("unified.batch.cancelDateSelection")
        }.accessibilityElement(children: .contain).accessibilityIdentifier("unified.batch.occurrenceCalendar")
    }
}
