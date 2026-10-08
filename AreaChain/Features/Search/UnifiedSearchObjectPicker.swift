import SwiftUI

/// 选择器无实体/正文读取，也不另写名称匹配。所有事件携带本次渲染的选择与候选版本。
struct UnifiedSearchObjectPicker: View {
    @Bindable var controller: UnifiedSearchController
    let command: CommandDescriptor
    @Environment(\.locale) private var locale

    var body: some View {
        let cancellation = controller.objectSelection?.id ?? controller.objectRequestID
        let keySelection = controller.objectSelection
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text(verbatim: command.name(locale: locale)).font(DaybookType.body.weight(.semibold))
            if let picker = controller.objectSelection, let object = picker.occurrenceDateTarget,
               controller.validatesObjectSelection(picker.stamp) {
                UnifiedSearchBatchOccurrenceCalendar(controller: controller, object: object, picker: picker)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
                        Text("unified.objects.queryPreserved")
                        Text(controller.allowsBatchOccurrenceSelection(command) ? "unified.batch.chooseExecutionDay" : "unified.objects.sourceLimit")
                    }.font(DaybookType.caption)
                }.frame(maxHeight: 68)
                if let picker = controller.objectSelection, controller.validatesObjectSelection(picker.stamp) {
                    Text(verbatim: L10n.format("unified.objects.allowed", locale: locale) + " "
                        + controller.objectTypes(picker.location, command: command).map {
                            L10n.format(UnifiedSearchResultCopy.typeKey($0), locale: locale)
                        }.sorted().joined(separator: "、"))
                        .font(DaybookType.caption)
                    Text(controller.allowsMultipleObjects(picker.location, command: command)
                         ? "unified.objects.multiple" : "unified.objects.singleOnly").font(DaybookType.caption)
                    selectionControls(picker)
                    candidates(picker)
                    if picker.browse.snapshot.knownUndisplayedCount > 0 {
                        Button("unified.results.loadMore") { controller.loadObjectCandidates(picker.stamp) }
                            .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                            .accessibilityIdentifier("unified.objects.more")
                    }
                    confirmation(picker)
                }
                Text(LocalizedStringKey(controller.objectSelectionMessage)).font(DaybookType.caption)
                Button("unified.operation.cancel") { controller.cancelObjectSelection(expecting: cancellation) }
                    .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                    .accessibilityIdentifier("unified.objects.cancel")
            }
        }
        .onExitCommand {
            if let picker = controller.objectSelection, picker.occurrenceDateTarget != nil {
                controller.editBatchOccurrenceSelection(nil, stamp: picker.stamp)
            } else { controller.cancelObjectSelection(expecting: cancellation) }
        }
        .onKeyPress(keys: [.return, .tab]) { key in
            guard key.modifiers.isEmpty, let picker = keySelection, picker.occurrenceDateTarget == nil else { return .ignored }
            _ = controller.acceptObjects(picker.stamp)
            return .handled
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("unified.objects.picker")
    }

    private func confirmation(_ picker: UnifiedSearchObjectSelection) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            Text(verbatim: L10n.format("unified.objects.temporaryCount", locale: locale, picker.objects.count))
                .font(DaybookType.caption)
            if let issue = controller.objectSelectionIssue(picker) {
                Text(LocalizedStringKey(issue)).font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
            }
            Button("unified.objects.accept") { controller.acceptObjects(picker.stamp) }
                .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
                .accessibilityIdentifier("unified.objects.accept")
        }
    }

    private func selectionControls(_ picker: UnifiedSearchObjectSelection) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            Button("unified.objects.visible") { controller.browseObjects(.selectVisible, stamp: picker.stamp) }
                .accessibilityIdentifier("unified.objects.visible")
            Button("unified.objects.known") { controller.browseObjects(.selectAllKnown, stamp: picker.stamp) }
                .accessibilityIdentifier("unified.objects.known")
            if controller.allowsMultipleObjects(picker.location, command: command) {
                if controller.session.allObjectResultsComplete(sourceID: picker.browse.snapshot.sourceID) {
                    Button("unified.objects.allResults") { controller.selectAllObjectResults(picker.stamp) }
                        .accessibilityIdentifier("unified.objects.allResults")
                } else {
                    Text("unified.objects.incompleteAll").font(DaybookType.caption)
                        .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("unified.objects.incompleteAll")
                }
            }
        }.buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
    }

    private func candidates(_ picker: UnifiedSearchObjectSelection) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DaybookSpacing.xs) {
                    ForEach(picker.browse.snapshot.visible, id: \.self) { object in
                        if let row = picker.browse.snapshot.row(object) {
                            VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
                                UnifiedSearchResultRow(row: row, layout: .compact,
                                    active: picker.browse.active == object, selected: picker.browse.selected.contains(object),
                                    activate: { controller.browseObjects(.activate(object), stamp: picker.stamp) },
                                    select: { controller.toggleObject(object, stamp: picker.stamp) }, showsIdentityDate: true)
                                if controller.allowsBatchOccurrenceSelection(command), object.type == .routine {
                                    if picker.browse.selected.contains(object) {
                                        UnifiedSearchBatchOccurrenceSelection(controller: controller, object: object, picker: picker)
                                    } else { Text("unified.batch.chooseExecutionDay").font(DaybookType.caption) }
                                } else if !controller.objectTypes(picker.location, command: command).contains(object.type) {
                                    Text("unified.objects.wrongType").font(DaybookType.caption)
                                } else if (try? controller.session.objectCandidate(object,
                                            sourceID: picker.browse.snapshot.sourceID)) == nil {
                                    Text("unified.objects.unsupported").font(DaybookType.caption)
                                }
                            }.id(object)
                        }
                    }
                }
            }
            .frame(minHeight: 50, maxHeight: .infinity)
            .modifier(DaybookScrollTargetModifier())
            .onChange(of: picker.browse.active) { _, id in if let id { proxy.scrollTo(id) } }
        }
    }
}
