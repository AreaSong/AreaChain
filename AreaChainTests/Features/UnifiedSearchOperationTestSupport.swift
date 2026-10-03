import AppKit
import SwiftUI
import Testing
@testable import AreaChain

struct UnifiedSearchOperationTestContent: View {
    @Bindable var controller: UnifiedSearchController
    let layout: UnifiedSearchInputLayout
    var body: some View {
        VStack(spacing: 8) {
            Color.clear.frame(height: 260)
            UnifiedSearchInput(buffer: controller.buffer, focused: $controller.inputFocused,
                actions: controller.actions, layout: layout, reset: controller.inputReset,
                parameter: controller.inputParameterContext, previewBelow: true)
            UnifiedSearchOperationPanel(controller: controller).frame(height: 450)
            UnifiedSearchResults(controller: controller, layout: layout)
        }
        .padding(12).background(DaybookPalette.fill.page).unifiedSearchOverlayHost()
    }
}

extension UnifiedSearchResultsFixture {
    func startOperation(_ id: String) throws {
        let response = controller.beginOperation(.init(rawValue: id), source: controller.buffer)
        try #require(response != nil)
    }

    var draft: CommandDraft { get throws { try #require(controller.operations?.active) } }

    func parameter(_ id: CommandParameterID) throws -> (CommandParameter, UnifiedSearchParameterContext) {
        let command = try #require(CommandCatalog.standard.command(id: draft.commandID))
        let parameter = try #require(command.parameters.first { $0.id == id })
        return (parameter, .init(command: command, parameter: parameter,
            operation: controller.fieldOperation(parameter, draft: try draft)))
    }

    func typeParameter(_ id: CommandParameterID, text: String) throws {
        let (parameter, context) = try parameter(id)
        let source = controller.parameterBuffer(parameter, draft: try draft)
        let result = controller.editParameterText(.init(source: source, text: text,
            selection: NSRange(location: text.utf16.count, length: 0)), context: context)
        try #require(result != nil)
    }
}

extension UnifiedSearchTestHost {
    func parameterField(_ id: CommandParameterID) throws -> NSTextField {
        try #require(SettingsButtonTestSupport.elements(window.contentView).compactMap { $0 as? NSTextField }.first {
            ($0.delegate as? DaybookTextField.Coordinator)?.parent.unifiedSearch?.parameter?.parameter.id == id
        })
    }

    func focusParameter(_ id: CommandParameterID) async throws -> NSTextView {
        let field = try parameterField(id)
        try await SettingsButtonTestSupport.reveal(field, in: window)
        window.makeFirstResponder(field)
        try await settle()
        return try #require(field.currentEditor() as? NSTextView)
    }
}
