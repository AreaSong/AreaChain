import AppKit
import Testing
@testable import AreaChain

@MainActor
final class UnifiedSearchSettingFixture {
    let io: PreferenceCommandIO
    let prefs: AppPreferences
    let results: UnifiedSearchResultsFixture
    var controller: UnifiedSearchController { results.controller }
    var adapter: LocalSettingCommandAdapter { controller.localSettings! }

    init(io: PreferenceCommandIO? = nil, hostID: String = HandoffFixture.source) throws {
        let io = try io ?? PreferenceCommandIO()
        self.io = io
        prefs = io.preferences()
        results = try UnifiedSearchResultsFixture(localPreferences: prefs, hostID: hostID)
        io.resetCounts()
    }

    func stop() { results.stop(); io.cleanup() }
    var draft: CommandDraft { get throws { try #require(controller.settingDraft) } }
    var run: CommandExecutionRun {
        get throws { try #require(results.handoff.state(controller.buffer.lease.ownership.hostID).execution) }
    }
    var unit: CommandExecutionUnit { get throws { try #require(run.units.first) } }
    var report: LocalSettingCommandReport {
        get throws {
            let attempt = try #require(run.attempt(unit.id))
            let actual = try adapter.report(for: attempt,
                expecting: results.handoff.owned(controller.buffer.lease.ownership.hostID).lease)
            return try #require(actual)
        }
    }

    func start(_ id: String = "setting.language", value: CommandValue? = .choice("english")) throws {
        try results.startOperation(id)
        if let value { try edit(value) }
    }

    func edit(_ value: CommandValue) throws {
        let command = try #require(CommandCatalog.standard.command(id: draft.commandID))
        let parameter = try #require(command.parameters.first)
        try #require(controller.editParameter(.init(parameter: parameter.id, operation: .assign, value: value),
                                              source: controller.buffer) != nil)
    }

    func queue() throws {
        try #require(controller.enqueue(draft.stamp, source: controller.buffer))
    }

    func submit() { controller.requestOperationSubmit(controller.buffer) }

    func host(layout: UnifiedSearchInputLayout = .standard, width: CGFloat = 620,
              locale: String = "en", dark: Bool = false) async throws -> UnifiedSearchTestHost {
        _ = try await results.publish()
        let host = UnifiedSearchTestHost(layout: layout, width: width, locale: locale, dark: dark,
                                         results: controller, operations: true)
        try await host.start()
        return host
    }

    func conflict() throws -> UnifiedSearchSettingConfirmation {
        controller.requestSettingConflict(source: controller.buffer)
        return try #require(controller.settingConfirmation)
    }
}

enum UnifiedSearchSettingSamples {
    static let ids = ["setting.language", "setting.appearance", "setting.truncation", "setting.captureSource"]
    static let values: [CommandValue] = [.choice("chinese"), .choice("dark"), .choice("middle"), .boolean(true)]
    static let preferences: [LocalPreferenceValue] = [.language(.chinese), .appearance(.dark),
                                                     .quadrantTitleTruncation(.middle), .stampCaptureApp(true)]
}

extension UnifiedSearchTestHost {
    func revealSettingControlInsidePanel(_ identifier: String) async throws {
        let node = try resultNode(identifier)
        try await SettingsButtonTestSupport.reveal(node, in: window)
        let boundary = try #require(SettingsButtonTestSupport.elements(window.contentView)
            .compactMap { $0 as? UnifiedSearchOperationBoundary }.first)
        let frame = try SettingsButtonTestSupport.frame(node, in: window)
        #expect(boundary.convert(boundary.bounds, to: nil).contains(frame), "控件 \(identifier) 必须位于操作面板内")
    }

    func chooseSettingValue(_ value: CommandValue) async throws {
        let picker = try MenuButtonTestSupport.menu("unified.operation.value", in: window)
        try await SettingsButtonTestSupport.reveal(picker, in: window)
        let menu = try await MenuButtonTestSupport.openAndEscape(picker, in: window)
        let title = UnifiedSearchSettingCopy.value(value, locale: .init(identifier: "en"), calendar: .current)
        let steps = try #require(menu.items.firstIndex { $0.title == title })
        try #require(menu.items.first?.state == .on)
        for _ in 0..<steps {
            let current = try MenuButtonTestSupport.menu("unified.operation.value", in: window)
            try await PickerNativeTestSupport.keyboardSelection(current, moveDown: true, in: window)
        }
    }

    func settingKey(_ code: UInt16, _ character: String, step: String, flags: NSEvent.ModifierFlags = []) async throws {
        if !window.isKeyWindow { try snapshot("setting-focus-failed-" + step) }
        try #require(window.isKeyWindow,
            "设置链路阶段 \(step)，appActive=\(NSApp.isActive)，frontmost=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown")")
        try await key(code, character, flags: flags)
    }

    func hasSettingControl(_ identifier: String) -> Bool {
        SettingsButtonTestSupport.elements(window.contentView).contains {
            SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String == identifier
        }
    }

    func settingStatus() throws -> String {
        let node = try resultNode("unified.setting.status")
        return SettingsButtonTestSupport.value(node, "accessibilityValue") as? String
            ?? SettingsButtonTestSupport.value(node, "accessibilityLabel") as? String ?? ""
    }
}
