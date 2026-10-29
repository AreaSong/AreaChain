import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct AppStartupTests {
    private func evidence(qa: Bool = true, marker: Bool = true, injection: Bool = true) -> AppLaunchPolicy.Evidence {
        .init(compiledForQA: qa, schema: "1", role: qa ? "qa" : "application",
              qaIdentifier: qa ? "com.areachain.privacy-qa.test" : "",
              bundleIdentifier: qa ? "com.areachain.privacy-qa.test" : "com.areachain.app",
              testMarkerPresent: marker, testInjectionLoaded: injection)
    }

    @Test func buildAndRuntimeMatrixNeverFallsBackFromQA() throws {
        var invalid = [AppLaunchPolicy.Evidence]()
        for marker in [false, true] {
            for injection in [false, true] where !marker || !injection {
                invalid.append(evidence(marker: marker, injection: injection))
            }
        }
        for role in [nil, "", "application", "unknown"] as [String?] {
            var item = evidence(); item.role = role; invalid.append(item)
        }
        for identifier in [nil, "", "com.areachain.app", "com.areachain.privacy-qa.other"] as [String?] {
            var item = evidence(); item.qaIdentifier = identifier; invalid.append(item)
        }
        var schema = evidence(); schema.schema = nil; invalid.append(schema)
        var wrongCompile = evidence(); wrongCompile.compiledForQA = false; invalid.append(wrongCompile)
        var wrongNamespace = evidence(); wrongNamespace.bundleIdentifier = "com.areachain.app"
        wrongNamespace.qaIdentifier = "com.areachain.app"; invalid.append(wrongNamespace)
        for item in invalid {
            var factories = 0
            let policy = AppLaunchPolicy.evaluate(item)
            #expect(throws: AppLaunchPolicy.Rejection.self) {
                try policy.construct(application: { factories += 1 }, testing: { factories += 1 })
            }
            #expect(throws: AppLaunchPolicy.Rejection.self) { try policy.startServices { factories += 1 } }
            #expect(factories == 0)
        }
    }

    @Test func normalDefaultAndTestFactoriesRemainDistinct() throws {
        var calls: [String] = []
        let normal = AppLaunchPolicy.evaluate(evidence(qa: false, marker: false, injection: false))
        #expect(normal == .application)
        try normal.construct(application: { calls.append("disk") }, testing: { calls.append("memory") })
        try normal.startServices { calls.append("services") }
        #expect(calls == ["disk", "services"])
        for qa in [false, true] {
            let test = AppLaunchPolicy.evaluate(evidence(qa: qa))
            #expect(test == .testing)
            calls = []
            let container: ModelContainer = try test.construct(application: { () throws -> ModelContainer in
                calls.append("disk"); throw AppLaunchPolicy.Rejection.testRuntime
            },
                testing: { calls.append("memory"); return try AppStartup.memoryContainer() })
            try test.startServices { calls.append("services") }
            #expect(calls == ["memory"])
            #expect(container.configurations.filter { !$0.isStoredInMemoryOnly }.isEmpty)
            #expect(!container.mainContext.autosaveEnabled)
        }
    }

    @Test func realXCTestReachedAfterEarlyGateAndUsesMemory() throws {
        #expect(AppStartup.policy == .testing)
        #expect(AppStartup.evidence.testMarkerPresent)
        #expect(AppStartup.evidence.testInjectionLoaded)
        #expect(Bundle(for: RuntimeBundle.self).bundleURL.pathExtension == "xctest")
        #expect(NSClassFromString("XCTestCase") != nil)
        let container = try AppStartup.memoryContainer()
        #expect(container.configurations.filter { !$0.isStoredInMemoryOnly }.isEmpty)
        let delegate = AppDelegate()
        var calls = 0
        delegate.terminationLocale = { calls += 1; return Locale(identifier: "en") }
        delegate.presentQuitConfirmation = { _ in calls += 1; return .alertFirstButtonReturn }
        delegate.confirmDiaryTermination = { calls += 1; return true }
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        #expect(delegate.applicationShouldTerminate(NSApp) == .terminateNow)
        #expect(calls == 0)
        // 只保留存在性和类别，真实 marker 的空值也作为正向启动时序证据。
        let packet = ["qa": AppStartup.compiledForQA, "markerPresent": AppStartup.evidence.testMarkerPresent,
                      "markerEmpty": ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == "",
                      "injectionLoadedBeforeApp": AppStartup.evidence.testInjectionLoaded]
        Attachment.record(try JSONSerialization.data(withJSONObject: packet, options: .sortedKeys),
                          named: "startup-runtime.json")
    }

    /// QA 包同样注册 areachain scheme，测试分支收到 URL 时不能打开浮窗、工作台或改共享导航。
    @Test func testingBranchIgnoresURLOpens() throws {
        #expect(AppStartup.policy == .testing)
        let activate = AppWindows.activateForOpening, show = AppWindows.showWorkspaceWindow
        let quickEntry = QuickEntryPanelController.shared
        let panelBefore = quickEntry.hostedWindow, visibleBefore = quickEntry.isVisible
        let tabBefore = WorkspaceNavigation.shared.selectedTab
        let policyBefore = NSApp.activationPolicy()
        var opened: [String] = []
        AppWindows.activateForOpening = { opened.append("activate") }
        AppWindows.showWorkspaceWindow = { opened.append("show") }
        defer {
            AppWindows.activateForOpening = activate; AppWindows.showWorkspaceWindow = show
            // 只在旧行为误开浮窗时收起，不走 resignIfIdle，避免波及其他测试窗口。
            if quickEntry.isVisible != visibleBefore { quickEntry.hostedWindow?.orderOut(nil) }
            WorkspaceNavigation.shared.selectedTab = tabBefore
            NSApp.setActivationPolicy(policyBefore)
        }
        let urls = ["quick-task", "quick-diary", "quadrant", "today", "diary", "unknown"]
            .compactMap { URL(string: "areachain://" + $0) }
        AppDelegate().application(NSApp, open: urls)
        #expect(opened.isEmpty)
        #expect(quickEntry.hostedWindow === panelBefore)
        #expect(quickEntry.isVisible == visibleBefore)
        #expect(WorkspaceNavigation.shared.selectedTab == tabBefore)
        #expect(NSApp.activationPolicy() == policyBefore)
    }

    private final class RuntimeBundle: NSObject {}
}
