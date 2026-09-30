import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct SettingsSectionPresentationTests {
    private static var retained: [ModelContainer] = []

    @Test func loginApprovalExplainsAndOffersSystemSettings() async throws {
        let container = try makeContainer()
        let view = LoginApprovalProbe()
        let window = SystemPageHost.window(
            view, container: container, scheme: .light, locale: "zh-Hans", size: NSSize(width: 520, height: 420)
        )
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let ids = SystemPageHost.identifiers(in: window)
        #expect(ids.contains("settings.login.needsApproval"))
        #expect(ids.contains("settings.login.openSystem"))
        try SystemPageHost.assertContained(["settings.login.needsApproval", "settings.login.openSystem"], in: window)
    }

    @Test func calendarConflictListsBothSidesAndAMissingEvent() async throws {
        let container = try makeContainer()
        let local = CalendarContent(title: "本地标题", dayKey: "2026-09-30", remindMinutes: 9 * 60)
        let remote = CalendarContent(title: "日历标题", dayKey: "2026-10-01", remindMinutes: nil)
        let view = CalendarConflictProbe(local: local, remote: remote)
        let window = SystemPageHost.window(
            view, container: container, scheme: .light, locale: "zh-Hans", size: NSSize(width: 520, height: 420)
        )
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let described = accessibilityDump(window)
        #expect(described.contains("本机 · 本地标题"), "\(described)")
        #expect(described.contains("09:00"), "\(described)")
        #expect(described.contains("日历 · 日历标题"), "\(described)")
        #expect(described.contains("无提醒"), "\(described)")
        #expect(described.contains("日历 · 日历里没有可对照的这一条"), "\(described)")
    }

    private struct LoginApprovalProbe: View {
        @State private var markers: Set<String> = []

        var body: some View {
            Form {
                GeneralSettingsSection(
                    launchesAtLogin: .constant(false),
                    loginNeedsApproval: true,
                    statusMessage: nil,
                    onUpdateLoginItem: { _ in }
                )
            }
            .formStyle(.grouped)
            .systemPageMarkers($markers)
            .accessibilityIdentifier("settings.login.probe")
            .accessibilityValue(markers.sorted().joined(separator: " "))
        }
    }

    private struct CalendarConflictProbe: View {
        var local: CalendarContent
        var remote: CalendarContent
        @State private var markers: Set<String> = []

        var body: some View {
            Form {
                CalendarConflictList(comparisons: [
                    CalendarConflictComparison(taskID: UUID(), local: local, remote: remote),
                    CalendarConflictComparison(taskID: UUID(), local: local, remote: nil)
                ]) { _ in }
            }
            .formStyle(.grouped)
            .systemPageMarkers($markers)
            .accessibilityIdentifier("settings.calendar.probe")
            .accessibilityValue(markers.sorted().joined(separator: " "))
        }
    }

    private func accessibilityDump(_ window: NSWindow) -> String {
        var lines: [String] = []
        func walk(_ element: NSObject) {
            if let accessible = element as? NSAccessibilityProtocol {
                let pieces = [
                    accessible.accessibilityIdentifier() ?? "",
                    accessible.accessibilityLabel() ?? "",
                    accessible.accessibilityTitle() ?? "",
                    String(describing: accessible.accessibilityValue() ?? "")
                ].filter { !$0.isEmpty && $0 != "nil" && $0 != "0" }
                if !pieces.isEmpty { lines.append(pieces.joined(separator: " ")) }
                for child in accessible.accessibilityChildren() ?? [] {
                    if let object = child as? NSObject { walk(object) }
                }
            }
            if let view = element as? NSView {
                for subview in view.subviews { walk(subview) }
            }
        }
        if let root = window.contentView { walk(root) }
        return lines.joined(separator: "\n")
    }

    private func makeContainer() throws -> ModelContainer {
        let container = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        Self.retained.append(container)
        return container
    }
}
