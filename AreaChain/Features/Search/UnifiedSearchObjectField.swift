import SwiftUI

/// 目标和普通对象参数共用安全行；唯一可编辑业务值来自原草稿。
struct UnifiedSearchObjectField: View {
    @Bindable var controller: UnifiedSearchController
    let draft: CommandDraft
    let command: CommandDescriptor
    let location: UnifiedSearchObjectLocation
    let source: UnifiedSearchBuffer
    @State private var expanded = true
    @State private var chooseKeySource: UnifiedSearchBuffer?
    @FocusState private var chooseFocused: Bool
    @Environment(\.locale) private var locale

    var body: some View {
        _ = controller.revision
        let objects = controller.selectedObjects(location, draft: draft)
        return VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text(verbatim: L10n.format("unified.objects.count", locale: locale, objects.count))
                .font(DaybookType.caption)
            if available {
                Button(objects.isEmpty ? "unified.objects.choose" : "unified.objects.reselect") {
                    controller.beginObjectSelection(location, source: source)
                }
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact)).focusable().focused($chooseFocused)
                .onKeyPress(.space, phases: [.down, .repeat, .up]) { press in
                    guard chooseFocused, press.modifiers.isEmpty, controller.validates(source) else {
                        chooseKeySource = nil
                        return .ignored
                    }
                    // 与公共 Toggle 一样，显式焦点容器在释放空格时单次激活，避免重复派发。
                    if press.phase == .down { chooseKeySource = source }
                    if press.phase == .up {
                        if let pressed = chooseKeySource { controller.beginObjectSelection(location, source: pressed) }
                        chooseKeySource = nil
                    }
                    return .handled
                }
                .onChange(of: chooseFocused) { _, value in if !value { chooseKeySource = nil } }
                .disabled(controller.objectSelectionLocation != nil)
                .accessibilityIdentifier("unified.objects.choose." + identifier)
            } else {
                Text("unified.objects.sourceLimit").font(DaybookType.caption)
            }
            if !objects.isEmpty {
                Button(expanded ? "unified.objects.hide" : "unified.objects.show") { expanded.toggle() }
                    .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                if expanded {
                    ForEach(objects, id: \.self) { object in
                        if let row = controller.objectPreview(object) {
                            UnifiedSearchResultRow(row: row, layout: .compact, active: false, selected: true,
                                activate: { controller.beginObjectSelection(location, source: source) },
                                select: { controller.removeObject(object, location: location, source: source) },
                                selectionLabel: "unified.objects.remove", showsIdentityDate: true)
                        } else {
                            unavailable(object)
                        }
                    }
                }
                if location == .targets, objects.count == 1, let object = objects.first,
                   object.type == .routineOccurrence, controller.routine?.supports(command.id) == true {
                    UnifiedSearchRoutineOccurrenceDate(controller: controller, object: object, source: source)
                }
                Text(controller.routesBatch(command.id) ? "unified.batch.finalCheck" : "unified.objects.finalCheck")
                    .font(DaybookType.caption)
            }
        }
        .onChange(of: controller.objectReturnRevision) { _, _ in
            if controller.objectReturnLocation == location {
                chooseFocused = true
                controller.objectReturnLocation = nil
            }
        }
        .onAppear {
            if controller.objectReturnLocation == location, controller.objectReturnRevision > 0 {
                chooseFocused = true
                controller.objectReturnLocation = nil
            }
        }
    }

    private var identifier: String {
        if case .parameter(let id) = location { return id.rawValue }
        return "target"
    }

    private var available: Bool {
        !controller.objectTypes(location, command: command).isDisjoint(with: UnifiedSearchController.adaptedObjectTypes)
            && command.interactions.isDisjoint(with: [.secureInput, .authentication, .freshAuthentication])
    }

    private func unavailable(_ object: CommandObjectReference) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            Text(verbatim: L10n.format(UnifiedSearchResultCopy.typeKey(object.type), locale: locale)
                 + (object.dayKey.map { " · " + $0 } ?? ""))
            Text("unified.objects.recheck").font(DaybookType.caption)
            Button("unified.objects.remove") { controller.removeObject(object, location: location, source: source) }
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                .accessibilityIdentifier("unified.objects.remove." + object.searchIdentifier)
        }
    }
}
