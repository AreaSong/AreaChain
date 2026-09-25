import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct DashboardRenderingTests {
    private struct Appearance: Sendable {
        var scheme: ColorScheme
        var language: String
        var minimumSize: Bool
    }

    private static let appearances: [Appearance] = [
        Appearance(scheme: .light, language: "zh-Hans", minimumSize: false),
        Appearance(scheme: .light, language: "zh-Hans", minimumSize: true),
        Appearance(scheme: .dark, language: "zh-Hans", minimumSize: false),
        Appearance(scheme: .dark, language: "en", minimumSize: true),
        Appearance(scheme: .light, language: "en", minimumSize: false),
        Appearance(scheme: .dark, language: "en", minimumSize: false)
    ]

    private static var retained: [ModelContainer] = []

    @Test(arguments: appearances)
    private func dashboardRendersDataAndEmptyStates(_ appearance: Appearance) async throws {
        let container = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        Self.retained.append(container)
        if appearance.language == "zh-Hans" && appearance.scheme == .light && !appearance.minimumSize {
            try seed(container.mainContext)
        }
        let previous = NSApp.appearance
        defer { NSApp.appearance = previous }
        NSApp.appearance = NSAppearance(named: appearance.scheme == .dark ? .darkAqua : .aqua)
        let width = appearance.minimumSize ? DaybookMetrics.Window.workspaceMinSize.width : 960
        let height = appearance.minimumSize ? DaybookMetrics.Window.workspaceMinSize.height : 640
        let host = NSHostingView(rootView: DashboardView()
            .modelContainer(container)
            .environment(\.locale, Locale(identifier: appearance.language))
            .environment(\.colorScheme, appearance.scheme)
            .environment(\.workspaceEmbedded, true)
            .frame(width: width, height: height))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 640), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(200))
        host.layoutSubtreeIfNeeded()
        #expect(host.bounds.width > 0)
        #expect(host.bounds.height > 0)
        #expect(host.bounds.width <= width + 1)
        window.close()
    }

    private func seed(_ context: ModelContext) throws {
        let today = "2026-09-25"
        context.insert(TodoItem(title: "完成总览", isDone: true, dayKey: today, createdAt: date("2026-09-25T01:00:00Z")))
        context.insert(TodoItem(title: "还没做", dayKey: today, createdAt: date("2026-09-25T02:00:00Z")))
        let routine = DailyRoutine(title: "喝水", sortOrder: 0, createdDayKey: today, createdAt: date("2026-09-25T03:00:00Z"))
        context.insert(routine)
        let secret = DiaryEntry(text: "私密正文不应出现", dayKey: today, createdAt: date("2026-09-25T04:00:00Z"))
        secret.isPrivate = true
        context.insert(secret)
        try context.save()
    }

    private func date(_ text: String) -> Date {
        ISO8601DateFormatter().date(from: text)!
    }
}
