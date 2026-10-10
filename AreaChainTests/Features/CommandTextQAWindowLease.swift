import AppKit
import Darwin
import Testing
@testable import AreaChain

/// 仅本批 XCTest 的就绪元数据，不保存正文；不能授予启动应用或桌面连接权限。
@MainActor final class CommandTextQAWindowLease {
    enum Failure: Error { case missingXCTest, invalidRunner, wrongBundle, wrongDirectory, missingTestRuntime }
    static let test = "CommandTextInteractiveTests/nativeInputWindow()"
    static let bundle = "com.areachain.privacy-qa.cm1r"
    let runID: String
    let directory: URL
    let expires: Double
    private var lastWrite = 0.0

    init(environment: [String: String] = ProcessInfo.processInfo.environment) throws {
        try Self.validate(environment, bundle: Bundle.main.bundleIdentifier)
        guard NSClassFromString("XCTestCase") != nil,
              Bundle(for: Self.self).bundleURL.pathExtension == "xctest" else { throw Failure.missingTestRuntime }
        runID = environment["AREACHAIN_CM1_RUN_ID"]!
        directory = URL(fileURLWithPath: environment["AREACHAIN_CM1_EVIDENCE"]!, isDirectory: true)
        let expected = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appending(path: "tmp/CM1Runner/" + runID, directoryHint: .isDirectory)
        guard directory.standardizedFileURL == expected.standardizedFileURL else { throw Failure.wrongDirectory }
        expires = Date().timeIntervalSince1970 + 300
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static func validate(_ environment: [String: String], bundle: String?) throws {
        // 当前 Xcode 可以传空值标志；与 App.init 的“存在”条件一致，真实运行另由测试 Bundle 核验。
        guard environment["XCTestConfigurationFilePath"] != nil else { throw Failure.missingXCTest }
        guard bundle == Self.bundle else { throw Failure.wrongBundle }
        guard environment["AREACHAIN_CM1_INTERACTIVE"] == "1",
              let raw = environment["AREACHAIN_CM1_RUN_ID"], UUID(uuidString: raw) != nil,
              environment["AREACHAIN_CM1_EVIDENCE"]?.isEmpty == false else {
            throw Failure.invalidRunner
        }
    }

    func write(_ state: String, window: NSWindow, locks: Int = 0, force: Bool = false) throws {
        let now = Date().timeIntervalSince1970
        guard force || now - lastWrite >= 1 else { return }
        let data: [String: Any] = [
            "format": 1, "runID": runID, "test": Self.test, "bundleID": Self.bundle,
            // 沙盒内不增加 proc-info 权限；启动秒/微秒由 runner 的 libproc 实测并持续核验。
            "pid": Int(getpid()), "launchDate": NSRunningApplication.current.launchDate?.timeIntervalSince1970 ?? 0,
            "path": Bundle.main.executableURL!.path, "window": window.windowNumber,
            "visible": window.isVisible, "key": window.isKeyWindow, "state": state,
            "heartbeat": now, "expires": expires, "memoryLocks": locks,
            "desktopConnectionAllowed": false
        ]
        try JSONSerialization.data(withJSONObject: data, options: [.sortedKeys])
            .write(to: directory.appending(path: "window.json"), options: .atomic)
        lastWrite = now
    }
}

@Suite(.serialized) @MainActor struct CommandTextQAWindowLeaseTests {
    @Test func missingRunnerOrXCTestIdentityCannotCreateWindowLease() {
        let valid = ["XCTestConfigurationFilePath": "synthetic.xctestconfiguration", "AREACHAIN_CM1_INTERACTIVE": "1",
                     "AREACHAIN_CM1_RUN_ID": UUID().uuidString, "AREACHAIN_CM1_EVIDENCE": "/synthetic"]
        #expect(throws: Never.self) { try CommandTextQAWindowLease.validate(valid, bundle: CommandTextQAWindowLease.bundle) }
        var emptyMarker = valid
        emptyMarker["XCTestConfigurationFilePath"] = ""
        #expect(throws: Never.self) { try CommandTextQAWindowLease.validate(emptyMarker, bundle: CommandTextQAWindowLease.bundle) }
        for key in valid.keys {
            var missing = valid
            missing[key] = nil
            #expect(throws: (any Error).self) { try CommandTextQAWindowLease.validate(missing, bundle: CommandTextQAWindowLease.bundle) }
        }
        #expect(throws: (any Error).self) { try CommandTextQAWindowLease.validate(valid, bundle: "com.areachain.app") }
    }
}
